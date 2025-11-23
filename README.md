# foonerd-dab

fooNerd custom build of DAB/DAB+ decoder with PCM format detection and metadata support.

## Attribution

- **Author**: fooNerd (Just a Nerd)
- **Source**: Cherry-picked from [dab-cmdline](https://github.com/JvanKatwijk/dab-cmdline) example-3
- **Build System**: Based on volumio-rtlsdr-binaries (proven working)
- **License**: GPL-2.0 (matching upstream)

## Features

- **PCM Format Detection**: Outputs `PCM: rate=X stereo=Y` to stderr for dynamic resampling
- **DLS Text Support**: Dynamic Label Segment (artist/title metadata)
- **MOT Slideshow Support**: Album artwork extraction from DAB broadcasts
- **Clean Source**: NO sed patches - all modifications made directly in source files
- **Multi-Architecture**: armv6, armhf, arm64, amd64

## Binary Names

- **fn-dab** - DAB/DAB+ decoder (replaces dab-rtlsdr-3)
- **fn-dab-scanner** - DAB channel scanner (replaces dab-scanner-3)

## Supported Architectures

- **armv6** - Raspberry Pi Zero, Pi 1 (ARMv6 hard-float)
- **armhf** - Raspberry Pi 2, Pi 3 (ARMv7)
- **arm64** - Raspberry Pi 3, Pi 4, Pi 5 (64-bit)
- **amd64** - x86/x64 systems

## Build Instructions

### Prerequisites

1. Clone required repositories as siblings:
```bash
cd ~/projects
git clone https://github.com/foonerd/rtlsdr-osmocom.git
# OR
git clone https://github.com/foonerd/rtlsdr-blog.git

git clone https://github.com/foonerd/foonerd-dab.git
```

2. Build RTL-SDR library DEBs first:
```bash
cd rtlsdr-osmocom  # or rtlsdr-blog
./build-matrix.sh
```

3. Verify DEBs exist:
```bash
ls out/*/
# Should show libfn-rtlsdr0_*.deb, libfn-rtlsdr-dev_*.deb, foonerd-rtlsdr_*.deb
```

### Build All Architectures

```bash
cd foonerd-dab
./build-matrix.sh --rtlsdr=osmocom
```

Or for rtlsdr-blog variant:
```bash
./build-matrix.sh --rtlsdr=blog
```

### Build Single Architecture

```bash
./docker/run-docker-dab.sh dab arm64 --rtlsdr=osmocom
./docker/run-docker-dab.sh dab armv6 --rtlsdr=blog --verbose
```

### Clean Build Artifacts

```bash
./clean-all.sh
```

## RTL-SDR Source Selection

The `--rtlsdr` flag selects which RTL-SDR library variant to link against:

- `--rtlsdr=osmocom` - Uses osmocom/rtl-sdr (works with FM + DAB V3 dongles)
- `--rtlsdr=blog` - Uses rtlsdr-blog variant (experimental, for testing V4 dongles)

**CRITICAL:** You must build the corresponding RTL-SDR library DEBs BEFORE building foonerd-dab.

The build system:
1. Locates the sibling `rtlsdr-<source>` repository
2. Mounts the DEBs from `rtlsdr-<source>/out/<arch>/`
3. Installs them in the build container
4. Links fn-dab against the installed library
```bash
./clean-all.sh
```

## Output

Binaries are placed in:
```
out/
  armv6/
    fn-dab
    fn-dab-scanner
  armhf/
    fn-dab
    fn-dab-scanner
  arm64/
    fn-dab
    fn-dab-scanner
  amd64/
    fn-dab
    fn-dab-scanner
```

## Usage

### fn-dab

Basic DAB/DAB+ decoding:
```bash
fn-dab -C 12C -P "BBC Radio 1" -G 80 | aplay -r 48000 -f S16_LE -c 2
```

With metadata extraction (requires `-i` flag):
```bash
fn-dab -C 12C -P "BBC Radio 1" -G 80 -i /tmp/dab/ | aplay -r 48000 -f S16_LE -c 2
# DLS text: /tmp/dab/DABlabel.txt
# MOT images: /tmp/dab/DABslide.jpg
```

PCM format detection:
```bash
fn-dab -C 12C -P "BBC Radio 1" -G 80 2>&1 | grep "PCM:"
# Output: PCM: rate=48000 stereo=1 size=4608
```

### fn-dab-scanner

Scan all DAB channels:
```bash
fn-dab-scanner -B "BAND III" -G 80
```

## Integration with Volumio Plugin

This binary is designed for use with the Volumio RTL-SDR Radio plugin:

```javascript
// Plugin detects PCM format automatically
spawn('fn-dab', ['-C', ensemble, '-P', service, '-G', gain])
.stderr.on('data', (data) => {
  const pcmMatch = data.toString().match(/PCM: rate=(\d+) stereo=(\d+)/);
  if (pcmMatch) {
    const rate = parseInt(pcmMatch[1]);
    const stereo = parseInt(pcmMatch[2]);
    // Auto-configure sox resampling
  }
});
```

## Source Modifications

All modifications made DIRECTLY in cherry-picked source files (NO sed patches):

1. **PCM Detection** (main.cpp line ~235):
   - Added stderr output: `fprintf(stderr, "PCM: rate=%d stereo=%d\n", ...)`
   - Static counter to limit output to first 5 occurrences

2. **ASan Removal** (CMakeLists.txt):
   - Removed `-fsanitize=address` flags
   - Changed to `-O2` optimization

3. **arm64 pthread Fix** (CMakeLists.txt):
   - Added explicit pthread setting for aarch64
   - Fixes CMake FindModule issues

4. **stdout→stderr Redirection**:
   - All `fprintf(stdout)` → `fprintf(stderr)`
   - All `printf()` → `fprintf(stderr, )`
   - Prevents debug output from corrupting PCM audio stream

5. **Binary Naming**:
   - CMakeLists.txt `objectName` set to `fn-dab-rtlsdr` and `fn-dab-scanner`

## Why Cherry-Picked Source?

Clean source tree allows:
- NO patching complexity
- Direct source-level modifications
- Easy version control
- Clear change history
- No sed/awk maintenance burden

## Dependencies

### Build-time (Docker)
- git, cmake, build-essential, g++, pkg-config
- libsndfile1-dev, libfftw3-dev, portaudio19-dev
- libfaad-dev, zlib1g-dev, libusb-1.0-0-dev
- mesa-common-dev, libgl1-mesa-dev, libsamplerate0-dev

**CRITICAL:** Custom RTL-SDR library (libfn-rtlsdr0, libfn-rtlsdr-dev) MUST be installed at build time via mounted DEBs from rtlsdr-osmocom or rtlsdr-blog repository. System librtlsdr-dev will NOT work.

The build system explicitly requires:
- pkg-config module: libfn-rtlsdr (not librtlsdr)
- library name: libfn-rtlsdr.so (not librtlsdr.so)

This ensures binaries link against the correct custom library and prevents conflicts with system RTL-SDR packages.

### Runtime (target system)
- libfn-rtlsdr0 (from rtlsdr-osmocom or rtlsdr-blog)
- libfftw3-3
- libsamplerate0
- libfaad2
- libusb-1.0-0

## Related Projects

- [foonerd/rtlsdr-osmocom](https://github.com/foonerd/rtlsdr-osmocom) - RTL-SDR library (osmocom source)
- [foonerd/rtlsdr-blog](https://github.com/foonerd/rtlsdr-blog) - RTL-SDR library (rtlsdrblog source)
- [volumio-plugins-sources-bookworm/rtlsdr_radio](https://github.com/volumio/volumio-plugins-sources-bookworm) - Volumio plugin

## Maintainer

fooNerd (Just a Nerd)  
GitHub: [foonerd](https://github.com/foonerd)

## License

GPL-2.0 (matching upstream dab-cmdline)
