import SwiftUI
import CoreHaptics
import OSLog

// MARK: - Liquid Scrubber
/// Variable-speed scrubbing system where vertical distance from the timeline
/// controls precision. Move finger up/down to increase precision for frame-accurate control.
///
/// Research-based implementation:
/// - Vertical distance = precision (farther = finer control)
/// - Haptic "ticks" at frame boundaries
/// - Haptic "thumps" at markers (start/end points)
/// - 56pt minimum touch targets for accessibility

// MARK: - Scrubber State

struct LiquidScrubberState {
    /// Current scrub ratio (1.0 = normal, 0.01 = finest)
    var scrubRatio: Double = 1.0

    /// Whether currently scrubbing
    var isScrubbing: Bool = false

    /// Start position of the drag
    var dragStartPosition: CGPoint = .zero

    /// Current position of the drag
    var currentPosition: CGPoint = .zero

    /// The time value at drag start
    var startTimeValue: Double = 0

    /// Vertical offset from timeline (controls precision)
    var verticalOffset: CGFloat = 0
}

// MARK: - Liquid Scrubber Configuration

struct LiquidScrubberConfig {
    /// Maximum vertical distance for finest precision (in points)
    let maxVerticalDistance: CGFloat = 200

    /// Minimum scrub ratio (finest control)
    let minScrubRatio: Double = 0.01

    /// Normal scrub ratio
    let normalScrubRatio: Double = 1.0

    /// Frame rate for haptic feedback
    var frameRate: Double = 30.0

    /// Whether to provide haptic feedback
    var hapticsEnabled: Bool = true

    /// Minimum touch target size
    let minTouchTarget: CGFloat = 56
}

// MARK: - Liquid Scrubber View Modifier

struct LiquidScrubberModifier: ViewModifier {
    @Binding var currentTime: Double
    let duration: Double
    let timelineY: CGFloat
    let config: LiquidScrubberConfig
    var onScrubStart: (() -> Void)?
    var onScrubEnd: (() -> Void)?
    var onFrameCrossed: (() -> Void)?
    var onMarkerCrossed: (() -> Void)?

    @State private var state = LiquidScrubberState()
    @State private var lastFrameIndex: Int = 0
    @ObservedObject private var accessibility = AccessibilityManager.shared

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎚️ LIQUID_SCRUBBER")

    func body(content: Content) -> some View {
        content
            .gesture(liquidScrubGesture)
            .overlay(alignment: .top) {
                if state.isScrubbing {
                    scrubIndicator
                }
            }
    }

    // MARK: - Scrub Gesture

    private var liquidScrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !state.isScrubbing {
                    // Start scrubbing
                    state.isScrubbing = true
                    state.dragStartPosition = value.startLocation
                    state.startTimeValue = currentTime
                    lastFrameIndex = frameIndex(for: currentTime)
                    onScrubStart?()
                    logger.debug("🎚️ Scrub started at time: \(currentTime)")
                }

                state.currentPosition = value.location

                // Calculate vertical offset from timeline
                state.verticalOffset = abs(value.location.y - timelineY)

                // Calculate scrub ratio based on vertical distance
                // Farther from timeline = finer precision
                let normalizedDistance = min(state.verticalOffset / config.maxVerticalDistance, 1.0)
                state.scrubRatio = config.normalScrubRatio - (normalizedDistance * (config.normalScrubRatio - config.minScrubRatio))

                // Apply scrubbed movement with ratio
                let horizontalDelta = value.translation.width
                let timeDelta = (Double(horizontalDelta) / 300.0) * duration * state.scrubRatio

                let newTime = max(0, min(state.startTimeValue + timeDelta, duration))

                // Check for frame boundary crossing
                let newFrameIndex = frameIndex(for: newTime)
                if newFrameIndex != lastFrameIndex {
                    // Frame boundary crossed - provide haptic feedback
                    if config.hapticsEnabled {
                        provideFrameHaptic()
                        onFrameCrossed?()
                    }
                    lastFrameIndex = newFrameIndex
                }

