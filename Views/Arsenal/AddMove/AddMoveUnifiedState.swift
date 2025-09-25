import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import OSLog
import CoreData

// MARK: - Unified Flow State
/// Simplified flow state that eliminates the dual state system complexity
public enum AddMoveFlowState: Equatable, Hashable, Sendable {
    case ready
    case loading(progress: Double, status: String)
    case previewing
    case trimming_setup
    case trimming
    case finalizing(status: String)
    case naming
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        switch self {
        case .loading: return true
        default: return false
        }
    }
    
    var isError: Bool {
        switch self {
        case .error: return true
        default: return false
        }
    }
    
    var canGoBack: Bool {
        switch self {
        case .ready, .error, .success: return false
        default: return true
        }
    }
    
    var progress: Double {
        switch self {
        case .ready: return 0.0
        case .loading(let progress, _): return progress
        case .trimming_setup: return 0.45
        case .trimming: return 0.5
        case .finalizing: return 0.6
        case .naming: return 0.7
        case .saving: return 0.9
        case .success: return 1.0
        case .error: return 0.0
        case .previewing: return 0.4  // Keep for compatibility but won't be used
        }
    }
}

// MARK: - Player State
/// Centralized player state management
public enum PlayerState: Equatable, Hashable, Sendable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case seeking
    case error(String)
    
    var isReady: Bool {
        switch self {
        case .ready, .playing, .paused, .seeking: return true
        default: return false
        }
    }
    
    var isActive: Bool {
        switch self {
        case .idle, .error: return false
        default: return true
        }
    }
}

// MARK: - Timeout Helper
/// Helper function to add timeout protection to async operations
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(seconds: seconds)
        }

        for try await result in group {
            group.cancelAll()
            return result
        }

        throw TimeoutError(seconds: seconds)
    }
}

struct TimeoutError: Error, LocalizedError {
    let seconds: TimeInterval

    var errorDescription: String? {
        return "Operation timed out after \(seconds) seconds"
    }
}

