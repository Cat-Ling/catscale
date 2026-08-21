import SwiftUI
import PhotosUI
import CoreML

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG (Lossless)"
    case jpeg = "JPEG"
    case heic = "HEIC (High Efficiency)"
    case webp = "WebP"

    public var id: String { rawValue }
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .webp: return "webp"
        }
    }

    public var supportsQualityAdjustment: Bool {
        self != .png
    }
}

public enum ExportQuality: Double, CaseIterable, Identifiable, Sendable {
    case maximum = 1.0
    case recommended = 0.95
    case high = 0.90
    case balanced = 0.85
    case compact = 0.75

    public var id: Double { rawValue }
    public var displayName: String {
        switch self {
        case .maximum: return "100% (Maximum Quality)"
        case .recommended: return "95% (Recommended)"
        case .high: return "90% (High Quality)"
        case .balanced: return "85% (Balanced)"
        case .compact: return "75% (Compact File Size)"
        }
    }
}

public struct BatchItem: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let originalImage: UIImage
    public var upscaledImage: UIImage?
    public var status: ItemStatus = .pending
    public var progress: Double = 0.0
    public var errorMessage: String?

    public enum ItemStatus: String, Sendable {
        case pending = "Queued"
        case processing = "Processing"
        case completed = "Done"
        case failed = "Failed"
    }

    public init(originalImage: UIImage) {
        self.originalImage = originalImage
    }
}

@Observable
@MainActor
public final class AppState {

    // MARK: - Single Image State
    public var inputImage: UIImage?
    public var upscaledImage: UIImage?
    public var selectedModel: ModelSpec = ModelRegistry.waifu2xAnimeNoise1
    public var isProcessing: Bool = false
    public var progressFraction: Double = 0.0
    public var statusText: String = "Ready"
    public var elapsedTime: TimeInterval = 0.0
    public var errorMessage: String?

    // MARK: - Batch Queue State
    public var batchQueue: [BatchItem] = []
    public var isBatchProcessing: Bool = false
    public var batchCurrentIndex: Int = 0

    // MARK: - Settings (Persisted via UserDefaults)
    public var computeUnitsSelection: MLComputeUnits {
        didSet {
            UserDefaults.standard.set(computeUnitsSelection.rawValue, forKey: "computeUnitsSelection")
            updateEngineComputeUnits()
        }
    }
    public var exportFormat: ExportFormat {
        didSet { UserDefaults.standard.set(exportFormat.rawValue, forKey: "exportFormat") }
    }
    public var exportQuality: ExportQuality {
        didSet { UserDefaults.standard.set(exportQuality.rawValue, forKey: "exportQuality") }
    }
    public var autoSaveToLibrary: Bool {
        didSet { UserDefaults.standard.set(autoSaveToLibrary, forKey: "autoSaveToLibrary") }
    }
    public var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    public var loggingEnabled: Bool {
        didSet { UserDefaults.standard.set(loggingEnabled, forKey: "loggingEnabled") }
    }
    public var syncGapMode: SyncGapMode {
        didSet { UserDefaults.standard.set(syncGapMode.rawValue, forKey: "syncGapMode") }
    }

    // MARK: - Engine Actor
    private var engine: UpscalerEngine
    private var processingTask: Task<Void, Never>?

    public init() {
        let computeUnits: MLComputeUnits
        if let savedObject = UserDefaults.standard.object(forKey: "computeUnitsSelection") as? Int,
           let decodedUnits = MLComputeUnits(rawValue: savedObject) {
            computeUnits = decodedUnits
        } else {
            computeUnits = .all
        }
        self.computeUnitsSelection = computeUnits

        if let savedFormatRaw = UserDefaults.standard.string(forKey: "exportFormat"),
           let format = ExportFormat(rawValue: savedFormatRaw) {
            self.exportFormat = format
        } else {
            self.exportFormat = .png
        }

        if let savedQualityVal = UserDefaults.standard.object(forKey: "exportQuality") as? Double,
           let quality = ExportQuality(rawValue: savedQualityVal) {
            self.exportQuality = quality
        } else {
            self.exportQuality = .recommended
        }

        if let savedSyncGap = UserDefaults.standard.string(forKey: "syncGapMode"),
           let mode = SyncGapMode(rawValue: savedSyncGap) {
            self.syncGapMode = mode
        } else {
            self.syncGapMode = .none
        }

        self.autoSaveToLibrary = UserDefaults.standard.bool(forKey: "autoSaveToLibrary")
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") != nil ? UserDefaults.standard.bool(forKey: "hapticsEnabled") : true
        self.loggingEnabled = UserDefaults.standard.bool(forKey: "loggingEnabled")

        self.engine = UpscalerEngine(computeUnits: computeUnits)
    }

    public func updateEngineComputeUnits() {
        self.engine = UpscalerEngine(computeUnits: computeUnitsSelection)
        AppLogger.shared.log("Compute hardware updated: \(computeUnitsSelection)", isEnabled: loggingEnabled)
    }

