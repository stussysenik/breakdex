import SwiftUI
import AVFoundation

struct HybridPreciseTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel

    // Custom handle views
    var startHandleView: AnyView?
    var endHandleView: AnyView?

    private let handleWidth: CGFloat = 44

    // Haptic Feedback Generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
            let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)

            let startDragGesture = drag(handle: .start, in: geometry)
            let endDragGesture = drag(handle: .end, in: geometry)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: trackWidth, height: 6)
                    .offset(x: handleWidth/2)

                // Active range
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: endX - startX, height: 6)
                    .offset(x: startX + handleWidth/2)

                // Start handle
                if let startView = startHandleView {
                    handle(content: startView)
                        .offset(x: startX)
                        .gesture(startDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle))
                        .offset(x: startX)
                        .gesture(startDragGesture)
                }

                // End handle
                if let endView = endHandleView {
                    handle(content: endView)
                        .offset(x: endX)
                        .gesture(endDragGesture)
                } else {
                    handle(content: Text("🔥").font(.largeTitle))
                        .offset(x: endX)
                        .gesture(endDragGesture)
                }
            }
        }
        .coordinateSpace(name: "track")
        .frame(height: 60)
        .onAppear {
            viewModel.startCoalescing()
        }
        .onDisappear(perform: viewModel.stopCoalescing)
    }

    private func handle(content: some View) -> some View {
        content
    }

    // MARK: - Coordinate System

    private func timeToXLeft(_ t: CMTime, trackWidth: CGFloat) -> CGFloat {
        guard viewModel.videoDuration.seconds > 0 else { return 0 }
        let p = t.seconds / viewModel.videoDuration.seconds
        return CGFloat(p) * trackWidth
    }

    private func xLeftToTime(_ x: CGFloat, trackWidth: CGFloat) -> CMTime {
        let clamped = max(0, min(x, trackWidth))
        let seconds = Double(clamped / trackWidth) * viewModel.videoDuration.seconds
        return CMTime(seconds: seconds, preferredTimescale: viewModel.videoDuration.timescale)
    }

    private func minDistancePx(_ g: GeometryProxy) -> CGFloat {
        let trackWidth = g.size.width - handleWidth
        let pps = trackWidth / viewModel.videoDuration.seconds
        return pps * viewModel.minimumDuration.seconds
    }

    private func drag(handle: HandleType, in g: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { value in
                if handle == .start && !viewModel.isDraggingStartHandle {
                    viewModel.isDraggingStartHandle = true
                    viewModel.startCoalescing()
                    impactGenerator.impactOccurred()
                    selectionGenerator.prepare()
                } else if handle == .end && !viewModel.isDraggingEndHandle {
                    viewModel.isDraggingEndHandle = true
                    viewModel.startCoalescing()
                    impactGenerator.impactOccurred()
                    selectionGenerator.prepare()
                }

                let trackWidth = g.size.width - handleWidth
                let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
                let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)
                let minPx = minDistancePx(g)

                // finger-aligned center -> left-edge
                var proposedLeft = value.location.x - handleWidth/2
                proposedLeft = max(0, min(proposedLeft, trackWidth))

                // bumper
                switch handle {
                case .start:
                    proposedLeft = min(proposedLeft, endX - minPx)
                case .end:
                    proposedLeft = max(proposedLeft, startX + minPx)
                }

                let t = xLeftToTime(proposedLeft, trackWidth: trackWidth)
                viewModel.proposeTime(t, for: handle)

                // Haptic feedback for normal sliding
                selectionGenerator.selectionChanged()
            }
            .onEnded { value in
                let trackWidth = g.size.width - handleWidth
                var xLeft = value.location.x - handleWidth/2
                xLeft = max(0, min(xLeft, trackWidth))
                let t = xLeftToTime(xLeft, trackWidth: trackWidth)
                viewModel.commitTime(t, for: handle)

                if handle == .start { viewModel.isDraggingStartHandle = false }
                else { viewModel.isDraggingEndHandle = false }

                viewModel.stopCoalescing()
                impactGenerator.impactOccurred()
            }
    }
}

// MARK: - Convenience Initializers for Common Handle Styles
extension HybridPreciseTrimmerView {
    // Default initializer with emoji fallback
    init(viewModel: TrimmerViewModel) {
        self.viewModel = viewModel
        self.startHandleView = nil
        self.endHandleView = nil
    }

    // Emoji handles - for backward compatibility
    static func emoji(viewModel: TrimmerViewModel,
                     startEmoji: String = "👟",
                     endEmoji: String = "🔥") -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleView: AnyView(Text(startEmoji).font(.largeTitle)),
            endHandleView: AnyView(Text(endEmoji).font(.largeTitle))
        )
    }

    // Custom view handles - now properly uses custom views
    static func custom(viewModel: TrimmerViewModel,
                      startView: some View,
                      endView: some View) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleView: AnyView(startView),
            endHandleView: AnyView(endView)
        )
    }
}
