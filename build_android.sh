#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build_android.sh [options]

Options:
  -a, --abi <abi>          Target ANDROID_ABI (default: arm64-v8a)
  -p, --platform <level>   Target ANDROID_PLATFORM (default: android-29)
  -v, --version <tag>      Git tag or revision to build (default: latest tag)
  -h, --help               Show this help message
EOF
}

ABI="arm64-v8a"
PLATFORM="android-29"
REQUESTED_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--abi)
      [[ $# -lt 2 ]] && { usage; exit 1; }
      ABI="$2"
      shift 2
      ;;
    -p|--platform)
      [[ $# -lt 2 ]] && { usage; exit 1; }
      PLATFORM="$2"
      shift 2
      ;;
    -v|--version)
      [[ $# -lt 2 ]] && { usage; exit 1; }
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

: "${OPUS_NDK:?Please set OPUS_NDK to the Android NDK directory.}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/opus/.git" ]]; then
  REPO_DIR="$SCRIPT_DIR/opus"
elif [[ -d "$SCRIPT_DIR/.git" ]]; then
  REPO_DIR="$SCRIPT_DIR"
else
  echo "Unable to locate opus git repository relative to $SCRIPT_DIR" >&2
  exit 1
fi

cd "$REPO_DIR"
if ! git fetch --tags --quiet >/dev/null 2>&1; then
  echo "Warning: Unable to fetch tags from remote, falling back to local tags." >&2
fi

if [[ -z "$REQUESTED_VERSION" ]]; then
  if ! REQUESTED_VERSION="$(git describe --tags "$(git rev-list --tags --max-count=1)")"; then
    echo "Unable to determine the latest tag. Please specify --version." >&2
    exit 1
  fi
fi
VERSION_SAFE="${REQUESTED_VERSION//[^A-Za-z0-9._-]/_}"
SUFFIX="${ABI}-${PLATFORM}-${VERSION_SAFE}"

TMP_SRC_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opus-src-XXXXXX")"
cleanup() {
  rm -rf "$TMP_SRC_DIR"
}
trap cleanup EXIT

if ! git archive "$REQUESTED_VERSION" | tar -x -C "$TMP_SRC_DIR"; then
  echo "Failed to materialize sources for $REQUESTED_VERSION" >&2
  exit 1
fi

OPUS_SRC_DIR="$TMP_SRC_DIR"
BUILD_DIR="$OPUS_SRC_DIR/build-android-${SUFFIX}"
DIST_DIR="$SCRIPT_DIR/dist/${SUFFIX}"

mkdir -p "$BUILD_DIR"

cmake -S "$OPUS_SRC_DIR" -B "$BUILD_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$OPUS_NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="$PLATFORM" \
  -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
  -DOPUS_BUILD_SHARED_LIBRARY=ON \
  -DOPUS_BUILD_PROGRAMS=OFF \
  -DOPUS_BUILD_TESTING=OFF

cmake --build "$BUILD_DIR" --config Release

# 收集头文件和so
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/include"
cp -R "$OPUS_SRC_DIR/include/"* "$DIST_DIR/include/"
rm -f "$DIST_DIR/include/meson.build"

mkdir -p "$DIST_DIR/lib/$ABI"
cp "$BUILD_DIR/libopus.so" "$DIST_DIR/lib/$ABI/"

echo "Done. Version: $REQUESTED_VERSION. Output in: $DIST_DIR"