    // MARK: - Single Upscale
    public func startUpscale() {
        guard let image = inputImage else { return }

        guard ModelDownloader.shared.isModelInstalled(selectedModel) else {
            self.errorMessage = "The model '\(selectedModel.name)' is not downloaded. Please download it from the Models tab."
            self.statusText = "Model not downloaded"
            AppLogger.shared.log("Upscale aborted: model '\(selectedModel.name)' is not downloaded", level: .warning, isEnabled: loggingEnabled)
            return
        }

        let inW = Int(image.size.width)
        let inH = Int(image.size.height)
        let outW = inW * selectedModel.scale
        let outH = inH * selectedModel.scale

        AppLogger.shared.log("--- Starting Upscale ---", isEnabled: loggingEnabled)
        AppLogger.shared.log("Input: \(inW)×\(inH) (\(String(format: "%.2f", Double(inW * inH) / 1_000_000)) MP)", isEnabled: loggingEnabled)
        AppLogger.shared.log("Model: \(selectedModel.name) (\(selectedModel.scale)x)", isEnabled: loggingEnabled)
        AppLogger.shared.log("Expected Output: \(outW)×\(outH) (\(String(format: "%.2f", Double(outW * outH) / 1_000_000)) MP)", isEnabled: loggingEnabled)
        AppLogger.shared.log("Config: Native Tile Size \(selectedModel.defaultTileSize)px • Overlap \(selectedModel.recommendedOverlap)px • Compute \(computeUnitsSelection)", isEnabled: loggingEnabled)

        isProcessing = true
        progressFraction = 0.0
        statusText = "Initializing \(selectedModel.name)..."
        errorMessage = nil
        let startTime = Date()

        processingTask?.cancel()
        processingTask = Task {
            do {
                let model = selectedModel

                let result = try await engine.upscale(
                    image: image,
                    model: model
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.progressFraction = progress.fraction
                        self.statusText = progress.statusMessage
                    }
                }

                if !Task.isCancelled {
                    let elapsed = Date().timeIntervalSince(startTime)
                    self.upscaledImage = result
                    self.elapsedTime = elapsed
                    self.statusText = String(format: "Finished in %.2fs (%dx upscale)", elapsed, model.scale)
                    self.isProcessing = false

                    let mpps = (Double(outW * outH) / 1_000_000) / max(elapsed, 0.01)
                    AppLogger.shared.log("Upscale Complete in \(String(format: "%.2fs", elapsed)) (\(String(format: "%.2f", mpps)) MP/s)", isEnabled: self.loggingEnabled)

                    if self.autoSaveToLibrary {
                        try? await ImageUtils.saveToPhotoLibrary(
                            image: result,
                            format: self.exportFormat,
                            quality: self.exportQuality.rawValue
                        )
                        AppLogger.shared.log("Auto-saved upscaled image to Photos (\(self.exportFormat.rawValue))", isEnabled: self.loggingEnabled)
                    }
                }
            } catch is CancellationError {
                self.statusText = "Cancelled"
                self.isProcessing = false
                AppLogger.shared.log("Upscale cancelled by user", level: .warning, isEnabled: self.loggingEnabled)
            } catch {
                self.errorMessage = error.localizedDescription
                self.statusText = "Error: \(error.localizedDescription)"
                self.isProcessing = false
                AppLogger.shared.log("Upscale Error: \(error.localizedDescription)", level: .error, isEnabled: self.loggingEnabled)
            }
        }
    }

    public func cancelUpscale() {
        processingTask?.cancel()
        Task {
            await engine.cancel()
        }
        isProcessing = false
        statusText = "Cancelled by user"
        AppLogger.shared.log("Cancelled upscale task", level: .warning, isEnabled: loggingEnabled)
    }

    // MARK: - Batch Processing
    public func addImagesToBatch(_ images: [UIImage]) {
        let newItems = images.map { BatchItem(originalImage: $0) }
        batchQueue.append(contentsOf: newItems)
    }

    public func removeBatchItems(at offsets: IndexSet) {
        batchQueue.remove(atOffsets: offsets)
    }

    public func removeBatchItem(id: UUID) {
        batchQueue.removeAll { $0.id == id }
    }

    public func startBatchProcessing() {
        guard !batchQueue.isEmpty, !isBatchProcessing else { return }
        isBatchProcessing = true

        Task {
            for i in 0..<batchQueue.count {
                if !isBatchProcessing { break }
                if batchQueue[i].status == .completed { continue }

                batchCurrentIndex = i
                batchQueue[i].status = .processing
                let itemImage = batchQueue[i].originalImage

                do {
                    let result = try await engine.upscale(
                        image: itemImage,
                        model: selectedModel
                    ) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.batchQueue[i].progress = progress.fraction
                        }
                    }

                    batchQueue[i].upscaledImage = result
                    batchQueue[i].status = .completed
                    batchQueue[i].progress = 1.0

                    if autoSaveToLibrary {
                        try? await ImageUtils.saveToPhotoLibrary(
                            image: result,
                            format: exportFormat,
                            quality: exportQuality.rawValue
                        )
                    }
                } catch {
                    batchQueue[i].status = .failed
                    batchQueue[i].errorMessage = error.localizedDescription
                }
            }

            isBatchProcessing = false
        }
    }

    public func cancelBatchProcessing() {
        isBatchProcessing = false
        Task {
            await engine.cancel()
        }
    }

    public func clearBatch() {
        cancelBatchProcessing()
        batchQueue.removeAll()
    }
}

// MARK: - Bundle Version Derivation
extension Bundle {
    public var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
    }

    public var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }
}

