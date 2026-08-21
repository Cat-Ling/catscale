import SwiftUI
import CoreML

public struct SettingsView: View {
    @Bindable var state: AppState
    @State private var showLogsSheet: Bool = false
    @State private var showDeleteModelsAlert: Bool = false
    @State private var logger = AppLogger.shared
    private var downloader = ModelDownloader.shared

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Models Storage & Offline Manager
                Section("AI Models & Offline Storage") {
                    let downloadable = ModelRegistry.allModels.filter { !$0.isBundled }
                    let installed = downloadable.filter { downloader.isModelInstalled($0) }
                    let installedMB = installed.reduce(0.0) { $0 + $1.uncompressedSizeMB }

                    HStack {
                        Text("Installed Models")
                        Spacer()
                        Text("\(installed.count) / \(downloadable.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Disk Usage")
                        Spacer()
                        Text(String(format: "%.1f MB", installedMB))
                            .foregroundStyle(.secondary)
                    }

                    if downloader.isDownloadingAll {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Downloading \(downloader.downloadAllCurrentModelName)...")
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Spacer()
                                Text("(\(downloader.downloadAllCurrentIndex)/\(downloader.downloadAllTotalCount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: downloader.downloadAllProgress)
                                .progressViewStyle(.linear)

                            Button("Cancel Download", role: .cancel) {
                                downloader.cancelDownloadAll()
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    } else if installed.count < downloadable.count {
                        Button {
                            downloader.downloadAllModels()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text("Download All Models (\(downloadable.count - installed.count) remaining)")
                                    .fontWeight(.medium)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("All Models Downloaded (Offline Ready)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !installed.isEmpty && !downloader.isDownloadingAll {
                        Button("Delete Downloaded Models", role: .destructive) {
                            showDeleteModelsAlert = true
                        }
                    }
                }

                // MARK: - Performance
                Section("Compute Engine") {
                    Picker("Hardware Acceleration", selection: $state.computeUnitsSelection) {
                        Text("All (Neural Engine + GPU + CPU)").tag(MLComputeUnits.all)
                        Text("CPU and GPU").tag(MLComputeUnits.cpuAndGPU)
                        Text("CPU Only").tag(MLComputeUnits.cpuOnly)
                    }
                    .onChange(of: state.computeUnitsSelection) { _, _ in
                        state.updateEngineComputeUnits()
                    }
                }

                // MARK: - Diagnostics
                Section("Diagnostics") {
                    Toggle("Logging", isOn: $state.loggingEnabled)

                    if state.loggingEnabled {
                        Button {
                            showLogsSheet = true
                        } label: {
                            HStack {
                                Text("Session Logs")
                                Spacer()
                                Text("\(logger.logCount) entries")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                // MARK: - About
                Section("About") {
                    LabeledContent("Version", value: "0.4")
                    LabeledContent("License", value: "MIT")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showLogsSheet) {
                SessionLogsView()
            }
            .alert("Delete Downloaded Models?", isPresented: $showDeleteModelsAlert) {
                Button("Delete All", role: .destructive) {
                    downloader.deleteAllDownloadedModels()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all downloaded model files from local storage to free up space. Bundled Waifu2x models will remain available.")
            }
            .onAppear {
                downloader.refreshInstalledModels()
            }
        }
    }
}

// MARK: - Session Logs Viewer
private struct SessionLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logger = AppLogger.shared
    @State private var copied: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if logger.entries.isEmpty {
                    ContentUnavailableView(
                        "No Logs Recorded",
                        systemImage: "doc.text",
                        description: Text("Upscale an image with Logging enabled to view runtime diagnostics.")
                    )
                } else {
                    ScrollView {
                        Text(logger.formattedText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Session Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !logger.entries.isEmpty {
                        Button("Clear", role: .destructive) {
                            withAnimation {
                                logger.clear()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !logger.entries.isEmpty {
                            Button {
                                UIPasteboard.general.string = logger.formattedText
                                copied = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    copied = false
                                }
                            } label: {
                                Text(copied ? "Copied!" : "Copy")
                                    .fontWeight(.medium)
                            }
                        }

                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
