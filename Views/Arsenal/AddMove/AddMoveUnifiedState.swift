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
        case .previewing: return 0.4
        case .trimming: return 0.6
        case .naming: return 0.8
        case .saving: return 0.95
        case .success: return 1.0
        case .error: return 0.0
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
    
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveUnifiedState")
    
    // MARK: - Core Flow State
    @Published
    public var flowState: AddMoveFlowState = .ready {
        didSet {
            let newFlowState = flowState
            logger.info("🎬 UNIFIED_STATE: Flow state changed from \(String(describing: oldValue)) to \(String(describing: newFlowState))")
            onFlowStateChange?(oldValue, flowState)
        }
    }
    
    @Published
    public var playerState: PlayerState = .idle {
        didSet {
            let newPlayerState = playerState
            logger.info("🎬 UNIFIED_STATE: Player state changed from \(String(describing: oldValue)) to \(String(describing: newPlayerState))")
        }
    }
    
    // MARK: - Video Asset State
    @Published
    public var videoAsset: AVAsset? {
        didSet {
            logger.info("🎬 UNIFIED_STATE: Video asset updated - \(self.videoAsset != nil ? "available" : "nil")")
        }
    }
    
    @Published
    public var photosIdentifier: String? {
        didSet {
            logger.info("🎬 UNIFIED_STATE: Photos identifier updated - \(self.photosIdentifier ?? "nil")")
        }
    }
    
    @Published
    public var selectedVideoItem: PhotosPickerItem? {
        didSet {
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
        self.unifiedPlayerManager = unifiedPlayerManager
        self.healthMonitor = healthMonitor ?? VideoHealthMonitorImpl(memoryManager: memoryManager)
        self.memoryManager = memoryManager
        self.appContainer = appContainer
        
        logger.info("🎬 UNIFIED_STATE: Initialized with persistent services")
    }
    
    // MARK: - State Management
    
    /// Transitions to a new flow state
    public func transitionTo(_ newState: AddMoveFlowState) {
        guard flowState != newState else { return }
        
        let oldState = flowState
        flowState = newState
        
        // Handle state-specific actions
        switch newState {
        case .loading(let progress, let status):
            loadingProgress = progress
            loadingStatus = status
            playerState = .loading
            
        case .previewing:
            playerState = .ready
            
        case .trimming:
            playerState = .paused
            isTrimmingActive = true
            setupTrimmerViewModel()
            
        case .naming:
            playerState = .paused
            isTrimmingActive = false
            cleanupTrimmerViewModel()
            
        case .saving:
            isSaving = true
            saveProgress = 0.0
            
        case .success(let message):
            logger.info("🎬 UNIFIED_STATE: Flow completed successfully - \(message)")
            
        case .error(let message, let underlying):
            setError(message: message, underlying: underlying)
            
        default:
            break
        }
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
        guard let asset = videoAsset else {
            throw AddMoveError.videoLoadFailed(underlyingError: nil)
        }
        
        trimStartTime = startTime
        trimEndTime = endTime
        rotationQuarterTurns = rotation
        
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        
        try await unifiedPlayerManager.applyTrimToCurrentPlayer(
            startTime: startCMTime,
            endTime: endCMTime,
            rotation: rotation
        )
        
        logger.info("🎬 UNIFIED_STATE: ✅ Trim settings applied")
    }
    
    /// Sets error state
    public func setError(message: String, underlying: String? = nil) {
        errorMessage = message
        underlyingError = underlying
        playerState = .error(message)
        
        if case .error = flowState {
            // Already in error state, just update the message
        } else {
            transitionTo(.error(message: message, underlyingError: underlying))
        }
        
        logger.error("🎬 UNIFIED_STATE: ❌ Error set - \(message)")
    }
    
    /// Clears error state
    public func clearError() {
        errorMessage = nil
        underlyingError = nil
        
        if case .error = flowState {
            transitionTo(.ready)
        }
        
        if case .error = playerState {
            playerState = .idle
        }
        
        logger.info("🎬 UNIFIED_STATE: ✅ Error cleared")
    }
    
    /// Resets all state to initial values
    public func reset() {
        logger.info("🎬 UNIFIED_STATE: Resetting all state")
        
        // Stop health monitoring
        healthMonitor.stopMonitoring()
        
        // Cleanup player manager
        unifiedPlayerManager.cleanup()
        
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
        
        logger.info("🎬 UNIFIED_STATE: ✅ Reset completed")
    }
    
    /// Prepares for view transition (pauses monitoring, preserves state)
    public func prepareForTransition() {
        logger.info("🎬 UNIFIED_STATE: Preparing for transition")
        
        unifiedPlayerManager.prepareForTransition()
        healthMonitor.pauseMonitoring()
    }
    
    /// Completes view transition (resumes monitoring)
    public func completeTransition() {
        logger.info("🎬 UNIFIED_STATE: Completing transition")
        
        unifiedPlayerManager.completeTransition()
        healthMonitor.resumeMonitoring()
    }
    
    // MARK: - Video Loading
    
    /// Loads video asset from PhotosPicker item and sets up the player
    private func loadVideo(from item: PhotosPickerItem) async {
        logger.info("🎬 UNIFIED_STATE: Loading video asset using VideoAssetPreparer")
        
        let assetPreparer = VideoAssetPreparer(videoLoader: AddMoveVideoLoader())

        do {
            // Update progress as VideoAssetPreparer handles loading
            updateProgress(0.1, status: "Preparing video import...")
            
            // The preparer handles everything: loading, player creation, and readiness.
            let result = try await assetPreparer.prepareVideo(from: item)
            
            updateProgress(0.8, status: "Finalizing video setup...")
            
            // Update the state with the prepared results.
            self.videoAsset = result.asset
            self.photosIdentifier = result.photosIdentifier
            
            // The player is already created and ready, just set it in the manager.
            if let playerVM = result.playerViewModel as? UnifiedVideoPlayerViewModel {
                self.unifiedPlayerManager.setPlayer(playerVM)
            }
            
            // Set initial trim range to the full video duration.
            self.trimStartTime = 0.0
            self.trimEndTime = try await result.asset.load(.duration).seconds
            
            // Transition to the final state.
            self.transitionTo(.previewing)
            logger.info("🎬 UNIFIED_STATE: ✅ Video preparation complete. Transitioning to previewing.")

        } catch {
            logger.error("🎬 UNIFIED_STATE: ❌ VideoAssetPreparer failed: \(error.localizedDescription)")
            self.setError(message: "Failed to prepare video", underlying: error.localizedDescription)
        }
    }
    
    // MARK: - Trimmer ViewModel Management
    
    /// Sets up the TrimmerViewModel when transitioning to trimming state
    private func setupTrimmerViewModel() {
        guard trimmerViewModel == nil,
              let asset = videoAsset,
              let playerViewModel = currentPlayerViewModel else {
            logger.info("🎬 UNIFIED_STATE: TrimmerViewModel already exists or missing required components")
            return
        }
        
        logger.info("🎬 UNIFIED_STATE: Setting up TrimmerViewModel")
        
        let newTrimmerViewModel = TrimmerViewModel(
            asset: asset,
            rotationQuarterTurns: rotationQuarterTurns,
            playerViewModel: playerViewModel
        )
        
        // Set initial trim values from unified state
        newTrimmerViewModel.startTime = CMTime(seconds: trimStartTime, preferredTimescale: 600)
        newTrimmerViewModel.endTime = CMTime(seconds: trimEndTime, preferredTimescale: 600)
        
        self.trimmerViewModel = newTrimmerViewModel
        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel setup completed")
    }
    
    /// Cleans up the TrimmerViewModel when transitioning away from trimming state
    private func cleanupTrimmerViewModel() {
        guard trimmerViewModel != nil else { return }
        
        logger.info("🎬 UNIFIED_STATE: Cleaning up TrimmerViewModel")
        
        // Sync final trim values back to unified state before cleanup
        if let trimmerViewModel = trimmerViewModel {
            trimStartTime = trimmerViewModel.startTime.seconds
            trimEndTime = trimmerViewModel.endTime.seconds
            rotationQuarterTurns = trimmerViewModel.rotationQuarterTurns
        }
        
        self.trimmerViewModel = nil
        logger.info("🎬 UNIFIED_STATE: ✅ TrimmerViewModel cleanup completed")
    }
    
    // MARK: - Validation
    
    /// Validates current state for the desired transition
    public func canTransitionTo(_ state: AddMoveFlowState) -> Bool {
        switch state {
        case .previewing:
            return hasVideo && currentPlayerViewModel != nil
        case .trimming:
            return flowState == .previewing && currentPlayerViewModel != nil
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
        """
        AddMoveUnifiedState Debug:
        - Flow State: \(flowState)
        - Player State: \(playerState)
        - Video Asset: \(videoAsset != nil ? "Available" : "Nil")
        - Photos ID: \(photosIdentifier ?? "Nil")
        - Player Ready: \(currentPlayerViewModel != nil)
        - Health Monitor Active: \(healthMonitor.getCurrentHealth().description)
        - Memory: \(memoryManager.getUsedMemory() / (1024*1024))MB used
        """
    }
    
    deinit {
        logger.info("🎬 UNIFIED_STATE: Deinitializing - cleaning up resources")
        healthMonitor.stopMonitoring()
        Task { @MainActor in
            unifiedPlayerManager.cleanup()
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
            
        case .previewing:
            transitionTo(.trimming)
            
        case .trimming:
            transitionTo(.naming)
            
        case .naming:
            transitionTo(.saving)
            
        default:
            logger.error("🎬 UNIFIED_STATE: Cannot proceed from current state: \(String(describing: self.flowState))")
        }
    }
}