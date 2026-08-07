# Valhalla-Android

Valhalla and its C/C++ dependencies, cross-compiled for Android and iOS, with a Kotlin Multiplatform wrapper in
`kmp/valhalla` published as `ch.vautherin:valhalla`.

## Licence

The wrapper is [MPL-2.0](LICENSE). Its copyleft is file-level: embedding the library in a closed application is
fine, but changes to these files must be published.

The native libraries linked into the published binaries keep their own licences — Valhalla is MIT, boost
BSL-1.0, OpenSSL Apache-2.0 — and every one of them is reproduced in the attribution artifacts below.

## Attribution

The native libraries are statically linked into the published binaries. They are real dependencies with real
licence obligations, but they arrive through CMake rather than Gradle, so nothing in a consumer's dependency
graph mentions them. Two artifacts are published alongside the library to close that gap:

| classifier | file | contents |
| --- | --- | --- |
| `cyclonedx` | `valhalla-<version>-cyclonedx.json` | CycloneDX SBOM of the native tree, with full licence texts |
| `third-party-notices` | `valhalla-<version>-third-party-notices.txt` | the same licences as flat text |

Neither is resolved automatically — Gradle fetches a classifier artifact only when asked:

```kotlin
val nativeSbom by configurations.creating { isTransitive = false }

dependencies {
    nativeSbom("ch.vautherin:valhalla:0.1.0") {
        artifact { name = "valhalla"; type = "json"; classifier = "cyclonedx"; extension = "json" }
    }
}
```

The SBOM is a normal CycloneDX document, so anything that reads CycloneDX will consume it — an attribution
generator, a vulnerability scanner, a licence audit.

### Where the data comes from

There is no package manager to interrogate: the `ExternalProject_add` calls in `src/dependencies/*/CMakeLists.txt`
*are* the dependency manifest. `tools/third_party.py` parses them, resolves each library's licence from GitHub,
and writes both files into `dist/`:

```
tools/third_party.py            # regenerate dist/
tools/third_party.py --check    # fail if dist/ has drifted from src/dependencies
```

A handful of licences cannot be determined automatically and are declared in a reviewed table in that script —
lz4 is dual-licensed and only `lib/` is BSD-2-Clause, and valhalla's `LICENSE.md` is a pointer to `COPYING`
rather than a licence. The script refuses to emit `NOASSERTION`, so a new dependency whose licence it cannot
establish fails the run rather than shipping an unattributed component.

`dist/` is committed rather than built, so `checkThirdParty` runs before any publish task. A stale SBOM is worse
than none: it is asserted, published under a version, and cannot be withdrawn.
