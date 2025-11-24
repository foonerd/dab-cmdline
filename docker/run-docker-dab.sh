#!/bin/bash
# foonerd-dab docker/run-docker-dab.sh
# Core Docker build logic for foonerd-dab binaries with custom RTL-SDR library selection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

VERBOSE=0
RTLSDR_SOURCE=""

# Parse arguments
PROJECT="$1"
ARCH="$2"
shift 2 || true

for arg in "$@"; do
  if [[ "$arg" == "--verbose" ]]; then
    VERBOSE=1
  elif [[ "$arg" == --rtlsdr=* ]]; then
    RTLSDR_SOURCE="${arg#*=}"
  fi
done

# Show usage if missing required parameters
if [ "$PROJECT" != "dab" ] || [ -z "$ARCH" ] || [ -z "$RTLSDR_SOURCE" ]; then
  echo "Usage: $0 dab <arch> --rtlsdr=<source> [--verbose]"
  echo ""
  echo "Arguments:"
  echo "  arch: armv6, armhf, arm64, amd64"
  echo "  --rtlsdr: osmocom or blog (REQUIRED)"
  echo "  --verbose: Show detailed build output"
  echo ""
  echo "Example:"
  echo "  $0 dab arm64 --rtlsdr=osmocom"
  echo "  $0 dab armv6 --rtlsdr=blog --verbose"
  exit 1
fi

# Validate RTLSDR_SOURCE
if [[ "$RTLSDR_SOURCE" != "osmocom" && "$RTLSDR_SOURCE" != "blog" ]]; then
  echo "Error: Invalid --rtlsdr value: $RTLSDR_SOURCE"
  echo "Must be 'osmocom' or 'blog'"
  exit 1
fi

# Locate RTL-SDR repository (sibling directory)
RTLSDR_REPO="../rtlsdr-${RTLSDR_SOURCE}"
if [ ! -d "$RTLSDR_REPO" ]; then
  echo "Error: RTL-SDR repository not found: $RTLSDR_REPO"
  echo "Expected: $(cd ..; pwd)/rtlsdr-${RTLSDR_SOURCE}"
  echo ""
  echo "Clone it first:"
  echo "  cd $(dirname "$(pwd)")"
  echo "  git clone https://github.com/foonerd/rtlsdr-${RTLSDR_SOURCE}.git"
  exit 1
fi

# Check for DEBs
RTLSDR_DEBS="$RTLSDR_REPO/out/$ARCH"
if [ ! -d "$RTLSDR_DEBS" ]; then
  echo "Error: RTL-SDR DEBs not found for $ARCH: $RTLSDR_DEBS"
  echo ""
  echo "Build them first:"
  echo "  cd $RTLSDR_REPO"
  echo "  ./build-matrix.sh"
  exit 1
fi

# Count DEBs
DEB_COUNT=$(find "$RTLSDR_DEBS" -name "*.deb" 2>/dev/null | wc -l)
if [ "$DEB_COUNT" -eq 0 ]; then
  echo "Error: No DEB files found in $RTLSDR_DEBS"
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

# Compiler triplet mappings
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
echo "Building foonerd-dab for $ARCH"
echo "========================================"
echo "  Platform: $PLATFORM"
echo "  RTL-SDR Source: $RTLSDR_SOURCE"
echo "  RTL-SDR DEBs: $RTLSDR_DEBS ($DEB_COUNT files)"
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

# Special CXXFLAGS for ARM architectures
EXTRA_CXXFLAGS=""
if [[ "$ARCH" == "armv6" ]]; then
  EXTRA_CXXFLAGS="-march=armv6 -mfpu=vfp -mfloat-abi=hard -marm"
elif [[ "$ARCH" == "armhf" ]]; then
  EXTRA_CXXFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard"
fi

# Absolute path to DEBs for mounting
ABS_RTLSDR_DEBS="$(cd "$RTLSDR_DEBS" && pwd)"

# Run build inside container with DEBs mounted
echo "[+] Running build inside container..."
if [[ "$VERBOSE" -eq 1 ]]; then
  docker run --rm --platform=$PLATFORM \
    -v "$(pwd)/source:/build/source:ro" \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    -v "$ABS_RTLSDR_DEBS:/debs:ro" \
    -e "ARCH=$ARCH" \
    -e "TRIPLET=$TRIPLET" \
    -e "PROCESSOR=$PROCESSOR" \
    -e "EXTRA_CXXFLAGS=$EXTRA_CXXFLAGS" \
    -e "RTLSDR_SOURCE=$RTLSDR_SOURCE" \
    "$IMAGE_NAME" \
    bash /build/scripts/build-binaries.sh
else
  docker run --rm --platform=$PLATFORM \
    -v "$(pwd)/source:/build/source:ro" \
    -v "$(pwd)/scripts:/build/scripts:ro" \
    -v "$(pwd)/$OUTPUT_DIR:/build/output" \
    -v "$ABS_RTLSDR_DEBS:/debs:ro" \
    -e "ARCH=$ARCH" \
    -e "TRIPLET=$TRIPLET" \
    -e "PROCESSOR=$PROCESSOR" \
    -e "EXTRA_CXXFLAGS=$EXTRA_CXXFLAGS" \
    -e "RTLSDR_SOURCE=$RTLSDR_SOURCE" \
    "$IMAGE_NAME" \
    bash /build/scripts/build-binaries.sh 2>&1 | grep -E "^\[|^Error|^Building"
fi

echo ""
echo "[+] Build complete for $ARCH"
echo "[+] Binaries in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
