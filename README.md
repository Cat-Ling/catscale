# Catscale 🐱⚡

**Catscale** is a modern, high-performance on-device AI image super-resolution and restoration app for iOS 18+ and macOS 15+ built with Swift 6 and Apple Core ML.

100% offline, privacy-first, zero telemetry, zero paywalls, MIT licensed.

---

## ✨ Supported Algorithms & Models

Catscale integrates **27 models** across **9 state-of-the-art super-resolution algorithms**:

### 🎨 Anime & Art
1. **Real-CUGAN**: High-fidelity UpCunet ($2\times, 3\times, 4\times$) with Denoise levels and **SyncGap** seam synchronization.
2. **Real-ESRGAN (Anime)**: `Real-ESRGAN UltraSharp (4x)` and lightweight `Real-ESRGAN Anime 6B (4x)`.
3. **Waifu2x (Anime)**: Bundled offline Caffe models ($2\times$, Noise Reduction $0\dots3$).
4. **ESRGAN (Manga Clean)**: `ESRGAN Manga Clean (1x)` JPEG restoration and line-art cleaner.

### 📷 Photo & Universal
5. **SRMD (Photo & Universal)**: Degradation-aware super-resolution ($2\times, 3\times, 4\times$) with $0\dots10$ Denoise levels, plus noise-free `SRMDNF (2x, 3x, 4x)`.
6. **BSRGAN (Photo & Degraded)**: Blind super-resolution ($2\times, 4\times$) for highly degraded vintage and mobile photos.
7. **Real-ESRNet (Photo & Natural)**: PSNR-oriented natural photo super-resolution (`Real-ESRNet x4 Plus`).
8. **Real-ESRGAN (Universal)**: Universal 4x super-resolution for textures, CGI, and photos (`Real-ESRGAN x4 Plus`).
9. **Waifu2x (Photo)**: Bundled offline Caffe photo models ($2\times$, Noise Reduction $1\dots2$).

---

## ⚡ Core Architecture

* **Cascading Hardware Fallback**: Runs on the **Apple Neural Engine (ANE)** with automatic fallback to **Metal GPU** and **CPU**.
* **Intelligent Overlap Tiling Engine**: Mathematical tile partition decomposition eliminating edge seams and iOS Jetsam OOM memory crashes.
* **Interactive Split Slider**: Real-time before/after comparison with isolated pan, pinch-zoom, and divider tap tracking.
* **Storage & Download Manager**: Sequential batch downloader, segmented model inspector (`All`, `Installed`, `Not Installed`), and individual swipe-to-delete.
* **Batch Processing Queue**: Multi-image batch upscale pipeline.
* **Zero External Dependencies**: Pure Swift 6 implementation using native Apple frameworks (`CoreML`, `Metal`, `Accelerate`, `SwiftUI`, `PhotosUI`).

---

## 🛠️ Project Structure

```text
.
├── Package.swift                    # SwiftPM package manifest (iOS 18+ / macOS 15+)
├── build.sh                         # High-performance Darwin toolchain builder
├── Catscale-Info.plist              # Application bundle info & permissions
├── LICENSE                          # MIT License
├── THIRD_PARTY_LICENSES.md          # Third-party notices for bundled models
└── Sources/
    └── Catscale/
        ├── App/
        │   ├── CatscaleApp.swift    # App entry point (@main)
        │   └── AppState.swift       # @Observable centralized state container
        ├── Engine/
        │   ├── ModelType.swift      # Model registry for all 27 models & 9 algorithms
        │   ├── UpscalerEngine.swift # Actor-isolated pipeline orchestrator
        │   ├── CoreMLUpscaler.swift # Cascading ANE -> GPU -> CPU inference runner
        │   ├── ImageTiler.swift     # Overlap tile decomposition & seamless stitching
        │   ├── ModelDownloader.swift# Streamed model downloader & batch offline manager
        │   ├── ZipExtractor.swift   # ARM64 byte-aligned ZIP decompressor
        │   ├── AppLogger.swift      # Diagnostics & disk log flusher
        │   └── ImageUtils.swift     # Image conversion & photo library saving
        └── Views/
            ├── ContentView.swift    # Root Tab navigation coordinator
            ├── UpscaleView.swift    # Primary single-image upscale view & picker
            ├── ComparisonSliderView.swift # 1:1 before/after interactive comparison canvas
            ├── ModelSelectionView.swift # Two-tier Algorithm -> Model selector
            ├── ManageModelsView.swift   # Storage inspector & swipe-to-delete model manager
            ├── BatchUpscaleView.swift   # Multi-image batch processing queue
            └── SettingsView.swift   # Compute engine, model storage & session logs
```

---

## 🚀 Building & Packaging

```bash
# Build and package unsigned IPA (Default)
./build.sh

# Clean build
./build.sh --clean

# Build .app only
./build.sh --app-only
```

*Output:* `build_output/Catscale-unsigned.ipa` and `build_output/Catscale.app`

---

## 📜 License

MIT License. Free and open source.

