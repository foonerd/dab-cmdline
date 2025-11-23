#!/bin/bash
# volumio-rtlsdr-binaries docker/run-docker-dab.sh
# Core Docker build logic for dab-cmdline binaries
# Pattern based on volumio-mpd-core and cdspeedctl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

VERBOSE=0
if [[ "$3" == "--verbose" ]]; then
  VERBOSE=1
fi

# Parse arguments
PROJECT="$1"
ARCH="$2"

if [ "$PROJECT" != "dab" ]; then
  echo "Usage: $0 dab <arch> [--verbose]"
  echo "  arch: armv6, armhf, arm64, amd64"
  exit 1
fi

if [ -z "$ARCH" ]; then
  echo "Error: Architecture not specified"
  echo "Usage: $0 dab <arch> [--verbose]"
  exit 1
fi

# Platform mappings for Docker
declare -A PLATFORM_MAP
PLATFORM_MAP=(
  ["armv6"]="linux/arm/v7"
  ["armhf"]="linux/arm/v7"
  ["arm64"]="linux/arm64"
  ["amd64"]="linux/amd64"
)

# Compiler triplet mappings for explicit cross-compilation specification
declare -A COMPILER_TRIPLET
COMPILER_TRIPLET=(
  ["armv6"]="arm-linux-gnueabihf"
  ["armhf"]="arm-linux-gnueabihf"
  ["arm64"]="aarch64-linux-gnu"
  ["amd64"]="x86_64-linux-gnu"
)

# CMake system processor mappings
declare -A CMAKE_PROCESSOR
CMAKE_PROCESSOR=(
  ["armv6"]="armv6"
  ["armhf"]="armv7"
  ["arm64"]="aarch64"
  ["amd64"]="x86_64"
)

# Validate architecture
if [[ -z "${PLATFORM_MAP[$ARCH]}" ]]; then
  echo "Error: Unknown architecture: $ARCH"
  echo "Supported: armv6, armhf, arm64, amd64"
  exit 1
fi

PLATFORM="${PLATFORM_MAP[$ARCH]}"
TRIPLET="${COMPILER_TRIPLET[$ARCH]}"
PROCESSOR="${CMAKE_PROCESSOR[$ARCH]}"
DOCKERFILE="docker/Dockerfile.dab.$ARCH"
IMAGE_NAME="volumio-dab-builder:$ARCH"
OUTPUT_DIR="out/$ARCH"

if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile not found: $DOCKERFILE"
  exit 1
fi

echo "========================================"
echo "Building dab-cmdline for $ARCH"
echo "========================================"
echo "  Platform: $PLATFORM"
echo "  Dockerfile: $DOCKERFILE"
echo "  Image: $IMAGE_NAME"
echo "  Output: $OUTPUT_DIR"
echo ""

# Build Docker image with platform flag
echo "[+] Building Docker image..."
if [[ "$VERBOSE" -eq 1 ]]; then
  DOCKER_BUILDKIT=1 docker build --platform=$PLATFORM --progress=plain -t "$IMAGE_NAME" -f "$DOCKERFILE" .
else
  docker build --platform=$PLATFORM --progress=auto -t "$IMAGE_NAME" -f "$DOCKERFILE" . > /dev/null 2>&1
fi
echo "[+] Docker image built: $IMAGE_NAME"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run build in container with platform flag and arch-specific flags
echo "[+] Running build in container..."
if [[ "$ARCH" == "armv6" ]]; then
  docker run --rm --platform=$PLATFORM \
    -e CMAKE_TRIPLET="$TRIPLET" \
    -e CMAKE_PROCESSOR="$PROCESSOR" \
    -v "$(pwd)/source:/build/source" \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    "$IMAGE_NAME" \
    bash -c '\
      export CXXFLAGS="-O2 -march=armv6 -mfpu=vfp -mfloat-abi=hard -marm -std=c++11" && \
      export CFLAGS="$CXXFLAGS" && \
      bash /build/scripts/build-binaries.sh armv6'
else
  docker run --rm --platform=$PLATFORM \
    -e CMAKE_TRIPLET="$TRIPLET" \
    -e CMAKE_PROCESSOR="$PROCESSOR" \
    -v "$(pwd)/source:/build/source" \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    "$IMAGE_NAME" \
    bash -c '\
      export CXXFLAGS="-O2 -std=c++11" && \
      export CFLAGS="$CXXFLAGS" && \
      bash /build/scripts/build-binaries.sh '"$ARCH"
fi

echo ""
echo "[+] Build complete for $ARCH"
echo ""
echo "Output binaries:"
ls -lh "$OUTPUT_DIR"
echo ""
