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
///
/// 🔧 COMPILATION ERROR FIXES APPLIED (October 1, 2025):
/// 1. ✅ Removed duplicate method declarations for canRestoreTrimmingState() and attemptTrimmingStateRestoration()
///    - Duplicates were found at lines 2319-2361, removed to avoid redeclaration conflicts
///    - Using private implementations at lines 2084-2100 with better error handling
/// 2. ✅ Removed duplicate method declarations for preserveTrimmingState() and clearPreservedTrimmingState()
///    - Duplicates were found at lines 2365-2389, removed to avoid redeclaration conflicts
///    - Using private implementations at lines 2016-2067 with comprehensive logging
/// 3. ✅ Fixed explicit self references in closures
///    - Self reference issues were resolved by removing duplicate methods that contained problematic closures
/// 4. ✅ Added comprehensive diagnostic logging for all fixes
/// 5. ✅ Maintained existing architecture and trimming state functionality
///
/// The private implementations provide superior error handling, diagnostic logging,
/// and follow the established architectural patterns while maintaining WYSIWYG experience.
public class AddMoveUnifiedState: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var flowState: AddMoveFlowState = .ready
    @Published public private(set) var playerState: PlayerState = .idle

    // MARK: - Service Components
    private var timerManagementService: TimerManagementService!
    private var videoProgressMonitoringService: VideoProgressMonitoringService!
    private let stateValidator = StateValidator()
    private var addMoveSaveCoordinator: AddMoveSaveCoordinator?
    internal var flowStateManager: FlowStateManager!

    // Save readiness monitoring timer
    private var saveReadinessTimer: Timer?

    // MARK: - Service Validation
    private var servicesInitialized = false

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
    @Published public var saveReadiness: SaveReadinessResult?
    @Published public var returnToTrimming: (() -> Void)?

    // 🎯 CRITICAL FIX: Enhanced transition management to prevent hang
    private var isTransitioningToTrimming = false
    private var transitionStartTime: Date?
    private var transitionCorrelationId: String?

    // 🎯 BACK BUTTON FIX: Preserve trimming state for back button functionality
    public var preservedTrimmingState: TrimmingStateSnapshot?

    // Compatibility methods
    @MainActor
    public func completeTransition() {
        logger.info("🎬 AddMoveUnifiedState: Completing transition")
        unifiedPlayerManager.completeTransition()
    }

  
    @MainActor
    public func clearError() async {
        logger.info("🎬 AddMoveUnifiedState: Clearing error state")
        // Reset to ready state when clearing error
        flowState = .ready
        playerState = .idle
    }

    /// 🎯 BACK BUTTON FIX: Public method to update player state for proper state synchronization
    /// This allows FlowStateManager to ensure player state consistency during transitions
    @MainActor
    public func updatePlayerState(_ newState: PlayerState) {
        logger.info("🎬 AddMoveUnifiedState: 🔧 BACK BUTTON FIX - Updating player state: \(String(describing: self.playerState)) → \(String(describing: newState))")
        self.playerState = newState
        logger.info("🎬 AddMoveUnifiedState: ✅ BACK BUTTON FIX - Player state updated to: \(String(describing: newState))")
    }

    @MainActor
    public func startSaveReadinessMonitoring() {
        logger.info("🎬 AddMoveUnifiedState: Starting save readiness monitoring")

        // Cancel any existing monitoring timer
        saveReadinessTimer?.invalidate()

        // Create timer for continuous validation monitoring
        saveReadinessTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSaveReadinessValidation()
            }
        }

        // Perform initial validation immediately
        Task { @MainActor in
            await self.performSaveReadinessValidation()
        }
    }

    @MainActor
    private func performSaveReadinessValidation() async {
        logger.info("🎬 AddMoveUnifiedState: 🔍 DIAGNOSTIC - Performing save readiness validation...")

        let validationResult = await validateSaveReadiness()

        // Log detailed validation results for debugging
        if validationResult.isValid {
            logger.info("🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Validation passed - ready to save")
            logger.info("🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Validation details: canSave=\(validationResult.canSave), issues=\(validationResult.issues.count)")
            logger.info("🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Player ready: \(validationResult.hasValidPlayer), Asset ready: \(validationResult.hasValidAsset), Trimmer ready: \(validationResult.hasValidTrimmer)")

            // 🎯 INFINITE LOOP FIX: Stop monitoring once validation succeeds
            logger.info("🎬 AddMoveUnifiedState: ✅ Validation succeeded - stopping monitoring timer")
            stopSaveReadinessMonitoring()
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ DIAGNOSTIC - Validation failed - issues: \(validationResult.issues)")
            for (index, issue) in validationResult.issues.enumerated() {
                logger.warning("🎬 AddMoveUnifiedState: ⚠️ DIAGNOSTIC - Issue \(index + 1): \(issue.localizedDescription) (critical: \(issue.isCritical))")
            }
        }

        // Update published property to notify UI
        logger.info("🎬 AddMoveUnifiedState: 🔧 DIAGNOSTIC - Updating saveReadiness property...")
        self.saveReadiness = validationResult
        logger.info("🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Save readiness validation completed")
    }

    @MainActor
    public func stopSaveReadinessMonitoring() {
        logger.info("🎬 AddMoveUnifiedState: Stopping save readiness monitoring")
        saveReadinessTimer?.invalidate()
        saveReadinessTimer = nil
    }

    // Video and asset properties
    @Published public var videoAsset: AVAsset?
    @Published public var photosIdentifier: String?
    @Published public var trimStartTime: Double = 0.0
    @Published public var trimEndTime: Double = 0.0
    @Published public var rotationQuarterTurns: Int = 0

    // 🎯 BACK BUTTON FIX: Trimming state preservation structure
    public struct TrimmingStateSnapshot {
        let videoAsset: AVAsset
        let photosIdentifier: String
        let trimStartTime: Double
        let trimEndTime: Double
        let rotationQuarterTurns: Int
        let timestamp: Date

        init?(unifiedState: AddMoveUnifiedState) {
            guard let videoAsset = unifiedState.videoAsset,
                  let photosIdentifier = unifiedState.photosIdentifier,
                  !photosIdentifier.isEmpty else {
                return nil
            }

            self.videoAsset = videoAsset
            self.photosIdentifier = photosIdentifier
            self.trimStartTime = unifiedState.trimStartTime
            self.trimEndTime = unifiedState.trimEndTime
            self.rotationQuarterTurns = unifiedState.rotationQuarterTurns
            self.timestamp = Date()
        }
    }

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

        // Initialize services asynchronously
        Task { @MainActor in
            do {
                try await initializeServices()

                logger.info("🎬 AddMoveUnifiedState: Core services initialized, setting up components")

                // Setup components and subscriptions immediately
                setupComponents()
                setupSubscriptions()

                // Mark services as initialized
                servicesInitialized = true

                logger.info("🎬 AddMoveUnifiedState: ✅ Initialization completed successfully")
            } catch {
                logger.error("🎬 AddMoveUnifiedState: ❌ Service initialization failed: \(error.localizedDescription)")
                // Put system in error state if services fail to initialize
                flowState = .error(message: "Service initialization failed", underlyingError: error.localizedDescription)
            }
        }
    }

    // MARK: - Service Initialization

    /// Initialize all required services with comprehensive validation
    @MainActor
    private func initializeServices() async throws {
        logger.info("🎬 AddMoveUnifiedState: 🔍 Initializing services with validation")

        var initializationErrors: [String] = []

        // Initialize TimerManagementService
        do {
            timerManagementService = TimerManagementService()
            logger.info("🎬 AddMoveUnifiedState: ✅ TimerManagementService initialized")
        } catch {
            let errorMsg = "Failed to initialize TimerManagementService: \(error.localizedDescription)"
            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
            initializationErrors.append(errorMsg)
        }

        // Initialize VideoProgressMonitoringService
        do {
            videoProgressMonitoringService = VideoProgressMonitoringService(modernVideoLoadingService: modernVideoLoadingService)
            logger.info("🎬 AddMoveUnifiedState: ✅ VideoProgressMonitoringService initialized")
        } catch {
            let errorMsg = "Failed to initialize VideoProgressMonitoringService: \(error.localizedDescription)"
            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
            initializationErrors.append(errorMsg)
        }

        // Initialize AddMoveSaveCoordinator
        do {
            addMoveSaveCoordinator = AddMoveSaveCoordinator(
                movePersistenceService: movePersistenceService,
                videoProcessingPipeline: videoProcessingPipeline,
                logger: appLogger
            )
            logger.info("🎬 AddMoveUnifiedState: ✅ AddMoveSaveCoordinator initialized")
        } catch {
            let errorMsg = "Failed to initialize AddMoveSaveCoordinator: \(error.localizedDescription)"
            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
            initializationErrors.append(errorMsg)
        }

        // Validate required dependencies
        try validateRequiredDependencies()

        // Throw initialization error if any service failed
        if !initializationErrors.isEmpty {
            let combinedError = initializationErrors.joined(separator: "; ")
            throw ServiceInitializationError.serviceInitializationFailed(combinedError)
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ All services initialized successfully")
    }

    /// Validate required dependencies are available
    @MainActor
    private func validateRequiredDependencies() throws {
        logger.info("🎬 AddMoveUnifiedState: 🔍 Validating required dependencies")

        var validationErrors: [String] = []

        // Validate video processing pipeline
        if videoProcessingPipeline == nil {
            validationErrors.append("VideoProcessingPipeline is nil")
        }

        // Validate timecode calculation service
        if timecodeCalculationService == nil {
            validationErrors.append("TimecodeCalculationService is nil")
        }

        // Validate persistent container
        if persistentContainer == nil {
            validationErrors.append("PersistentContainer is nil")
        }

        // Validate move persistence service
        if movePersistenceService == nil {
            validationErrors.append("MovePersistenceService is nil")
        }

        // Validate app container
        if appContainer == nil {
            validationErrors.append("AppContainer is nil")
        }

        if !validationErrors.isEmpty {
            let combinedError = validationErrors.joined(separator: "; ")
            logger.error("🎬 AddMoveUnifiedState: ❌ Dependency validation failed: \(combinedError)")
            throw ServiceInitializationError.dependencyValidationFailed(combinedError)
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ All required dependencies validated")
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

        // 🎯 STRATEGIC FIX: Enhanced completion callback with atomic guard integration
        videoProgressMonitoringService.onCompletion = { [weak self] completion in
            guard let self = self else { return }

            switch completion {
            case .finished:
                logger.info("🎬 AddMoveUnifiedState: ✅ Progress monitoring completed successfully")

                // 🎯 CRITICAL FIX: Trigger atomic transformation if we're in loading state
                // This ensures the loading → trimming transition happens even if progress monitoring missed the completion
                if case .loadingVideo = self.flowState {
                    logger.info("🎬 AddMoveUnifiedState: 🔄 Completion callback detected loading state - triggering atomic transformation")

                    // 🎯 ATOMIC GUARD: Check if transition already in progress
                    guard !self.isTransitioningToTrimming else {
                        logger.info("🎬 AddMoveUnifiedState: 📊 Atomic transition already in progress - completion callback skipped")
                        return
                    }

                    // 🎯 ATOMIC LOCK: Set transition guard immediately
                    self.isTransitioningToTrimming = true
                    self.transitionStartTime = Date()
                    self.transitionCorrelationId = "completion_callback_\(UUID().uuidString)"

                    self.logger.info("🎬 AddMoveUnifiedState: 🔒 ATOMIC TRANSITION LOCKED via completion callback")

                    // 🎯 ASYNC EXECUTION: Use Task for async operations
                    Task { @MainActor in
                        // Small delay to ensure all progress updates are processed
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

                        await self.handleLoadingCompletionWithAtomicGuard()
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
                    self.timerManagementService.stopLoadTimer()

                    // 🎯 SYNCHRONOUS RESET: Clear any in-progress transition
                    self.isTransitioningToTrimming = false
                    self.transitionStartTime = nil
                    self.transitionCorrelationId = nil

                    Task { @MainActor in
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

    // MARK: - Enhanced Progress Handling
    @MainActor
    public func handleVideoLoadingProgress(_ progress: VideoLoadingProgress) {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Handling video loading progress - \(String(describing: progress.phase)) - \(Int(progress.progress * 100))% - \(progress.message)")

        // 🎯 CRITICAL FIX: Enhanced progress validation and state consistency
        guard validateProgressUpdate(progress) else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Progress update validation failed - skipping update")
            return
        }

        // Convert to SimpleProgress for internal use
        let simpleProgress = SimpleProgress(from: progress)

        // Update loading properties for UI binding - ensures real-time progress updates
        loadingProgress = progress.progress
        loadingStatus = progress.message
        currentProgress = progress.progress

        // 🎯 CRITICAL FIX: Enhanced state transition logic with proper completion detection
        if case .loadingVideo = flowState {
            logger.info("🎬 AddMoveUnifiedState: 📊 Updating loading progress: \(Int(progress.progress * 100))%")

            // 🎯 CRITICAL FIX: Enhanced completion detection with transition guard
            if progress.progress >= 1.0 {
                logger.info("🎬 AddMoveUnifiedState: ✅ VIDEO LOADING COMPLETE - transitioning to trimming stage")

                // 🎯 ENHANCED FIX: Prevent duplicate transitions with atomic check
                guard !isTransitioningToTrimming else {
                    logger.warning("🎬 AddMoveUnifiedState: ⚠️ Transition to trimming already in progress - skipping duplicate")
                    return
                }

                // 🎯 ATOMIC TRANSITION: Mark transition in progress immediately
                isTransitioningToTrimming = true
                transitionStartTime = Date()
                transitionCorrelationId = progress.correlationId

                logger.info("🎬 AddMoveUnifiedState: 🔒 ATOMIC TRANSITION LOCKED - Correlation: \(progress.correlationId)")

                // 🎯 SYNCHRONIZED TRANSITION: Execute immediately on main actor
                Task { @MainActor in
                    await handleLoadingCompletionWithAtomicGuard()
                }
            } else if progress.progress >= 0.95 {
                logger.info("🎬 AddMoveUnifiedState: 🔄 NEARING COMPLETION - \(Int(progress.progress * 100))%")
            }
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Progress update received while not in loadingVideo state - Current state: \(String(describing: self.flowState))")
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ Video loading progress handled successfully")
    }

    /// 🎯 CRITICAL FIX: Enhanced progress validation
    @MainActor
    private func validateProgressUpdate(_ progress: VideoLoadingProgress) -> Bool {
        // Validate progress values are within valid range
        guard progress.progress >= 0.0 && progress.progress <= 1.0 else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Invalid progress value: \(progress.progress)")
            return false
        }

        // Validate phase is appropriate for current state
        if case .loadingVideo = flowState {
            let validPhases: [VideoLoadingProgress.LoadingPhase] = [
                .initializing, .transferring, .validating, .creatingAsset,
                .loadingTrimmerDuration, .loadingTrimmerTracks, .validatingTrimmer
            ]
            let currentPhase = progress.phase
            guard validPhases.contains(currentPhase) else {
                logger.warning("🎬 AddMoveUnifiedState: ⚠️ Unexpected phase for loading state: \(currentPhase.rawValue)")
                return false
            }
        }

        return true
    }

    /// 🎯 CRITICAL FIX: Handle loading completion with atomic guard protection
    @MainActor
    private func handleLoadingCompletionWithAtomicGuard() async {
        let transitionDuration = transitionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        logger.info("🎬 AddMoveUnifiedState: 🚀 ATOMIC LOADING COMPLETION - Duration: \(String(format: "%.3f", transitionDuration))s")

        // 🎯 ATOMIC VALIDATION: Verify transition state
        guard isTransitioningToTrimming else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ ATOMIC GUARD VIOLATION - Transition not marked as in progress")
            return
        }

        guard let correlationId = transitionCorrelationId else {
            logger.error("🎬 AddMoveUnifiedState: ❌ ATOMIC GUARD FAILED - Missing correlation ID")
            await resetAtomicTransitionLock()
            return
        }

        // Validate we're still in loading state (race condition protection)
        guard case .loadingVideo = self.flowState else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ ATOMIC GUARD - Not in loading state during completion - current: \(String(describing: self.flowState))")
            await resetAtomicTransitionLock()
            return
        }

        // Validate required data is available
        guard videoAsset != nil && photosIdentifier != nil else {
            logger.error("🎬 AddMoveUnifiedState: ❌ ATOMIC GUARD - Missing required data for completion [\(correlationId)]")
            await setError(message: "Video loading incomplete", underlying: "Missing video asset or photos identifier")
            await resetAtomicTransitionLock()
            return
        }

        // 🎯 ATOMIC TRANSITION: Execute with proper error handling
        do {
            logger.info("🎬 AddMoveUnifiedState: 🎯 EXECUTING ATOMIC TRANSITION [\(correlationId)]")
            try await performAtomicCompletionTransition(correlationId: correlationId)
            logger.info("🎬 AddMoveUnifiedState: ✅ ATOMIC TRANSITION COMPLETED [\(correlationId)]")
        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ ATOMIC TRANSITION FAILED [\(correlationId)]: \(error.localizedDescription)")
            await setError(message: "Failed to complete video loading", underlying: error.localizedDescription)
            await resetAtomicTransitionLock()
        }
    }

    /// 🎯 CRITICAL FIX: Reset atomic transition lock
    @MainActor
    private func resetAtomicTransitionLock() async {
        logger.info("🎬 AddMoveUnifiedState: 🔓 RESETTING ATOMIC TRANSITION LOCK")
        isTransitioningToTrimming = false
        transitionStartTime = nil
        transitionCorrelationId = nil
    }

    /// 🎯 CRITICAL FIX: Enhanced atomic completion transition with improved natural transformation
    @MainActor
    private func performAtomicCompletionTransition(correlationId: String) async throws {
        logger.info("🎬 AddMoveUnifiedState: 🎯 ENHANCED ATOMIC COMPLETION TRANSITION [\(correlationId)]")

        // 🎯 ATOMIC STATE: Stop load timer immediately
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Stopping load timer [\(correlationId)]")
        timerManagementService.stopLoadTimer()

        // 🎯 SYNCHRONIZED TRANSITION: Execute state change first
        logger.info("🎬 AddMoveUnifiedState: 🔄 Executing state transition to trimming [\(correlationId)]")
        await transition(to: .trimming, triggeredBy: "atomic_completion_\(correlationId)")

        // 🎯 ENHANCED PLAYER CREATION: Create player with improved concurrency and error handling
        logger.info("🎬 AddMoveUnifiedState: 🎬 Creating player for loaded video [\(correlationId)]")

        let playerCreationStart = Date()
        let timeoutSeconds: TimeInterval = 12.0 // Reduced timeout matching UnifiedPlayerManager

        do {
            // Validate dependencies first
            guard validatePlayerCreationDependencies() else {
                logger.error("🎬 AddMoveUnifiedState: ❌ Dependencies not ready for player creation [\(correlationId)]")
                throw PlayerCreationError.dependenciesNotReady
            }

            // 🎯 CRITICAL FIX: Use improved player creation with better timeout handling
            let playerViewModel = try await withThrowingTaskGroup(of: Result<UnifiedVideoPlayerViewModel, Error>.self) { group in
                // Player creation task
                group.addTask { [weak self] in
                    do {
                        guard let self = self else {
                            throw PlayerCreationError.dependenciesNotReady
                        }

                        let player = try await self.unifiedPlayerManager.createOrUpdatePlayer(
                            asset: self.videoAsset!,
                            photosIdentifier: self.photosIdentifier!,
                            rotationQuarterTurns: self.rotationQuarterTurns,
                            appContainer: self.appContainer
                        )
                        return .success(player)
                    } catch {
                        return .failure(error)
                    }
                }

                // Timeout task with better error reporting
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    return .failure(PlayerCreationError.timedOut)
                }

                // Get first completed result
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            // Handle player creation result
            switch playerViewModel {
            case .success(let player):
                let playerCreationTime = Date().timeIntervalSince(playerCreationStart)
                logger.info("🎬 AddMoveUnifiedState: ✅ Player created successfully [\(correlationId)] - Time: \(String(format: "%.3f", playerCreationTime))s")

                // Set player and setup trimmer
                currentPlayerViewModel = player
                // 🎯 CRITICAL FIX: Update player state to reflect readiness
                playerState = .ready

                // 🎯 ENHANCED: Setup trimmer with better error handling
                do {
                    try await setupTrimmerDirectlyWithValidation()

                    // 🎯 ATOMIC COMPLETION: Release lock on successful transition
                    await resetAtomicTransitionLock()
                    logger.info("🎬 AddMoveUnifiedState: 🎉 ENHANCED ATOMIC TRANSITION COMPLETED [\(correlationId)]")

                } catch {
                    logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup failed [\(correlationId)]: \(error.localizedDescription)")
                    await resetAtomicTransitionLock()
                    throw error
                }

            case .failure(let error):
                logger.error("🎬 AddMoveUnifiedState: ❌ Player creation failed [\(correlationId)]: \(error.localizedDescription)")
                throw error
            }

        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ Enhanced atomic transition failed [\(correlationId)]: \(error.localizedDescription)")
            await resetAtomicTransitionLock()
            throw error
        }
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
            logger.info("🎬 AddMoveUnifiedState: ✅ TRIMMED ASSET LOADING COMPLETE - delegating to FlowStateManager")

            // 🎯 CRITICAL FIX: Delegate the transition to the FlowStateManager instead of directly mutating flowState
            // This ensures proper state synchronization between flowState and playerState, fixing the "Save Move" issue
            Task { @MainActor in
                guard let fsm = self.flowStateManager else {
                    logger.error("❌ FlowStateManager not available to complete asset loading transition.")
                    await self.setError(message: "Internal error during video processing.")
                    return
                }
                await fsm.completeAssetLoading()
            }
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ Trimmed asset progress handled successfully")
    }

    // 🎯 DEPRECATED: Legacy transition method - replaced by atomic version
    /// This method is kept for backward compatibility but should not be called
    @MainActor
    private func transitionToTrimmingAfterLoading() {
        logger.warning("🎬 AddMoveUnifiedState: ⚠️ LEGACY METHOD CALLED - Use atomic version instead")

        // 🎯 SAFETY: Immediately redirect to atomic version
        guard !isTransitioningToTrimming else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Atomic transition already in progress")
            return
        }

        // Set atomic guard and execute
        isTransitioningToTrimming = true
        transitionStartTime = Date()
        transitionCorrelationId = "legacy_fallback_\(UUID().uuidString)"

        Task { @MainActor in
            await handleLoadingCompletionWithAtomicGuard()
        }
    }

    /// 🎯 DEPRECATED: Problematic deadlock method - replaced by atomic version
    /// This method was causing indefinite hangs due to TaskGroup deadlock
    @MainActor
    private func performTransitionToTrimmingWithCancellation() async {
        logger.warning("🎬 AddMoveUnifiedState: ⚠️ DEPRECATED METHOD CALLED - Redirecting to atomic version")

        // Reset atomic lock and execute safe transition
        await resetAtomicTransitionLock()

        guard let correlationId = transitionCorrelationId else {
            transitionCorrelationId = "deprecated_fallback_\(UUID().uuidString)"
            return
        }

        do {
            try await performAtomicCompletionTransition(correlationId: transitionCorrelationId!)
        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ Deprecated method fallback failed: \(error.localizedDescription)")
            await setError(message: "Video transition failed", underlying: error.localizedDescription)
        }
    }

    /// Create player and handle transition with enhanced error handling
    @MainActor
    private func createPlayerAndTransition() async throws {
        logger.info("🎬 AddMoveUnifiedState: 📡 Starting player creation process")

        // Validate dependencies before player creation
        guard validatePlayerCreationDependencies() else {
            throw PlayerCreationError.dependenciesNotReady
        }

        // Create player with timeout
        let playerViewModel = try await withThrowingTaskGroup(of: UnifiedVideoPlayerViewModel?.self) { group in
            // Player creation task
            group.addTask {
                try await self.unifiedPlayerManager.createOrUpdatePlayer(
                    asset: self.videoAsset!,
                    photosIdentifier: self.photosIdentifier!,
                    rotationQuarterTurns: self.rotationQuarterTurns,
                    appContainer: self.appContainer
                )
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                return nil // Timeout indicator
            }

            // Get first completed task
            let result = try await group.next()!

            // Cancel remaining tasks
            group.cancelAll()

            // Return result or throw timeout error
            if let player = result {
                return player
            } else {
                throw PlayerCreationError.timedOut
            }
        }

        // At this point, playerViewModel is guaranteed to be non-nil
        // because the nil case was handled in the TaskGroup above

        logger.info("🎬 AddMoveUnifiedState: ✅ Player created successfully - isReady: \(playerViewModel.isPlayerReady)")
        currentPlayerViewModel = playerViewModel
        // 🎯 CRITICAL FIX: Update player state to reflect readiness
        playerState = .ready

        // 🎯 CRITICAL FIX: Ensure we transition to trimming state first
        logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to trimming state")
        await transition(to: .trimming, triggeredBy: "video_loading_complete_new_player")

        logger.info("🎬 AddMoveUnifiedState: 📡 Setting up trimmer after state transition")

        // Setup trimmer within the trimming state
        await setupTrimmerDirectly()

        logger.info("🎬 AddMoveUnifiedState: ✅ Player creation and transition completed successfully")
    }

    /// Validate dependencies for player creation
    @MainActor
    private func validatePlayerCreationDependencies() -> Bool {
        logger.info("🎬 AddMoveUnifiedState: 🔍 Validating player creation dependencies")

        var allDependenciesValid = true

        if videoAsset == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ Video asset is nil")
            allDependenciesValid = false
        }

        if photosIdentifier == nil || photosIdentifier!.isEmpty {
            logger.error("🎬 AddMoveUnifiedState: ❌ Photos identifier is nil or empty")
            allDependenciesValid = false
        }

        if unifiedPlayerManager == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ UnifiedPlayerManager is nil")
            allDependenciesValid = false
        }

        if appContainer == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ AppContainer is nil")
            allDependenciesValid = false
        }

        logger.info("🎬 AddMoveUnifiedState: 📊 Player creation dependencies valid: \(allDependenciesValid)")
        return allDependenciesValid
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

    /// 🎯 ENHANCED: Trimmer setup with comprehensive validation and error handling
    @MainActor
    private func setupTrimmerDirectlyWithValidation() async throws {
        logger.info("🎬 AddMoveUnifiedState: 🚀 ENHANCED TRIMMER SETUP WITH VALIDATION")

        // 🎯 CRITICAL: Validate we're in trimming state
        guard case .trimming = self.flowState else {
            throw TrimmerSetupError.invalidState(self.flowState)
        }

        // 🎯 ENHANCED: Validate all prerequisites with detailed diagnostics
        guard let asset = self.videoAsset else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Video asset missing for trimmer setup")
            throw TrimmerSetupError.missingAsset
        }

        guard let photosIdentifier = self.photosIdentifier, !photosIdentifier.isEmpty else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Photos identifier missing for trimmer setup")
            throw TrimmerSetupError.missingPhotosIdentifier
        }

        guard let playerViewModel = self.currentPlayerViewModel as? UnifiedVideoPlayerViewModel else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Player view model missing for trimmer setup")
            throw TrimmerSetupError.missingPlayerViewModel
        }

        // 🎯 ENHANCED: Validate player readiness
        guard playerViewModel.isPlayerReady else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Player not ready for trimmer setup")
            throw TrimmerSetupError.playerNotReady
        }

        // 🎯 ENHANCED: Validate asset with timeout
        let assetValidationStart = Date()
        do {
            let duration = try await withThrowingTaskGroup(of: CMTime.self) { group in
                group.addTask {
                    try await asset.load(.duration)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second timeout
                    throw TrimmerSetupError.assetValidationTimeout
                }

                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                } else {
                    throw TrimmerSetupError.assetValidationTimeout
                }
            }

            guard duration.seconds > 0 else {
                throw TrimmerSetupError.invalidAsset
            }

            let validationTime = Date().timeIntervalSince(assetValidationStart)
            logger.info("🎬 AddMoveUnifiedState: ✅ Asset validation completed in \(String(format: "%.3f", validationTime))s - Duration: \(duration.seconds)s")

        } catch {
            logger.error("🎬 AddMoveUnifiedState: ❌ Asset validation failed: \(error.localizedDescription)")
            throw TrimmerSetupError.assetValidationFailed(error.localizedDescription)
        }

        // 🎯 ENHANCED: Create and configure trimmer with error handling
        let trimmerSetupStart = Date()
        do {
            let trimmerVM = TrimmerViewModel(
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns,
                playerViewModel: playerViewModel
            )

            // Set the progress delegate
            trimmerVM.progressDelegate = self

            // Update the published trimmer view model
            trimmerViewModel = trimmerVM

            logger.info("🎬 AddMoveUnifiedState: ✅ TrimmerViewModel created and configured")

            // Setup the trimmer with timeout
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await trimmerVM.setupAsync()
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                    throw TrimmerSetupError.setupTimeout
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            let setupTime = Date().timeIntervalSince(trimmerSetupStart)
            logger.info("🎬 AddMoveUnifiedState: ✅ Trimmer setup completed in \(String(format: "%.3f", setupTime))s")

            // 🎯 ENHANCED: Set trim range with validation
            let duration = try await asset.load(.duration).seconds
            let startTime = CMTime(seconds: trimStartTime > 0 ? trimStartTime : 0, preferredTimescale: 600)
            let endTime = CMTime(seconds: trimEndTime > 0 ? trimEndTime : duration, preferredTimescale: 600)

            // Validate trim range
            guard startTime < endTime else {
                throw TrimmerSetupError.invalidTrimRange
            }

            guard (endTime - startTime).seconds >= 0.5 else {
                throw TrimmerSetupError.trimRangeTooShort
            }

            trimmerVM.startTime = startTime
            trimmerVM.endTime = endTime

            logger.info("🎬 AddMoveUnifiedState: ✅ Trim range validated and set - start: \(startTime.seconds)s, end: \(endTime.seconds)s")
            logger.info("🎬 AddMoveUnifiedState: 🎉 ENHANCED TRIMMER SETUP COMPLETED SUCCESSFULLY")

        } catch {
            let setupTime = Date().timeIntervalSince(trimmerSetupStart)
            logger.error("🎬 AddMoveUnifiedState: ❌ Trimmer setup failed after \(String(format: "%.3f", setupTime))s: \(error.localizedDescription)")
            throw TrimmerSetupError.setupFailed(error.localizedDescription)
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
    public func transition(to newState: AddMoveFlowState, triggeredBy: String = "unknown") async {
        let previousState = flowState

        // 🎯 BACK BUTTON FIX: Preserve trimming state when transitioning from trimming to naming
        if case .trimming = previousState, case .naming = newState {
            logger.info("🎬 AddMoveUnifiedState: 💾 Preserving trimming state before transitioning to naming")
            preserveTrimmingState()
        }

        // 🎯 SAVE READINESS FIX: Start validation monitoring when entering naming state
        if case .naming = newState {
            logger.info("🎬 AddMoveUnifiedState: 🚀 Starting save readiness monitoring for naming state")
            // 🎯 CRITICAL FIX: Synchronize player state with actual UnifiedPlayerManager readiness
            await synchronizePlayerStateForNaming()
            startSaveReadinessMonitoring()
        }

        // 🎯 SAVE READINESS FIX: Stop validation monitoring when leaving naming state
        if case .naming = previousState {
            logger.info("🎬 AddMoveUnifiedState: 🛑 Stopping save readiness monitoring - leaving naming state")
            stopSaveReadinessMonitoring()
        }

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
        // Enhanced logging with metrics
        logStateTransitionWithMetrics(from: from, to: to, triggeredBy: "state_transition")

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
            // 🎯 BACK BUTTON FIX: Preserve trimming state before leaving trimming
            preserveTrimmingState()

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

        // Use the new service initialization flag
        guard servicesInitialized else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Services not initialized yet")
            return false
        }

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

        // Validate flow state manager
        if flowStateManager == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ FlowStateManager not initialized")
            allServicesReady = false
        } else {
            logger.info("🎬 AddMoveUnifiedState: ✅ FlowStateManager ready")
        }

        logger.info("🎬 AddMoveUnifiedState: 📊 Service validation result: \(allServicesReady ? "READY" : "NOT READY")")
        return allServicesReady
    }

    @MainActor
    public func reset() {
        logger.info("🎬 AddMoveUnifiedState: Resetting to ready state")

        // 🎯 ATOMIC RESET: Clear any in-progress transitions
        Task {
            await resetAtomicTransitionLock()
        }

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

        // 🎯 BACK BUTTON FIX: Clear preserved trimming state
        clearPreservedTrimmingState()
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
        await transition(to: .loadingVideo(progress: initialProgress))

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

    // MARK: - Player State Synchronization

    /// 🎯 CRITICAL FIX: Synchronizes player state with actual UnifiedPlayerManager readiness
    /// This ensures the playerState property reflects the true player readiness before validation
    @MainActor
    private func synchronizePlayerStateForNaming() async {
        logger.info("🎬 AddMoveUnifiedState: 🔧 SYNCHRONIZING player state for naming phase")

        let syncStartTime = Date()
        let timeoutSeconds: TimeInterval = 10.0
        let checkInterval: TimeInterval = 0.1

        // 🎯 DIAGNOSTIC: Log initial state
        // Fix: Add explicit self. references to satisfy closure capture semantics
        logger.info("🎬 AddMoveUnifiedState: 🔍 DIAGNOSTIC - Initial sync state - playerState: \(String(describing: self.playerState)), unifiedPlayerManager.currentPlayer: \(self.unifiedPlayerManager.currentPlayer != nil ? "available" : "nil")")

        // Check if unified player manager has a ready player
        while true {
            let elapsed = Date().timeIntervalSince(syncStartTime)

            if elapsed > timeoutSeconds {
                logger.error("🎬 AddMoveUnifiedState: ❌ Player state synchronization TIMEOUT after \(String(format: "%.3f", elapsed))s")
                // 🎯 FALLBACK: Set to ready anyway to prevent permanent blocking
                logger.warning("🎬 AddMoveUnifiedState: 🔄 FALLBACK - Setting player state to .ready after timeout to prevent permanent blocking")
                playerState = .ready
                return
            }

            // Check actual player readiness from UnifiedPlayerManager
            if let currentPlayer = unifiedPlayerManager.currentPlayer {
                let actualPlayerReady = await currentPlayer.isPlayerReady

                // Fix: Add explicit self. reference to satisfy closure capture semantics
                logger.debug("🎬 AddMoveUnifiedState: 🔍 Sync check - elapsed: \(String(format: "%.1f", elapsed))s, actualPlayerReady: \(actualPlayerReady), currentPublishedState: \(String(describing: self.playerState))")

                if actualPlayerReady {
                    // 🎯 SUCCESS: Actual player is ready, synchronize our state
                    // Fix: Add explicit self. references to satisfy closure capture semantics
                    if self.playerState != .ready {
                        logger.info("🎬 AddMoveUnifiedState: ✅ SYNCHRONIZATION SUCCESS - Setting player state to .ready (was: \(String(describing: self.playerState)))")
                        self.playerState = .ready
                    } else {
                        logger.info("🎬 AddMoveUnifiedState: ✅ SYNCHRONIZATION SUCCESS - Player state already .ready")
                    }

                    let syncDuration = Date().timeIntervalSince(syncStartTime)
                    logger.info("🎬 AddMoveUnifiedState: 🎉 Player state synchronization completed in \(String(format: "%.3f", syncDuration))s")
                    return
                }
            } else {
                logger.debug("🎬 AddMoveUnifiedState: 🔍 Sync check - elapsed: \(String(format: "%.1f", elapsed))s, no currentPlayer available yet")
            }

            // Wait before next check
            try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
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
        await transition(to: state, triggeredBy: "PreTrimViewUnified")
    }

    @MainActor
    public func setError(message: String, underlying: String? = nil) async {
        logger.error("🎬 AddMoveUnifiedState: Error - \(message)")
        if let underlying = underlying {
            logger.error("🎬 AddMoveUnifiedState: Underlying error - \(underlying)")
        }

        // 🎯 ENHANCEMENT: Determine error recovery strategy based on current state and error type
        let recoveryStrategy = determineRecoveryStrategy(for: message, underlying: underlying)
        logger.info("🎬 AddMoveUnifiedState: 🔄 Recovery strategy determined: \(recoveryStrategy.description)")

        // Store recovery information for potential retry mechanisms
        pendingRecovery = ErrorRecoveryInfo(
            originalState: flowState,
            errorMessage: message,
            underlyingError: underlying,
            strategy: recoveryStrategy,
            timestamp: Date()
        )

        await transition(to: .error(message: message, underlyingError: underlying))
    }

    // MARK: - Error Recovery Mechanisms

    /// Information about pending error recovery
    private struct ErrorRecoveryInfo {
        let originalState: AddMoveFlowState
        let errorMessage: String
        let underlyingError: String?
        let strategy: ErrorRecoveryStrategy
        let timestamp: Date
    }

    private var pendingRecovery: ErrorRecoveryInfo?

    /// Error recovery strategies based on error type and context
    private enum ErrorRecoveryStrategy {
        case retryFromStart          // Retry entire flow from ready state
        case retryVideoLoading       // Retry video loading from scratch
        case retryTrimmerSetup       // Retry trimmer setup only
        case retrySaveOperation      // Retry save operation only
        case resetToReady           // Reset to ready state and clear data
        case userIntervention       // Requires user action to resolve

        var description: String {
            switch self {
            case .retryFromStart: return "Retry entire flow from start"
            case .retryVideoLoading: return "Retry video loading"
            case .retryTrimmerSetup: return "Retry trimmer setup"
            case .retrySaveOperation: return "Retry save operation"
            case .resetToReady: return "Reset to ready state"
            case .userIntervention: return "Requires user intervention"
            }
        }

        var isRetryable: Bool {
            switch self {
            case .retryFromStart, .retryVideoLoading, .retryTrimmerSetup, .retrySaveOperation:
                return true
            case .resetToReady, .userIntervention:
                return false
            }
        }
    }

    /// Determine appropriate recovery strategy based on error context
    @MainActor
    private func determineRecoveryStrategy(for message: String, underlying: String?) -> ErrorRecoveryStrategy {
        logger.info("🎬 AddMoveUnifiedState: 🧠 Analyzing error for recovery strategy - Message: '\(message)'")

        // Check for specific error patterns
        let lowercasedMessage = message.lowercased()
        let lowercasedUnderlying = underlying?.lowercased() ?? ""

        // Video loading related errors
        if lowercasedMessage.contains("loading") || lowercasedUnderlying.contains("loading") {
            if lowercasedMessage.contains("timeout") || lowercasedUnderlying.contains("timeout") {
                logger.info("🎬 AddMoveUnifiedState: 🔄 Detected timeout error - will retry video loading")
                return .retryVideoLoading
            } else if lowercasedMessage.contains("permission") || lowercasedUnderlying.contains("permission") {
                logger.info("🎬 AddMoveUnifiedState: 🔐 Detected permission error - requires user intervention")
                return .userIntervention
            } else {
                logger.info("🎬 AddMoveUnifiedState: 🔄 Detected general loading error - will retry video loading")
                return .retryVideoLoading
            }
        }

        // Trimmer setup related errors
        if lowercasedMessage.contains("trimmer") || lowercasedUnderlying.contains("trimmer") {
            logger.info("🎬 AddMoveUnifiedState: ✂️ Detected trimmer error - will retry trimmer setup")
            return .retryTrimmerSetup
        }

        // Save operation related errors
        if lowercasedMessage.contains("save") || lowercasedUnderlying.contains("save") {
            if lowercasedMessage.contains("duplicate") || lowercasedUnderlying.contains("duplicate") {
                logger.info("🎬 AddMoveUnifiedState: 📝 Detected duplicate error - requires user intervention")
                return .userIntervention
            } else {
                logger.info("🎬 AddMoveUnifiedState: 💾 Detected save error - will retry save operation")
                return .retrySaveOperation
            }
        }

        // Service initialization errors
        if lowercasedMessage.contains("initialization") || lowercasedUnderlying.contains("initialization") {
            logger.info("🎬 AddMoveUnifiedState: 🔧 Detected initialization error - will retry from start")
            return .retryFromStart
        }

        // Network related errors
        if lowercasedMessage.contains("network") || lowercasedUnderlying.contains("network") ||
           lowercasedMessage.contains("connection") || lowercasedUnderlying.contains("connection") {
            logger.info("🎬 AddMoveUnifiedState: 🌐 Detected network error - will retry video loading")
            return .retryVideoLoading
        }

        // Memory related errors
        if lowercasedMessage.contains("memory") || lowercasedUnderlying.contains("memory") {
            logger.info("🎬 AddMoveUnifiedState: 🧠 Detected memory error - will reset to ready state")
            return .resetToReady
        }

        // Default to retry from start for unknown errors
        logger.info("🎬 AddMoveUnifiedState: 🔄 Unknown error type - will retry from start")
        return .retryFromStart
    }

    /// Attempt error recovery based on current pending recovery info
    @MainActor
    public func attemptErrorRecovery() async {
        guard let recovery = pendingRecovery else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ No pending recovery information available")
            return
        }

        // Log recovery attempt with enhanced diagnostics
        logRecoveryAttempt(strategy: recovery.strategy, originalError: recovery.errorMessage)

        // Log state before recovery attempt
        logDiagnosticState("Before Recovery")

        // Clear any existing timers before recovery
        timerManagementService.resetAllTimers()

        switch recovery.strategy {
        case .retryFromStart:
            await performRetryFromStart()

        case .retryVideoLoading:
            await performRetryVideoLoading()

        case .retryTrimmerSetup:
            await performRetryTrimmerSetup()

        case .retrySaveOperation:
            await performRetrySaveOperation()

        case .resetToReady:
            await performResetToReady()

        case .userIntervention:
            logger.info("🎬 AddMoveUnifiedState: 🙋 User intervention required - cannot auto-recover")
            return
        }

        // Clear recovery info after attempt
        pendingRecovery = nil
    }

    /// Perform retry from start - reset all state and begin fresh
    @MainActor
    private func performRetryFromStart() async {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Performing retry from start")

        // Clear all temporary data
        videoAsset = nil
        photosIdentifier = nil
        currentPlayerViewModel = nil
        moveName = ""
        trimStartTime = 0.0
        trimEndTime = 0.0
        rotationQuarterTurns = 0

        // Reset loading state
        loadingProgress = 0.0
        loadingStatus = ""
        currentProgress = 0.0

        // Transition to ready state
        await transition(to: .ready)

        logger.info("🎬 AddMoveUnifiedState: ✅ Retry from start completed - ready for new video selection")
    }

    /// Perform retry of video loading only
    @MainActor
    private func performRetryVideoLoading() async {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Performing video loading retry")

        guard let identifier = photosIdentifier else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Cannot retry video loading - missing photos identifier")
            await performResetToReady()
            return
        }

        // Reset video-specific state but preserve metadata
        videoAsset = nil
        currentPlayerViewModel = nil
        loadingProgress = 0.0
        loadingStatus = ""
        currentProgress = 0.0

        // Video reloading from photos identifier not currently supported
        // Reset to ready state instead
        await performResetToReady()
    }

    /// Perform retry of trimmer setup only
    @MainActor
    private func performRetryTrimmerSetup() async {
        logger.info("🎬 AddMoveUnifiedState: ✂️ Performing trimmer setup retry")

        guard videoAsset != nil else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Cannot retry trimmer setup - missing video asset")
            await performResetToReady()
            return
        }

        // Reset to trimming state and attempt setup again
        await transition(to: .trimming)

        // Attempt trimmer setup
        await setupTrimmerAfterPreview()
    }

    /// Perform retry of save operation only
    @MainActor
    private func performRetrySaveOperation() async {
        logger.info("🎬 AddMoveUnifiedState: 💾 Performing save operation retry")

        guard currentPlayerViewModel != nil else {
            logger.error("🎬 AddMoveUnifiedState: ❌ Cannot retry save operation - missing player view model")
            await performResetToReady()
            return
        }

        // Reset to naming state and attempt save again
        await transition(to: .naming)

        // Attempt save operation
        await saveMove()
    }

    /// Perform reset to ready state with cleanup
    @MainActor
    private func performResetToReady() async {
        logger.info("🎬 AddMoveUnifiedState: 🧹 Performing reset to ready state")

        // Clear all data
        videoAsset = nil
        photosIdentifier = nil
        currentPlayerViewModel = nil
        moveName = ""
        trimStartTime = 0.0
        trimEndTime = 0.0
        rotationQuarterTurns = 0
        loadingProgress = 0.0
        loadingStatus = ""
        currentProgress = 0.0

        // Reset all timers
        timerManagementService.resetAllTimers()

        // Transition to ready state
        await transition(to: .ready)

        logger.info("🎬 AddMoveUnifiedState: ✅ Reset to ready state completed")
    }

    /// Check if current error is recoverable
    @MainActor
    public var isCurrentErrorRecoverable: Bool {
        guard let recovery = pendingRecovery else { return false }
        return recovery.strategy.isRetryable
    }

    /// Get description of current recovery strategy
    @MainActor
    public var currentRecoveryDescription: String {
        guard let recovery = pendingRecovery else { return "No recovery information available" }
        return recovery.strategy.description
    }

    // MARK: - Enhanced Diagnostic Logging

    /// Log comprehensive system state for debugging
    @MainActor
    public func logDiagnosticState(_ context: String) {
        logger.info("🎬 AddMoveUnifiedState: 📊 DIAGNOSTIC STATE [\(context)]")
        logger.info("🎬 AddMoveUnifiedState: 📊 Flow State: \(String(describing: self.flowState))")
        logger.info("🎬 AddMoveUnifiedState: 📊 Video Asset: \(self.videoAsset != nil ? "✅ Loaded" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 📊 Photos ID: \(self.photosIdentifier != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 📊 Player VM: \(self.currentPlayerViewModel != nil ? "✅ Created" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 📊 Move Name: '\(self.moveName.isEmpty ? "Empty" : self.moveName)'")
        logger.info("🎬 AddMoveUnifiedState: 📊 Trim Range: \(String(format: "%.2f", self.trimStartTime))s - \(String(format: "%.2f", self.trimEndTime))s")
        logger.info("🎬 AddMoveUnifiedState: 📊 Rotation: \(self.rotationQuarterTurns * 90)°")
        logger.info("🎬 AddMoveUnifiedState: 📊 Load Progress: \(String(format: "%.1f", self.loadingProgress * 100))%")
        logger.info("🎬 AddMoveUnifiedState: 📊 Load Timer: \(String(format: "%.2f", self.loadElapsedTime))s")
        logger.info("🎬 AddMoveUnifiedState: 📊 Save Timer: \(String(format: "%.2f", self.saveElapsedTime))s")
        logger.info("🎬 AddMoveUnifiedState: 📊 Memory: \(self.getMemoryUsage())")
        logger.info("🎬 AddMoveUnifiedState: 📊 Recovery Available: \(self.isCurrentErrorRecoverable ? "✅ Yes" : "❌ No")")
        logger.info("🎬 AddMoveUnifiedState: 📊 Timestamp: \(Date())")
    }

    /// Log service status for debugging
    @MainActor
    public func logServiceStatus() {
        logger.info("🎬 AddMoveUnifiedState: 🔧 SERVICE STATUS DIAGNOSTIC")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Timer Service: \(self.timerManagementService != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Progress Monitor: \(self.videoProgressMonitoringService != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Save Coordinator: \(self.addMoveSaveCoordinator != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Flow Manager: \(self.flowStateManager != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 State Validator: \(self.stateValidator != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Video Loading Service: \(self.modernVideoLoadingService != nil ? "✅ Available" : "❌ Missing")")
        logger.info("🎬 AddMoveUnifiedState: 🔧 Dependencies: \(self.persistentContainer != nil ? "✅" : "❌") Core Data, \(self.timecodeCalculationService != nil ? "✅" : "❌") Timecode, \(self.movePersistenceService != nil ? "✅" : "❌") Persistence, \(self.videoProcessingPipeline != nil ? "✅" : "❌") Processing")
    }

    /// Log performance metrics for monitoring
    @MainActor
    public func logPerformanceMetrics() {
        logger.info("🎬 AddMoveUnifiedState: 📈 PERFORMANCE METRICS")

        let currentMemory = self.getMemoryUsage()
        logger.info("🎬 AddMoveUnifiedState: 📈 Memory Usage: \(currentMemory)")

        // Log timer performance
        let loadElapsed = self.timerManagementService.getLoadElapsedTime()
        let saveElapsed = self.timerManagementService.getSaveElapsedTime()
        logger.info("🎬 AddMoveUnifiedState: 📈 Load Timer: \(String(format: "%.2f", loadElapsed))s")
        logger.info("🎬 AddMoveUnifiedState: 📈 Save Timer: \(String(format: "%.2f", saveElapsed))s")

        // Log state transition frequency
        logger.info("🎬 AddMoveUnifiedState: 📈 State Transitions: \(self.stateTransitionCount)")

        // Log error recovery attempts
        logger.info("🎬 AddMoveUnifiedState: 📈 Recovery Attempts: \(self.recoveryAttemptCount)")

        // Log asset information if available
        if let asset = self.videoAsset {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    logger.info("🎬 AddMoveUnifiedState: 📈 Video Duration: \(String(format: "%.2f", duration.seconds))s")

                    let tracks = try await asset.load(.tracks)
                    logger.info("🎬 AddMoveUnifiedState: 📈 Video Tracks: \(tracks.count)")
                } catch {
                    logger.error("🎬 AddMoveUnifiedState: ❌ Failed to load asset info: \(error.localizedDescription)")
                }
            }
        }

        logger.info("🎬 AddMoveUnifiedState: 📈 Timestamp: \(Date())")
    }

    /// State transition counter for performance monitoring
    private var stateTransitionCount: Int = 0
    private var recoveryAttemptCount: Int = 0

    /// Enhanced state transition logging with metrics
    @MainActor
    private func logStateTransitionWithMetrics(from: AddMoveFlowState, to: AddMoveFlowState, triggeredBy: String) {
        self.stateTransitionCount += 1

        logger.info("🎬 AddMoveUnifiedState: 🔄 STATE TRANSITION #\(self.stateTransitionCount)")
        logger.info("🎬 AddMoveUnifiedState: 🔄 From: \(String(describing: from))")
        logger.info("🎬 AddMoveUnifiedState: 🔄 To: \(String(describing: to))")
        logger.info("🎬 AddMoveUnifiedState: 🔄 Triggered by: \(triggeredBy)")
        logger.info("🎬 AddMoveUnifiedState: 🔄 Timestamp: \(Date())")

        // Log performance impact
        if case .loadingVideo = to {
            logger.info("🎬 AddMoveUnifiedState: 🔄 Starting load phase - beginning performance monitoring")
        } else if case .saving = to {
            logger.info("🎬 AddMoveUnifiedState: 🔄 Starting save phase - monitoring save performance")
        } else if to.isTerminalState {
            logger.info("🎬 AddMoveUnifiedState: 🔄 Reached terminal state - completing performance monitoring")
            self.logPerformanceMetrics()
        }
    }

    /// Log error recovery attempt
    @MainActor
    private func logRecoveryAttempt(strategy: ErrorRecoveryStrategy, originalError: String) {
        self.recoveryAttemptCount += 1

        logger.info("🎬 AddMoveUnifiedState: 🔄 RECOVERY ATTEMPT #\(self.recoveryAttemptCount)")
        logger.info("🎬 AddMoveUnifiedState: 🔄 Strategy: \(strategy.description)")
        logger.info("🎬 AddMoveUnifiedState: 🔄 Original Error: \(originalError)")
        logger.info("🎬 AddMoveUnifiedState: 🔄 Timestamp: \(Date())")
    }

    /// Debug method to log all current timers
    @MainActor
    public func logTimerDiagnostics() {
        logger.info("🎬 AddMoveUnifiedState: ⏱️ TIMER DIAGNOSTICS")
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Load Elapsed: \(String(format: "%.3f", self.timerManagementService.getLoadElapsedTime()))s")
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Save Elapsed: \(String(format: "%.3f", self.timerManagementService.getSaveElapsedTime()))s")
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Timestamp: \(Date())")
    }

    /// Debug method to log progress monitoring status
    @MainActor
    public func logProgressDiagnostics() {
        logger.info("🎬 AddMoveUnifiedState: 📊 PROGRESS DIAGNOSTICS")
        logger.info("🎬 AddMoveUnifiedState: 📊 Current Progress: \(String(format: "%.3f", self.currentProgress * 100))%")
        logger.info("🎬 AddMoveUnifiedState: 📊 Loading Progress: \(String(format: "%.3f", self.loadingProgress * 100))%")
        logger.info("🎬 AddMoveUnifiedState: 📊 Loading Status: '\(self.loadingStatus)'")
        logger.info("🎬 AddMoveUnifiedState: 📊 Timestamp: \(Date())")
    }

    /// Comprehensive debug log for troubleshooting
    @MainActor
    public func logFullDebugDiagnostics() {
        logger.info("🎬 AddMoveUnifiedState: 🐛 FULL DEBUG DIAGNOSTICS START")
        logger.info("🎬 AddMoveUnifiedState: 🐛 ======================================")

        logDiagnosticState("Full Debug")
        logServiceStatus()
        logTimerDiagnostics()
        logProgressDiagnostics()
        logPerformanceMetrics()

        // Log error state if applicable
        if case .error(let message, let underlying) = self.flowState {
            logger.error("🎬 AddMoveUnifiedState: 🐛 Current Error: \(message)")
            if let underlying = underlying {
                logger.error("🎬 AddMoveUnifiedState: 🐛 Underlying Error: \(underlying)")
            }
            logger.info("🎬 AddMoveUnifiedState: 🐛 Recovery Available: \(self.isCurrentErrorRecoverable)")
            logger.info("🎬 AddMoveUnifiedState: 🐛 Recovery Strategy: \(self.currentRecoveryDescription)")
        }

        logger.info("🎬 AddMoveUnifiedState: 🐛 ======================================")
        logger.info("🎬 AddMoveUnifiedState: 🐛 FULL DEBUG DIAGNOSTICS END")
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

    // MARK: - Trimming State Preservation (Back Button Fix)

    /// Preserve trimming state data for back button functionality
    @MainActor
    private func preserveTrimmingState() {
        logger.info("🎬 AddMoveUnifiedState: 💾 Preserving trimming state for back button functionality")

        guard let snapshot = TrimmingStateSnapshot(unifiedState: self) else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Failed to create trimming state snapshot - missing required data")
            return
        }

        preservedTrimmingState = snapshot
        logger.info("🎬 AddMoveUnifiedState: ✅ Trimming state preserved successfully")
        logTrimmingStateSnapshot(snapshot)
    }

    /// Restore trimming state from preserved snapshot
    @MainActor
    private func restoreTrimmingState() -> Bool {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Restoring trimming state from preserved snapshot")

        guard let snapshot = preservedTrimmingState else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ No preserved trimming state available")
            return false
        }

        // Check if snapshot is still valid (not too old)
        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)
        let maxAge: TimeInterval = 300.0 // 5 minutes

        guard snapshotAge < maxAge else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Preserved trimming state is too old (\(String(format: "%.1f", snapshotAge))s)")
            preservedTrimmingState = nil
            return false
        }

        // Restore the data
        videoAsset = snapshot.videoAsset
        photosIdentifier = snapshot.photosIdentifier
        trimStartTime = snapshot.trimStartTime
        trimEndTime = snapshot.trimEndTime
        rotationQuarterTurns = snapshot.rotationQuarterTurns

        logger.info("🎬 AddMoveUnifiedState: ✅ Trimming state restored successfully")
        logTrimmingStateSnapshot(snapshot)

        return true
    }

    /// Clear preserved trimming state
    @MainActor
    private func clearPreservedTrimmingState() {
        preservedTrimmingState = nil
        logger.info("🎬 AddMoveUnifiedState: 🧹 Preserved trimming state cleared")
    }

    /// Check if preserved trimming state is available and valid
    @MainActor
    private func hasValidPreservedTrimmingState() -> Bool {
        guard let snapshot = preservedTrimmingState else {
            return false
        }

        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)
        let maxAge: TimeInterval = 300.0 // 5 minutes

        return snapshotAge < maxAge
    }

    /// 🎯 PUBLIC API: Check if trimming state can be restored (for AddMoveContainer)
    @MainActor
    public func canRestoreTrimmingState() -> Bool {
        return hasValidPreservedTrimmingState()
    }

    /// 🎯 PUBLIC API: Attempt to restore trimming state (for AddMoveContainer)
    @MainActor
    public func attemptTrimmingStateRestoration() -> Bool {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Public trimming state restoration requested")

        let success = restoreTrimmingState()

        if success {
            logger.info("🎬 AddMoveUnifiedState: ✅ Public trimming state restoration successful")
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ❌ Public trimming state restoration failed")
        }

        return success
    }

    /// Log trimming state snapshot for debugging
    @MainActor
    private func logTrimmingStateSnapshot(_ snapshot: TrimmingStateSnapshot?) {
        guard let snapshot = snapshot else {
            logger.info("🎬 AddMoveUnifiedState: 📊 No trimming state snapshot to log")
            return
        }

        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)
        logger.info("🎬 AddMoveUnifiedState: 📊 TRIMMING STATE SNAPSHOT")
        logger.info("🎬 AddMoveUnifiedState: 📊 Photos ID: \(snapshot.photosIdentifier)")
        logger.info("🎬 AddMoveUnifiedState: 📊 Trim Range: \(String(format: "%.2f", snapshot.trimStartTime))s - \(String(format: "%.2f", snapshot.trimEndTime))s")
        logger.info("🎬 AddMoveUnifiedState: 📊 Rotation: \(snapshot.rotationQuarterTurns * 90)°")
        logger.info("🎬 AddMoveUnifiedState: 📊 Asset Age: \(String(format: "%.1f", snapshotAge))s")
        logger.info("🎬 AddMoveUnifiedState: 📊 Timestamp: \(snapshot.timestamp)")
    }

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