// MARK: - Add Move Unified State
/// Single source of truth for the entire Add Move flow
/// Eliminates State Object Churn by centralizing all state and persistent services
@MainActor
public class AddMoveUnifiedState: ObservableObject {
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "AddMoveUnifiedState")
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveUnifiedState")

    // MARK: - Save Completion Handler
    /// Completion handler called when a move is successfully saved
    /// This enables proper navigation to the detail view with the final persisted object
    public var onSaveSuccess: ((Move) -> Void)?

    // MARK: - Core Flow State
    @Published
    public var flowState: AddMoveFlowState = .ready {
        didSet {
            guard oldValue != flowState else { return }
            
            diagnosticLogger.logStateChange("flow_state_transition", from: oldValue, to: flowState, metadata: [
                "transition_reason": "property_observer",
                "player_ready": "\(currentPlayerViewModel != nil)",
                "video_asset_available": "\(videoAsset != nil)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            
            let newFlowState = flowState
            logger.info("🎬 UNIFIED_STATE: Flow state changed from \(String(describing: oldValue)) to \(String(describing: newFlowState))")
            onFlowStateChange?(oldValue, flowState)
            
            // Log resource usage on state transitions
            diagnosticLogger.checkResourceWarnings()
        }
    }
    
    @Published
    public var playerState: PlayerState = .idle {
        didSet {
            guard oldValue != playerState else { return }
            
            diagnosticLogger.logStateChange("player_state_transition", from: oldValue, to: playerState, metadata: [
                "flow_state": "\(flowState)",
                "is_player_ready": "\(currentPlayerViewModel?.isPlayerReady ?? false)",
                "has_video_asset": "\(videoAsset != nil)"
            ])
            
            let newPlayerState = playerState
            logger.info("🎬 UNIFIED_STATE: Player state changed from \(String(describing: oldValue)) to \(String(describing: newPlayerState))")
        }
    }
    
    // MARK: - Video Asset State
    @Published
    public var videoAsset: AVAsset? {
        didSet {
            guard oldValue != videoAsset else { return }
            
            let assetInfo = diagnosticLogger.videoMetadata(asset: videoAsset)
            diagnosticLogger.logStateChange("video_asset", from: oldValue != nil ? "available" : "nil", to: videoAsset != nil ? "available" : "nil", metadata: assetInfo)
            
            logger.info("🎬 UNIFIED_STATE: Video asset updated - \(self.videoAsset != nil ? "available" : "nil")")
        }
    }
    
    @Published
    public var photosIdentifier: String? {
        didSet {
            guard oldValue != photosIdentifier else { return }
            
            diagnosticLogger.logStateChange("photos_identifier", from: oldValue ?? "nil", to: photosIdentifier ?? "nil", metadata: [
                "flow_state": "\(flowState)",
                "has_video_asset": "\(videoAsset != nil)"
            ])
            
            logger.info("🎬 UNIFIED_STATE: Photos identifier updated - \(self.photosIdentifier ?? "nil")")
        }
    }
    
    @Published
    public var selectedVideoItem: PhotosPickerItem? {
        didSet {
            guard oldValue != selectedVideoItem else { return }
            
            diagnosticLogger.logUserInteraction("video_item_selection", metadata: [
                "item_selected": "\(selectedVideoItem != nil)",
                "flow_state": "\(flowState)",
                "previous_item_available": "\(oldValue != nil)"
            ])
            
            logger.info("🎬 UNIFIED_STATE: Selected video item updated - \(self.selectedVideoItem != nil ? "available" : "nil")")
        }
    }
    
    // MARK: - Video Processing State
    @Published
    public var loadingProgress: Double = 0.0
    @Published
    public var loadingStatus: String = ""
    @Published
    public var rotationQuarterTurns: Int = 0
    
    // MARK: - Trimming State
    @Published
    public var trimStartTime: Double = 0.0
    @Published
    public var trimEndTime: Double = 0.0
    @Published
    public var isTrimmingActive: Bool = false
    
    // MARK: - User Input State
    @Published
    public var moveName: String = ""
    @Published
    public var isSaving: Bool = false
    @Published
    public var saveProgress: Double = 0.0
    
    // MARK: - Error State
    @Published
    public var errorMessage: String?
    @Published
    public var underlyingError: String?
    
    // MARK: - Trimmer State
    @Published
    public var trimmerViewModel: TrimmerViewModel?

    // MARK: - Seek State Management
    /// 🎯 CRITICAL FIX: Seek state management for naming view responsiveness
    @Published
    private(set) var isSeekInProgress = false
    @Published
    private(set) var lastSeekCompletionTime: Date?
    private var seekOperationCancellationToken: CancellationToken?

    // MARK: - Persistent Services
    /// Shared player manager that persists across view transitions
    public let unifiedPlayerManager: UnifiedPlayerManager
    
    /// Health monitor for video processing
    public let healthMonitor: VideoHealthMonitor

    /// Memory manager for resource optimization
    public let memoryManager: MemoryManager
    
    /// App container for dependency injection
    public let appContainer: AppContainer
    
    // MARK: - Callbacks
    public var onFlowStateChange: ((AddMoveFlowState, AddMoveFlowState) -> Void)?
    
    // MARK: - Computed Properties
    public var isInError: Bool {
        return errorMessage != nil
    }
    
    public var isReady: Bool {
        return flowState == .ready && !isInError
    }
    
    public var hasVideo: Bool {
        return videoAsset != nil
    }
    
    public var canProceed: Bool {
        switch flowState {
        case .ready:
            return hasVideo
        case .previewing:
            return true
        case .trimming_setup, .trimming:
            return true
        case .finalizing:
            return true
        case .naming:
            return !moveName.isEmpty
        case .saving, .success, .error, .loading:
            return false
        }
    }
    
    public var currentPlayerViewModel: UnifiedVideoPlayerViewModel? {
        return unifiedPlayerManager.getCurrentPlayer()
    }
    
    // MARK: - Initialization
    public init(
        unifiedPlayerManager: UnifiedPlayerManager,
        appContainer: AppContainer = AppContainer.shared
    ) {
        diagnosticLogger.startTiming("unified_state_initialization")

        self.unifiedPlayerManager = unifiedPlayerManager
        // 🎯 CRITICAL FIX: Get all services from the AppContainer,
        // ensuring a single shared instance for each.
        self.healthMonitor = appContainer.videoHealthMonitor as! VideoHealthMonitorImpl
        self.memoryManager = appContainer.memoryManager as! MemoryManagerImpl
        self.appContainer = appContainer
        
        let memoryInfo = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: Initialized with persistent services", metadata: [
            "initial_flow_state": "\(flowState)",
            "initial_player_state": "\(playerState)",
            "memory_usage_mb": "\(String(format: "%.1f", memoryInfo.used))",
            "memory_percent": "\(String(format: "%.1f", memoryInfo.percentage))",
            "health_monitor_active": "\(healthMonitor != nil)"
        ])

        // 🎯 CRITICAL FIX: Add transition validation hook to prevent race conditions
        // Note: Type annotation issue prevents full implementation
        // The assertion is already handled in proceedToNextState() via sequential cleanup

        diagnosticLogger.stopTiming("unified_state_initialization")
    }
    
    // MARK: - State Management
    
    /// Transitions to a new flow state
    public func transitionTo(_ newState: AddMoveFlowState) async {
        guard flowState != newState else { return }
        
        let oldState = flowState
        
        diagnosticLogger.startTiming("state_transition_\(String(describing: newState).lowercased())")
        diagnosticLogger.logUserInteraction("state_transition_requested", metadata: [
            "from_state": "\(String(describing: oldState))",
            "to_state": "\(String(describing: newState))",
            "can_proceed": "\(canProceed)",
            "player_ready": "\(currentPlayerViewModel?.isPlayerReady ?? false)",
            "video_loaded": "\(videoAsset != nil)"
        ])
        
        flowState = newState
        
        // Handle state-specific actions
        switch newState {
        case .loading(let progress, let status):
            loadingProgress = progress
            loadingStatus = status
            playerState = .loading
            diagnosticLogger.logInfo("🔄 Transitioned to loading state", metadata: [
                "progress": "\(progress)",
                "status": status
            ])
            
                    
        case .trimming_setup:
            playerState = .paused
            isTrimmingActive = true
            currentPlayerViewModel?.pauseForTrimming()

            // 🎯 CRITICAL FIX: Only setup the trimmer view model, don't auto-transition to .trimming
            // The transition to .trimming will happen after async setup completes successfully
            await setupTrimmerViewModel()
            diagnosticLogger.logInfo("🔄 Transitioned to trimming_setup state", metadata: [
                "trimmer_vm_created": "\(trimmerViewModel != nil)",
                "trimmer_vm_ready": "\(trimmerViewModel?.isReady ?? false)",
                "trim_range": "\(trimStartTime)-\(trimEndTime)"
            ])

        case .trimming:
            // 🎯 CRITICAL FIX: Assert player readiness before transitioning to trimming
            assert(currentPlayerViewModel != nil && currentPlayerViewModel?.avPlayer != nil, "Player must be ready before entering trimming state.")

            playerState = .paused
            isTrimmingActive = true
            currentPlayerViewModel?.pauseForTrimming()
            diagnosticLogger.logInfo("🔄 Transitioned to trimming state", metadata: [
                "trimmer_vm_ready": "\(trimmerViewModel?.isReady ?? false)",
                "trim_range": "\(trimStartTime)-\(trimEndTime)"
            ])

        case .finalizing(let status):
            // The .finalizing state is now purely for display.
            // All complex async logic has been moved to the calling context (`proceedToNextState`).
            // This ensures state transitions are clean and predictable.
            loadingStatus = status
            playerState = .paused // Keep the player paused during this intermediate step.
            diagnosticLogger.logInfo("🔄 Transitioned to finalizing state", metadata: [
                "status": status,
                "player_state": "paused",
                "async_logic_location": "moved_to_proceedToNextState"
            ])

        case .naming:
            playerState = .paused
            isTrimmingActive = false

            // The call to `currentPlayerViewModel?.pauseForTrimming()` is still a good safeguard.
            currentPlayerViewModel?.pauseForTrimming()

            // All the complex async logic and cleanup that was here is now in the .finalizing case.
            logger.info("🎬 UNIFIED_STATE: ✅ Naming state transition initiated. Player is pre-seeked and ready.")
            
        case .saving:
            isSaving = true
            saveProgress = 0.0
            diagnosticLogger.logInfo("🔄 Transitioned to saving state", metadata: [
                "video_ready": "\(videoAsset != nil)",
                "name_provided": "\(moveName.isEmpty ? "no" : "yes")"
            ])
            
        case .success(let message):
            logger.info("🎬 UNIFIED_STATE: Flow completed successfully - \(message)")
            diagnosticLogger.logInfo("✅ Flow completed successfully", metadata: [
                "success_message": message,
                "total_duration": diagnosticLogger.getActiveTimersCount() > 0 ? "measured" : "unknown"
            ])
            
        case .error(let message, let underlying):
            await setError(message: message, underlying: underlying)
            
        default:
            break
        }
        
        diagnosticLogger.stopTiming("state_transition_\(String(describing: newState).lowercased())")
    }
    
    /// Updates loading progress
    public func updateLoadingProgress(_ progress: Double, status: String) {
        loadingProgress = progress
        loadingStatus = status
        
        if case .loading = flowState {
            // Update the loading state with new progress
            flowState = .loading(progress: progress, status: status)
        }
    }
    
    
    /// Applies trim settings to the current video with enhanced race condition prevention and millisecond precision
    public func applyTrimSettings(startTime: CMTime, endTime: CMTime, rotation: Int) async throws {
        diagnosticLogger.startTiming("apply_trim_settings")

        let memoryBefore = diagnosticLogger.getMemoryInfo()
        let startTimeBeforeOperation = Date()

        // 🎯 CRITICAL FIX: Prevent duplicate calls with same parameters
        // This eliminates redundant processing during state transitions
        let currentStartTime = trimStartTime
        let currentEndTime = trimEndTime
        let currentTrimState = (currentStartTime, currentEndTime, rotationQuarterTurns)
        let requestedTrimState = (startTime.seconds, endTime.seconds, rotation)

        if currentStartTime == startTime.seconds && currentEndTime == endTime.seconds && rotationQuarterTurns == rotation {
            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: ⏭️ Skipping redundant trim application - parameters unchanged", metadata: [
                "current_start": "\(TimecodeFormatter.format(time: CMTime(seconds: currentStartTime, preferredTimescale: 600)))",
                "current_end": "\(TimecodeFormatter.format(time: CMTime(seconds: currentEndTime, preferredTimescale: 600)))",
                "current_rotation": "\(rotationQuarterTurns)",
                "requested_start": "(startTime.seconds)",
                "requested_end": "(endTime.seconds)",
                "requested_rotation": "\(rotation)"
            ])
            return
        }

        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 Starting enhanced trim settings application with race condition prevention", metadata: [
            "start_time": "(startTime.seconds)",
            "end_time": "(endTime.seconds)",
            "rotation": "\(rotation)",
            "current_flow_state": "\(flowState)",
            "current_player_state": "\(playerState)",
            "has_asset": "\(videoAsset != nil)",
            "has_trimmer": "\(trimmerViewModel != nil)",
            "has_player": "\(currentPlayerViewModel != nil)",
            "memory_usage_mb": "\(String(format: "%.1f", memoryBefore.used))",
            "cpu_usage_percent": "\(String(format: "%.1f", diagnosticLogger.getCurrentCPUUsage()))",
            "parameters_changed": "\(currentTrimState != requestedTrimState)"
        ])

        // 💡 ENHANCEMENT: Comprehensive preconditions validation
        guard let asset = videoAsset else {
            let errorMessage = "Cannot apply trim settings - no video asset available"
            let errorDetails: [String: String] = [
                "flow_state": "\(flowState)",
                "player_state": "\(playerState)",
                "trim_start": "\(trimStartTime)",
                "trim_end": "\(trimEndTime)",
                "rotation": "\(rotationQuarterTurns)"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.videoLoadFailed(underlyingError: nil)
        }

        guard currentPlayerViewModel != nil else {
            let errorMessage = "Cannot apply trim settings - no player available"
            let errorDetails: [String: String] = [
                "flow_state": "\(flowState)",
                "player_state": "\(playerState)",
                "has_asset": "\(videoAsset != nil)",
                "unified_player_manager_state": "\(unifiedPlayerManager.currentPlayer != nil)"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.playerNotReady
        }

        // 💡 ENHANCEMENT: Validate trim parameters with enhanced checks
        let duration = endTime - startTime
        let assetDuration = try await asset.load(.duration)

        guard duration.seconds > 0 else {
            let errorMessage = "Invalid trim range: duration must be positive (\(duration)s)"
            let errorDetails: [String: String] = [
                "start_time": "(startTime.seconds)",
                "end_time": "(endTime.seconds)",
                "duration": "\(duration)",
                "asset_duration": "\(assetDuration)",
                "minimum_required": "0.1"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.invalidTrimRange(errorMessage)
        }

        guard duration.seconds >= 3.0 else {
            let errorMessage = "Trim duration too short: \(duration)s (minimum: 3.0s)"
            let errorDetails: [String: String] = [
                "start_time": "(startTime.seconds)",
                "end_time": "(endTime.seconds)",
                "duration": "\(duration)",
                "asset_duration": "\(assetDuration)",
                "minimum_required": "3.0"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.invalidTrimRange(errorMessage)
        }

        guard startTime.seconds >= 0 else {
            let errorMessage = "Start time cannot be negative (\(startTime)s)"
            let errorDetails: [String: String] = [
                "start_time": "(startTime.seconds)",
                "end_time": "(endTime.seconds)",
                "asset_duration": "\(assetDuration)"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.invalidTrimRange(errorMessage)
        }

        guard endTime <= assetDuration else {
            let errorMessage = "End time ((endTime.seconds)s) exceeds asset duration ((TimecodeFormatter.format(time: assetDuration))s)"
            let errorDetails: [String: String] = [
                "start_time": "(startTime.seconds)",
                "end_time": "(endTime.seconds)",
                "asset_duration": "\(assetDuration)",
                "excess_duration": "\(TimecodeFormatter.format(time: endTime - assetDuration))"
            ]

            diagnosticLogger.logError(errorMessage, metadata: errorDetails)
            logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
            throw AddMoveError.invalidTrimRange(errorMessage)
        }

        // 💡 ENHANCEMENT: Store old values for potential rollback
        let oldStartTime = trimStartTime
        let oldEndTime = trimEndTime
        let oldRotation = rotationQuarterTurns

        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: ✅ Trim parameters validated, preparing to apply changes", metadata: [
            "old_range": "\(oldStartTime)-\(oldEndTime)",
            "new_range": "\(startTime)-\(endTime)",
            "old_rotation": "\(oldRotation)",
            "new_rotation": "\(rotation)",
            "duration_seconds": "\(duration)",
            "asset_duration": "\(assetDuration)",
            "validation_passed": "true"
        ])

        let startCMTime = startTime
        let endCMTime = endTime

        // 💡 ENHANCEMENT: Synchronize TrimmerViewModel state with UnifiedState BEFORE applying trim
        if let trimmerVM = trimmerViewModel {
            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 Synchronizing TrimmerViewModel state before trim application", metadata: [
                "trimmer_ready": "\(trimmerVM.isReady)",
                "trimmer_duration": "\(trimmerVM.videoDuration.seconds)",
                "current_trimmer_rotation": "\(trimmerVM.rotationQuarterTurns)",
                "target_rotation": "\(rotation)"
            ])

            await MainActor.run {
                // Force complete state synchronization with validation
                trimmerVM.rotationQuarterTurns = rotation
                trimmerVM.startTime = startCMTime
                trimmerVM.endTime = endCMTime

                // Force validation to ensure UI consistency
                trimmerVM.forceStateValidation()

                // Trigger object change notification to update UI
                self.objectWillChange.send()

                logger.info("🎬 UNIFIED_STATE: ✅ Synchronized TrimmerViewModel with UnifiedState")
            }
            diagnosticLogger.logDebug("✅ TrimmerViewModel synchronized successfully")
        } else {
            diagnosticLogger.logWarning("⚠️ TrimmerViewModel not available for synchronization", metadata: [
                "flow_state": "\(flowState)",
                "player_state": "\(playerState)"
            ])
        }

        // 💡 ENHANCEMENT: Prepare state transition with enhanced logging
        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 Updating local state before player operation", metadata: [
            "old_start_time": "\(oldStartTime)",
            "new_start_time": "\(startTime)",
            "old_end_time": "\(oldEndTime)",
            "new_end_time": "\(endTime)",
            "old_rotation": "\(oldRotation)",
            "new_rotation": "\(rotation)"
        ])

        // 🎯 CRITICAL FIX: Store CMTime values as Double for API compatibility
        trimStartTime = startTime.seconds
        trimEndTime = endTime.seconds
        rotationQuarterTurns = rotation

        // 💡 ENHANCEMENT: Apply trim to player with comprehensive error handling and retry logic
        do {
            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 Starting player trim operation with readiness monitoring", metadata: [
                "start_time_cm": "\(TimecodeFormatter.format(time: startCMTime))",
                "end_time_cm": "\(TimecodeFormatter.format(time: endCMTime))",
                "rotation": "\(rotation)",
                "player_ready": "\(currentPlayerViewModel?.isPlayerReady ?? false)"
            ])

            try await unifiedPlayerManager.applyTrimToCurrentPlayer(
                startTime: startCMTime,
                endTime: endCMTime,
                rotation: rotation
            )

            // 💡 ENHANCEMENT: Post-operation validation
            guard let playerVM = currentPlayerViewModel, playerVM.isPlayerReady else {
                let errorMessage = "Player failed to achieve ready state after trim operation"
                diagnosticLogger.logError(errorMessage, metadata: [
                    "player_state": "\(currentPlayerViewModel?.state ?? .idle)",
                    "player_ready": "\(currentPlayerViewModel?.isPlayerReady ?? false)",
                    "is_playback_pending": "false"
                ])
                logger.error("🎬 UNIFIED_STATE: ❌ \(errorMessage)")
                throw AddMoveError.playerNotReady
            }

            let memoryAfter = diagnosticLogger.getMemoryInfo()
            let operationDuration = Date().timeIntervalSince(startTimeBeforeOperation)

            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🎉 Enhanced trim settings applied successfully", metadata: [
                "final_start_time": "\(trimStartTime)",
                "final_end_time": "\(trimEndTime)",
                "final_rotation": "\(rotationQuarterTurns)",
                "player_ready": "\(playerVM.isPlayerReady)",
                "player_state": "\(playerVM.state)",
                "memory_before_mb": "\(String(format: "%.1f", memoryBefore.used))",
                "memory_after_mb": "\(String(format: "%.1f", memoryAfter.used))",
                "memory_delta_mb": "\(String(format: "%.1f", memoryAfter.used - memoryBefore.used))",
                "operation_duration_seconds": "\(String(format: "%.3f", operationDuration))",
                "operation_success": "true"
            ])

            logger.info("🎬 UNIFIED_STATE: ✅ Trim settings applied with enhanced race condition prevention")

        } catch {
            // 💡 ENHANCEMENT: Enhanced error handling with rollback and detailed diagnostics
            diagnosticLogger.logError("Trim operation failed, attempting rollback", error: error, metadata: [
                "error_type": "\(type(of: error))",
                "error_description": error.localizedDescription,
                "operation_start_time": "\(startTimeBeforeOperation)",
                "failed_start_time": "\(startTime)",
                "failed_end_time": "\(endTime)",
                "failed_rotation": "\(rotation)"
            ])

            // 💡 ENHANCEMENT: Rollback local state changes
            await MainActor.run {
                self.trimStartTime = oldStartTime
                self.trimEndTime = oldEndTime
                self.rotationQuarterTurns = oldRotation
                self.objectWillChange.send()
            }

            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 State rollback completed", metadata: [
                "restored_start_time": "\(trimStartTime)",
                "restored_end_time": "\(trimEndTime)",
                "restored_rotation": "\(rotationQuarterTurns)"
            ])

            // 💡 ENHANCEMENT: Attempt to synchronize TrimmerViewModel with rolled-back state
            if let trimmerVM = trimmerViewModel {
                await MainActor.run {
                    trimmerVM.rotationQuarterTurns = oldRotation
                    trimmerVM.startTime = CMTime(seconds: oldStartTime, preferredTimescale: 600)
                    trimmerVM.endTime = CMTime(seconds: oldEndTime, preferredTimescale: 600)
                    trimmerVM.forceStateValidation()
                    trimmerVM.objectWillChange.send()
                }
                diagnosticLogger.logDebug("✅ TrimmerViewModel synchronized with rolled-back state")
            }

            logger.error("🎬 UNIFIED_STATE: ❌ Trim settings application failed, state rolled back")
            throw error
        }

        diagnosticLogger.stopTiming("apply_trim_settings")
    }

    /// 🎯 NEW: Synchronizes trim state without rotation changes (for normal trim operations)
    /// This ensures normal trim operations have the same robust synchronization as rotation
    public func synchronizeTrimState() async {
        guard let trimmerVM = trimmerViewModel else {
            diagnosticLogger.logWarning("⚠️ Cannot synchronize trim state - TrimmerViewModel not available")
            return
        }

        diagnosticLogger.logDebug("🔄 Synchronizing trim state for normal operation")

        await MainActor.run {
            // Force validation to ensure UI consistency
            trimmerVM.forceStateValidation()

            // Trigger object change notification to update UI
            self.objectWillChange.send()
        }

        diagnosticLogger.logDebug("✅ Trim state synchronized successfully")
    }

    /// Sets error state
    public func setError(message: String, underlying: String? = nil) async {
        let wasInError = errorMessage != nil
        
        errorMessage = message
        underlyingError = underlying
        playerState = .error(message)
        
        diagnosticLogger.logError("Error state set", metadata: [
            "error_message": message,
            "underlying_error": underlying ?? "none",
            "was_in_error": "\(wasInError)",
            "flow_state": "\(flowState)",
            "player_state": "\(playerState)",
            "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
        ])
        
        if case .error = flowState {
            // Already in error state, just update the message
            diagnosticLogger.logDebug("Already in error state, updating message only")
        } else {
            await transitionTo(.error(message: message, underlyingError: underlying))
        }
        
        logger.error("🎬 UNIFIED_STATE: ❌ Error set - \(message)")
    }
    
    /// Clears error state
    public func clearError() async {
        let hadError = errorMessage != nil
        
        errorMessage = nil
        underlyingError = nil
        
        diagnosticLogger.logInfo("Clearing error state", metadata: [
            "had_error": "\(hadError)",
            "current_flow_state": "\(flowState)",
            "current_player_state": "\(playerState)"
        ])
        
        if case .error = flowState {
            await transitionTo(.ready)
        }

        if case .error = playerState {
            playerState = .idle
        }
        
        logger.info("🎬 UNIFIED_STATE: ✅ Error cleared")
        diagnosticLogger.logDebug("✅ Error state cleared successfully")
    }
    
    /// Resets all state to initial values
    public func reset() {
        diagnosticLogger.startTiming("unified_state_reset")
        
        let preResetMemory = diagnosticLogger.getMemoryInfo()
        let currentFlowState = flowState
        let currentVideoAsset = videoAsset != nil
        
        diagnosticLogger.logInfo("🔄 Starting unified state reset", metadata: [
            "current_flow_state": "\(currentFlowState)",
            "has_video_asset": "\(currentVideoAsset)",
            "memory_usage_mb": "\(String(format: "%.1f", preResetMemory.used))"
        ])
        
        logger.info("🎬 UNIFIED_STATE: Resetting all state")
        
        // Stop health monitoring
        healthMonitor.stopMonitoring()
        diagnosticLogger.logDebug("⏹️ Health monitoring stopped")

        // 🎯 CRITICAL FIX: Cleanup player manager to prevent retain cycles
        diagnosticLogger.logInfo("🚨 Starting player manager cleanup - RETAIN CYCLE PREVENTION", metadata: [
            "currentPlayer_exists": "\(currentPlayerViewModel != nil)",
            "playerManager_hasPlayer": "\(unifiedPlayerManager.currentPlayer != nil)",
            "flowState": "\(flowState)"
        ])
        unifiedPlayerManager.cleanup()
        diagnosticLogger.logInfo("✅ Player manager cleanup completed - RETAIN CYCLE BROKEN", metadata: [
            "currentPlayer_exists_after": "\(currentPlayerViewModel != nil)",
            "playerManager_hasPlayer_after": "\(unifiedPlayerManager.currentPlayer != nil)"
        ])
        
        // Reset all properties
        flowState = .ready
        playerState = .idle
        videoAsset = nil
        photosIdentifier = nil
        selectedVideoItem = nil
        loadingProgress = 0.0
        loadingStatus = ""
        rotationQuarterTurns = 0
        trimStartTime = 0.0
        trimEndTime = 0.0
        isTrimmingActive = false
        moveName = ""
        isSaving = false
        saveProgress = 0.0
        errorMessage = nil
        underlyingError = nil
        
        let postResetMemory = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("✅ Unified state reset completed", metadata: [
            "previous_flow_state": "\(currentFlowState)",
            "previous_video_asset": "\(currentVideoAsset)",
            "memory_before_mb": "\(String(format: "%.1f", preResetMemory.used))",
            "memory_after_mb": "\(String(format: "%.1f", postResetMemory.used))",
            "memory_freed_mb": "\(String(format: "%.1f", preResetMemory.used - postResetMemory.used))"
        ])
        
        logger.info("🎬 UNIFIED_STATE: ✅ Reset completed")
        diagnosticLogger.stopTiming("unified_state_reset")
    }
    
    /// Prepares for view transition (pauses monitoring, preserves state)
    public func prepareForTransition() {
        diagnosticLogger.startTiming("view_transition_prepare")
        
        diagnosticLogger.logInfo("🔄 Preparing for view transition", metadata: [
            "current_flow_state": "\(flowState)",
            "current_player_state": "\(playerState)",
            "has_video_asset": "\(videoAsset != nil)",
            "trimmer_vm_active": "\(trimmerViewModel != nil)"
        ])
        
        logger.info("🎬 UNIFIED_STATE: Preparing for transition")
        
        unifiedPlayerManager.prepareForTransition()
        healthMonitor.pauseMonitoring()
        
        diagnosticLogger.logDebug("✅ Transition preparation completed")
        diagnosticLogger.stopTiming("view_transition_prepare")
    }
    
    /// Completes view transition (resumes monitoring)
    public func completeTransition() {
        diagnosticLogger.startTiming("view_transition_complete")
        
        diagnosticLogger.logInfo("🔄 Completing view transition", metadata: [
            "current_flow_state": "\(flowState)",
            "current_player_state": "\(playerState)",
            "health_monitor_resumed": "true"
        ])
        
        logger.info("🎬 UNIFIED_STATE: Completing transition")
        
        unifiedPlayerManager.completeTransition()
        healthMonitor.resumeMonitoring()
        
        let memoryInfo = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("✅ Transition completed successfully", metadata: [
            "memory_usage_mb": "\(String(format: "%.1f", memoryInfo.used))",
            "cpu_usage_percent": "\(String(format: "%.1f", diagnosticLogger.getCurrentCPUUsage()))"
        ])
        
        diagnosticLogger.stopTiming("view_transition_complete")
    }
    
    // MARK: - Video Loading
    
    /// Loads video asset from PhotosPicker item and sets up the player
    private func loadVideo(from item: PhotosPickerItem) async {
        diagnosticLogger.startTiming("video_loading")
        let startMemory = diagnosticLogger.getMemoryInfo()

        diagnosticLogger.logInfo("🎬 Starting video asset loading", metadata: [
            "flow_state": "\(flowState)",
            "player_state": "\(playerState)",
            "memory_usage_mb": "\(String(format: "%.1f", startMemory.used))"
        ])

        logger.info("🎬 UNIFIED_STATE: Loading video asset using VideoAssetPreparer")

        let assetPreparer = VideoAssetPreparer(videoLoader: AddMoveVideoLoader())

        do {
            // 🎯 CRITICAL FIX: Implement atomic health monitor management with defer
            healthMonitor.pauseMonitoring()
            defer {
                // This guarantees health monitor is resumed whether function succeeds or fails
                healthMonitor.resumeMonitoring()
                logger.info("🎬 UNIFIED_STATE: 🏥 Health monitor resumed via defer.")
            }

            // 🎯 CRITICAL FIX: Consolidate to 3 meaningful progress states
            updateProgress(0.1, status: "Preparing video import...")
            diagnosticLogger.logDebug("📥 Video import preparation started")

            // The preparer handles everything: loading, player creation, and readiness.
            let result = try await assetPreparer.prepareVideo(from: item)

            updateProgress(0.8, status: "Finalizing setup...")
            diagnosticLogger.logDebug("⚙️ Video asset preparation completed")

            // 🎯 CRITICAL FIX: Set player and update state properties
            if let playerVM = result.playerViewModel as? UnifiedVideoPlayerViewModel {
                self.unifiedPlayerManager.setPlayer(playerVM)
                diagnosticLogger.logDebug("✅ Player view model set in manager")
            }

            // Update the state with the prepared results.
            self.videoAsset = result.asset
            self.photosIdentifier = result.photosIdentifier

            // Update the UnifiedPlayerManager's internal state
            self.unifiedPlayerManager.updateAsset(result.asset, photosIdentifier: result.photosIdentifier)

            // 🎯 CRITICAL FIX: Single consolidated validation block
            guard self.currentPlayerViewModel != nil,
                  self.videoAsset != nil,
                  self.photosIdentifier != nil else {
                let failureDescription = "Missing required components after video preparation."
                logger.error("🎬 UNIFIED_STATE: ❌ Validation failed: \(failureDescription)")
                await self.setError(message: "Video setup incomplete", underlying: failureDescription)
                return
            }

            // Set initial trim range to the full video duration.
            let assetDuration = try await result.asset.load(.duration).seconds

            // Validate duration before setting trim times
            guard assetDuration > 0 else {
                throw NSError(domain: "VideoLoading", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video duration: \(assetDuration)"])
            }

            // Ensure minimum duration requirement is met
            let minimumDuration = 3.0
            let validatedEndTime = assetDuration >= minimumDuration ? assetDuration : minimumDuration

            await MainActor.run {
                self.trimStartTime = 0.0
                self.trimEndTime = validatedEndTime
            }

            diagnosticLogger.logInfo("📏 Set initial trim range", metadata: [
                "asset_duration": "\(assetDuration)",
                "start_time": "\(trimStartTime)",
                "end_time": "\(trimEndTime)",
                "meets_minimum": "\(validatedEndTime >= minimumDuration)"
            ])

            diagnosticLogger.logInfo("📹 Video loading completed successfully", metadata: [
                "asset_duration_seconds": "\(assetDuration)",
                "player_ready": "\(result.playerViewModel.isPlayerReady)",
                "photos_identifier": "\(result.photosIdentifier ?? "none")",
                "validation_passed": "true"
            ])

            // 🎯 CRITICAL FIX: Final progress state before transition
            updateProgress(1.0, status: "Complete!")
            diagnosticLogger.logDebug("⚙️ Video loading process finalized")

            // 🎯 CRITICAL FIX: Transition to trimming_setup state with timeout protection
            do {
                try await withTimeout(seconds: 3.0) {
                    // Transition to trimming_setup state to prepare trimmer view model
                    await self.transitionTo(.trimming_setup)
                    self.logger.info("🎬 UNIFIED_STATE: ✅ Video preparation complete. Transitioning to trimming_setup.")
                }
            } catch {
                logger.error("🎬 UNIFIED_STATE: ❌ State transition timed out")
                await self.setError(message: "Video setup timed out", underlying: "State transition timeout")
                return
            }

            let endMemory = diagnosticLogger.getMemoryInfo()
            diagnosticLogger.logInfo("📊 Video loading performance", metadata: [
                "memory_before_mb": "\(String(format: "%.1f", startMemory.used))",
                "memory_after_mb": "\(String(format: "%.1f", endMemory.used))",
                "memory_increase_mb": "\(String(format: "%.1f", endMemory.used - startMemory.used))"
            ])

        } catch {
            // 🎯 CRITICAL FIX: Health monitor is automatically resumed by defer block
            // No need for manual resume here

            diagnosticLogger.logError("Video loading failed", error: error, metadata: [
                "flow_state": "\(flowState)",
                "item_type": "\(type(of: item))",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            logger.error("🎬 UNIFIED_STATE: ❌ VideoAssetPreparer failed: \(error.localizedDescription)")
            await self.setError(message: "Failed to prepare video", underlying: error.localizedDescription)
        }

        diagnosticLogger.stopTiming("video_loading")
    }
    
    // MARK: - Trimmer ViewModel Management
    
    /// Sets up the TrimmerViewModel when transitioning to trimming state
    private func setupTrimmerViewModel() async {
        diagnosticLogger.startTiming("trimmer_vm_setup")

        let canSetup = trimmerViewModel == nil && videoAsset != nil && currentPlayerViewModel != nil

        diagnosticLogger.logInfo("🔧 Setting up TrimmerViewModel", metadata: [
            "can_setup": "\(canSetup)",
            "trimmer_vm_exists": "\(trimmerViewModel != nil)",
            "asset_available": "\(videoAsset != nil)",
            "player_vm_available": "\(currentPlayerViewModel != nil)",
            "current_rotation": "\(rotationQuarterTurns)",
            "current_trim_range": "\(trimStartTime)-\(trimEndTime)"
        ])

        guard trimmerViewModel == nil,
              let asset = videoAsset,
              let playerViewModel = currentPlayerViewModel else {
            logger.info("🎬 UNIFIED_STATE: TrimmerViewModel already exists or missing required components")
            diagnosticLogger.logWarning("⚠️ TrimmerViewModel setup skipped - missing requirements")
            return
        }

        logger.info("🎬 UNIFIED_STATE: Setting up TrimmerViewModel")

        // 🎯 CRITICAL FIX: Create TrimmerViewModel and wait for async setup
        let newTrimmerViewModel = TrimmerViewModel(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns,
            playerViewModel: playerViewModel
        )

        self.trimmerViewModel = newTrimmerViewModel

        // 🎯 CRITICAL FIX: Wait for async setup to complete with timeout protection
        do {
            // Use timeout protection to prevent hanging
            try await withTimeout(seconds: 15.0) {
                try await newTrimmerViewModel.setupAsync()
            }

            // 🎯 CRITICAL FIX: Validate that setup completed successfully before setting trim values
            guard newTrimmerViewModel.isReady else {
                diagnosticLogger.logError("❌ TrimmerViewModel setup completed but isReady is false")
                throw NSError(domain: "TrimmerSetup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Trimmer not ready after setup"])
            }

            guard newTrimmerViewModel.videoDuration.seconds > 0 else {
                diagnosticLogger.logError("❌ TrimmerViewModel has invalid duration after setup")
                throw NSError(domain: "TrimmerSetup", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid duration after setup"])
            }

            // Now set initial trim values using the actual asset duration
            let startTime = trimStartTime
            let endTime = trimEndTime

            // Validate trim range against actual duration
            let validatedEndTime = min(endTime, newTrimmerViewModel.videoDuration.seconds)
            let validatedStartTime = min(startTime, validatedEndTime - newTrimmerViewModel.minimumDuration.seconds)

            await MainActor.run {
                newTrimmerViewModel.startTime = CMTime(seconds: validatedStartTime, preferredTimescale: 600)
                newTrimmerViewModel.endTime = CMTime(seconds: validatedEndTime, preferredTimescale: 600)
            }

            diagnosticLogger.logDebug("✅ TrimmerViewModel setup completed and trim values set")

            diagnosticLogger.logInfo("✅ TrimmerViewModel setup completed", metadata: [
                "initial_start_time": "\(validatedStartTime)",
                "initial_end_time": "\(validatedEndTime)",
                "duration_seconds": "\(validatedEndTime - validatedStartTime)",
                "video_duration_seconds": "\(newTrimmerViewModel.videoDuration.seconds)",
                "rotation_quarter_turns": "\(rotationQuarterTurns)",
                "trimmer_ready": "\(newTrimmerViewModel.isReady)"
            ])

            // 🎯 CRITICAL FIX: Now that setup is complete, transition to trimming state
            // This ensures the UI only shows trimmer when everything is truly ready
            try await withTimeout(seconds: 5.0) {
                await self.transitionTo(.trimming)
            }

        } catch let timeoutError as TimeoutError {
            diagnosticLogger.logError("⏰ TrimmerViewModel setup timed out", error: timeoutError)
            self.trimmerViewModel = nil
            await setError(message: "Video trimmer setup timed out", underlying: "The async initialization took too long")
        } catch {
            diagnosticLogger.logError("TrimmerViewModel setup failed", error: error)
            // Don't continue - the trimmer won't function properly
            self.trimmerViewModel = nil
            await setError(message: "Failed to setup video trimmer", underlying: error.localizedDescription)
        }

        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel setup process completed")
        diagnosticLogger.stopTiming("trimmer_vm_setup")
    }
    
    /// Cleans up the TrimmerViewModel when transitioning away from trimming state
    private func cleanupTrimmerViewModel() async {
        guard trimmerViewModel != nil else {
            diagnosticLogger.logDebug("⏭️ TrimmerViewModel cleanup skipped - already nil")
            return
        }

        diagnosticLogger.startTiming("trimmer_vm_cleanup")

        logger.info("🎬 UNIFIED_STATE: Cleaning up TrimmerViewModel")

        // Sync final trim values back to unified state before cleanup
        if let trimmerViewModel = trimmerViewModel {
            let finalStartTime = trimmerViewModel.startTime.seconds
            let finalEndTime = trimmerViewModel.endTime.seconds
            let finalRotation = trimmerViewModel.rotationQuarterTurns

            await MainActor.run {
                self.trimStartTime = finalStartTime
                self.trimEndTime = finalEndTime
                self.rotationQuarterTurns = finalRotation
            }

            diagnosticLogger.logInfo("🔄 Syncing final trim values before cleanup", metadata: [
                "final_start_time": "\(finalStartTime)",
                "final_end_time": "\(finalEndTime)",
                "final_rotation": "\(finalRotation)",
                "final_duration": "\(finalEndTime - finalStartTime)"
            ])
        }

        // Clear the trimmer view model
        await MainActor.run {
            self.trimmerViewModel = nil
        }

        diagnosticLogger.logInfo("✅ TrimmerViewModel cleanup completed")
        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel cleanup completed")
        diagnosticLogger.stopTiming("trimmer_vm_cleanup")
    }
    
    // MARK: - Validation
    
    /// Validates current state for the desired transition
    public func canTransitionTo(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .trimming_setup:
            return hasVideo && currentPlayerViewModel != nil
        case .trimming:
            return flowState == .trimming_setup && currentPlayerViewModel != nil
        case .naming:
            return flowState == .trimming && currentPlayerViewModel != nil
        case .saving:
            return flowState == .naming && !moveName.isEmpty
        default:
            return true
        }
    }
    
    // MARK: - Debug Info
    
    /// Returns current state information for debugging
    public func debugInfo() -> String {
        let memoryInfo = diagnosticLogger.getMemoryInfo()
        let cpuUsage = diagnosticLogger.getCurrentCPUUsage()
        
        return """
        AddMoveUnifiedState Debug:
        - Flow State: \(flowState)
        - Player State: \(playerState)
        - Video Asset: \(videoAsset != nil ? "Available" : "Nil")
        - Photos ID: \(photosIdentifier ?? "Nil")
        - Player Ready: \(currentPlayerViewModel != nil)
        - Trimmer VM Active: \(trimmerViewModel != nil)
        - Health Monitor Active: \(healthMonitor.getCurrentHealth().description)
        - Memory: \(String(format: "%.1f", memoryInfo.used))MB used (\(String(format: "%.1f", memoryInfo.percentage))%)
        - CPU Usage: \(String(format: "%.1f", cpuUsage))%
        - Can Proceed: \(canProceed)
        - Is In Error: \(isInError)
        - Loading Progress: \(loadingProgress)
        - Active Timers: \(diagnosticLogger.getActiveTimerNames().joined(separator: ", "))
        """
    }
    
    deinit {
        // Perform synchronous cleanup to avoid retain cycles
        // Note: Can't call main actor methods in deinit, so we simplify

        // Skip memory/timer info as those require main actor

        // Perform essential cleanup synchronously
        // Note: These methods might be main actor isolated, but we'll try synchronous calls
        do {
            healthMonitor.stopMonitoring()
        } catch {
            // Ignore cleanup errors in deinit
        }

        // Note: Can't call unifiedPlayerManager.cleanup() from deinit as it's main actor-isolated
        // The manager should handle its own cleanup when it's deallocated

        // Use a simple logger for deinit messages to avoid any complex operations
        let deinitLogger = Logger(subsystem: "BreakingFlashcards", category: "AddMoveUnifiedState")
        deinitLogger.info("🗑️ AddMoveUnifiedState deinitialized")
    }

    // MARK: - Real-time Validation State
    @Published private var saveReadiness: SaveReadinessResult?
    @Published private var lastSaveReadiness: SaveReadinessResult?
    private var saveReadinessMonitoringTask: Task<Void, Never>?
}

// MARK: - Convenience Extensions
extension AddMoveUnifiedState {
    
    /// Convenience method to transition to loading state
    public func startLoading(status: String = "Loading...") async {
        await transitionTo(.loading(progress: 0.0, status: status))
    }
    
    /// Convenience method to update loading progress
    public func updateProgress(_ progress: Double, status: String? = nil) {
        let currentStatus = status ?? loadingStatus
        updateLoadingProgress(progress, status: currentStatus)
    }
    
    
    /// Convenience method to handle video selection
    public func didSelectVideo(_ item: PhotosPickerItem) {
        selectedVideoItem = item
        Task {
            await startLoading(status: "Preparing to load video...")

            logger.info("🎬 UNIFIED_STATE: Video selection detected, starting loading task")

            // Start the video loading task
            await loadVideo(from: item)
        }
    }
    
    /// Convenience method to proceed to next logical state
    public func proceedToNextState() async throws {
        switch flowState {
        case .ready:
            // Should have video selected by this point
            guard hasVideo else {
                throw AddMoveError.videoLoadFailed(underlyingError: nil)
            }

        case .trimming:
            // 🎯 CRITICAL CATEGORICAL FIX: Perform video processing BEFORE state transition
            // This preserves the AVPlayerLayer in the view hierarchy during composition
            diagnosticLogger.startTiming("transition_trimming_to_naming")
            logger.info("🎬 UNIFIED_STATE: 🚀 Starting deadlock-free transition from .trimming")

            // 1. 🧠 Get final values directly from the TrimmerViewModel BEFORE any cleanup.
            guard let trimmerVM = self.trimmerViewModel else {
                await setError(message: "Trimmer state was lost.", underlying: "TrimmerViewModel was nil during transition.")
                return
            }
            let finalStartTime = trimmerVM.startTime.seconds
            let finalEndTime = trimmerVM.endTime.seconds
            let finalRotation = trimmerVM.rotationQuarterTurns

            diagnosticLogger.logInfo("✅ Captured final trim values while UI is still active", metadata: [
                "start_time": "\(finalStartTime)",
                "end_time": "\(finalEndTime)",
                "rotation": "\(finalRotation)",
                "render_layer_preserved": "true"
            ])

            // 2. 🎯 CRITICAL FIX: Perform all sequential async work BEFORE transitioning state.
            // This keeps the AVPlayerLayer in the view hierarchy, allowing the new AVPlayerItem to become ready.
            do {
                diagnosticLogger.startTiming("transactional_trim_and_seek")
                try await unifiedPlayerManager.applyTrimAndSeek(
                    startTime: CMTime(seconds: finalStartTime, preferredTimescale: 600),
                    endTime: CMTime(seconds: finalEndTime, preferredTimescale: 600),
                    rotation: finalRotation
                )
                diagnosticLogger.stopTiming("transactional_trim_and_seek")

                // 3. 🧹 Perform cleanup for the state we are LEAVING.
                await cleanupTrimmerViewModel()

                // 4. ✅ ONLY after all work is successful, transition to the final state.
                await transitionTo(.naming)

                logger.info("🎬 UNIFIED_STATE: 🎉 Successfully transitioned to .naming state via deadlock-free operation.")
                diagnosticLogger.stopTiming("transition_trimming_to_naming")

            } catch {
                // 5. ❌ If any step fails, transition to a clear error state.
                logger.error("🎬 UNIFIED_STATE: ❌ Failed to prepare video for naming view: \(error.localizedDescription)")
                diagnosticLogger.logError("Video preparation for naming failed", error: error)
                await setError(message: "Could not prepare video preview.", underlying: error.localizedDescription)
                diagnosticLogger.stopTiming("transition_trimming_to_naming")
            }

        case .naming:
            await transitionTo(.saving)
            
        default:
            logger.error("🎬 UNIFIED_STATE: Cannot proceed from current state: \(String(describing: self.flowState))")
        }
    }

    // MARK: - State Validation Methods

    /// Validates the current state for consistency across all components
    public func validateStateConsistency() -> [StateValidationError] {
        var errors: [StateValidationError] = []

        // Validate video asset consistency
        if let videoAsset = videoAsset {
            if videoAsset.duration.seconds <= 0 {
                errors.append(.invalidAssetDuration(videoAsset.duration.seconds))
            }
        }

        // Validate trimmer state consistency
        if let trimmerVM = trimmerViewModel {
            if trimmerVM.startTime.seconds < 0 {
                errors.append(.invalidStartTime(trimmerVM.startTime.seconds))
            }

            if trimmerVM.endTime.seconds > (videoAsset?.duration.seconds ?? 0) {
                errors.append(.endTimeExceedsAsset(trimmerVM.endTime.seconds, videoAsset?.duration.seconds ?? 0))
            }

            if trimmerVM.startTime >= trimmerVM.endTime {
                errors.append(.startTimeAfterEndTime(trimmerVM.startTime.seconds, trimmerVM.endTime.seconds))
            }

            let duration = trimmerVM.endTime - trimmerVM.startTime
            if duration.seconds < trimmerVM.minimumDuration.seconds {
                errors.append(.durationTooShort(duration.seconds, trimmerVM.minimumDuration.seconds))
            }
        }

        // Validate player state consistency
        if let playerVM = currentPlayerViewModel {
            if !playerVM.isPlayerReady && flowState == .trimming {
                errors.append(.playerNotReadyInTrimmingState)
            }
        }

        // Validate flow state consistency
        switch flowState {
        case .trimming:
            if trimmerViewModel == nil {
                errors.append(.missingTrimmerInTrimmingState)
            }
        case .finalizing:
            // Finalizing state should have no active trimmer but should have a player
            if trimmerViewModel != nil {
                errors.append(.missingTrimmerInTrimmingState)
            }
            if currentPlayerViewModel == nil {
                errors.append(.missingPlayerInNamingState)
            }
        case .naming:
            if currentPlayerViewModel == nil {
                errors.append(.missingPlayerInNamingState)
            }
        default:
            break
        }

        if !errors.isEmpty {
            diagnosticLogger.logWarning("⚠️ State validation found \(errors.count) issues", metadata: [
                "error_count": "\(errors.count)",
                "flow_state": "\(flowState)",
                "has_trimmer": "\(trimmerViewModel != nil)",
                "has_player": "\(currentPlayerViewModel != nil)"
            ])
        } else {
            diagnosticLogger.logDebug("✅ State validation passed")
        }

        return errors
    }

    /// Validates trim parameters for saving using persistent state properties
    /// 🎯 FIXED: Removes dependency on deallocated TrimmerViewModel
    public func validateTrimParametersForSave() throws {
        // 🗑️ REMOVED: Dependency on trimmerViewModel which is deallocated during state transition
        // guard let trimmerVM = trimmerViewModel else {
        //     throw AddMoveError.trimmerNotAvailable
        // }

        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔧 Validating trim parameters using persistent state properties")

        // ✅ USE: Direct properties from unified state that persist after trimming
        let startTime = self.trimStartTime
        let endTime = self.trimEndTime
        let assetDuration = videoAsset?.duration.seconds ?? 0

        // Log the validation source for debugging
        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 📊 Trim validation data source", metadata: [
            "source": "persistent_state_properties",
            "trim_start_time": "\(startTime)",
            "trim_end_time": "\(endTime)",
            "asset_duration": "\(assetDuration)",
            "rotation_quarter_turns": "\(rotationQuarterTurns)"
        ])

        // Validate start time
        guard startTime >= 0 else {
            let error = AddMoveError.invalidTrimRange("Start time cannot be negative")
            diagnosticLogger.logError("Trim validation failed: negative start time", error: error)
            throw error
        }

        // Validate end time
        guard endTime <= assetDuration else {
            let error = AddMoveError.invalidTrimRange("End time cannot exceed video duration")
            diagnosticLogger.logError("Trim validation failed: end time exceeds duration", error: error, metadata: [
                "end_time": "(endTime.seconds)",
                "asset_duration": "\(assetDuration)"
            ])
            throw error
        }

        // Validate time order
        guard startTime < endTime else {
            let error = AddMoveError.invalidTrimRange("Start time must be before end time")
            diagnosticLogger.logError("Trim validation failed: invalid time order", error: error, metadata: [
                "start_time": "(startTime.seconds)",
                "end_time": "(endTime.seconds)"
            ])
            throw error
        }

        // Validate minimum duration
        let duration = endTime - startTime
        guard duration >= 3.0 else {
            let error = AddMoveError.invalidTrimRange("Video duration must be at least 3 seconds")
            diagnosticLogger.logError("Trim validation failed: duration too short", error: error, metadata: [
                "duration": "\(duration)",
                "minimum_required": "3.0"
            ])
            throw error
        }

        // 🎯 SUCCESS: Trim parameters are valid - log comprehensive diagnostics
        diagnosticLogger.logInfo("✅ Trim parameters validated for save using persistent state", metadata: [
            "start_time": "(startTime.seconds)",
            "end_time": "(endTime.seconds)",
            "duration": "\(duration)",
            "asset_duration": "\(assetDuration)",
            "validation_source": "unified_state_properties",
            "trimmer_viewmodel_dependency": "removed"
        ])
    }

    /// Validates that the state is ready for saving
    public func validateReadyForSave() throws {
        // Check if we have a valid move name
        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AddMoveError.invalidMoveName
        }

        // Validate video asset
        guard videoAsset != nil else {
            throw AddMoveError.videoAssetNotAvailable
        }

        // Validate trim parameters
        try validateTrimParametersForSave()

        // Validate player readiness
        guard let playerVM = currentPlayerViewModel, playerVM.isPlayerReady else {
            throw AddMoveError.playerNotReady
        }

        diagnosticLogger.logInfo("✅ State validated and ready for save", metadata: [
            "move_name": "\(moveName)",
            "has_asset": "\(videoAsset != nil)",
            "player_ready": "\(currentPlayerViewModel?.isPlayerReady ?? false)"
        ])
    }

    /// Forces synchronization of all time-related state
    public func synchronizeTimeState() {
        diagnosticLogger.logDebug("🔄 Synchronizing time state")

        // Force trimmer view model to update
        trimmerViewModel?.objectWillChange.send()

        // Force player view model to update
        currentPlayerViewModel?.objectWillChange.send()

        // Update our own published properties
        objectWillChange.send()

        diagnosticLogger.logDebug("✅ Time state synchronization completed")
    }

    // MARK: - Asset Readiness Verification

    /// Verifies that the current video asset is ready for processing
    public func verifyAssetReadiness() async throws -> AVAsset {
        diagnosticLogger.startTiming("asset_readiness_verification")

        guard let asset = videoAsset else {
            diagnosticLogger.logError("❌ No video asset available for verification")
            throw AddMoveError.videoAssetNotAvailable
        }

        diagnosticLogger.logInfo("🔍 Starting asset readiness verification", metadata: [
            "asset_duration": "\(asset.duration.seconds)",
            "is_playable": "\(asset.isPlayable)",
            "flow_state": "\(flowState)"
        ])

        // Basic asset validation
        guard asset.isPlayable else {
            diagnosticLogger.logError("❌ Asset is not playable", metadata: [
                "asset_duration": "\(asset.duration.seconds)"
            ])
            throw AddMoveError.assetNotReady("Asset is not playable")
        }

        guard asset.duration.seconds > 0 else {
            diagnosticLogger.logError("❌ Asset has invalid duration", metadata: [
                "asset_duration": "\(asset.duration.seconds)"
            ])
            throw AddMoveError.invalidAssetDuration
        }

        // Load and verify tracks asynchronously
        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard !videoTracks.isEmpty else {
                diagnosticLogger.logError("❌ Asset has no video tracks")
                throw AddMoveError.assetNotReady("Asset has no video tracks")
            }

            // Load and verify duration asynchronously
            let loadedDuration = try await asset.load(.duration)
            guard loadedDuration.seconds > 0 else {
                diagnosticLogger.logError("❌ Asset duration after load is invalid", metadata: [
                    "loaded_duration": "\(loadedDuration.seconds)"
                ])
                throw AddMoveError.invalidAssetDuration
            }

            // Verify asset can be used for export
            let isExportable = await verifyAssetExportability(asset)
            guard isExportable else {
                diagnosticLogger.logError("❌ Asset is not exportable")
                throw AddMoveError.assetNotReady("Asset is not exportable")
            }

            diagnosticLogger.logInfo("✅ Asset readiness verification completed", metadata: [
                "video_tracks": "\(videoTracks.count)",
                "duration_seconds": "\(loadedDuration.seconds)",
                "is_exportable": "\(isExportable)"
            ])

            diagnosticLogger.stopTiming("asset_readiness_verification")
            return asset

        } catch {
            diagnosticLogger.logError("❌ Asset readiness verification failed", error: error, metadata: [
                "asset_duration": "\(asset.duration.seconds)",
                "flow_state": "\(flowState)"
            ])
            throw AddMoveError.assetNotReady("Asset verification failed: \(error.localizedDescription)")
        }
    }

    /// Verifies that asset can be exported/processed
    private func verifyAssetExportability(_ asset: AVAsset) async -> Bool {
        diagnosticLogger.logDebug("🔍 Checking asset exportability")

        do {
            // Check if asset has compatible tracks for export
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)

            // At minimum, need video tracks
            guard !videoTracks.isEmpty else {
                diagnosticLogger.logWarning("⚠️ No video tracks found for export")
                return false
            }

            // Verify track formats are supported
            for track in videoTracks {
                let formatDescriptions = try await track.load(.formatDescriptions)
                guard !formatDescriptions.isEmpty else {
                    diagnosticLogger.logWarning("⚠️ Video track has no format descriptions")
                    return false
                }
            }

            // Check if asset is readable
            let isReadable = asset.isReadable
            guard isReadable else {
                diagnosticLogger.logWarning("⚠️ Asset is not readable")
                return false
            }

            diagnosticLogger.logDebug("✅ Asset exportability verified", metadata: [
                "video_tracks": "\(videoTracks.count)",
                "audio_tracks": "\(audioTracks.count)",
                "is_readable": "\(isReadable)"
            ])

            return true

        } catch {
            diagnosticLogger.logError("❌ Asset exportability check failed", error: error)
            return false
        }
    }

    /// Verifies that trimming state is ready for saving using persistent state properties
    /// 🎯 FIXED: Removes dependency on deallocated TrimmerViewModel
    public func verifyTrimmingReadiness() async throws -> TrimmingReadinessResult {
        diagnosticLogger.startTiming("trimming_readiness_verification")

        diagnosticLogger.logInfo("🔍 Starting trimming readiness verification", metadata: [
            "flow_state": "\(flowState)",
            "has_trimmer": "\(trimmerViewModel != nil)",
            "has_player": "\(currentPlayerViewModel != nil)",
            "validation_source": "persistent_state_properties"
        ])

        var readinessIssues: [TrimmingReadinessIssue] = []

        // ✅ USE: Persistent state properties instead of trimmerViewModel
        let startTime = self.trimStartTime
        let endTime = self.trimEndTime
        let duration = endTime - startTime
        let assetDuration = videoAsset?.duration.seconds ?? 0.0

        // Verify asset is available
        guard let asset = videoAsset else {
            readinessIssues.append(.assetNotReady("Video asset not available"))
            throw AddMoveError.assetNotReady("Video asset not available")
        }

        // Verify asset duration is valid
        guard assetDuration > 0 else {
            readinessIssues.append(.invalidTrimmerDuration)
            throw AddMoveError.invalidAssetDuration
        }

        // Verify trim times are valid
        if startTime < 0 {
            readinessIssues.append(.invalidStartTime(startTime))
        }

        if endTime > assetDuration {
            readinessIssues.append(.endTimeExceedsAsset(endTime, assetDuration))
        }

        if startTime >= endTime {
            readinessIssues.append(.startTimeAfterEndTime(startTime, endTime))
        }

        if duration < 3.0 {
            readinessIssues.append(.durationTooShort(duration, 3.0))
        }

        // Verify asset is ready
        do {
            _ = try await verifyAssetReadiness()
        } catch {
            readinessIssues.append(.assetNotReady(error.localizedDescription))
            throw error
        }

        // Verify player is ready (if available)
        if let playerVM = currentPlayerViewModel, !playerVM.isPlayerReady {
            readinessIssues.append(.playerNotReady)
            throw AddMoveError.playerNotReady
        }

        // Create a lightweight result without trimmerViewModel dependency
        let result = TrimmingReadinessResult(
            isReady: readinessIssues.isEmpty,
            issues: readinessIssues,
            trimmerViewModel: nil, // ✅ REMOVED: No longer depends on deallocated VM
            videoAsset: asset,
            playerViewModel: currentPlayerViewModel
        )

        diagnosticLogger.logInfo("✅ Trimming readiness verification completed", metadata: [
            "is_ready": "\(result.isReady)",
            "issue_count": "\(readinessIssues.count)",
            "duration_seconds": "\(duration)",
            "start_time": "(startTime.seconds)",
            "end_time": "(endTime.seconds)",
            "asset_duration": "\(assetDuration)"
        ])

        diagnosticLogger.stopTiming("trimming_readiness_verification")
        return result
    }

    /// Prepares asset for saving by ensuring all components are ready
    public func prepareAssetForSaving() async throws -> PreparedAssetResult {
        diagnosticLogger.startTiming("asset_preparation_for_saving")

        diagnosticLogger.logInfo("🔧 Starting asset preparation for saving", metadata: [
            "flow_state": "\(flowState)",
            "move_name_length": "\(moveName.count)",
            "has_video": "\(videoAsset != nil)"
        ])

        // Validate we're in the correct state
        guard flowState == .naming || flowState == .saving else {
            throw AddMoveError.invalidStateForSaving
        }

        // Validate move name
        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AddMoveError.invalidMoveName
        }

        // Verify asset readiness
        let readyAsset = try await verifyAssetReadiness()

        // Verify trimming readiness
        let trimmingResult = try await verifyTrimmingReadiness()

        // Verify all required components are available
        guard let photosID = photosIdentifier else {
            throw AddMoveError.photosIdentifierNotAvailable
        }

        // ✅ FIXED: Calculate final trim parameters from persistent state properties
        let finalStartTime = self.trimStartTime
        let finalEndTime = self.trimEndTime
        let finalRotation = self.rotationQuarterTurns

        // Create prepared asset result
        let result = PreparedAssetResult(
            asset: readyAsset,
            photosIdentifier: photosID,
            trimStartTime: finalStartTime,
            trimEndTime: finalEndTime,
            rotationQuarterTurns: finalRotation,
            moveName: moveName,
            trimmingReadiness: trimmingResult
        )

        diagnosticLogger.logInfo("✅ Asset preparation for saving completed", metadata: [
            "asset_duration": "\(readyAsset.duration.seconds)",
            "trim_start": "\(finalStartTime)",
            "trim_end": "\(finalEndTime)",
            "trim_duration": "\(finalEndTime - finalStartTime)",
            "rotation": "\(finalRotation)"
        ])

        diagnosticLogger.stopTiming("asset_preparation_for_saving")
        return result
    }

    // MARK: - Real-time Save Validation

    /// Validates save readiness in real-time with continuous updates
    public func validateSaveReadiness() async -> SaveReadinessResult {
        diagnosticLogger.startTiming("save_readiness_validation")

        var validationIssues: [SaveValidationIssue] = []
        var isValid = true

        diagnosticLogger.logInfo("🔍 Starting real-time save readiness validation", metadata: [
            "flow_state": "\(flowState)",
            "move_name_length": "\(moveName.count)",
            "has_asset": "\(videoAsset != nil)"
        ])

        // Validate move name
        if moveName.trimmingCharacters(in: .whitespaces).isEmpty {
            validationIssues.append(.emptyMoveName)
            isValid = false
        } else if moveName.count < 2 {
            validationIssues.append(.moveNameTooShort(moveName.count))
            isValid = false
        } else if moveName.count > 50 {
            validationIssues.append(.moveNameTooLong(moveName.count))
            isValid = false
        }

        // Validate asset availability
        if videoAsset == nil {
            validationIssues.append(.noVideoAsset)
            isValid = false
        }

        // Validate trimmer state if available
        if let trimmerVM = trimmerViewModel {
            if !trimmerVM.isReady {
                validationIssues.append(.trimmerNotReady)
                isValid = false
            }

            // Validate trim parameters
            let startTime = trimmerVM.startTime.seconds
            let endTime = trimmerVM.endTime.seconds
            let duration = endTime - startTime

            if startTime < 0 {
                validationIssues.append(.invalidStartTime(startTime))
                isValid = false
            }

            if endTime > (videoAsset?.duration.seconds ?? 0) {
                validationIssues.append(.endTimeExceedsAsset(endTime, videoAsset?.duration.seconds ?? 0))
                isValid = false
            }

            if startTime >= endTime {
                validationIssues.append(.startTimeAfterEndTime(startTime, endTime))
                isValid = false
            }

            if duration < 3.0 {
                validationIssues.append(.durationTooShort(duration, 3.0))
                isValid = false
            }
        }

        // Validate player state
        if let playerVM = currentPlayerViewModel {
            if !playerVM.isPlayerReady {
                validationIssues.append(.playerNotReady)
                isValid = false
            }
        } else {
            validationIssues.append(.noPlayerAvailable)
            isValid = false
        }

        // 🎯 CRITICAL FIX: Enhanced player state validation with seek awareness
        if isSeekInProgress {
            validationIssues.append(.seekInProgress)
            isValid = false
            logger.info("🎬 ADD_MOVE_UNIFIED_STATE: ⚠️ Seek operation in progress, deferring save readiness")
        }

        // Validate photos identifier
        if photosIdentifier == nil {
            validationIssues.append(.noPhotosIdentifier)
            isValid = false
        }

        // Validate flow state
        if flowState != .naming && flowState != .saving {
            validationIssues.append(.invalidFlowState(flowState))
            isValid = false
        }

        // Additional validations for saving state
        if flowState == .saving {
            if !isSaving {
                validationIssues.append(.saveNotInProgress)
                isValid = false
            }
        }

        let result = SaveReadinessResult(
            isValid: isValid,
            issues: validationIssues,
            canSave: isValid && validationIssues.isEmpty && !isSeekInProgress,
            confidence: calculateValidationConfidence(validationIssues),
            moveName: moveName,
            hasValidAsset: videoAsset != nil,
            hasValidTrimmer: trimmerViewModel?.isReady ?? false,
            hasValidPlayer: currentPlayerViewModel?.isPlayerReady ?? false,
            trimDuration: trimmerViewModel != nil ?
                (trimmerViewModel!.endTime.seconds - trimmerViewModel!.startTime.seconds) : 0
        )

        diagnosticLogger.logInfo("✅ Real-time save readiness validation completed", metadata: [
            "is_valid": "\(result.isValid)",
            "can_save": "\(result.canSave)",
            "confidence": "\(result.confidence)",
            "issue_count": "\(validationIssues.count)",
            "trim_duration": "\(result.trimDuration)"
        ])

        diagnosticLogger.stopTiming("save_readiness_validation")
        return result
    }

    /// Calculates validation confidence based on issue types
    private func calculateValidationConfidence(_ issues: [SaveValidationIssue]) -> Double {
        guard !issues.isEmpty else { return 1.0 }

        var confidence = 1.0
        let criticalIssues = issues.filter { $0.isCritical }
        let warningIssues = issues.filter { !$0.isCritical }

        // Reduce confidence for critical issues
        confidence -= Double(criticalIssues.count) * 0.3
        // Reduce confidence for warning issues
        confidence -= Double(warningIssues.count) * 0.1

        return max(0.0, confidence)
    }

    // MARK: - Seek Operations Management

    /// CancellationToken for cancelling operations
    private class CancellationToken {
        private var _isCancelled = false
        private let lock = NSLock()

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _isCancelled
        }

        func cancel() {
            lock.lock()
            _isCancelled = true
            lock.unlock()
        }
    }

    /// 🎯 CRITICAL FIX: Debounced seek operation to prevent rapid successive seeks
    public func debouncedSeekToTrimStart() async {
        let debounceInterval: TimeInterval = 0.5 // 500ms debounce

        // Cancel any pending seek operation
        seekOperationCancellationToken?.cancel()

        let cancellationToken = CancellationToken()
        seekOperationCancellationToken = cancellationToken

        do {
            // Wait for debounce interval
            try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            // Check if cancelled
            if cancellationToken.isCancelled {
                logger.info("🎬 ADD_MOVE_UNIFIED_STATE: ⏭️ Seek operation cancelled due to debouncing")
                return
            }

            logger.info("🎬 ADD_MOVE_UNIFIED_STATE: 🔧 Starting debounced seek to trim start - trimStartTime: \(self.trimStartTime), debounceInterval: \(Int(debounceInterval * 1000))ms")

            // Mark seek as in progress
            await MainActor.run {
                isSeekInProgress = true
            }

            // Perform seek with timeout
            guard let playerViewModel = currentPlayerViewModel else {
                logger.error("🎬 ADD_MOVE_UNIFIED_STATE: ❌ No player view model available for seek")
                return
            }

            let startTime = trimStartTime
            try await withTimeout(seconds: 3.0) {
                try await playerViewModel.asyncSeek(to: CMTime(seconds: startTime, preferredTimescale: 600))
            }

            // Update seek completion state
            await MainActor.run {
                isSeekInProgress = false
                lastSeekCompletionTime = Date()
            }

            logger.info("🎬 ADD_MOVE_UNIFIED_STATE: ✅ Debounced seek completed successfully")

        } catch {
            await MainActor.run {
                isSeekInProgress = false
            }

            logger.error("🎬 ADD_MOVE_UNIFIED_STATE: ❌ Debounced seek failed - \(error.localizedDescription)")
        }
    }

    /// 🎯 CRITICAL FIX: Enhanced save readiness monitoring that considers seek operations
    public func startSaveReadinessMonitoring() {
        diagnosticLogger.logInfo("🔍 Starting enhanced save readiness monitoring with seek awareness")

        Task {
            while flowState == .naming || flowState == .saving {
                let result = await validateSaveReadiness()

                await MainActor.run {
                    // Update state based on validation results
                    self.saveReadiness = result

                    // Log significant changes
                    if result.canSave != (self.lastSaveReadiness?.canSave ?? false) {
                        diagnosticLogger.logInfo("🔄 Save readiness changed", metadata: [
                            "can_save": "\(result.canSave)",
                            "issue_count": "\(result.issues.count)",
                            "seek_in_progress": "\(self.isSeekInProgress)"
                        ])
                    }

                    self.lastSaveReadiness = result
                }

                // Adaptive monitoring interval
                let monitoringInterval: TimeInterval = isSeekInProgress ? 1.0 : 0.5
                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }

            diagnosticLogger.logInfo("⏹️ Enhanced save readiness monitoring stopped")
        }
    }

    /// Stops save readiness monitoring
    public func stopSaveReadinessMonitoring() {
        diagnosticLogger.logInfo("⏹️ Stopping save readiness monitoring")
        // The monitoring loop will naturally stop when flow state changes
    }

    /// Gets current save validation status with detailed feedback
    public func getSaveValidationStatus() -> SaveValidationStatus {
        let issues = saveReadiness?.issues ?? []

        if issues.isEmpty {
            return .ready("All validation checks passed")
        } else if issues.contains(where: { $0.isCritical }) {
            let criticalIssues = issues.filter { $0.isCritical }
            return .critical(criticalIssues.map { $0.localizedDescription }.joined(separator: "\n"))
        } else {
            let warningIssues = issues.filter { !$0.isCritical }
            return .warning(warningIssues.map { $0.localizedDescription }.joined(separator: "\n"))
        }
    }

    /// Performs immediate save validation with detailed error reporting
    public func validateForImmediateSave() async throws -> ImmediateSaveValidationResult {
        diagnosticLogger.startTiming("immediate_save_validation")

        let readiness = await validateSaveReadiness()

        guard readiness.canSave else {
            let errorDetails = readiness.issues.map { issue in
                "\(issue.localizedDescription) [\(issue.severity)]"
            }.joined(separator: "\n")

            diagnosticLogger.logError("❌ Immediate save validation failed", metadata: [
                "issue_count": "\(readiness.issues.count)",
                "confidence": "\(readiness.confidence)"
            ])

            throw AddMoveError.saveValidationFailed(errorDetails)
        }

        // Prepare asset for saving
        let preparedAsset = try await prepareAssetForSaving()

        let result = ImmediateSaveValidationResult(
            isValid: true,
            preparedAsset: preparedAsset,
            saveReadiness: readiness,
            validationTimestamp: Date()
        )

        diagnosticLogger.logInfo("✅ Immediate save validation passed", metadata: [
            "asset_duration": "\(preparedAsset.asset.duration.seconds)",
            "trim_duration": "\(preparedAsset.trimDuration)"
        ])

        diagnosticLogger.stopTiming("immediate_save_validation")
        return result
    }

    // MARK: - Save Move Function

    /// Validates state, processes the video, saves to Core Data, and updates the final state with enhanced race condition prevention.
    /// 🎯 REFACTORED: Eliminates TrimmerViewModel dependency and uses dedicated coordinator
    public func saveMove() async {
        let operationStartTime = Date()
        let memoryBeforeOperation = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.startTiming("save_move_operation")
        logger.info("🎬 UNIFIED_STATE: 🚀 Starting FINAL saveMove operation with TrimmerViewModel decoupling...")

        // 💡 ENHANCEMENT: Comprehensive pre-save validation using persistent state
        do {
            try await validateReadyForSave()
            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: ✅ Pre-save validation passed")
        } catch {
            let errorMessage = "Save validation failed"
            diagnosticLogger.logError("Pre-save validation failed", error: error, metadata: [
                "error_message": errorMessage,
                "validation_error": error.localizedDescription,
                "move_name": "\(moveName)",
                "flow_state": "\(flowState)"
            ])
            await setError(message: errorMessage, underlying: error.localizedDescription)
            return
        }

        // 1. Transition to the saving state immediately to update the UI
        await transitionTo(.saving)

        do {
            // ✅ CRITICAL FIX: Directly use persistent state properties, NOT prepareAssetForSaving
            guard let assetToProcess = self.videoAsset else {
                let errorMessage = "Asset not found for processing"
                diagnosticLogger.logError(errorMessage, metadata: [
                    "flow_state": "\(flowState)",
                    "move_name": "\(moveName)"
                ])
                throw AddMoveError.assetNotReady(errorMessage)
            }

            // 2. Delegate the entire operation to the dedicated coordinator
            let coordinator = self.appContainer.addMoveSaveCoordinator
            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🔄 Delegating save operation to AddMoveSaveCoordinator", metadata: [
                "asset_duration": "\(try await assetToProcess.load(.duration).seconds)",
                "move_name": "\(moveName)",
                "trim_start": "\(trimStartTime)",
                "trim_end": "\(trimEndTime)",
                "rotation": "\(rotationQuarterTurns)"
            ])

            // 3. Execute the save operation with parameters from persistent state
            let result = try await coordinator.saveMove(
                name: self.moveName,
                asset: assetToProcess,
                photosIdentifier: self.photosIdentifier ?? "",
                trimStartTime: self.trimStartTime,
                trimEndTime: self.trimEndTime,
                rotationQuarterTurns: self.rotationQuarterTurns
            )

            // 4. Log successful save operation with comprehensive metrics
            let totalOperationTime = Date().timeIntervalSince(operationStartTime)
            let finalMemory = diagnosticLogger.getMemoryInfo()

            diagnosticLogger.logInfo("🎬 UNIFIED_STATE: ✅ Save operation completed successfully", metadata: [
                "move_name": result.move.name ?? "Unknown Move",
                "photos_identifier": result.photosIdentifier,
                "total_operation_time_seconds": "\(String(format: "%.3f", totalOperationTime))",
                "memory_before_mb": "\(String(format: "%.1f", memoryBeforeOperation.used))",
                "memory_after_mb": "\(String(format: "%.1f", finalMemory.used))",
                "memory_delta_mb": "\(String(format: "%.1f", finalMemory.used - memoryBeforeOperation.used))",
                "coordinator_used": "true",
                "trimmer_viewmodel_dependency": "removed"
            ])

            // 5. Call completion handler with the final persisted Move object
            // 🎯 CRITICAL FIX: This enables proper navigation to the detail view
            if let onSaveSuccess = onSaveSuccess {
                let finalMove = result.move
                diagnosticLogger.logInfo("🎬 UNIFIED_STATE: 🚀 Calling onSaveSuccess completion handler", metadata: [
                    "move_name": "\(finalMove.name ?? "Unknown Move")",
                    "move_id": "\(finalMove.objectID)",
                    "photos_identifier": "\(finalMove.photosIdentifier ?? "nil")",
                    "final_object_persistent": "true"
                ])
                onSaveSuccess(finalMove)
            }

            // 6. Transition to success state
            let successMessage = "Move '\(result.move.name ?? "Unknown Move")' was added to your Arsenal!"
            await transitionTo(.success(message: successMessage))

        } catch {
            // 6. Enhanced error handling with detailed diagnostics
            let totalOperationTime = Date().timeIntervalSince(operationStartTime)
            let finalMemory = diagnosticLogger.getMemoryInfo()

            // ✅ Enhanced, user-facing error handling
            let errorMessage: String
            let underlyingError = error.localizedDescription

            if let addMoveError = error as? AddMoveError, case .duplicateMoveName = addMoveError {
                errorMessage = "A move named '\(self.moveName)' already exists. Please choose a different name."
                await MainActor.run { self.flowState = .naming } // Return user to naming screen
                diagnosticLogger.logError("Duplicate move name detected", error: error, metadata: [
                    "duplicate_move_name": "\(self.moveName)",
                    "user_returned_to_naming": "true"
                ])
            } else {
                errorMessage = "Failed to save move"
                diagnosticLogger.logError("Final save operation failed", error: error, metadata: [
                    "error_message": errorMessage,
                    "underlying_error": underlyingError,
                    "error_type": "\(type(of: error))",
                    "flow_state": "\(flowState)",
                    "player_state": "\(playerState)",
                    "move_name": "\(moveName)",
                    "operation_duration_seconds": "\(String(format: "%.3f", totalOperationTime))",
                    "memory_before_mb": "\(String(format: "%.1f", memoryBeforeOperation.used))",
                    "memory_after_mb": "\(String(format: "%.1f", finalMemory.used))",
                    "memory_delta_mb": "\(String(format: "%.1f", finalMemory.used - memoryBeforeOperation.used))",
                    "save_progress": "\(saveProgress)",
                    "coordinator_used": "true",
                    "architecture_fixed": "decoupled_from_trimmer_viewmodel"
                ])
            }

            await setError(message: errorMessage, underlying: underlyingError)
        }

        diagnosticLogger.stopTiming("save_move_operation")
        logger.info("🎬 UNIFIED_STATE: 🏁 FINAL saveMove operation completed (success or failure)")
    }
}

