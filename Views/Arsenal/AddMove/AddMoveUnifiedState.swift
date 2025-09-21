import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import OSLog

// MARK: - Unified Flow State
/// Simplified flow state that eliminates the dual state system complexity
public enum AddMoveFlowState: Equatable, Hashable, Sendable {
    case ready
    case loading(progress: Double, status: String)
    case previewing
    case trimming
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
        case .trimming: return 0.5
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

// MARK: - Add Move Unified State
/// Single source of truth for the entire Add Move flow
/// Eliminates State Object Churn by centralizing all state and persistent services
@MainActor
public class AddMoveUnifiedState: ObservableObject {
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "AddMoveUnifiedState")
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveUnifiedState")
    
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
    
    // MARK: - Persistent Services
    /// Shared player manager that persists across view transitions
    public let unifiedPlayerManager: UnifiedPlayerManager
    
    /// Health monitor for video processing
    public let healthMonitor: VideoHealthMonitorImpl
    
    /// Memory manager for resource optimization
    public let memoryManager: MemoryManagerImpl
    
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
        case .trimming:
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
        healthMonitor: VideoHealthMonitorImpl? = nil,
        memoryManager: MemoryManagerImpl = MemoryManagerImpl(),
        appContainer: AppContainer = AppContainer.shared
    ) {
        diagnosticLogger.startTiming("unified_state_initialization")
        
        self.unifiedPlayerManager = unifiedPlayerManager
        self.healthMonitor = healthMonitor ?? VideoHealthMonitorImpl(memoryManager: memoryManager)
        self.memoryManager = memoryManager
        self.appContainer = appContainer
        
        let memoryInfo = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("🎬 UNIFIED_STATE: Initialized with persistent services", metadata: [
            "initial_flow_state": "\(flowState)",
            "initial_player_state": "\(playerState)",
            "memory_usage_mb": "\(String(format: "%.1f", memoryInfo.used))",
            "memory_percent": "\(String(format: "%.1f", memoryInfo.percentage))",
            "health_monitor_active": "\(healthMonitor != nil)"
        ])
        
        diagnosticLogger.stopTiming("unified_state_initialization")
    }
    
    // MARK: - State Management
    
    /// Transitions to a new flow state
    public func transitionTo(_ newState: AddMoveFlowState) {
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
            
                    
        case .trimming:
            playerState = .paused
            isTrimmingActive = true
            currentPlayerViewModel?.pauseForTrimming()
            setupTrimmerViewModel()
            diagnosticLogger.logInfo("🔄 Transitioned to trimming state", metadata: [
                "trimmer_vm_created": "\(trimmerViewModel != nil)",
                "trim_range": "\(trimStartTime)-\(trimEndTime)"
            ])
            
        case .naming:
            playerState = .paused
            isTrimmingActive = false
            cleanupTrimmerViewModel()
            diagnosticLogger.logInfo("🔄 Transitioned to naming state", metadata: [
                "move_name_length": "\(moveName.count)",
                "trimmer_vm_cleaned": "true"
            ])
            
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
            setError(message: message, underlying: underlying)
            
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
    
    
    /// Applies trim settings to the current video
    public func applyTrimSettings(startTime: Double, endTime: Double, rotation: Int) async throws {
        diagnosticLogger.startTiming("apply_trim_settings")
        
        guard let asset = videoAsset else {
            diagnosticLogger.logError("Cannot apply trim settings - no video asset available")
            throw AddMoveError.videoLoadFailed(underlyingError: nil)
        }
        
        let oldStartTime = trimStartTime
        let oldEndTime = trimEndTime
        let oldRotation = rotationQuarterTurns
        
        trimStartTime = startTime
        trimEndTime = endTime
        rotationQuarterTurns = rotation
        
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        
        diagnosticLogger.logInfo("🔄 Applying trim settings", metadata: [
            "old_range": "\(oldStartTime)-\(oldEndTime)",
            "new_range": "\(startTime)-\(endTime)",
            "old_rotation": "\(oldRotation)",
            "new_rotation": "\(rotation)",
            "duration_seconds": "\(endTime - startTime)",
            "asset_duration": "\(asset.duration.seconds)"
        ])
        
        // Synchronize TrimmerViewModel state with UnifiedState BEFORE applying trim
        if let trimmerVM = trimmerViewModel {
            await MainActor.run {
                trimmerVM.rotationQuarterTurns = rotation
                trimmerVM.startTime = startCMTime
                trimmerVM.endTime = endCMTime
                logger.info("🎬 UNIFIED_STATE: 🔄 Synchronized TrimmerViewModel with UnifiedState")
            }
            diagnosticLogger.logDebug("✅ TrimmerViewModel synchronized successfully")
        } else {
            diagnosticLogger.logWarning("⚠️ TrimmerViewModel not available for synchronization")
        }
        
        do {
            try await unifiedPlayerManager.applyTrimToCurrentPlayer(
                startTime: startCMTime,
                endTime: endCMTime,
                rotation: rotation
            )
            diagnosticLogger.logInfo("✅ Trim settings applied successfully to player")
        } catch {
            diagnosticLogger.logError("Failed to apply trim settings to player", error: error)
            throw error
        }
        
        logger.info("🎬 UNIFIED_STATE: ✅ Trim settings applied")
        diagnosticLogger.stopTiming("apply_trim_settings")
    }
    
    /// Sets error state
    public func setError(message: String, underlying: String? = nil) {
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
            transitionTo(.error(message: message, underlyingError: underlying))
        }
        
        logger.error("🎬 UNIFIED_STATE: ❌ Error set - \(message)")
    }
    
    /// Clears error state
    public func clearError() {
        let hadError = errorMessage != nil
        
        errorMessage = nil
        underlyingError = nil
        
        diagnosticLogger.logInfo("Clearing error state", metadata: [
            "had_error": "\(hadError)",
            "current_flow_state": "\(flowState)",
            "current_player_state": "\(playerState)"
        ])
        
        if case .error = flowState {
            transitionTo(.ready)
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
        
        // Cleanup player manager
        unifiedPlayerManager.cleanup()
        diagnosticLogger.logDebug("🧹 Player manager cleaned up")
        
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

        // 🎯 CRITICAL FIX: Coordinate health monitor lifecycle during video loading
        // This prevents multiple start/stop cycles seen in logs
        healthMonitor.pauseMonitoring()
        logger.info("🎬 UNIFIED_STATE: 🏥 Health monitor paused for video loading")

        let assetPreparer = VideoAssetPreparer(videoLoader: AddMoveVideoLoader())
        
        do {
            // Update progress as VideoAssetPreparer handles loading
            updateProgress(0.1, status: "Preparing video import...")
            diagnosticLogger.logDebug("📥 Video import preparation started")
            
            // The preparer handles everything: loading, player creation, and readiness.
            let result = try await assetPreparer.prepareVideo(from: item)
            
            updateProgress(0.8, status: "Finalizing video setup...")
            diagnosticLogger.logDebug("⚙️ Video asset preparation completed")
            
            // Update the state with the prepared results.
            self.videoAsset = result.asset
            self.photosIdentifier = result.photosIdentifier
            
            // ✅ CRITICAL FIX: Update the UnifiedPlayerManager's internal state
            // This ensures rotation/trim operations can find the asset
            self.unifiedPlayerManager.updateAsset(result.asset, photosIdentifier: result.photosIdentifier)
            
            // The player is already created and ready, just set it in the manager.
            if let playerVM = result.playerViewModel as? UnifiedVideoPlayerViewModel {
                self.unifiedPlayerManager.setPlayer(playerVM)
                diagnosticLogger.logDebug("✅ Player view model set in manager")
            }
            
            // Set initial trim range to the full video duration.
            let assetDuration = try await result.asset.load(.duration).seconds
            self.trimStartTime = 0.0
            self.trimEndTime = assetDuration
            
            diagnosticLogger.logInfo("📹 Video loading completed successfully", metadata: [
                "asset_duration_seconds": "\(assetDuration)",
                "player_ready": "\(result.playerViewModel.isPlayerReady)",
                "photos_identifier": "\(result.photosIdentifier ?? "none")"
            ])
            
            // 🎯 CRITICAL FIX: Validate state before transitioning to trimming
            // This prevents premature transition before async operations complete
            guard self.currentPlayerViewModel != nil &&
                  self.videoAsset != nil &&
                  self.photosIdentifier != nil else {
                logger.error("🎬 UNIFIED_STATE: ❌ Cannot transition to trimming - missing required components")
                self.setError(message: "Video not properly loaded for trimming", underlying: "Missing player, asset, or photos identifier")
                return
            }

            // 🎯 CRITICAL FIX: Resume health monitoring after successful video loading
            healthMonitor.resumeMonitoring()
            logger.info("🎬 UNIFIED_STATE: 🏥 Health monitor resumed after video loading")

            // Transition to the final state
            self.transitionTo(.trimming)
            logger.info("🎬 UNIFIED_STATE: ✅ Video preparation complete. Transitioning to trimming.")

            let endMemory = diagnosticLogger.getMemoryInfo()
            diagnosticLogger.logInfo("📊 Video loading performance", metadata: [
                "memory_before_mb": "\(String(format: "%.1f", startMemory.used))",
                "memory_after_mb": "\(String(format: "%.1f", endMemory.used))",
                "memory_increase_mb": "\(String(format: "%.1f", endMemory.used - startMemory.used))"
            ])
            
        } catch {
            // 🎯 CRITICAL FIX: Ensure health monitor is resumed even in error case
            healthMonitor.resumeMonitoring()
            logger.error("🎬 UNIFIED_STATE: 🏥 Health monitor resumed after error")

            diagnosticLogger.logError("Video loading failed", error: error, metadata: [
                "flow_state": "\(flowState)",
                "item_type": "\(type(of: item))",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            logger.error("🎬 UNIFIED_STATE: ❌ VideoAssetPreparer failed: \(error.localizedDescription)")
            self.setError(message: "Failed to prepare video", underlying: error.localizedDescription)
        }
        
        diagnosticLogger.stopTiming("video_loading")
    }
    
    // MARK: - Trimmer ViewModel Management
    
    /// Sets up the TrimmerViewModel when transitioning to trimming state
    private func setupTrimmerViewModel() {
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

        // 🎯 CRITICAL FIX: Pass photosIdentifier to TrimmerViewModel to maintain context
        let newTrimmerViewModel = TrimmerViewModel(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns,
            playerViewModel: playerViewModel
        )
        
        // Set initial trim values from unified state
        let startTime = CMTime(seconds: trimStartTime, preferredTimescale: 600)
        let endTime = CMTime(seconds: trimEndTime, preferredTimescale: 600)
        newTrimmerViewModel.startTime = startTime
        newTrimmerViewModel.endTime = endTime
        
        self.trimmerViewModel = newTrimmerViewModel
        
        diagnosticLogger.logInfo("✅ TrimmerViewModel setup completed", metadata: [
            "initial_start_time": "\(startTime.seconds)",
            "initial_end_time": "\(endTime.seconds)",
            "duration_seconds": "\(endTime.seconds - startTime.seconds)",
            "rotation_quarter_turns": "\(rotationQuarterTurns)"
        ])
        
        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel setup completed")
        diagnosticLogger.stopTiming("trimmer_vm_setup")
    }
    
    /// Cleans up the TrimmerViewModel when transitioning away from trimming state
    private func cleanupTrimmerViewModel() {
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
            
            trimStartTime = finalStartTime
            trimEndTime = finalEndTime
            rotationQuarterTurns = finalRotation
            
            diagnosticLogger.logInfo("🔄 Syncing final trim values before cleanup", metadata: [
                "final_start_time": "\(finalStartTime)",
                "final_end_time": "\(finalEndTime)",
                "final_rotation": "\(finalRotation)",
                "final_duration": "\(finalEndTime - finalStartTime)"
            ])
        }
        
        self.trimmerViewModel = nil
        
        diagnosticLogger.logInfo("✅ TrimmerViewModel cleanup completed")
        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel cleanup completed")
        diagnosticLogger.stopTiming("trimmer_vm_cleanup")
    }
    
    // MARK: - Validation
    
    /// Validates current state for the desired transition
    public func canTransitionTo(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .trimming:
            return hasVideo && currentPlayerViewModel != nil
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
        Task { @MainActor in
            diagnosticLogger.startTiming("unified_state_deinitialization")

            let finalMemory = diagnosticLogger.getMemoryInfo()
            let activeTimersCount = diagnosticLogger.getActiveTimersCount()

            diagnosticLogger.logInfo("🗑️ AddMoveUnifiedState deinitializing", metadata: [
                "flow_state": "\(flowState)",
                "player_state": "\(playerState)",
                "video_asset_present": "\(videoAsset != nil)",
                "memory_usage_mb": "\(String(format: "%.1f", finalMemory.used))",
                "active_timers_count": "\(activeTimersCount)",
                "active_timers": "\(diagnosticLogger.getActiveTimerNames())"
            ])

            logger.info("🎬 UNIFIED_STATE: Deinitializing - cleaning up resources")
            healthMonitor.stopMonitoring()

            unifiedPlayerManager.cleanup()
            diagnosticLogger.logPerformanceSummary()
            diagnosticLogger.stopTiming("unified_state_deinitialization")
        }
    }
}

// MARK: - Convenience Extensions
extension AddMoveUnifiedState {
    
    /// Convenience method to transition to loading state
    public func startLoading(status: String = "Loading...") {
        transitionTo(.loading(progress: 0.0, status: status))
    }
    
    /// Convenience method to update loading progress
    public func updateProgress(_ progress: Double, status: String? = nil) {
        let currentStatus = status ?? loadingStatus
        updateLoadingProgress(progress, status: currentStatus)
    }
    
    
    /// Convenience method to handle video selection
    public func didSelectVideo(_ item: PhotosPickerItem) {
        selectedVideoItem = item
        startLoading(status: "Preparing to load video...")
        
        logger.info("🎬 UNIFIED_STATE: Video selection detected, starting loading task")
        
        // Start the video loading task
        Task {
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
            transitionTo(.naming)

        case .naming:
            transitionTo(.saving)
            
        default:
            logger.error("🎬 UNIFIED_STATE: Cannot proceed from current state: \(String(describing: self.flowState))")
        }
    }
}
