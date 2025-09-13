import SwiftUI
import AVKit
import Combine
import OSLog
import PhotosUI

// MARK: - AddMove Flow Coordinator
// Single Responsibility: Manage AddMoveState transitions and flow control
@MainActor
public class AddMoveFlowCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentStep: AddMoveFlowStep = .selectVideo
    @Published public private(set) var canGoBack = false
    @Published public private(set) var canGoForward = false
    @Published public private(set) var flowProgress: Double = 0.0
    
    // MARK: - Services
    private let stateManager: AddMoveStateManagerProtocol
    private let videoOrchestrator: AddMoveVideoOrchestratorProtocol
    private let playerManager: AddMovePlayerManagerProtocol
    private let saveCoordinator: AddMoveSaveCoordinatorProtocol
    private let logger: AppLogger
    
    // MARK: - Flow State
    private var flowHistory: [AddMoveFlowStep] = []
    private var currentVideoAsset: AVAsset?
    private var currentPhotosIdentifier: String?
    private var currentRotation: Int = 0
    private var moveName: String = ""
    
    // MARK: - Initialization
    public init(
        stateManager: AddMoveStateManagerProtocol,
        videoOrchestrator: AddMoveVideoOrchestratorProtocol,
        playerManager: AddMovePlayerManagerProtocol,
        saveCoordinator: AddMoveSaveCoordinatorProtocol,
        logger: AppLogger
    ) {
        self.stateManager = stateManager
        self.videoOrchestrator = videoOrchestrator
        self.playerManager = playerManager
        self.saveCoordinator = saveCoordinator
        self.logger = logger
        
        setupStateMonitoring()
    }
    
    // MARK: - Public API - Flow Navigation
    
    /// Start new AddMove flow
    public func startFlow() {
        logger.info("🎬 FLOW_COORDINATOR: Starting new AddMove flow", metadata: nil)
        
        resetFlow()
        currentStep = .selectVideo
        updateFlowProgress()
        
        // Reset all services
        videoOrchestrator.reset()
        playerManager.reset()
        saveCoordinator.reset()
        stateManager.reset()
    }
    
    /// Move to next step in flow
    public func nextStep() {
        logger.info("🎬 FLOW_COORDINATOR: Moving to next step from \(currentStep)", metadata: nil)
        
        switch currentStep {
        case .selectVideo:
            // Should be called after video selection
            break
        case .previewVideo:
            moveToTrimming()
        case .trimVideo:
            moveToNaming()
        case .nameMove:
            // Should be called after save
            break
        case .complete:
            break
        }
        
        updateFlowProgress()
    }
    
    /// Move to previous step in flow
    public func previousStep() {
        logger.info("🎬 FLOW_COORDINATOR: Moving to previous step from \(currentStep)", metadata: nil)
        
        switch currentStep {
        case .selectVideo:
            // Can't go back from start
            break
        case .previewVideo:
            returnToVideoSelection()
        case .trimVideo:
            returnToPreview()
        case .nameMove:
            returnToTrimming()
        case .complete:
            break
        }
        
        updateFlowProgress()
    }
    
    /// Cancel current flow
    public func cancelFlow() {
        logger.info("🎬 FLOW_COORDINATOR: Cancelling flow", metadata: nil)
        
        // Cancel any ongoing operations
        videoOrchestrator.cancelLoading()
        saveCoordinator.cancelSave()
        
        // Reset flow
        startFlow()
    }
    
    // MARK: - Public API - Video Selection
    
    /// Handle video selection
    public func selectVideo(_ item: PhotosPickerItem) async {
        logger.info("🎬 FLOW_COORDINATOR: Video selected", metadata: nil)
        
        do {
            let preparationResult = try await videoOrchestrator.loadAndPrepareVideo(from: item)
            
            // Store video info
            currentVideoAsset = preparationResult.asset
            currentPhotosIdentifier = preparationResult.photosIdentifier
            
            // Setup player
            let playerViewModel = try await playerManager.setupPlayerForPlayback(
                asset: preparationResult.asset,
                photosIdentifier: preparationResult.photosIdentifier,
                rotationQuarterTurns: 0
            )
            
            // Move to preview step
            await MainActor.run {
                self.currentStep = .previewVideo
                self.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: Video loaded successfully, moved to preview", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Video selection failed: \(error.localizedDescription)", metadata: nil)
            await stateManager.transitionToError(
                message: "Failed to load video",
                underlyingError: error.localizedDescription
            )
        }
    }
    
    // MARK: - Public API - Trimming
    
    /// Move to trimming step
    public func moveToTrimming() {
        logger.info("🎬 FLOW_COORDINATOR: Moving to trimming step", metadata: nil)
        
        guard let asset = currentVideoAsset else {
            logger.error("🎬 FLOW_COORDINATOR: No asset available for trimming", metadata: nil)
            return
        }
        
        // Prepare player for trimming
        playerManager.preparePlayerForTrimming()
        
        // Update step
        currentStep = .trimVideo
        updateFlowProgress()
        
        logger.info("🎬 FLOW_COORDINATOR: Moved to trimming step", metadata: nil)
    }
    
    /// Complete trimming and move to naming
    public func completeTrimming(
        with trimmerViewModel: TrimmerViewModel
    ) async {
        logger.info("🎬 FLOW_COORDINATOR: Completing trimming", metadata: nil)
        
        do {
            // Export trimmed video
            let trimmedAssetURL = try await trimmerViewModel.exportVideo()
            let trimmedAsset = AVURLAsset(url: trimmedAssetURL)
            
            // Update current asset to trimmed version
            currentVideoAsset = trimmedAsset
            currentRotation = trimmerViewModel.rotationQuarterTurns
            
            // Move to naming step
            await MainActor.run {
                self.currentStep = .nameMove
                self.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: Trimming completed, moved to naming", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Trimming failed: \(error.localizedDescription)", metadata: nil)
            await stateManager.transitionToError(
                message: "Failed to trim video",
                underlyingError: error.localizedDescription
            )
        }
    }
    
    // MARK: - Public API - Saving
    
    /// Save move with current name
    public func saveMove() async {
        logger.info("🎬 FLOW_COORDINATOR: Saving move: \(moveName)", metadata: nil)
        
        guard let asset = currentVideoAsset,
              let photosIdentifier = currentPhotosIdentifier else {
            logger.error("🎬 FLOW_COORDINATOR: Missing required data for save", metadata: nil)
            return
        }
        
        do {
            let result = try await saveCoordinator.saveTrimmedMove(
                name: moveName,
                originalAsset: asset,
                trimmedAsset: asset, // Assuming we're using the processed asset
                photosIdentifier: photosIdentifier,
                trimStartTime: 0.0, // These would come from trimming state
                trimEndTime: asset.duration.seconds,
                rotationQuarterTurns: currentRotation
            )
            
            // Move to complete step
            await MainActor.run {
                self.currentStep = .complete
                self.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: ✅ Move saved successfully", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Save failed: \(error.localizedDescription)", metadata: nil)
            await stateManager.transitionToError(
                message: "Failed to save move",
                underlyingError: error.localizedDescription
            )
        }
    }
    
    /// Update move name
    public func updateMoveName(_ name: String) {
        logger.info("🎬 FLOW_COORDINATOR: Move name updated: \(name)", metadata: nil)
        moveName = name
    }
    
    // MARK: - Private Methods - Flow Navigation
    
    private func returnToVideoSelection() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to video selection", metadata: nil)
        
        // Clear player
        playerManager.clearCurrentPlayer()
        
        // Reset video data
        currentVideoAsset = nil
        currentPhotosIdentifier = nil
        currentRotation = 0
        
        // Go back to selection
        currentStep = .selectVideo
        updateFlowProgress()
    }
    
    private func returnToPreview() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to preview", metadata: nil)
        
        // Resume player
        playerManager.resumePlayerAfterTrimming()
        
        currentStep = .previewVideo
        updateFlowProgress()
    }
    
    private func returnToTrimming() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to trimming", metadata: nil)
        
        // Prepare player for trimming again
        playerManager.preparePlayerForTrimming()
        
        currentStep = .trimVideo
        updateFlowProgress()
    }
    
    private func resetFlow() {
        logger.info("🎬 FLOW_COORDINATOR: Resetting flow", metadata: nil)
        
        flowHistory.removeAll()
        currentVideoAsset = nil
        currentPhotosIdentifier = nil
        currentRotation = 0
        moveName = ""
        currentStep = .selectVideo
        
        updateFlowProgress()
    }
    
    private func updateFlowProgress() {
        switch currentStep {
        case .selectVideo:
            flowProgress = 0.0
            canGoBack = false
            canGoForward = false
        case .previewVideo:
            flowProgress = 0.33
            canGoBack = true
            canGoForward = true
        case .trimVideo:
            flowProgress = 0.66
            canGoBack = true
            canGoForward = true
        case .nameMove:
            flowProgress = 0.9
            canGoBack = true
            canGoForward = false // Save action instead
        case .complete:
            flowProgress = 1.0
            canGoBack = false
            canGoForward = false
        }
        
        logger.info("🎬 FLOW_COORDINATOR: Flow progress updated - Step: \(currentStep), Progress: \(flowProgress)", metadata: nil)
    }
    
    // MARK: - Private Methods - State Monitoring
    
    private func setupStateMonitoring() {
        // Monitor state manager changes
        // This would integrate with the existing state management system
    }
}