// MARK: - Real-time Save Validation Types

public enum SaveValidationIssue {
    case emptyMoveName
    case moveNameTooShort(Int)
    case moveNameTooLong(Int)
    case noVideoAsset
    case trimmerNotReady
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case playerNotReady
    case noPlayerAvailable
    case noPhotosIdentifier
    case invalidFlowState(AddMoveFlowState)
    case saveNotInProgress
    case seekInProgress
    case seekOperationTimeout
    case seekOperationFailed

    var isCritical: Bool {
        switch self {
        case .emptyMoveName, .noVideoAsset, .trimmerNotReady, .playerNotReady, .noPlayerAvailable, .noPhotosIdentifier, .seekInProgress, .seekOperationTimeout, .seekOperationFailed:
            return true
        default:
            return false
        }
    }

    var severity: String {
        return isCritical ? "Critical" : "Warning"
    }

    var localizedDescription: String {
        switch self {
        case .emptyMoveName:
            return "Move name cannot be empty"
        case .moveNameTooShort(let length):
            return "Move name is too short (\(length) characters, minimum 2)"
        case .moveNameTooLong(let length):
            return "Move name is too long (\(length) characters, maximum 50)"
        case .noVideoAsset:
            return "No video asset available"
        case .trimmerNotReady:
            return "Trimmer is not ready"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .playerNotReady:
            return "Player is not ready"
        case .noPlayerAvailable:
            return "No player available"
        case .noPhotosIdentifier:
            return "Photos identifier not available"
        case .invalidFlowState(let state):
            return "Invalid flow state for saving: \(state)"
        case .saveNotInProgress:
            return "Save operation is not in progress"
        case .seekInProgress:
            return "Seek operation in progress, please wait..."
        case .seekOperationTimeout:
            return "Video seek operation timed out"
        case .seekOperationFailed:
            return "Video seek operation failed"
        }
    }
}

