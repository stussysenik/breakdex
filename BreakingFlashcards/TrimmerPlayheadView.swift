import SwiftUI
import AVFoundation

struct TrimmerPlayheadView: View {
    let metrics: LayoutMetrics
    let duration: TimeInterval
    let startFraction: CGFloat
    let endFraction: CGFloat

    /// Current playback fraction (0...1 of full duration)
    @Binding var currentFraction: CGFloat

    let onScrub: (CMTime) -> Void

    @GestureState private var isDragging = false
    @State private var lastScrubTick: Int = -1

    private var timelineWidth: CGFloat { metrics.timelineWidth }
    private var timelineHeight: CGFloat { metrics.timelineHeight }
    private var lineWidth: CGFloat { isDragging ? 3 : 2 }
    private var grabSize: CGFloat { isDragging ? 14 : 10 }

    /// Clamp playhead X to the selected region
    private var playheadX: CGFloat {
        let clamped = max(startFraction, min(endFraction, currentFraction))
        return clamped * timelineWidth
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Playhead line
            Rectangle()
                .fill(Color.white)
                .frame(width: lineWidth, height: timelineHeight)
                .elevation(Elevation.medium)
                .offset(x: playheadX - lineWidth / 2)

            // Grab handle circle on top
            Circle()
                .fill(Color.white)
                .frame(width: grabSize, height: grabSize)
                .elevation(Elevation.low)
                .offset(x: playheadX - grabSize / 2, y: -(timelineHeight / 2) - grabSize / 2 + 2)
        }
        .frame(width: timelineWidth, height: timelineHeight)
        .contentShape(Rectangle())
        .animation(AppMotion.scrubRelease, value: isDragging)
        .gesture(
            DragGesture(coordinateSpace: .named("timeline"))
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    if !isDragging {
                        HapticEngine.shared.handleGrab()
                    }
                    let fraction = max(startFraction, min(endFraction, value.location.x / timelineWidth))
                    currentFraction = fraction

                    // Scrub tick feedback
                    let tickIndex = Int(fraction * 100)
                    if tickIndex != lastScrubTick {
                        lastScrubTick = tickIndex
                        HapticEngine.shared.scrubTick()
                    }

                    let time = CMTime(seconds: Double(fraction) * duration, preferredTimescale: 600)
                    onScrub(time)
                }
                .onEnded { _ in
                    HapticEngine.shared.trimPointSet()
                }
        )
    }
}
