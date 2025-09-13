import SwiftUI
import PhotosUI
import AVKit
import CoreData
import Combine
import OSLog
import Foundation
import AVFoundation
import Photos

// MARK: - Lean AddMove View Model
// Single Responsibility: Coordinate between services and provide UI state
@MainActor
public class AddMoveViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: AddMoveState {
        didSet {
            // Delegate state transitions to state manager
            stateManager.transition(to: state)
        }
    }
    
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            logger.info("🎬 VIEWMODEL: selectedItem changed", metadata: nil)
            handleVideoSelection()
        }
    }
    
    @Published var moveName: String = ""
    @Published var selectedFilename: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Services
    private let flowCoordinator: AddMoveFlowCoordinatorProtocol
    private let videoOrchestrator: AddMoveVideoOrchestratorProtocol
    private let playerManager: AddMovePlayerManagerProtocol
    private let saveCoordinator: AddMoveSaveCoordinatorProtocol
    private let stateManager: AddMoveStateManagerProtocol
    private let logger: AppLogger
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(
        flowCoordinator: AddMoveFlowCoordinatorProtocol,
        videoOrchestrator: AddMoveVideoOrchestratorProtocol,
        playerManager: AddMovePlayerManagerProtocol,
        saveCoordinator: AddMoveSaveCoordinatorProtocol,
        stateManager: AddMoveStateManagerProtocol,
        logger: AppLogger
    ) {
        self.flowCoordinator = flowCoordinator
        self.videoOrchestrator = videoOrchestrator
        self.playerManager = playerManager
        self.saveCoordinator = saveCoordinator
        self.stateManager = stateManager
        self.logger = logger
        
        self.state = .ready
        
        setupServiceMonitoring()
    }
    
    // MARK: - Factory Method
    public static func create(viewContext: NSManagedObjectContext) -> AddMoveViewModel {
        let appContainer = AppContainer.shared
        
        // Create services
        let stateManager = AddMoveStateManager()
        let videoAssetPreparer = VideoAssetPreparer()
        let videoPlayerCacheManager = VideoPlayerCacheManager()
        let photosImportService = PhotosImportService()
        let movePersistenceService = MovePersistenceService(viewContext: viewContext)
        let videoProcessingPipeline = appContainer.videoProcessingPipeline
        
        // Create orchestrators
        let videoOrchestrator = AddMoveVideoOrchestrator(
            photosImportService: photosImportService,
            videoAssetPreparer: videoAssetPreparer,
            logger: appContainer.logger
        )
        
        let playerManager = AddMovePlayerManager(
            videoPlayerCacheManager: videoPlayerCacheManager,
            appContainer: appContainer,
            logger: appContainer.logger
        )
        
        let saveCoordinator = AddMoveSaveCoordinator(
            movePersistenceService: movePersistenceService,
            videoProcessingPipeline: videoProcessingPipeline,
            logger: appContainer.logger
        )
        
        let flowCoordinator = AddMoveFlowCoordinator(
            stateManager: stateManager,
            videoOrchestrator: videoOrchestrator,
            playerManager: playerManager,
            saveCoordinator: saveCoordinator,
            logger: appContainer.logger
        )
        
        return AddMoveViewModel(
            flowCoordinator: flowCoordinator,
            videoOrchestrator: videoOrchestrator,
            playerManager: playerManager,
            saveCoordinator: saveCoordinator,
            stateManager: stateManager,
            logger: appContainer.logger
        )
    }
    
    // MARK: - Public API
    
    /// Reset the entire AddMove flow
    public func reset() {
        logger.info("🎬 VIEWMODEL: Resetting AddMove flow", metadata: nil)
        
        flowCoordinator.cancelFlow()
        selectedItem = nil
        moveName = ""
        selectedFilename = nil
        isLoading = false
        errorMessage = nil
        state = .ready
    }
    
    /// Handle video selection from PhotosPicker
    public func handleVideoSelection() {
        logger.info("🎬 VIEWMODEL: Handling video selection", metadata: nil)
        
        guard let item = selectedItem else {
            logger.info("🎬 VIEWMODEL: No item selected", metadata: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                await flowCoordinator.selectVideo(item)
                
                // Update UI state from video orchestrator
                await MainActor.run {
                    self.selectedFilename = self.videoOrchestrator.selectedFilename
                    self.isLoading = false
                }
                
            } catch {
                logger.error("🎬 VIEWMODEL: ❌ Video selection failed: \(error.localizedDescription)", metadata: nil)
                
                await MainActor.run {
                    self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                    self.isLoading = false
                    self.state = .error(message: self.errorMessage ?? "Unknown error", underlyingError: error.localizedDescription)
                }
            }
        }
    }
    
    /// Move to next step in flow
    public func nextStep() {
        logger.info("🎬 VIEWMODEL: Moving to next step", metadata: nil)
        flowCoordinator.nextStep()
    }
    
    /// Move to previous step in flow
    public func previousStep() {
        logger.info("🎬 VIEWMODEL: Moving to previous step", metadata: nil)
        flowCoordinator.previousStep()
    }
    
    /// Start trimming current video
    public func startTrimming() {
        logger.info("🎬 VIEWMODEL: Starting trimming", metadata: nil)
        flowCoordinator.moveToTrimming()
    }
    
    /// Complete trimming with results
    public func completeTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("🎬 VIEWMODEL: Completing trimming", metadata: nil)
        
        isLoading = true
        
        Task {
            await flowCoordinator.completeTrimming(with: trimmerViewModel)
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    /// Cancel trimming and return to preview
    public func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: Cancelling trimming", metadata: nil)
        flowCoordinator.previousStep()
    }
    
    /// Save the current move
    public func saveMove() {
        logger.info("🎬 VIEWMODEL: Saving move", metadata: nil)
        
        guard !moveName.isEmpty else {
            errorMessage = "Please enter a name for your move"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Update move name in flow coordinator
        flowCoordinator.updateMoveName(moveName)
        
        Task {
            await flowCoordinator.saveMove()
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    /// Cancel current operation
    public func cancelOperation() {
        logger.info("🎬 VIEWMODEL: Cancelling current operation", metadata: nil)
        
        videoOrchestrator.cancelLoading()
        saveCoordinator.cancelSave()
        
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    
    /// Current player view model for UI
    var currentPlayerViewModel: (any VideoPlayerViewModelProtocol)? {
        return playerManager.currentPlayerViewModel
    }
    
    /// Current flow step for UI
    var currentStep: AddMoveFlowStep {
        return flowCoordinator.currentStep
    }
    
    /// Whether navigation back is possible
    var canGoBack: Bool {
        return flowCoordinator.canGoBack
    }
    
    /// Whether navigation forward is possible
    var canGoForward: Bool {
        return flowCoordinator.canGoForward
    }
    
    /// Current flow progress
    var flowProgress: Double {
        return flowCoordinator.flowProgress
    }
    
    /// Loading state from video orchestrator
    var isVideoLoading: Bool {
        return videoOrchestrator.isLoadingVideo
    }
    
    /// Video loading progress
    var videoLoadingProgress: Double {
        return videoOrchestrator.loadingProgress
    }
    
    /// Save state
    var isSaving: Bool {
        return saveCoordinator.isSaving
    }
    
    var saveProgress: Double {
        return saveCoordinator.saveProgress
    }
    
    // MARK: - Private Methods
    
    private func setupServiceMonitoring() {
        // Monitor flow coordinator changes
        flowCoordinator.$currentStep
            .receive(on: RunLoop.main)
            .sink { [weak self] step in
                self?.handleFlowStepChange(step)
            }
            .store(in: &cancellables)
        
        // Monitor video orchestrator loading state
        videoOrchestrator.$isLoadingVideo
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                self?.handleVideoLoadingChange(isLoading)
            }
            .store(in: &cancellables)
        
        // Monitor save coordinator state
        saveCoordinator.$isSaving
            .receive(on: RunLoop.main)
            .sink { [weak self] isSaving in
                self?.handleSaveStateChange(isSaving)
            }
            .store(in: &cancellables)
        
        // Monitor save coordinator errors
        saveCoordinator.$saveStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.handleSaveStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func handleFlowStepChange(_ step: AddMoveFlowStep) {
        logger.info("🎬 VIEWMODEL: Flow step changed to \(step)", metadata: nil)
        
        // Update state based on flow step
        switch step {
        case .selectVideo:
            state = .ready
        case .previewVideo:
            state = .previewing
        case .trimVideo:
            state = .trimming
        case .nameMove:
            state = .naming
        case .complete:
            state = .ready // Reset for next move
        }
    }
    
    private func handleVideoLoadingChange(_ isLoading: Bool) {
        logger.info("🎬 VIEWMODEL: Video loading state changed: \(isLoading)", metadata: nil)
        
        if isLoading {
            state = .loading
        } else if flowCoordinator.currentStep == .previewVideo {
            state = .previewing
        }
    }
    
    private func handleSaveStateChange(_ isSaving: Bool) {
        logger.info("🎬 VIEWMODEL: Save state changed: \(isSaving)", metadata: nil)
        
        if isSaving {
            state = .saving
        }
    }
    
    private func handleSaveStatusChange(_ status: SaveStatus) {
        switch status {
        case .completed:
            logger.info("🎬 VIEWMODEL: Save completed successfully", metadata: nil)
            // Flow coordinator handles step transition
        case .error(let message):
            logger.error("🎬 VIEWMODEL: Save failed: \(message)", metadata: nil)
            errorMessage = message
            state = .error(message: message, underlyingError: message)
        case .cancelled:
            logger.info("🎬 VIEWMODEL: Save cancelled", metadata: nil)
            state = .naming // Return to naming step
        default:
            break
        }
    }
}

// MARK: - Legacy Compatibility
// These methods provide backward compatibility with existing views

extension AddMoveViewModel {
    
    /// Get cached player view model (for compatibility with existing views)
    func getCachedPlayerViewModel(asset: AVAsset, rotationQuarterTurns: Int) -> (any VideoPlayerViewModelProtocol)? {
        logger.info("🎬 VIEWMODEL: Getting cached player (legacy method)", metadata: nil)
        
        return Task {
            try? await playerManager.getOrCreatePlayerViewModel(
                asset: asset,
                photosIdentifier: videoOrchestrator.currentPhotosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns
            )
        }.value
    }
    
    /// Prepare video for display (for compatibility with existing views)
    func prepareVideoForDisplay(from item: PhotosPickerItem) async {
        logger.info("🎬 VIEWMODEL: Preparing video for display (legacy method)", metadata: nil)
        
        do {
            let _ = try await videoOrchestrator.loadAndPrepareVideo(from: item)
        } catch {
            logger.error("🎬 VIEWMODEL: ❌ Video preparation failed: \(error.localizedDescription)", metadata: nil)
        }
    }
}