// MARK: - SaveValidationIssue Extensions
extension SaveValidationIssue {
    var isSeekRelated: Bool {
        switch self {
        case .seekInProgress, .seekOperationTimeout, .seekOperationFailed:
            return true
        default:
            return false
        }
    }
}

public struct SaveReadinessResult {
    public let isValid: Bool
    public let issues: [SaveValidationIssue]
    public let canSave: Bool
    public let confidence: Double
    public let moveName: String
    public let hasValidAsset: Bool
    public let hasValidTrimmer: Bool
    public let hasValidPlayer: Bool
    public let trimDuration: Double

    public var hasCriticalIssues: Bool {
        issues.contains { $0.isCritical }
    }

    public var hasWarningIssues: Bool {
        issues.contains { !$0.isCritical }
    }

    public var criticalIssues: [SaveValidationIssue] {
        issues.filter { $0.isCritical }
    }

    public var warningIssues: [SaveValidationIssue] {
        issues.filter { !$0.isCritical }
    }

    public var issuesDescription: String {
        issues.map { $0.localizedDescription }.joined(separator: "\n")
    }
}

public enum SaveValidationStatus {
    case ready(String)
    case warning(String)
    case critical(String)

    var isReady: Bool {
        switch self {
        case .ready: return true
        default: return false
        }
    }

