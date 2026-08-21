import SwiftUI

public struct ComparisonSliderView: View {
    let originalImage: UIImage
    let upscaledImage: UIImage
    let scaleFactor: Int

    // MARK: - Slider State
    @State private var sliderPosition: CGFloat = 0.5 // 0.0 to 1.0

    // MARK: - Zoom & Pan State
    @State private var zoomScale: CGFloat = 1.0
    @State private var magnifyGestureScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var dragGestureOffset: CGSize = .zero

    // MARK: - Handle Drag State
    @State private var isDraggingHandle: Bool = false

    public init(originalImage: UIImage, upscaledImage: UIImage, scaleFactor: Int = 2) {
        self.originalImage = originalImage
        self.upscaledImage = upscaledImage
        self.scaleFactor = scaleFactor
    }

    private var currentScale: CGFloat {
        max(1.0, min(8.0, zoomScale * magnifyGestureScale))
    }

    private func currentPan(in fittedSize: CGSize) -> CGSize {
        let rawX = panOffset.width + dragGestureOffset.width
        let rawY = panOffset.height + dragGestureOffset.height
        let maxPanX = max(0, (fittedSize.width * currentScale - fittedSize.width) / 2)
        let maxPanY = max(0, (fittedSize.height * currentScale - fittedSize.height) / 2)
        return CGSize(
            width: min(maxPanX, max(-maxPanX, rawX)),
            height: min(maxPanY, max(-maxPanY, rawY))
        )
    }

    private func computeFittedRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let fittedWidth: CGFloat
        let fittedHeight: CGFloat

        if imageAspect > containerAspect {
            fittedWidth = containerSize.width
            fittedHeight = containerSize.width / imageAspect
        } else {
            fittedHeight = containerSize.height
            fittedWidth = containerSize.height * imageAspect
        }

        let originX = (containerSize.width - fittedWidth) / 2.0
        let originY = (containerSize.height - fittedHeight) / 2.0

        return CGRect(x: originX, y: originY, width: fittedWidth, height: fittedHeight)
    }

    public var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let containerCenter = CGPoint(x: containerSize.width / 2.0, y: containerSize.height / 2.0)
            let imgSize = CGSize(width: originalImage.size.width, height: originalImage.size.height)
            let fittedRect = computeFittedRect(imageSize: imgSize, in: containerSize)
            let effectivePan = currentPan(in: fittedRect.size)

            ZStack {
                // Neutral Viewport Background
                Color(uiColor: .systemGroupedBackground)

                // ─── 1. Unified Zoomable Image & Divider Canvas ───
                ZStack {
                    // Layer A: Upscaled (Full background)
                    Image(uiImage: upscaledImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fittedRect.width, height: fittedRect.height)

                    // Layer B: Original (Masked left side)
                    Image(uiImage: originalImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fittedRect.width, height: fittedRect.height)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: max(0, fittedRect.width * sliderPosition))
                                Spacer(minLength: 0)
                            }
                            .frame(width: fittedRect.width, height: fittedRect.height)
                        )

                    // Layer C: Synchronized Divider Line & Draggable Knob
                    let dividerX = fittedRect.width * sliderPosition
                    ZStack {
                        // Vertical Hairline
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2 / currentScale, height: fittedRect.height)
                            .shadow(color: .black.opacity(0.4), radius: 2 / currentScale, x: 0, y: 0)

                        // Interaction Knob Handle (Size maintained at comfortable screen scale)
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36 / currentScale, height: 36 / currentScale)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2 / currentScale)
                            )
                            .overlay(
                                HStack(spacing: 2 / currentScale) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 9 / currentScale, weight: .bold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9 / currentScale, weight: .bold))
                                }
                                .foregroundStyle(.primary)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 6 / currentScale, x: 0, y: 2 / currentScale)
                            .scaleEffect(isDraggingHandle ? 1.15 : 1.0)
                    }
                    .position(x: dividerX, y: fittedRect.height / 2)
                }
                .frame(width: fittedRect.width, height: fittedRect.height)
                .scaleEffect(currentScale)
                .offset(effectivePan)
                .contentShape(Rectangle())
                // Combined Tap to Position Divider & Double-Tap to Zoom
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if zoomScale > 1.05 {
                            zoomScale = 1.0
                            magnifyGestureScale = 1.0
                            panOffset = .zero
                            dragGestureOffset = .zero
                        } else {
                            zoomScale = 3.0
                            magnifyGestureScale = 1.0
                        }
                    }
                }
                .simultaneousGesture(
                    SpatialTapGesture(count: 1)
                        .onEnded { event in
                            let tapScreenX = event.location.x
                            let targetPos = (tapScreenX - containerCenter.x - effectivePan.width) / (fittedRect.width * currentScale) + 0.5
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                sliderPosition = max(0.001, min(0.999, targetPos))
                            }
                        }
                )
                // Unified Drag Gesture: Intelligently handles Divider Drag vs Canvas Pan
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .named("comparisonCanvas"))
                        .onChanged { value in
                            let dividerScreenX = containerCenter.x + effectivePan.width + (fittedRect.width * sliderPosition - fittedRect.width / 2) * currentScale
                            let touchDistance = abs(value.startLocation.x - dividerScreenX)

                            // Within 44pt touch zone of divider or unzoomed -> Drag Divider
                            if isDraggingHandle || touchDistance <= 44 || currentScale <= 1.05 {
                                isDraggingHandle = true
                                let touchScreenX = value.location.x
                                let newPos = (touchScreenX - containerCenter.x - effectivePan.width) / (fittedRect.width * currentScale) + 0.5
                                sliderPosition = max(0.001, min(0.999, newPos))
                            } else {
                                // Outside divider touch zone while zoomed in -> Pan Image
                                dragGestureOffset = value.translation
                            }
                        }
                        .onEnded { _ in
                            isDraggingHandle = false
                            if currentScale > 1.01 {
                                panOffset = currentPan(in: fittedRect.size)
                                dragGestureOffset = .zero
                            }
                        }
                )
                // Pinch-to-Zoom Gesture
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            magnifyGestureScale = value.magnification
                        }
                        .onEnded { value in
                            zoomScale = max(1.0, min(8.0, zoomScale * value.magnification))
                            magnifyGestureScale = 1.0

                            if zoomScale <= 1.05 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    zoomScale = 1.0
                                    panOffset = .zero
                                    dragGestureOffset = .zero
                                }
                            } else {
                                panOffset = currentPan(in: fittedRect.size)
                                dragGestureOffset = .zero
                            }
                        }
                )

                // ─── 2. Clean Minimal Floating Pill Badges ───
                VStack {
                    HStack {
                        Text("Original")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(.capsule)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 1)

                        Spacer()

                        if currentScale > 1.05 {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    zoomScale = 1.0
                                    magnifyGestureScale = 1.0
                                    panOffset = .zero
                                    dragGestureOffset = .zero
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(String(format: "%.1fx", currentScale))
                                }
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(.capsule)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Upscaled (\(scaleFactor)x)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial)
                            .clipShape(.capsule)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    Spacer()
                }
            }
            .coordinateSpace(name: "comparisonCanvas")
            .clipShape(.rect(cornerRadius: 16))
        }
    }
}
