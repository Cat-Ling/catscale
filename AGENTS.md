# AGENTS.md — Catscale Repository Context & Guidelines

> **Catscale** is a high-performance, native iOS 18+ / macOS 15+ super-resolution neural upscaler built with Swift 6 and Apple Core ML.

---

## 1. Architecture Overview

* **Engine Layer (`Sources/Catscale/Engine/`):**
  * `CoreMLUpscaler.swift`: Hardware-accelerated inference runner (Apple Neural Engine + Metal GPU + CPU) supporting dynamic 3D, 4D, and 5D tensor ranks and `Float16`/`Float32` precision.
  * `ImageTiler.swift`: Overlap tile decomposition and stitching engine to eliminate iOS Jetsam OOM crashes on multi-megapixel images.
  * `UpscalerEngine.swift`: Actor-isolated pipeline orchestrating planar RGB extraction, tiling, inference, and Lanczos alpha resampling.
  * `ModelDownloader.swift`: Streamed chunk downloader with cancellation and per-scale file verification.
  * `ZipExtractor.swift`: ARM64-safe ZIP decompression with byte-aligned bit-shift readers.
  * `AppLogger.swift`: In-memory session diagnostics and synchronous disk flush to `Documents/catscale.log`.
* **State & App Layer (`Sources/Catscale/App/`):**
  * `AppState.swift`: State container with `@Observable` and `UserDefaults` persistence.
  * `CatscaleApp.swift`: SwiftUI App lifecycle entry point.
* **UI Layer (`Sources/Catscale/Views/`):**
  * `UpscaleView.swift`: Main viewport with non-destructive photo picker, left-aligned brand header, and action bar.
  * `ComparisonSliderView.swift`: 1:1 before/after comparison canvas with isolated pan and pinch-zoom.
  * `ModelSelectionView.swift`: Dropdown sheet with categorized model selection, dynamic scale factors, and output resolution calculation.
  * `SettingsView.swift`: Compute hardware selection, tile size tuning, overlap margin, and session logs inspector.

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

## 3. AI Model Addition & Compatibility Standard (CRITICAL)

When adding or updating AI models in Catscale, you **must strictly adhere to the following compatibility criteria**:

### Supported Model Formats
1. **Apple Core ML Packages (`.mlpackage`):**
   * Must contain `Manifest.json`, `Data/com.apple.CoreML/model.mlmodel`, and `Data/com.apple.CoreML/weights/weight.bin`.
2. **Compiled or Raw Core ML Models (`.mlmodel`, `.mlmodelc`):**
   * Must be standard protobuf models compilable via `MLModel.compileModel(at:)`.

### ⛔ Prohibited Formats (Do Not Add Directly)
* **NCNN Binaries (`.bin` / `.param`):** Core ML cannot execute NCNN files directly.
* **Raw PyTorch (`.pth`, `.pt`), ONNX, or TensorFlow (`.tflite`):** Must first be converted to `.mlpackage` via `coremltools` before integration.

### Tensor Shape & Datatype Compatibility
* **Input Rank:** Must accept planar RGB tensors: `[1, 3, H, W]`, `[3, H, W]`, or `[1, 1, 3, H, W]`.
* **Output Rank:** Supported ranks are 3D (`[3, H, W]`), 4D (`[1, 3, H, W]` / `[1, H, W, 3]`), and 5D (`[1, 1, 3, H, W]`).
* **Precision:** Weights and activations must execute safely on `Float16` (Apple Neural Engine) and `Float32` without memory alignment faults.

### Mandatory Pre-Integration Verification Checklist
Before committing any new model to `ModelType.swift`:
1. **Download & Inspect Archive:** Verify all files inside the zip using a script. Ensure valid `Manifest.json` and `model.mlmodel` exist.
2. **Measure Sizes:** Record the exact **compressed download size** and **uncompressed on-disk size** in megabytes.
3. **Register in `ModelType.swift`:**
   * Add the `ModelSpec` entry with `downloadSizeMB` and `uncompressedSizeMB`.
   * Add the model to `ModelRegistry.allModels`.
   * Update `ModelGroup` and `ModelFamily` enums if creating a new category.
4. **Update File Discovery in `ModelDownloader.swift`:**
   * Add the model's filename or package keyword to the `switch model.group` matcher.
5. **Verify Compilation:** Run `./build.sh` to confirm zero Swift / packaging errors.

---

## 4. UI & Code Conventions

* **Minimalist iOS Design:** Zero "AI magic" emojis, sparkles, or tacky decorative borders. Use native Apple HIG components (`Form`, `Picker`, `Section`, `PhotosPicker`, `Material`).
* **Non-Destructive Workflows:** Tapping an image to change photos must never wipe the existing photo if the user cancels the picker.
* **Swift 6 Concurrency:** Never block the main thread. Heavy image processing and model inference must run inside actor-isolated background tasks.
* **Logging:** Runtime diagnostics must go through `AppLogger.shared.log(..., isEnabled: loggingEnabled)` to ensure synchronous flushing to `Documents/catscale.log`.
