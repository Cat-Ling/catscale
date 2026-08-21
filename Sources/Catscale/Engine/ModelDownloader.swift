import Foundation

@Observable
@MainActor
public final class ModelDownloader {

    public static let shared = ModelDownloader()

    public var downloadingModels: [String: Double] = [:] // [ModelID: Progress 0.0...1.0]
    public var downloadErrors: [String: String] = [:]
    public var installedModelIds: Set<String> = []

    // MARK: - Batch Download State
    public var isDownloadingAll: Bool = false
    public var downloadAllCurrentIndex: Int = 0
    public var downloadAllTotalCount: Int = 0
    public var downloadAllCurrentModelName: String = ""
    public var downloadAllProgress: Double = 0.0

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var batchTask: Task<Void, Never>? = nil

    private init() {
        refreshInstalledModels()
    }

    /// Refresh and scan for all available local, downloaded, and bundled models
    public func refreshInstalledModels() {
        var installed = Set<String>()

        let fileManager = FileManager.default
        let searchDirectories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Models")
        ].compactMap { $0 }

        // Gather all subpaths across storage directories
        var allSubpaths: [String] = []
        for dir in searchDirectories {
            if let paths = try? fileManager.subpathsOfDirectory(atPath: dir.path) {
                allSubpaths.append(contentsOf: paths.map { $0.lowercased() })
            }
        }

        for model in ModelRegistry.allModels {
            if model.isBundled {
                installed.insert(model.id)
                continue
            }

            // 1. Check App Bundle & Frameworks
            if Bundle.main.url(forResource: model.compiledModelName, withExtension: "mlmodelc") != nil ||
               Bundle.main.url(forResource: model.compiledModelName, withExtension: "mlmodel") != nil ||
               Bundle.main.url(forResource: model.compiledModelName, withExtension: "mlpackage") != nil {
                installed.insert(model.id)
                continue
            }

            #if SWIFT_PACKAGE
            if Bundle.module.url(forResource: model.compiledModelName, withExtension: "mlmodelc") != nil ||
               Bundle.module.url(forResource: model.compiledModelName, withExtension: "mlmodel") != nil ||
               Bundle.module.url(forResource: model.compiledModelName, withExtension: "mlpackage") != nil {
                installed.insert(model.id)
                continue
            }
            #endif

            // 2. Check Recursive Subpaths in Downloaded Models for this specific model
            let baseName = model.compiledModelName.lowercased()
            let normalizedBase = baseName.replacingOccurrences(of: "-", with: "_")

            let matches = allSubpaths.contains { path in
                path.contains("\(baseName).mlpackage") ||
                path.contains("\(baseName).mlmodel") ||
                path.contains("\(baseName).mlmodelc") ||
                path.contains("\(normalizedBase).mlpackage") ||
                path.contains("\(normalizedBase).mlmodel") ||
                path.contains("\(normalizedBase).mlmodelc")
            }

            if matches {
                installed.insert(model.id)
            }
        }

