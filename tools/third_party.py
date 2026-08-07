#!/usr/bin/env python3
"""Generate third-party attribution from the ExternalProject_add declarations in src/dependencies.

The CMake superbuild is already a lockfile — every dependency is pinned to a tag — it is just
written in a dialect no SBOM tool reads. This walks it and emits a CycloneDX SBOM plus the notice
file that the BSD/MIT/Apache licences actually require, fetching each licence text from GitHub.

    tools/third_party.py                 # regenerate dist/
    tools/third_party.py --check         # CI: fail if dist/ is stale

Outputs are committed, so builds stay offline and CI catches a dependency bump that forgot to
regenerate. Set GITHUB_TOKEN to lift the 60/hour anonymous API rate limit.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shlex
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEPENDENCIES = ROOT / "src" / "dependencies"
DIST = ROOT / "dist"

# Dependencies not fetched from GitHub, and the repository that actually carries their licence.
# OpenSSL ships from openssl.org but develops on GitHub, so the text is fetchable at the same tag.
OVERRIDES = {
    "openssl": {"repo": "openssl/openssl", "tag": "openssl-{version}"},
}

# Reviewed by hand, because GitHub's classifier returned "other" for these. Two of them do not
# carry a licence in the file GitHub picked at all — lz4's LICENSE and valhalla's LICENSE.md are
# pointers to the real text elsewhere in the tree — so `path` overrides where the text is read from.
# Anything unclassified and absent here fails the run rather than shipping as NOASSERTION.
DECLARED = {
    "protobuf": {
        "spdx": "BSD-3-Clause",
    },
    "cares": {
        "spdx": "MIT",
    },
    "lz4": {
        "spdx": "BSD-2-Clause",
        "path": "lib/LICENSE",
        "note": "Dual-licensed: lib/ is BSD-2-Clause, everything else GPL-2.0. Only the "
                "library is built and linked here (BUILD_SHARED=no, lib target only), so "
                "BSD-2-Clause applies and lib/LICENSE is the operative text.",
    },
    "valhalla": {
        "spdx": "MIT",
        "path": "COPYING",
        "note": "LICENSE.md only points at COPYING, which carries the actual MIT text.",
    },
}

# Where the licence GitHub reports understates or complicates the real terms.
CAVEATS = {
    "boost": "Boost Software License 1.0 waives the notice requirement for binary distribution; "
             "the notice is reproduced anyway.",
}

KEYWORDS = {"URL", "GIT_REPOSITORY", "GIT_TAG", "DEPENDS", "PREFIX", "CMAKE_ARGS",
            "CONFIGURE_COMMAND", "BUILD_COMMAND", "INSTALL_COMMAND", "PATCH_COMMAND",
            "BUILD_IN_SOURCE", "GIT_SUBMODULES_RECURSE"}


class Dependency:
    def __init__(self, name: str) -> None:
        self.name = name
        self.url: str | None = None
        self.git_repository: str | None = None
        self.git_tag: str | None = None
        self.depends: list[str] = []

    def merge(self, other: "Dependency") -> None:
        """Platform branches redeclare the same project; they must agree on what they fetch."""
        for field in ("url", "git_repository", "git_tag"):
            mine, theirs = getattr(self, field), getattr(other, field)
            if mine and theirs and mine != theirs:
                raise SystemExit(f"{self.name}: conflicting {field}: {mine!r} vs {theirs!r}")
            if theirs:
                setattr(self, field, theirs)
        for dependency in other.depends:
            if dependency not in self.depends:
                self.depends.append(dependency)


def split_calls(text: str, command: str) -> list[str]:
    """Argument lists of every `command(...)` in `text`, matching parens outside quotes."""
    calls = []
    for match in re.finditer(rf"\b{command}\s*\(", text, re.IGNORECASE):
        index, depth, quote = match.end(), 1, None
        while index < len(text) and depth:
            char = text[index]
            if quote:
                if char == quote:
                    quote = None
            elif char in "\"'":
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            index += 1
        calls.append(text[match.end():index - 1])
    return calls


def variables(text: str) -> dict[str, str]:
    values = {}
    for call in split_calls(text, "set"):
        try:
            tokens = shlex.split(call, comments=True)
        except ValueError:
            continue
        if len(tokens) >= 2:
            values[tokens[0]] = tokens[1]
    return values


def expand(value: str, values: dict[str, str]) -> str:
    return re.sub(r"\$\{(\w+)\}", lambda m: values.get(m.group(1), m.group(0)), value)


def parse(path: Path) -> list[Dependency]:
    text = path.read_text()
    values = variables(text)
    found = []
    for call in split_calls(text, "ExternalProject_add"):
        try:
            tokens = shlex.split(call, comments=True)
        except ValueError as error:
            raise SystemExit(f"{path}: unparseable ExternalProject_add: {error}")
        if not tokens:
            continue
        dependency = Dependency(tokens[0])
        index = 1
        while index < len(tokens):
            keyword = tokens[index]
            if keyword == "URL" and index + 1 < len(tokens):
                dependency.url = expand(tokens[index + 1], values)
            elif keyword == "GIT_REPOSITORY" and index + 1 < len(tokens):
                dependency.git_repository = expand(tokens[index + 1], values)
            elif keyword == "GIT_TAG" and index + 1 < len(tokens):
                dependency.git_tag = expand(tokens[index + 1], values)
            elif keyword == "DEPENDS":
                index += 1
                while index < len(tokens) and tokens[index] not in KEYWORDS:
                    dependency.depends.append(tokens[index])
                    index += 1
                continue
            index += 1
        found.append(dependency)
    return found


def collect() -> list[Dependency]:
    merged: dict[str, Dependency] = {}
    for path in sorted(DEPENDENCIES.glob("*/CMakeLists.txt")):
        for dependency in parse(path):
            merged.setdefault(dependency.name, Dependency(dependency.name)).merge(dependency)
    if not merged:
        raise SystemExit(f"no ExternalProject_add found under {DEPENDENCIES}")
    return [merged[name] for name in sorted(merged)]


ARCHIVE = re.compile(r"https://github\.com/([^/]+)/([^/]+)/archive/refs/tags/(.+?)\.(?:tar\.gz|zip)$")
CLONE = re.compile(r"https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$")


def identify(dependency: Dependency) -> tuple[str | None, str]:
    """The GitHub `owner/repo` carrying this dependency's licence, and the tag it is pinned to."""
    if dependency.git_repository:
        match = CLONE.match(dependency.git_repository)
        if match and dependency.git_tag:
            return f"{match.group(1)}/{match.group(2)}", dependency.git_tag
    if dependency.url:
        match = ARCHIVE.match(dependency.url)
        if match:
            return f"{match.group(1)}/{match.group(2)}", match.group(3)
    override = OVERRIDES.get(dependency.name)
    if override and dependency.url:
        version = re.search(r"-([0-9][\w.]*?)\.tar\.gz$", dependency.url)
        if version:
            return override["repo"], override["tag"].format(version=version.group(1))
    return None, dependency.git_tag or ""


