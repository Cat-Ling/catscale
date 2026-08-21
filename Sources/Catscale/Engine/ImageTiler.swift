import Foundation
import CoreGraphics

/// Definition of an image tile with overlap margins
public struct ImageTile: Sendable {
    public let index: Int
    public let cropRect: CGRect         // Area to crop from source image (including overlap)
    public let innerRect: CGRect        // Usable area in source coordinates (excluding overlap)
    public let targetRect: CGRect       // Target area in destination canvas
}

/// Intelligent tiler that splits high-resolution images into overlapping tiles to prevent iOS OOMs
public final class ImageTiler: Sendable {

    public let tileSize: Int
    public let overlap: Int
    public let scale: Int

    public init(tileSize: Int = 256, overlap: Int = 16, scale: Int = 2) {
        self.tileSize = tileSize
        self.overlap = overlap
        self.scale = scale
    }

    /// Decompose an image size into a grid of overlapping tiles with continuous non-overlapping target coverage
    public func generateTiles(width: Int, height: Int) -> [ImageTile] {
        var tiles: [ImageTile] = []
        let step = tileSize - (2 * overlap)
        var tileIndex = 0

        var curY = 0
        while curY < height {
            let cropY: Int
            let innerY: Int
            let innerMaxY: Int

            if curY == 0 {
                cropY = 0
                innerY = 0
                innerMaxY = tileSize < height ? (tileSize - overlap) : height
            } else if curY + tileSize - overlap < height {
                cropY = curY - overlap
                innerY = curY
                innerMaxY = curY + step
            } else {
                cropY = max(0, height - tileSize)
                innerY = curY
                innerMaxY = height
            }

            var curX = 0
            while curX < width {
                let cropX: Int
                let innerX: Int
                let innerMaxX: Int

                if curX == 0 {
                    cropX = 0
                    innerX = 0
                    innerMaxX = tileSize < width ? (tileSize - overlap) : width
                } else if curX + tileSize - overlap < width {
                    cropX = curX - overlap
                    innerX = curX
                    innerMaxX = curX + step
                } else {
                    cropX = max(0, width - tileSize)
                    innerX = curX
                    innerMaxX = width
                }

                let cropW = min(tileSize, width - cropX)
                let cropH = min(tileSize, height - cropY)
                let innerW = innerMaxX - innerX
                let innerH = innerMaxY - innerY

                let cropRect = CGRect(
                    x: cropX,
                    y: cropY,
                    width: cropW,
                    height: cropH
                )

                let innerRect = CGRect(
                    x: innerX,
                    y: innerY,
                    width: innerW,
                    height: innerH
                )

                let targetRect = CGRect(
                    x: innerX * scale,
                    y: innerY * scale,
                    width: innerW * scale,
                    height: innerH * scale
                )

                tiles.append(ImageTile(
                    index: tileIndex,
                    cropRect: cropRect,
                    innerRect: innerRect,
                    targetRect: targetRect
                ))

                tileIndex += 1
                curX = innerMaxX
            }

            curY = innerMaxY
        }

        return tiles
    }

    /// Extract a planar RGB sub-tile from the main planar RGB image
    public func cropTile(
        from srcRGB: [Float],
        srcWidth: Int,
        srcHeight: Int,
        rect: CGRect
    ) -> [Float] {
        let cropX = Int(rect.origin.x)
        let cropY = Int(rect.origin.y)
        let cropW = Int(rect.size.width)
        let cropH = Int(rect.size.height)
        let srcTotal = srcWidth * srcHeight
        let dstTotal = cropW * cropH

        var tileRGB = [Float](repeating: 0, count: dstTotal * 3)

        for dy in 0..<cropH {
            let sy = cropY + dy
            for dx in 0..<cropW {
                let sx = cropX + dx
                let srcIndex = sy * srcWidth + sx
                let dstIndex = dy * cropW + dx

                tileRGB[dstIndex] = srcRGB[srcIndex]                               // Red
                tileRGB[dstTotal + dstIndex] = srcRGB[srcTotal + srcIndex]         // Green
                tileRGB[2 * dstTotal + dstIndex] = srcRGB[2 * srcTotal + srcIndex] // Blue
            }
        }

        return tileRGB
    }

    /// Blend/Merge an upscaled tile result into the output destination canvas
    public func mergeTile(
        tileRGB: [Float],
        tileWidth: Int,
        tileHeight: Int,
        into dstRGB: inout [Float],
        dstWidth: Int,
        dstHeight: Int,
        tile: ImageTile
    ) {
        let expectedFullW = Int(tile.cropRect.size.width) * scale
        let isModelTrimmed = tileWidth < expectedFullW

        let srcInnerX: Int
        let srcInnerY: Int

        if isModelTrimmed {
            // Model convolution already dropped the overlap border (e.g. Waifu2x Caffe)
            srcInnerX = 0
            srcInnerY = 0
        } else {
            // Full-field model (Real-ESRGAN, Real-CUGAN, SRMD)
            srcInnerX = Int((tile.innerRect.origin.x - tile.cropRect.origin.x) * CGFloat(scale))
            srcInnerY = Int((tile.innerRect.origin.y - tile.cropRect.origin.y) * CGFloat(scale))
        }

        let copyW = min(max(0, tileWidth - srcInnerX), Int(tile.targetRect.size.width))
        let copyH = min(max(0, tileHeight - srcInnerY), Int(tile.targetRect.size.height))
        let dstOriginX = Int(tile.targetRect.origin.x)
        let dstOriginY = Int(tile.targetRect.origin.y)

        let srcTotal = tileWidth * tileHeight
        let dstTotal = dstWidth * dstHeight

        guard copyW > 0, copyH > 0 else { return }

        for dy in 0..<copyH {
            let sy = srcInnerY + dy
            let targetY = dstOriginY + dy
            if targetY >= dstHeight { continue }

            for dx in 0..<copyW {
                let sx = srcInnerX + dx
                let targetX = dstOriginX + dx
                if targetX >= dstWidth { continue }

                let srcIndex = sy * tileWidth + sx
                let dstIndex = targetY * dstWidth + targetX

                if srcIndex < srcTotal && dstIndex < dstTotal {
                    dstRGB[dstIndex] = tileRGB[srcIndex]
                    dstRGB[dstTotal + dstIndex] = tileRGB[srcTotal + srcIndex]
                    dstRGB[2 * dstTotal + dstIndex] = tileRGB[2 * srcTotal + srcIndex]
                }
            }
        }
    }
}
