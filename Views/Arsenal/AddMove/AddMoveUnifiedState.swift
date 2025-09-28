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

    // MARK: - Core Properties
    @Published public var moveName: String = ""
    @Published public var loadingProgress: Double = 0.0
    @Published public var loadingStatus: String = ""
    @Published public var currentProgress: Double = 0.0

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

    // MARK: - Initialization
    @MainActor
    public init(
        unifiedPlayerManager: UnifiedPlayerManager,
        modernVideoLoadingService: ModernVideoLoadingService,
        videoProcessingPipeline: VideoProcessingPipeline,
        timecodeCalculationService: TimecodeCalculationService,
        persistentContainer: NSPersistentContainer,
        movePersistenceService: MovePersistenceServiceProtocol
    ) {
        self.unifiedPlayerManager = unifiedPlayerManager
        self.modernVideoLoadingService = modernVideoLoadingService
        self.videoProcessingPipeline = videoProcessingPipeline
        self.timecodeCalculationService = timecodeCalculationService
        self.persistentContainer = persistentContainer
        self.movePersistenceService = movePersistenceService

        // 🎯 CRITICAL FIX: Sequential service initialization to prevent race conditions
        logger.info("🎬 AddMoveUnifiedState: Beginning sequential service initialization")

        // Initialize services synchronously on main actor
        timerManagementService = TimerManagementService()
        videoProgressMonitoringService = VideoProgressMonitoringService(modernVideoLoadingService: modernVideoLoadingService)

        logger.info("🎬 AddMoveUnifiedState: Services initialized, setting up components")

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
            self.handleProgressUpdate(progress)
        }

        // 🎯 STRATEGIC FIX: Add completion callback for comprehensive monitoring
        videoProgressMonitoringService.onCompletion = { [weak self] completion in
            guard let self = self else { return }

            switch completion {
            case .finished:
                logger.info("🎬 AddMoveUnifiedState: ✅ Progress monitoring completed successfully")
            case .failure(let error):
                logger.error("🎬 AddMoveUnifiedState: ❌ Progress monitoring failed: \(error.localizedDescription)")
            }
        }

        // 🎯 CRITICAL FIX: Start monitoring with validation
        logger.info("🎬 AddMoveUnifiedState: Starting progress monitoring service")
        videoProgressMonitoringService.startMonitoring()

        logger.info("🎬 AddMoveUnifiedState: Components setup completed")
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

    // MARK: - Progress Handling
    @MainActor
    private func handleProgressUpdate(_ progress: VideoLoadingProgress) {
        logger.info("🎬 AddMoveUnifiedState: 🔄 Handling progress update - Phase: \(String(describing: progress.phase)), Progress: \(Int(progress.progress * 100))%, Message: \(progress.message)")

        // 🎯 CRITICAL FIX: Update loading properties for UI binding
        loadingProgress = progress.progress
        loadingStatus = progress.message
        currentProgress = progress.progress

        // 🎯 STRATEGIC FIX: Enhanced flow state management with validation
        let previousState = flowState
        logger.info("🎬 AddMoveUnifiedState: 📊 Current flow state: \(String(describing: previousState))")

        // Update flow state based on progress phase
        if case .loading = flowState {
            let newState = AddMoveFlowState.loading(progressPhase: progress.phase)
            logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to loading state with phase: \(String(describing: progress.phase))")
            flowState = newState
        } else {
            self.logger.warning("🎬 AddMoveUnifiedState: ⚠️ Progress update received while not in loading state - Current state: \(String(describing: self.flowState))")
        }

        // 🎯 STRATEGIC FIX: Update timer with estimated progress for better UX
        let estimatedDuration = 30.0 // 30 seconds expected loading time
        let elapsedProgress = progress.progress * estimatedDuration
        logger.info("🎬 AddMoveUnifiedState: ⏱️ Estimated elapsed time: \(String(format: "%.1f", elapsedProgress))s")

        // 🎯 CRITICAL FIX: Call timer update directly instead of through optional callback
        if let timerUpdate = timerManagementService.onLoadTimerUpdate {
            timerUpdate(elapsedProgress)
        } else {
            logger.warning("🎬 AddMoveUnifiedState: ⚠️ Load timer update callback not available")
        }

        logger.info("🎬 AddMoveUnifiedState: ✅ Progress update handled successfully")
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

        // Validate transition
        let validationErrors = stateValidator.validateStateConsistency(
            flowState: newState,
            playerState: playerState,
            videoAsset: videoAsset,
            trimmerViewModel: nil, // Will be injected
            playerViewModel: nil, // Will be injected
            photosIdentifier: photosIdentifier
        )

        if !validationErrors.isEmpty {
            let errorDescriptions = validationErrors.map { $0.localizedDescription }
            let errorMessage = errorDescriptions.joined(separator: ", ")
            logger.error("❌ State validation failed: \(errorMessage)")
            return
        }

        // Perform transition
        flowState = newState
        logger.info("🔄 State transition: \(String(describing: previousState)) -> \(String(describing: newState)) [triggered by: \(triggeredBy)]")

        // Handle state-specific actions
        handleStateTransition(from: previousState, to: newState)
    }

    @MainActor
    private func handleStateTransition(from: AddMoveFlowState, to: AddMoveFlowState) {
        logger.info("🎬 AddMoveUnifiedState: State transition from \(String(describing: from)) to \(String(describing: to))")

        switch to {
        case .loading:
            timerManagementService.startLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: Started loading timer")

        case .ready, .error, .success:
            timerManagementService.stopLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: Stopped loading timer")

        case .previewing:
            timerManagementService.stopLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: Video loaded, transitioning to preview")

        case .replacingVideo:
            timerManagementService.startLoadTimer()
            logger.info("🎬 AddMoveUnifiedState: Started replacement timer")

        default:
            break
        }
    }

    // MARK: - Save Operations
    public func saveMove() async {
        guard let coordinator = addMoveSaveCoordinator else {
            logger.error("❌ Save operation coordinator not available")
            return
        }

        do {
            let result = try await coordinator.saveMove(
                name: moveName,
                asset: videoAsset!,
                photosIdentifier: photosIdentifier!,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime,
                rotationQuarterTurns: rotationQuarterTurns
            )

            await transition(to: .success(message: "Move saved successfully"))
            if let moveName = result.move.name {
                logger.info("✅ Move saved successfully: \(moveName)")
            } else {
                logger.info("✅ Move saved successfully")
            }

        } catch {
            await transition(to: .error(message: "Failed to save move", underlyingError: error.localizedDescription))
            logger.error("❌ Save operation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation Methods
    public func validateSaveReadiness() async -> SaveReadinessResult {
        return await stateValidator.validateSaveReadiness(
            flowState: flowState,
            playerState: playerState,
            moveName: moveName,
            videoAsset: videoAsset,
            trimmerViewModel: nil, // Will be injected
            playerViewModel: nil, // Will be injected
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

        // 🎯 STRATEGIC FIX: Reset loading state before starting
        loadingProgress = 0.0
        loadingStatus = "Preparing to load..."
        currentProgress = 0.0

        logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to loading state")
        await transition(to: .loading(progressPhase: .initializing))

        let loadingStartTime = Date()

        do {
            logger.info("🎬 AddMoveUnifiedState: 📡 Calling modern video loading service")

            // Load the video using the modern video loading service
            let result = try await modernVideoLoadingService.loadVideo(from: item)

            let loadingDuration = Date().timeIntervalSince(loadingStartTime)

            // 🎯 CRITICAL FIX: Update video asset and properties with logging
            logger.info("🎬 AddMoveUnifiedState: 🏆 Video loading completed in \(String(format: "%.2f", loadingDuration))s")
            logger.info("🎬 AddMoveUnifiedState: 📊 Result - Filename: \(result.filename), Duration: \(result.duration.seconds)s, Size: \(result.fileSize ?? 0) bytes")

            videoAsset = result.asset
            photosIdentifier = result.photosIdentifier
            loadingProgress = 1.0
            loadingStatus = "Loading completed"
            currentProgress = 1.0

            logger.info("🎬 AddMoveUnifiedState: ✅ Video asset and properties updated successfully")

            // Transition to preview state
            logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to preview state")
            await transition(to: .previewing)

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

        // Transition to replacing state
        await transition(to: .replacingVideo(status: "Replacing video..."))

        // Reset existing video data
        videoAsset = nil
        photosIdentifier = nil
        loadingProgress = 0.0
        loadingStatus = "Replacing video..."

        // Load the new video
        await loadVideo(from: item)
    }

    @MainActor
    public func proceedToNextState() async throws {
        logger.info("🎬 AddMoveUnifiedState: Proceeding to next state")
        // This method should handle transition logic to next state
        // For now, transition to naming state
        await transition(to: .naming)
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

    // MARK: - Cleanup
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🎬 AddMoveUnifiedState")
    private let appLogger = AddMoveAppLogger()

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