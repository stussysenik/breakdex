import SwiftUI
import AVFoundation
import Combine
import OSLog

// Local import for memory utilities

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

    // MARK: - Animation State Tracking
    @State private var animationState = AnimationState()

    private struct AnimationState {
        var lastAnimationTime: Date = .distantPast
        var animationCount: Int = 0
        var conflictingAnimations: Int = 0
        var averageAnimationDuration: Double = 0
        var lastAnimationDuration: Double = 0
        var lastMemoryUsage: Double = 0
    }

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
            return formatTimeWithMs(time)
        case .frameOnly:
            return "\(frameNumber)"
        case .durationOnly:
            return formatDurationWithMs(time)
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
        updateAnimationState(duration: animationDuration, type: "initial_setup")

        diagnosticLogger.logDebug("⚡ ReactiveTimeCodeComponent initialized", metadata: [
            "position": "\(position)",
            "initial_time": "\(time.seconds)",
            "initial_time_formatted": "\(formatTimeWithMs(time))",
            "is_active": "\(isActive)",
            "display_mode": "\(displayMode)",
            "animation_duration_ms": "\(animationDuration * 1000)",
            "animation_count": "\(animationState.animationCount)",
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

        // Log animation start with context
        diagnosticLogger.logAnimation("active_state_change_start", metadata: [
            "target_active": "\(active)",
            "target_scale": "\(targetScale)",
            "target_opacity": "\(targetOpacity)",
            "current_scale": "\(scaleEffect)",
            "current_opacity": "\(animatedOpacity)",
            "position": "\(position)",
            "current_time": "\(time.seconds)",
            "current_time_formatted": "\(formatTimeWithMs(time))",
            "time_since_last_animation": "\(Date().timeIntervalSince(animationState.lastAnimationTime))",
            "animation_queue_pressure": "\(animationState.animationCount)",
            "memory_usage_mb": "\(MemoryHelper.getCurrentMemoryUsage())",
            "frame_rate": "\(frameRate)"
        ])

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scaleEffect = targetScale
            animatedOpacity = targetOpacity
        }

        let animationDuration = Date().timeIntervalSince(animationStartTime)
        updateAnimationState(duration: animationDuration, type: "active_state_change")

        diagnosticLogger.logAnimation("active_state_change_complete", metadata: [
            "new_active_state": "\(active)",
            "animation_duration_ms": "\(animationDuration * 1000)",
            "total_animations": "\(animationState.animationCount)",
            "avg_duration_ms": "\(animationState.averageAnimationDuration * 1000)",
            "final_scale": "\(scaleEffect)",
            "final_opacity": "\(animatedOpacity)",
            "sync_success": "\(scaleEffect == targetScale && animatedOpacity == targetOpacity)"
        ])
    }

    private func handleWarningStateChange(to warning: Bool) {
        let animationStartTime = Date()

        if warning {
            isPulsing = true
            diagnosticLogger.logAnimation("warning_pulse_start", metadata: [
                "position": "\(position)",
                "current_duration": "\(time.seconds)",
                "current_duration_formatted": "\(formatDurationWithMs(time))",
                "minimum_duration": "\(minimumDuration?.seconds ?? 0)",
                "minimum_duration_formatted": "\(minimumDuration != nil ? formatDurationWithMs(minimumDuration!) : "N/A")",
                "pulse_duration": "\(pulseDuration)",
                "pulse_interval": "\(warningPulseInterval)",
                "warning_violation": "\((minimumDuration != nil && time.seconds < minimumDuration!.seconds))",
                "severity": "minimum_duration_breach",
                "animation_state": "\(animationState.animationCount) animations running"
            ])
        } else {
            isPulsing = false
            diagnosticLogger.logAnimation("warning_pulse_stop", metadata: [
                "position": "\(position)",
                "was_pulsing": "\(true)",
                "final_duration": "\(time.seconds)",
                "final_duration_formatted": "\(formatDurationWithMs(time))",
                "minimum_met": "\((minimumDuration != nil && time.seconds >= minimumDuration!.seconds))",
                "pulse_stopped_gracefully": "\(true)"
            ])
        }

        let animationDuration = Date().timeIntervalSince(animationStartTime)
        updateAnimationState(duration: animationDuration, type: "warning_state_change")
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
        let changeTime = Date()

        diagnosticLogger.logAnimation("rotation_state_change", metadata: [
            "position": "\(position)",
            "current_time": "\(time.seconds)",
            "time_since_last_animation": "\(changeTime.timeIntervalSince(animationState.lastAnimationTime))",
            "total_animations_so_far": "\(animationState.animationCount)",
            "potential_conflict_risk": animationState.animationCount > 0 ? "high" : "low"
        ])

        updateAnimationState(duration: 0.0, type: "rotation_change")
        // SwiftUI handles the updates naturally
    }

    /// Handles validation state changes (simplified)
    func handleValidationStateChange(isWarning: Bool) {
        let changeTime = Date()

        diagnosticLogger.logAnimation("validation_state_change", metadata: [
            "position": "\(position)",
            "warning_state": "\(isWarning)",
            "time_since_last_animation": "\(changeTime.timeIntervalSince(animationState.lastAnimationTime))",
            "animation_queue_pressure": animationState.animationCount > 2 ? "high" : "normal",
            "memory_pressure": MemoryHelper.getCurrentMemoryUsage()
        ])

        updateAnimationState(duration: 0.0, type: "validation_change")
        // SwiftUI handles the updates naturally
    }

    // MARK: - Animation State Management
    private func updateAnimationState(duration: Double, type: String) {
        let now = Date()
        let timeSinceLastAnimation = now.timeIntervalSince(animationState.lastAnimationTime)
        let memoryInfo = MemoryHelper.getDetailedMemoryInfo()

        // Detect potential animation conflicts with enhanced detection
        let isConflictRisk = timeSinceLastAnimation < 0.1 && animationState.animationCount > 0
        let conflictSeverity = timeSinceLastAnimation < 0.05 ? "high" : (timeSinceLastAnimation < 0.1 ? "medium" : "low")

        if isConflictRisk {
            animationState.conflictingAnimations += 1
            diagnosticLogger.logAnimationWarning("potential_animation_conflict", metadata: [
                "time_since_last_ms": "\(timeSinceLastAnimation * 1000)",
                "animation_type": "\(type)",
                "duration_ms": "\(duration * 1000)",
                "total_conflicts": "\(animationState.conflictingAnimations)",
                "recent_animation_count": "\(animationState.animationCount)",
                "conflict_severity": "\(conflictSeverity)",
                "position": "\(position)",
                "display_mode": "\(displayMode)",
                "current_time": "\(time.seconds)",
                "memory_pressure_mb": "\(memoryInfo.used)",
                "memory_pressure_percent": "\(memoryInfo.percentage)"
            ])
        }

        // Update state tracking
        animationState.lastAnimationTime = now
        animationState.animationCount += 1
        animationState.lastAnimationDuration = duration

        // Calculate rolling average with enhanced metrics
        animationState.averageAnimationDuration =
            (animationState.averageAnimationDuration * Double(animationState.animationCount - 1) + duration) / Double(animationState.animationCount)

        // Enhanced performance metrics
        let animationEfficiency = duration < 0.05 ? "excellent" : (duration < 0.1 ? "good" : "slow")
        let memoryDelta = memoryInfo.used - animationState.lastMemoryUsage
        animationState.lastMemoryUsage = memoryInfo.used

        // Periodic performance logging with enhanced details
        if animationState.animationCount % 10 == 0 {
            diagnosticLogger.logAnimationPerformance("periodic_animation_stats", metadata: [
                "total_animations": "\(animationState.animationCount)",
                "avg_duration_ms": "\(animationState.averageAnimationDuration * 1000)",
                "last_duration_ms": "\(duration * 1000)",
                "conflict_count": "\(animationState.conflictingAnimations)",
                "conflict_rate": "\(Double(animationState.conflictingAnimations) / Double(animationState.animationCount))",
                "animation_efficiency": "\(animationEfficiency)",
                "memory_usage_mb": "\(memoryInfo.used)",
                "memory_delta_mb": "\(memoryDelta)",
                "memory_pressure": "\(memoryInfo.percentage)",
                "position": "\(position)",
                "active_state": "\(isActive)",
                "warning_state": "\(showWarning)",
                "frame_rate": "\(frameRate)"
            ])
        }
    }

    // MARK: - Animation Diagnostics
    func getAnimationDiagnostics() -> [String: String] {
        return [
            "total_animations": "\(animationState.animationCount)",
            "conflicting_animations": "\(animationState.conflictingAnimations)",
            "average_duration_ms": "\(animationState.averageAnimationDuration * 1000)",
            "last_duration_ms": "\(animationState.lastAnimationDuration * 1000)",
            "position": "\(position)",
            "display_mode": "\(displayMode)"
        ]
    }

    // MARK: - Utility Methods
    private func formatTimeWithMs(_ time: CMTime) -> String {
        let seconds = time.seconds
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds - Double(Int(seconds))) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
    }

    private func formatDurationWithMs(_ time: CMTime) -> String {
        let seconds = abs(time.seconds)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds - Double(Int(seconds))) * 1000)

        if position == .duration {
            return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
        } else {
            return formatTimeWithMs(time)
        }
    }
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