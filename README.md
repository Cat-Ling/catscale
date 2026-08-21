# Catscale 🐱⚡

**Catscale** is a modern, high-performance on-device AI image upscaler and restoration app for iOS 18+ and macOS 15+.

100% offline, privacy-first, zero telemetry, zero paywalls, MIT licensed.

---

## ✨ Features

- **5 State-of-the-Art Upscaler Families**:
  - ⚡ **Real-ESRGAN**: Anime 6B (ultra-crisp line art), x4 Plus (universal), RealESRGANv3.
  - 🎨 **Real-CUGAN**: High-fidelity U-Net anime enhancer (SE 2x/3x/4x, Pro 2x).
  - ✨ **Waifu2x**: Classic CUNet / UpConv7 with customizable noise reduction (0–3).
  - 🔍 **SRMD**: Degradation-aware super-resolution restoring blurry and noisy images.
  - 📷 **RealSR**: Specialized optical super-resolution for DSLR/smartphone photography.
- **Intelligent Overlap Tiling Engine**:
  - Automatically tiles high-resolution images with seamless feathered blend margins.
  - Eliminates edge seam artifacts and prevents iOS out-of-memory (OOM) crashes.
- **Interactive Split Slider**:
  - Real-time before/after comparison with draggable divider and smooth pinch-to-zoom.
- **Batch Processing Queue**:
  - Upscale entire photo albums and galleries in the background.
- **Hardware Acceleration**:
  - Leverages Apple Neural Engine (ANE) and Metal Performance Shaders via Core ML.
- **Cross-Platform Building**:
  - Built with SwiftPM and `xtool` (Xcode-free development on Linux, Windows, macOS).

---

## 🛠️ Project Structure

```text
.
├── Package.swift                    # SwiftPM package manifest (iOS 18+ / macOS 15+)
├── xtool.yml                        # xtool cross-platform build config
├── Catscale-Info.plist              # Application bundle info
├── .github/
│   └── workflows/
│       └── build-and-release.yml    # Automated CI/CD builder & release workflow
└── Sources/
    └── Catscale/
        ├── App/
        │   ├── CatscaleApp.swift    # App entry point (@main)
        │   └── AppState.swift       # @Observable centralized state container
        ├── Engine/
        │   ├── ModelType.swift      # Model definitions for all 5 architectures
        │   ├── UpscalerEngine.swift # Actor-based async upscaling orchestrator
        │   ├── CoreMLUpscaler.swift # Core ML runtime & model loader
        │   ├── ImageTiler.swift     # Overlapping tile decomposition & blending
        │   └── ImageUtils.swift     # High-speed image processing & vImage alpha
        └── Views/
            ├── ContentView.swift    # Root TabView with iOS 18 Tab APIs
            ├── UpscaleView.swift    # Main single-image upscale view & picker
            ├── BatchUpscaleView.swift # Batch processing queue
            ├── ComparisonSliderView.swift # Interactive before/after split slider
            ├── ModelSelectionView.swift # Filterable model browser & specifications
            └── SettingsView.swift   # Compute hardware, tile size & export preferences
```

---

## 🚀 Building & Packaging

### Option 1: Fast Build with `xtool` (Linux / macOS / Windows)

```bash
# Build app bundle
xtool dev build

# Build unsigned IPA for sideloading
xtool dev build --ipa
```

### Option 2: Automated GitHub Actions Builder

The workflow at `.github/workflows/build-and-release.yml`:
1. Fetches pre-trained models from Hugging Face and GitHub releases.
2. Compiles `.mlpackage` / `.mlmodel` into Core ML `.mlmodelc` bundles.
3. Builds the unsigned `.app` and packages it into `Catscale-vX.X.X-unsigned.ipa`.
4. Publishes a GitHub Release automatically.

---

## 📜 License

MIT License. Free and open source.
