# Catscale

Native, on-device AI image super-resolution and restoration for iOS 18+ and macOS 15+. Built with Swift 6 and Apple Core ML.

---

### Features

* **On-Device Inference:** Hardware-accelerated execution on Apple Neural Engine (ANE), Metal GPU, and CPU.
* **Super-Resolution Algorithms:** 27 models across 9 architectures, including Real-CUGAN, Real-ESRGAN, Waifu2x, SRMD, BSRGAN, Real-ESRNet, and Manga Clean.
* **Tiling Engine:** Overlap decomposition and seamless stitching to process multi-megapixel images without memory pressure.
* **Interactive Comparison:** Full-screen before-and-after slider with synchronized pan and pinch-zoom.
* **Batch Processing:** Multi-image queue for automated background upscaling.
* **Storage & Offline Management:** Built-in model manager with on-demand downloads and swipe-to-delete.
* **Privacy by Design:** 100% offline, zero network requests during inference, zero analytics.

---

### Build

```bash
# Build unsigned IPA
./build.sh

# Clean build
./build.sh --clean
```

Outputs `.ipa` and `.app` to `build_output/`.

---

### Requirements

* iOS 18.0+ / iPadOS 18.0+ / macOS 15.0+
* Apple Silicon (A12 Bionic or newer recommended)

---

### License

MIT

