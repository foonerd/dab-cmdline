#!/bin/bash
# foonerd-dab scripts/build-binaries.sh
# Build script for foonerd-dab binaries (fn-dab, fn-dab-scanner)
# Runs inside Docker container

set -e

echo "[+] Starting foonerd-dab build"
echo "[+] Architecture: $ARCH"
echo "[+] Processor: $PROCESSOR"
echo "[+] RTL-SDR Source: $RTLSDR_SOURCE"
echo "[+] Extra CXXFLAGS: $EXTRA_CXXFLAGS"
echo ""

# Install custom RTL-SDR library from mounted DEBs
echo "[+] Installing RTL-SDR DEBs from /debs..."
DEB_COUNT=$(ls /debs/*.deb 2>/dev/null | wc -l)
if [ "$DEB_COUNT" -eq 0 ]; then
  echo "Error: No DEB files found in /debs"
  exit 1
fi

dpkg -i /debs/*.deb || true
apt-get install -f -y

# Verify installation
if ! pkg-config --exists libfn-rtlsdr; then
  echo "Error: libfn-rtlsdr not found after DEB installation"
  echo "Available packages:"
  dpkg -l | grep rtlsdr
  exit 1
fi

echo "[+] RTL-SDR library installed:"
pkg-config --modversion libfn-rtlsdr
pkg-config --cflags libfn-rtlsdr
pkg-config --libs libfn-rtlsdr
echo ""

# Create build directories
BUILD_DAB="/build/build-dab"
BUILD_SCANNER="/build/build-scanner"
OUTPUT="/build/output"

mkdir -p "$BUILD_DAB"
mkdir -p "$BUILD_SCANNER"
mkdir -p "$OUTPUT"

#
# Build fn-dab-rtlsdr (DAB/DAB+ decoder with DLS/MOT support)
#
echo "[+] Building fn-dab..."
cd "$BUILD_DAB"

if [[ "$ARCH" == "arm64" ]]; then
  # arm64 needs explicit library paths due to broken FindModule
  cmake /build/source/foonerd-dab \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_PROCESSOR="$PROCESSOR" \
    -DCMAKE_CXX_FLAGS="$EXTRA_CXXFLAGS" \
    -DRTLSDR_INCLUDE_DIR=/usr/include \
    -DRTLSDR_LIBRARY=/usr/lib/aarch64-linux-gnu/libfn-rtlsdr.so \
    -DFFTW3F_INCLUDE_DIR=/usr/include \
    -DFFTW3F_LIBRARY=/usr/lib/aarch64-linux-gnu/libfftw3f.so \
    -DFAAD_INCLUDE_DIR=/usr/include \
    -DFAAD_LIBRARY=/usr/lib/aarch64-linux-gnu/libfaad.so \
    -DSAMPLERATE_INCLUDE_DIR=/usr/include \
    -DSAMPLERATE_LIBRARY=/usr/lib/aarch64-linux-gnu/libsamplerate.so \
    -DSNDFILE_INCLUDE_DIR=/usr/include \
    -DSNDFILE_LIBRARY=/usr/lib/aarch64-linux-gnu/libsndfile.so \
    -DUSB_INCLUDE_DIR=/usr/include \
    -DUSB_LIBRARY=/usr/lib/aarch64-linux-gnu/libusb-1.0.so \
    -DPORTAUDIO_INCLUDE_DIR=/usr/include \
    -DPORTAUDIO_LIBRARY=/usr/lib/aarch64-linux-gnu/libportaudio.so
else
  # Other architectures use standard CMake
  cmake /build/source/foonerd-dab \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_PROCESSOR="$PROCESSOR" \
    -DCMAKE_CXX_FLAGS="$EXTRA_CXXFLAGS"
fi

make -j$(nproc)
strip fn-dab-rtlsdr
mv fn-dab-rtlsdr "$OUTPUT/fn-dab"

echo "[+] fn-dab built: $(ls -lh $OUTPUT/fn-dab | awk '{print $5}')"

#
# Build fn-dab-scanner (DAB channel scanner)
#
echo "[+] Building fn-dab-scanner..."
cd "$BUILD_SCANNER"

if [[ "$ARCH" == "arm64" ]]; then
  cmake /build/source/foonerd-dab-scanner \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_PROCESSOR="$PROCESSOR" \
    -DCMAKE_CXX_FLAGS="$EXTRA_CXXFLAGS" \
    -DRTLSDR_INCLUDE_DIR=/usr/include \
    -DRTLSDR_LIBRARY=/usr/lib/aarch64-linux-gnu/libfn-rtlsdr.so \
    -DFFTW3F_INCLUDE_DIR=/usr/include \
    -DFFTW3F_LIBRARY=/usr/lib/aarch64-linux-gnu/libfftw3f.so \
    -DUSB_INCLUDE_DIR=/usr/include \
    -DUSB_LIBRARY=/usr/lib/aarch64-linux-gnu/libusb-1.0.so
else
  cmake /build/source/foonerd-dab-scanner \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_PROCESSOR="$PROCESSOR" \
    -DCMAKE_CXX_FLAGS="$EXTRA_CXXFLAGS"
fi

make -j$(nproc)
strip fn-dab-scanner
mv fn-dab-scanner "$OUTPUT/fn-dab-scanner"

echo "[+] fn-dab-scanner built: $(ls -lh $OUTPUT/fn-dab-scanner | awk '{print $5}')"

echo "[+] Build complete"
ls -lh "$OUTPUT"
