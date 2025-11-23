#!/bin/bash
# foonerd-dab build-matrix.sh
# Build foonerd-dab binaries for all architectures with specified RTL-SDR source

set -e

VERBOSE=""
RTLSDR_SOURCE=""

# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--verbose" ]]; then
    VERBOSE="--verbose"
  elif [[ "$arg" == --rtlsdr=* ]]; then
    RTLSDR_SOURCE="$arg"
  fi
done

# Require --rtlsdr flag
if [ -z "$RTLSDR_SOURCE" ]; then
  echo "Usage: $0 --rtlsdr=<source> [--verbose]"
  echo ""
  echo "Arguments:"
  echo "  --rtlsdr: osmocom or blog (REQUIRED)"
  echo "  --verbose: Show detailed build output"
  echo ""
  echo "Example:"
  echo "  $0 --rtlsdr=osmocom"
  echo "  $0 --rtlsdr=blog --verbose"
  exit 1
fi

echo "========================================"
echo "foonerd-dab Build Matrix"
echo "========================================"
echo "RTL-SDR Source: ${RTLSDR_SOURCE#*=}"
echo ""

# Check source directories
if [ ! -d "source/foonerd-dab" ]; then
  echo "Error: source/foonerd-dab not found"
  exit 1
fi

if [ ! -d "source/foonerd-dab-scanner" ]; then
  echo "Error: source/foonerd-dab-scanner not found"
  exit 1
fi

# Build for all architectures
ARCHITECTURES=("armv6" "armhf" "arm64" "amd64")

for ARCH in "${ARCHITECTURES[@]}"; do
  echo ""
  echo "----------------------------------------"
  echo "Building for: $ARCH"
  echo "----------------------------------------"
  ./docker/run-docker-dab.sh dab $ARCH $RTLSDR_SOURCE $VERBOSE
done

echo ""
echo "========================================"
echo "Build Matrix Complete"
echo "========================================"
echo ""
echo "Output structure:"
for ARCH in "${ARCHITECTURES[@]}"; do
  if [ -d "out/$ARCH" ]; then
    echo "  out/$ARCH/"
    ls -lh "out/$ARCH/" | tail -n +2 | awk '{printf "    %s  %s\n", $9, $5}'
  fi
done

echo ""
echo "Binaries: fn-dab, fn-dab-scanner"
echo "RTL-SDR: ${RTLSDR_SOURCE#*=}"
