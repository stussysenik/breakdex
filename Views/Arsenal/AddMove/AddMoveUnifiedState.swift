import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import OSLog
import CoreData
import Combine

// Import required services
// These should be available in the codebase

// Note: Service dependencies are defined elsewhere in the codebase

// MARK: - Main Unified State Class
/// Central coordinator for the Add Move workflow
public class AddMoveUnifiedState: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var flowState: AddMoveFlowState = .ready
    @Published public private(set) var playerState: PlayerState = .idle

    // MARK: - Service Components
    private var timerManagementService: TimerManagementService!
    private var videoProgressMonitoringService: VideoProgressMonitoringService!
    private let stateValidator = StateValidator()
    private var addMoveSaveCoordinator: AddMoveSaveCoordinator?
    private var flowStateManager: FlowStateManager!

    // MARK: - Core Properties
    @Published public var moveName: String = ""
    @Published public var loadingProgress: Double = 0.0
    @Published public var loadingStatus: String = ""
    @Published public var currentProgress: Double = 0.0

    // MARK: - Logging Properties
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🎬 AddMoveUnifiedState")
    private let appLogger = ConsoleLogger()

    // 🎯 REMOVED: Transformation deduplication guard - was blocking legitimate transitions
    // private var isTransforming = false

    // Additional properties for compatibility
    @Published public var onSaveSuccess: ((Any) -> Void)?
    @Published public var trimmerViewModel: Any?
    @Published public var loadElapsedTime: TimeInterval = 0.0
    @Published public var saveElapsedTime: TimeInterval = 0.0
    @Published public var saveProgress: Double = 0.0
    @Published public var currentPlayerViewModel: Any?
    @Published public var saveReadiness: Any?
    @Published public var returnToTrimming: (() -> Void)?

    // Compatibility methods
    @MainActor
    public func completeTransition() {
        logger.info("🎬 AddMoveUnifiedState: Completing transition")
        unifiedPlayerManager.completeTransition()
    }

    @MainActor
    public func stopSaveReadinessMonitoring() {
        logger.info("🎬 AddMoveUnifiedState: Stopping save readiness monitoring")
        // Implementation for stopping monitoring
    }

    @MainActor
    public func clearError() async {
        logger.info("🎬 AddMoveUnifiedState: Clearing error state")
        // Reset to ready state when clearing error
        flowState = .ready
        playerState = .idle
    }

    @MainActor
    public func startSaveReadinessMonitoring() {
        logger.info("🎬 AddMoveUnifiedState: Starting save readiness monitoring")
        // Implementation for starting monitoring
        // This would typically setup validation checks for save operation
    }

    // Video and asset properties
    @Published public var videoAsset: AVAsset?
    @Published public var photosIdentifier: String?
    @Published public var trimStartTime: Double = 0.0
    @Published public var trimEndTime: Double = 0.0
    @Published public var rotationQuarterTurns: Int = 0

    // Service dependencies
    public let unifiedPlayerManager: UnifiedPlayerManager
    public let modernVideoLoadingService: ModernVideoLoadingService
    public let videoProcessingPipeline: VideoProcessingPipeline
    public let timecodeCalculationService: TimecodeCalculationService
    public let persistentContainer: NSPersistentContainer
    private let movePersistenceService: MovePersistenceServiceProtocol
    let appContainer: AppContainer

    // MARK: - Initialization
    @MainActor
    public init(
        unifiedPlayerManager: UnifiedPlayerManager,
        modernVideoLoadingService: ModernVideoLoadingService,
        videoProcessingPipeline: VideoProcessingPipeline,
        timecodeCalculationService: TimecodeCalculationService,
        persistentContainer: NSPersistentContainer,
        movePersistenceService: MovePersistenceServiceProtocol,
        appContainer: AppContainer
    ) {
        self.unifiedPlayerManager = unifiedPlayerManager
        self.modernVideoLoadingService = modernVideoLoadingService
        self.videoProcessingPipeline = videoProcessingPipeline
        self.timecodeCalculationService = timecodeCalculationService
        self.persistentContainer = persistentContainer
        self.movePersistenceService = movePersistenceService
        self.appContainer = appContainer

        // 🎯 CRITICAL FIX: Sequential service initialization to prevent race conditions
        logger.info("🎬 AddMoveUnifiedState: Beginning sequential service initialization")

        // Initialize services synchronously on main actor
        timerManagementService = TimerManagementService()
        videoProgressMonitoringService = VideoProgressMonitoringService(modernVideoLoadingService: modernVideoLoadingService)

        logger.info("🎬 AddMoveUnifiedState: Core services initialized, setting up components")

        // Setup components and subscriptions immediately
        setupComponents()
        setupSubscriptions()

        logger.info("🎬 AddMoveUnifiedState: Initialization completed successfully")
    }

    // MARK: - Setup Methods
    @MainActor
    private func setupComponents() {
        logger.info("🎬 AddMoveUnifiedState: Setting up components")

        // Initialize save operation coordinator
        addMoveSaveCoordinator = AddMoveSaveCoordinator(
            movePersistenceService: movePersistenceService,
            videoProcessingPipeline: videoProcessingPipeline,
            logger: appLogger
        )

        // 🎯 CRITICAL FIX: Enhanced progress monitoring setup with validation
        logger.info("🎬 AddMoveUnifiedState: Setting up progress monitoring callback")

        videoProgressMonitoringService.onProgressUpdate = { [weak self] progress in
            guard let self = self else {
                self?.logger.warning("🎬 AddMoveUnifiedState: Progress update callback received after deallocation")
                return
            }

            self.logger.info("🎬 AddMoveUnifiedState: 📊 Progress callback triggered - Phase: \(String(describing: progress.phase)), Progress: \(Int(progress.progress * 100))%")
            self.handleVideoLoadingProgress(progress)
        }

        // 🎯 STRATEGIC FIX: Enhanced completion callback with state management integration
        videoProgressMonitoringService.onCompletion = { [weak self] completion in
            guard let self = self else { return }

            switch completion {
            case .finished:
                logger.info("🎬 AddMoveUnifiedState: ✅ Progress monitoring completed successfully")

                // 🎯 CRITICAL FIX: Trigger natural transformation if we're in loading state
                // This ensures the loading → previewing transition happens even if progress monitoring missed the completion
                if case .loadingVideo = self.flowState {
                    logger.info("🎬 AddMoveUnifiedState: 🔄 Completion callback detected loading state - triggering natural transformation")

                    Task {
                        // Small delay to ensure all progress updates are processed
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

                        self.logger.info("🎬 AddMoveUnifiedState: 🚀 Executing natural transformation from completion callback")
                        self.transitionToTrimmingAfterLoading()
                    }
                } else {
                    logger.info("🎬 AddMoveUnifiedState: 📊 Completion callback processed - not in loading state: \(String(describing: self.flowState))")
                }

            case .failure(let error):
                logger.error("🎬 AddMoveUnifiedState: ❌ Progress monitoring failed: \(error.localizedDescription)")

                // 🎯 ERROR HANDLING: Transition to error state if we're in loading state
                if case .loadingVideo = self.flowState {
                    logger.error("🎬 AddMoveUnifiedState: 🔄 Transitioning to error state due to progress monitoring failure")

                    // 🎯 TIMER FIX: Stop load timer on error
                    logger.info("🎬 AddMoveUnifiedState: ⏱️ Stopping load timer due to progress monitoring failure")
                    timerManagementService.stopLoadTimer()

                    Task {
                        await self.setError(message: "Video loading failed", underlying: error.localizedDescription)
                    }
                }
            }
        }

        // 🎯 CRITICAL FIX: Start monitoring with validation
        logger.info("🎬 AddMoveUnifiedState: Starting progress monitoring service")
        videoProgressMonitoringService.startMonitoring()

        logger.info("🎬 AddMoveUnifiedState: Components setup completed")

        // 🎯 CRITICAL FIX: Initialize FlowStateManager after all dependencies are ready
        logger.info("🎬 AddMoveUnifiedState: Initializing FlowStateManager")

        // Ensure save coordinator is initialized before creating flow state manager
        if addMoveSaveCoordinator == nil {
            addMoveSaveCoordinator = AddMoveSaveCoordinator(
                movePersistenceService: movePersistenceService,
                videoProcessingPipeline: videoProcessingPipeline,
                logger: appLogger
            )
        }

        flowStateManager = FlowStateManager(
            unifiedState: self,
            stateValidator: stateValidator,
            addMoveSaveCoordinator: addMoveSaveCoordinator!
        )

        // Setup flow state manager callbacks
        flowStateManager.onStateTransition = { [weak self] from, to, triggeredBy in
            self?.logger.info("🎬 AddMoveUnifiedState: 🔄 Flow state transition: \(String(describing: from)) → \(String(describing: to)) [triggered by: \(triggeredBy)]")
        }

        logger.info("🎬 AddMoveUnifiedState: FlowStateManager initialized successfully")
    }

    @MainActor
    private func setupSubscriptions() {
        logger.info("🎬 AddMoveUnifiedState: Setting up service subscriptions")

        // 🎯 CRITICAL FIX: Setup save timer subscription with proper logging
        timerManagementService.onSaveTimerUpdate = { [weak self] elapsed in
            guard let self = self else {
                self?.logger.warning("🎬 AddMoveUnifiedState: Save timer update callback received after deallocation")
                return
            }

            self.logger.info("🎬 AddMoveUnifiedState: ⏱️ Save timer update: \(Int(elapsed))s")
            self.saveElapsedTime = elapsed
        }

        // 🎯 STRATEGIC FIX: Setup load timer subscription for loading overlay integration
        timerManagementService.onLoadTimerUpdate = { [weak self] elapsed in
            guard let self = self else {
                self?.logger.warning("🎬 AddMoveUnifiedState: Load timer update callback received after deallocation")
                return
            }

            self.logger.info("🎬 AddMoveUnifiedState: ⏱️ Load timer update: \(Int(elapsed))s")
            self.loadElapsedTime = elapsed
        }

        // 🎯 STRATEGIC FIX: Setup diagnostic logging callback
        timerManagementService.onLogDiagnostic = { [weak self] message, metadata in
            guard let self = self else { return }

            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logger.info("🎬 AddMoveUnifiedState: 📊 Timer diagnostic: \(message) | \(metadataString)")
        }

        logger.info("🎬 AddMoveUnifiedState: Service subscriptions setup completed")
    }

    // MARK: - Simplified Progress Handling
    @MainActor
    public func handleVideoLoadingProgress(_ progress: VideoLoadingProgress) {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Handling video loading progress - \(String(describing: progress.phase)) - \(Int(progress.progress * 100))% - \(progress.message)")

        // Convert to SimpleProgress for internal use
        _ = SimpleProgress(from: progress)

        // Update loading properties for UI binding - ensures real-time progress updates
        loadingProgress = progress.progress
        loadingStatus = progress.message
        currentProgress = progress.progress

        // Update flow state based on loading progress
        if case .loadingVideo = flowState {
            logger.info("🎬 AddMoveUnifiedState: 📊 Updating loading progress: \(Int(progress.progress * 100))%")

            // 🎯 CRITICAL FIX: Check if loading is complete and we haven't already transitioned
            // Use 1.0 (100%) instead of 0.99 to ensure proper completion
            if progress.progress >= 1.0 {
                logger.info("🎬 AddMoveUnifiedState: ✅ VIDEO LOADING COMPLETE - transitioning to trimming stage")

                // 🎯 PREVENT DUPLICATE TRANSITIONS: Only trigger if we're still in loading state
                if case .loadingVideo = flowState {
                    transitionToTrimmingAfterLoading()
                } else {
                    logger.info("🎬 AddMoveUnifiedState: 📊 Already transitioned out of loading state - skipping duplicate transition")
                }
            }
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Progress update received while not in loadingVideo state - Current state: \(String(describing: self.flowState))")
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ Video loading progress handled successfully")
    }

    // Legacy method for compatibility
    @MainActor
    public func handleProgressUpdate(_ progress: VideoLoadingProgress) {
        handleVideoLoadingProgress(progress)
    }

    @MainActor
    public func handleTrimmedAssetProgress(_ progress: SimpleProgress) {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Handling trimmed asset progress - \(progress.percentage)% - \(progress.message)")

        // Update loading properties for UI binding
        loadingProgress = progress.value
        loadingStatus = progress.message
        currentProgress = progress.value

        // Check if trimmed asset loading is complete
        if progress.value >= 1.0 {
            logger.info("🎬 AddMoveUnifiedState: ✅ TRIMMED ASSET LOADING COMPLETE - transitioning to naming stage")
            transition(to: .naming, triggeredBy: "trimmed_asset_loading_complete")
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ Trimmed asset progress handled successfully")
    }

    // 🎯 SIMPLIFIED TRANSITION: Direct transition from loading to trimming
    /// This eliminates the complex natural transformation that was causing the 99% stuck issue
    @MainActor
    private func transitionToTrimmingAfterLoading() {
        logger.info("🎬 AddMoveUnifiedState: 🚀 SIMPLIFIED TRANSITION: loadingVideo → trimming")
        logger.info("🎬 AddMoveUnifiedState: 📊 Video asset available: \(self.videoAsset != nil)")
        logger.info("🎬 AddMoveUnifiedState: 📊 Photos identifier available: \(self.photosIdentifier != nil)")

        // Validate we have all required data
        guard videoAsset != nil && photosIdentifier != nil else {
            logger.error("🎬 AddMoveUnifiedState: ❌ TRANSITION FAILED: Missing required data - videoAsset: \(self.videoAsset != nil), photosIdentifier: \(self.photosIdentifier != nil)")
            Task {
                await setError(message: "Video loading incomplete", underlying: "Missing video asset or photos identifier")
            }
            return
        }

        // Stop the load timer before transitioning
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Stopping load timer before trimming transition")
        timerManagementService.stopLoadTimer()

        // 🎯 CRITICAL FIX: Prevent multiple player creation attempts
        // Check if we already have a player ready to avoid duplicate attempts
        if let existingPlayer = currentPlayerViewModel as? UnifiedVideoPlayerViewModel, existingPlayer.isPlayerReady {
            logger.info("🎬 AddMoveUnifiedState: ✅ Using existing ready player - skipping duplicate creation")

            // Direct transition to trimming state
            logger.info("🎬 AddMoveUnifiedState: ✅ Direct transition to trimming stage with existing player")
            transition(to: .trimming, triggeredBy: "video_loading_complete")

            // Setup trimmer within the trimming state
            Task { @MainActor in
                await setupTrimmerDirectly()
            }
        } else {
            logger.info("🎬 AddMoveUnifiedState: 🎬 Creating player for loaded video asset")

            // Create player asynchronously to avoid blocking
            Task { @MainActor in
                logger.info("🎬 AddMoveUnifiedState: 📡 Starting async player creation")

                do {
                    let playerViewModel = try await unifiedPlayerManager.createOrUpdatePlayer(
                        asset: videoAsset!,
                        photosIdentifier: photosIdentifier!,
                        rotationQuarterTurns: rotationQuarterTurns,
                        appContainer: appContainer
                    )

                    logger.info("🎬 AddMoveUnifiedState: ✅ Player created successfully - isReady: \(playerViewModel.isPlayerReady)")
                    currentPlayerViewModel = playerViewModel

                    // 🎯 CRITICAL FIX: Ensure we transition to trimming state first
                    logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to trimming state")
                    transition(to: .trimming, triggeredBy: "video_loading_complete")

                    logger.info("🎬 AddMoveUnifiedState: 📡 Setting up trimmer after state transition")

                    // Setup trimmer within the trimming state
                    await setupTrimmerDirectly()

                    logger.info("🎬 AddMoveUnifiedState: ✅ Trimming flow completed successfully")

                } catch {
                    logger.error("🎬 AddMoveUnifiedState: ❌ Failed to create player: \(error.localizedDescription)")
                    logger.error("🎬 AddMoveUnifiedState: 🔍 Error details: \(error)")
                    await setError(message: "Failed to create video player", underlying: error.localizedDescription)
                    return
                }
            }
        }
    }

    // 🎯 SIMPLIFIED TRIMMER SETUP: Direct setup within trimming state
    /// This eliminates the complex auto-progression logic that was causing timeouts
    @MainActor
    private func setupTrimmerDirectly() async {
        logger.info("🎬 AddMoveUnifiedState: 🚀 SETTING UP TRIMMER DIRECTLY in trimming state")
        logger.info("🎬 AddMoveUnifiedState: 📊 Current flow state: \(String(describing: self.flowState))")

        // Validate prerequisites
        logger.info("🎬 AddMoveUnifiedState: 🔍 Validating trimmer prerequisites")

        guard let asset = self.videoAsset else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - video asset is nil")
            await setError(message: "No video available for trimming", underlying: "Video asset is nil")
            return
        }

        do {
            let duration = try await asset.load(.duration)
            logger.info("🎬 AddMoveUnifiedState: ✅ Video asset validated - duration: \(duration.seconds)s")
        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ Failed to load video duration: \(error.localizedDescription)")
            await setError(message: "Failed to load video duration", underlying: error.localizedDescription)
            return
        }

        guard let photosIdentifier = self.photosIdentifier else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - photos identifier is nil")
            await setError(message: "No video identifier available", underlying: "Photos identifier is nil")
            return
        }
        logger.info("🎬 AddMoveUnifiedState: ✅ Photos identifier validated - \(photosIdentifier)")

        guard let playerViewModel = self.currentPlayerViewModel as? UnifiedVideoPlayerViewModel else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - no current player")
            logger.error("🎬 AddMoveUnifiedState: 📊 currentPlayerViewModel: \(self.currentPlayerViewModel != nil ? "available" : "nil")")
            logger.error("🎬 AddMoveUnifiedState: 📊 unifiedPlayerManager.currentPlayer: \(self.unifiedPlayerManager.currentPlayer != nil ? "available" : "nil")")
            await setError(message: "No player available for trimming", underlying: "Current player is nil")
            return
        }
        logger.info("🎬 AddMoveUnifiedState: ✅ Player validated - ready: \(playerViewModel.isPlayerReady)")

        do {
            logger.info("🎬 AddMoveUnifiedState: ✅ Creating trimmer view model directly")

            // Initialize trimmer view model
            let trimmerVM = TrimmerViewModel(
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns,
                playerViewModel: playerViewModel
            )
            logger.info("🎬 AddMoveUnifiedState: ✅ TrimmerViewModel initialized")

            // Set the progress delegate
            trimmerVM.progressDelegate = self

            // Update the published trimmer view model
            trimmerViewModel = trimmerVM
            logger.info("🎬 AddMoveUnifiedState: ✅ Published trimmer view model updated")

            logger.info("🎬 AddMoveUnifiedState: 📡 Starting async trimmer setup")

            // Setup the trimmer
            try await trimmerVM.setupAsync()
            logger.info("🎬 AddMoveUnifiedState: ✅ Trimmer async setup completed successfully")

            // Set the trim range
            let duration = try await asset.load(.duration).seconds
            let startTime = CMTime(seconds: trimStartTime > 0 ? trimStartTime : 0, preferredTimescale: 600)
            let endTime = CMTime(seconds: trimEndTime > 0 ? trimEndTime : duration, preferredTimescale: 600)

            trimmerVM.startTime = startTime
            trimmerVM.endTime = endTime

            logger.info("🎬 AddMoveUnifiedState: ✅ Trim range set - start: \(startTime.seconds)s, end: \(endTime.seconds)s")
            logger.info("🎬 AddMoveUnifiedState: ✅ Trimmer is ready for user interaction")
            logger.info("🎬 AddMoveUnifiedState: 🎉 TRIMMER SETUP FLOW COMPLETED SUCCESSFULLY")

        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ Failed to setup trimmer: \(error.localizedDescription)")
            logger.error("🎬 AddMoveUnifiedState: 🔍 Full error: \(error)")
            await setError(message: "Failed to setup trimmer", underlying: error.localizedDescription)
        }
    }

    // 🎯 SIMPLIFIED ERROR HANDLING: Direct error transitions without complex rollback logic
    @MainActor
    private func handleTransitionError(message: String, underlying: String? = nil) async {
        logger.warning("🎬 AddMoveUnifiedState: 🔄 Handling transition error: \(message)")
        await setError(message: message, underlying: underlying)
    }

    @MainActor
    private func updateTimerProgress(_ elapsed: TimeInterval) {
        let progress = min(1.0, elapsed / 30.0) // 30 second expected duration
        loadingProgress = progress
    }

    // MARK: - State Transitions
    @MainActor
    public func transition(to newState: AddMoveFlowState, triggeredBy: String = "unknown") {
        let previousState = flowState

        // 🎯 STRATEGIC FIX: State validation is now handled by FlowStateManager
        // Direct transition for internal use (FlowStateManager handles validation)
        flowState = newState

        // 🎯 CATEGORY THEORY: Enhanced functor composition logging
        logFunctorComposition(from: previousState, to: newState, triggeredBy: triggeredBy)

        // Handle state-specific actions
        handleStateTransition(from: previousState, to: newState)
    }

    // MARK: - Category Theory Diagnostic Logging

    /// Enhanced functor composition logging using category theory principles
    /// Logs morphism compositions and natural transformations for systematic debugging
    @MainActor
    private func logFunctorComposition(from: AddMoveFlowState, to: AddMoveFlowState, triggeredBy: String) {
        logger.info("🎬 AddMoveUnifiedState: 🔄 State transition: \(String(describing: from)) -> \(String(describing: to)) [triggered by: \(triggeredBy)]")

        // 🎯 CATEGORY THEORY: Functor composition analysis
        let compositionResult = analyzeFunctorComposition(from: from, to: to)
        logger.info("🎬 AddMoveUnifiedState: 📊 Functor composition: \(compositionResult.description)")

        // 🎯 NATURAL TRANSFORMATION: Track critical transformations
        if compositionResult.isNaturalTransformation {
            logger.info("🎬 AddMoveUnifiedState: 🌟 Natural transformation detected: \(compositionResult.transformationType)")
        }

        // 🎯 UNIVERSAL PROPERTY: Validate invariants
        if !compositionResult.maintainsInvariants {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Universal property violation detected - invariants not maintained")
        }

        // 🎯 ADJOINT FUNCTOR: Track reversible operations
        if compositionResult.hasAdjoint {
            logger.info("🎬 AddMoveUnifiedState: 🔄 Adjoint functor available - transformation is reversible")
        }

        // Log memory and performance metrics at critical points
        if compositionResult.isCriticalTransition {
            logPerformanceMetrics(for: to)
        }
    }

    /// Functor composition analysis using category theory principles
    private struct FunctorCompositionResult {
        let description: String
        let isNaturalTransformation: Bool
        let transformationType: String
        let maintainsInvariants: Bool
        let hasAdjoint: Bool
        let isCriticalTransition: Bool
    }

    private func analyzeFunctorComposition(from: AddMoveFlowState, to: AddMoveFlowState) -> FunctorCompositionResult {
        // 🎯 CATEGORY THEORY: Analyze the morphism between objects (states)
        switch (from, to) {
        case (.loadingVideo, .trimming):
            return FunctorCompositionResult(
                description: "LoadingVideo → Trimming functor composition",
                isNaturalTransformation: true,
                transformationType: "Natural transformation (loading complete)",
                maintainsInvariants: true,
                hasAdjoint: true,
                isCriticalTransition: true
            )

        case (.trimming, .loadingTrimmedAsset):
            return FunctorCompositionResult(
                description: "Trimming → LoadingTrimmedAsset functor composition",
                isNaturalTransformation: true,
                transformationType: "Natural transformation (asset preparation)",
                maintainsInvariants: true,
                hasAdjoint: true,
                isCriticalTransition: true
            )

        case (.trimming, .naming):
            return FunctorCompositionResult(
                description: "Trimming → Naming functor composition",
                isNaturalTransformation: false,
                transformationType: "Morphism (state progression)",
                maintainsInvariants: true,
                hasAdjoint: false,
                isCriticalTransition: false
            )

        case (.naming, .saving):
            return FunctorCompositionResult(
                description: "Naming → Saving functor composition",
                isNaturalTransformation: false,
                transformationType: "Morphism (operation execution)",
                maintainsInvariants: true,
                hasAdjoint: false,
                isCriticalTransition: true
            )

        case (.saving, .success):
            return FunctorCompositionResult(
                description: "Saving → Success terminal functor",
                isNaturalTransformation: true,
                transformationType: "Terminal object morphism",
                maintainsInvariants: true,
                hasAdjoint: false,
                isCriticalTransition: true
            )

        case (_, .error):
            return FunctorCompositionResult(
                description: "Error transformation functor",
                isNaturalTransformation: true,
                transformationType: "Error handling natural transformation",
                maintainsInvariants: false,
                hasAdjoint: false,
                isCriticalTransition: true
            )

        default:
            return FunctorCompositionResult(
                description: "Standard state morphism",
                isNaturalTransformation: false,
                transformationType: "State progression morphism",
                maintainsInvariants: true,
                hasAdjoint: false,
                isCriticalTransition: false
            )
        }
    }

    /// Performance metrics logging at critical functor composition points
    @MainActor
    private func logPerformanceMetrics(for state: AddMoveFlowState) {
        let memoryUsage = getMemoryUsage()
        let loadElapsed = timerManagementService.getLoadElapsedTime()
        let saveElapsed = timerManagementService.getSaveElapsedTime()

        logger.info("🎬 AddMoveUnifiedState: 📊 Performance metrics at \(String(describing: state)) - Memory: \(memoryUsage), Load: \(String(format: "%.2f", loadElapsed))s, Save: \(String(format: "%.2f", saveElapsed))s")

        // Log asset status for video-related states
        if case .loadingVideo = state {
            let assetStatus = videoAsset != nil ? "loaded" : "missing"
            let playerStatus = currentPlayerViewModel != nil ? "created" : "missing"
            logger.info("🎬 AddMoveUnifiedState: 📈 Asset status at loadingVideo - Asset: \(assetStatus), Player: \(playerStatus)")
        }
    }

    /// Enhanced memory usage calculation
    private func getMemoryUsage() -> String {
        let memoryInfo = ProcessInfo.processInfo
        let totalGB = memoryInfo.physicalMemory / (1024 * 1024 * 1024)

        // availableMemory has been removed from iOS 13+, use basic total memory display
        return "\(totalGB)GB total"
    }

    /// Logs state information for debugging
    private func logState(_ context: String, flowState: AddMoveFlowState) {
        let memoryInfo = ProcessInfo.processInfo
        logger.info("🎬 [\(context)] State: \(String(describing: flowState)), Mem: \(memoryInfo.physicalMemory / (1024*1024*1024))GB")
    }

    @MainActor
    private func handleStateTransition(from: AddMoveFlowState, to: AddMoveFlowState) {
        logger.info("🎬 AddMoveUnifiedState: State transition from \(String(describing: from)) to \(String(describing: to))")

        // 🔄 Simplified timer lifecycle management for 5-stage flow
        switch (from, to) {
        // Loading phase transitions
        case (.ready, .loadingVideo), (.error, .loadingVideo), (.success, .loadingVideo):
            timerManagementService.startLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: 📱 Started load timer for transition: \(String(describing: from)) → \(String(describing: to))")

        case (.loadingVideo, .trimming):
            timerManagementService.stopLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: ✅ Load timer stopped - loading complete: loadingVideo → trimming")

        case (.loadingVideo, .error), (.loadingVideo, .ready):
            timerManagementService.stopLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: ⚠️ Load timer stopped - transition aborted: \(String(describing: from)) → \(String(describing: to))")

        // Asset preparation transitions
        case (.trimming, .loadingTrimmedAsset):
            logger.info("🎬 AddMoveUnifiedState: 📱 Starting asset preparation: trimming → loadingTrimmedAsset")

        case (.loadingTrimmedAsset, .naming):
            logger.info("🎬 AddMoveUnifiedState: ✅ Asset preparation complete: loadingTrimmedAsset → naming")

        case (.loadingTrimmedAsset, .error):
            logger.info("🎬 AddMoveUnifiedState: ❌ Asset preparation failed: loadingTrimmedAsset → error")

        // Save phase transitions
        case (.naming, .saving):
            timerManagementService.startSaveTimer()
            logger.info("🎬 AddMoveUnifiedState: 📱 Started save timer for transition: \(String(describing: from)) → \(String(describing: to))")

        case (.saving, .success):
            timerManagementService.stopSaveTimer()
            logger.info("🎬 AddMoveUnifiedState: ✅ Save timer stopped - operation successful: \(String(describing: from)) → \(String(describing: to))")

        case (.saving, .error):
            timerManagementService.stopSaveTimer()
            logger.info("🎬 AddMoveUnifiedState: ❌ Save timer stopped - operation failed: \(String(describing: from)) → \(String(describing: to))")

        // Terminal states - ensure all timers are stopped
        case (_, .success), (_, .error), (_, .ready):
            timerManagementService.resetAllTimers()
            logger.info("🎬 AddMoveUnifiedState: 🧹 All timers reset - reached terminal state: \(String(describing: to))")

        default:
            logger.info("🎬 AddMoveUnifiedState: 📝 No timer action needed for transition: \(String(describing: from)) → \(String(describing: to))")
        }

        // 🎯 STRATEGIC FIX: Log timer state for debugging
        logTimerState("state_transition", from: String(describing: from), to: String(describing: to))
    }

    // MARK: - Timer State Monitoring

    /// Logs current timer state for debugging and monitoring
    @MainActor
    private func logTimerState(_ context: String, from: String? = nil, to: String? = nil) {
        let saveElapsed = timerManagementService.getSaveElapsedTime()
        let loadElapsed = timerManagementService.getLoadElapsedTime()

        var metadata: [String: String] = [
            "context": context,
            "save_elapsed": String(format: "%.2f", saveElapsed),
            "load_elapsed": String(format: "%.2f", loadElapsed)
        ]

        if let from = from { metadata["transition_from"] = from }
        if let to = to { metadata["transition_to"] = to }

        logger.info("🎬 AddMoveUnifiedState: ⏱️ Timer state [\(context)] - Save: \(String(format: "%.2f", saveElapsed))s, Load: \(String(format: "%.2f", loadElapsed))s")
    }

    // MARK: - Save Operations
    public func saveMove() async {
        logger.info("🎬 AddMoveUnifiedState: Save operations now handled by FlowStateManager")

        // Save operations are now handled by FlowStateManager.proceedToNextState()
        // when in .naming state
        guard flowStateManager != nil else {
            logger.error("🎬 AddMoveUnifiedState: FlowStateManager not available for save operation")
            await setError(message: "Save service not available", underlying: "FlowStateManager is nil")
            return
        }

        // This method is kept for backward compatibility but delegates to FlowStateManager
        logger.info("🎬 AddMoveUnifiedState: Save operation delegated to FlowStateManager")
    }

    // MARK: - Validation Methods
    public func validateSaveReadiness() async -> SaveReadinessResult {
        logger.info("🎬 AddMoveUnifiedState: Validation delegated to StateValidator")

        // Delegate to StateValidator for validation logic
        return await stateValidator.validateSaveReadiness(
            flowState: flowState,
            playerState: playerState,
            moveName: moveName,
            videoAsset: videoAsset,
            trimmerViewModel: trimmerViewModel as? TrimmerViewModel,
            playerViewModel: currentPlayerViewModel as? UnifiedVideoPlayerViewModel,
            photosIdentifier: photosIdentifier,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        )
    }

    public func getSaveValidationStatus() -> SaveValidationStatus {
        _ = Task {
            await validateSaveReadiness()
        }

        // For synchronous access, use a default result
        return .ready("Validating...")
    }

    // MARK: - Public API Methods
    @MainActor
    public func prepareForTransition() {
        logger.info("🎬 AddMoveUnifiedState: Preparing for transition")
        unifiedPlayerManager.prepareForTransition()
    }

    public var canProceed: Bool {
        return videoAsset != nil && photosIdentifier != nil
    }

    // MARK: - Service Validation Methods
    @MainActor
    private func validateServicesReady() -> Bool {
        logger.info("🎬 AddMoveUnifiedState: 🔍 Validating service readiness")

        var allServicesReady = true

        // Validate timer management service
        if timerManagementService == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ TimerManagementService not initialized")
            allServicesReady = false
        } else {
            logger.info("🎬 AddMoveUnifiedState: ✅ TimerManagementService ready")
        }

        // Validate progress monitoring service
        if videoProgressMonitoringService == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ VideoProgressMonitoringService not initialized")
            allServicesReady = false
        } else {
            logger.info("🎬 AddMoveUnifiedState: ✅ VideoProgressMonitoringService ready")
        }

        // Validate callback setup
        if videoProgressMonitoringService?.onProgressUpdate == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ Progress monitoring callback not set")
            allServicesReady = false
        } else {
            logger.info("🎬 AddMoveUnifiedState: ✅ Progress monitoring callback configured")
        }

        // Validate save coordinator
        if addMoveSaveCoordinator == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ AddMoveSaveCoordinator not initialized")
            allServicesReady = false
        } else {
            logger.info("🎬 AddMoveUnifiedState: ✅ AddMoveSaveCoordinator ready")
        }

        logger.info("🎬 AddMoveUnifiedState: 📊 Service validation result: \(allServicesReady ? "READY" : "NOT READY")")
        return allServicesReady
    }

    @MainActor
    public func reset() {
        logger.info("🎬 AddMoveUnifiedState: Resetting to ready state")
        flowState = .ready
        playerState = .idle
        moveName = ""
        videoAsset = nil
        photosIdentifier = nil
        trimStartTime = 0.0
        trimEndTime = 0.0
        rotationQuarterTurns = 0
        loadingProgress = 0.0
        loadingStatus = ""
        currentProgress = 0.0
    }

    @MainActor
    public func didSelectVideo(_ item: PhotosPickerItem) {
        let identifier = item.itemIdentifier ?? "unknown"
        logger.info("🎬 AddMoveUnifiedState: Video selected - \(identifier)")

        // Start the video loading process
        Task {
            await loadVideo(from: item)
        }
    }

    // MARK: - Video Loading Implementation
    @MainActor
    private func loadVideo(from item: PhotosPickerItem) async {
        let identifier = item.itemIdentifier ?? "unknown"
        logger.info("🎬 AddMoveUnifiedState: 🚀 Starting video loading process for \(identifier)")

        // 🎯 CRITICAL FIX: Validate services are ready before loading
        guard validateServicesReady() else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Services not ready for video loading")
            await setError(message: "Services not ready", underlying: "Required services not initialized")
            return
        }

        // Reset loading state before starting
        loadingProgress = 0.0
        loadingStatus = "Preparing to load video..."
        currentProgress = 0.0

        logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to loadingVideo state")
        let initialProgress = SimpleProgress(value: 0.0, message: "Preparing to load video...")
        transition(to: .loadingVideo(progress: initialProgress))

        let loadingStartTime = Date()

        do {
            logger.info("🎬 AddMoveUnifiedState: 📡 Calling modern video loading service")

            // Load the video using the modern video loading service
            let result = try await modernVideoLoadingService.loadVideo(from: item)

            let loadingDuration = Date().timeIntervalSince(loadingStartTime)

            // Update video asset and properties with logging
            logger.info("🎬 AddMoveUnifiedState: 🏆 Video loading completed in \(String(format: "%.2f", loadingDuration))s")
            logger.info("🎬 AddMoveUnifiedState: 📊 Result - Filename: \(result.filename), Duration: \(result.duration.seconds)s, Size: \(result.fileSize ?? 0) bytes")

            videoAsset = result.asset
            photosIdentifier = result.photosIdentifier

            // Notify completion of video loading
            let completedProgress = VideoLoadingProgress(phase: .creatingAsset, correlationId: "load_complete")
            handleVideoLoadingProgress(completedProgress)

            logger.info("🎬 AddMoveUnifiedState: ✅ Video asset and properties updated successfully")

            // 🎯 CRITICAL FIX: Player creation is now handled in transitionToTrimmingAfterLoading()
            // This prevents duplicate player creation attempts that were causing timeout issues
            logger.info("🎬 AddMoveUnifiedState: ✅ Video asset loaded - player creation deferred to trimming transition")

            // Note: The transition to trimming state is now handled by handleVideoLoadingProgress when progress reaches 100%
            logger.info("🎬 AddMoveUnifiedState: 📊 Video loading completed - waiting for transition to trimming")

        } catch {
            let loadingDuration = Date().timeIntervalSince(loadingStartTime)
            logger.error("🎬 AddMoveUnifiedState: ❌ Video loading failed after \(String(format: "%.2f", loadingDuration))s - \(error.localizedDescription)")
            await setError(message: "Failed to load video", underlying: error.localizedDescription)
        }
    }

    @MainActor
    public func replaceSelectedVideo(_ item: PhotosPickerItem) async {
        let identifier = item.itemIdentifier ?? "unknown"
        logger.info("🎬 AddMoveUnifiedState: Replacing selected video - \(identifier)")

        // Reset existing video data
        videoAsset = nil
        photosIdentifier = nil
        loadingProgress = 0.0
        loadingStatus = "Replacing video..."

        // Load the new video - this will transition to loadingVideo state
        await loadVideo(from: item)
    }

    @MainActor
    public func proceedToNextState() async throws {
        logger.info("🎬 AddMoveUnifiedState: Delegating to FlowStateManager")

        // Delegate to FlowStateManager for proper state transition logic
        guard let flowStateManager = flowStateManager else {
            logger.error("🎬 AddMoveUnifiedState: FlowStateManager not initialized")
            throw NSError(domain: "AddMoveUnifiedState", code: -1, userInfo: [NSLocalizedDescriptionKey: "FlowStateManager not available"])
        }

        try await flowStateManager.proceedToNextState()
    }

    @MainActor
    public func transitionTo(_ state: AddMoveFlowState) async {
        logger.info("🎬 AddMoveUnifiedState: Transitioning to \(String(describing: state))")
        transition(to: state, triggeredBy: "PreTrimViewUnified")
    }

    @MainActor
    public func setError(message: String, underlying: String? = nil) async {
        logger.error("🎬 AddMoveUnifiedState: Error - \(message)")
        if let underlying = underlying {
            logger.error("🎬 AddMoveUnifiedState: Underlying error - \(underlying)")
        }
        transition(to: .error(message: message, underlyingError: underlying))
    }

    @MainActor
    public func applyTrimSettings(startTime: CMTime, endTime: CMTime, rotation: Int) async throws {
        logger.info("🎬 AddMoveUnifiedState: Applying trim settings")
        trimStartTime = startTime.seconds
        trimEndTime = endTime.seconds
        rotationQuarterTurns = rotation

        // Apply trim to player if available
        if let _ = unifiedPlayerManager.currentPlayer {
            try await unifiedPlayerManager.applyTrimToCurrentPlayer(
                startTime: startTime,
                endTime: endTime,
                rotation: rotation
            )
        }
    }

    // MARK: - Trimmer Setup Method
    @MainActor
    public func setupTrimmerAfterPreview() async {
        logger.info("🎬 AddMoveUnifiedState: Delegating trimmer setup to FlowStateManager")

        // Delegate to FlowStateManager for proper trimmer setup logic
        guard let flowStateManager = flowStateManager else {
            logger.error("🎬 AddMoveUnifiedState: FlowStateManager not initialized")
            await setError(message: "FlowStateManager not available", underlying: "FlowStateManager is nil")
            return
        }

        await flowStateManager.setupTrimmerAfterPreview()
    }

    // MARK: - Simplified State Management
    // Note: setupTrimmerAfterPreview() is now handled by transitionToTrimmingAfterLoading() in the simplified flow

    // MARK: - Cleanup
    private var cancellables = Set<AnyCancellable>()

    // MARK: - App Logger Wrapper
    /// Wrapper that adapts OSLog.Logger to AppLogger protocol
    private class OSLogAppLogger: AppLogger {
        private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveAppLogger")

        func info(_ message: String, metadata: [String: Any]? = nil) {
            logger.info("\(message)")
        }

        func warning(_ message: String, metadata: [String: Any]? = nil) {
            logger.warning("\(message)")
        }

        func error(_ message: String, metadata: [String: Any]? = nil) {
            logger.error("\(message)")
        }

        func critical(_ message: String, metadata: [String: Any]? = nil) {
            logger.critical("\(message)")
        }

        func debug(_ message: String, metadata: [String: Any]? = nil) {
            logger.debug("\(message)")
        }
    }

    public func tearDown() {
        logger.info("🎬 AddMoveUnifiedState teardown initiated")

        Task { @MainActor in
            timerManagementService.resetAllTimers()
            videoProgressMonitoringService.stopMonitoring()
            stateValidator.tearDown()
            addMoveSaveCoordinator?.reset()
            cancellables.removeAll()
        }
    }

    deinit {
        tearDown()
    }
}

