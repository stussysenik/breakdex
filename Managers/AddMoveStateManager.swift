import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - AddMoveStateManager Protocol
@MainActor
public protocol AddMoveStateManagerProtocol {
    var currentState: AddMoveState { get }
    var statePublisher: Published<AddMoveState>.Publisher { get }
    
    func transition(to state: AddMoveState)
    func reset()
    func getStateDescription(_ state: AddMoveState) -> String
    
    // Convenience state transition methods
    func transitionToTrimming(
        playerViewModel: UnifiedVideoPlayerViewModel,
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    )
    func transitionToTrimming(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    func transitionToPreviewing(playerViewModel: any VideoPlayerViewModelProtocol, asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    
    // Debug properties
    var currentStateDescription: String { get }
}

// MARK: - AddMove State Manager
@MainActor
class AddMoveStateManager: AddMoveStateManagerProtocol, ObservableObject {
    
    // MARK: - Properties
    @Published var currentState: AddMoveState = .ready {
        didSet {
            logStateTransition(from: oldValue, to: currentState)
        }
    }
    
    var statePublisher: Published<AddMoveState>.Publisher { $currentState }
    
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveStateManager")
    
    // MARK: - Initialization
    init() {
        logger.info("🔄 STATE_MANAGER: Initialized with ready state")
    }
    
    // MARK: - Public API
    
    /// Transition to a new state
    func transition(to state: AddMoveState) {
        logger.info("🔄 STATE_MANAGER: Manual transition requested")
        logger.info("🔄 STATE_MANAGER: From: \(self.getStateDescription(self.currentState))")
        logger.info("🔄 STATE_MANAGER: To: \(self.getStateDescription(state))")
        
        currentState = state
        logger.info("🔄 STATE_MANAGER: ✅ Transition completed")
    }
    
    /// Reset to initial state
    func reset() {
        logger.info("🔄 STATE_MANAGER: Reset requested")
        logger.info("🔄 STATE_MANAGER: Current state: \(self.getStateDescription(self.currentState))")
        
        currentState = .ready
        logger.info("🔄 STATE_MANAGER: ✅ State reset to ready")
    }
    
    /// Get description of state for logging
    func getStateDescription(_ state: AddMoveState) -> String {
        switch state {
        case .ready:
            return "ready"
        case .loading(let progress, let status):
            return "loading(\(progress), \(status))"
        case .initializing(let progress, let status):
            return "initializing(\(progress), \(status))"
        case .loaded(_, let id, _):
            return "loaded(id: \(id ?? "nil"), rotation: 0°)"
        case .previewing(_, _, let id, let rotation):
            return "previewing(id: \(id ?? "nil"), rotation: \(rotation)°)"
        case .selectingVideo(let asset):
            return "selectingVideo(asset: \(asset != nil ? "exists" : "nil"))"
        case .trimming(_, _, let id, let rotation):
            return "trimming(id: \(id ?? "nil"), rotation: \(rotation)°)"
        case .exporting(let progress, let status):
            return "exporting(\(progress), \(status))"
        case .naming(let id, _, let start, let end, let rotation, _):
            return "naming(id: \(id), start: \(start ?? -1), end: \(end ?? -1), rotation: \(rotation)°)"
        case .saving:
            return "saving"
        case .success(let message):
            return "success(\(message))"
        case .error(let message, let underlying):
            return "error(\(message), underlying: \(underlying ?? "nil"))"
        }
    }
    
    // MARK: - Convenience State Transitions
    
    /// Transition to loading state
    func transitionToLoading(progress: Double, status: String) {
        logger.info("🔄 STATE_MANAGER: Transitioning to loading state")
        logger.info("🔄 STATE_MANAGER: Progress: \(progress), Status: \(status)")
        currentState = .loading(progress: progress, status: status)
    }
    
    /// Transition to initializing state
    func transitionToInitializing(progress: Double, status: String) {
        logger.info("🔄 STATE_MANAGER: Transitioning to initializing state")
        logger.info("🔄 STATE_MANAGER: Progress: \(progress), Status: \(status)")
        currentState = .initializing(progress: progress, status: status)
    }
    
    /// Transition to previewing state
    func transitionToPreviewing(
        playerViewModel: any VideoPlayerViewModelProtocol,
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) {
        logger.info("🔄 STATE_MANAGER: Transitioning to previewing state")
        logger.info("🔄 STATE_MANAGER: Photos ID: \(photosIdentifier ?? "nil")")
        logger.info("🔄 STATE_MANAGER: Rotation: \(rotationQuarterTurns)°")
        currentState = .previewing(
            playerViewModel: UnifiedVideoPlayerViewModel(
                player: AVPlayer(playerItem: AVPlayerItem(asset: asset)),
                mode: .preview,
                appContainer: AppContainer.shared
            ),
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Transition to trimming state
    func transitionToTrimming(
        playerViewModel: UnifiedVideoPlayerViewModel,
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) {
        logger.info("🔄 STATE_MANAGER: Transitioning to trimming state")
        logger.info("🔄 STATE_MANAGER: Photos ID: \(photosIdentifier ?? "nil")")
        logger.info("🔄 STATE_MANAGER: Rotation: \(rotationQuarterTurns)°")
        currentState = .trimming(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Legacy transition to trimming state (for backward compatibility)
    func transitionToTrimming(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) {
        logger.info("🔄 STATE_MANAGER: Legacy transition to trimming state")
        logger.info("🔄 STATE_MANAGER: Photos ID: \(photosIdentifier ?? "nil")")
        logger.info("🔄 STATE_MANAGER: Rotation: \(rotationQuarterTurns)°")
        
        // Apply the same fix as loadVideo - create player immediately to avoid deadlock
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: AppContainer.shared
        )
        
        currentState = .trimming(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Transition to naming state
    func transitionToNaming(
        photosIdentifier: String,
        originalAsset: AVAsset,
        trimStartTime: Double,
        trimEndTime: Double,
        rotationQuarterTurns: Int
    ) {
        logger.info("🔄 STATE_MANAGER: Transitioning to naming state")
        logger.info("🔄 STATE_MANAGER: Photos ID: \(photosIdentifier)")
        logger.info("🔄 STATE_MANAGER: Trim start: \(trimStartTime), end: \(trimEndTime)")
        logger.info("🔄 STATE_MANAGER: Rotation: \(rotationQuarterTurns)°")
        currentState = .naming(
            photosIdentifier: photosIdentifier,
            originalAsset: originalAsset,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            rotationQuarterTurns: rotationQuarterTurns,
            playerViewModel: UnifiedVideoPlayerViewModel(player: AVPlayer(), mode: .preview, appContainer: AppContainer.shared)
        )
    }
    
    /// Transition to saving state
    func transitionToSaving() {
        logger.info("🔄 STATE_MANAGER: Transitioning to saving state")
        currentState = .saving
    }
    
    /// Transition to success state
    func transitionToSuccess(message: String) {
        logger.info("🔄 STATE_MANAGER: Transitioning to success state")
        logger.info("🔄 STATE_MANAGER: Message: \(message)")
        currentState = .success(message: message)
    }
    
    /// Transition to error state
    func transitionToError(message: String, underlyingError: String? = nil) {
        logger.info("🔄 STATE_MANAGER: Transitioning to error state")
        logger.info("🔄 STATE_MANAGER: Message: \(message)")
        logger.info("🔄 STATE_MANAGER: Underlying error: \(underlyingError ?? "nil")")
        currentState = .error(message: message, underlyingError: underlyingError)
    }
    
    // MARK: - State Validation
    
    /// Check if current state matches expected state
    func validateCurrentState(_ expectedState: AddMoveState) -> Bool {
        let isValid = currentState == expectedState
        logger.info("🔄 STATE_MANAGER: State validation")
        logger.info("🔄 STATE_MANAGER: Expected: \(self.getStateDescription(expectedState))")
        logger.info("🔄 STATE_MANAGER: Actual: \(self.getStateDescription(self.currentState))")
        logger.info("🔄 STATE_MANAGER: Valid: \(isValid)")
        return isValid
    }
    
    /// Check if current state is one of the allowed states
    func validateCurrentState(in allowedStates: [AddMoveState]) -> Bool {
        let isValid = allowedStates.contains(currentState)
        logger.info("🔄 STATE_MANAGER: Multi-state validation")
        logger.info("🔄 STATE_MANAGER: Current: \(self.getStateDescription(self.currentState))")
        logger.info("🔄 STATE_MANAGER: Allowed: \(allowedStates.map { self.getStateDescription($0) })")
        logger.info("🔄 STATE_MANAGER: Valid: \(isValid)")
        return isValid
    }
    
    // MARK: - Private Methods
    
    /// Log state transitions
    private func logStateTransition(from: AddMoveState, to: AddMoveState) {
        logger.info("🔄 STATE_MANAGER: State transition detected")
        logger.info("🔄 STATE_MANAGER: From: \(self.getStateDescription(from))")
        logger.info("🔄 STATE_MANAGER: To: \(self.getStateDescription(to))")
        logger.info("🔄 STATE_MANAGER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")
    }
    
    // MARK: - Debug Properties
    
    /// Current state description for debugging
    var currentStateDescription: String {
        return getStateDescription(currentState)
    }
    
    /// Check if state is ready
    var isReady: Bool {
        return currentState == .ready
    }
    
    /// Check if state is in error
    var isInError: Bool {
        if case .error = currentState {
            return true
        }
        return false
    }
    
    /// Check if state is saving
    var isSaving: Bool {
        return currentState == .saving
    }
}