                currentTime = newTime
            }
            .onEnded { _ in
                state.isScrubbing = false
                onScrubEnd?()

                // Snap to nearest frame
                currentTime = snapToFrame(currentTime)

                // Final haptic
                if config.hapticsEnabled {
                    accessibility.mediumHaptic()
                }

                logger.debug("🎚️ Scrub ended at time: \(currentTime), ratio was: \(state.scrubRatio)")
            }
    }

    // MARK: - Scrub Indicator

    @ViewBuilder
    private var scrubIndicator: some View {
        VStack(spacing: 4) {
            // Precision indicator
            HStack(spacing: 8) {
                Image(systemName: precisionIcon)
                    .font(.caption)

                Text(precisionLabel)
                    .font(.ibmPlexMono(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.backgroundSecondary.opacity(0.95))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            // Time display
            Text(formatTime(currentTime))
                .font(.ibmPlexMono(size: 14, weight: .semibold))
                .foregroundColor(.accent)
        }
        .offset(y: -60)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(MotionSystem.micro, value: state.isScrubbing)
    }

    // MARK: - Helpers

    private var precisionIcon: String {
        if state.scrubRatio < 0.1 {
            return "scope" // Frame-accurate
        } else if state.scrubRatio < 0.5 {
            return "dial.low" // Fine
        } else {
            return "dial.high" // Normal
        }
    }

    private var precisionLabel: String {
        if state.scrubRatio < 0.1 {
            return "Frame"
        } else if state.scrubRatio < 0.5 {
            return "Fine"
        } else {
            return "Normal"
        }
    }

    private func frameIndex(for time: Double) -> Int {
        return Int(time * config.frameRate)
    }

    private func snapToFrame(_ time: Double) -> Double {
        let frameTime = 1.0 / config.frameRate
        return (time / frameTime).rounded() * frameTime
    }

    private func provideFrameHaptic() {
        // Light haptic for frame boundaries
        accessibility.lightHaptic()
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time - floor(time)) * config.frameRate)
        return String(format: "%d:%02d.%02d", minutes, seconds, frames)
    }
}

// MARK: - View Extension

extension View {
    /// Adds liquid scrubber behavior to a view
    func liquidScrubber(
        currentTime: Binding<Double>,
        duration: Double,
        timelineY: CGFloat,
        config: LiquidScrubberConfig = LiquidScrubberConfig(),
        onScrubStart: (() -> Void)? = nil,
        onScrubEnd: (() -> Void)? = nil,
        onFrameCrossed: (() -> Void)? = nil,
        onMarkerCrossed: (() -> Void)? = nil
    ) -> some View {
        modifier(LiquidScrubberModifier(
            currentTime: currentTime,
            duration: duration,
            timelineY: timelineY,
            config: config,
            onScrubStart: onScrubStart,
            onScrubEnd: onScrubEnd,
            onFrameCrossed: onFrameCrossed,
            onMarkerCrossed: onMarkerCrossed
        ))
    }
}

// MARK: - Liquid Trim Handle

/// Enhanced trim handle with liquid scrubbing support
struct LiquidTrimHandle: View {
    @Binding var time: Double
    let duration: Double
    let minTime: Double
    let maxTime: Double
    let frameRate: Double
    let usableWidth: CGFloat
    let handlePadding: CGFloat
    let isStart: Bool

    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?

    @State private var isDragging = false
    @State private var scrubRatio: Double = 1.0
    @State private var lastFrameIndex: Int = 0
    @State private var dragStartTime: Double = 0
    @State private var dragStartY: CGFloat = 0
    @ObservedObject private var accessibility = AccessibilityManager.shared

    private let config = LiquidScrubberConfig()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎚️ LIQUID_HANDLE")

    var body: some View {
        handleView
            .gesture(liquidDragGesture)
            .accessibilityLabel(isStart ? "Start trim handle" : "End trim handle")
            .accessibilityValue(String(format: "%.1f seconds", time))
            .accessibilityHint("Drag to adjust. Move finger up for finer control.")
    }

    // MARK: - Handle View

