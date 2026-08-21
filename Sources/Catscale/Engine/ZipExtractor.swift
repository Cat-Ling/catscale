import Foundation
#if canImport(zlib)
import zlib
#endif

public enum ZipExtractorError: LocalizedError {
    case invalidZipData
    case decompressionFailed
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidZipData: return "Invalid or corrupted zip archive."
        case .decompressionFailed: return "Failed to decompress file inside archive."
        case .fileWriteFailed(let path): return "Failed to write extracted file to '\(path)'."
        }
    }
}

public enum ZipExtractor {

    private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }

    private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    /// Extract a .zip archive safely from source URL to destination directory
    public static func unzip(archiveAt sourceURL: URL, to destinationDirectory: URL) throws {
        let fileData = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var offset = 0
        let totalBytes = fileData.count

        while offset + 30 <= totalBytes {
            let signature = readUInt32(from: fileData, at: offset)
            
            // Check for Local File Header signature (0x04034b50)
            if signature != 0x04034b50 {
                break
            }

            let compressionMethod = readUInt16(from: fileData, at: offset + 8)
            let compressedSize = Int(readUInt32(from: fileData, at: offset + 18))
            let uncompressedSize = Int(readUInt32(from: fileData, at: offset + 22))
            let fileNameLength = Int(readUInt16(from: fileData, at: offset + 26))
            let extraFieldLength = Int(readUInt16(from: fileData, at: offset + 28))

            let fileNameOffset = offset + 30
            guard fileNameOffset + fileNameLength <= totalBytes,
                  let fileName = String(data: fileData.subdata(in: fileNameOffset..<(fileNameOffset + fileNameLength)), encoding: .utf8) else {
                break
            }

            let dataOffset = fileNameOffset + fileNameLength + extraFieldLength
            guard dataOffset + compressedSize <= totalBytes else {
                break
            }

            let filePayload = fileData.subdata(in: dataOffset..<(dataOffset + compressedSize))
            let targetURL = destinationDirectory.appendingPathComponent(fileName)

            if fileName.hasSuffix("/") {
                // Directory entry
                try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } else {
                // Create parent directory if needed
                try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                if compressionMethod == 0 {
                    // Stored (no compression)
                    try filePayload.write(to: targetURL)
                } else if compressionMethod == 8 {
                    // Deflated compression
                    let decompressed = try decompressDeflate(data: filePayload, uncompressedSize: uncompressedSize)
                    try decompressed.write(to: targetURL)
                }
            }

            offset = dataOffset + compressedSize
        }
    }

    /// Decompress raw Deflate stream using zlib
    private static func decompressDeflate(data: Data, uncompressedSize: Int) throws -> Data {
        #if canImport(zlib)
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw ZipExtractorError.decompressionFailed
        }
        defer { inflateEnd(&stream) }

        var outputData = Data(count: max(uncompressedSize, 64))
        var outputOffset = 0

        try data.withUnsafeBytes { srcBuffer in
            guard let srcPtr = srcBuffer.baseAddress else { return }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcPtr.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(data.count)

            while stream.avail_in > 0 {
                var currentCapacity = outputData.count
                if outputOffset >= currentCapacity {
                    outputData.count += max(currentCapacity, 8192)
                    currentCapacity = outputData.count
                }

                let remainingCapacity = currentCapacity - outputOffset
                let status = outputData.withUnsafeMutableBytes { dstBuffer -> Int32 in
                    guard let dstPtr = dstBuffer.baseAddress else { return Z_DATA_ERROR }
                    stream.next_out = dstPtr.advanced(by: outputOffset).assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(remainingCapacity)
                    return inflate(&stream, Z_NO_FLUSH)
                }

                guard status == Z_OK || status == Z_STREAM_END else {
                    throw ZipExtractorError.decompressionFailed
                }

                let produced = remainingCapacity - Int(stream.avail_out)
                outputOffset += produced

                if status == Z_STREAM_END {
                    break
                }
            }
        }

        outputData.count = outputOffset
        return outputData
        #else
        throw ZipExtractorError.decompressionFailed
        #endif
    }
}
