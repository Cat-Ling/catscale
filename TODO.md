# TODO — Catscale Future Roadmap & Model Additions

---

## 1. Face Restoration Pipeline (CodeFormer)

- [ ] **Core ML Conversion:**
  - Convert `sczhou/CodeFormer` (`codeformer.pth`) to Float16 `.mlpackage` via `coremltools`.
  - Support inputs: `image: [1, 3, 512, 512]` and scalar `fidelity_ratio: Float` ($w \in [0.0, 1.0]$).
- [ ] **Apple Vision Landmark Detection:**
  - Use native `VNDetectFaceLandmarksRequest` to extract 5 facial keypoints (left eye, right eye, nose tip, left mouth, right mouth).
- [ ] **Affine Crop & Normalization:**
  - Compute 2D affine transformation matrix to crop and align faces into canonical $512\times 512$ tensors.
- [ ] **Inverse Affine Warping & Blending:**
  - Perform inverse affine warp of the restored $512\times 512$ face back into the main image coordinates.
  - Implement elliptical Gaussian alpha feathering for seamless edge blending.
- [ ] **UI Integration:**
  - Add contextual *"Enhance Faces (CodeFormer)"* toggle in the Model Selector.
  - Add Fidelity Slider ($w = 0.0$ max sharpness $\dots$ $w = 1.0$ identity preservation; default $0.7$).

---

## 2. Single-Image Reflection Removal (SIRR)

- [ ] **Candidate Models:**
  - **DSRNet / DSIT (from XReflection):** NTIRE 2025/2026 Champion for reflection separation.
  - **PINTO0309 Reflection Removal:** Lightweight ONNX/CoreML-optimized edge architectures.
- [ ] **Engine Integration:**
  - Convert to Core ML `.mlpackage` (`[1, 3, H, W] -> [1, 3, H, W]`).
  - Drop directly into Catscale's existing `ImageTiler` and `UpscalerEngine` pipelines.
- [ ] **UI Integration:**
  - Add *"Reflection Removal (Photo & Glass)"* under the Photo & Universal algorithm category.

---

## 3. Single-Image Shadow Removal

- [ ] **Candidate Models:**
  - **PhaSR (CVPR 2026):** State-of-the-art physical Retinex illumination priors + geometric-semantic attention.
  - **ShadowFormer (AAAI) / HomoFormer (CVPR):** Contextual transformer attention for shadow-to-lit texture borrowing.
- [ ] **Engine Integration:**
  - Convert to Core ML `.mlpackage` (`[1, 3, H, W] -> [1, 3, H, W]`).
  - Fully compatible with standard tile partition and overlap stitching.
- [ ] **UI Integration:**
  - Add *"Shadow Removal (Documents & Photos)"* under the Photo & Universal algorithm category.

---

## 4. App & Ecosystem Enhancements

- [ ] **iOS Photos Share Sheet Extension:**
  - Add an Action / Share Extension to upscale photos directly from the native iOS Photos app without opening Catscale.
  - Configure `com.apple.security.application-groups` for shared container storage.
- [ ] **Model Weight Quantization (Float8 / Palettization):**
  - Benchmark Core ML 4-bit / 8-bit palettization for large models (e.g., Real-ESRGAN, BSRGAN, CodeFormer) to reduce download size below 15MB.
- [ ] **Drag & Drop / iPad Multitasking:**
  - Support native iPadOS Split View and image Drag & Drop into the viewport.\n