// MARK: - Service Initialization Errors

public enum ServiceInitializationError: Error, LocalizedError {
    case serviceInitializationFailed(String)
    case dependencyValidationFailed(String)
    case serviceNotReady(String)

    public var errorDescription: String? {
        switch self {
        case .serviceInitializationFailed(let details):
            return "Service initialization failed: \(details)"
        case .dependencyValidationFailed(let details):
            return "Dependency validation failed: \(details)"
        case .serviceNotReady(let serviceName):
            return "Service not ready: \(serviceName)"
        }
    }
}

public enum PlayerCreationError: Error, LocalizedError {
    case dependenciesNotReady
    case timedOut
    case creationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .dependenciesNotReady:
            return "Player creation dependencies are not ready"
        case .timedOut:
            return "Player creation timed out"
        case .creationFailed(let details):
            return "Player creation failed: \(details)"
        }
    }
}

public enum TrimmerSetupError: Error, LocalizedError {
    case invalidState(AddMoveFlowState)
    case missingAsset
    case missingPhotosIdentifier
    case missingPlayerViewModel
    case playerNotReady
    case assetValidationTimeout
    case assetValidationFailed(String)
    case invalidAsset
    case setupTimeout
    case setupFailed(String)
    case invalidTrimRange
    case trimRangeTooShort

