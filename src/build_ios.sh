#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configurable ──────────────────────────────────────────────────────────────
BUILD_TYPE="${BUILD_TYPE:-Release}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-16.3}"
BUILD_DIR="${script_dir}/build/ios"
INSTALL_DIR="${script_dir}/install/ios"
TOOLCHAIN_FILE="${script_dir}/cmake/ios.toolchain.cmake"
FRAMEWORK_NAME="ValhallaCAPI"
XCFRAMEWORK_DIR="${INSTALL_DIR}/${FRAMEWORK_NAME}.xcframework"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "==> $*"; }

die() { echo "ERROR: $*" >&2; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  die "This script must be run on macOS."
fi

if ! command -v xcodebuild &>/dev/null; then
  die "Xcode command-line tools not found. Run: xcode-select --install"
fi

if [[ ! -f "${TOOLCHAIN_FILE}" ]]; then
  die "iOS toolchain not found at: ${TOOLCHAIN_FILE}"
fi

if [[ -d "${XCFRAMEWORK_DIR}" ]]; then
  die "Output already exists: ${XCFRAMEWORK_DIR} — please remove it before re-running."
fi

# ── Step 1: Host dependencies (e.g. protoc) ───────────────────────────────────
HOST_INSTALL_DIR="${BUILD_DIR}/host/install"

if [[ ! -f "${HOST_INSTALL_DIR}/bin/protoc" ]]; then
  log "Building host dependencies..."
  cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${HOST_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${HOST_INSTALL_DIR}" \
    -B "${BUILD_DIR}/host" \
    -S "${script_dir}/host-dependencies"
  cmake --build "${BUILD_DIR}/host" -j"$(sysctl -n hw.ncpu)"
else
  log "Host dependencies already built, skipping."
fi

HOST_PROTOC="${HOST_INSTALL_DIR}/bin/protoc"

# ── Step 2: Cross-compile for each iOS platform ───────────────────────────────
# name       | PLATFORM          | SDK
# -----------|-------------------|---------------
# device     | OS64              | iphoneos
# sim-x64    | SIMULATOR64       | iphonesimulator
# sim-arm64  | SIMULATORARM64    | iphonesimulator

for target in device sim-arm64; do
  case "$target" in
    device)    PLATFORM="OS64";           SDK="iphoneos"       ;;
    sim-arm64) PLATFORM="SIMULATORARM64"; SDK="iphonesimulator" ;;
  esac

  TARGET_BUILD_DIR="${BUILD_DIR}/${target}"
  TARGET_INSTALL_DIR="${INSTALL_DIR}/${target}"

  export SDKROOT
  SDKROOT="$(xcrun --sdk "${SDK}" --show-sdk-path)"

  # ── Step 2a: Dependencies ──────────────────────────────────────────────────
  DEPS_INSTALL_DIR="${TARGET_BUILD_DIR}/dependencies/install"
  DEPS_DONE_MARKER="${DEPS_INSTALL_DIR}/lib/libvalhalla.a"

  if [[ ! -f "${DEPS_DONE_MARKER}" ]]; then
    log "[${target}] Building dependencies..."
    cmake \
      -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
      -DPLATFORM="${PLATFORM}" \
      -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
      -DENABLE_BITCODE=OFF \
      -DENABLE_STRICT_TRY_COMPILE=ON \
      -DCMAKE_PREFIX_PATH="${DEPS_INSTALL_DIR}" \
      -DCMAKE_INSTALL_PREFIX="${DEPS_INSTALL_DIR}" \
      -DHOST_PROTOC_EXECUTABLE="${HOST_PROTOC}" \
      -B "${TARGET_BUILD_DIR}/dependencies" \
      -S "${script_dir}/dependencies"
    cmake --build "${TARGET_BUILD_DIR}/dependencies" -j"$(sysctl -n hw.ncpu)"
  else
    log "[${target}] Dependencies already built, skipping."
  fi

  # ── Step 2b: Main library ──────────────────────────────────────────────────
  log "[${target}] Building main library..."
  cmake \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DPLATFORM="${PLATFORM}" \
    -DDEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
    -DENABLE_BITCODE=OFF \
    -DENABLE_STRICT_TRY_COMPILE=ON \
    -DCMAKE_PREFIX_PATH="${DEPS_INSTALL_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${TARGET_INSTALL_DIR}" \
    -B "${TARGET_BUILD_DIR}/main" \
    -S "${script_dir}/main"
  cmake --build "${TARGET_BUILD_DIR}/main" -j"$(sysctl -n hw.ncpu)"
  cmake --install "${TARGET_BUILD_DIR}/main"

  # ── Step 2c: Merge all static libs into one .a ─────────────────────────────
  log "[${target}] Merging static libraries..."

  libtool -static -o "${TARGET_INSTALL_DIR}/lib/${FRAMEWORK_NAME}.a" \
    "${DEPS_INSTALL_DIR}"/lib/*.a \
    "${TARGET_INSTALL_DIR}"/lib/*.a

  log "[${target}] Done: ${TARGET_INSTALL_DIR}/lib/${FRAMEWORK_NAME}.a"
done

log "Done! Static libraries at:"
log "  ${INSTALL_DIR}/device/lib/${FRAMEWORK_NAME}.a"
log "  ${INSTALL_DIR}/sim-arm64/lib/${FRAMEWORK_NAME}.a"
