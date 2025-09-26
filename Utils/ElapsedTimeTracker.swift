import SwiftUI
import Combine
import OSLog

/// Utility service for tracking elapsed time during async operations
/// Provides MM:SS formatted time display with real-time updates
@MainActor
public class ElapsedTimeTracker: ObservableObject {
    @Published public private(set) var elapsedSeconds: TimeInterval = 0
    @Published public private(set) var formattedTime: String = "00:00"
    @Published public private(set) var isActive: Bool = false

    private var timer: Timer?
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "ElapsedTimeTracker")

    public init() {}

    /// Start tracking elapsed time from now
    public func start() {
        guard !isActive else { return }

        logger.info("⏱️ ELAPSED_TIME_TRACKER: Starting timer for operation timing")

        isActive = true
        elapsedSeconds = 0
        formattedTime = "00:00"

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.elapsedSeconds += 1.0
                self.formattedTime = self.formatTime(self.elapsedSeconds)

                // Enhanced diagnostic logging with performance thresholds
                self.logPerformanceMilestones()
            }
        }
    }

    /// Stop tracking elapsed time
    public func stop() {
        guard isActive else { return }

        logger.info("⏱️ ELAPSED_TIME_TRACKER: Stopping timer - Final elapsed time: \(self.formattedTime)")

        isActive = false
        timer?.invalidate()
        timer = nil
    }

    /// Reset the elapsed time
    public func reset() {
        logger.info("⏱️ ELAPSED_TIME_TRACKER: Resetting timer")

        stop()
        elapsedSeconds = 0
        formattedTime = "00:00"
    }

    /// Log performance milestones for diagnostics
    private func logPerformanceMilestones() {
        let seconds = Int(elapsedSeconds)
        let currentFormattedTime = self.formattedTime

        // Performance threshold logging
        switch seconds {
        case 5:
            logger.warning("⚠️ ELAPSED_TIME_TRACKER: Operation taking longer than expected (5s) - Current: \(currentFormattedTime)")
        case 10:
            logger.warning("⚠️ ELAPSED_TIME_TRACKER: Performance threshold reached (10s) - Current: \(currentFormattedTime)")
        case 30:
            logger.error("❌ ELAPSED_TIME_TRACKER: Critical performance threshold exceeded (30s) - Current: \(currentFormattedTime)")
        case 60:
            logger.error("❌ ELAPSED_TIME_TRACKER: SEVERE performance issue - Operation exceeded 1 minute: \(currentFormattedTime)")
        default:
            // Log every 15 seconds for general monitoring
            if seconds % 15 == 0 {
                logger.info("⏱️ ELAPSED_TIME_TRACKER: Operation in progress - \(currentFormattedTime)")
            }
        }
    }

  /// Format seconds to MM:SS format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    deinit {
        Task { @MainActor in
            stop()
        }
    }
}

/// SwiftUI view modifier for easily integrating elapsed time tracking
public struct ElapsedTimeTrackingModifier: ViewModifier {
    @StateObject private var tracker = ElapsedTimeTracker()
    @Binding var isTracking: Bool
    let onUpdate: ((TimeInterval, String) -> Void)?

    public func body(content: Content) -> some View {
        content
            .onReceive(tracker.$elapsedSeconds) { elapsedSeconds in
                onUpdate?(elapsedSeconds, tracker.formattedTime)
            }
            .onChange(of: isTracking) { _, newValue in
                if newValue {
                    tracker.start()
                } else {
                    tracker.stop()
                }
            }
    }
}

extension View {
    /// Adds elapsed time tracking to any view
    /// - Parameters:
    ///   - isTracking: Binding to control when tracking is active
    ///   - onUpdate: Callback called every second with elapsed time
    public func trackElapsedTime(
        isTracking: Binding<Bool>,
        onUpdate: @escaping (TimeInterval, String) -> Void
    ) -> some View {
        self.modifier(ElapsedTimeTrackingModifier(
            isTracking: isTracking,
            onUpdate: onUpdate
        ))
    }
}