    @ViewBuilder
    private var handleView: some View {
        ZStack {
            // Main handle
            RoundedRectangle(cornerRadius: 2)
                .fill(isDragging ? Color.accent : Color.accent.opacity(0.8))

            // Grip indicators
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 4, height: 2)
                }
            }
        }
        .shadow(color: isDragging ? .accent.opacity(0.3) : .clear, radius: 4)
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(MotionSystem.micro, value: isDragging)
    }

    // MARK: - Liquid Drag Gesture

    private var liquidDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartTime = time
                    dragStartY = value.startLocation.y
                    lastFrameIndex = Int(time * frameRate)
                    onDragStart?()
                    accessibility.selectionHaptic()
                }

                // Calculate vertical distance for precision
                let verticalOffset = abs(value.location.y - dragStartY)

                // Map vertical distance to scrub ratio
                let normalizedDistance = min(verticalOffset / config.maxVerticalDistance, 1.0)
                scrubRatio = config.normalScrubRatio - (normalizedDistance * (config.normalScrubRatio - config.minScrubRatio))

                // Calculate position with scrub ratio applied
                let horizontalDelta = value.translation.width * scrubRatio
                let timePerPoint = duration / Double(usableWidth)
                var newTime = dragStartTime + (Double(horizontalDelta) * timePerPoint)

                // Clamp to valid range
                newTime = max(minTime, min(newTime, maxTime))

                // Check for frame crossing
                let newFrameIndex = Int(newTime * frameRate)
                if newFrameIndex != lastFrameIndex {
                    accessibility.lightHaptic()
                    lastFrameIndex = newFrameIndex
                }

                time = newTime
            }
            .onEnded { _ in
                isDragging = false

                // Snap to frame
                let frameTime = 1.0 / frameRate
                time = (time / frameTime).rounded() * frameTime

                accessibility.mediumHaptic()
                onDragEnd?()

                logger.debug("🎚️ Handle drag ended at \(time)s with final ratio \(scrubRatio)")
            }
    }
}

// MARK: - Precision Indicator

/// Shows current scrubbing precision
struct ScrubPrecisionIndicator: View {
    let scrubRatio: Double
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption)

                Text(label)
                    .font(.ibmPlexMono(size: 10, weight: .medium))

                // Precision bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))

                        Capsule()
                            .fill(fillColor)
                            .frame(width: geo.size.width * (1.0 - scrubRatio))
                    }
                }
                .frame(width: 40, height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.backgroundSecondary.opacity(0.9))
            .clipShape(Capsule())
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var iconName: String {
        if scrubRatio < 0.1 { return "scope" }
        if scrubRatio < 0.5 { return "dial.low" }
        return "dial.high"
    }

    private var label: String {
        if scrubRatio < 0.1 { return "Frame" }
        if scrubRatio < 0.5 { return "Fine" }
        return "Normal"
    }

    private var fillColor: Color {
        if scrubRatio < 0.1 { return .green }
        if scrubRatio < 0.5 { return .orange }
        return .accent
    }
}

// MARK: - Preview

#if DEBUG
struct LiquidScrubber_Previews: PreviewProvider {
    static var previews: some View {
        LiquidScrubberDemoView()
    }
}

struct LiquidScrubberDemoView: View {
    @State private var currentTime: Double = 30.0
    let duration: Double = 120.0

    var body: some View {
        VStack(spacing: 40) {
            Text("Liquid Scrubber Demo")
                .font(.ibmPlexMono(size: 20, weight: .bold))

            Text("Current: \(String(format: "%.2f", currentTime))s")
                .font(.ibmPlexMono(size: 16))

            // Timeline with liquid scrubber
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 40)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent.opacity(0.5))
                        .frame(width: geo.size.width * CGFloat(currentTime / duration), height: 40)

                    // Playhead
                    Circle()
                        .fill(Color.accent)
                        .frame(width: 20, height: 20)
                        .offset(x: geo.size.width * CGFloat(currentTime / duration) - 10)
                }
                .liquidScrubber(
                    currentTime: $currentTime,
                    duration: duration,
                    timelineY: geo.frame(in: .global).midY
                )
            }
            .frame(height: 40)
            .padding(.horizontal, 20)

            Text("Drag left/right to scrub\nMove finger up/down for precision")
                .font(.ibmPlexMono(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Precision indicators demo
            VStack(spacing: 12) {
                ScrubPrecisionIndicator(scrubRatio: 1.0, isVisible: true)
                ScrubPrecisionIndicator(scrubRatio: 0.5, isVisible: true)
                ScrubPrecisionIndicator(scrubRatio: 0.05, isVisible: true)
            }
        }
        .padding()
    }
}
#endif