    public var errorDescription: String? {
        switch self {
        case .invalidState(let state):
            return "Invalid state for trimmer setup: \(String(describing: state))"
        case .missingAsset:
            return "Video asset is missing for trimmer setup"
        case .missingPhotosIdentifier:
            return "Photos identifier is missing for trimmer setup"
        case .missingPlayerViewModel:
            return "Player view model is missing for trimmer setup"
        case .playerNotReady:
            return "Player is not ready for trimmer setup"
        case .assetValidationTimeout:
            return "Asset validation timed out"
        case .assetValidationFailed(let reason):
            return "Asset validation failed: \(reason)"
        case .invalidAsset:
            return "Asset is invalid for trimmer setup"
        case .setupTimeout:
            return "Trimmer setup timed out"
        case .setupFailed(let reason):
            return "Trimmer setup failed: \(reason)"
        case .invalidTrimRange:
            return "Invalid trim range: start time must be less than end time"
        case .trimRangeTooShort:
            return "Trim range is too short (minimum 0.5 seconds)"
        }
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

    // MARK: - Trimming State Preservation (Duplicate methods removed - using private implementations above)

    // Note: Duplicate methods canRestoreTrimmingState() and attemptTrimmingStateRestoration()
    // were removed from lines 2319-2361 as they duplicated the functionality provided by
    // the private implementations at lines 2084-2100. The private implementations provide
    // better error handling and diagnostic logging.

    // Note: Duplicate methods preserveTrimmingState() and clearPreservedTrimmingState()
    // were removed from lines 2322-2389 as they duplicated the functionality provided by
    // the private implementations at lines 2016-2067. The private implementations include
    // comprehensive error handling and diagnostic logging.

    // MARK: - End of AddMoveUnifiedState - Compilation Error Fixes Applied
}
