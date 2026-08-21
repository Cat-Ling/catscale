import SwiftUI

public struct ModelSelectionView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: ModelGroup
    @State private var selectedScale: Int
    @State private var selectedNoiseLevel: Int
    @State private var downloadAlertMessage: String?
    @State private var showDownloadAlert: Bool = false

    private var downloader = ModelDownloader.shared

    public init(state: AppState) {
        self.state = state
        _selectedGroup = State(initialValue: state.selectedModel.group)
        _selectedScale = State(initialValue: state.selectedModel.scale)
        _selectedNoiseLevel = State(initialValue: max(0, state.selectedModel.noiseLevel))
    }

    private var currentModelSpec: ModelSpec {
        ModelRegistry.resolve(group: selectedGroup, scale: selectedScale, noiseLevel: selectedNoiseLevel)
    }

    private var isModelInstalled: Bool {
        downloader.isModelInstalled(currentModelSpec)
    }

    private var isModelDownloading: Bool {
        downloader.downloadingModels[currentModelSpec.id] != nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1. Model & Scale Selection
                Section("Upscaling Engine") {
                    // Model Dropdown with Categories
                    Picker("Model", selection: $selectedGroup) {
                        Section("Anime & Art") {
                            Text("Real-CUGAN (Anime)").tag(ModelGroup.realCUGANAnime)
                            Text("Real-ESRGAN (Anime)").tag(ModelGroup.realESRGANAnime)
                            Text("Waifu2x (Anime)").tag(ModelGroup.waifu2xAnime)
                            Text("ESRGAN (Manga & Clean)").tag(ModelGroup.mangaClean)
                        }

                        Section("Photo & Universal") {
                            Text("SRMD (Photo & Universal)").tag(ModelGroup.srmdPhoto)
                            Text("Real-ESRGAN (Universal)").tag(ModelGroup.realESRGANUniversal)
                            Text("Waifu2x (Photo)").tag(ModelGroup.waifu2xPhoto)
                        }
                    }
                    .onChange(of: selectedGroup) { _, newGroup in
                        if !newGroup.supportedScales.contains(selectedScale) {
                            selectedScale = newGroup.supportedScales.first ?? 2
                        }
                        syncSelectedModel()
                    }

                    // Scale Dropdown (Restricted to selected model's capabilities)
                    Picker("Scale Factor", selection: $selectedScale) {
                        ForEach(selectedGroup.supportedScales, id: \.self) { scale in
                            Text("\(scale)x").tag(scale)
                        }
                    }
                    .onChange(of: selectedScale) { _, _ in
                        syncSelectedModel()
                    }

                    // Noise Reduction (if model supports it)
                    if selectedGroup.supportsNoiseReduction {
                        Picker("Noise Reduction", selection: $selectedNoiseLevel) {
                            Text("None (0)").tag(0)
                            Text("Low (1)").tag(1)
                            Text("Medium (2)").tag(2)
                            Text("High (3)").tag(3)
                        }
                        .onChange(of: selectedNoiseLevel) { _, _ in
                            syncSelectedModel()
                        }
                    }
                }

                // MARK: - 2. Model Status & Dynamic Storage Footprint
                Section {
                    if isModelInstalled {
                        HStack {
                            Text("Status")
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                if currentModelSpec.isBundled {
                                    Text("Bundled (Offline)")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(String(format: "Installed (%.1f MB on disk)", currentModelSpec.uncompressedSizeMB))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else if let progress = downloader.downloadingModels[currentModelSpec.id] {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Downloading Model...")
                                    .font(.subheadline.bold())
                                Text(String(format: "%d%% • %.1f MB on disk when ready", Int(progress * 100), currentModelSpec.uncompressedSizeMB))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                downloader.cancelDownload(for: currentModelSpec)
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(progress))
                                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentModelSpec.name)
                                    .font(.subheadline)
                                Text(String(format: "Download: %.1f MB • Disk: %.1f MB", currentModelSpec.downloadSizeMB, currentModelSpec.uncompressedSizeMB))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Download") {
                                Task {
                                    let success = await downloader.downloadModel(currentModelSpec)
                                    if success {
                                        syncSelectedModel()
                                    } else if let err = downloader.downloadErrors[currentModelSpec.id] {
                                        downloadAlertMessage = err
                                        showDownloadAlert = true
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                // MARK: - 3. Output Format & Saving
                Section("Saving") {
                    Picker("Image Format", selection: $state.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }

                    Toggle("Auto-Save to Photos", isOn: $state.autoSaveToLibrary)
                }

                // MARK: - 4. Output Resolution (Only shown at the end when an image is loaded)
                if let img = state.inputImage {
                    let inW = Int(img.size.width)
                    let inH = Int(img.size.height)
                    let outW = inW * selectedScale
                    let outH = inH * selectedScale

                    Section {
                        HStack {
                            Text("Output")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(outW) × \(outH)")
                                .font(.body.weight(.medium))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Model & Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Download Notice", isPresented: $showDownloadAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloadAlertMessage ?? "An error occurred.")
            }
            .onAppear {
                downloader.refreshInstalledModels()
            }
        }
    }

    private func syncSelectedModel() {
        state.selectedModel = currentModelSpec
    }
}
