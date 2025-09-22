import Foundation
import AVFoundation
import Combine
import CoreHaptics
import OSLog
import UIKit

/// Advanced frame synchronizer that provides precise frame-accurate timing
/// and haptic feedback coordination for video trimming operations
@MainActor
public final class FrameSynchronizer: ObservableObject {

    // MARK: - Frame Synchronization State
    @Published public private(set) var currentFrame: Int = 0
    @Published public private(set) var lastSyncedFrame: Int = 0
    @Published public private(set) var frameAccuracy: Double = 0.0
    @Published public private(set) var isSynchronized: Bool = false

    // MARK: - Haptic Feedback Configuration
    public enum HapticPattern {
        case light      // Subtle feedback for regular frame advancement
        case medium     // Moderate feedback for significant changes
        case heavy      // Strong feedback for boundary hits
        case pattern    // Custom rhythmic patterns for extended scrubbing
    }

    public struct HapticConfiguration {
        let pattern: HapticPattern
        let frameInterval: Int        // Trigger every N frames
        let intensity: Double         // 0.0 to 1.0
        let sharpness: Double         // 0.0 to 1.0
        let enableBoundaries: Bool    // Trigger on frame boundaries

        public static let `default` = HapticConfiguration(
            pattern: .light,
            frameInterval: 3,
            intensity: 0.7,
            sharpness: 0.8,
            enableBoundaries: true
        )

        public static let sensitive = HapticConfiguration(
            pattern: .light,
            frameInterval: 1,
            intensity: 0.5,
            sharpness: 0.6,
            enableBoundaries: true
        )

        public static let aggressive = HapticConfiguration(
            pattern: .medium,
            frameInterval: 2,
            intensity: 0.9,
            sharpness: 1.0,
            enableBoundaries: true
        )
    }

    // MARK: - Performance Monitoring
    public struct PerformanceMetrics {
        let averageSyncTime: TimeInterval
        let frameMissRate: Double
        let hapticLatency: TimeInterval
        let cpuUsage: Double
        let memoryUsage: Double
    }

    // MARK: - Private Properties
    private let frameRate: Double
    private let oneFrameDuration: CMTime
    private var hapticEngine: CHHapticEngine?
    private var syncTimer: Timer?
    private var lastHapticFrame: Int = 0
    private var lastBoundaryFrame: Int = 0

    // MARK: - Performance Tracking
    private var syncTimes: [TimeInterval] = []
    private var missedFrames: Int = 0
    private var totalFrames: Int = 0
    private var hapticTriggerTimes: [TimeInterval] = []