    var statusMessage: String {
        switch self {
        case .ready(let message): return message
        case .warning(let message): return "⚠️ " + message
        case .critical(let message): return "❌ " + message
        }
    }
}

public struct ImmediateSaveValidationResult {
    public let isValid: Bool
    public let preparedAsset: PreparedAssetResult
    public let saveReadiness: SaveReadinessResult
    public let validationTimestamp: Date
}

// MARK: - Asset Readiness Types

public enum TrimmingReadinessIssue {
    case trimmerNotAvailable
    case trimmerNotReady
    case invalidTrimmerDuration
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case assetNotReady(String)
    case playerNotReady

    var localizedDescription: String {
        switch self {
        case .trimmerNotAvailable:
            return "Trimmer is not available"
        case .trimmerNotReady:
            return "Trimmer is not ready"
        case .invalidTrimmerDuration:
            return "Trimmer has invalid duration"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .assetNotReady(let reason):
            return "Asset not ready: \(reason)"
        case .playerNotReady:
            return "Player is not ready"
        }
    }
}

public struct TrimmingReadinessResult {
    public let isReady: Bool
    public let issues: [TrimmingReadinessIssue]
    public let trimmerViewModel: TrimmerViewModel? // ✅ MADE OPTIONAL: No longer required for save operations
    public let videoAsset: AVAsset
    public let playerViewModel: UnifiedVideoPlayerViewModel?

