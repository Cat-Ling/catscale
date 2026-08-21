import Foundation
import CoreGraphics
import UIKit
import CoreML

public struct UpscaleProgress: Sendable {
    public let fraction: Double
    public let statusMessage: String
    public let currentTile: Int
    public let totalTiles: Int
}

public actor UpscalerEngine {

    private let coreMLRunner: CoreMLUpscaler
    private var isCancelled: Bool = false

    public init(computeUnits: MLComputeUnits = .all) {
        self.coreMLRunner = CoreMLUpscaler(computeUnits: computeUnits)
    }

    /// Cancel any running upscale task
    public func cancel() {
        self.isCancelled = true
    }

    /// Perform full super-resolution upscale on a UIImage
    public func upscale(
        image: UIImage,
        model: ModelSpec,
        tileSize: Int? = nil,
        overlapMargin: Int? = nil,
        onProgress: @Sendable (UpscaleProgress) -> Void
    ) async throws -> UIImage {
        self.isCancelled = false

        guard let cgImage = image.cgImage else {
            throw CoreMLError.invalidInputData
        }

        onProgress(UpscaleProgress(
            fraction: 0.05,
            statusMessage: "Extracting color and alpha channels...",
            currentTile: 0,
            totalTiles: 1
        ))

        guard let (rgb, alpha, srcWidth, srcHeight) = ImageUtils.extractChannels(from: cgImage) else {
            throw CoreMLError.invalidInputData
        }

        let scale = model.scale
        let outWidth = srcWidth * scale
        let outHeight = srcHeight * scale
        let totalOutPixels = outWidth * outHeight

        // Process alpha in background
        var outAlpha: [UInt8]? = nil
        if let alpha = alpha {
            outAlpha = ImageUtils.resizeAlpha(
                alpha: alpha,
                srcWidth: srcWidth,
                srcHeight: srcHeight,
                dstWidth: outWidth,
                dstHeight: outHeight
            )
        }

        // Allocate canvas for destination RGB
        var dstRGB = [Float](repeating: 0, count: totalOutPixels * 3)

        if model.family == .waifu2x {
            // MARK: - Native Waifu2x Caffe Pipeline (imxieyi/waifu2x-ios standard)
            try await upscaleWaifu2x(
                rgb: rgb,
                srcWidth: srcWidth,
                srcHeight: srcHeight,
                outWidth: outWidth,
                outHeight: outHeight,
                model: model,
                dstRGB: &dstRGB,
                onProgress: onProgress
            )
        } else {
            // MARK: - Universal Overlap Pipeline (Real-CUGAN, Real-ESRGAN, SRMD)
            let effectiveTileSize = tileSize ?? model.defaultTileSize
            let effectiveOverlap = overlapMargin ?? model.recommendedOverlap

            let tiler = ImageTiler(
                tileSize: effectiveTileSize,
                overlap: effectiveOverlap,
                scale: scale
            )

            let tiles = tiler.generateTiles(width: srcWidth, height: srcHeight)
            let totalTiles = tiles.count

            for (index, tile) in tiles.enumerated() {
                if Task.isCancelled || isCancelled {
                    throw CancellationError()
                }

                let tileProgress = 0.1 + (0.8 * Double(index) / Double(max(totalTiles, 1)))
                onProgress(UpscaleProgress(
                    fraction: tileProgress,
                    statusMessage: "Processing tile \(index + 1) of \(totalTiles)...",
                    currentTile: index + 1,
                    totalTiles: totalTiles
                ))

                let cropRect = tile.cropRect
                let tileCropW = Int(cropRect.size.width)
                let tileCropH = Int(cropRect.size.height)

                let tileRGB = tiler.cropTile(
                    from: rgb,
                    srcWidth: srcWidth,
                    srcHeight: srcHeight,
                    rect: cropRect
                )

                let tileOutput = try coreMLRunner.predictTile(
                    rgbInput: tileRGB,
                    width: tileCropW,
                    height: tileCropH,
                    scale: scale,
                    modelName: model.compiledModelName
                )

                tiler.mergeTile(
                    tileRGB: tileOutput.rgb,
                    tileWidth: tileOutput.width,
                    tileHeight: tileOutput.height,
                    into: &dstRGB,
                    dstWidth: outWidth,
                    dstHeight: outHeight,
                    tile: tile
                )
            }
        }

        onProgress(UpscaleProgress(
            fraction: 0.95,
            statusMessage: "Reconstructing high-resolution image...",
            currentTile: 1,
            totalTiles: 1
        ))

        guard let outputCGImage = ImageUtils.createCGImage(
            from: dstRGB,
            alpha: outAlpha,
            width: outWidth,
            height: outHeight
        ) else {
            throw CoreMLError.invalidInputData
        }

        onProgress(UpscaleProgress(
            fraction: 1.0,
            statusMessage: "Upscaling complete!",
            currentTile: 1,
            totalTiles: 1
        ))

        return UIImage(cgImage: outputCGImage, scale: 1.0, orientation: image.imageOrientation)
    }

    /// Dedicated Waifu2x Caffe execution engine matching reference imxieyi/waifu2x-ios
    private func upscaleWaifu2x(
        rgb: [Float],
        srcWidth: Int,
        srcHeight: Int,
        outWidth: Int,
        outHeight: Int,
        model: ModelSpec,
        dstRGB: inout [Float],
        onProgress: @Sendable (UpscaleProgress) -> Void
    ) async throws {
        let blockSize = 142
        let shrinkSize = 7
        let inputBlockSize = blockSize + 2 * shrinkSize // 156
        let scale = 2

        // 1. Expand image by shrinkSize (7px) on all 4 borders with edge replication
        let expW = srcWidth + 2 * shrinkSize
        let expH = srcHeight + 2 * shrinkSize
        var expRGB = [Float](repeating: 0, count: expW * expH * 3)

        for c in 0..<3 {
            let srcOffset = c * srcWidth * srcHeight
            let expOffset = c * expW * expH
            for y in 0..<expH {
                let clampedY = min(max(0, y - shrinkSize), srcHeight - 1)
                let expRow = expOffset + y * expW
                let srcRow = srcOffset + clampedY * srcWidth
                for x in 0..<expW {
                    let clampedX = min(max(0, x - shrinkSize), srcWidth - 1)
                    expRGB[expRow + x] = rgb[srcRow + clampedX]
                }
            }
        }

        // 2. Compute crop coordinates (142px step + right/bottom boundary alignments)
        let numW = srcWidth / blockSize
        let numH = srcHeight / blockSize
        let exW = srcWidth % blockSize
        let exH = srcHeight % blockSize

        var rects: [(x: Int, y: Int)] = []
        for j in 0..<numH {
            for i in 0..<numW {
                rects.append((x: i * blockSize, y: j * blockSize))
            }
        }
        if exW > 0 {
            let x = max(0, srcWidth - blockSize)
            for j in 0..<numH {
                rects.append((x: x, y: j * blockSize))
            }
        }
        if exH > 0 {
            let y = max(0, srcHeight - blockSize)
            for i in 0..<numW {
                rects.append((x: i * blockSize, y: y))
            }
        }
        if exW > 0 && exH > 0 {
            rects.append((x: max(0, srcWidth - blockSize), y: max(0, srcHeight - blockSize)))
        }
        if rects.isEmpty {
            rects.append((x: 0, y: 0))
        }

        let totalTiles = rects.count

        // 3. Process each 156x156 patch and write directly to destination
        for (index, rect) in rects.enumerated() {
            if Task.isCancelled || isCancelled {
                throw CancellationError()
            }

            let tileProgress = 0.1 + (0.8 * Double(index) / Double(max(totalTiles, 1)))
            onProgress(UpscaleProgress(
                fraction: tileProgress,
                statusMessage: "Waifu2x tile \(index + 1) of \(totalTiles)...",
                currentTile: index + 1,
                totalTiles: totalTiles
            ))

            let cropX = rect.x
            let cropY = rect.y

            var tileInput = [Float](repeating: 0, count: inputBlockSize * inputBlockSize * 3)
            for c in 0..<3 {
                let expOffset = c * expW * expH
                let tileOffset = c * inputBlockSize * inputBlockSize
                for dy in 0..<inputBlockSize {
                    let clampedExpY = min(cropY + dy, expH - 1)
                    let expRow = expOffset + clampedExpY * expW
                    let tileRow = tileOffset + dy * inputBlockSize
                    for dx in 0..<inputBlockSize {
                        let clampedExpX = min(cropX + dx, expW - 1)
                        tileInput[tileRow + dx] = expRGB[expRow + clampedExpX]
                    }
                }
            }

            let tileOutput = try coreMLRunner.predictTile(
                rgbInput: tileInput,
                width: inputBlockSize,
                height: inputBlockSize,
                scale: scale,
                modelName: model.compiledModelName
            )

            let originX = cropX * scale
            let originY = cropY * scale
            let tileW = tileOutput.width
            let tileH = tileOutput.height
            let tileTotal = tileW * tileH
            let dstTotal = outWidth * outHeight

            for c in 0..<3 {
                let tileOffset = c * tileTotal
                let dstOffset = c * dstTotal
                for dy in 0..<tileH {
                    let dstY = originY + dy
                    guard dstY < outHeight else { continue }
                    let dstRow = dstOffset + dstY * outWidth
                    let tileRow = tileOffset + dy * tileW
                    for dx in 0..<tileW {
                        let dstX = originX + dx
                        guard dstX < outWidth else { continue }
                        dstRGB[dstRow + dstX] = tileOutput.rgb[tileRow + dx]
                    }
                }
            }
        }
    }

    /// Free resources
    public func cleanup() {
        coreMLRunner.unload()
    }
}
