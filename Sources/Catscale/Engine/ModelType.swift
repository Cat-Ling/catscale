import Foundation

/// Primary upscaling algorithm in dropdowns
public enum ModelGroup: String, CaseIterable, Identifiable, Sendable {
    case realCUGANAnime = "Real-CUGAN (Anime)"
    case realESRGANAnime = "Real-ESRGAN (Anime)"
    case waifu2xAnime = "Waifu2x (Anime)"
    case mangaClean = "ESRGAN (Manga & Clean)"
    case srmdPhoto = "SRMD (Photo & Universal)"
    case bsrganPhoto = "BSRGAN (Photo & Degraded)"
    case realESRNetPhoto = "Real-ESRNet (Photo & Natural)"
    case realESRGANUniversal = "Real-ESRGAN (Universal)"
    case waifu2xPhoto = "Waifu2x (Photo)"

    public var id: String { rawValue }

    public var isAnime: Bool {
        switch self {
        case .waifu2xAnime, .realCUGANAnime, .realESRGANAnime, .mangaClean: return true
        default: return false
        }
    }

    public var category: ModelCategory {
        isAnime ? .anime : .photo
    }

    public var availableVariantNames: [String] {
        switch self {
        case .srmdPhoto:
            return [
                "SRMD 2x",
                "SRMD 3x",
                "SRMD 4x",
                "SRMDNF 2x (Noise-Free)",
                "SRMDNF 3x (Noise-Free)",
                "SRMDNF 4x (Noise-Free)"
            ]
        case .realCUGANAnime:
            return [
                "Real-CUGAN 2x",
                "Real-CUGAN 3x",
                "Real-CUGAN 4x"
            ]
        case .bsrganPhoto:
            return [
                "BSRGAN 2x",
                "BSRGAN 4x"
            ]
        case .realESRGANAnime:
            return [
                "Real-ESRGAN UltraSharp (4x)",
                "Real-ESRGAN Anime 6B (4x)"
            ]
        case .realESRNetPhoto:
            return [
                "Real-ESRNet x4 Plus (4x)"
            ]
        case .realESRGANUniversal:
            return [
                "Real-ESRGAN x4 Plus (4x)"
            ]
        case .mangaClean:
            return [
                "ESRGAN Manga Clean (1x)"
            ]
        case .waifu2xAnime:
            return [
                "Waifu2x Anime 2x"
            ]
        case .waifu2xPhoto:
            return [
                "Waifu2x Photo 2x"
            ]
        }
    }

    public var supportsNoiseReduction: Bool {
        switch self {
        case .waifu2xAnime, .waifu2xPhoto, .realCUGANAnime, .srmdPhoto:
            return true
        default:
            return false
        }
    }
}

/// Real-CUGAN Seam Synchronization mode
public enum SyncGapMode: String, CaseIterable, Identifiable, Sendable {
    case none = "None (Standard)"
    case accurate = "Accurate (SyncGap 1)"
    case rough = "Rough (SyncGap 2)"
    case veryRough = "Very Rough (SyncGap 3)"

    public var id: String { rawValue }
}

/// Architecture families supported by Catscale
public enum ModelFamily: String, CaseIterable, Identifiable, Sendable {
    case waifu2x = "Waifu2x"
    case realCUGAN = "Real-CUGAN"
    case realESRGAN = "Real-ESRGAN"
    case realESRNet = "Real-ESRNet"
    case esrganManga = "ESRGAN-Manga"
    case srmd = "SRMD"
    case bsrgan = "BSRGAN"

    public var id: String { rawValue }
}

/// Category domain of the model
public enum ModelCategory: String, CaseIterable, Identifiable, Sendable {
    case anime = "Anime & Art"
    case photo = "Photo & Universal"

    public var id: String { rawValue }
}

