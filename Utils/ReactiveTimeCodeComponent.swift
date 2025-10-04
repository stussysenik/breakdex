import SwiftUI
import AVFoundation
import Combine
import OSLog

// Local import for memory utilities
import breakdex // Import the module to access TimecodeFormatter

/// Enhanced reactive time code component that provides smooth animated time displays
/// with frame-accurate timing and visual feedback for active states
struct ReactiveTimeCodeComponent: View {

    // MARK: - Configuration
    enum TimeCodePosition {
        case start, end, duration
    }

    enum DisplayMode {
        case timeOnly         // Shows only time (MM:SS.mmm)
        case frameOnly        // Shows only frame count
        case timeAndFrame     // Shows both time and frame
        case durationOnly     // Shows duration with visual warning
    }

    // MARK: - Properties
    let time: CMTime
    let position: TimeCodePosition
    let isActive: Bool
    let displayMode: DisplayMode
    let frameRate: Double
    let showWarning: Bool
    let minimumDuration: CMTime?

    // MARK: - Animation State
    @State private var animatedOpacity: Double = 0.0
    @State private var scaleEffect: Double = 1.0
    @State private var isPulsing: Bool = false

    // MARK: - Constants
    private let animationDuration: Double = 0.15
    private let pulseDuration: Double = 0.6
    private let warningPulseInterval: Double = 1.0

    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "ReactiveTimeCodeComponent")

    // MARK: - Simplified Animation State
    // Complex animation state tracking removed to eliminate conflicts
    // SwiftUI's default transitions provide smooth, reliable animations

    // MARK: - Initialization
    init(
        time: CMTime,
        position: TimeCodePosition,
        isActive: Bool = false,
        displayMode: DisplayMode = .timeOnly,
        frameRate: Double = 30.0,
        showWarning: Bool = false,
        minimumDuration: CMTime? = nil
    ) {
        self.time = time
        self.position = position
        self.isActive = isActive
        self.displayMode = displayMode
        self.frameRate = frameRate
        self.showWarning = showWarning
        self.minimumDuration = minimumDuration

        // Initialize animated state
        _animatedOpacity = State(initialValue: 0.0)
    }

    var body: some View {
        VStack(spacing: 4) {
            mainContent
                .scaleEffect(scaleEffect)
                .opacity(animatedOpacity)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7),
                    value: [scaleEffect, animatedOpacity]
                )

            if shouldShowFrameInfo {
                frameInfoView
                    .font(.ibmPlexMono(size: 9, weight: .regular))
                    .foregroundColor(isActive ? Color.accent.opacity(0.8) : Color.textSecondary.opacity(0.7))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onAppear {
            setupInitialAnimations()
            startTimeAnimation()
        }
        // .onChange(of: time) block removed - eliminates animation conflicts
        .onChange(of: isActive) { _, newActiveState in
            animateActiveStateChange(to: newActiveState)
        }
        .onChange(of: showWarning) { _, newWarningState in
            handleWarningStateChange(to: newWarningState)
        }
        .onDisappear {
            // Cleanup is minimal in simplified version
        }
    }

    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        HStack(spacing: 6) {
            if shouldShowWarning {
                warningIcon
            }

            timeDisplay
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowOffset
        )
    }

    @ViewBuilder
    private var timeDisplay: some View {
        let displayString = timeDisplayString

        Text(displayString)
            .font(font)
            .foregroundColor(textColor)
            .contentTransition(.numericText())
            // .animation modifier removed - SwiftUI handles updates naturally
    }

    @ViewBuilder
    private var frameInfoView: some View {
        HStack(spacing: 4) {
            if position != .duration {
                Text("Frame \(frameNumber)")
                    .font(.ibmPlexMono(size: 9, weight: .medium))
            }

            if displayMode == .timeAndFrame && position != .duration {
                Text("•")
                    .font(.system(size: 8))
            }

            if displayMode == .timeAndFrame || displayMode == .durationOnly {
                Text(frameRateString)
                    .font(.ibmPlexMono(size: 9, weight: .regular))
            }
        }
    }

    @ViewBuilder
    private var warningIcon: some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.buttonHard)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(
                .easeInOut(duration: pulseDuration).repeatForever(autoreverses: true),
                value: isPulsing
            )
    }

    // MARK: - Computed Properties
    private var shouldShowFrameInfo: Bool {
        return displayMode == .timeAndFrame || displayMode == .frameOnly
    }

    private var shouldShowWarning: Bool {
        return showWarning && minimumDuration != nil
    }

    private var timeDisplayString: String {
        switch displayMode {
        case .timeOnly, .timeAndFrame:
            return TimecodeFormatter.format(time: time)
        case .frameOnly:
            return "\(frameNumber)"
        case .durationOnly:
            return TimecodeFormatter.formatDuration(time: time, minimumDuration: minimumDuration)
        }
    }

    private var frameNumber: Int {
        guard frameRate > 0 else { return 0 }
        return Int(time.seconds * frameRate)
    }

    private var frameRateString: String {
        return String(format: "%.0ffps", frameRate)
    }

    private var font: Font {
        let baseSize: CGFloat = isActive ? 12 : 11
        let weight: Font.Weight = isActive ? .medium : .regular

        return .ibmPlexMono(size: baseSize, weight: weight)
    }

    private var textColor: Color {
        if showWarning {
            return .buttonHard
        }
        return isActive ? Color.accent : Color.textPrimary
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accent.opacity(0.15)
        } else if showWarning {
            return Color.buttonHard.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isActive {
            return Color.accent
        } else if showWarning {
            return Color.buttonHard
        } else {
            return Color.clear
        }
    }

    private var borderWidth: CGFloat {
        return isActive ? 1.5 : (showWarning ? 1.0 : 0.0)
    }

    private var shadowColor: Color {
        if isActive {
            return Color.accent.opacity(0.3)
        } else if showWarning {
            return Color.buttonHard.opacity(0.2)
        } else {
            return Color.clear
        }
    }

    private var shadowRadius: CGFloat {
        return isActive ? 4 : (showWarning ? 2 : 0)
    }

    private var shadowOffset: CGFloat {
        return isActive ? 2 : (showWarning ? 1 : 0)
    }

    // MARK: - Animation Methods
    private func setupInitialAnimations() {
        let animationStartTime = Date()

        withAnimation(.easeInOut(duration: animationDuration)) {
            animatedOpacity = 1.0
        }

        let animationDuration = Date().timeIntervalSince(animationStartTime)

        diagnosticLogger.logDebug("⚡ ReactiveTimeCodeComponent initialized", metadata: [
            "position": "\(position)",
            "initial_time": "\(time.seconds)",
            "initial_time_formatted": "\(TimecodeFormatter.format(time: time))",
            "is_active": "\(isActive)",
            "display_mode": "\(displayMode)",
            "animation_duration_ms": "\(animationDuration * 1000)",
            "frame_rate": "\(frameRate)",
            "frame_number": "\(frameNumber)",
            "minimum_duration": "\(minimumDuration?.seconds ?? 0)",
            "memory_usage_mb": "\(MemoryHelper.getCurrentMemoryUsage())"
        ])
    }

    private func startTimeAnimation() {
        // No complex animation needed - SwiftUI handles the updates naturally
    }

    private func animateActiveStateChange(to active: Bool) {
        let animationStartTime = Date()
        let targetScale: Double = active ? 1.05 : 1.0
        let targetOpacity: Double = active ? 1.0 : 0.9

        // Simplified logging without animation state tracking
        diagnosticLogger.logDebug("🎭 Active state animation", metadata: [
            "target_active": "\(active)",
            "target_scale": "\(targetScale)",
            "target_opacity": "\(targetOpacity)",
            "position": "\(position)",
            "current_time": "\(time.seconds)",
            "current_time_formatted": "\(TimecodeFormatter.format(time: time))",
            "frame_rate": "\(frameRate)"
        ])

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scaleEffect = targetScale
            animatedOpacity = targetOpacity
        }

        let finalAnimationDuration = Date().timeIntervalSince(animationStartTime)
        diagnosticLogger.logDebug("🎭 Active state animation complete", metadata: [
            "new_active_state": "\(active)",
            "animation_duration_ms": "\(finalAnimationDuration * 1000)",
            "final_scale": "\(scaleEffect)",
            "final_opacity": "\(animatedOpacity)",
            "sync_success": "\(scaleEffect == targetScale && animatedOpacity == targetOpacity)"
        ])
    }

    private func handleWarningStateChange(to warning: Bool) {
        if warning {
            isPulsing = true
            diagnosticLogger.logDebug("⚠️ Warning pulse started", metadata: [
                "position": "\(position)",
                "current_duration": "\(time.seconds)",
                "current_duration_formatted": "\(TimecodeFormatter.formatDuration(time: time, minimumDuration: minimumDuration))",
                "minimum_duration": "\(minimumDuration?.seconds ?? 0)",
                "minimum_duration_formatted": "\(minimumDuration != nil ? TimecodeFormatter.format(time: minimumDuration!) : "N/A")",
                "pulse_duration": "\(pulseDuration)",
                "warning_violation": "\((minimumDuration != nil && time.seconds < minimumDuration!.seconds))"
            ])
        } else {
            isPulsing = false
            diagnosticLogger.logDebug("⚠️ Warning pulse stopped", metadata: [
                "position": "\(position)",
                "was_pulsing": "\(true)",
                "final_duration": "\(time.seconds)",
                "final_duration_formatted": "\(TimecodeFormatter.formatDuration(time: time, minimumDuration: minimumDuration))",
                "minimum_met": "\((minimumDuration != nil && time.seconds >= minimumDuration!.seconds))",
                "pulse_stopped_gracefully": "\(true)"
            ])
        }
    }

    // MARK: - Simplified Public API

    /// Returns the current time (no complex synchronization needed)
    var synchronizedTime: CMTime {
        return time
    }

    /// Validates timecode consistency (always true in simplified version)
    func validateTimecodeConsistency() -> Bool {
        return true
    }

    /// Handles rotation state changes (simplified)
    func handleRotationStateChange() {
        diagnosticLogger.logDebug("🔄 Rotation state change", metadata: [
            "position": "\(position)",
            "current_time": "\(time.seconds)",
            "current_time_formatted": "\(TimecodeFormatter.format(time: time))"
        ])
        // SwiftUI handles the updates naturally
    }

    /// Handles validation state changes (simplified)
    func handleValidationStateChange(isWarning: Bool) {
        diagnosticLogger.logDebug("✅ Validation state change", metadata: [
            "position": "\(position)",
            "warning_state": "\(isWarning)",
            "memory_pressure": MemoryHelper.getCurrentMemoryUsage()
        ])

        // SwiftUI handles the updates naturally
    }

    // MARK: - Animation Diagnostics (Simplified)
    func getAnimationDiagnostics() -> [String: String] {
        return [
            "position": "\(position)",
            "display_mode": "\(displayMode)",
            "is_active": "\(isActive)",
            "show_warning": "\(showWarning)"
        ]
    }

    // MARK: - Utility Methods
    // MARK: - REMOVED: Local formatting methods replaced with centralized TimecodeFormatter
    // The following methods have been replaced with calls to TimecodeFormatter.format() and
    // TimecodeFormatter.formatDuration() to ensure consistency and precision across all components.
}

