#!/bin/bash
# volumio-rtlsdr-binaries clean-all.sh
# Remove all build artifacts and output binaries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Cleaning volumio-rtlsdr-binaries"
echo "========================================"
echo ""

# Remove source directory
if [ -d "source" ]; then
  echo "[+] Removing source/"
  rm -rf source
fi

# Remove build directory
if [ -d "build" ]; then
  echo "[+] Removing build/"
  rm -rf build
fi

# Remove output binaries
if [ -d "out" ]; then
  echo "[+] Removing out/ binaries"
  rm -f out/armv6/dab-rtlsdr-3
  rm -f out/armv6/dab-scanner-3
  rm -f out/armhf/dab-rtlsdr-3
  rm -f out/armhf/dab-scanner-3
  rm -f out/arm64/dab-rtlsdr-3
  rm -f out/arm64/dab-scanner-3
  rm -f out/amd64/dab-rtlsdr-3
  rm -f out/amd64/dab-scanner-3
fi

echo ""
echo "Clean complete"
