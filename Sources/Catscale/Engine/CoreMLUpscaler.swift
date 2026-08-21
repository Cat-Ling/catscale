import Foundation
import CoreML
import CoreGraphics
import Accelerate

public enum CoreMLError: LocalizedError {
    case modelNotFound(String)
    case invalidInputData
    case predictionFailed(String)
    case unsupportedShape(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found in app bundle or storage directory."
        case .invalidInputData:
            return "Failed to convert image chunk into model input tensor."
        case .predictionFailed(let reason):
            return "Core ML inference failed: \(reason)"
        case .unsupportedShape(let shape):
            return "Model tensor shape is unsupported: \(shape)"
        }
    }
}

/// Core ML Super-Resolution Inference Runner with universal N-dimensional tensor mapping, stride-safety, and multi-bundle discovery
public final class CoreMLUpscaler: @unchecked Sendable {

    private var activeModel: MLModel?
    private var loadedModelName: String?
    private var activeComputeUnits: MLComputeUnits?
    private let initialComputeUnits: MLComputeUnits

    public init(computeUnits: MLComputeUnits = .all) {
        self.initialComputeUnits = computeUnits
    }

    /// Load or retrieve cached Core ML model with JIT compilation caching
    public func loadModel(named modelName: String, forceComputeUnits: MLComputeUnits? = nil) throws -> MLModel {
        let targetUnits = forceComputeUnits ?? activeComputeUnits ?? initialComputeUnits
        if let model = activeModel, loadedModelName == modelName, activeComputeUnits == targetUnits {
            return model
        }

        let config = MLModelConfiguration()
        config.computeUnits = targetUnits
        config.allowLowPrecisionAccumulationOnGPU = (targetUnits != .cpuOnly)

        let fileManager = FileManager.default
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let compiledCacheDir = cachesURL.appendingPathComponent("CompiledModels")
        try? fileManager.createDirectory(at: compiledCacheDir, withIntermediateDirectories: true)

        let cachedCompiledURL = compiledCacheDir.appendingPathComponent("\(modelName).mlmodelc")

        // 1. Check if already pre-compiled in Cache
        if fileManager.fileExists(atPath: cachedCompiledURL.path) {
            if let model = try? MLModel(contentsOf: cachedCompiledURL, configuration: config) {
                self.activeModel = model
                self.loadedModelName = modelName
                self.activeComputeUnits = targetUnits
                AppLogger.shared.log("Loaded cached compiled model '\(modelName).mlmodelc' on \(targetUnits)", isEnabled: true)
                return model
            }
        }

        // 2. Locate source model URL across App Bundle, Resource Bundles, Frameworks, and Storage
        guard let sourceURL = findModelSourceURL(named: modelName) else {
            AppLogger.shared.log("Failed to find model source file for '\(modelName)'", level: .error, isEnabled: true)
            throw CoreMLError.modelNotFound(modelName)
        }

        AppLogger.shared.log("Found model file at: \(sourceURL.path)", isEnabled: true)

        let modelURLToLoad: URL
        if sourceURL.pathExtension.lowercased() == "mlmodelc" {
            modelURLToLoad = sourceURL
        } else {
            // JIT compile .mlmodel or .mlpackage
            AppLogger.shared.log("Compiling model '\(modelName)' to CoreML format...", isEnabled: true)
            let tempCompiledURL = try MLModel.compileModel(at: sourceURL)

            // Cache compiled model for future instant loads
            try? fileManager.removeItem(at: cachedCompiledURL)
            try? fileManager.copyItem(at: tempCompiledURL, to: cachedCompiledURL)

            modelURLToLoad = fileManager.fileExists(atPath: cachedCompiledURL.path) ? cachedCompiledURL : tempCompiledURL
        }

        let model = try MLModel(contentsOf: modelURLToLoad, configuration: config)
        self.activeModel = model
        self.loadedModelName = modelName
        self.activeComputeUnits = targetUnits
        AppLogger.shared.log("Successfully initialized MLModel '\(modelName)' on \(targetUnits)", isEnabled: true)
        return model
    }

