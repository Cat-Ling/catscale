# AGENTS.md — Catscale Repository Context & Guidelines

> **Catscale** is a high-performance, native iOS 18+ / iPadOS 18+ super-resolution neural upscaler built with Swift 6 and Apple Core ML.

---

## 1. Architecture Overview

* **Engine Layer (`Sources/Catscale/Engine/`):**
  * `CoreMLUpscaler.swift`: Hardware-accelerated inference runner with cascading execution fallback (**Apple Neural Engine $\to$ Metal GPU $\to$ CPU**) supporting dynamic 3D, 4D, and 5D tensor ranks and `Float16`/`Float32` precision.
  * `ImageTiler.swift`: Overlap tile decomposition and seamless continuous stitching engine to eliminate iOS Jetsam OOM crashes on multi-megapixel images.
  * `UpscalerEngine.swift`: Actor-isolated pipeline orchestrating planar RGB extraction, optimal per-model receptive margin padding, tiling, inference, and Lanczos alpha resampling.
  * `ModelType.swift`: Complete registry of all 27 models across 9 algorithms, defining input/output channels, default tile sizes, overlap margins, and remote asset metadata.
  * `ModelDownloader.swift`: Streamed chunk downloader with sequential "Download All" batching, per-model deletion (`deleteModel`), download cancellation, and storage verification.
  * `ZipExtractor.swift`: ARM64-safe ZIP decompression with byte-aligned bit-shift readers.
  * `AppLogger.swift`: In-memory session diagnostics and synchronous disk flush to `Documents/catscale.log`.
* **State & App Layer (`Sources/Catscale/App/`):**
  * `AppState.swift`: State container with `@Observable`, Swift 6 concurrency isolation, and `UserDefaults` persistence.
  * `CatscaleApp.swift`: SwiftUI App lifecycle entry point.
* **UI Layer (`Sources/Catscale/Views/`):**
  * `ContentView.swift`: Primary navigation coordinator.
  * `UpscaleView.swift`: Main viewport with non-destructive photo picker, left-aligned brand header, live comparison canvas, and processing state locks.
  * `ComparisonSliderView.swift`: 1:1 before/after comparison canvas with isolated pan, pinch-zoom, and responsive divider tap tracking.
  * `ModelSelectionView.swift`: Two-tier selector (**Algorithm $\to$ Model Variant**) with contextual controls (SRMD Denoise $0\dots10$, Real-CUGAN SyncGap & Noise, Waifu2x Noise Reduction).
  * `ManageModelsView.swift`: Storage inspector with segmented filtering (`All`, `Installed`, `Not Installed`), individual swipe-to-delete, and direct repair/re-downloads.
  * `BatchUpscaleView.swift`: Multi-image batch queue pipeline.
  * `SettingsView.swift`: Hardware compute engine selection, offline model storage manager, batch downloader, session log viewer, and diagnostic tools.

---

## 2. Build & Test Commands

* **Build & Package Unsigned IPA (Default):**
  ```bash
  ./build.sh
  ```
  *Output:* `build_output/Catscale-unsigned.ipa` and `build_output/Catscale.app`
* **Clean Build:**
  ```bash
  ./build.sh --clean
  ```
* **Build `.app` Only (Without IPA Packaging):**
  ```bash
  ./build.sh --app-only
  ```
* **Pre-fetch Remote Models:**
  ```bash
  ./build.sh --fetch-models
  ```

---

## 3. AI Model Hierarchy & Supported Algorithms

Catscale categorizes models under **9 Core Algorithms** across **Anime & Art** and **Photo & Universal** domains:

### Anime & Art
1. **Real-CUGAN:** UpCunet models ($2\times, 3\times, 4\times$) with Denoising levels and **SyncGap** (`None`, `Accurate/SyncGap 1`, `Rough/SyncGap 2`, `Very Rough/SyncGap 3`) seam synchronization.
2. **Real-ESRGAN (Anime):** `Real-ESRGAN UltraSharp (4x)` and `Real-ESRGAN Anime 6B (4x)`.
3. **Waifu2x (Anime):** Bundled offline Caffe models ($2\times$, Noise levels $0\dots3$).
4. **ESRGAN (Manga & Clean):** `ESRGAN Manga Clean (1x)` JPEG restoration model.

### Photo & Universal
5. **SRMD (Photo & Universal):** PCA blur map models ($2\times, 3\times, 4\times$) with $0\dots10$ Denoise levels, plus noise-free `SRMDNF (2x, 3x, 4x)`.
6. **BSRGAN (Photo & Degraded):** Blind super-resolution ($2\times, 4\times$) for heavily degraded, vintage, or noisy images.
7. **Real-ESRNet (Photo & Natural):** `Real-ESRNet x4 Plus (4x)` PSNR-oriented natural super-resolution.
8. **Real-ESRGAN (Universal):** `Real-ESRGAN x4 Plus (4x)` universal texture and photo model.
9. **Waifu2x (Photo):** Bundled offline Caffe photo models ($2\times$, Noise levels $1\dots2$).

### Model Distribution Standard
* All remote model archives are packaged as Float16 `.mlpackage.zip` files hosted on GitHub Releases:
  `https://github.com/Cat-Ling/CatML/releases/download/0.1/<Model-Name>.mlpackage.zip`

---

## 4. UI & Code Conventions

* **Minimalist iOS Design:** Zero "AI magic" emojis, sparkles, or tacky decorative borders. Use native Apple HIG components (`Form`, `Picker`, `Section`, `PhotosPicker`, `Material`).
* **Non-Destructive Workflows:** Tapping an image to change photos must never wipe the existing photo if the user cancels the picker.
* **Input Locking:** The image preview and model selection buttons must be disabled (`.disabled(state.isProcessing)`) while an upscale task is executing.
* **Zero External Dependencies:** Use native Apple frameworks (`CoreML`, `Metal`, `Accelerate`, `SwiftUI`, `PhotosUI`) and pure Swift implementations.
* **Swift 6 Concurrency:** Never block the main thread. Heavy image processing and model inference must run inside actor-isolated background tasks.
* **Logging:** Runtime diagnostics must go through `AppLogger.shared.log(..., isEnabled: loggingEnabled)` to ensure synchronous flushing to `Documents/catscale.log`.