    // MARK: - Configuration
    private let configuration: HapticConfiguration
    private let boundaryThreshold: Int = 5  // Frames from boundary to trigger warning

    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "FrameSynchronizer")

    // MARK: - Initialization
    public init(frameRate: Double, configuration: HapticConfiguration = .default) {
        self.frameRate = frameRate
        self.oneFrameDuration = CMTime(seconds: 1.0 / frameRate, preferredTimescale: 600)
        self.configuration = configuration

        setupHapticEngine()
        startPerformanceMonitoring()

        diagnosticLogger.logInfo("⚡ FrameSynchronizer initialized", metadata: [
            "frame_rate": "\(frameRate)",
            "frame_duration_ms": "\(oneFrameDuration.seconds * 1000)",
            "haptic_pattern": "\(configuration.pattern)",
            "frame_interval": "\(configuration.frameInterval)"
        ])
    }

    deinit {
        Task { @MainActor in
            stopSynchronization()
            cleanupHapticEngine()

            diagnosticLogger.logInfo("🗑️ FrameSynchronizer deinitialized")
        }
    }

    // MARK: - Public API

    /// Synchronize to a specific time with frame accuracy
    public func synchronize(to time: CMTime) {
        let startTime = CFAbsoluteTimeGetCurrent()

        let targetFrame = calculateFrameNumber(for: time)
        let wasSynchronized = isSynchronized

        // Check if we've moved to a new frame
        guard targetFrame != currentFrame else {
            return
        }

        // Update frame state
        let previousFrame = currentFrame
        currentFrame = targetFrame
        totalFrames += 1

        // Calculate frame accuracy (how close we are to exact frame boundaries)
        let frameTime = getTimeForFrame(targetFrame)
        let timeError = abs(time.seconds - frameTime.seconds)
        frameAccuracy = max(0.0, 1.0 - (timeError / oneFrameDuration.seconds))

        // Determine if this frame should be synced
        let shouldSync = shouldSynchronizeFrame(targetFrame, previousFrame: previousFrame)

        if shouldSync {
            lastSyncedFrame = targetFrame
            isSynchronized = true

            // Trigger haptic feedback if configured
            if shouldTriggerHaptic(for: targetFrame) {
                triggerHapticFeedback(for: targetFrame)
            }

            // Check for boundary proximity
            checkBoundaryProximity(for: targetFrame)

            diagnosticLogger.logDebug("🎯 Frame synchronized", metadata: [
                "target_frame": "\(targetFrame)",
                "previous_frame": "\(previousFrame)",
                "frame_accuracy": "\(String(format: "%.3f", frameAccuracy))",
                "time_error_ms": "\(String(format: "%.3f", timeError * 1000))"
            ])
        } else {
            isSynchronized = false
            missedFrames += 1
        }

        // Track performance
        let syncTime = CFAbsoluteTimeGetCurrent() - startTime
        trackSyncPerformance(syncTime)

        // Log significant synchronization events
        if !wasSynchronized && isSynchronized {
            diagnosticLogger.logInfo("🔄 Frame synchronization established", metadata: [
                "current_frame": "\(currentFrame)",
                "sync_time_ms": "\(String(format: "%.3f", syncTime * 1000))",
                "accuracy": "\(String(format: "%.3f", frameAccuracy))"
            ])
        }
    }

    /// Start continuous frame synchronization
    public func startSynchronization() {
        guard syncTimer == nil else { return }

        diagnosticLogger.logInfo("🚀 Starting continuous frame synchronization")

        // Create high-precision timer for frame synchronization
        syncTimer = Timer.scheduledTimer(withTimeInterval: oneFrameDuration.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicSync()
            }
        }

        // Configure timer run loop for optimal performance
        syncTimer?.tolerance = oneFrameDuration.seconds * 0.1  // 10% tolerance
    }

    /// Stop continuous frame synchronization
    public func stopSynchronization() {
        guard syncTimer != nil else { return }

        diagnosticLogger.logInfo("⏹️ Stopping frame synchronization")

        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Get the exact time for the current frame
    public func getCurrentFrameTime() -> CMTime {
        return getTimeForFrame(currentFrame)
    }

    /// Get the nearest frame boundary for a given time
    public func getNearestFrameBoundary(for time: CMTime) -> CMTime {
        let frameNumber = calculateFrameNumber(for: time)
        return getTimeForFrame(frameNumber)
    }

    /// Check if a time is exactly on a frame boundary
    public func isOnFrameBoundary(_ time: CMTime) -> Bool {
        let frameTime = getNearestFrameBoundary(for: time)
        return abs(time.seconds - frameTime.seconds) < (oneFrameDuration.seconds * 0.01)  // 1% tolerance
    }

    /// Get current performance metrics
    public func getPerformanceMetrics() -> PerformanceMetrics {
        let avgSyncTime = syncTimes.isEmpty ? 0.0 : syncTimes.reduce(0, +) / Double(syncTimes.count)
        let missRate = totalFrames > 0 ? Double(missedFrames) / Double(totalFrames) : 0.0
        let avgHapticLatency = hapticTriggerTimes.isEmpty ? 0.0 : hapticTriggerTimes.reduce(0, +) / Double(hapticTriggerTimes.count)

        return PerformanceMetrics(
            averageSyncTime: avgSyncTime,
            frameMissRate: missRate,
            hapticLatency: avgHapticLatency,
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage()
        )
    }

    /// Reset synchronization state
    public func reset() {
        currentFrame = 0
        lastSyncedFrame = 0
        lastHapticFrame = 0
        lastBoundaryFrame = 0
        isSynchronized = false
        frameAccuracy = 0.0

        syncTimes.removeAll()
        missedFrames = 0
        totalFrames = 0
        hapticTriggerTimes.removeAll()

        diagnosticLogger.logInfo("🔄 FrameSynchronizer state reset")
    }

    // MARK: - Private Methods

    private func calculateFrameNumber(for time: CMTime) -> Int {
        guard oneFrameDuration.seconds > 0 else { return 0 }
        return Int(time.seconds / oneFrameDuration.seconds)
    }

    private func getTimeForFrame(_ frameNumber: Int) -> CMTime {
        return CMTime(seconds: Double(frameNumber) * oneFrameDuration.seconds, preferredTimescale: oneFrameDuration.timescale)
    }

    private func shouldSynchronizeFrame(_ targetFrame: Int, previousFrame: Int) -> Bool {
        // Always sync if we've moved at least one frame
        guard targetFrame != previousFrame else { return false }

        // Check frame interval requirement
        let framesSinceLastSync = abs(targetFrame - lastSyncedFrame)
        return framesSinceLastSync >= configuration.frameInterval
    }

    private func shouldTriggerHaptic(for frameNumber: Int) -> Bool {
        let framesSinceLastHaptic = abs(frameNumber - lastHapticFrame)
        return framesSinceLastHaptic >= configuration.frameInterval
    }

    private func triggerHapticFeedback(for frameNumber: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Determine haptic pattern based on context
            let pattern = determineHapticPattern(for: frameNumber)

            switch pattern {
            case .light:
                try triggerLightHaptic()
            case .medium:
                try triggerMediumHaptic()
            case .heavy:
                try triggerHeavyHaptic()
            case .pattern:
                try triggerPatternHaptic()
            }

            lastHapticFrame = frameNumber

            // Track haptic performance
            let hapticTime = CFAbsoluteTimeGetCurrent() - startTime
            hapticTriggerTimes.append(hapticTime)

            // Keep only recent performance data
            if hapticTriggerTimes.count > 100 {
                hapticTriggerTimes.removeFirst()
            }

            diagnosticLogger.logDebug("📳 Haptic feedback triggered", metadata: [
                "frame_number": "\(frameNumber)",
                "pattern": "\(pattern)",
                "latency_ms": "\(String(format: "%.3f", hapticTime * 1000))"
            ])

        } catch {
            diagnosticLogger.logError("Failed to trigger haptic feedback", error: error, metadata: [
                "frame_number": "\(frameNumber)"
            ])
        }
    }

    private func determineHapticPattern(for frameNumber: Int) -> HapticPattern {
        // Use boundary pattern if near frame boundaries
        if configuration.enableBoundaries && isNearBoundary(frameNumber) {
            return .heavy
        }

        // Use pattern for extended scrubbing sequences
        let recentFrameVelocity = abs(frameNumber - lastSyncedFrame)
        if recentFrameVelocity > 10 {
            return .pattern
        }

        return configuration.pattern
    }

    private func isNearBoundary(_ frameNumber: Int) -> Bool {
        return abs(frameNumber - lastBoundaryFrame) <= boundaryThreshold
    }

    private func checkBoundaryProximity(for frameNumber: Int) {
        // Check if we're approaching a significant frame boundary
        // This could be keyframes, scene changes, or trim boundaries
        if frameNumber % 30 == 0 {  // Every half second at 60fps
            lastBoundaryFrame = frameNumber

            diagnosticLogger.logDebug("🎯 Frame boundary detected", metadata: [
                "frame_number": "\(frameNumber)",
                "boundary_type": "regular"
            ])
        }
    }

    private func performPeriodicSync() {
        // Perform any periodic synchronization tasks
        // This could include drift correction or health checks

        let metrics = getPerformanceMetrics()

        // Log performance warnings if needed
        if metrics.frameMissRate > 0.1 {
            diagnosticLogger.logWarning("⚠️ High frame miss rate detected", metadata: [
                "miss_rate": "\(String(format: "%.3f", metrics.frameMissRate))",
                "missed_frames": "\(missedFrames)",
                "total_frames": "\(totalFrames)"
            ])
        }

        if metrics.averageSyncTime > oneFrameDuration.seconds * 0.5 {
            diagnosticLogger.logWarning("⚠️ High synchronization latency detected", metadata: [
                "avg_sync_time_ms": "\(String(format: "%.3f", metrics.averageSyncTime * 1000))",
                "frame_duration_ms": "\(oneFrameDuration.seconds * 1000)"
            ])
        }
    }

    // MARK: - Haptic Engine Management

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            diagnosticLogger.logWarning("⚠️ Haptic feedback not supported on this device")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()

            diagnosticLogger.logInfo("✅ Haptic engine initialized successfully")
        } catch {
            diagnosticLogger.logError("Failed to initialize haptic engine", error: error)
        }
    }

    private func cleanupHapticEngine() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    private func triggerLightHaptic() throws {
        try hapticEngine?.playPattern(from: URL(string: "")!)
        // Fallback to UIKit haptics if Core Haptics fails
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func triggerMediumHaptic() throws {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerHeavyHaptic() throws {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    private func triggerPatternHaptic() throws {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Performance Monitoring

    private func startPerformanceMonitoring() {
        // Periodic performance reporting could be added here
        diagnosticLogger.logDebug("📊 Performance monitoring started")
    }

    private func trackSyncPerformance(_ syncTime: TimeInterval) {
        syncTimes.append(syncTime)

        // Keep only recent performance data
        if syncTimes.count > 1000 {
            syncTimes.removeFirst()
        }
    }

    private func getCurrentCPUUsage() -> Double {
        // Implement CPU usage monitoring
        return 0.0  // Placeholder
    }

    private func getCurrentMemoryUsage() -> Double {
        let memoryInfo = DiagnosticLoggingHelper(category: "temp").getMemoryInfo()
        return memoryInfo.used
    }
}

// MARK: - Convenience Extensions

extension FrameSynchronizer {

    /// Create a synchronizer for video trimming operations
    public static func forVideoTrimming(frameRate: Double) -> FrameSynchronizer {
        return FrameSynchronizer(
            frameRate: frameRate,
            configuration: .sensitive
        )
    }

    /// Create a synchronizer for playback operations
    public static func forPlayback(frameRate: Double) -> FrameSynchronizer {
        return FrameSynchronizer(
            frameRate: frameRate,
            configuration: .default
        )
    }

    /// Create a synchronizer for precise editing operations
    public static func forPrecisionEditing(frameRate: Double) -> FrameSynchronizer {
        return FrameSynchronizer(
            frameRate: frameRate,
            configuration: .aggressive
        )
    }
}