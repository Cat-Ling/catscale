import Foundation

@Observable
@MainActor
public final class ModelDownloader {

    public static let shared = ModelDownloader()

    public var downloadingModels: [String: Double] = [:] // [ModelID: Progress 0.0...1.0]
    public var downloadErrors: [String: String] = [:]
    public var installedModelIds: Set<String> = []

    private var activeTasks: [String: Task<Void, Never>] = [:]

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
        return installedModelIds.contains(model.id)
    }

    /// Cancel an active model download
    public func cancelDownload(for model: ModelSpec) {
        activeTasks[model.id]?.cancel()
        activeTasks.removeValue(forKey: model.id)
        downloadingModels.removeValue(forKey: model.id)
        downloadErrors[model.id] = nil
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
