import SwiftUI
import AVKit
import Combine
import OSLog
import Foundation
import BreakingFlashcards // Import the module to access TimecodeFormatter

// MemoryHelper is available as a static utility - no import needed

// MARK: - HandleType Enum
public enum TrimmerHandleType {
    case start, end
}

// MARK: - Constraint Severity Enum
public enum ConstraintSeverity: String {
    case none = "none"
    case soft = "soft"
    case hard = "hard"
}

// MARK: - Validation Result Struct
public struct ValidationResult {
    public let validatedTime: CMTime
    public let didHitLimit: Bool
    public let boundaryType: String
    public let constraintSeverity: ConstraintSeverity
    public let minimumDuration: CMTime

    public var isAtBoundary: Bool {
        return didHitLimit && constraintSeverity == .hard
    }

    public var boundaryDescription: String {
        if isAtBoundary {
            return "Hit \(boundaryType) boundary at \(minimumDuration.seconds)s"
        }
        return "No constraint violation"
    }
}

// MARK: - TrimmerViewModel
@MainActor
public final class TrimmerViewModel: ObservableObject {
    // MARK: - Core Properties
    let playerViewModel: any VideoPlayerViewModelProtocol
    public let asset: AVAsset
    public let photosIdentifier: String?
    
    public var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30)
    public let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)
    
    // MARK: - Initialization State
    private var isSetupComplete = false
    @Published public var isReady: Bool = false {
        didSet {
            // 🎯 ENHANCED LOGGING: Track when isReady changes
            diagnosticLogger.logStateChange("is_ready", from: oldValue, to: isReady, metadata: [
                "setup_complete": "\(isSetupComplete)",
                "video_duration": "\(videoDuration.seconds)",
                "timestamp": "\(Date())"
            ])
        }
    }
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "TrimmerViewModel")

    // MARK: - Timecode Service Integration
    private let timecodeService = TimecodeCalculationService()

    // MARK: - Animation State Tracking
    private var animationState = TrimmerAnimationState()

    private struct TrimmerAnimationState {
        var lastStateSyncTime: Date = .distantPast
        var lastRotationTime: Date = .distantPast
        var stateSyncCount: Int = 0
        var rotationCount: Int = 0
        var averageStateSyncDuration: Double = 0
        var animationConflicts: Int = 0
        var lastMemoryUsage: Double = 0
    }
    
    // MARK: - Observable State
    @Published
    public var startTime: CMTime = .zero
    @Published
    public var endTime: CMTime = .zero
    @Published
    public var videoDuration: CMTime = .zero
    @Published
    public var isExporting: Bool = false
    @Published
    public var rotationQuarterTurns: Int = 0 {
        didSet {
            // 🛑 PREVENT running during initialization - avoid race condition
            guard isSetupComplete else { return }

            // This is no longer a simple UI rotation change.
            // It now triggers real-time asset transformation for true WYSIWYG.
            let rotationStartTime = Date()
            let timeSinceLastRotation = rotationStartTime.timeIntervalSince(animationState.lastRotationTime)
            let rotationDelta = abs(rotationQuarterTurns - oldValue)

            diagnosticLogger.logAnimation("rotation_change_start", metadata: [
                "old_rotation": "\(oldValue)",
                "new_rotation": "\(rotationQuarterTurns)",
                "rotation_delta": "\(rotationDelta)",
                "time_since_last_rotation_ms": "\(timeSinceLastRotation * 1000)",
                "rotation_count": "\(animationState.rotationCount)",
                "setup_complete": "\(isSetupComplete)",
                "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
            ])

            // Force state synchronization to ensure UI consistency
            synchronizeStateAfterExternalChange()

            Task {
                await applyRotationToPlayerAsset()

                // Log rotation completion
                let rotationDuration = Date().timeIntervalSince(rotationStartTime)
                await MainActor.run {
                    self.updateAnimationState(syncDuration: rotationDuration, type: "asset_rotation")

                    diagnosticLogger.logAnimation("rotation_change_complete", metadata: [
                        "rotation_duration_ms": "\(rotationDuration * 1000)",
                        "total_rotations": "\(animationState.rotationCount)",
                        "avg_rotation_duration_ms": "\(animationState.averageStateSyncDuration * 1000)",
                        "final_rotation": "\(rotationQuarterTurns)"
                    ])
                }
            }
        }
    }
    @Published
    public var showMinimumDurationWarning = false {
        didSet {
            // Ensure warning state changes trigger UI updates
            if oldValue != showMinimumDurationWarning {
                diagnosticLogger.logStateChange("minimum_duration_warning", from: oldValue, to: showMinimumDurationWarning)
                notifyWarningStateChange()
            }
        }
    }
    @Published
    public var isDraggingStartHandle: Bool = false
    @Published
    public var isDraggingEndHandle: Bool = false

    // MARK: - NEW: State for Minimum Duration Alert
    /// Drives the one-time alert when the 3-second boundary is first hit.
    @Published public var showMinDurationAlert: Bool = false {
        didSet {
            if oldValue != showMinDurationAlert {
                diagnosticLogger.logStateChange("minimum_duration_alert", from: oldValue, to: showMinDurationAlert, metadata: [
                    "alert_triggered_this_session": "\(hasShownAlertThisDragSession)",
                    "current_duration": "\((endTime - startTime).seconds)"
                ])
            }
        }
    }

    /// Internal state to ensure the alert only appears once per drag session.
    private var hasShownAlertThisDragSession: Bool = false
    
    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?

    // MARK: - State Synchronization
    private var stateChangeCallbacks: [(Bool) -> Void] = []
    
    // MARK: - Initialization & Deinitialization
    public init(asset: AVAsset, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, playerViewModel: any VideoPlayerViewModelProtocol) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.playerViewModel = playerViewModel
        self.rotationQuarterTurns = rotationQuarterTurns

        // 🎯 CRITICAL FIX: Initialize with zero values to avoid race conditions
        // These will be properly set by async setup, preventing incorrect duration display
        self.startTime = .zero
        self.endTime = .zero
        self.videoDuration = .zero
        self.oneFrameDuration = CMTime(value: 1, timescale: 30) // Default 30 FPS

        Task { @MainActor in
            diagnosticLogger.logInfo("🎬 TrimmerViewModel initialized", metadata: [
                "initial_rotation": "\(rotationQuarterTurns)",
                "photos_identifier": "\(photosIdentifier ?? "nil")",
                "video_duration_set": "\(self.videoDuration.seconds)",
                "setup_complete": "\(self.isSetupComplete)"
            ])
        }

        // 🎯 CRITICAL FIX: Don't start setup immediately - let the caller coordinate timing
        // This prevents race conditions during component initialization
    }
    
    deinit {
        Task { @MainActor in
            diagnosticLogger.logAnimation("trimmer_viewmodel_deinitialized", metadata: [
                "total_syncs": "\(animationState.stateSyncCount)",
                "total_rotations": "\(animationState.rotationCount)",
                "animation_conflicts": "\(animationState.animationConflicts)",
                "avg_sync_duration_ms": "\(animationState.averageStateSyncDuration * 1000)",
                "final_memory_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
            ])

            diagnosticLogger.logInfo("🗑️ TrimmerViewModel deinitialized")
        }
        // Schedule cleanup on main thread to avoid actor isolation issues
        Task { [weak self] in
            await MainActor.run {
                guard let self = self else { return }
                // 🎯 CRITICAL FIX: Call comprehensive teardown
                self.teardown()
            }
        }
    }

    // MARK: - State Synchronization Methods

    /// Registers a callback for state changes
    public func onStateChange(_ callback: @escaping (Bool) -> Void) {
        stateChangeCallbacks.append(callback)
    }

  
    /// Validates and updates minimum duration warning state
    private func validateCurrentDurationWarning() {
        let currentDuration = endTime - startTime
        let shouldBeWarning = currentDuration <= minimumDuration

        if showMinimumDurationWarning != shouldBeWarning {
            showMinimumDurationWarning = shouldBeWarning
            diagnosticLogger.logDebug("🔧 Validated and updated minimum duration warning", metadata: [
                "current_duration": "\(currentDuration.seconds)",
                "minimum_duration": "\(minimumDuration.seconds)",
                "new_warning_state": "\(shouldBeWarning)"
            ])
        }
    }

    /// Notifies external components of warning state changes
    private func notifyWarningStateChange() {
        // This method can be called by UI components to respond to warning changes
        diagnosticLogger.logDebug("📢 Notifying warning state change", metadata: [
            "warning_state": "\(showMinimumDurationWarning)"
        ])

        // Animation updates removed - SwiftUI handles updates naturally
    }

    // MARK: - External Synchronization
    /// Forces complete state validation for external synchronization
    public func forceStateValidation() {
        let validationStartTime = Date()

        diagnosticLogger.logAnimation("state_validation_start", metadata: [
            "warning_state_before": "\(showMinimumDurationWarning)",
            "current_start_before": "\(startTime.seconds)",
            "current_end_before": "\(endTime.seconds)",
            "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)",
            "validation_count": "\(animationState.stateSyncCount)"
        ])

        // Force warning validation
        validateCurrentDurationWarning()

        // Notify all callbacks of state change
        notifyWarningStateChange()

        // Time display updates removed - SwiftUI handles updates naturally

        let validationDuration = Date().timeIntervalSince(validationStartTime)

        diagnosticLogger.logAnimation("state_validation_complete", metadata: [
            "validation_duration_ms": "\(validationDuration * 1000)",
            "warning_state_after": "\(showMinimumDurationWarning)",
            "current_start_after": "\(startTime.seconds)",
            "current_end_after": "\(endTime.seconds)",
            "validation_successful": validationDuration < 0.1 ? "yes" : "slow"
        ])
    }

    /// Synchronizes state after external changes (like rotation)
    private func synchronizeStateAfterExternalChange() {
        let syncStartTime = Date()
        let timeSinceLastSync = syncStartTime.timeIntervalSince(animationState.lastStateSyncTime)
        let currentMemory = MemoryHelper.getDetailedMemoryInfo().used
        let memoryDelta = currentMemory - animationState.lastMemoryUsage

        // Log detailed synchronization context
        diagnosticLogger.logAnimation("state_synchronization_start", metadata: [
            "sync_type": "external_change",
            "time_since_last_sync_ms": "\(timeSinceLastSync * 1000)",
            "previous_sync_count": "\(animationState.stateSyncCount)",
            "current_memory_mb": "\(currentMemory)",
            "memory_delta_mb": "\(memoryDelta)",
            "animation_conflict_risk": timeSinceLastSync < 0.1 ? "high" : "normal"
        ])

        // Force complete validation cycle
        forceStateValidation()

        let syncDuration = Date().timeIntervalSince(syncStartTime)
        updateAnimationState(syncDuration: syncDuration, type: "state_synchronization")

        diagnosticLogger.logAnimation("state_synchronization_complete", metadata: [
            "sync_duration_ms": "\(syncDuration * 1000)",
            "total_syncs": "\(animationState.stateSyncCount)",
            "avg_sync_duration_ms": "\(animationState.averageStateSyncDuration * 1000)",
            "memory_after_sync_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
        ])

        // objectWillChange.send() removed - SwiftUI handles state updates naturally
    }

    // MARK: - Public Setup
    public func setupAsync() async throws {
        // Prevent multiple setup calls
        guard !isSetupComplete else {
            diagnosticLogger.logDebug("⚠️ Setup already completed, skipping duplicate call")
            return
        }

        diagnosticLogger.startTiming("trimmer_setup")

        diagnosticLogger.logInfo("🚀 Starting async setup", metadata: [
            "asset_duration_before_load": "\(asset.duration.seconds)",
            "is_ready_before": "\(isReady)",
            "setup_complete_before": "\(isSetupComplete)"
        ])

        do {
            let loadedDuration = try await asset.load(.duration)
            diagnosticLogger.logInfo("📊 Asset duration loaded successfully", metadata: [
                "loaded_duration": "\(loadedDuration.seconds)",
                "asset_timescale": "\(loadedDuration.timescale)",
                "asset_value": "\(loadedDuration.value)"
            ])

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30

            diagnosticLogger.logInfo("📊 Video tracks loaded", metadata: [
                "track_count": "\(videoTracks.count)",
                "frame_rate": "\(frameRate)"
            ])

            // 🎯 CRITICAL FIX: Update all properties atomically to prevent race conditions
            await MainActor.run {
                videoDuration = loadedDuration
                endTime = loadedDuration
                oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

                diagnosticLogger.logDebug("📏 Updated video duration from asset", metadata: [
                    "new_duration": "\(loadedDuration.seconds)",
                    "end_time_set": "\(endTime.seconds)",
                    "video_duration_set": "\(videoDuration.seconds)"
                ])
            }

            // ✅ ARM the rotation logic now that the model is in a valid state
            isSetupComplete = true
            isReady = true

            diagnosticLogger.logInfo("✅ Trimmer setup completed", metadata: [
                "video_duration_seconds": "\(videoDuration.seconds)",
                "frame_rate": "\(frameRate)",
                "video_tracks": "\(videoTracks.count)",
                "one_frame_duration": "\(oneFrameDuration.seconds)",
                "setup_complete": "\(isSetupComplete)",
                "is_ready": "\(isReady)"
            ])

            diagnosticLogger.stopTiming("trimmer_setup")

        } catch {
            diagnosticLogger.logError("❌ Trimmer setup failed during asset loading", error: error, metadata: [
                "asset_duration_before_error": "\(asset.duration.seconds)",
                "is_ready_after_error": "\(isReady)",
                "setup_complete_after_error": "\(isSetupComplete)"
            ])
            throw error
        }
    }
    
    // MARK: - Coalescing Timer Control
    public func startCoalescing() {
        // Only log if this is actually starting a new timer
        if displayLink == nil {
            diagnosticLogger.logDebug("⏱️ Starting coalescing timer")
        }
        playerViewModel.pauseForTrimming()
        guard displayLink == nil else { return }

        // 🎯 CRITICAL FIX: Use weak reference to prevent retain cycle
        let weakTarget = WeakTimerTarget(self, selector: #selector(TrimmerViewModel.tick))
        displayLink = CADisplayLink(target: weakTarget, selector: #selector(WeakTimerTarget.forwardTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stopCoalescing() {
        // Only log if we actually had an active timer
        if displayLink != nil {
            diagnosticLogger.logDebug("⏹️ Stopping coalescing timer")
        }
        displayLink?.invalidate()
        displayLink = nil
    }

    // 🎯 CRITICAL FIX: Added explicit display link cleanup
    private func cleanupDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        diagnosticLogger.logDebug("🧹 Display link cleanup completed")
    }

    // 🎯 CRITICAL FIX: Enhanced comprehensive teardown method for retain cycle prevention
    public func teardown() {
        diagnosticLogger.logInfo("🧹 Starting TrimmerViewModel teardown")

        let startTime = Date()
        let memoryBefore = MemoryHelper.getDetailedMemoryInfo()

        // Stop all async operations
        stopCoalescing()

        // Clear state change callbacks to break potential retain cycles
        cleanupStateChangeCallbacks()

        // Cleanup display link
        cleanupDisplayLink()

        // 🎯 ENHANCED: Reset all @Published properties to break potential cycles
        // Since this method is already @MainActor, we can directly assign
        self.startTime = .zero
        self.endTime = .zero
        self.videoDuration = .zero
        self.rotationQuarterTurns = 0
        self.isReady = false
        self.isExporting = false
        self.showMinimumDurationWarning = false
        self.isDraggingStartHandle = false
        self.isDraggingEndHandle = false
        self.showMinDurationAlert = false
        self.hasShownAlertThisDragSession = false

        let cleanupDuration = Date().timeIntervalSince(startTime)
        let memoryAfter = MemoryHelper.getDetailedMemoryInfo()

        diagnosticLogger.logInfo("✅ TrimmerViewModel teardown completed", metadata: [
            "cleanup_duration_ms": "\(cleanupDuration * 1000)",
            "memory_before_mb": "\(memoryBefore.used)",
            "memory_after_mb": "\(memoryAfter.used)",
            "memory_freed_mb": "\(memoryBefore.used - memoryAfter.used)",
            "teardown_comprehensive": "true"
        ])
    }

    // 🎯 CRITICAL FIX: Added state change callback cleanup
    private func cleanupStateChangeCallbacks() {
        stateChangeCallbacks.removeAll()
        diagnosticLogger.logDebug("🧹 State change callbacks cleared")
    }
    
    @objc func tick() {
        guard let time = pendingPreviewTime else { return }
        pendingPreviewTime = nil
        // Reduce verbosity - only log significant time jumps
        if abs(time.seconds - (playerViewModel.currentTime?.seconds ?? 0)) > 0.5 {
            diagnosticLogger.logDebug("⏰ Coalescing tick - seeking to pending time", metadata: [
                "target_time_seconds": "\(time.seconds)"
            ])
        }
        playerViewModel.seek(to: time)
    }
    
    // MARK: - Time Proposal and Committing
    public func proposeTime(_ proposedTime: CMTime, for handle: TrimmerHandleType) {
        let snappedTime = snapToFrame(proposedTime)

        // Use the enhanced validation method that returns state information.
        let validation = validateWithHandleState(snappedTime, for: handle)
        let validatedTime = validation.validatedTime

        // Track state change for logging
        let oldStartTime = startTime
        let oldEndTime = endTime
        let newStartTime = handle == .start ? validatedTime : startTime
        let newEndTime = handle == .end ? validatedTime : endTime
        let oldDuration = endTime - startTime
        let newDuration = newEndTime - newStartTime

        // Enhanced logging for duration calculations
        let durationDelta = abs(newDuration.seconds - oldDuration.seconds)
        let frameNumber = getFrameNumber(for: validatedTime)
        let frameDelta = abs(frameNumber - getFrameNumber(for: handle == .start ? startTime : endTime))

        switch handle {
        case .start:
            if startTime != validatedTime {
                startTime = validatedTime
                // Enhanced logging with duration impact
                diagnosticLogger.logDebug("🎯 Start time proposal processed", metadata: [
                    "old_time": "\(oldStartTime.seconds)",
                    "new_time": "\(validatedTime.seconds)",
                    "old_formatted": "\(TimecodeFormatter.format(time: oldStartTime))",
                    "new_formatted": "\(TimecodeFormatter.format(time: validatedTime))",
                    "old_duration": "\(oldDuration.seconds)",
                    "new_duration": "\(newDuration.seconds)",
                    "duration_delta": "\(durationDelta)",
                    "frame_number": "\(frameNumber)",
                    "frame_delta": "\(frameDelta)",
                    "validation_result": "\(validatedTime == proposedTime ? "accepted" : "constrained")",
                    "handle_dragging": "\(isDraggingStartHandle)",
                    "hit_boundary": "\(validation.didHitLimit)",
                    "boundary_type": "\(validation.boundaryType)"
                ])
            }
        case .end:
            if endTime != validatedTime {
                endTime = validatedTime
                // Enhanced logging with duration impact
                diagnosticLogger.logDebug("🎯 End time proposal processed", metadata: [
                    "old_time": "\(oldEndTime.seconds)",
                    "new_time": "\(validatedTime.seconds)",
                    "old_formatted": "\(TimecodeFormatter.format(time: oldEndTime))",
                    "new_formatted": "\(TimecodeFormatter.format(time: validatedTime))",
                    "old_duration": "\(oldDuration.seconds)",
                    "new_duration": "\(newDuration.seconds)",
                    "duration_delta": "\(durationDelta)",
                    "frame_number": "\(frameNumber)",
                    "frame_delta": "\(frameDelta)",
                    "validation_result": "\(validatedTime == proposedTime ? "accepted" : "constrained")",
                    "handle_dragging": "\(isDraggingEndHandle)",
                    "hit_boundary": "\(validation.didHitLimit)",
                    "boundary_type": "\(validation.boundaryType)"
                ])
            }
        }

        self.pendingPreviewTime = validatedTime

        // Trigger frame-synchronized haptic feedback
        triggerFrameSynchronizedHaptic(at: validatedTime)

        // Update the persistent warning banner state. It should be visible
        // whenever the duration is less than or equal to the minimum.
        let currentDuration = self.endTime - self.startTime
        let shouldShowWarning = currentDuration.seconds <= minimumDuration.seconds

        if showMinimumDurationWarning != shouldShowWarning {
            showMinimumDurationWarning = shouldShowWarning
            diagnosticLogger.logDebug("⚠️ Duration warning state updated", metadata: [
                "current_duration": "\(currentDuration.seconds)",
                "current_formatted": "\(TimecodeFormatter.format(time: currentDuration))",
                "minimum_threshold": "\(minimumDuration.seconds)",
                "minimum_formatted": "\(TimecodeFormatter.format(time: minimumDuration))",
                "showing_warning": "\(shouldShowWarning)",
                "duration_ratio": "\(String(format: "%.2f", currentDuration.seconds / minimumDuration.seconds))",
                "handle": "\(handle)"
            ])
        }

        // MARK: - NEW: Alert Trigger Logic
        // If the handle hit the hard boundary AND we haven't shown the alert during this drag...
        if validation.didHitLimit && validation.constraintSeverity == .hard && !hasShownAlertThisDragSession {
            // ...trigger the alert and set the flag so it doesn't show again.
            showMinDurationAlert = true
            hasShownAlertThisDragSession = true
            triggerBoundaryHaptic() // Provide a strong haptic bump at the boundary.

            diagnosticLogger.logDebug("🚨 Minimum duration boundary hit - triggering alert", metadata: [
                "current_duration": "\(currentDuration.seconds)",
                "minimum_duration": "\(minimumDuration.seconds)",
                "handle": "\(handle)",
                "boundary_type": "\(validation.boundaryType)",
                "first_hit_this_session": "\(hasShownAlertThisDragSession)"
            ])
        }

        // If the user drags away from the boundary, reset the alert flag for the next drag session.
        if !showMinimumDurationWarning {
            hasShownAlertThisDragSession = false
            diagnosticLogger.logDebug("🔄 Alert flag reset - user moved away from boundary", metadata: [
                "current_duration": "\(currentDuration.seconds)",
                "minimum_duration": "\(minimumDuration.seconds)"
            ])
        }
    }
    
    public func commitTime(_ time: CMTime, for handle: TrimmerHandleType) {
        let snappedTime = snapToFrame(time)
        let validatedTime = validate(snappedTime, for: handle)

        // Track state change for logging
        let oldStartTime = startTime
        let oldEndTime = endTime
        let newStartTime = handle == .start ? validatedTime : startTime
        let newEndTime = handle == .end ? validatedTime : endTime
        let oldDuration = endTime - startTime
        let newDuration = newEndTime - newStartTime
        let durationDelta = abs(newDuration.seconds - oldDuration.seconds)

        switch handle {
        case .start:
            startTime = validatedTime
            diagnosticLogger.logDebug("🎯 Start time committed", metadata: [
                "committed_time": "\(validatedTime.seconds)",
                "formatted_time": "\(TimecodeFormatter.format(time: validatedTime))",
                "previous_time": "\(oldStartTime.seconds)",
                "previous_formatted": "\(TimecodeFormatter.format(time: oldStartTime))",
                "old_duration": "\(oldDuration.seconds)",
                "new_duration": "\(newDuration.seconds)",
                "duration_delta": "\(durationDelta)",
                "committed_frame": "\(getFrameNumber(for: validatedTime))",
                "validation_result": "\(validatedTime == time ? "accepted" : "constrained")",
                "handle_was_dragging": "\(isDraggingStartHandle)"
            ])
        case .end:
            endTime = validatedTime
            diagnosticLogger.logDebug("🎯 End time committed", metadata: [
                "committed_time": "\(validatedTime.seconds)",
                "formatted_time": "\(TimecodeFormatter.format(time: validatedTime))",
                "previous_time": "\(oldEndTime.seconds)",
                "previous_formatted": "\(TimecodeFormatter.format(time: oldEndTime))",
                "old_duration": "\(oldDuration.seconds)",
                "new_duration": "\(newDuration.seconds)",
                "duration_delta": "\(durationDelta)",
                "committed_frame": "\(getFrameNumber(for: validatedTime))",
                "validation_result": "\(validatedTime == time ? "accepted" : "constrained")",
                "handle_was_dragging": "\(isDraggingEndHandle)"
            ])
        }

        // Keep warning consistent with the final committed range
        let wasBelowMin = showMinimumDurationWarning
        let shouldBeWarning = (endTime - startTime) <= minimumDuration
        let finalDuration = endTime - startTime
        let durationRatio = finalDuration.seconds / minimumDuration.seconds

        // Always update warning state to ensure consistency
        if wasBelowMin != shouldBeWarning {
            showMinimumDurationWarning = shouldBeWarning
            diagnosticLogger.logDebug("⚠️ Duration warning state updated after commit", metadata: [
                "final_duration": "\(finalDuration.seconds)",
                "final_formatted": "\(TimecodeFormatter.format(time: finalDuration))",
                "minimum_duration": "\(minimumDuration.seconds)",
                "minimum_formatted": "\(TimecodeFormatter.format(time: minimumDuration))",
                "duration_ratio": "\(String(format: "%.2f", durationRatio))",
                "was_below_min": "\(wasBelowMin)",
                "now_below_min": "\(shouldBeWarning)",
                "breach_amount": "\(max(0, minimumDuration.seconds - finalDuration.seconds))",
                "safety_margin": "\(shouldBeWarning ? "none" : "\(finalDuration.seconds - minimumDuration.seconds)s")"
            ])
        }

        // Force validation after commit to ensure state consistency
        validateCurrentDurationWarning()

        // 🎯 NEW: Trigger external synchronization for robust state management
        // This ensures normal trim operations have the same synchronization as rotation
        Task {
            await MainActor.run {
                synchronizeStateAfterExternalChange()
            }
        }

        // Final animation update removed - SwiftUI handles updates naturally

        // MARK: - NEW: Reset Alert State on Drag End
        // Reset the alert flag so it's ready for the next interaction.
        hasShownAlertThisDragSession = false

        // Trigger completion haptic
        triggerHapticFeedback(for: .dragEnd)

        diagnosticLogger.logUserInteraction("Time commit completed", metadata: [
            "handle": "\(handle)",
            "committed_time": "\(validatedTime.seconds)",
            "formatted_time": "\(TimecodeFormatter.format(time: validatedTime))",
            "committed_frame": "\(getFrameNumber(for: validatedTime))",
            "final_duration": "\(finalDuration.seconds)",
            "final_formatted": "\(TimecodeFormatter.format(time: finalDuration))",
            "duration_warning": "\(showMinimumDurationWarning)",
            "trim_frame_count": "\(currentTrimFrameCount)",
            "validation_success": "\(validateTrimRanges())",
            "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
        ])
    }
    
    private func validate(_ proposedTime: CMTime, for handle: TrimmerHandleType) -> CMTime {
        var validatedTime = max(.zero, min(proposedTime, videoDuration))
        var didHitLimit = false
        var boundaryType = ""

        switch handle {
        case .start:
            let limit = endTime - minimumDuration
            if validatedTime > limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
                boundaryType = "minimum_duration"
            }
        case .end:
            let limit = startTime + minimumDuration
            if validatedTime < limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
                boundaryType = "minimum_duration"
            }
        }

        if didHitLimit {
            diagnosticLogger.logDebug("🛑 Time validation hit limit", metadata: [
                "handle": "\(handle)",
                "proposed_time": "\(proposedTime.seconds)",
                "validated_time": "\(validatedTime.seconds)",
                "minimum_duration_seconds": "\(minimumDuration.seconds)",
                "boundary_type": "\(boundaryType)"
            ])
        }

        // Apply frame snapping only if not at boundary for smoother constraint experience
        if oneFrameDuration.seconds > 0 && !didHitLimit {
            // 🎯 ENHANCED: Use TimecodeCalculationService for frame-accurate snapping
            validatedTime = timecodeService.snapToFrame(time: validatedTime, frameRate: currentFrameRate)
        }

        return validatedTime
    }

    // Enhanced validation with handle state awareness
    private func validateWithHandleState(_ proposedTime: CMTime, for handle: TrimmerHandleType) -> ValidationResult {
        var validatedTime = max(.zero, min(proposedTime, videoDuration))
        var didHitLimit = false
        var boundaryType = ""
        var constraintSeverity = ConstraintSeverity.none

        switch handle {
        case .start:
            let limit = endTime - minimumDuration
            if validatedTime > limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
                boundaryType = "minimum_duration"
                constraintSeverity = .hard
            }
        case .end:
            let limit = startTime + minimumDuration
            if validatedTime < limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
                boundaryType = "minimum_duration"
                constraintSeverity = .hard
            }
        }

        if didHitLimit {
            diagnosticLogger.logDebug("🛑 Enhanced validation hit limit", metadata: [
                "handle": "\(handle)",
                "proposed_time": "\(proposedTime.seconds)",
                "validated_time": "\(validatedTime.seconds)",
                "minimum_duration_seconds": "\(minimumDuration.seconds)",
                "boundary_type": "\(boundaryType)",
                "constraint_severity": "\(constraintSeverity)"
            ])
        }

        // Apply frame snapping only if not at boundary
        if oneFrameDuration.seconds > 0 && !didHitLimit {
            // 🎯 ENHANCED: Use TimecodeCalculationService for frame-accurate snapping
            validatedTime = timecodeService.snapToFrame(time: validatedTime, frameRate: currentFrameRate)
        }

        return ValidationResult(
            validatedTime: validatedTime,
            didHitLimit: didHitLimit,
            boundaryType: boundaryType,
            constraintSeverity: constraintSeverity,
            minimumDuration: minimumDuration
        )
    }
    
    // MARK: - Validation Methods
    public func validateTrimRanges() -> Bool {
        let isValid = startTime >= .zero && endTime <= videoDuration && startTime < endTime

        diagnosticLogger.logDebug("🔍 Validating trim ranges", metadata: [
            "is_valid": "\(isValid)",
            "start_time_seconds": "\(startTime.seconds)",
            "end_time_seconds": "\(endTime.seconds)",
            "video_duration_seconds": "\(videoDuration.seconds)",
            "start_before_end": "\(startTime < endTime)"
        ])

        return isValid
    }

      
    // MARK: - Real-time Asset Transformation
    private func applyRotationToPlayerAsset() async {
        diagnosticLogger.startTiming("asset_rotation")
        
        diagnosticLogger.logInfo("🔄 Applying asset-level rotation: \(self.rotationQuarterTurns * 90)°")
        
        // 🛡️ DEFENSIVE GUARD: Ensure the time range is valid before processing.
        guard (self.endTime - self.startTime).seconds > 0 else {
            diagnosticLogger.logWarning("Skipping asset rotation due to invalid (zero-duration) time range")
            return
        }
        
        do {
            // Use the VideoTransformBuilder to create a new player item with the current trim
            // and the NEW rotation. This implements true WYSIWYG.
            let transformedItem = try await VideoTransformBuilder.createPlayerItem(
                asset: self.asset,
                trimRange: CMTimeRange(start: self.startTime, end: self.endTime),
                quarterTurns: self.rotationQuarterTurns
            )
            
            // Hot-swap the player's content. This is a powerful feature of AVFoundation.
            guard let unifiedPlayer = self.playerViewModel as? UnifiedVideoPlayerViewModel else {
                diagnosticLogger.logError("PlayerViewModel is not UnifiedVideoPlayerViewModel")
                return
            }
            
            try await unifiedPlayer.replacePlayerItemAndWaitForReady(transformedItem)
            
            diagnosticLogger.logInfo("✅ Asset rotation applied successfully")
            diagnosticLogger.stopTiming("asset_rotation")
        } catch {
            diagnosticLogger.logError("Failed to apply asset rotation", error: error)
            // Optionally, revert rotationQuarterTurns or show a user-facing error.
            // For now, we'll log the error and continue with the previous state.
        }
    }
    
    // MARK: - Export Methods (needed by TrimmerView)
    public func exportVideo() async throws -> URL {
        diagnosticLogger.startTiming("video_export")
        diagnosticLogger.logInfo("📤 Starting video export")
        
        guard validateTrimRanges() else {
            diagnosticLogger.logError("Invalid trim ranges for export")
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid trim ranges"])
        }
        
        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        // Create trim range
        let timeRange = CMTimeRange(start: startTime, duration: endTime - startTime)
        
        diagnosticLogger.logInfo("📤 Export parameters set", metadata: [
            "start_time_seconds": "\(startTime.seconds)",
            "end_time_seconds": "\(endTime.seconds)",
            "duration_seconds": "\(timeRange.duration.seconds)",
            "rotation": "\(rotationQuarterTurns)"
        ])
        
        let exportedURL = try await VideoTransformBuilder.exportVideo(
            asset: asset,
            trimRange: timeRange,
            quarterTurns: rotationQuarterTurns,
            outputURL: outputURL
        )
        
        diagnosticLogger.logInfo("✅ Video export completed successfully")
        diagnosticLogger.stopTiming("video_export")
        return exportedURL
    }
    
    // MARK: - Preview Updates
    public func updatePreview() async {
        diagnosticLogger.logInfo("👁️ Updating preview", metadata: [
            "seek_time_seconds": "\(startTime.seconds)",
            "player_state": "\(playerViewModel.isPlayerReady)"
        ])
        // Update the live preview by seeking to current start time
        requestSeek(to: startTime)
    }
    
    public func requestSeek(to time: CMTime) {
        diagnosticLogger.logDebug("⏩ Seeking to time", metadata: [
            "target_time_seconds": "\(time.seconds)"
        ])
        playerViewModel.seek(to: time)
    }
    
    // MARK: - Frame-Accurate Timing Methods
    public func getFrameNumber(for time: CMTime) -> Int {
        // 🎯 ENHANCED: Use TimecodeCalculationService for frame-accurate calculations
        let timecodeResult = timecodeService.calculateTimecode(
            startTime: time,
            endTime: time,
            assetDuration: videoDuration,
            frameRate: currentFrameRate
        )

        diagnosticLogger.logDebug("🧮 Frame number calculation completed", metadata: [
            "input_time": "\(time.seconds)",
            "calculated_frame": "\(timecodeResult.startFrame)",
            "frame_rate": "\(currentFrameRate)",
            "is_valid": "\(timecodeResult.isValid)",
            "calculation_source": "TimecodeCalculationService"
        ])

        return timecodeResult.startFrame
    }

    public func getTimeForFrame(_ frameNumber: Int) -> CMTime {
        // 🎯 ENHANCED: Use TimecodeCalculationService for precise frame-to-time conversion
        let frameTime = CMTime(seconds: Double(frameNumber) / currentFrameRate, preferredTimescale: 600)
        return timecodeService.snapToFrame(time: frameTime, frameRate: currentFrameRate)
    }

    public func snapToFrame(_ time: CMTime) -> CMTime {
        // 🎯 ENHANCED: Use TimecodeCalculationService for frame-accurate snapping
        let snappedTime = timecodeService.snapToFrame(time: time, frameRate: currentFrameRate)

        diagnosticLogger.logDebug("🎯 Frame snapping completed", metadata: [
            "input_time": "\(time.seconds)",
            "snapped_time": "\(snappedTime.seconds)",
            "time_delta": "\(abs(snappedTime.seconds - time.seconds))",
            "frame_rate": "\(currentFrameRate)",
            "snapping_source": "TimecodeCalculationService"
        ])

        return snappedTime
    }

    public func getFrameRate() -> Double {
        return 1.0 / oneFrameDuration.seconds
    }

    // MARK: - Time Formatting Utilities
    // formatTimeWithMs function removed - use TimecodeFormatter.format(time:) instead

    // MARK: - Simplified Animation Properties (Removed - SwiftUI handles updates naturally)

    // MARK: - Enhanced Haptic Feedback
    public func triggerFrameSynchronizedHaptic(at time: CMTime) {
        // Simplified haptic feedback - trigger based on time changes
        triggerHapticFeedback(for: .frameDetent)
    }

    public func triggerBoundaryHaptic() {
        // Provide a distinctive haptic feedback for boundary hits
        diagnosticLogger.logDebug("🛑 Triggering boundary haptic feedback", metadata: [
            "boundary_type": "minimum_duration",
            "current_duration": "\((endTime - startTime).seconds)",
            "minimum_duration": "\(minimumDuration.seconds)"
        ])

        // 🎯 CRITICAL FIX: Resilient haptic error handling to prevent system-level errors
        do {
            HapticManager.shared.trigger(.heavyImpact)
        } catch {
            diagnosticLogger.logWarning("Haptic feedback failed for boundary", metadata: [
                "error": error.localizedDescription,
                "haptic_event": "heavyImpact"
            ])
        }
    }

    // MARK: - Haptic Feedback
    public func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        diagnosticLogger.logDebug("📳 Triggering haptic feedback", metadata: [
            "haptic_event": "\(event)"
        ])

        // 🎯 CRITICAL FIX: Resilient haptic error handling to prevent system-level errors
        do {
            HapticManager.shared.trigger(event)
        } catch {
            diagnosticLogger.logWarning("Haptic feedback failed", metadata: [
                "error": error.localizedDescription,
                "haptic_event": "\(event)"
            ])
        }
    }

    // MARK: - Animation State Management
    private func updateAnimationState(syncDuration: Double, type: String) {
        let now = Date()
        let timeSinceLastSync = now.timeIntervalSince(animationState.lastStateSyncTime)
        let currentMemory = MemoryHelper.getDetailedMemoryInfo().used
        let memoryDelta = currentMemory - animationState.lastMemoryUsage

        // Detect potential animation conflicts
        if timeSinceLastSync < 0.05 && animationState.stateSyncCount > 0 {
            animationState.animationConflicts += 1
            diagnosticLogger.logAnimationWarning("trimmer_animation_conflict", metadata: [
                "time_since_last_sync_ms": "\(timeSinceLastSync * 1000)",
                "sync_type": "\(type)",
                "sync_duration_ms": "\(syncDuration * 1000)",
                "total_conflicts": "\(animationState.animationConflicts)",
                "conflict_rate": "\(Double(animationState.animationConflicts) / Double(max(1, animationState.stateSyncCount)))",
                "memory_delta_mb": "\(memoryDelta)",
                "current_sync_count": "\(animationState.stateSyncCount)"
            ])
        }

        // Update state tracking
        animationState.lastStateSyncTime = now
        animationState.stateSyncCount += 1
        animationState.lastMemoryUsage = currentMemory

        // Calculate rolling average for sync duration
        animationState.averageStateSyncDuration =
            (animationState.averageStateSyncDuration * Double(animationState.stateSyncCount - 1) + syncDuration) / Double(animationState.stateSyncCount)

        // Update rotation-specific tracking
        if type.contains("rotation") {
            animationState.lastRotationTime = now
            animationState.rotationCount += 1
        }

        // Periodic performance logging
        if animationState.stateSyncCount % 5 == 0 {
            diagnosticLogger.logAnimationPerformance("trimmer_periodic_stats", metadata: [
                "total_syncs": "\(animationState.stateSyncCount)",
                "total_rotations": "\(animationState.rotationCount)",
                "avg_sync_duration_ms": "\(animationState.averageStateSyncDuration * 1000)",
                "conflict_count": "\(animationState.animationConflicts)",
                "conflict_rate": "\(Double(animationState.animationConflicts) / Double(max(1, animationState.stateSyncCount)))",
                "current_memory_mb": "\(currentMemory)",
                "memory_delta_from_baseline_mb": "\(memoryDelta)"
            ])
        }
    }

    // MARK: - Animation Diagnostics
    public func getAnimationDiagnostics() -> [String: String] {
        return [
            "total_syncs": "\(animationState.stateSyncCount)",
            "total_rotations": "\(animationState.rotationCount)",
            "animation_conflicts": "\(animationState.animationConflicts)",
            "avg_sync_duration_ms": "\(animationState.averageStateSyncDuration * 1000)",
            "last_sync_duration_ms": "\(animationState.lastStateSyncTime.timeIntervalSinceNow.magnitude * 1000)",
            "current_memory_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)",
            "conflict_rate": "\(Double(animationState.animationConflicts) / Double(max(1, animationState.stateSyncCount)))"
        ]
    }

    // MARK: - Computed Properties
    public var isValidTrim: Bool {
        return validateTrimRanges()
    }

    public var duration: CMTime {
        return videoDuration
    }

    public var currentFrameRate: Double {
        return getFrameRate()
    }

    public var totalFrames: Int {
        return getFrameNumber(for: videoDuration)
    }

    public var currentTrimFrameCount: Int {
        return getFrameNumber(for: endTime - startTime)
    }
}


// MARK: - Haptic Feedback Manager (Helper)
public final class HapticManager {
    public static let shared = HapticManager()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    public enum HapticEvent {
        case dragStart
        case dragEnd
        case frameDetent
        case heavyImpact
    }
    
    private init() {
        selectionFeedback.prepare()
    }
    
    public func trigger(_ event: HapticEvent) {
        switch event {
        case .dragStart, .dragEnd:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .frameDetent:
            selectionFeedback.selectionChanged()
        case .heavyImpact:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// MARK: - Weak Timer Target (Memory Leak Fix)
// 🎯 CRITICAL FIX: Weak reference wrapper to prevent CADisplayLink retain cycles
fileprivate class WeakTimerTarget: NSObject {
    private weak var target: TrimmerViewModel?
    private let selector: Selector

    init(_ target: TrimmerViewModel, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
    }

    @objc func forwardTick() {
        Task { @MainActor in
            target?.tick()
        }
    }
}