def version_of(tag: str) -> str:
    """The tag with the project's prefix stripped; `cares-1_29_0` and `boost-1.85.0` both occur."""
    stripped = re.sub(r"^[A-Za-z][\w.-]*?[-_]v?(?=\d)", "", tag)
    stripped = re.sub(r"^v(?=\d)", "", stripped)
    return stripped.replace("_", ".") if re.fullmatch(r"[\d_]+", stripped) else stripped


def fetch(url: str) -> dict:
    request = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "valhalla-kmp-third-party",
    })
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def fetch_raw(repo: str, tag: str, path: str) -> tuple[str, str]:
    url = f"https://raw.githubusercontent.com/{repo}/{tag}/{path}"
    request = urllib.request.Request(url, headers={"User-Agent": "valhalla-kmp-third-party"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace"), url


def licence_of(repo: str, tag: str) -> tuple[str, str, str]:
    """SPDX id, licence text and the URL it came from, read at the pinned tag where possible."""
    for reference in (tag, None):
        url = f"https://api.github.com/repos/{repo}/license"
        if reference:
            url += f"?ref={urllib.parse.quote(reference)}"
        try:
            payload = fetch(url)
        except urllib.error.HTTPError as error:
            if error.code in (404, 422):
                continue
            raise SystemExit(f"{repo}: GitHub returned {error.code} — {error.reason}")
        spdx = (payload.get("license") or {}).get("spdx_id") or "NOASSERTION"
        text = base64.b64decode(payload.get("content", "")).decode("utf-8", "replace")
        return ("NOASSERTION" if spdx in ("NOASSERTION", "other") else spdx,
                text, payload.get("html_url") or f"https://github.com/{repo}")
    return "NOASSERTION", "", f"https://github.com/{repo}"


def resolve() -> list[dict]:
    components = []
    for dependency in collect():
        repo, tag = identify(dependency)
        if not repo:
            raise SystemExit(
                f"{dependency.name}: cannot tell where this comes from "
                f"(url={dependency.url!r}, git={dependency.git_repository!r}). "
                f"Add it to OVERRIDES.")
        spdx, text, licence_url = licence_of(repo, tag)
        declared = DECLARED.get(dependency.name)
        if declared:
            spdx = declared["spdx"]
            if "path" in declared:
                text, licence_url = fetch_raw(repo, tag, declared["path"])
        elif spdx == "NOASSERTION":
            raise SystemExit(
                f"{dependency.name}: GitHub could not classify the licence at {licence_url}. "
                f"Read it, then record the answer in DECLARED.")
        components.append({
            "name": dependency.name,
            "repo": repo,
            "tag": tag,
            "version": version_of(tag),
            "spdx": spdx,
            "text": text.strip(),
            "licence_url": licence_url,
            "source_url": dependency.url or dependency.git_repository,
            "depends": sorted(dependency.depends),
            "note": (declared or {}).get("note") or CAVEATS.get(dependency.name, ""),
        })
    return components


def sbom(components: list[dict], name: str, version: str) -> dict:
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tools": {"components": [
                {"type": "application", "name": "third_party.py", "author": "valhalla-kmp"},
            ]},
            "component": {
                "type": "library",
                "bom-ref": f"pkg:maven/ch.vautherin/{name}@{version}",
                "name": name,
                "version": version,
                "purl": f"pkg:maven/ch.vautherin/{name}@{version}",
            },
        },
        "components": [{
            "type": "library",
            "bom-ref": f"pkg:github/{c['repo']}@{c['tag']}",
            "name": c["name"],
            "version": c["version"],
            "purl": f"pkg:github/{c['repo']}@{c['tag']}",
            "scope": "required",
            # The text is carried inline, not just referenced. It is what the licences actually
            # require reproducing, and it makes this file sufficient on its own — a consumer can
            # render notices or feed an attribution UI without fetching anything.
            "licenses": [{"license": {
                "id": c["spdx"],
                "url": c["licence_url"],
                "text": {"contentType": "text/plain", "content": c["text"]},
            }}],
            "externalReferences": [
                {"type": "distribution", "url": c["source_url"]},
                {"type": "license", "url": c["licence_url"]},
                {"type": "vcs", "url": f"https://github.com/{c['repo']}"},
            ],
            **({"description": c["note"]} if c["note"] else {}),
        } for c in components],
        "dependencies": [
            {"ref": f"pkg:maven/ch.vautherin/{name}@{version}",
             "dependsOn": [f"pkg:github/{c['repo']}@{c['tag']}" for c in components]},
            *[{"ref": f"pkg:github/{c['repo']}@{c['tag']}",
               "dependsOn": [f"pkg:github/{d['repo']}@{d['tag']}"
                             for d in components if d["name"] in c["depends"]]}
              for c in components],
        ],
    }


