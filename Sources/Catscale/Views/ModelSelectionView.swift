import SwiftUI

public struct ModelSelectionView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroup: ModelGroup
    @State private var selectedVariantName: String
    @State private var selectedNoiseLevel: Int
    @State private var downloadAlertMessage: String?
    @State private var showDownloadAlert: Bool = false

    private var downloader = ModelDownloader.shared

    public init(state: AppState) {
        self.state = state
        _selectedGroup = State(initialValue: state.selectedModel.group)
        _selectedVariantName = State(initialValue: state.selectedModel.variantName)
        _selectedNoiseLevel = State(initialValue: max(0, state.selectedModel.noiseLevel))
    }

    private var currentModelSpec: ModelSpec {
        ModelRegistry.resolve(group: selectedGroup, variantName: selectedVariantName, noiseLevel: selectedNoiseLevel)
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
                // MARK: - 1. Algorithm & Model Selection
                Section("Upscaling Engine") {
                    // Algorithm Dropdown with Categorized Domains
                    Picker("Algorithm", selection: $selectedGroup) {
                        Section("Anime & Art") {
                            Text("Real-CUGAN (Anime)").tag(ModelGroup.realCUGANAnime)
                            Text("Real-ESRGAN (Anime)").tag(ModelGroup.realESRGANAnime)
                            Text("Waifu2x (Anime)").tag(ModelGroup.waifu2xAnime)
                            Text("ESRGAN (Manga & Clean)").tag(ModelGroup.mangaClean)
                        }

                        Section("Photo & Universal") {
                            Text("SRMD (Photo & Universal)").tag(ModelGroup.srmdPhoto)
                            Text("BSRGAN (Photo & Degraded)").tag(ModelGroup.bsrganPhoto)
                            Text("Real-ESRNet (Photo & Natural)").tag(ModelGroup.realESRNetPhoto)
                            Text("Real-ESRGAN (Universal)").tag(ModelGroup.realESRGANUniversal)
                            Text("Waifu2x (Photo)").tag(ModelGroup.waifu2xPhoto)
                        }
                    }
                    .onChange(of: selectedGroup) { _, newGroup in
                        if !newGroup.availableVariantNames.contains(selectedVariantName) {
                            selectedVariantName = newGroup.availableVariantNames.first ?? ""
                        }
                        if newGroup == .waifu2xPhoto {
                            if selectedNoiseLevel < 1 || selectedNoiseLevel > 2 {
                                selectedNoiseLevel = 1
                            }
                        } else if newGroup == .realCUGANAnime && (selectedVariantName.contains("3x") || selectedVariantName.contains("4x")) {
                            if selectedNoiseLevel != 0 && selectedNoiseLevel != 3 {
                                selectedNoiseLevel = 0
                            }
                        }
                        syncSelectedModel()
                    }

                    // Model Dropdown (Specific scale/variant for the chosen algorithm)
                    Picker("Model", selection: $selectedVariantName) {
                        ForEach(selectedGroup.availableVariantNames, id: \.self) { variant in
                            Text(variant).tag(variant)
                        }
                    }
                    .onChange(of: selectedVariantName) { _, newVariant in
                        if selectedGroup == .realCUGANAnime && (newVariant.contains("3x") || newVariant.contains("4x")) {
                            if selectedNoiseLevel != 0 && selectedNoiseLevel != 3 {
                                selectedNoiseLevel = 0
                            }
                        }
                        syncSelectedModel()
                    }

                    // SRMD Denoising Level (0 to 10 for standard SRMD)
                    if selectedGroup == .srmdPhoto && !currentModelSpec.isSRMDNF {
                        Picker("Denoising Level", selection: $selectedNoiseLevel) {
                            Text("0 (Clean / Sharp)").tag(0)
                            Text("1 (Subtle)").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5 (Moderate)").tag(5)
                            Text("6").tag(6)
                            Text("7").tag(7)
                            Text("8").tag(8)
                            Text("9").tag(9)
                            Text("10 (Strong)").tag(10)
                        }
                        .onChange(of: selectedNoiseLevel) { _, _ in
                            syncSelectedModel()
                        }
                    }

                    // Real-CUGAN Quality & SyncGap
                    if selectedGroup == .realCUGANAnime {
                        if selectedVariantName.contains("3x") || selectedVariantName.contains("4x") {
                            Picker("Denoising Level", selection: $selectedNoiseLevel) {
                                Text("No Denoise (0)").tag(0)
                                Text("Denoise (3)").tag(3)
                            }
                            .onChange(of: selectedNoiseLevel) { _, _ in
                                syncSelectedModel()
                            }
                        } else {
                            Picker("Denoising Level", selection: $selectedNoiseLevel) {
                                Text("No Denoise (0)").tag(0)
                                Text("Low (1)").tag(1)
                                Text("Medium (2)").tag(2)
                                Text("High (3)").tag(3)
                            }
                            .onChange(of: selectedNoiseLevel) { _, _ in
                                syncSelectedModel()
                            }
                        }

                        Picker("SyncGap (Seam Sync)", selection: $state.syncGapMode) {
                            ForEach(SyncGapMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }

                    // Waifu2x Anime Noise Reduction
                    if selectedGroup == .waifu2xAnime {
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

                    // Waifu2x Photo Noise Reduction
                    if selectedGroup == .waifu2xPhoto {
                        Picker("Noise Reduction", selection: $selectedNoiseLevel) {
                            Text("Light (1)").tag(1)
                            Text("Medium (2)").tag(2)
                        }
                        .onChange(of: selectedNoiseLevel) { _, _ in
                            syncSelectedModel()
                        }
                    }
                }

                // MARK: - 2. Model Download Action (Only shown when model is missing from device)
                if !isModelInstalled {
                    Section {
                        if let progress = downloader.downloadingModels[currentModelSpec.id] {
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
                }

                // MARK: - 3. Output Format & Saving
                Section("Saving") {
                    Picker("Image Format", selection: $state.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }

                    if state.exportFormat.supportsQualityAdjustment {
                        Picker("Image Quality", selection: $state.exportQuality) {
                            ForEach(ExportQuality.allCases) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                    }

                    Toggle("Auto-Save to Photos", isOn: $state.autoSaveToLibrary)
                }

                // MARK: - 4. Output Resolution (Only shown at the end when an image is loaded)
                if let img = state.inputImage {
                    let inW = Int(img.size.width)
                    let inH = Int(img.size.height)
                    let outW = inW * currentModelSpec.scale
                    let outH = inH * currentModelSpec.scale

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
            .navigationTitle("Algorithm & Model")
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
                selectedGroup = state.selectedModel.group
                selectedVariantName = state.selectedModel.variantName
                selectedNoiseLevel = max(0, state.selectedModel.noiseLevel)
                downloader.refreshInstalledModels()
            }
        }
    }

    private func syncSelectedModel() {
        state.selectedModel = currentModelSpec
    }
}

