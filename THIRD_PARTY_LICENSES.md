# Third-Party Licenses & Attributions

Catscale bundles and integrates open-source neural network models, architectures, and tools developed by the machine learning and open-source communities. This document provides full licensing information and attributions for all third-party components.

---

## 1. Bundled & Integrated Neural Models

### 1.1 Waifu2x (Bundled Offline Models)
* **Components:** `up_anime_*`, `up_photo_*`, `anime_noise*`, `photo_noise*`
* **Original Authors:** nagadomi ([nagadomi/waifu2x](https://github.com/nagadomi/waifu2x)), imxieyi ([imxieyi/waifu2x-ios](https://github.com/imxieyi/waifu2x-ios))
* **License:** MIT License

```
Copyright (c) 2015 nagadomi
Copyright (c) 2017-2024 imxieyi <wez733@live.cn>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 1.2 Real-CUGAN (Anime Super-Resolution)
* **Components:** `RealCUGAN-2x-*`, `RealCUGAN-3x-*`, `RealCUGAN-4x-*`
* **Authors:** Bilibili AI Lab ([bilibili/ailab](https://github.com/bilibili/ailab/tree/main/Real-CUGAN))
* **License:** MIT License

```
MIT License

Copyright (c) 2022 bilibili

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 1.3 Real-ESRGAN & Real-ESRNet
* **Components:** `RealESRGAN-UltraSharp`, `RealESRGAN-Anime6B`, `RealESRGAN-x4plus`, `RealESRNet-x4plus`
* **Authors:** Xintao Wang, Liangbin Xie, Chao Dong, Ying Shan (ARC Lab, Tencent PCG / XPixelGroup)
* **Repository:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)
* **License:** BSD 3-Clause License

```
BSD 3-Clause License

Copyright (c) 2021, XPixelGroup
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING FORM OF USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

### 1.4 SRMD & BSRGAN (KAIR Image Restoration)
* **Components:** `SRMD-2x`, `SRMD-3x`, `SRMD-4x`, `SRMDNF-2x`, `SRMDNF-3x`, `SRMDNF-4x`, `BSRGAN-2x`, `BSRGAN-4x`
* **Authors:** Kai Zhang, Wangmeng Zuo, Lei Zhang
* **Repository:** [cszn/KAIR](https://github.com/cszn/KAIR), [cszn/BSRGAN](https://github.com/cszn/BSRGAN), [cszn/SRMD](https://github.com/cszn/SRMD)
* **License:** MIT License

```
MIT License

Copyright (c) 2021 Kai Zhang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 1.5 ESRGAN Manga & RealESRGAN Core ML Conversions
* **Components:** `ESRGAN-MangaJPEGLQ`
* **Port Author:** Vincent GOURBIN ([VincentGOURBIN/RealESRGAN-CoreML](https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML))
* **License:** MIT License

```
MIT License

Copyright (c) 2023 Vincent GOURBIN

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```\n