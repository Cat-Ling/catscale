import SwiftUI

public struct ManageModelsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloader = ModelDownloader.shared
    @State private var showDeleteAllAlert: Bool = false
    @State private var selectedFilter: ModelCategoryFilter = .all

    private enum ModelCategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case installed = "Installed"
        case notInstalled = "Not Installed"

        var id: String { rawValue }
    }

    private var downloadableModels: [ModelSpec] {
        ModelRegistry.allModels.filter { !$0.isBundled }
    }

    private var filteredModels: [ModelSpec] {
        switch selectedFilter {
        case .all:
            return downloadableModels
        case .installed:
            return downloadableModels.filter { downloader.isModelInstalled($0) }
        case .notInstalled:
            return downloadableModels.filter { !downloader.isModelInstalled($0) }
        }
    }

    private var installedCount: Int {
        downloadableModels.filter { downloader.isModelInstalled($0) }.count
    }

    private var installedSizeMB: Double {
        downloadableModels.filter { downloader.isModelInstalled($0) }
            .reduce(0.0) { $0 + $1.uncompressedSizeMB }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Summary Header
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(installedCount) of \(downloadableModels.count) Models Ready")
                                    .font(.headline)
                                Text(String(format: "%.1f MB occupied on disk", installedSizeMB))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        if downloader.isDownloadingAll {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Downloading \(downloader.downloadAllCurrentModelName)...")
                                        .font(.caption.bold())
                                    Spacer()
                                    Text("(\(downloader.downloadAllCurrentIndex)/\(downloader.downloadAllTotalCount))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: downloader.downloadAllProgress)
                                    .progressViewStyle(.linear)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Filter Picker
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ModelCategoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                // MARK: - Models List
                Section("Models (\(filteredModels.count))") {
                    if filteredModels.isEmpty {
                        Text("No models match the selected filter.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredModels) { model in
                            ModelRowView(model: model, downloader: downloader)
                        }
                    }
                }
            }
            .navigationTitle("Manage Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if installedCount > 0 && !downloader.isDownloadingAll {
                        Button("Delete All", role: .destructive) {
                            showDeleteAllAlert = true
                        }
                        .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete All Downloaded Models?", isPresented: $showDeleteAllAlert) {
                Button("Delete All", role: .destructive) {
                    downloader.deleteAllDownloadedModels()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all downloaded models from your device storage. You can re-download them anytime.")
            }
            .onAppear {
                downloader.refreshInstalledModels()
            }
        }
    }
}

// MARK: - Model Row View with Swipe-to-Delete
private struct ModelRowView: View {
    let model: ModelSpec
    var downloader: ModelDownloader

    private var isInstalled: Bool {
        downloader.isModelInstalled(model)
    }

    private var isDownloading: Bool {
        downloader.downloadingModels[model.id] != nil
    }

    private var progress: Double {
        downloader.downloadingModels[model.id] ?? 0.0
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Text("\(model.scale)x")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(.capsule)
                }

                Text(String(format: "Download: %.1f MB • Disk: %.1f MB", model.downloadSizeMB, model.uncompressedSizeMB))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isDownloading {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)

                    Button {
                        downloader.cancelDownload(for: model)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            } else {
                Button("Download") {
                    Task {
                        await downloader.downloadModel(model)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            if isInstalled {
                Button(role: .destructive) {
                    withAnimation {
                        downloader.deleteModel(model)
                    }
                } label: {
                    Label("Delete Model", systemImage: "trash")
                }
            } else if !isDownloading {
                Button {
                    Task {
                        await downloader.downloadModel(model)
                    }
                } label: {
                    Label("Download Model", systemImage: "arrow.down.circle")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isInstalled {
                Button(role: .destructive) {
                    withAnimation {
                        downloader.deleteModel(model)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }
}