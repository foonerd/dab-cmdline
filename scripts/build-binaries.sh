#!/bin/bash
# foonerd-dab build-binaries.sh
# Builds fn-dab and fn-dab-scanner binaries for specified architecture
# Source: Clean cherry-picked code, NO PATCHING REQUIRED

set -e

ARCH="$1"
if [ -z "$ARCH" ]; then
  echo "Usage: $0 <arch>"
  echo "  arch: armv6, armhf, arm64, amd64"
  exit 1
fi

echo "========================================"
echo "Building foonerd-dab binaries for $ARCH"
echo "========================================"
echo ""

SOURCE_DIR="/build/source/foonerd-dab"
SCANNER_DIR="/build/source/foonerd-dab-scanner"
BUILD_DIR="/build/build"
OUTPUT_DIR="/build/output"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "[!] Source directory not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

echo "    CXXFLAGS: $CXXFLAGS"
echo "    CMAKE_TRIPLET: $CMAKE_TRIPLET"
echo "    CMAKE_PROCESSOR: $CMAKE_PROCESSOR"
echo ""

# Build fn-dab-rtlsdr
echo "[+] Building fn-dab-rtlsdr..."
mkdir -p "$BUILD_DIR/dab"
cd "$BUILD_DIR/dab"

if [ "$ARCH" = "arm64" ]; then
  cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_PROCESSOR" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DRTLSDR=ON \
    -DFFTW3F_INCLUDE_DIR=/usr/include \
    -DFFTW3F_LIBRARIES=/usr/lib/aarch64-linux-gnu/libfftw3f.so \
    -DFAAD_INCLUDE_DIR=/usr/include \
    -DFAAD_LIBRARY=/usr/lib/aarch64-linux-gnu/libfaad.so \
    -DLIBSAMPLERATE_INCLUDE_DIR=/usr/include \
    -DLIBSAMPLERATE_LIBRARY=/usr/lib/aarch64-linux-gnu/libsamplerate.so \
    -DPORTAUDIO_INCLUDE_DIR=/usr/include \
    -DPORTAUDIO_LIBRARIES=/usr/lib/aarch64-linux-gnu/libportaudio.so \
    -DRTLSDR_INCLUDE_DIR=/usr/include \
    -DRTLSDR_LIBRARY=/usr/lib/aarch64-linux-gnu/librtlsdr.so \
    -DLIBSNDFILE_INCLUDE_DIR=/usr/include \
    -DLIBSNDFILE_LIBRARY=/usr/lib/aarch64-linux-gnu/libsndfile.so \
    -DZLIB_INCLUDE_DIR=/usr/include \
    -DZLIB_LIBRARY=/usr/lib/aarch64-linux-gnu/libz.so \
    -DPTHREADS=/usr/lib/aarch64-linux-gnu/libpthread.so
else
  cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_PROCESSOR" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DRTLSDR=ON
fi

if [ $? -ne 0 ]; then
  echo "[!] CMake configuration failed for fn-dab-rtlsdr"
  exit 1
fi

make -j$(nproc)
if [ $? -ne 0 ]; then
  echo "[!] Build failed for fn-dab-rtlsdr"
  exit 1
fi

strip fn-dab-rtlsdr
cp fn-dab-rtlsdr "$OUTPUT_DIR/fn-dab"
SIZE=$(stat -c%s "$OUTPUT_DIR/fn-dab")
echo "    Built: fn-dab ($SIZE bytes)"
echo ""

# Build fn-dab-scanner
echo "[+] Building fn-dab-scanner..."
mkdir -p "$BUILD_DIR/scanner"
cd "$BUILD_DIR/scanner"

if [ "$ARCH" = "arm64" ]; then
  cmake "$SCANNER_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_PROCESSOR" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DRTLSDR=ON \
    -DFFTW3F_INCLUDE_DIR=/usr/include \
    -DFFTW3F_LIBRARIES=/usr/lib/aarch64-linux-gnu/libfftw3f.so \
    -DFAAD_INCLUDE_DIR=/usr/include \
    -DFAAD_LIBRARY=/usr/lib/aarch64-linux-gnu/libfaad.so \
    -DRTLSDR_INCLUDE_DIR=/usr/include \
    -DRTLSDR_LIBRARY=/usr/lib/aarch64-linux-gnu/librtlsdr.so \
    -DLIBSNDFILE_INCLUDE_DIR=/usr/include \
    -DLIBSNDFILE_LIBRARY=/usr/lib/aarch64-linux-gnu/libsndfile.so \
    -DZLIB_INCLUDE_DIR=/usr/include \
    -DZLIB_LIBRARY=/usr/lib/aarch64-linux-gnu/libz.so \
    -DPTHREADS=/usr/lib/aarch64-linux-gnu/libpthread.so
else
  cmake "$SCANNER_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_PROCESSOR" \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
    -DRTLSDR=ON
fi

if [ $? -ne 0 ]; then
  echo "[!] CMake configuration failed for fn-dab-scanner"
  exit 1
fi

make -j$(nproc)
if [ $? -ne 0 ]; then
  echo "[!] Build failed for fn-dab-scanner"
  exit 1
fi

strip fn-dab-scanner
cp fn-dab-scanner "$OUTPUT_DIR/"
SIZE=$(stat -c%s "$OUTPUT_DIR/fn-dab-scanner")
echo "    Built: fn-dab-scanner ($SIZE bytes)"
echo ""

echo "========================================"
echo "Build complete for $ARCH"
echo "========================================"
echo ""
echo "Output binaries in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
echo ""
