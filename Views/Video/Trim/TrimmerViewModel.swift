import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - HandleType Enum
public enum TrimmerHandleType {
    case start, end
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
    public var isReady: Bool { isSetupComplete }
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "TrimmerViewModel")
    
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
            diagnosticLogger.logStateChange("rotation_quarter_turns", from: oldValue, to: rotationQuarterTurns)
            Task {
                await applyRotationToPlayerAsset()
            }
        }
    }
    @Published
    public var showMinimumDurationWarning = false
    @Published
    public var isDraggingStartHandle: Bool = false
    @Published
    public var isDraggingEndHandle: Bool = false
    
    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?
    
    // MARK: - Initialization & Deinitialization
    public init(asset: AVAsset, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, playerViewModel: any VideoPlayerViewModelProtocol) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.playerViewModel = playerViewModel
        self.rotationQuarterTurns = rotationQuarterTurns
        
        // Initialize with sensible defaults to avoid race conditions
        // These will be refined by the async setup if needed
        self.startTime = .zero
        self.endTime = CMTime(seconds: 5.0, preferredTimescale: 600) // Default 5 seconds
        self.videoDuration = CMTime(seconds: 5.0, preferredTimescale: 600) // Default 5 seconds
        self.oneFrameDuration = CMTime(value: 1, timescale: 30) // Default 30 FPS
        
        Task { @MainActor in
            diagnosticLogger.logInfo("🎬 TrimmerViewModel initialized", metadata: [
                "initial_rotation": "\(rotationQuarterTurns)",
                "photos_identifier": "\(photosIdentifier ?? "nil")",
                "video_duration_set": "\(self.videoDuration.seconds)"
            ])
        }
        
        Task {
            do {
                try await setupAsync()
            } catch {
                diagnosticLogger.logError("Initialization failed", error: error)
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            diagnosticLogger.logInfo("🗑️ TrimmerViewModel deinitialized")
        }
        // Schedule cleanup on main thread to avoid actor isolation issues
        Task { [weak self] in
            await MainActor.run {
                guard let self = self else { return }
                self.stopCoalescing()
            }
        }
    }
    
    // MARK: - Public Setup
    public func setupAsync() async throws {
        // Prevent multiple setup calls
        guard !isSetupComplete else {
            diagnosticLogger.logDebug("⚠️ Setup already completed, skipping duplicate call")
            return
        }
        
        diagnosticLogger.startTiming("trimmer_setup")
        
        let loadedDuration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30
        
        // Only update if significantly different from defaults
        if abs(loadedDuration.seconds - videoDuration.seconds) > 0.1 {
            videoDuration = loadedDuration
            endTime = loadedDuration
            diagnosticLogger.logDebug("📏 Updated video duration from asset", metadata: [
                "new_duration": "\(loadedDuration.seconds)"
            ])
        }
        
        oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // ✅ ARM the rotation logic now that the model is in a valid state.
        isSetupComplete = true
        
        diagnosticLogger.logInfo("✅ Trimmer setup completed", metadata: [
            "video_duration_seconds": "\(videoDuration.seconds)",
            "frame_rate": "\(frameRate)",
            "video_tracks": "\(videoTracks.count)",
            "one_frame_duration": "\(oneFrameDuration.seconds)"
        ])
        
        diagnosticLogger.stopTiming("trimmer_setup")
    }
    
    // MARK: - Coalescing Timer Control
    public func startCoalescing() {
        // Only log if this is actually starting a new timer
        if displayLink == nil {
            diagnosticLogger.logDebug("⏱️ Starting coalescing timer")
        }
        playerViewModel.pauseForTrimming()
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
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
    
    @objc private func tick() {
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
        let validatedTime = validate(proposedTime, for: handle)
        
        // Track state change for logging
        let oldStartTime = startTime
        let oldEndTime = endTime
        
        switch handle {
        case .start:
            if startTime != validatedTime {
                startTime = validatedTime
                // Only log significant time changes during proposal
                if abs(validatedTime.seconds - oldStartTime.seconds) > 0.1 {
                    diagnosticLogger.logStateChange("propose_start_time", from: oldStartTime.seconds, to: validatedTime.seconds)
                }
            }
        case .end:
            if endTime != validatedTime {
                endTime = validatedTime
                // Only log significant time changes during proposal
                if abs(validatedTime.seconds - oldEndTime.seconds) > 0.1 {
                    diagnosticLogger.logStateChange("propose_end_time", from: oldEndTime.seconds, to: validatedTime.seconds)
                }
            }
        }
        
        self.pendingPreviewTime = validatedTime
        
        // Show while duration <= minimum during drag
        let atOrBelowMin = (endTime - startTime) <= minimumDuration
        let wasBelowMin = showMinimumDurationWarning
        showMinimumDurationWarning = atOrBelowMin
        
        if wasBelowMin != atOrBelowMin {
            diagnosticLogger.logStateChange("minimum_duration_warning", from: wasBelowMin, to: atOrBelowMin)
        }
    }
    
    public func commitTime(_ time: CMTime, for handle: TrimmerHandleType) {
        let validatedTime = validate(time, for: handle)
        
        // Track state change for logging
        let oldStartTime = startTime
        let oldEndTime = endTime
        
        switch handle {
        case .start:
            startTime = validatedTime
            diagnosticLogger.logStateChange("commit_start_time", from: oldStartTime.seconds, to: validatedTime.seconds)
        case .end:
            endTime = validatedTime
            diagnosticLogger.logStateChange("commit_end_time", from: oldEndTime.seconds, to: validatedTime.seconds)
        }
        
        // Keep warning consistent with the final committed range
        let wasBelowMin = showMinimumDurationWarning
        showMinimumDurationWarning = (endTime - startTime) <= minimumDuration
        
        diagnosticLogger.logUserInteraction("Time committed", metadata: [
            "handle": "\(handle)",
            "committed_time": "\(validatedTime.seconds)",
            "duration_warning": "\(showMinimumDurationWarning)"
        ])
    }
    
    private func validate(_ proposedTime: CMTime, for handle: TrimmerHandleType) -> CMTime {
        var validatedTime = max(.zero, min(proposedTime, videoDuration))
        var didHitLimit = false
        
        switch handle {
        case .start:
            let limit = endTime - minimumDuration
            if validatedTime > limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
            }
        case .end:
            let limit = startTime + minimumDuration
            if validatedTime < limit {
                validatedTime = limit
                showMinimumDurationWarning = true
                didHitLimit = true
            }
        }
        
        if didHitLimit {
            diagnosticLogger.logDebug("🛑 Time validation hit limit", metadata: [
                "handle": "\(handle)",
                "proposed_time": "\(proposedTime.seconds)",
                "validated_time": "\(validatedTime.seconds)",
                "minimum_duration_seconds": "\(minimumDuration.seconds)"
            ])
        }
        
        if oneFrameDuration.seconds > 0 {
            let frameNumber = round(validatedTime.seconds / oneFrameDuration.seconds)
            validatedTime = CMTime(seconds: frameNumber * oneFrameDuration.seconds, preferredTimescale: validatedTime.timescale)
        }
        
        return validatedTime
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
    
    // MARK: - Haptic Feedback
    public func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        diagnosticLogger.logDebug("📳 Triggering haptic feedback", metadata: [
            "haptic_event": "\(event)"
        ])
        HapticManager.shared.trigger(event)
    }
    
    // MARK: - Computed Properties
    public var isValidTrim: Bool {
        return validateTrimRanges()
    }
    
    public var duration: CMTime {
        return videoDuration
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
        }
    }
}