    /// Recursively search across App Bundle, Resource Bundles, and Storage directories
    private func findModelSourceURL(named modelName: String) -> URL? {
        let fileManager = FileManager.default
        let targetName = modelName.lowercased()
        let extensions = ["mlmodelc", "mlpackage", "mlmodel"]

        // 1. Direct search in Bundle.main
        for ext in extensions {
            if let url = Bundle.main.url(forResource: modelName, withExtension: ext) {
                return url
            }
        }

        // 2. Recursive search in App Bundle directory (including Catscale_Catscale.bundle)
        var bundlePaths: [String] = [
            Bundle.main.bundlePath,
            Bundle.main.bundleURL.path
        ]
        if let resourcePath = Bundle.main.resourcePath {
            bundlePaths.append(resourcePath)
        }

        for bPath in bundlePaths {
            if let subpaths = try? fileManager.subpathsOfDirectory(atPath: bPath) {
                for relPath in subpaths {
                    let fullPath = URL(fileURLWithPath: bPath).appendingPathComponent(relPath)
                    let fileName = fullPath.lastPathComponent.lowercased()

                    for ext in extensions {
                        if fileName == "\(targetName).\(ext)" ||
                           fileName == targetName && fullPath.pathExtension.lowercased() == ext ||
                           (fileName.contains(targetName) && fullPath.pathExtension.lowercased() == ext) {
                            return fullPath
                        }
                    }
                }
            }
        }

        // 3. Search storage directories (Documents/Models, Caches/Models, etc.)
        let searchDirectories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Models")
        ].compactMap { $0 }