// MARK: - Flow Steps
public enum AddMoveFlowStep: CaseIterable {
    case selectVideo
    case previewVideo
    case trimVideo
    case nameMove
    case complete
    
    public var title: String {
        switch self {
        case .selectVideo: return "Select Video"
        case .previewVideo: return "Preview"
        case .trimVideo: return "Trim"
        case .nameMove: return "Name Move"
        case .complete: return "Complete"
        }
    }
    
    public var icon: String {
        switch self {
        case .selectVideo: return "photo"
        case .previewVideo: return "play"
        case .trimVideo: return "scissors"
        case .nameMove: return "pencil"
        case .complete: return "checkmark"
        }
    }
}

// MARK: - Flow Coordinator Protocol
@MainActor
public protocol AddMoveFlowCoordinatorProtocol: ObservableObject {
    var currentStep: AddMoveFlowStep { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    var flowProgress: Double { get }
    
    func startFlow()
    func nextStep()
    func previousStep()
    func cancelFlow()
    func selectVideo(_ item: PhotosPickerItem) async
    func moveToTrimming()
    func completeTrimming(with trimmerViewModel: TrimmerViewModel) async
    func saveMove() async
    func updateMoveName(_ name: String)
}

// MARK: - Conformance
extension AddMoveFlowCoordinator: AddMoveFlowCoordinatorProtocol {}