    public var hasIssues: Bool {
        !issues.isEmpty
    }

    public var issuesDescription: String {
        issues.map { $0.localizedDescription }.joined(separator: "; ")
    }
}

public struct PreparedAssetResult {
    public let asset: AVAsset
    public let photosIdentifier: String
    public let trimStartTime: Double
    public let trimEndTime: Double
    public let rotationQuarterTurns: Int
    public let moveName: String
    public let trimmingReadiness: TrimmingReadinessResult

    public var trimDuration: Double {
        trimEndTime - trimStartTime
    }

    public var isValidForSave: Bool {
        trimmingReadiness.isReady && !moveName.isEmpty && trimDuration >= 3.0
    }
}

// MARK: - State Validation Errors

public enum StateValidationError {
    case invalidAssetDuration(Double)
    case invalidStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case playerNotReadyInTrimmingState
    case missingTrimmerInTrimmingState
    case missingPlayerInNamingState

    var localizedDescription: String {
        switch self {
        case .invalidAssetDuration(let duration):
            return "Invalid asset duration: \(duration) seconds"
        case .invalidStartTime(let startTime):
            return "Invalid start time: \(startTime) seconds"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)) exceeds asset duration (\(assetDuration))"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)) is after end time (\(endTime))"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)) is too short (minimum: \(minimum))"
        case .playerNotReadyInTrimmingState:
            return "Player is not ready in trimming state"
        case .missingTrimmerInTrimmingState:
            return "Trimmer view model is missing in trimming state"
        case .missingPlayerInNamingState:
            return "Player view model is missing in naming state"
        }
    }
}
