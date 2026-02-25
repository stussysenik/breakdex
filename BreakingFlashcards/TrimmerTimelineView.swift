import SwiftUI
import AVFoundation

struct TrimmerTimelineView: View {
    let metrics: LayoutMetrics
    let thumbnailGenerator: AdaptiveThumbnailGenerator
    let duration: TimeInterval

    @Binding var startFraction: CGFloat  // 0...1
    @Binding var endFraction: CGFloat    // 0...1

    let onScrub: (CMTime) -> Void

    @GestureState private var startDragOffset: CGFloat? = nil
    @GestureState private var endDragOffset: CGFloat? = nil
    @State private var lastTickIndex: Int = -1

    private let handleWidth: CGFloat = 14
    private let handleExpandedWidth: CGFloat = 18
    private let minimumGapFraction: CGFloat = 0.02 // ~1s for 50s video

    private var timelineWidth: CGFloat { metrics.timelineWidth }
    private var timelineHeight: CGFloat { metrics.timelineHeight }
    private var thumbnailCount: Int { thumbnailGenerator.totalCount }

    private var startX: CGFloat { startFraction * timelineWidth }
    private var endX: CGFloat { endFraction * timelineWidth }

    private var minimumGap: CGFloat {
        guard duration > 0 else { return 10 }
        return max(10, timelineWidth * CGFloat(1.0 / duration))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Thumbnail strip
            thumbnailStrip

            // Dim overlays outside selection
            dimOverlays

            // Selection border
            selectionBorder

            // Start handle
            handle(isStart: true)

            // End handle
            handle(isStart: false)
        }
        .frame(width: timelineWidth, height: timelineHeight)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .coordinateSpace(name: "timeline")
    }

    // MARK: - Thumbnail Strip

    @ViewBuilder
    private var thumbnailStrip: some View {
        if duration > 120 {
            // Long videos: scrollable lazy strip
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 1) {
                    ForEach(0..<thumbnailCount, id: \.self) { index in
                        thumbnailCell(index: index)
                    }
                }
            }
            .frame(width: timelineWidth, height: timelineHeight)
            .background(Color.neutralFill)
        } else {
            // Short videos: regular HStack
            HStack(spacing: 1) {
                ForEach(0..<thumbnailCount, id: \.self) { index in
                    thumbnailCell(index: index)
                }
            }
            .frame(width: timelineWidth, height: timelineHeight)
            .background(Color.neutralFill)
        }
    }

    @ViewBuilder
    private func thumbnailCell(index: Int) -> some View {
        let cellWidth = timelineWidth / CGFloat(max(1, thumbnailCount))
        Group {
            if let image = thumbnailGenerator.thumbnail(at: index) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.neutralFill
            }
        }
        .frame(width: cellWidth, height: timelineHeight)
        .clipped()
        .onAppear {
            let lo = max(0, index - 2)
            let hi = min(thumbnailCount, index + 3)
            thumbnailGenerator.updateVisibleRange(lo..<hi)
        }
    }

    // MARK: - Dim Overlays

    private var dimOverlays: some View {
        ZStack(alignment: .leading) {
            // Left dim
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: max(0, startX), height: timelineHeight)

            // Right dim
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: max(0, timelineWidth - endX), height: timelineHeight)
                .offset(x: endX)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Selection Border

    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 3)
            .stroke(Color.accent, lineWidth: 2)
            .frame(width: max(0, endX - startX), height: timelineHeight)
            .offset(x: startX)
            .allowsHitTesting(false)
    }

    // MARK: - Handles

    @ViewBuilder
    private func handle(isStart: Bool) -> some View {
        let isDragging = isStart ? (startDragOffset != nil) : (endDragOffset != nil)
        let width = isDragging ? handleExpandedWidth : handleWidth
        let xPos = isStart ? startX - width / 2 : endX - width / 2

        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accent)
            .frame(width: width, height: timelineHeight)
            .overlay {
                Image(systemName: isStart ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: xPos)
            .animation(AppMotion.handleRelease, value: isDragging)
            .gesture(dragGesture(isStart: isStart))
    }

    private func dragGesture(isStart: Bool) -> some Gesture {
        if isStart {
            return DragGesture(coordinateSpace: .named("timeline"))
                .updating($startDragOffset) { value, state, _ in
                    state = value.location.x
                }
                .onChanged { value in
                    handleDragChanged(x: value.location.x, isStart: true)
                }
                .onEnded { _ in
                    HapticEngine.shared.trimPointSet()
                }
        } else {
            return DragGesture(coordinateSpace: .named("timeline"))
                .updating($endDragOffset) { value, state, _ in
                    state = value.location.x
                }
                .onChanged { value in
                    handleDragChanged(x: value.location.x, isStart: false)
                }
                .onEnded { _ in
                    HapticEngine.shared.trimPointSet()
                }
        }
    }

    private func handleDragChanged(x: CGFloat, isStart: Bool) {
        let fraction = max(0, min(1, x / timelineWidth))

        if isStart {
            let maxFraction = endFraction - minimumGap / timelineWidth
            startFraction = min(fraction, maxFraction)

            // Snap feedback at boundaries
            if startFraction <= 0.001 {
                HapticEngine.shared.handleSnap()
            }
        } else {
            let minFraction = startFraction + minimumGap / timelineWidth
            endFraction = max(fraction, minFraction)

            if endFraction >= 0.999 {
                HapticEngine.shared.handleSnap()
            }
        }

        // Scrub tick at thumbnail boundaries
        let currentIndex = Int(fraction * CGFloat(thumbnailCount))
        if currentIndex != lastTickIndex {
            lastTickIndex = currentIndex
            HapticEngine.shared.scrubTick()
        }

        // Seek preview
        let time = CMTime(seconds: Double(fraction) * duration, preferredTimescale: 600)
        onScrub(time)
    }
}