// MARK: - Convenience Initializers
extension ReactiveTimeCodeComponent {

    /// Create a start time display
    static func startTime(
        _ time: CMTime,
        isActive: Bool = false,
        frameRate: Double = 30.0
    ) -> ReactiveTimeCodeComponent {
        ReactiveTimeCodeComponent(
            time: time,
            position: .start,
            isActive: isActive,
            displayMode: .timeOnly,
            frameRate: frameRate
        )
    }

    /// Create an end time display
    static func endTime(
        _ time: CMTime,
        isActive: Bool = false,
        frameRate: Double = 30.0
    ) -> ReactiveTimeCodeComponent {
        ReactiveTimeCodeComponent(
            time: time,
            position: .end,
            isActive: isActive,
            displayMode: .timeOnly,
            frameRate: frameRate
        )
    }

    /// Create a duration display with warning capability
    static func duration(
        _ time: CMTime,
        minimumDuration: CMTime,
        showWarning: Bool = false,
        frameRate: Double = 30.0
    ) -> ReactiveTimeCodeComponent {
        ReactiveTimeCodeComponent(
            time: time,
            position: .duration,
            isActive: false,
            displayMode: .durationOnly,
            frameRate: frameRate,
            showWarning: showWarning,
            minimumDuration: minimumDuration
        )
    }