        self.installedModelIds = installed
    }

    /// Check if a model is installed
    public func isModelInstalled(_ model: ModelSpec) -> Bool {
        if model.isBundled { return true }
        if installedModelIds.contains(model.id) { return true }
        let baseName = model.compiledModelName.lowercased()
        return installedModelIds.contains(where: { installedId in
            if let installedSpec = ModelRegistry.allModels.first(where: { $0.id == installedId }) {
                return installedSpec.compiledModelName.lowercased() == baseName
            }
            return false
        })
    }

    /// Cancel an active model download
    public func cancelDownload(for model: ModelSpec) {
        activeTasks[model.id]?.cancel()
        activeTasks.removeValue(forKey: model.id)
        downloadingModels.removeValue(forKey: model.id)
        downloadErrors[model.id] = nil
    }

    /// Cancel all ongoing downloads including batch
    public func cancelDownloadAll() {
        batchTask?.cancel()
        batchTask = nil
        isDownloadingAll = false
        for (id, task) in activeTasks {
            task.cancel()
            downloadingModels.removeValue(forKey: id)
        }
        activeTasks.removeAll()
    }

    /// Download all missing models one by one sequentially
    public func downloadAllModels() {
        guard !isDownloadingAll else { return }

        let missingModels = ModelRegistry.allModels.filter { !$0.isBundled && !isModelInstalled($0) }
        guard !missingModels.isEmpty else { return }

        isDownloadingAll = true
        downloadAllTotalCount = missingModels.count
        downloadAllCurrentIndex = 0
        downloadAllProgress = 0.0

        batchTask = Task { @MainActor in
            for (index, model) in missingModels.enumerated() {
                if Task.isCancelled { break }

                downloadAllCurrentIndex = index + 1
                downloadAllCurrentModelName = model.name
                downloadAllProgress = Double(index) / Double(missingModels.count)

                _ = await downloadModel(model)

                downloadAllProgress = Double(index + 1) / Double(missingModels.count)
            }

            self.isDownloadingAll = false
            self.downloadAllCurrentModelName = ""
            self.refreshInstalledModels()
        }
    }

    /// Delete a specific downloaded model from local storage
    public func deleteModel(_ model: ModelSpec) {
        guard !model.isBundled else { return }
        cancelDownload(for: model)

        let fileManager = FileManager.default
        let searchDirectories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Models")
        ].compactMap { $0 }

        let baseName = model.compiledModelName.lowercased()
        let normalizedBase = baseName.replacingOccurrences(of: "-", with: "_")

        for dir in searchDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) else { continue }
            for item in contents {
                let lower = item.lowercased()
                if lower.contains(baseName) || lower.contains(normalizedBase) {
                    let itemURL = dir.appendingPathComponent(item)
                    try? fileManager.removeItem(at: itemURL)
                }
            }
        }

        refreshInstalledModels()
    }

    /// Delete all locally downloaded models to free storage space
    public func deleteAllDownloadedModels() {
        cancelDownloadAll()

        let fileManager = FileManager.default
        let searchDirectories = [
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Models"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Models")
        ].compactMap { $0 }

        for dir in searchDirectories {
            try? fileManager.removeItem(at: dir)
        }

        refreshInstalledModels()
    }

    /// Download and unpack model with live streaming progress
    @discardableResult
    public func downloadModel(_ model: ModelSpec) async -> Bool {
        guard downloadingModels[model.id] == nil else {
            return false // Already actively downloading
        }

        guard let urlString = model.downloadURLString, let url = URL(string: urlString) else {
            downloadErrors[model.id] = "Invalid download URL"
            return false
        }

        downloadingModels[model.id] = 0.01
        downloadErrors[model.id] = nil

        let fileManager = FileManager.default
        let tempFileURL = fileManager.temporaryDirectory.appendingPathComponent("catscale_\(UUID().uuidString).tmp")

        let downloadTask = Task { @MainActor in
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

                let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let expectedLength = response.expectedContentLength
                fileManager.createFile(atPath: tempFileURL.path, contents: nil)
                let fileHandle = try FileHandle(forWritingTo: tempFileURL)

                var buffer = Data()
                buffer.reserveCapacity(64 * 1024)
                var totalDownloaded: Int64 = 0
                var lastReportTime = Date()

                for try await byte in asyncBytes {
                    if Task.isCancelled {
                        try? fileHandle.close()
                        try? fileManager.removeItem(at: tempFileURL)
                        throw CancellationError()
                    }

                    buffer.append(byte)
                    totalDownloaded += 1

                    if buffer.count >= 64 * 1024 {
                        try fileHandle.write(contentsOf: buffer)
                        buffer.removeAll(keepingCapacity: true)

                        let now = Date()
                        if now.timeIntervalSince(lastReportTime) >= 0.1 && expectedLength > 0 {
                            let progress = Double(totalDownloaded) / Double(expectedLength)
                            self.downloadingModels[model.id] = min(max(progress, 0.01), 0.99)
                            lastReportTime = now
                        }
                    }
                }

                if !buffer.isEmpty {
                    try fileHandle.write(contentsOf: buffer)
                    buffer.removeAll()
                }
                try fileHandle.close()

                if Task.isCancelled {
                    try? fileManager.removeItem(at: tempFileURL)
                    throw CancellationError()
                }

                guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw URLError(.cannotCreateFile)
                }

                let modelsDir = documentsURL.appendingPathComponent("Models")
                try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)

                let isZip = url.lastPathComponent.lowercased().hasSuffix(".zip")

                if isZip {
                    try ZipExtractor.unzip(archiveAt: tempFileURL, to: modelsDir)
                } else {
                    let dest = modelsDir.appendingPathComponent(url.lastPathComponent)
                    if fileManager.fileExists(atPath: dest.path) {
                        try fileManager.removeItem(at: dest)
                    }
                    try fileManager.moveItem(at: tempFileURL, to: dest)
                }

                try? fileManager.removeItem(at: tempFileURL)

                self.downloadingModels[model.id] = 1.0
                try? await Task.sleep(nanoseconds: 100_000_000)
                self.downloadingModels.removeValue(forKey: model.id)
                self.activeTasks.removeValue(forKey: model.id)
                self.refreshInstalledModels()
            } catch is CancellationError {
                try? fileManager.removeItem(at: tempFileURL)
                self.downloadingModels.removeValue(forKey: model.id)
                self.activeTasks.removeValue(forKey: model.id)
            } catch {
                try? fileManager.removeItem(at: tempFileURL)
                self.downloadErrors[model.id] = error.localizedDescription
                self.downloadingModels.removeValue(forKey: model.id)
                self.activeTasks.removeValue(forKey: model.id)
            }
        }

        activeTasks[model.id] = downloadTask
        await downloadTask.value
        return isModelInstalled(model)
    }
}
