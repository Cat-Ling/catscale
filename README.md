# Catscale

Catscale is a native, on-device AI image super-resolution and restoration tool for iOS.

---

### Features

* **On-Device Inference:** Hardware-accelerated execution on Apple Neural Engine (ANE), Metal GPU, and CPU.
* **Super-Resolution Algorithms:** 27 models across 9 architectures, including Real-CUGAN, Real-ESRGAN, Waifu2x, SRMD, BSRGAN, Real-ESRNet, and Manga Clean.
* **Batch Processing:** Multi-image queue for automated background upscaling.
---

### Build

```bash
# Build unsigned IPA
./build.sh

# Clean build
./build.sh
```

Outputs `.ipa` and `.app` to `build_output/`.

---

### Requirements

* iOS 18.0+ / iPadOS 18.0+ / macOS 15.0+
* Apple Silicon (A16 or newer recommended)

---

### License

MIT

