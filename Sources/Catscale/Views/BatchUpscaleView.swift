import SwiftUI
import PhotosUI

public struct BatchUpscaleView: View {
    @Bindable var state: AppState

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showSaveAllAlert: Bool = false

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        NavigationStack {
            VStack {
                if state.batchQueue.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 6) {
                            Text("No Images in Queue")
                                .font(.title3.bold())

                            Text("Select multiple photos to upscale in bulk.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        PhotosPicker(selection: $selectedPhotos, matching: .images) {
                            Label("Select Photos", systemImage: "photo.badge.plus")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(.capsule)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Queue (\(state.batchQueue.count))") {
                            ForEach(state.batchQueue) { item in
                                BatchItemRow(item: item)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            state.removeBatchItem(id: item.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                            .onDelete { offsets in
                                state.removeBatchItems(at: offsets)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)

                    // Bottom Action Bar
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotos, matching: .images) {
                            Label("Add", systemImage: "plus")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        if state.isBatchProcessing {
                            Button(role: .destructive) {
                                state.cancelBatchProcessing()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .clipShape(.rect(cornerRadius: 12))
                            }
                        } else {
                            Button {
                                state.startBatchProcessing()
                            } label: {
                                Label("Start (\(state.selectedModel.scale)x)", systemImage: "play.fill")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(.rect(cornerRadius: 12))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Batch Upscale")
            .toolbar {
                if !state.batchQueue.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            state.clearBatch()
                        }
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, items in
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    if !images.isEmpty {
                        state.addImagesToBatch(images)
                        selectedPhotos.removeAll()
                    }
                }
            }
        }
    }
}

private struct BatchItemRow: View {
    let item: BatchItem

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: item.originalImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Image (\(Int(item.originalImage.size.width)) × \(Int(item.originalImage.size.height)))")
                    .font(.subheadline.bold())

                if item.status == .processing {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                } else if let error = item.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text(item.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            switch item.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            case .processing:
                ProgressView()
                    .controlSize(.small)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