    /// Create a time display with frame information
    static func timeWithFrame(
        _ time: CMTime,
        position: TimeCodePosition,
        isActive: Bool = false,
        frameRate: Double = 30.0
    ) -> ReactiveTimeCodeComponent {
        ReactiveTimeCodeComponent(
            time: time,
            position: position,
            isActive: isActive,
            displayMode: .timeAndFrame,
            frameRate: frameRate
        )
    }
}

// MARK: - Preview
struct ReactiveTimeCodeComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ReactiveTimeCodeComponent.startTime(
                    CMTime(seconds: 12.345, preferredTimescale: 600),
                    isActive: true
                )

                ReactiveTimeCodeComponent.duration(
                    CMTime(seconds: 5.678, preferredTimescale: 600),
                    minimumDuration: CMTime(seconds: 3.0, preferredTimescale: 600),
                    showWarning: false
                )

                ReactiveTimeCodeComponent.endTime(
                    CMTime(seconds: 18.023, preferredTimescale: 600),
                    isActive: false
                )
            }

            HStack(spacing: 16) {
                ReactiveTimeCodeComponent.duration(
                    CMTime(seconds: 2.1, preferredTimescale: 600),
                    minimumDuration: CMTime(seconds: 3.0, preferredTimescale: 600),
                    showWarning: true
                )

                ReactiveTimeCodeComponent.timeWithFrame(
                    CMTime(seconds: 15.750, preferredTimescale: 600),
                    position: .start,
                    isActive: true,
                    frameRate: 60.0
                )
            }
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