// MARK: - App Logger Adapter
/// Simple adapter to make OSLog compatible with AppLogger protocol
private class AddMoveAppLogger: AppLogger {
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🎬 AddMoveUnifiedState")

    func info(_ message: String, metadata: [String: Any]? = nil) {
        logger.info("\(message)")
    }

    func warning(_ message: String, metadata: [String: Any]? = nil) {
        logger.warning("\(message)")
    }

    func error(_ message: String, metadata: [String: Any]? = nil) {
        logger.error("\(message)")
    }

    func critical(_ message: String, metadata: [String: Any]? = nil) {
        logger.critical("\(message)")
    }

    func debug(_ message: String, metadata: [String: Any]? = nil) {
        logger.debug("\(message)")
    }
}

// MARK: - TrimmerSetupProgressDelegate Implementation
extension AddMoveUnifiedState: @preconcurrency TrimmerSetupProgressDelegate {

    public func trimmerDidUpdateProgress(_ progress: Double, status: String) {
        logger.info("🎬 AddMoveUnifiedState: 📊 Trimmer setup progress: \(String(format: "%.1f", progress * 100))% - \(status)")

        // In the simplified flow, trimmer setup happens within trimming state
        if case .trimming = self.flowState {
            logger.info("🎬 AddMoveUnifiedState: 📊 Trimmer setup continuing in trimming state")
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Trimmer progress update received but not in trimming state: \(String(describing: self.flowState))")
        }
    }

    public func trimmerDidCompleteSetup(totalTime: TimeInterval?) {
        logger.info("🎬 AddMoveUnifiedState: ✅ Trimmer setup completed successfully")

        if let totalTime = totalTime {
            logger.info("🎬 AddMoveUnifiedState: ⏱️ Total setup time: \(String(format: "%.2f", totalTime))s")
        }

        // In the simplified flow, we should already be in trimming state
        if case .trimming = self.flowState {
            logger.info("🎬 AddMoveUnifiedState: ✅ Trimmer is ready for user interaction")
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Trimmer completion received but not in trimming state: \(String(describing: self.flowState))")
        }
    }

    public func trimmerDidEncounterError(_ error: Error, context: String) {
        logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup error in context '\(context)': \(error.localizedDescription)")

        // Provide detailed error information
        let underlyingError = "\(context): \(error.localizedDescription)"
        logger.error("🎬 AddMoveUnifiedState: 🔍 Full error context: \(underlyingError)")

        // Transition to error state
        Task { @MainActor in
            await setError(message: "Trimmer setup failed", underlying: underlyingError)
        }
    }
}
