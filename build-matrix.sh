#!/bin/bash
# volumio-rtlsdr-binaries build-matrix.sh
# Builds dab-cmdline binaries for all supported architectures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERBOSE=""
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  VERBOSE="--verbose"
fi

echo "========================================"
echo "foonerd-dab build matrix"
echo "========================================"
echo ""

# Verify cherry-picked source exists
if [ ! -d "source/foonerd-dab" ]; then
  echo "[!] Source not found: source/foonerd-dab"
  echo "[!] Cherry-pick source files first"
  exit 1
fi

if [ ! -d "source/foonerd-dab-scanner" ]; then
  echo "[!] Source not found: source/foonerd-dab-scanner"
  echo "[!] Cherry-pick source files first"
  exit 1
fi

# Build all architectures
ARCHS="armv6 armhf arm64 amd64"

for ARCH in $ARCHS; do
  echo "[+] Building for: $ARCH"
  ./docker/run-docker-dab.sh dab $ARCH $VERBOSE
  echo ""
done

echo "========================================"
echo "Build matrix complete"
echo "========================================"
echo ""
echo "Output binaries:"
for ARCH in $ARCHS; do
  echo "  out/$ARCH/"
  if [ -f "out/$ARCH/fn-dab" ]; then
    SIZE=$(stat -f%z "out/$ARCH/fn-dab" 2>/dev/null || stat -c%s "out/$ARCH/fn-dab" 2>/dev/null || echo "?")
    echo "    fn-dab ($SIZE bytes)"
  fi
  if [ -f "out/$ARCH/fn-dab-scanner" ]; then
    SIZE=$(stat -f%z "out/$ARCH/fn-dab-scanner" 2>/dev/null || stat -c%s "out/$ARCH/fn-dab-scanner" 2>/dev/null || echo "?")
    echo "    fn-dab-scanner ($SIZE bytes)"
  fi
done
echo ""