def notices(components: list[dict], name: str) -> str:
    lines = [
        f"Third-party notices for {name}",
        "",
        "This build statically links the following components. Each is reproduced below with the",
        "licence it is distributed under, as required by those licences.",
        "",
        "Generated by tools/third_party.py from src/dependencies — do not edit by hand.",
        "",
    ]
    for component in components:
        lines += ["=" * 88, f"{component['name']} {component['version']}  ({component['spdx']})",
                  f"https://github.com/{component['repo']}  @ {component['tag']}"]
        if component["note"]:
            lines += ["", component["note"]]
        lines += ["=" * 88, "", component["text"] or "(no licence text retrieved — check manually)", ""]
    lines += [
        "=" * 88,
        "",
        "Not covered above: Valhalla is fetched with GIT_SUBMODULES_RECURSE, so its own vendored",
        "submodules are linked in but are not declared in src/dependencies and cannot be discovered",
        "from it. Enumerate them from the Valhalla source tree before relying on this file.",
        "",
    ]
    return "\n".join(lines)


def stable(document: dict) -> str:
    """Comparable form: what describes the dependencies, minus what only identifies this release of them."""
    copy = json.loads(json.dumps(document))
    copy["metadata"].pop("timestamp", None)
    component = copy["metadata"].get("component", {})
    root = component.get("bom-ref")
    component.pop("version", None)
    text = json.dumps(copy, indent=2, sort_keys=True)
    return text.replace(root, "ROOT") if root else text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="exit non-zero if the committed output is out of date")
    parser.add_argument("--name", default="valhalla-kmp")
    parser.add_argument("--version", default="0.1.0")
    parser.add_argument("--out", type=Path, default=DIST)
    args = parser.parse_args()

    components = resolve()
    document = sbom(components, args.name, args.version)
    text = notices(components, args.name)

    bom_path = args.out / "third-party.cdx.json"
    notices_path = args.out / "THIRD-PARTY-NOTICES.txt"

    if args.check:
        if not bom_path.exists() or not notices_path.exists():
            print(f"{args.out} is missing generated files; run tools/third_party.py", file=sys.stderr)
            return 1
        if (stable(json.loads(bom_path.read_text())) != stable(document)
                or notices_path.read_text() != text):
            print("third-party attribution is out of date; run tools/third_party.py", file=sys.stderr)
            return 1
        print(f"third-party attribution is up to date ({len(components)} components)")
        return 0

    args.out.mkdir(parents=True, exist_ok=True)
    bom_path.write_text(json.dumps(document, indent=2) + "\n")
    notices_path.write_text(text)

    for component in components:
        print(f"  {component['name']:10s} {component['version']:12s} {component['spdx']}")
    print(f"\nwrote {bom_path.relative_to(ROOT)} and {notices_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
