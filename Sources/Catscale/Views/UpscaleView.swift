import SwiftUI
import PhotosUI

@MainActor
public struct UpscaleView: View {
    @Bindable var state: AppState

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showModelPicker: Bool = false
    @State private var showSavedNotification: Bool = false

    private var downloader = ModelDownloader.shared

    public init(state: AppState) {
        self.state = state
    }

    private var isModelDownloading: Bool {
        downloader.downloadingModels[state.selectedModel.id] != nil
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let input = state.inputImage {
                    ZStack {
                        if let upscaled = state.upscaledImage {
                            ComparisonSliderView(
                                originalImage: input,
                                upscaledImage: upscaled,
                                scaleFactor: state.selectedModel.scale
                            )
                        } else {
                            // Tap image to choose a new photo before upscaling
                            PhotoPreviewCanvas(
                                input: input,
                                isProcessing: state.isProcessing,
                                selectedPhotoItem: $selectedPhotoItem
                            )
                        }

                        if state.isProcessing {
                            ProcessingOverlay(
                                progress: state.progressFraction,
                                statusText: state.statusText,
                                onCancel: {
                                    state.cancelUpscale()
                                }
                            )
                        }
                    }
                    .padding()

                    // Bottom Action Bar
                    ControlPanel(
                        state: state,
                        isModelDownloading: isModelDownloading,
                        showModelPicker: $showModelPicker,
                        showSavedNotification: $showSavedNotification,
                        onNewPhotoRequested: {
                            selectedPhotoItem = nil
                            state.inputImage = nil
                            state.upscaledImage = nil
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                } else {
                    // Clean Empty State
                    EmptyStatePicker(selectedItem: $selectedPhotoItem)
                        .padding()
                }
            }
            .toolbar {
                // Left-aligned brand header
                ToolbarItem(placement: .topBarLeading) {
                    Text("Catscale")
                        .font(.title3.bold())
                }

                // Model Selector Pill on Trailing Side
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(state.selectedModel.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2.bold())
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(state.isProcessing ? .secondary : .primary)
                        .clipShape(.capsule)
                    }
                    .disabled(state.isProcessing)
                }
            }
            .sheet(isPresented: $showModelPicker) {
                ModelSelectionView(state: state)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        state.inputImage = image
                        state.upscaledImage = nil
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSavedNotification {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved to Photos")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(.capsule)
                    .shadow(radius: 6)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Subviews
private struct PhotoPreviewCanvas: View {
    let input: UIImage
    let isProcessing: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: input)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 16))

                if !isProcessing {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Change")
                    }
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.primary)
                    .clipShape(.capsule)
                    .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

private struct EmptyStatePicker: View {
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text("No Image Selected")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Choose an image from your photo library to upscale")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Choose Photo")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(.capsule)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct ProcessingOverlay: View {
    let progress: Double
    let statusText: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .frame(width: 200)

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Button("Cancel", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10)
    }
}

private struct ControlPanel: View {
    @Bindable var state: AppState
    let isModelDownloading: Bool
    @Binding var showModelPicker: Bool
    @Binding var showSavedNotification: Bool
    let onNewPhotoRequested: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if state.upscaledImage == nil {
                Button {
                    state.startUpscale()
                } label: {
                    Text(isModelDownloading ? "Model Downloading..." : "Upscale (\(state.selectedModel.scale)x)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(state.isProcessing || isModelDownloading ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(state.isProcessing || isModelDownloading)
            } else {
                HStack(spacing: 10) {
                    Button(action: onNewPhotoRequested) {
                        Text("New")
                            .font(.subheadline.bold())
                            .frame(width: 65, height: 48)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isProcessing)

                    Button {
                        state.startUpscale()
                    } label: {
                        Text(isModelDownloading ? "Downloading..." : "Upscale Again (\(state.selectedModel.scale)x)")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, maxHeight: 48)
                            .background(state.isProcessing || isModelDownloading ? Color.gray : Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isProcessing || isModelDownloading)

                    Button {
                        if let image = state.upscaledImage {
                            Task {
                                try? await ImageUtils.saveToPhotoLibrary(
                                    image: image,
                                    format: state.exportFormat,
                                    quality: state.exportQuality.rawValue
                                )
                                withAnimation { showSavedNotification = true }
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation { showSavedNotification = false }
                            }
                        }
                    } label: {
                        Text("Save")
                            .font(.subheadline.bold())
                            .frame(width: 75, height: 48)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isProcessing)
                }
            }
        }
    }
}
