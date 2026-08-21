import Foundation

/// Primary model group in dropdowns
public enum ModelGroup: String, CaseIterable, Identifiable, Sendable {
    case waifu2xAnime = "Waifu2x (Anime)"
    case realCUGANAnime = "Real-CUGAN (Anime)"
    case realESRGANAnime = "Real-ESRGAN (Anime)"
    case mangaClean = "ESRGAN (Manga & Clean)"
    case waifu2xPhoto = "Waifu2x (Photo)"
    case srmdPhoto = "SRMD (Photo & Universal)"
    case realESRGANUniversal = "Real-ESRGAN (Universal)"

    public var id: String { rawValue }

    public var isAnime: Bool {
        switch self {
        case .waifu2xAnime, .realCUGANAnime, .realESRGANAnime, .mangaClean: return true
        default: return false
        }
    }

    public var supportedScales: [Int] {
        switch self {
        case .waifu2xAnime, .waifu2xPhoto:
            return [2]
        case .realCUGANAnime, .srmdPhoto:
            return [2, 3, 4]
        case .mangaClean:
            return [1]
        case .realESRGANAnime, .realESRGANUniversal:
            return [4]
        }
    }

    public var supportsNoiseReduction: Bool {
        switch self {
        case .waifu2xAnime, .waifu2xPhoto, .realCUGANAnime:
            return true
        default:
            return false
        }
    }
}

/// Architecture families supported by Catscale
public enum ModelFamily: String, CaseIterable, Identifiable, Sendable {
    case waifu2x = "Waifu2x"
    case realCUGAN = "Real-CUGAN"
    case realESRGAN = "Real-ESRGAN"
    case esrganManga = "ESRGAN-Manga"
    case srmd = "SRMD"

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
    public let family: ModelFamily
    public let group: ModelGroup
    public let category: ModelCategory
    public let scale: Int
    public let noiseLevel: Int // -1 = none, 0..3 = noise reduction levels
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
        family: ModelFamily,
        group: ModelGroup,
        category: ModelCategory,
        scale: Int,
        noiseLevel: Int = -1,
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
        self.family = family
        self.group = group
        self.category = category
        self.scale = scale
        self.noiseLevel = noiseLevel
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
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 3,
        noiseLevel: 1,
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
        family: .realCUGAN,
        group: .realCUGANAnime,
        category: .anime,
        scale: 4,
        noiseLevel: 1,
        description: "4x anime upscaling with artifact removal.",
        compiledModelName: "RealCUGAN-4x-Denoise3",
        defaultTileSize: 256,
        recommendedOverlap: 19,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-4x-Denoise3.mlpackage.zip",
        downloadSizeMB: 2.5,
        uncompressedSizeMB: 2.8
    )

    // MARK: - SRMD Models (Photo & Universal)
    public static let srmd2x = ModelSpec(
        id: "srmd_2x",
        name: "SRMD 2x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 2,
        description: "2x realistic photo and texture restoration with blur kernel handling.",
        compiledModelName: "SRMDNF-2x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-2x.mlpackage.zip",
        downloadSizeMB: 2.7,
        uncompressedSizeMB: 2.9
    )

    public static let srmd3x = ModelSpec(
        id: "srmd_3x",
        name: "SRMD 3x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 3,
        description: "3x realistic photo and texture super-resolution.",
        compiledModelName: "SRMDNF-3x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-3x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    public static let srmd4x = ModelSpec(
        id: "srmd_4x",
        name: "SRMD 4x",
        family: .srmd,
        group: .srmdPhoto,
        category: .photo,
        scale: 4,
        description: "4x realistic photo super-resolution.",
        compiledModelName: "SRMDNF-4x",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-4x.mlpackage.zip",
        downloadSizeMB: 2.8,
        uncompressedSizeMB: 3.0
    )

    // MARK: - Real-ESRGAN Anime Models
    public static let realESRGANUltraSharp = ModelSpec(
        id: "realesrgan_ultrasharp_4x",
        name: "Real-ESRGAN UltraSharp 4x",
        family: .realESRGAN,
        group: .realESRGANAnime,
        category: .anime,
        scale: 4,
        description: "Ultra-sharp 4x anime & art upscaling with crisp edges.",
        compiledModelName: "RealESRGAN-UltraSharp",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML/resolve/main/RealESRGAN-UltraSharp.mlpackage.zip",
        downloadSizeMB: 29.5,
        uncompressedSizeMB: 32.5
    )

    // MARK: - ESRGAN Manga & Clean (1x Restoration)
    public static let mangaJPEGLQ = ModelSpec(
        id: "esrgan_manga_1x",
        name: "ESRGAN Manga Clean",
        family: .esrganManga,
        group: .mangaClean,
        category: .anime,
        scale: 1,
        description: "Manga and illustration clean-up with JPEG compression restoration.",
        compiledModelName: "ESRGAN-MangaJPEGLQ",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML/resolve/main/ESRGAN-MangaJPEGLQ.mlpackage.zip",
        downloadSizeMB: 8.9,
        uncompressedSizeMB: 9.8
    )

    // MARK: - Real-ESRGAN Universal Models
    public static let realESRGANx4Plus = ModelSpec(
        id: "realesrgan_x4plus",
        name: "Real-ESRGAN x4 Plus",
        family: .realESRGAN,
        group: .realESRGANUniversal,
        category: .photo,
        scale: 4,
        description: "Universal 4x super-resolution for textures, CGI, and photos.",
        compiledModelName: "RealESRGAN-x4plus",
        defaultTileSize: 256,
        recommendedOverlap: 16,
        downloadURLString: "https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML/resolve/main/RealESRGAN-x4plus.mlpackage.zip",
        downloadSizeMB: 29.6,
        uncompressedSizeMB: 32.5
    )

    // MARK: - Waifu2x Anime Models (Bundled in App Bundle)
    public static let waifu2xAnimeNoise0 = ModelSpec(
        id: "waifu2x_anime_noise0_2x",
        name: "Waifu2x Anime (No Denoise)",
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
        realESRGANUltraSharp,
        mangaJPEGLQ,
        srmd2x,
        srmd3x,
        srmd4x,
        waifu2xPhotoNoise1,
        waifu2xPhotoNoise2,
        realESRGANx4Plus
    ]

    /// Resolve model by group, scale, and noise level
    public static func resolve(group: ModelGroup, scale: Int, noiseLevel: Int = 1) -> ModelSpec {
        let matches = allModels.filter { $0.group == group && $0.scale == scale }
        if matches.isEmpty {
            return allModels.first { $0.group == group } ?? waifu2xAnimeNoise1
        }
        if group.supportsNoiseReduction {
            if let exact = matches.first(where: { $0.noiseLevel == noiseLevel }) {
                return exact
            }
        }
        return matches.first!
    }
}