/// Specification for an individual AI upscaling model
public struct ModelSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let variantName: String
    public let family: ModelFamily
    public let group: ModelGroup
    public let category: ModelCategory
    public let scale: Int
    public let noiseLevel: Int // -1 = none, 0..10 for SRMD, 0..3 for CUGAN/Waifu2x
    public let isSRMDNF: Bool
    public let description: String
    public let compiledModelName: String
    public let defaultTileSize: Int
    public let recommendedOverlap: Int
    public let isBundled: Bool
    public let downloadURLString: String?
    public let downloadSizeMB: Double
    public let uncompressedSizeMB: Double

    public init(
        id: String,
        name: String,
        variantName: String,
        family: ModelFamily,
        group: ModelGroup,
        category: ModelCategory,
        scale: Int,
        noiseLevel: Int = -1,
        isSRMDNF: Bool = false,
        description: String,
        compiledModelName: String,
        defaultTileSize: Int = 256,
        recommendedOverlap: Int = 16,
        isBundled: Bool = false,
        downloadURLString: String? = nil,
        downloadSizeMB: Double = 0.0,
        uncompressedSizeMB: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.variantName = variantName
        self.family = family
        self.group = group
        self.category = category
        self.scale = scale
        self.noiseLevel = noiseLevel
        self.isSRMDNF = isSRMDNF
        self.description = description
        self.compiledModelName = compiledModelName
        self.defaultTileSize = defaultTileSize
        self.recommendedOverlap = recommendedOverlap
        self.isBundled = isBundled
        self.downloadURLString = downloadURLString
        self.downloadSizeMB = downloadSizeMB
        self.uncompressedSizeMB = uncompressedSizeMB
    }
}

/// Model registry containing verified CoreML presets
public enum ModelRegistry {

