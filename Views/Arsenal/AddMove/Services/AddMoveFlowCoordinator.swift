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
    private let videoOrchestrator: AddMoveVideoOrchestratorProtocol
    private let playerManager: AddMovePlayerManagerProtocol
    private let saveCoordinator: AddMoveSaveCoordinatorProtocol
    private let logger: AppLogger
    private let appState: AddMoveAppState
    
    // MARK: - Flow State
    private var flowHistory: [AddMoveFlowStep] = []
    private var currentVideoAsset: AVAsset?
    private var currentPhotosIdentifier: String?
    private var currentRotation: Int = 0
    private var moveName: String = ""
    
    // MARK: - Initialization
    public init(
        videoOrchestrator: AddMoveVideoOrchestratorProtocol,
        playerManager: AddMovePlayerManagerProtocol,
        saveCoordinator: AddMoveSaveCoordinatorProtocol,
        logger: AppLogger
    ) {
        self.videoOrchestrator = videoOrchestrator
        self.playerManager = playerManager
        self.saveCoordinator = saveCoordinator
        self.logger = logger
        self.appState = AddMoveAppState()
        
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
            nextStep()
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
            
            // Update app state directly
            await MainActor.run {
                self.appState.videoAsset = preparationResult.asset
                self.appState.photosIdentifier = preparationResult.photosIdentifier
                self.appState.selectedFilename = preparationResult.filename
                self.appState.currentPlayerViewModel = preparationResult.playerViewModel
                self.appState.currentStep = .previewVideo
                self.appState.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: Video loaded successfully, moved to preview", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Video selection failed: \(error.localizedDescription)", metadata: nil)
            await MainActor.run {
                self.appState.setError(message: "Failed to load video", underlying: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Public API - Trimming
    
    /// Move to trimming step
    public func moveToTrimming() {
        logger.info("🎬 FLOW_COORDINATOR: Moving to trimming step", metadata: nil)
        
        guard let asset = appState.videoAsset else {
            logger.error("🎬 FLOW_COORDINATOR: No asset available for trimming", metadata: nil)
            appState.setError(message: "No video available for trimming")
            return
        }
        
        // Prepare player for trimming
        playerManager.preparePlayerForTrimming()
        
        // Update app state
        appState.currentStep = .trimVideo
        appState.updateFlowProgress()
        
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
            
            // Update app state with trimmed video
            await MainActor.run {
                self.appState.videoAsset = trimmedAsset
                self.appState.rotationQuarterTurns = trimmerViewModel.rotationQuarterTurns
                self.appState.trimStartTime = trimmerViewModel.startTime.seconds
                self.appState.trimEndTime = trimmerViewModel.endTime.seconds
                self.appState.currentStep = .nameMove
                self.appState.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: Trimming completed, moved to naming", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Trimming failed: \(error.localizedDescription)", metadata: nil)
            await MainActor.run {
                self.appState.setError(message: "Failed to trim video", underlying: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Public API - Saving
    
    /// Save move with current name
    public func saveMove() async {
        logger.info("🎬 FLOW_COORDINATOR: Saving move: \(appState.moveName)", metadata: nil)
        
        guard let asset = appState.videoAsset,
              let photosIdentifier = appState.photosIdentifier else {
            logger.error("🎬 FLOW_COORDINATOR: Missing required data for save", metadata: nil)
            appState.setError(message: "Missing video data for save")
            return
        }
        
        do {
            let result = try await saveCoordinator.saveTrimmedMove(
                name: appState.moveName,
                originalAsset: asset,
                trimmedAsset: asset, // Assuming we're using the processed asset
                photosIdentifier: photosIdentifier,
                trimStartTime: appState.trimStartTime ?? 0.0,
                trimEndTime: appState.trimEndTime ?? asset.duration.seconds,
                rotationQuarterTurns: appState.rotationQuarterTurns
            )
            
            // Move to complete step
            await MainActor.run {
                self.appState.currentStep = .complete
                self.appState.updateFlowProgress()
            }
            
            logger.info("🎬 FLOW_COORDINATOR: ✅ Move saved successfully", metadata: nil)
            
        } catch {
            logger.error("🎬 FLOW_COORDINATOR: ❌ Save failed: \(error.localizedDescription)", metadata: nil)
            await MainActor.run {
                self.appState.setError(message: "Failed to save move", underlying: error.localizedDescription)
            }
        }
    }
    
    /// Update move name
    public func updateMoveName(_ name: String) {
        logger.info("🎬 FLOW_COORDINATOR: Move name updated: \(name)", metadata: nil)
        appState.moveName = name
    }
    
    // MARK: - Private Methods - Flow Navigation
    
    private func returnToVideoSelection() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to video selection", metadata: nil)
        
        // Clear player
        playerManager.clearCurrentPlayer()
        
        // Reset app state video data
        appState.videoAsset = nil
        appState.photosIdentifier = nil
        appState.rotationQuarterTurns = 0
        appState.currentPlayerViewModel = nil
        
        // Go back to selection
        appState.currentStep = .selectVideo
        appState.updateFlowProgress()
    }
    
    private func returnToPreview() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to preview", metadata: nil)
        
        // Resume player
        playerManager.resumePlayerAfterTrimming()
        
        appState.currentStep = .previewVideo
        appState.updateFlowProgress()
    }
    
    private func returnToTrimming() {
        logger.info("🎬 FLOW_COORDINATOR: Returning to trimming", metadata: nil)
        
        // Prepare player for trimming again
        playerManager.preparePlayerForTrimming()
        
        appState.currentStep = .trimVideo
        appState.updateFlowProgress()
    }
    
    private func resetFlow() {
        logger.info("🎬 FLOW_COORDINATOR: Resetting flow", metadata: nil)
        
        appState.reset()
        currentStep = .selectVideo
        updateFlowProgress()
    }
    
    private func updateFlowProgress() {
        // Synchronize with app state
        currentStep = appState.currentStep
        flowProgress = appState.flowProgress
        canGoBack = appState.canGoBack
        canGoForward = appState.canGoForward
        
        logger.info("🎬 FLOW_COORDINATOR: Flow progress updated - Step: \(currentStep), Progress: \(flowProgress)", metadata: nil)
    }
    
    // MARK: - Private Methods - State Monitoring
    
    private func setupStateMonitoring() {
        // Modern @Observable pattern - no explicit monitoring needed
        // SwiftUI automatically tracks changes to @Observable properties
        logger.info("🎬 FLOW_COORDINATOR: Modern state monitoring setup complete", metadata: nil)
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