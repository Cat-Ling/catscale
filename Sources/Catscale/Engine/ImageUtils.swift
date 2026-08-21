import Foundation
import CoreGraphics
import Accelerate
import UIKit
import Photos

public enum ImageUtils {

    /// Extract RGB and Alpha channels from a CGImage
    public static func extractChannels(from image: CGImage) -> (rgb: [Float], alpha: [UInt8]?, width: Int, height: Int)? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let totalPixels = width * height
        var rgbPlanar = [Float](repeating: 0, count: totalPixels * 3)
        var alphaPlanar: [UInt8]? = nil

        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst
        if hasAlpha {
            alphaPlanar = [UInt8](repeating: 255, count: totalPixels)
        }

        // Convert interleaved RGBA to planar Float32 RGB [0.0...1.0] and Alpha [0...255]
        for i in 0..<totalPixels {
            let offset = i * bytesPerPixel
            let r = rawData[offset]
            let g = rawData[offset + 1]
            let b = rawData[offset + 2]
            let a = rawData[offset + 3]

            // Planar format: RRR... GGG... BBB...
            rgbPlanar[i] = Float(r) / 255.0
            rgbPlanar[totalPixels + i] = Float(g) / 255.0
            rgbPlanar[2 * totalPixels + i] = Float(b) / 255.0

            if hasAlpha {
                alphaPlanar?[i] = a
            }
        }

        return (rgbPlanar, alphaPlanar, width, height)
    }

    /// Create a CGImage from planar Float32 RGB and optional Alpha
    public static func createCGImage(
        from rgb: [Float],
        alpha: [UInt8]?,
        width: Int,
        height: Int
    ) -> CGImage? {
        let totalPixels = width * height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rgbaData = [UInt8](repeating: 255, count: totalPixels * bytesPerPixel)

        for i in 0..<totalPixels {
            let r = min(max(rgb[i] * 255.0, 0.0), 255.0)
            let g = min(max(rgb[totalPixels + i] * 255.0, 0.0), 255.0)
            let b = min(max(rgb[2 * totalPixels + i] * 255.0, 0.0), 255.0)
            let a = alpha?[i] ?? 255

            let offset = i * bytesPerPixel
            if alpha != nil {
                let alphaFactor = Float(a) / 255.0
                rgbaData[offset] = UInt8(r * alphaFactor)
                rgbaData[offset + 1] = UInt8(g * alphaFactor)
                rgbaData[offset + 2] = UInt8(b * alphaFactor)
            } else {
                rgbaData[offset] = UInt8(r)
                rgbaData[offset + 1] = UInt8(g)
                rgbaData[offset + 2] = UInt8(b)
            }
            rgbaData[offset + 3] = a
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let alphaInfo: CGImageAlphaInfo = (alpha != nil) ? .premultipliedLast : .noneSkipLast
        let bitmapInfo: UInt32 = alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let provider = CGDataProvider(data: Data(rgbaData) as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// High quality Lanczos/Bicubic upscale of alpha channel using vImage
    public static func resizeAlpha(
        alpha: [UInt8],
        srcWidth: Int,
        srcHeight: Int,
        dstWidth: Int,
        dstHeight: Int
    ) -> [UInt8] {
        var srcAlpha = alpha
        var dstAlpha = [UInt8](repeating: 255, count: dstWidth * dstHeight)

        srcAlpha.withUnsafeMutableBytes { srcRaw in
            dstAlpha.withUnsafeMutableBytes { dstRaw in
                var srcBuffer = vImage_Buffer(
                    data: srcRaw.baseAddress,
                    height: vImagePixelCount(srcHeight),
                    width: vImagePixelCount(srcWidth),
                    rowBytes: srcWidth
                )

                var dstBuffer = vImage_Buffer(
                    data: dstRaw.baseAddress,
                    height: vImagePixelCount(dstHeight),
                    width: vImagePixelCount(dstWidth),
                    rowBytes: dstWidth
                )

                _ = vImageScale_Planar8(
                    &srcBuffer,
                    &dstBuffer,
                    nil,
                    vImage_Flags(kvImageHighQualityResampling)
                )
            }
        }

        return dstAlpha
    }

    /// Downsample large UIImage for smooth preview performance
    public static func downsample(image: UIImage, to pointSize: CGSize, scale: CGFloat = 2.0) -> UIImage {
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else {
            return image
        }

        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return image
        }

        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return image
        }

        return UIImage(cgImage: downsampledImage)
    }

    /// Save an image to the iOS Photo Library asynchronously
    public static func saveToPhotoLibrary(image: UIImage) async throws {
        _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