        for directory in searchDirectories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }

            for ext in extensions {
                let directPath = directory.appendingPathComponent("\(modelName).\(ext)")
                if fileManager.fileExists(atPath: directPath.path) {
                    return directPath
                }
            }

            if let subpaths = try? fileManager.subpathsOfDirectory(atPath: directory.path) {
                for relPath in subpaths {
                    let fullPath = directory.appendingPathComponent(relPath)
                    let fileName = fullPath.lastPathComponent.lowercased()

                    for ext in extensions {
                        if fileName == "\(targetName).\(ext)" ||
                           fileName == targetName && fullPath.pathExtension.lowercased() == ext ||
                           (fileName.contains(targetName) && fullPath.pathExtension.lowercased() == ext) {
                            return fullPath
                        }
                    }
                }
            }
        }

        return nil
    }

    public struct TileOutput: Sendable {
        public let rgb: [Float]
        public let width: Int
        public let height: Int

        public init(rgb: [Float], width: Int, height: Int) {
            self.rgb = rgb
            self.width = width
            self.height = height
        }
    }

    /// Predict single tile with universal N-D shape support (3D, 4D, 5D) and Float16/Float32/Double stride safety
    public func predictTile(
        rgbInput: [Float],
        width: Int,
        height: Int,
        scale: Int,
        modelName: String
    ) throws -> TileOutput {
        let model = try loadModel(named: modelName)

        // 1. Inspect Model Input Feature
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        guard let inputName = inputDescriptions.keys.first,
              let inputFeatureDesc = inputDescriptions[inputName] else {
            throw CoreMLError.invalidInputData
        }

        let inputConstraint = inputFeatureDesc.multiArrayConstraint
        let inputRank = inputConstraint?.shape.count ?? 4
        let inputDataType = inputConstraint?.dataType ?? .float32

        var reqWidth = width
        var reqHeight = height

        if let shapeConstraint = inputConstraint?.shapeConstraint {
            switch shapeConstraint.type {
            case .range:
                // Dynamic range model (Real-CUGAN, Real-ESRGAN, SRMD): use requested tile size within bounds
                if let ranges = shapeConstraint.sizeRangeForDimension as? [NSRange], ranges.count >= 2 {
                    let hRange = ranges[ranges.count - 2]
                    let wRange = ranges[ranges.count - 1]
                    let minH = hRange.location
                    let maxH = hRange.location + hRange.length
                    let minW = wRange.location
                    let maxW = wRange.location + wRange.length
                    reqHeight = min(max(minH, height), maxH)
                    reqWidth = min(max(minW, width), maxW)
                }
            case .enumerated:
                // Pick matching or closest enumerated shape
                let shapes = shapeConstraint.enumeratedShapes
                let matching = shapes.first { shape in
                    let h = shape[shape.count - 2].intValue
                    let w = shape[shape.count - 1].intValue
                    return h == height && w == width
                } ?? shapes.first
                if let chosen = matching {
                    reqHeight = chosen[chosen.count - 2].intValue
                    reqWidth = chosen[chosen.count - 1].intValue
                }
            case .unspecified:
                // Fixed shape model (e.g. Waifu2x Caffe 156x156)
                if let shape = inputConstraint?.shape.map({ $0.intValue }), !shape.isEmpty {
                    let fixedH = shape[shape.count - 2]
                    let fixedW = shape[shape.count - 1]
                    if fixedH > 0 { reqHeight = fixedH }
                    if fixedW > 0 { reqWidth = fixedW }
                }
            @unknown default:
                break
            }
        } else if let shape = inputConstraint?.shape.map({ $0.intValue }), !shape.isEmpty {
            let fixedH = shape[shape.count - 2]
            let fixedW = shape[shape.count - 1]
            if fixedH > 0 { reqHeight = fixedH }
            if fixedW > 0 { reqWidth = fixedW }
        }

        // Build Input Shape matching model rank (3D, 4D, 5D)
        let shape: [NSNumber]
        switch inputRank {
        case 5:
            // [1, 1, 3, H, W]
            shape = [1, 1, 3, NSNumber(value: reqHeight), NSNumber(value: reqWidth)]
        case 3:
            // [3, H, W]
            shape = [3, NSNumber(value: reqHeight), NSNumber(value: reqWidth)]
        default:
            // [1, 3, H, W]
            shape = [1, 3, NSNumber(value: reqHeight), NSNumber(value: reqWidth)]
        }

        let inputArray = try MLMultiArray(shape: shape, dataType: inputDataType)
        let inputStrides = inputArray.strides.map { $0.intValue }

        let strideC: Int
        let strideH: Int
        let strideW: Int

        switch inputRank {
        case 5:
            strideC = inputStrides[2]
            strideH = inputStrides[3]
            strideW = inputStrides[4]
        case 3:
            strideC = inputStrides[0]
            strideH = inputStrides[1]
            strideW = inputStrides[2]
        default:
            strideC = inputStrides[1]
            strideH = inputStrides[2]
            strideW = inputStrides[3]
        }

        let srcTotal = width * height

        // Populate Input Tensor with Edge Clamping (safe across Float32, Float16, and Double)
        if inputDataType == .float16 {
            let ptr = inputArray.dataPointer.bindMemory(to: Float16.self, capacity: inputArray.count)
            for c in 0..<3 {
                let srcOffset = c * srcTotal
                let cOffset = c * strideC
                for y in 0..<reqHeight {
                    let clampedY = min(y, height - 1)
                    let yOffset = cOffset + y * strideH
                    let srcRowOffset = srcOffset + clampedY * width
                    for x in 0..<reqWidth {
                        let clampedX = min(x, width - 1)
                        let srcVal = rgbInput[srcRowOffset + clampedX]
                        ptr[yOffset + x * strideW] = Float16(srcVal)
                    }
                }
            }
        } else if inputDataType == .double {
            let ptr = inputArray.dataPointer.bindMemory(to: Double.self, capacity: inputArray.count)
            for c in 0..<3 {
                let srcOffset = c * srcTotal
                let cOffset = c * strideC
                for y in 0..<reqHeight {
                    let clampedY = min(y, height - 1)
                    let yOffset = cOffset + y * strideH
                    let srcRowOffset = srcOffset + clampedY * width
                    for x in 0..<reqWidth {
                        let clampedX = min(x, width - 1)
                        let srcVal = rgbInput[srcRowOffset + clampedX]
                        ptr[yOffset + x * strideW] = Double(srcVal)
                    }
                }
            }
        } else {
            let ptr = inputArray.dataPointer.bindMemory(to: Float.self, capacity: inputArray.count)
            for c in 0..<3 {
                let srcOffset = c * srcTotal
                let cOffset = c * strideC
                for y in 0..<reqHeight {
                    let clampedY = min(y, height - 1)
                    let yOffset = cOffset + y * strideH
                    let srcRowOffset = srcOffset + clampedY * width
                    for x in 0..<reqWidth {
                        let clampedX = min(x, width - 1)
                        let srcVal = rgbInput[srcRowOffset + clampedX]
                        ptr[yOffset + x * strideW] = srcVal
                    }
                }
            }
        }

        // 2. Execute Model Inference with Automatic Compute Unit Fallback
        let featureProvider = try MLDictionaryFeatureProvider(dictionary: [inputName: inputArray])
        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: featureProvider)
        } catch {
            let errorMsg = error.localizedDescription
            AppLogger.shared.log("Inference failed on \(activeComputeUnits ?? initialComputeUnits) (\(errorMsg)). Attempting fallback...", level: .warning, isEnabled: true)

            if activeComputeUnits != .cpuAndGPU {
                do {
                    let fallbackModel = try loadModel(named: modelName, forceComputeUnits: .cpuAndGPU)
                    prediction = try fallbackModel.prediction(from: featureProvider)
                    AppLogger.shared.log("Inference succeeded on Metal GPU fallback (.cpuAndGPU)", isEnabled: true)
                } catch {
                    AppLogger.shared.log("GPU fallback failed (\(error.localizedDescription)). Attempting CPU fallback...", level: .warning, isEnabled: true)
                    let cpuModel = try loadModel(named: modelName, forceComputeUnits: .cpuOnly)
                    prediction = try cpuModel.prediction(from: featureProvider)
                    AppLogger.shared.log("Inference succeeded on CPU fallback (.cpuOnly)", isEnabled: true)
                }
            } else {
                let cpuModel = try loadModel(named: modelName, forceComputeUnits: .cpuOnly)
                prediction = try cpuModel.prediction(from: featureProvider)
                AppLogger.shared.log("Inference succeeded on CPU fallback (.cpuOnly)", isEnabled: true)
            }
        }

        // 3. Inspect Output Feature
        let outputDescriptions = model.modelDescription.outputDescriptionsByName
        guard let outputName = outputDescriptions.keys.first,
              let outputFeature = prediction.featureValue(for: outputName),
              let outputArray = outputFeature.multiArrayValue else {
            throw CoreMLError.predictionFailed("Output feature '\(outputDescriptions.keys.first ?? "")' is not an MLMultiArray")
        }

        let outShape = outputArray.shape.map { $0.intValue }
        let outStrides = outputArray.strides.map { $0.intValue }

        guard outShape.count >= 2 else {
            throw CoreMLError.unsupportedShape("\(outShape)")
        }

        // Identify Channel dimension and Spatial (H, W) dimensions
        let channelIdx: Int
        let heightIdx: Int
        let widthIdx: Int

        if outShape.last == 3 {
            // Channel-Last: e.g. [..., H, W, 3]
            channelIdx = outShape.count - 1
            heightIdx = outShape.count - 3
            widthIdx = outShape.count - 2
        } else if let firstThree = outShape.firstIndex(of: 3) {
            // Channel-First: e.g. [3, H, W], [1, 3, H, W], or [1, 1, 3, H, W]
            channelIdx = firstThree
            heightIdx = outShape.count - 2
            widthIdx = outShape.count - 1
        } else {
            channelIdx = max(0, outShape.count - 3)
            heightIdx = outShape.count - 2
            widthIdx = outShape.count - 1
        }

        let outStrideC = outStrides[channelIdx]
        let outStrideH = outStrides[heightIdx]
        let outStrideW = outStrides[widthIdx]

        let producedH = outShape[heightIdx]
        let producedW = outShape[widthIdx]
        let producedTotal = producedH * producedW

        var rawTileRGB = [Float](repeating: 0, count: producedTotal * 3)

        // Read raw produced pixel grid and auto-normalize range (0..1 vs 0..255)
        if outputArray.dataType == .double {
            let outPtr = outputArray.dataPointer.bindMemory(to: Double.self, capacity: outputArray.count)
            for c in 0..<3 {
                let dstOffset = c * producedTotal
                let cOffset = c * outStrideC
                for y in 0..<producedH {
                    let yOffset = cOffset + y * outStrideH
                    let dstRowOffset = dstOffset + y * producedW
                    for x in 0..<producedW {
                        let val = Float(outPtr[yOffset + x * outStrideW])
                        let normVal = val > 1.05 ? val / 255.0 : val
                        rawTileRGB[dstRowOffset + x] = min(max(normVal, 0.0), 1.0)
                    }
                }
            }
        } else if outputArray.dataType == .float16 {
            let outPtr = outputArray.dataPointer.bindMemory(to: Float16.self, capacity: outputArray.count)
            for c in 0..<3 {
                let dstOffset = c * producedTotal
                let cOffset = c * outStrideC
                for y in 0..<producedH {
                    let yOffset = cOffset + y * outStrideH
                    let dstRowOffset = dstOffset + y * producedW
                    for x in 0..<producedW {
                        let val = Float(outPtr[yOffset + x * outStrideW])
                        let normVal = val > 1.05 ? val / 255.0 : val
                        rawTileRGB[dstRowOffset + x] = min(max(normVal, 0.0), 1.0)
                    }
                }
            }
        } else {
            let outPtr = outputArray.dataPointer.bindMemory(to: Float.self, capacity: outputArray.count)
            for c in 0..<3 {
                let dstOffset = c * producedTotal
                let cOffset = c * outStrideC
                for y in 0..<producedH {
                    let yOffset = cOffset + y * outStrideH
                    let dstRowOffset = dstOffset + y * producedW
                    for x in 0..<producedW {
                        let val = outPtr[yOffset + x * outStrideW]
                        let normVal = val > 1.05 ? val / 255.0 : val
                        rawTileRGB[dstRowOffset + x] = min(max(normVal, 0.0), 1.0)
                    }
                }
            }
        }

        return TileOutput(rgb: rawTileRGB, width: producedW, height: producedH)
    }

    /// Unload model from RAM/ANE to free memory
    public func unload() {
        activeModel = nil
        loadedModelName = nil
    }
}
