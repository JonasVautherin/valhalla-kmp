#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

# ── Source (build_ios.sh output) ──────────────────────────────────────────────
INSTALL_DIR="${script_dir}/install/ios"
FRAMEWORK_NAME="ValhallaCAPI"

# ── Destination (KMP project) ────────────────────────────────────────────────
CINTEROP_DIR="${repo_root}/kmp/valhalla/src/nativeInterop/cinterop"

log() { echo "==> $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# ── Sanity checks ────────────────────────────────────────────────────────────
for target in device sim-arm64; do
  lib="${INSTALL_DIR}/${target}/lib/${FRAMEWORK_NAME}.a"
  header="${INSTALL_DIR}/${target}/include/valhalla_capi.h"
  [[ -f "${lib}" ]]    || die "Missing ${lib} — run build_ios.sh first."
  [[ -f "${header}" ]] || die "Missing ${header} — run build_ios.sh first."
done

# ── Copy build targets into KMP cinterop directories ─────────────────────────
for target in device sim-arm64; do
  case "$target" in
    device)    dir="ios-device"            ;;
    sim-arm64) dir="ios-simulator-arm64"   ;;
  esac

  dest="${CINTEROP_DIR}/${dir}"

  log "Copying ${target} → ${dest}"

  cp "${INSTALL_DIR}/${target}/lib/${FRAMEWORK_NAME}.a"  "${dest}/lib/"
  cp "${INSTALL_DIR}/${target}/include/valhalla_capi.h"  "${dest}/include/"
done

log "Done! iOS libraries installed into KMP project."
log ""
for dir in ios-device ios-simulator-arm64; do
  echo "  ${CINTEROP_DIR}/${dir}/lib/${FRAMEWORK_NAME}.a"
done