    // MARK: - Real-CUGAN Models (Anime & Illustration)
    public static let realCUGAN2xNoDenoise = ModelSpec(
        id: "realcugan_2x_noise0",
        name: "Real-CUGAN 2x (No Denoise)",
        variantName: "Real-CUGAN 2x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 0,
        description: "2x high-fidelity anime upscaler with crisp line art.",
        compiledModelName: "RealCUGAN-2x-NoDenoise",
        defaultTileSize: 256,
        recommendedOverlap: 18,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-2x-NoDenoise.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN2xDenoise1 = ModelSpec(
        id: "realcugan_2x_noise1",
        name: "Real-CUGAN 2x (Low Denoise)",
        variantName: "Real-CUGAN 2x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 1,
        description: "2x anime upscaling with light smoothing.",
        compiledModelName: "RealCUGAN-2x-Denoise1",
        defaultTileSize: 256,
        recommendedOverlap: 18,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-2x-Denoise1.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN2xDenoise2 = ModelSpec(
        id: "realcugan_2x_noise2",
        name: "Real-CUGAN 2x (Medium Denoise)",
        variantName: "Real-CUGAN 2x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 2,
        description: "2x anime upscaling with medium noise removal.",
        compiledModelName: "RealCUGAN-2x-Denoise2",
        defaultTileSize: 256,
        recommendedOverlap: 18,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-2x-Denoise2.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN2xDenoise3 = ModelSpec(
        id: "realcugan_2x_noise3",
        name: "Real-CUGAN 2x (High Denoise)",
        variantName: "Real-CUGAN 2x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 3,
        description: "2x anime upscaling with heavy artifact cleaning.",
        compiledModelName: "RealCUGAN-2x-Denoise3",
        defaultTileSize: 256,
        recommendedOverlap: 18,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-2x-Denoise3.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN3xNoDenoise = ModelSpec(
        id: "realcugan_3x_noise0",
        name: "Real-CUGAN 3x (No Denoise)",
        variantName: "Real-CUGAN 3x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 3,
        noiseLevel: 0,
        description: "3x anime super-resolution for wallpapers and art.",
        compiledModelName: "RealCUGAN-3x-NoDenoise",
        defaultTileSize: 256,
        recommendedOverlap: 14,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-3x-NoDenoise.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN3xDenoise3 = ModelSpec(
        id: "realcugan_3x_noise3",
        name: "Real-CUGAN 3x (Denoise)",
        variantName: "Real-CUGAN 3x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 3,
        noiseLevel: 3,
        description: "3x anime upscaling with noise reduction.",
        compiledModelName: "RealCUGAN-3x-Denoise3",
        defaultTileSize: 256,
        recommendedOverlap: 14,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-3x-Denoise3.mlpackage.zip",
        downloadSizeMB: 2.3,
        uncompressedSizeMB: 2.6
    )

    public static let realCUGAN4xNoDenoise = ModelSpec(
        id: "realcugan_4x_noise0",
        name: "Real-CUGAN 4x (No Denoise)",
        variantName: "Real-CUGAN 4x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 4,
        noiseLevel: 0,
        description: "4x ultra-resolution anime and manga upscaling.",
        compiledModelName: "RealCUGAN-4x-NoDenoise",
        defaultTileSize: 256,
        recommendedOverlap: 19,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-4x-NoDenoise.mlpackage.zip",
        downloadSizeMB: 2.5,
        uncompressedSizeMB: 2.8
    )

    public static let realCUGAN4xDenoise3 = ModelSpec(
        id: "realcugan_4x_noise3",
        name: "Real-CUGAN 4x (Denoise)",
        variantName: "Real-CUGAN 4x",
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 4,
        noiseLevel: 3,
        description: "4x anime upscaling with artifact removal.",
        compiledModelName: "RealCUGAN-4x-Denoise3",
        defaultTileSize: 256,
        recommendedOverlap: 19,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-4x-Denoise3.mlpackage.zip",
        downloadSizeMB: 2.5,
        uncompressedSizeMB: 2.8
    )

    // MARK: - SRMD Standard Models (with Denoise 0..10)
    public static let srmd2x = ModelSpec(
        id: "srmd_2x",
        name: "SRMD 2x",
        variantName: "SRMD 2x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 2,
        noiseLevel: 0,
        isSRMDNF: false,
        description: "2x realistic photo and texture restoration with blur and noise control.",
        compiledModelName: "SRMD-2x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMD-2x.mlpackage.zip",
        downloadSizeMB: 2.7,
        uncompressedSizeMB: 2.9
    )

    public static let srmd3x = ModelSpec(
        id: "srmd_3x",
        name: "SRMD 3x",
        variantName: "SRMD 3x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 3,
        noiseLevel: 0,
        isSRMDNF: false,
        description: "3x realistic photo restoration with blur and noise control.",
        compiledModelName: "SRMD-3x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMD-3x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    public static let srmd4x = ModelSpec(
        id: "srmd_4x",
        name: "SRMD 4x",
        variantName: "SRMD 4x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 4,
        noiseLevel: 0,
        isSRMDNF: false,
        description: "4x realistic photo super-resolution with blur and noise control.",
        compiledModelName: "SRMD-4x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMD-4x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    // MARK: - SRMDNF Models (Noise-Free)
    public static let srmdnf2x = ModelSpec(
        id: "srmdnf_2x",
        name: "SRMDNF 2x (Noise-Free)",
        variantName: "SRMDNF 2x (Noise-Free)",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 2,
        noiseLevel: -1,
        isSRMDNF: true,
        description: "2x realistic noise-free photo and texture super-resolution.",
        compiledModelName: "SRMDNF-2x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-2x.mlpackage.zip",
        downloadSizeMB: 2.7,
        uncompressedSizeMB: 2.9
    )

    public static let srmdnf3x = ModelSpec(
        id: "srmdnf_3x",
        name: "SRMDNF 3x (Noise-Free)",
        variantName: "SRMDNF 3x (Noise-Free)",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 3,
        noiseLevel: -1,
        isSRMDNF: true,
        description: "3x realistic noise-free photo super-resolution.",
        compiledModelName: "SRMDNF-3x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-3x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    public static let srmdnf4x = ModelSpec(
        id: "srmdnf_4x",
        name: "SRMDNF 4x (Noise-Free)",
        variantName: "SRMDNF 4x (Noise-Free)",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 4,
        noiseLevel: -1,
        isSRMDNF: true,
        description: "4x realistic noise-free photo super-resolution.",
        compiledModelName: "SRMDNF-4x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-4x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    // MARK: - BSRGAN Models (Blind Super-Resolution for Degraded Photos)
    public static let bsrgan2x = ModelSpec(
        id: "bsrgan_2x",
        name: "BSRGAN 2x",
        variantName: "BSRGAN 2x",
        family: .bsrgan,
        group: .bsrganPhoto,
        category: .photo,
        scale: 2,
        description: "2x blind super-resolution designed for highly degraded vintage and mobile photos.",
        compiledModelName: "BSRGAN-2x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/BSRGAN-2x.mlpackage.zip",
        downloadSizeMB: 29.5,
        uncompressedSizeMB: 32.5
    )

    public static let bsrgan4x = ModelSpec(
        id: "bsrgan_4x",
        name: "BSRGAN 4x",
        variantName: "BSRGAN 4x",
        family: .bsrgan,
        group: .bsrganPhoto,
        category: .photo,
        scale: 4,
        description: "4x blind super-resolution for complex camera noise, motion blur, and JPEG compression.",
        compiledModelName: "BSRGAN-4x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/BSRGAN-4x.mlpackage.zip",
        downloadSizeMB: 29.6,
        uncompressedSizeMB: 32.5
    )

    // MARK: - Real-ESRNet Models (Natural Photo Super-Resolution)
    public static let realESRNetx4Plus = ModelSpec(
        id: "realesrnet_x4plus",
        name: "Real-ESRNet x4 Plus (4x)",
        variantName: "Real-ESRNet x4 Plus (4x)",
        family: .realESRNet,
        group: .realESRNetPhoto,
        category: .photo,
        scale: 4,
        description: "4x PSNR-oriented natural photo super-resolution with zero hallucinated artifacts.",
        compiledModelName: "RealESRNet-x4plus",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealESRNet-x4plus.mlpackage.zip",
        downloadSizeMB: 29.6,
        uncompressedSizeMB: 32.5
    )

    // MARK: - Real-ESRGAN Anime Models
    public static let realESRGANUltraSharp = ModelSpec(
        id: "realesrgan_ultrasharp_4x",
        name: "Real-ESRGAN UltraSharp 4x",
        variantName: "Real-ESRGAN UltraSharp (4x)",
        family: .realESRGAN,
        group: .realESRGANAnime,
        category: .anime,
        scale: 4,
        description: "Ultra-sharp 4x anime & art upscaling with crisp line edges.",
        compiledModelName: "RealESRGAN-UltraSharp",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealESRGAN-UltraSharp.mlpackage.zip",
        downloadSizeMB: 29.5,
        uncompressedSizeMB: 32.5
    )

    public static let realESRGANAnime6B = ModelSpec(
        id: "realesrgan_anime6b_4x",
        name: "Real-ESRGAN Anime 6B 4x",
        variantName: "Real-ESRGAN Anime 6B (4x)",
        family: .realESRGAN,
        group: .realESRGANAnime,
        category: .anime,
        scale: 4,
        description: "Lightweight 6-block anime upscaler optimized for fast mobile performance.",
        compiledModelName: "RealESRGAN-Anime6B",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealESRGAN-Anime6B.mlpackage.zip",
        downloadSizeMB: 7.9,
        uncompressedSizeMB: 8.8
    )

    // MARK: - ESRGAN Manga & Clean (1x Restoration)
    public static let mangaJPEGLQ = ModelSpec(
        id: "esrgan_manga_1x",
        name: "ESRGAN Manga Clean (1x)",
        variantName: "ESRGAN Manga Clean (1x)",
        family: .esrganManga,
        group: .mangaClean,
        category: .anime,
        scale: 1,
        description: "Manga and illustration clean-up with JPEG compression restoration.",
        compiledModelName: "ESRGAN-MangaJPEGLQ",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/ESRGAN-MangaJPEGLQ.mlpackage.zip",
        downloadSizeMB: 8.9,
        uncompressedSizeMB: 9.8
    )

    // MARK: - Real-ESRGAN Universal Models
    public static let realESRGANx4Plus = ModelSpec(
        id: "realesrgan_x4plus",
        name: "Real-ESRGAN x4 Plus (4x)",
        variantName: "Real-ESRGAN x4 Plus (4x)",
        family: .realESRGAN,
        group: .realESRGANUniversal,
        category: .photo,
        scale: 4,
        description: "Universal 4x super-resolution for textures, CGI, and photos.",
        compiledModelName: "RealESRGAN-x4plus",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealESRGAN-x4plus.mlpackage.zip",
        downloadSizeMB: 29.6,
        uncompressedSizeMB: 32.5
    )

    // MARK: - Waifu2x Anime Models (Bundled in App Bundle)
    public static let waifu2xAnimeNoise0 = ModelSpec(
        id: "waifu2x_anime_noise0_2x",
        name: "Waifu2x Anime (No Denoise)",
        variantName: "Waifu2x Anime 2x",
        family: .waifu2x,
        group: .waifu2xAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 0,
        description: "2x upscale for clean anime illustrations.",
        compiledModelName: "up_anime_noise0_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    public static let waifu2xAnimeNoise1 = ModelSpec(
        id: "waifu2x_anime_noise1_2x",
        name: "Waifu2x Anime (Low Denoise)",
        variantName: "Waifu2x Anime 2x",
        family: .waifu2x,
        group: .waifu2xAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 1,
        description: "2x upscale with light denoising.",
        compiledModelName: "up_anime_noise1_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    public static let waifu2xAnimeNoise2 = ModelSpec(
        id: "waifu2x_anime_noise2_2x",
        name: "Waifu2x Anime (Medium Denoise)",
        variantName: "Waifu2x Anime 2x",
        family: .waifu2x,
        group: .waifu2xAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 2,
        description: "2x upscale with medium denoising.",
        compiledModelName: "up_anime_noise2_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    public static let waifu2xAnimeNoise3 = ModelSpec(
        id: "waifu2x_anime_noise3_2x",
        name: "Waifu2x Anime (High Denoise)",
        variantName: "Waifu2x Anime 2x",
        family: .waifu2x,
        group: .waifu2xAnime,
        category: .anime,
        scale: 2,
        noiseLevel: 3,
        description: "2x upscale with heavy denoising.",
        compiledModelName: "up_anime_noise3_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    // MARK: - Waifu2x Photo Models (Bundled in App Bundle)
    public static let waifu2xPhotoNoise1 = ModelSpec(
        id: "waifu2x_photo_noise1_2x",
        name: "Waifu2x Photo (Light Denoise)",
        variantName: "Waifu2x Photo 2x",
        family: .waifu2x,
        group: .waifu2xPhoto,
        category: .photo,
        scale: 2,
        noiseLevel: 1,
        description: "2x photo upscale with light noise reduction.",
        compiledModelName: "up_photo_noise1_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    public static let waifu2xPhotoNoise2 = ModelSpec(
        id: "waifu2x_photo_noise2_2x",
        name: "Waifu2x Photo (Medium Denoise)",
        variantName: "Waifu2x Photo 2x",
        family: .waifu2x,
        group: .waifu2xPhoto,
        category: .photo,
        scale: 2,
        noiseLevel: 2,
        description: "2x photo upscale with medium noise reduction.",
        compiledModelName: "up_photo_noise2_scale2x_model",
        defaultTileSize: 156,
        recommendedOverlap: 7,
        isBundled: true,
        downloadSizeMB: 0.0,
        uncompressedSizeMB: 2.2
    )

    /// All registered models
    public static let allModels: [ModelSpec] = [
        waifu2xAnimeNoise1,
        waifu2xAnimeNoise2,
        waifu2xAnimeNoise3,
        waifu2xAnimeNoise0,
        realCUGAN2xNoDenoise,
        realCUGAN2xDenoise1,
        realCUGAN2xDenoise2,
        realCUGAN2xDenoise3,
        realCUGAN3xNoDenoise,
        realCUGAN3xDenoise3,
        realCUGAN4xNoDenoise,
        realCUGAN4xDenoise3,
        srmd2x,
        srmd3x,
        srmd4x,
        srmdnf2x,
        srmdnf3x,
        srmdnf4x,
        bsrgan2x,
        bsrgan4x,
        realESRNetx4Plus,
        realESRGANUltraSharp,
        realESRGANAnime6B,
        mangaJPEGLQ,
        waifu2xPhotoNoise1,
        waifu2xPhotoNoise2,
        realESRGANx4Plus
    ]

    /// Resolve model by algorithm, variant name, and noise level
    public static func resolve(group: ModelGroup, variantName: String? = nil, noiseLevel: Int = 1) -> ModelSpec {
        let groupModels = allModels.filter { $0.group == group }
        if groupModels.isEmpty {
            return waifu2xAnimeNoise1
        }

        let variantModels: [ModelSpec]
        if let variant = variantName, !variant.isEmpty {
            let matched = groupModels.filter { $0.variantName == variant }
            variantModels = matched.isEmpty ? groupModels : matched
        } else {
            variantModels = groupModels
        }

        if group.supportsNoiseReduction {
            if let exact = variantModels.first(where: { $0.noiseLevel == noiseLevel }) {
                return exact
            } else if let closest = variantModels.filter({ $0.noiseLevel >= 0 }).min(by: { abs($0.noiseLevel - noiseLevel) < abs($1.noiseLevel - noiseLevel) }) {
                return closest
            }
        }

        return variantModels.first ?? groupModels.first!
    }
}

