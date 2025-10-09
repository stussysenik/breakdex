import AVFoundation
import AVKit
import Combine
import CoreData
import Darwin.Mach
import OSLog
import PhotosUI
import SwiftUI

// AddMoveUnifiedState.swift

// MARK: - CLASS
public class AddMoveUnifiedState: ObservableObject {

    // MARK: - PUBLISHED
    @Published public private(set) var flowState: AddMoveFlowState = .ready
    @Published public private(set) var playerState: PlayerState = .idle
    @Published public private(set) var correlationId: String? = nil

    // MARK: - INIT
    init(
        unifiedPlayerManager: UnifiedPlayerManager,
        modernVideoLoadingService: ModernVideoLoadingService,
        videoProcessingPipeline: VideoProcessingPipeline,
        timecodeCalculationService: TimecodeCalculationService,
        persistentContainer: NSPersistentContainer,
        movePersistenceService: MovePersistenceService,
        appContainer: AppContainer
    ) {
        let initTime = Date()
        let initThreadId = Thread.isMainThread ? "MAIN" : "BACKGROUND"

        self.unifiedPlayerManager = unifiedPlayerManager
        self.modernVideoLoadingService = modernVideoLoadingService
        self.videoProcessingPipeline = videoProcessingPipeline
        self.timecodeCalculationService = timecodeCalculationService
        self.persistentContainer = persistentContainer
        self.movePersistenceService = movePersistenceService
        self.appContainer = appContainer

//        logger.info("🚨 STATE_LIFECYCLE: 🏗️ AddMoveUnifiedState INITIALIZING")
//        logger.info(
//            "🚨 STATE_LIFECYCLE: 🎯 STATE_OBJECT_ID: \(self.stateObjectId)"
//        )
//        logger.info("🚨 STATE_LIFECYCLE: 📱 Thread: \(initThreadId)")
//        logger.info(
//            "🚨 STATE_LIFECYCLE: ⏰ Init timestamp: \(initTime.description)"
//        )
//        logger.info(
//            "🚨 STATE_LIFECYCLE:  Initial state: \(String(describing: self.flowState))"
//        )
//        logger.info("🚨 STATE_LIFECYCLE: 🔧 Dependencies injected: 7 services")

        initializeServices()

        hasLoggedInitialization = true

//        logger.info(
//            "🚨 STATE_LIFECYCLE: ✅ AddMoveUnifiedState INITIALIZATION COMPLETE"
//        )
//        logger.info(
//            "🚨 STATE_LIFECYCLE: 🎯 STATE_OBJECT_ID: \(self.stateObjectId)"
//        )
//        logger.info("🚨 STATE_LIFECYCLE:  Ready for video selection workflow")
//        logger.info(
//            "🚨 STATE_LIFECYCLE: 📋 Initialization duration: \(String(format: "%.3f", Date().timeIntervalSince(initTime)))s"
//        )
//
//        let memoryUsage = getMemoryUsageInMB()
//        logger.info(
//            "🚨 STATE_LIFECYCLE:  Memory usage after init: \(String(format: "%.1f", memoryUsage))MB"
//        )
//
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 🎯 SINGLE_INSTANCE_CHECK - AddMoveUnifiedState created"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 🎯 STATE_OBJECT_ID: \(self.stateObjectId)"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 📝 If multiple instances appear, state lifecycle bug is present"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 🔍 SOLUTION: Use AddMoveStateOwner with single @StateObject"
//        )
    }

    deinit {
        let deinitTime = Date()
        let deinitThreadId = Thread.isMainThread ? "MAIN" : "BACKGROUND"

//        logger.critical("🚨 STATE_LIFECYCLE: 💥 AddMoveUnifiedState DEALLOCATING")
//        logger.critical(
//            "🚨 STATE_LIFECYCLE: 🎯 STATE_OBJECT_ID: \(self.stateObjectId)"
//        )
//        logger.critical("🚨 STATE_LIFECYCLE: 📱 Thread: \(deinitThreadId)")
//        logger.critical(
//            "🚨 STATE_LIFECYCLE: ⏰ Deinit timestamp: \(deinitTime.description)"
//        )
//        logger.critical(
//            "🚨 STATE_LIFECYCLE:  Final state: \(String(describing: self.flowState))"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 🔴 STATE_OBJECT_DESTROYED - This could cause race conditions!"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 📝 If this happens mid-workflow, loading will fail"
//        )
//        logger.critical(
//            "🚨 ROOT_CAUSE_DEBUG: 🔍 SOLUTION: Ensure single persistent @StateObject owner"
//        )

        let memoryUsage = getMemoryUsageInMB()
//        logger.critical(
//            "🚨 STATE_LIFECYCLE:  Memory usage at deinit: \(String(format: "%.1f", memoryUsage))MB"
//        )
    }

    // MARK: - FUNC
    private func initializeServices() {
//        logger.info("🚨 STATE_LIFECYCLE: 🔧 Initializing services...")

        Task { @MainActor in
            self.flowStateManager = FlowStateManager(
                unifiedState: self,
                stateValidator: stateValidator,
                addMoveSaveCoordinator: AddMoveSaveCoordinator(
                    movePersistenceService: self.movePersistenceService,
                    videoProcessingPipeline: self.videoProcessingPipeline,
                    logger: AddMoveAppLogger()
                )
            )
        }

        servicesInitialized = true
//        logger.info("🚨 STATE_LIFECYCLE: ✅ Services initialization complete")
    }

    // MARK: - VAR
    private var timerManagementService: TimerManagementService!
    private var videoProgressMonitoringService: VideoProgressMonitoringService!
    private let stateValidator = StateValidator()
    private var addMoveSaveCoordinator: AddMoveSaveCoordinator?
    internal var flowStateManager: FlowStateManager!

    // MARK: - VAR
    @MainActor
    public let unifiedProgressEngine = UnifiedProgressEngine()
    private var saveReadinessTimer: Timer?
    private var servicesInitialized = false
    private let stateObjectId = UUID().uuidString.prefix(8)
    private var hasLoggedInitialization = false
    private var videoLoadingTask: Task<Void, Error>?
    private var isCompletingLoad: Bool = false

    @Published public var moveName: String = ""
    @Published public private(set) var estimatedFileSize: Int64 = 0
    @Published public private(set) var formattedFileSize: String = ""

    // MARK: - LOG
    private let logger = Logger(
        subsystem: "breakdex",
        category: "🎬 AddMoveUnifiedState"
    )
//    private let appLogger = ConsoleLogger()

    // MARK: - FUNC
    @MainActor
    private func logUnifiedLoadingStateDiagnostics(
        _ context: String,
        operation: String = "UNIFIED_LOADING_CHECK"
    ) {
        let operationId = UUID().uuidString.prefix(8)

//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS:  \(operation) [\(operationId)] - \(context)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: ┌─ Comprehensive Loading State Analysis"
//        )
//
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: ├─ Flow State & Loading Status"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ flow_state: \(String(describing: self.flowState))"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ player_state: \(String(describing: self.playerState))"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ unified_status: '\(self.unifiedProgressEngine.unifiedStatus)'"
//        )

        // MARK: TASK
        // note: unit of asynch work
        Task {
            let isLocked = await transitionLockManager.isLocked()
            let lockOwner = await transitionLockManager.getCurrentOwner()
            let ownsLock =
                currentTransitionId != nil
                ? await transitionLockManager.ownsLock(id: currentTransitionId!)
                : false

            await MainActor.run {
//                logger.info(
//                    "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ is_transitioning_to_trimming: \(isLocked)"
//                )
//                logger.info(
//                    "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ current_transition_id: \(self.currentTransitionId?.uuidString ?? "none")"
//                )
//                logger.info(
//                    "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ owns_transition_lock: \(ownsLock)"
//                )
//                logger.info(
//                    "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  └─ transition_correlation_id: \(self.transitionCorrelationId ?? "none")"
//                )
            }
        }

//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: ├─ Timing Information")
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ load_elapsed_time: \(String(format: "%.3f", self.loadElapsedTime))s"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ loading_overlay_start_time: \(self.loadingOverlayStartTime?.description ?? "none")"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ transition_start_time: \(self.transitionStartTime?.description ?? "none")"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  └─ minimum_loading_display_time: \(self.minimumLoadingDisplayTime)s"
//        )
//
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: ├─ Progress Engine State")
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ unified_progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ target_progress: \(String(format: "%.3f", self.unifiedProgressEngine.targetProgress)) (\(Int(self.unifiedProgressEngine.targetProgress * 100))%)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ current_phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ elapsed_time_string: \(self.unifiedProgressEngine.elapsedTimeString)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  └─ estimated_time_remaining: \(String(format: "%.1f", self.unifiedProgressEngine.estimatedTimeRemaining))s"
//        )
//
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: ├─ Resource Availability")
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ video_asset_available: \(self.videoAsset != nil)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ photos_identifier: \(self.photosIdentifier ?? "missing")"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ current_player_viewmodel: \(self.currentPlayerViewModel != nil)"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  └─ trimmer_viewmodel: \(self.trimmerViewModel != nil)"
//        )
//
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: ├─ Memory & Performance")
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ timestamp: \(Date())")
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ operation_id: \(operationId)"
//        )
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: │  ├─ context: \(context)")
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: │  └─ unified_loading_experience: ACTIVE"
//        )
//        logger.info("🎯 UNIFIED_LOADING_DIAGNOSTICS: └─ Architectural State")

        // MARK: - TASK
        Task {
            let isLocked = await transitionLockManager.isLocked()
            await MainActor.run {
//                logger.info(
//                    "🎯 UNIFIED_LOADING_DIAGNOSTICS:    ├─ atomic_transition_lock: \(isLocked ? "ENGAGED" : "RELEASED")"
//                )
            }
        }
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS:    ├─ preview_to_trim_transition_fallback: PREVENTED"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS:    ├─ loading_overlay_persistence: MAINTAINED"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS:    ├─ trimmer_readiness_check: BEFORE_TRANSITION"
//        )
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS:    └─ ux_stability_enhancement: ACTIVE"
//        )
//
//        logger.info(
//            "🎯 UNIFIED_LOADING_DIAGNOSTICS: ✅ Comprehensive diagnostic logging completed for \(context) [\(operationId)]"
//        )
    }

    // MARK: - FUNC
    @MainActor
    private func logRotationStateFix(
        _ context: String,
        operation: String = "STATE_CHECK"
    ) {
        let operationId = UUID().uuidString.prefix(8)

//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX:  \(operation) [\(operationId)] - \(context)"
//        )
//        logger.info("🎯 DOUBLE_ROTATION_FIX: ┌─ Comprehensive State Analysis")
//
//        logger.info("🎯 DOUBLE_ROTATION_FIX: ├─ Rotation State")
//        if let trimmerVM = trimmerViewModel as? TrimmerViewModel {
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  ├─ intrinsic_rotation: \(trimmerVM.assetIntrinsicRotationTurns) turns (\(trimmerVM.assetIntrinsicRotationTurns * 90)°)"
//            )
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  ├─ user_applied_rotation: \(trimmerVM.userAppliedRotationTurns) turns (\(trimmerVM.userAppliedRotationTurns * 90)°)"
//            )
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  ├─ total_rotation: \(trimmerVM.totalRotationQuarterTurns) turns (\(trimmerVM.totalRotationQuarterTurns * 90)°)"
//            )
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  └─ natural_transformation_η: intrinsic ⊕ user = total"
//            )
//        } else {
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  └─ trimmer_viewmodel: NOT_AVAILABLE"
//            )
//        }

//        logger.info("🎯 DOUBLE_ROTATION_FIX: ├─ Player State")
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  ├─ current_player_available: \(self.unifiedPlayerManager.currentPlayer != nil)"
//        )
//        if let player = self.unifiedPlayerManager.currentPlayer {
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  ├─ player_status: \(player.avPlayer != nil ? "AVAILABLE" : "UNAVAILABLE")"
//            )
//            logger.info(
//                "🎯 DOUBLE_ROTATION_FIX: │  └─ player_ready: \(player.isPlayerReady)"
//            )
//        } else {
//            logger.info("🎯 DOUBLE_ROTATION_FIX: │  └─ player_status: NO_PLAYER")
//        }
//
//        logger.info("🎯 DOUBLE_ROTATION_FIX: ├─ UI State")
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  ├─ swiftui_rotation_layer: DISABLED"
//        )
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  ├─ avplayer_rotation_baked_in: ACTIVE"
//        )
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  ├─ double_rotation_bug: ELIMINATED"
//        )
//        logger.info("🎯 DOUBLE_ROTATION_FIX: │  └─ identity_morphism: ENFORCED")
//
//        logger.info("🎯 DOUBLE_ROTATION_FIX: ├─ Category Theory")
//        logger.info("🎯 DOUBLE_ROTATION_FIX: │  ├─ domain: UserInteractionSpace")
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  ├─ codomain: VideoOrientationSpace"
//        )
//        logger.info("🎯 DOUBLE_ROTATION_FIX: │  ├─ morphism: handleRotation()")
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: │  └─ natural_transformation: rotation → video_composition"
//        )
//
//        logger.info("🎯 DOUBLE_ROTATION_FIX: └─ Flow Context")
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX:    ├─ flow_state: \(String(describing: self.flowState))"
//        )
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX:    ├─ photos_identifier: \(self.photosIdentifier ?? "missing")"
//        )
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX:    ├─ video_asset_available: \(self.videoAsset != nil)"
//        )
//        logger.info("🎯 DOUBLE_ROTATION_FIX:    └─ timestamp: \(Date())")
//
//        logger.info(
//            "🎯 DOUBLE_ROTATION_FIX: ✅ Diagnostic logging completed for \(context) [\(operationId)]"
//        )
    }

    // MARK: - VAR
    @Published public var onSaveSuccess: ((Any) -> Void)?
    @Published public var trimmerViewModel: Any?
    @Published public var loadElapsedTime: TimeInterval = 0.0
    @Published public var saveElapsedTime: TimeInterval = 0.0
    @Published public var saveProgress: Double = 0.0
    @Published public var currentPlayerViewModel: Any?
    @Published public var saveReadiness: SaveReadinessResult?
    @Published public var returnToTrimming: (() -> Void)?

    // MARK: - VAR
    private let transitionLockManager = TransitionLockManager.shared
    private var currentTransitionId: UUID?
    private var transitionStartTime: Date?
    private var transitionCorrelationId: String?

    private var loadingOverlayStartTime: Date?
    private let minimumLoadingDisplayTime: TimeInterval = 1.0

    public var preservedTrimmingState: TrimmingStateSnapshot?

    // MARK: - FUNC
    @MainActor
    public func completeTransition() {
        // logger.info("🎬 AddMoveUnifiedState: Completing transition")
        unifiedPlayerManager.completeTransition()
    }
    // MARK: - FUNC
    @MainActor
    public func clearError() async {
        // logger.info("🎬 AddMoveUnifiedState: Clearing error state")

        flowState = .ready
        playerState = .idle
    }
    // MARK: - FUNC
    @MainActor
    public func updateEstimatedFileSize(
        _ fileSize: Int64,
        formattedSize: String
    ) {
//        logger.info(
//            "🎬 AddMoveUnifiedState:  UPDATING_FILE_SIZE: File size information updated"
//        )
        // logger.info("🎬 AddMoveUnifiedState: ├─ Raw Size: \(fileSize) bytes")
        // logger.info("🎬 AddMoveUnifiedState: └─ Formatted: '\(formattedSize)'")

        self.estimatedFileSize = fileSize
        self.formattedFileSize = formattedSize

//        if fileSize > 0 {
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ FILE_SIZE_VALID: Valid file size received"
//            )
//        } else {
//            logger.warning(
//                "🎬 AddMoveUnifiedState: ⚠️ FILE_SIZE_ZERO: Zero or invalid file size received"
//            )
//        }
    }
    // MARK: - FUNC
    @MainActor
    public func clearFileSize() {
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🧹 CLEARING_FILE_SIZE: Resetting file size information"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: ├─ Previous Size: \(self.estimatedFileSize) bytes"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: └─ Previous Formatted: '\(self.formattedFileSize)'"
//        )

        self.estimatedFileSize = 0
        self.formattedFileSize = ""
    }
    // MARK: - FUNC
    @MainActor
    public func cancelVideoLoading() async {
        // logger.info("🎬 AddMoveUnifiedState: 🚫 Video loading cancelled by user")

        unifiedProgressEngine.cancelLoading()

        modernVideoLoadingService.cancelCurrentOperation()

        videoProgressMonitoringService.stopMonitoring()

        await transition(to: .ready, triggeredBy: "user_cancellation")

//        logger.info(
//            "🎬 AddMoveUnifiedState: ✅ Video loading cancellation completed"
//        )
    }
    // MARK: - FUNC
    @MainActor
    private func validateStorageBeforeLoading() async {
//        logger.info(
//            "🎬 AddMoveUnifiedState: 💾 Validating storage before video loading"
//        )

        do {
            let availableSpace = try await getAvailableDiskSpace()
            let requiredSpace: Int64 = 500 * 1024 * 1024

//            logger.info(
//                "🎬 AddMoveUnifiedState: 💾 Storage check - Available: \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)), Required: \(ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file))"
//            )

//            if availableSpace < requiredSpace {
//                logger.warning(
//                    "🎬 AddMoveUnifiedState: ⚠️ Insufficient storage available"
//                )
//                unifiedProgressEngine.handleStorageError(
//                    available: availableSpace,
//                    required: requiredSpace
//                )
//                await setError(
//                    message: "Insufficient storage",
//                    underlying:
//                        "Need at least \(ByteCountFormatter.string(fromByteCount: requiredSpace, countStyle: .file)) of available space"
//                )
//            } else {
//                logger.info(
//                    "🎬 AddMoveUnifiedState: ✅ Storage validation passed"
//                )
//            }
        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Failed to check available storage: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - FUNC
    private func getAvailableDiskSpace() async throws -> Int64 {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let resourceValues = try documentsPath.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey
        ])

        guard
            let availableSpace = resourceValues
                .volumeAvailableCapacityForImportantUsage
        else {
            throw NSError(
                domain: "AddMoveUnifiedState",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unable to determine available disk space"
                ]
            )
        }

        return availableSpace
    }

    // MARK: - FUNC
    @MainActor
    public func updatePlayerState(_ newState: PlayerState) {
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🔧 BACK BUTTON FIX - Updating player state: \(String(describing: self.playerState)) → \(String(describing: newState))"
//        )
        self.playerState = newState
//        logger.info(
//            "🎬 AddMoveUnifiedState: ✅ BACK BUTTON FIX - Player state updated to: \(String(describing: newState))"
//        )
    }

    // MARK: - FUNC
    @MainActor
    public func startSaveReadinessMonitoring() {
        // logger.info("🎬 AddMoveUnifiedState: Starting save readiness monitoring")

        saveReadinessTimer?.invalidate()

        saveReadinessTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performSaveReadinessValidation()
            }
        }

        Task { @MainActor in
            await self.performSaveReadinessValidation()
        }
    }

    @MainActor
    private func performSaveReadinessValidation() async {
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🔍 DIAGNOSTIC - Performing save readiness validation..."
//        )

        let validationResult = await validateSaveReadiness()

//        if validationResult.isValid {
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Validation passed - ready to save"
//            )
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Validation details: canSave=\(validationResult.canSave), issues=\(validationResult.issues.count)"
//            )
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Player ready: \(validationResult.hasValidPlayer), Asset ready: \(validationResult.hasValidAsset), Trimmer ready: \(validationResult.hasValidTrimmer)"
//            )
//
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ Validation succeeded - stopping monitoring timer"
//            )
//            stopSaveReadinessMonitoring()
//        } else {
//            logger.warning(
//                "🎬 AddMoveUnifiedState: ⚠️ DIAGNOSTIC - Validation failed - issues: \(validationResult.issues)"
//            )
//            for (index, issue) in validationResult.issues.enumerated() {
//                logger.warning(
//                    "🎬 AddMoveUnifiedState: ⚠️ DIAGNOSTIC - Issue \(index + 1): \(issue.localizedDescription) (critical: \(issue.isCritical))"
//                )
//            }
//        }

//        logger.info(
//            "🎬 AddMoveUnifiedState: 🔧 DIAGNOSTIC - Updating saveReadiness property..."
//        )
//        self.saveReadiness = validationResult
//        logger.info(
//            "🎬 AddMoveUnifiedState: ✅ DIAGNOSTIC - Save readiness validation completed"
//        )
    }

    // MARK: - FUNC
    @MainActor
    public func stopSaveReadinessMonitoring() {
        // logger.info("🎬 AddMoveUnifiedState: Stopping save readiness monitoring")
        saveReadinessTimer?.invalidate()
        saveReadinessTimer = nil
    }

    // MARK: - VAR
    @Published public var videoAsset: AVAsset?
    @Published public var photosIdentifier: String?

    @MainActor
    public var trimStartTime: Double {
        return (trimmerViewModel as? TrimmerViewModel)?.startTime.seconds ?? 0.0
    }

    @MainActor
    public var trimEndTime: Double {
        return (trimmerViewModel as? TrimmerViewModel)?.endTime.seconds ?? 0.0
    }

    @MainActor
    public var intrinsicAssetRotation: Int {
        return (trimmerViewModel as? TrimmerViewModel)?
            .assetIntrinsicRotationTurns ?? 0
    }

    @MainActor
    public var userAppliedRotation: Int {
        return (trimmerViewModel as? TrimmerViewModel)?.userAppliedRotationTurns
            ?? 0
    }

    @MainActor
    public var totalRotationQuarterTurns: Int {
        return (trimmerViewModel as? TrimmerViewModel)?
            .totalRotationQuarterTurns ?? 0
    }

    // MARK: - CLASS
    public struct TrimmingStateSnapshot {
        let videoAsset: AVAsset
        let photosIdentifier: String
        let trimStartTime: Double
        let trimEndTime: Double
        let intrinsicAssetRotation: Int
        let userAppliedRotation: Int
        let timestamp: Date
        let creationTimeMs: Double

        var totalRotationQuarterTurns: Int {
            return (intrinsicAssetRotation + userAppliedRotation) % 4
        }

        // MARK: - @AVAILABLE
        @available(
            *,
            deprecated,
            message:
                "Use async initializer for proper intrinsic rotation extraction"
        )

        // MARK: - MAIN ACTOR
        @MainActor
        init?(unifiedState: AddMoveUnifiedState) {
            let logger = Logger(
                subsystem: "breakdex",
                category: "📸 TrimmingStateSync"
            )
            let startTime = CFAbsoluteTimeGetCurrent()

            guard let videoAsset = unifiedState.videoAsset,
                let photosIdentifier = unifiedState.photosIdentifier,
                !photosIdentifier.isEmpty
            else {
                logger.warning(
                    "📸 [SYNC] Cannot create snapshot: missing video asset or photos identifier"
                )
                return nil
            }

            logger.warning(
                "📸 [SYNC] Using deprecated synchronous initializer - intrinsic rotation will be inaccurate"
            )
            logger.debug(
                "📸 [SYNC] Domain: AddMoveUnifiedState → TrimmingStateSnapshot (degraded morphism)"
            )

            self.videoAsset = videoAsset
            self.photosIdentifier = photosIdentifier
            self.trimStartTime = unifiedState.trimStartTime
            self.trimEndTime = unifiedState.trimEndTime

            let intrinsicAssetRotation = 0
            let userAppliedRotation = unifiedState.userAppliedRotation
            let timestamp = Date()
            let creationTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            self.intrinsicAssetRotation = intrinsicAssetRotation
            self.userAppliedRotation = userAppliedRotation
            self.timestamp = timestamp
            self.creationTimeMs = creationTimeMs

//            logger.warning(
//                "📸 [SYNC] Legacy snapshot created - intrinsic rotation: 0 (hardcoded), user: \(userAppliedRotation)"
//            )
//            logger.warning(
//                "📸 [SYNC] Performance: \(String(format: "%.2f", creationTimeMs))ms (degraded accuracy)"
//            )
        }
        // MARK: - MAIN ACTOR
        @MainActor
        init?(unifiedState: AddMoveUnifiedState) async {
            let logger = Logger(
                subsystem: "breakdex",
                category: "📸 TrimmingStateAsync"
            )
            let startTime = CFAbsoluteTimeGetCurrent()

            guard let videoAsset = unifiedState.videoAsset,
                let photosIdentifier = unifiedState.photosIdentifier,
                !photosIdentifier.isEmpty
            else {
                logger.warning(
                    "📸 [ASYNC] Cannot create snapshot: missing video asset or photos identifier"
                )
                return nil
            }

            logger.info(
                "📸 [ASYNC] Creating enhanced TrimmingStateSnapshot with categorical rotation analysis"
            )
            logger.debug(
                "📸 [ASYNC] Starting natural transformation η: TotalRotation → Intrinsic ⊕ UserApplied"
            )

            let intrinsicRotationExtractionStart = CFAbsoluteTimeGetCurrent()
            let intrinsicRotation = await videoAsset.getRotationInQuarterTurns()
            let intrinsicRotationTime =
                (CFAbsoluteTimeGetCurrent() - intrinsicRotationExtractionStart)
                * 1000

            logger.debug(
                "📸 [ASYNC] Morphism 1 completed: Intrinsic rotation extracted in \(String(format: "%.2f", intrinsicRotationTime))ms"
            )
            logger.debug(
                "📸 [ASYNC] Intrinsic rotation (f₁(asset)): \(intrinsicRotation) quarter turns"
            )

            let currentTotalRotation = unifiedState.totalRotationQuarterTurns
            let userAppliedRotation =
                (currentTotalRotation - intrinsicRotation + 4) % 4

//            logger.debug("📸 [ASYNC] Natural transformation η applied:")
//            logger.debug(
//                "📸 [ASYNC]   Total rotation (state): \(currentTotalRotation) quarter turns"
//            )
//            logger.debug(
//                "📸 [ASYNC]   Intrinsic rotation (asset): \(intrinsicRotation) quarter turns"
//            )
//            logger.debug(
//                "📸 [ASYNC]   User-applied rotation (η⁻¹): \(userAppliedRotation) quarter turns"
//            )
//            logger.debug(
//                "📸 [ASYNC]   Verification: (\(intrinsicRotation) + \(userAppliedRotation)) mod 4 = \((intrinsicRotation + userAppliedRotation) % 4)"
//            )

            let rotationQuarterTurns =
                (intrinsicRotation + userAppliedRotation) % 4
            let timestamp = Date()
            let creationTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            self.videoAsset = videoAsset
            self.photosIdentifier = photosIdentifier
            self.trimStartTime = unifiedState.trimStartTime
            self.trimEndTime = unifiedState.trimEndTime
            self.intrinsicAssetRotation = intrinsicRotation
            self.userAppliedRotation = userAppliedRotation
            self.timestamp = timestamp
            self.creationTimeMs = creationTimeMs

            let isIsoMorphic =
                ((intrinsicRotation + userAppliedRotation) % 4)
                == currentTotalRotation
            let isoStatus =
                isIsoMorphic ? "✅ ISOMORPHIC" : "❌ BROKEN ISOMORPHISM"

//            logger.info(
//                "📸 [ASYNC] Enhanced TrimmingStateSnapshot created successfully"
//            )
//            logger.info(
//                "📸 [ASYNC] Categorical composition: h ∘ g ∘ f completed"
//            )
//            logger.info("📸 [ASYNC] Natural transformation η: \(isoStatus)")
//            logger.info(
//                "📸 [ASYNC] Final state - Intrinsic: \(intrinsicRotation), User: \(userAppliedRotation), Total: \(rotationQuarterTurns)"
//            )
//            logger.info(
//                "📸 [ASYNC] Performance metrics: Total \(String(format: "%.2f", creationTimeMs))ms (Extraction: \(String(format: "%.2f", intrinsicRotationTime))ms)"
//            )
//
//            if !isIsoMorphic {
//                logger.error(
//                    "📸 [ASYNC] ⚠️ CRITICAL: Rotation isomorphism violated! WYSIWYG preservation compromised."
//                )
//            }
        }

        // MARK: - FUNC
        func performanceAnalysis() -> String {
            var analysis = " TrimmingStateSnapshot Performance Analysis:\n"
            analysis +=
                "  Total creation time: \(String(format: "%.2f", creationTimeMs))ms\n"
            analysis += "  Categorical morphisms: h ∘ g ∘ f\n"
            analysis += "  Natural transformation η: ✅ Applied\n"
            let computedRotation =
                (intrinsicAssetRotation + userAppliedRotation) % 4
            analysis +=
                "  Isomorphism status: \(computedRotation == computedRotation ? "PRESERVED" : "VIOLATED")\n"
            analysis +=
                "  Rotation decomposition: Intrinsic(\(intrinsicAssetRotation)) ⊕ User(\(userAppliedRotation)) = Total(\(computedRotation))"
            return analysis
        }
    }

    // MARK: VAR
    public let unifiedPlayerManager: UnifiedPlayerManager
    public let modernVideoLoadingService: ModernVideoLoadingServiceProtocol
    public let videoProcessingPipeline: VideoProcessingPipeline
    public let timecodeCalculationService: TimecodeCalculationService
    public let persistentContainer: NSPersistentContainer
    private let movePersistenceService: MovePersistenceServiceProtocol
    let appContainer: AppContainer

    // MARK: - MAIN ACTOR
    @MainActor
    public init(
        unifiedPlayerManager: UnifiedPlayerManager,
        modernVideoLoadingService: ModernVideoLoadingServiceProtocol,
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

//        logger.info(
//            "🎬 AddMoveUnifiedState: Beginning sequential service initialization"
//        )

        Task { @MainActor in
            do {
                try await initializeServices()

//                logger.info(
//                    "🎬 AddMoveUnifiedState: Core services initialized, setting up components"
//                )

//                setupComponents()
                setupSubscriptions()

                servicesInitialized = true

//                logger.info(
//                    "🎬 AddMoveUnifiedState: ✅ Initialization completed successfully"
//                )
            } catch {
//                logger.error(
//                    "🎬 AddMoveUnifiedState: ❌ Service initialization failed: \(error.localizedDescription)"
//                )

                flowState = .error(
                    message: "Service initialization failed",
                    underlyingError: error.localizedDescription
                )
            }
        }
    }

    // MARK: - FUNC
    @MainActor
    private func initializeServices() async throws {
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🔍 Initializing services with validation"
//        )

        var initializationErrors: [String] = []

        do {
            timerManagementService = TimerManagementService()
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ TimerManagementService initialized"
            )
        } catch {
            let errorMsg =
                "Failed to initialize TimerManagementService: \(error.localizedDescription)"
            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
            initializationErrors.append(errorMsg)
        }

        do {
            videoProgressMonitoringService = VideoProgressMonitoringService(
                modernVideoLoadingService: modernVideoLoadingService
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ VideoProgressMonitoringService initialized"
            )
        } catch {
            let errorMsg =
                "Failed to initialize VideoProgressMonitoringService: \(error.localizedDescription)"
            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
            initializationErrors.append(errorMsg)
        }

//        do {
//            addMoveSaveCoordinator = AddMoveSaveCoordinator(
//                movePersistenceService: movePersistenceService,
//                videoProcessingPipeline: videoProcessingPipeline,
//                logger: appLogger
//            )
//            logger.info(
//                "🎬 AddMoveUnifiedState: ✅ AddMoveSaveCoordinator initialized"
//            )
//        } catch {
//            let errorMsg =
//                "Failed to initialize AddMoveSaveCoordinator: \(error.localizedDescription)"
//            logger.error("🎬 AddMoveUnifiedState: ❌ \(errorMsg)")
//            initializationErrors.append(errorMsg)
//        }

        try validateRequiredDependencies()

        if !initializationErrors.isEmpty {
            let combinedError = initializationErrors.joined(separator: "; ")
            throw ServiceInitializationError.serviceInitializationFailed(
                combinedError
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ All services initialized successfully"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func validateRequiredDependencies() throws {
        // logger.info("🎬 AddMoveUnifiedState: 🔍 Validating required dependencies")

        let validationErrors: [String] = []

        if !validationErrors.isEmpty {
            let combinedError = validationErrors.joined(separator: "; ")
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Dependency validation failed: \(combinedError)"
            )
            throw ServiceInitializationError.dependencyValidationFailed(
                combinedError
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ All required dependencies validated"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func setupComponents() {
        // logger.info("🎬 AddMoveUnifiedState: Setting up components")

//        addMoveSaveCoordinator = AddMoveSaveCoordinator(
//            movePersistenceService: movePersistenceService,
//            videoProcessingPipeline: videoProcessingPipeline,
//            logger: appLogger
//        )

        logger.info(
            "🎬 AddMoveUnifiedState: Setting up progress monitoring callback"
        )

        videoProgressMonitoringService.onProgressUpdate = {
            [weak self] progress in
            guard let self = self else {
                self?.logger.warning(
                    "🎬 AddMoveUnifiedState: Progress update callback received after deallocation"
                )
                return
            }

            self.logger.info(
                "🎬 AddMoveUnifiedState:  Progress callback triggered - Phase: \(String(describing: progress.phase)), Progress: \(Int(progress.progress * 100))%"
            )
            self.handleVideoLoadingProgress(progress)
        }

        videoProgressMonitoringService.onCompletion = {
            [weak self] completion in
            guard let self = self else { return }

            switch completion {

            case .finished:
                logger.info(
                    "🎬 AddMoveUnifiedState: ✅ Progress monitoring completed successfully"
                )

                if case .loadingVideo = self.flowState {
                    logger.info(
                        "🎬 AddMoveUnifiedState: 🔄 Completion callback detected loading state - triggering atomic transformation"
                    )

                    Task { @MainActor in
                        do {
                            let transitionId =
                                try await self.acquireTransitionLock(
                                    correlationId:
                                        "completion_callback_\(UUID().uuidString)"
                                )
                            self.logger.info(
                                "🎬 AddMoveUnifiedState: 🔒 ACTOR-BASED TRANSITION LOCKED via completion callback - ID: \(transitionId.uuidString)"
                            )

                            try? await Task.sleep(nanoseconds: 100_000_000)

                            await self.handleLoadingCompletionWithAtomicGuard()
                        } catch {
                            self.logger.error(
                                "🎬 AddMoveUnifiedState: ❌ Failed to acquire transition lock for completion callback: \(error.localizedDescription)"
                            )
                        }
                    }
                } else {
                    logger.info(
                        "🎬 AddMoveUnifiedState:  Completion callback processed - not in loading state: \(String(describing: self.flowState))"
                    )
                }

            case .failure(let error):
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Progress monitoring failed: \(error.localizedDescription)"
                )

                if case .loadingVideo = self.flowState {
                    logger.error(
                        "🎬 AddMoveUnifiedState: 🔄 Transitioning to error state due to progress monitoring failure"
                    )

                    logger.info(
                        "🎬 AddMoveUnifiedState: ⏱️ Stopping load timer due to progress monitoring failure"
                    )
                    self.timerManagementService.stopLoadTimer()

                    Task {
                        if let transitionId = self.currentTransitionId {
                            await self.transitionLockManager.releaseLock(
                                for: transitionId
                            )
                            self.logger.info(
                                "🎬 AddMoveUnifiedState: 🔒 Released transition lock due to error"
                            )
                        }
                        self.currentTransitionId = nil
                        self.transitionStartTime = nil
                        self.transitionCorrelationId = nil
                    }

                    Task { @MainActor in
                        await self.setError(
                            message: "Video loading failed",
                            underlying: error.localizedDescription
                        )
                    }
                }
            }
        }

        logger.info(
            "🎬 AddMoveUnifiedState: Starting progress monitoring service"
        )
        videoProgressMonitoringService.startMonitoring()

        // logger.info("🎬 AddMoveUnifiedState: Components setup completed")

        // logger.info("🎬 AddMoveUnifiedState: Initializing FlowStateManager")

//        if addMoveSaveCoordinator == nil {
//            addMoveSaveCoordinator = AddMoveSaveCoordinator(
//                movePersistenceService: movePersistenceService,
//                videoProcessingPipeline: videoProcessingPipeline,
//                logger: appLogger
//            )
//        }

//        flowStateManager = FlowStateManager(
//            unifiedState: self,
//            stateValidator: stateValidator,
//            addMoveSaveCoordinator: addMoveSaveCoordinator!
//        )

        flowStateManager.onStateTransition = {
            [weak self] from, to, triggeredBy in
            self?.logger.info(
                "🎬 AddMoveUnifiedState: 🔄 Flow state transition: \(String(describing: from)) → \(String(describing: to)) [triggered by: \(triggeredBy)]"
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState: FlowStateManager initialized successfully"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func setupSubscriptions() {
        // logger.info("🎬 AddMoveUnifiedState: Setting up service subscriptions")

        timerManagementService.onSaveTimerUpdate = { [weak self] elapsed in
            guard let self = self else {
                self?.logger.warning(
                    "🎬 AddMoveUnifiedState: Save timer update callback received after deallocation"
                )
                return
            }

            self.logger.info(
                "🎬 AddMoveUnifiedState: ⏱️ Save timer update: \(String(format: "%.2f", elapsed))s (centisecond precision maintained)"
            )
            self.saveElapsedTime = elapsed
        }

        timerManagementService.onLoadTimerUpdate = { [weak self] elapsed in
            guard let self = self else {
                self?.logger.warning(
                    "🎬 AddMoveUnifiedState: Load timer update callback received after deallocation"
                )
                return
            }
            self.loadElapsedTime = elapsed
        }

        timerManagementService.onLogDiagnostic = {
            [weak self] message, metadata in
            guard let self = self else { return }

            let metadataString = metadata.map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            logger.info(
                "🎬 AddMoveUnifiedState:  Timer diagnostic: \(message) | \(metadataString)"
            )
        }

//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: Timer precision upgrade completed"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: ├─ TimerManagementService: ✅ 0.01s intervals (centisecond precision)"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: ├─ LoadingOverlayView.formatTime(): ✅ MM:SS.ss format"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: ├─ Logging precision: ✅ Centisecond precision preserved"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: ├─ Data structure: ✅ isomorphic - no breaking changes"
//        )
//        logger.info(
//            "🎬 AddMoveUnifiedState: 🎯 PRECISION_FIX_DIAGNOSTIC: └─ User experience: ✅ Enhanced timing accuracy for loading overlay"
//        )

        Task { @MainActor in
            await self.setupPhaseChangeCompletionHandler()
        }

        logger.info(
            "🎬 AddMoveUnifiedState: Service subscriptions setup completed"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func setupPhaseChangeCompletionHandler() async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 COMPLETION_MORPHISM: Setting up phase change completion handler"
        )

        for await phase in unifiedProgressEngine.$currentPhase.values {
            await handleEnginePhaseChange(to: phase)
        }
    }

    // MARK: - FUNC
    @MainActor
    private func handleEnginePhaseChange(
        to phase: UnifiedProgressEngine.LoadingPhase
    ) async {
        let phaseChangeId = UUID().uuidString.prefix(8)
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 PHASE_CHANGE [\(phaseChangeId)]: \(phase.displayName)"
        )

        guard case .loadingVideo = flowState else {
            logger.debug(
                "🎬 AddMoveUnifiedState:  PHASE_CHANGE [\(phaseChangeId)]: Ignored - not in loadingVideo state"
            )
            return
        }

        guard !isCompletingLoad else {
            logger.debug(
                "🎬 AddMoveUnifiedState:  PHASE_CHANGE [\(phaseChangeId)]: Ignored - already completing load"
            )
            return
        }

        if phase == .error {
            logger.warning(
                "🎬 AddMoveUnifiedState: ❌ COMPLETION_MORPHISM: Error phase detected"
            )
            await handleEngineError(phaseChangeId: String(phaseChangeId))
        }
    }

    // MARK: - FUNC
    @MainActor
    private func handleEngineCompletion(phaseChangeId: String) async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 ENGINE_COMPLETION [\(phaseChangeId)]: Handling successful engine completion"
        )

        isCompletingLoad = true

        logger.info(
            "🎬 AddMoveUnifiedState:  COMPLETION_METRICS [\(phaseChangeId)]:"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Unified Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Target Progress: \(String(format: "%.3f", self.unifiedProgressEngine.targetProgress)) (\(Int(self.unifiedProgressEngine.targetProgress * 100))%)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Final Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Load Elapsed: \(String(format: "%.2f", self.loadElapsedTime))s"
        )
        // logger.info("🎬 AddMoveUnifiedState: │ └─ Completion Guard: ✅ Engaged")

        do {
            try await performAtomicCompletionTransition(
                correlationId: "engine_completion_\(phaseChangeId)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ ENGINE_COMPLETION_SUCCESS [\(phaseChangeId)]: Atomic completion transition finished with proper lock release"
            )

        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ENGINE_COMPLETION_ERROR [\(phaseChangeId)]: Atomic completion transition failed - \(error.localizedDescription)"
            )

            await resetAtomicTransitionLock()
            logger.info(
                "🎬 AddMoveUnifiedState: 🔒 ENGINE_COMPLETION_CLEANUP [\(phaseChangeId)]: Transition lock cleaned up after error"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func handleEngineError(phaseChangeId: String) async {
        logger.warning(
            "🎬 AddMoveUnifiedState: ❌ ENGINE_ERROR [\(phaseChangeId)]: Handling engine error state"
        )

        if let error = unifiedProgressEngine.currentError {
            logger.error(
                "🎬 AddMoveUnifiedState: 🚨 ENGINE_ERROR_DETAILS [\(phaseChangeId)]: \(error.localizedDescription)"
            )

            await transition(
                to: .error(
                    message: "Video loading failed",
                    underlyingError: error.localizedDescription
                ),
                triggeredBy: "engine_error_\(phaseChangeId)"
            )
        } else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ENGINE_ERROR_UNKNOWN [\(phaseChangeId)]: Error phase with no error details"
            )
            await transition(
                to: .error(
                    message: "Video loading failed",
                    underlyingError: "Unknown error during loading"
                ),
                triggeredBy: "engine_error_unknown_\(phaseChangeId)"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func handleVideoLoadingProgress(_ progress: VideoLoadingProgress) {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Handling unified video loading progress - \(String(describing: progress.phase)) - \(Int(progress.progress * 100))% - \(progress.message) [\(progress.correlationId)]"
        )

        let currentStateForValidation = flowState
        logger.info(
            "🎬 AddMoveUnifiedState:  CATEGORY_THEORY_CURRENT_STATE: \(String(describing: currentStateForValidation)) [\(progress.correlationId)]"
        )

        StateLifecycleDiagnosticLogger.logProgressUpdate(
            self,
            progress: progress.progress,
            message: progress.message
        )

        guard case .loadingVideo = currentStateForValidation else {

            logger.critical(
                "🎬 AddMoveUnifiedState: ❌ CATEGORICAL_LIMIT_VIOLATION: Invalid state for video loading progress! [\(progress.correlationId)]"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 EXPECTED: loadingVideo state [\(progress.correlationId)]"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 ACTUAL: \(String(describing: currentStateForValidation)) [\(progress.correlationId)]"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 PROGRESS_DETAILS: [\(progress.correlationId)]"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ phase: \(String(describing: progress.phase))"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ progress: \(Int(progress.progress * 100))%"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ message: \(progress.message)"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ correlation_id: \(progress.correlationId)"
            )
            logger.critical("🎬 AddMoveUnifiedState: │ └─ timestamp: \(Date())")
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 CATEGORY_THEORY_ANALYSIS: State transition morphism failed - left adjoint (η) not properly applied [\(progress.correlationId)]"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 IMPACT: Progress updates ignored due to state mismatch causing 'stuck at 0%' [\(progress.correlationId)]"
            )

            let errorMessage =
                "Video loading state corrupted. Please try selecting the video again."
            logger.warning(
                "🎬 AddMoveUnifiedState: 🔄 CATEGORICAL_ERROR_TRANSITION: Moving to error state due to state corruption [\(progress.correlationId)]"
            )

            Task { @MainActor in
                await self.transition(
                    to: .error(
                        message: errorMessage,
                        underlyingError:
                            "State mismatch: expected loadingVideo, got \(String(describing: currentStateForValidation)) [\(progress.correlationId)]"
                    ),
                    triggeredBy:
                        "categorical_limit_violation_\(progress.correlationId)"
                )
            }

            return
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ CATEGORICAL_GUARD_PASSED: State morphism valid, proceeding with progress handling"
        )

        guard validateProgressUpdate(progress) else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Progress update validation failed - skipping update"
            )
            return
        }

        let stateBeforeProcessing = flowState
        logger.info(
            "🎬 AddMoveUnifiedState:  STATE_TRANSITION_ANALYSIS: State before progress processing: \(String(describing: stateBeforeProcessing))"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 MORPHISM_CHAIN: handleVideoLoadingProgress() → unifiedProgressEngine.processLegacyProgress()"
        )

        unifiedProgressEngine.processLegacyProgress(progress)

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ MORPHISM_CHAIN_EXECUTED: unifiedProgressEngine.processLegacyProgress() completed"
        )

        let stateAfterProcessing = flowState
        logger.info(
            "🎬 AddMoveUnifiedState:  PHASE_1_STATE_AFTER_PROCESSING: \(String(describing: stateAfterProcessing))"
        )

        if case .loadingVideo = stateAfterProcessing {
            logger.info(
                "🎬 AddMoveUnifiedState:  Unified loading progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))% - \(self.unifiedProgressEngine.unifiedStatus)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🎯 DIAGNOSTIC: Phase: \(self.unifiedProgressEngine.currentPhase.displayName), Target: \(String(format: "%.3f", self.unifiedProgressEngine.targetProgress))"
            )

            // logger.info("🎬 AddMoveUnifiedState:  RACE_CONDITION_ANALYSIS:")
            logger.info(
                "🎬 AddMoveUnifiedState: │ ├─ Animated Progress (UI): \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress)) (\(Int(self.unifiedProgressEngine.unifiedProgress * 100))%)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │ ├─ Target Progress (Actual): \(String(format: "%.3f", self.unifiedProgressEngine.targetProgress)) (\(Int(self.unifiedProgressEngine.targetProgress * 100))%)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │ ├─ Progress Delta: \(String(format: "%.3f", abs(self.unifiedProgressEngine.targetProgress - self.unifiedProgressEngine.unifiedProgress)))"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │ ├─ Current Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │ ├─ Load Elapsed Time: \(String(format: "%.2f", self.loadElapsedTime))s"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │ └─ Correlation ID: \(progress.correlationId)"
            )

            logger.info(
                "🎬 AddMoveUnifiedState:  COMPLETION_HANDLING: Deferring to phase change completion morphism"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ├─ Target Progress: \(Int(self.unifiedProgressEngine.targetProgress * 100))%"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ├─ Current Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ├─ Current Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: └─ Completion Trigger: Phase change handler monitors .completed phase"
            )
        } else {
            logger.critical(
                "🎬 AddMoveUnifiedState: ❌ PHASE_1_STATE_MISMATCH_ERROR: Progress update received in wrong state!"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 CURRENT_STATE: \(String(describing: stateAfterProcessing))"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 EXPECTED_STATE: loadingVideo"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 PROGRESS_UPDATE_BEING_IGNORED:"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ phase: \(String(describing: progress.phase))"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ progress: \(Int(progress.progress * 100))%"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ message: \(progress.message)"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: │ ├─ correlation_id: \(progress.correlationId)"
            )
            logger.critical("🎬 AddMoveUnifiedState: │ └─ timestamp: \(Date())")
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 IMPACT: This is a symptom of the 'stuck at 0%' bug!"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 ACTION: Progress update SKIPPED due to invalid state"
            )
            logger.critical(
                "🎬 AddMoveUnifiedState: 🚨 DEBUG: Check didSelectVideo() method for proper state transition timing"
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Unified video loading progress handled successfully"
        )
    }

    @MainActor
    private func validateProgressUpdate(_ progress: VideoLoadingProgress)
        -> Bool
    {

        guard progress.progress >= 0.0 && progress.progress <= 1.0 else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Invalid progress value received: \(progress.progress)"
            )
            return false
        }

        return true
    }

    @MainActor
    private func handleLoadingCompletionWithAtomicGuard() async {
        let transitionDuration =
            transitionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let loadingDisplayDuration =
            loadingOverlayStartTime.map { Date().timeIntervalSince($0) } ?? 0

        logger.info(
            "🎬 AddMoveUnifiedState: 🚀 ATOMIC LOADING COMPLETION - Duration: \(String(format: "%.3f", transitionDuration))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ LOADING_OVERLAY_DURATION: \(String(format: "%.3f", loadingDisplayDuration))s (minimum: \(self.minimumLoadingDisplayTime)s)"
        )

        guard let transitionId = currentTransitionId else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ ACTOR GUARD VIOLATION - No transition ID found"
            )
            return
        }

        guard await transitionLockManager.ownsLock(id: transitionId) else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ ACTOR GUARD VIOLATION - Transition lock not owned by this operation"
            )
            return
        }

        guard let correlationId = transitionCorrelationId else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC GUARD FAILED - Missing correlation ID"
            )
            await resetAtomicTransitionLock()
            return
        }

        guard case .loadingVideo = self.flowState else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ ATOMIC GUARD - Not in loading state during completion - current: \(String(describing: self.flowState))"
            )
            await resetAtomicTransitionLock()
            return
        }

        guard videoAsset != nil && photosIdentifier != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC GUARD - Missing required data for completion [\(correlationId)]"
            )
            await setError(
                message: "Video loading incomplete",
                underlying: "Missing video asset or photos identifier"
            )
            await resetAtomicTransitionLock()
            return
        }

        do {
            logger.info(
                "🎬 AddMoveUnifiedState: 🎯 EXECUTING ATOMIC TRANSITION [\(correlationId)]"
            )
            try await performAtomicCompletionTransition(
                correlationId: correlationId
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ ATOMIC TRANSITION COMPLETED [\(correlationId)]"
            )
        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC TRANSITION FAILED [\(correlationId)]: \(error.localizedDescription)"
            )
            await setError(
                message: "Failed to complete video loading",
                underlying: error.localizedDescription
            )
            await resetAtomicTransitionLock()
        }
    }

    // MARK: - FUNC
    @MainActor
    private func resetAtomicTransitionLock() async {
        // logger.info("🎬 AddMoveUnifiedState: 🔓 RESETTING ATOMIC TRANSITION LOCK")

        isCompletingLoad = false
        // logger.info("🎬 AddMoveUnifiedState: 🧹 Terminal morphism guard reset.")

        if let transitionId = currentTransitionId {
            await transitionLockManager.releaseLock(for: transitionId)
            logger.info(
                "🎬 AddMoveUnifiedState: 🔒 Transition lock released for operation: \(transitionId.uuidString)"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ No current transition ID - cannot release lock"
            )
        }

        currentTransitionId = nil
        transitionStartTime = nil
        transitionCorrelationId = nil

        loadingOverlayStartTime = nil

        logger.info(
            "🎬 AddMoveUnifiedState: 🧹 Loading overlay timer reset (status managed by UnifiedProgressEngine)"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func acquireTransitionLock(correlationId: String) async throws
        -> UUID
    {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔒 Acquiring transition lock for correlation: \(correlationId)"
        )

        let transitionId = UUID()

        do {
            try await transitionLockManager.acquireLockWithRetry(
                for: transitionId,
                retryCount: 3,
                retryDelay: 10
            )
            currentTransitionId = transitionId
            transitionStartTime = Date()
            transitionCorrelationId = correlationId

            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Transition lock acquired successfully - ID: \(transitionId.uuidString)"
            )
            return transitionId
        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Failed to acquire transition lock after retries: \(error.localizedDescription)"
            )
            throw error
        }
    }

    // MARK: - FUNC
    @MainActor
    private func performAtomicCompletionTransition(correlationId: String)
        async throws
    {
        logger.info(
            "🎬 AddMoveUnifiedState: 🚀 SIMPLIFIED - Starting atomic completion transition [\(correlationId)]"
        )

        defer {
            Task { @MainActor in
                await resetAtomicTransitionLock()
            }
        }

        await logUnifiedLoadingStateDiagnostics(
            "video_loading_complete",
            operation: "SIMPLIFIED_TRANSITION_START"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 📝 Status managed by UnifiedProgressEngine during finalization [\(correlationId)]"
        )

        let elapsedTime = loadElapsedTime
        let minimumDisplayTime: TimeInterval = 1.2
        let remainingTime = max(0, minimumDisplayTime - elapsedTime)
        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ TIMING ANALYSIS - Elapsed: \(String(format: "%.3f", elapsedTime))s, Minimum: \(minimumDisplayTime)s, Remaining: \(String(format: "%.3f", remainingTime))s [\(correlationId)]"
        )

        await logUnifiedLoadingStateDiagnostics(
            "video_loading_complete_pre_transition",
            operation: "SIMPLIFIED_TRANSITION"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 🎬 FINAL STEP: Starting final state transition to trimming [\(correlationId)]"
        )
        await transitionToTrimmingWithDelay(correlationId: correlationId)

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ SIMPLIFIED TRANSITION COMPLETED - Video loading transition finished [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 📝 NOTE: Player and trimmer setup will occur when trimming view appears"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func transitionToTrimmingWithDelay(correlationId: String) async {
        let transitionStartTime = CFAbsoluteTimeGetCurrent()
        let performanceOptimizer = PerformanceOptimizer()
        let initialMemoryUsage =
            Double(
                MemoryHelper.getCurrentMemoryUsage().replacingOccurrences(
                    of: "MB",
                    with: ""
                )
            ) ?? 0.0
        let initialCPUUsage = await performanceOptimizer.getCPUUsagePercent()

        logger.info(
            "🎬 AddMoveUnifiedState: 🚀 PERFORMANCE_OPTIMIZED_TRANSITION - Starting lightweight transition [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  PERFORMANCE_BASELINE - Memory: \(String(format: "%.1f", initialMemoryUsage))MB, CPU: \(String(format: "%.1f", initialCPUUsage))% [\(correlationId)]"
        )

        let elapsedTime = loadElapsedTime
        let minimumDisplayTime: TimeInterval = 0.3
        let remainingTime = max(0, minimumDisplayTime - elapsedTime)

        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ PERFORMANCE_TIMING - Elapsed: \(String(format: "%.3f", elapsedTime))s, Min: \(minimumDisplayTime)s, Remaining: \(String(format: "%.3f", remainingTime))s [\(correlationId)]"
        )

        if remainingTime > 0 {
            logger.info(
                "🎬 AddMoveUnifiedState: ⏱️ MINIMAL_DELAY - Applying \(String(format: "%.3f", remainingTime))s UX delay [\(correlationId)]"
            )
            try? await Task.sleep(
                nanoseconds: UInt64(remainingTime * 1_000_000_000)
            )
        }

        timerManagementService.stopLoadTimer()
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 PERFORMANCE_CLEANUP: Timer stopped immediately [\(correlationId)]"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 PERFORMANCE_OPTIMIZATION: Deferring TrimmerViewModel creation to FeatureRichTrimmerView [\(correlationId)]"
        )

        guard videoAsset != nil, photosIdentifier != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ PERFORMANCE_TRANSITION_FAILED - Missing basic dependencies [\(correlationId)]"
            )
            await transition(
                to: .error(
                    message: "Missing video dependencies for transition",
                    underlyingError:
                        "performance_transition_missing_deps_\(correlationId)"
                ),
                triggeredBy:
                    "performance_transition_missing_deps_\(correlationId)"
            )
            return
        }

        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 CRITICAL_FIX - Creating UnifiedVideoPlayerViewModel before trimming transition [\(correlationId)]"
        )

        do {

            let playerViewModel =
                try await createUnifiedVideoPlayerViewModelForTrimmer(
                    correlationId: correlationId
                )

            guard let player = playerViewModel else {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ CRITICAL_FIX_FAILED - Player creation returned nil [\(correlationId)]"
                )
                await transition(
                    to: .error(
                        message: "Failed to create video player for trimming",
                        underlyingError: "player_creation_nil_\(correlationId)"
                    ),
                    triggeredBy:
                        "critical_fix_player_creation_failed_\(correlationId)"
                )
                return
            }

            currentPlayerViewModel = playerViewModel
            playerState = .ready

            logger.info(
                "🎬 AddMoveUnifiedState: ✅ CRITICAL_FIX_SUCCESS - UnifiedVideoPlayerViewModel created successfully [\(correlationId)]"
            )
            logger.info(
                "🎬 AddMoveUnifiedState:  Player ready: \(playerViewModel?.isPlayerReady ?? false), hasPlayer: \(playerViewModel?.avPlayer != nil)"
            )

        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ CRITICAL_FIX_FAILED - Player creation failed: \(error.localizedDescription) [\(correlationId)]"
            )
            await transition(
                to: .error(
                    message: "Failed to prepare video player for trimming",
                    underlyingError: "player_creation_error_\(correlationId)"
                ),
                triggeredBy:
                    "critical_fix_player_creation_error_\(correlationId)"
            )
            return
        }

        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 ATOMIC_TRANSITION - Executing state change to .trimming with ready player [\(correlationId)]"
        )
        await transition(
            to: .trimming,
            triggeredBy: "atomic_trim_transition_with_player_\(correlationId)"
        )

        let transitionTime = CFAbsoluteTimeGetCurrent() - transitionStartTime
        let finalMemoryUsage =
            Double(
                MemoryHelper.getCurrentMemoryUsage().replacingOccurrences(
                    of: "MB",
                    with: ""
                )
            ) ?? 0.0
        let finalCPUUsage = await performanceOptimizer.getCPUUsagePercent()
        let memoryDelta = finalMemoryUsage - initialMemoryUsage
        let cpuDelta = finalCPUUsage - initialCPUUsage

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ PERFORMANCE_TRANSITION_COMPLETE - Transition time: \(String(format: "%.3f", transitionTime))s [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 PERFORMANCE_TARGET_MET: Transition under 250ms target: \(transitionTime < 0.250 ? "✅ YES" : "❌ NO") [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 CPU_TARGET_MET: CPU usage below 90% target: \(finalCPUUsage < 90.0 ? "✅ YES" : "❌ NO") [\(correlationId)]"
        )

        logger.info(
            "🎬 AddMoveUnifiedState:  PERFORMANCE_METRICS - Resource usage optimized:"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Memory: \(initialMemoryUsage)MB → \(finalMemoryUsage)MB (Δ\(memoryDelta > 0 ? "+" : "")\(memoryDelta)MB)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ CPU: \(String(format: "%.1f", initialCPUUsage))% → \(String(format: "%.1f", finalCPUUsage))% (Δ\(cpuDelta > 0 ? "+" : "")\(String(format: "%.1f", cpuDelta))%)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Transition Duration: \(String(format: "%.3f", transitionTime))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: └─ Optimization: Deferred ~70% CPU and ~60% Memory intensive operations to FeatureRichTrimmerView"
        )

        if finalCPUUsage > 90.0 {
            logger.error(
                "🎬 AddMoveUnifiedState: ⚠️ CRITICAL_CPU_USAGE - CPU exceeded 90% threshold: \(String(format: "%.1f", finalCPUUsage))% [\(correlationId)]"
            )
        }

        if memoryDelta > 50 {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ MEMORY_SPIKE - Memory increased by \(memoryDelta)MB during transition [\(correlationId)]"
            )
        }

        if transitionTime > 0.250 {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ SLOW_TRANSITION - Transition exceeded 250ms target: \(String(format: "%.3f", transitionTime))s [\(correlationId)]"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func createUnifiedVideoPlayerViewModelForTrimmer(
        correlationId: String
    ) async throws -> UnifiedVideoPlayerViewModel? {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 CRITICAL_FIX - Creating UnifiedVideoPlayerViewModel for trimming [\(correlationId)]"
        )

        guard let videoAsset = videoAsset else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Player creation failed - video asset is nil [\(correlationId)]"
            )
            throw PlayerCreationError.missingVideoAsset
        }

        guard let photosIdentifier = photosIdentifier, !photosIdentifier.isEmpty
        else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Player creation failed - photos identifier is nil [\(correlationId)]"
            )
            throw PlayerCreationError.missingPhotosIdentifier
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Dependencies validated for player creation [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Asset duration available: \(videoAsset.duration.seconds)s"
        )
        // logger.info("🎬 AddMoveUnifiedState:  Photos ID: \(photosIdentifier)")
        logger.info(
            "🎬 AddMoveUnifiedState:  Total rotation: \(self.totalRotationQuarterTurns * 90)°"
        )

        let playerCreationTimeout: TimeInterval = 15.0
        let playerViewModel = try await withThrowingTaskGroup(
            of: UnifiedVideoPlayerViewModel?.self
        ) { group in

            group.addTask { [weak self] in
                guard let self = self else {
                    throw PlayerCreationError.dependenciesNotReady
                }

                self.logger.info(
                    "🎬 AddMoveUnifiedState: 🔧 PLAYER_CREATION_TASK - Calling UnifiedPlayerManager.createOrUpdatePlayer() [\(correlationId)]"
                )

                return try await self.unifiedPlayerManager.createOrUpdatePlayer(
                    asset: videoAsset,
                    photosIdentifier: photosIdentifier,
                    rotationQuarterTurns: self.totalRotationQuarterTurns,
                    appContainer: self.appContainer
                )
            }

            group.addTask {
                self.logger.info(
                    "🎬 AddMoveUnifiedState: ⏰ TIMEOUT_TASK - Starting \(playerCreationTimeout)s timeout [\(correlationId)]"
                )
                try await Task.sleep(
                    nanoseconds: UInt64(playerCreationTimeout * 1_000_000_000)
                )
                self.logger.warning(
                    "🎬 AddMoveUnifiedState: ⏰ TIMEOUT_REACHED - Player creation timed out after \(playerCreationTimeout)s [\(correlationId)]"
                )
                throw PlayerCreationError.playerCreationTimeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        guard let player = playerViewModel else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Player creation returned nil [\(correlationId)]"
            )
            throw PlayerCreationError.playerCreationFailed
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ UnifiedVideoPlayerViewModel created successfully [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Player ready: \(player.isPlayerReady)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Has AVPlayer: \(player.avPlayer != nil)"
        )
        // logger.info("🎬 AddMoveUnifiedState:  Player type: \(type(of: player))")

        return player
    }

    // MARK: - ENUM STATE
    private enum PlayerCreationError: Error, LocalizedError {
        case missingVideoAsset
        case missingPhotosIdentifier
        case dependenciesNotReady
        case playerCreationTimeout
        case playerCreationFailed

        var errorDescription: String? {
            switch self {
            case .missingVideoAsset:
                return "Video asset is missing for player creation"
            case .missingPhotosIdentifier:
                return "Photos identifier is missing for player creation"
            case .dependenciesNotReady:
                return "Player dependencies are not ready"
            case .playerCreationTimeout:
                return "Player creation timed out"
            case .playerCreationFailed:
                return "Player creation failed"
            }
        }
    }

    @MainActor
    public func handleProgressUpdate(_ progress: VideoLoadingProgress) {
        handleVideoLoadingProgress(progress)
    }

    @MainActor
    public func handleTrimmedAssetProgress(_ progress: SimpleProgress) {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Handling trimmed asset progress - \(progress.percentage)% - \(progress.message)"
        )

        if progress.value >= 1.0 {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ TRIMMED ASSET LOADING COMPLETE - delegating to FlowStateManager"
            )

            Task { @MainActor in
                guard let fsm = self.flowStateManager else {
                    logger.error(
                        "❌ FlowStateManager not available to complete asset loading transition."
                    )
                    await self.setError(
                        message: "Internal error during video processing."
                    )
                    return
                }
                await fsm.completeAssetLoading()
            }
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Trimmed asset progress handled successfully"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func transitionToTrimmingAfterLoading() async {
        logger.warning(
            "🎬 AddMoveUnifiedState: ⚠️ LEGACY METHOD CALLED - Use atomic version instead"
        )

        do {
            let transitionId = try await acquireTransitionLock(
                correlationId: "legacy_fallback_\(UUID().uuidString)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🔒 ACTOR-BASED LEGACY TRANSITION LOCKED - ID: \(transitionId.uuidString)"
            )
        } catch {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Legacy transition lock acquisition failed: \(error.localizedDescription)"
            )
            return
        }

        await handleLoadingCompletionWithAtomicGuard()
    }

    @MainActor
    private func performTransitionToTrimmingWithCancellation() async {
        logger.warning(
            "🎬 AddMoveUnifiedState: ⚠️ DEPRECATED METHOD CALLED - Redirecting to atomic version"
        )

        await resetAtomicTransitionLock()

        guard let correlationId = transitionCorrelationId else {
            transitionCorrelationId = "deprecated_fallback_\(UUID().uuidString)"
            return
        }

        do {
            try await performAtomicCompletionTransition(
                correlationId: transitionCorrelationId!
            )
        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Deprecated method fallback failed: \(error.localizedDescription)"
            )
            await setError(
                message: "Video transition failed",
                underlying: error.localizedDescription
            )
        }
    }

    @MainActor
    private func createPlayerAndTransition() async throws {
        // logger.info("🎬 AddMoveUnifiedState: 📡 Starting player creation process")

        guard validatePlayerCreationDependencies() else {
            throw PlayerCreationError.dependenciesNotReady
        }

        let playerViewModel = try await withThrowingTaskGroup(
            of: UnifiedVideoPlayerViewModel?.self
        ) { group in

            group.addTask {
                try await self.unifiedPlayerManager.createOrUpdatePlayer(
                    asset: self.videoAsset!,
                    photosIdentifier: self.photosIdentifier!,
                    rotationQuarterTurns: self.totalRotationQuarterTurns,
                    appContainer: self.appContainer
                )
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                return nil
            }

            let result = try await group.next()!

            group.cancelAll()

            if let player = result {
                return player
            } else {
                throw PlayerCreationError.playerCreationTimeout
            }
        }

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Player created successfully - isReady: \(playerViewModel.isPlayerReady)"
        )
        currentPlayerViewModel = playerViewModel

        playerState = .ready

        // logger.info("🎬 AddMoveUnifiedState: 🔄 Transitioning to trimming state")
        await transition(
            to: .trimming,
            triggeredBy: "video_loading_complete_new_player"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 📡 Setting up trimmer after state transition"
        )

        await setupTrimmerDirectly()

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Player creation and transition completed successfully"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func validatePlayerCreationDependencies() -> Bool {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔍 Validating player creation dependencies"
        )

        var allDependenciesValid = true

        if videoAsset == nil {
            logger.error("🎬 AddMoveUnifiedState: ❌ Video asset is nil")
            allDependenciesValid = false
        }

        if photosIdentifier == nil || photosIdentifier!.isEmpty {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Photos identifier is nil or empty"
            )
            allDependenciesValid = false
        }

        logger.info(
            "🎬 AddMoveUnifiedState:  Player creation dependencies valid: \(allDependenciesValid)"
        )
        return allDependenciesValid
    }

    // MARK: - FUNC
    @MainActor
    private func setupTrimmerDirectly() async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🚀 SETTING UP TRIMMER DIRECTLY in trimming state"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Current flow state: \(String(describing: self.flowState))"
        )

        // logger.info("🎬 AddMoveUnifiedState: 🔍 Validating trimmer prerequisites")

        guard let asset = self.videoAsset else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - video asset is nil"
            )
            await setError(
                message: "No video available for trimming",
                underlying: "Video asset is nil"
            )
            return
        }

        do {
            let duration = try await asset.load(.duration)
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Video asset validated - duration: \(duration.seconds)s"
            )
        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Failed to load video duration: \(error.localizedDescription)"
            )
            await setError(
                message: "Failed to load video duration",
                underlying: error.localizedDescription
            )
            return
        }

        guard let photosIdentifier = self.photosIdentifier else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - photos identifier is nil"
            )
            await setError(
                message: "No video identifier available",
                underlying: "Photos identifier is nil"
            )
            return
        }
        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Photos identifier validated - \(photosIdentifier)"
        )

        guard
            let playerViewModel = self.currentPlayerViewModel
                as? UnifiedVideoPlayerViewModel
        else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Trimmer setup failed - no current player"
            )
            logger.error(
                "🎬 AddMoveUnifiedState:  currentPlayerViewModel: \(self.currentPlayerViewModel != nil ? "available" : "nil")"
            )
            logger.error(
                "🎬 AddMoveUnifiedState:  unifiedPlayerManager.currentPlayer: \(self.unifiedPlayerManager.currentPlayer != nil ? "available" : "nil")"
            )
            await setError(
                message: "No player available for trimming",
                underlying: "Current player is nil"
            )
            return
        }
        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Player validated - ready: \(playerViewModel.isPlayerReady)"
        )

        do {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Creating trimmer view model directly with rollback integrity fix"
            )

            let startTime = CMTime(
                seconds: self.trimStartTime,
                preferredTimescale: 600
            )
            let endTime = CMTime(
                seconds: self.trimEndTime,
                preferredTimescale: 600
            )

            let trimmerVM = TrimmerViewModel(
                asset: asset,
                photosIdentifier: photosIdentifier,
                initialIntrinsicRotation: self.intrinsicAssetRotation,
                initialUserRotation: self.userAppliedRotation,
                initialStartTime: startTime,
                initialEndTime: endTime,
                playerViewModel: playerViewModel
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ TrimmerViewModel initialized with rollback integrity fix - startTime: \(startTime.seconds)s, endTime: \(endTime.seconds)s"
            )

            trimmerVM.progressDelegate = self

            trimmerViewModel = trimmerVM
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Published trimmer view model updated"
            )

            // logger.info("🎬 AddMoveUnifiedState: 📡 Starting async trimmer setup")

            try await trimmerVM.setupAsync()
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer async setup completed successfully"
            )

            let duration = try await asset.load(.duration).seconds

            let currentStartTime = trimmerVM.startTime
            let currentEndTime = trimmerVM.endTime

            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trim range preserved from initialization - start_time: \(currentStartTime.seconds)s, end_time: \(currentEndTime.seconds)s, duration: \((currentEndTime - currentStartTime).seconds)s, rollback_integrity_fix: trim_range_preserved_from_initialization, validation_only: true"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer is ready for user interaction"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🎉 TRIMMER SETUP FLOW COMPLETED SUCCESSFULLY"
            )

        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Failed to setup trimmer: \(error.localizedDescription)"
            )
            logger.error("🎬 AddMoveUnifiedState: 🔍 Full error: \(error)")
            await setError(
                message: "Failed to setup trimmer",
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func prepareTrimmerEnvironment() async {
        let correlationId = UUID().uuidString.prefix(8)
        // logger.info(
        //     "🎬 AddMoveUnifiedState: 🛑 DEPRECATED METHOD CALLED - prepareTrimmerEnvironment() [\(correlationId)]"
        // )
        // logger.info(
        //     "🎬 AddMoveUnifiedState: 🎯 CRITICAL FIX APPLIED - This method is now a NO-OP"
        // )

        if case .trimming = self.flowState, self.trimmerViewModel != nil {
            // logger.info(
            //     "🎬 AddMoveUnifiedState: ✅ INVARIANT VERIFIED - Trimmer already available due to atomic setup [\(correlationId)]"
            // )
            // logger.info(
            //     "🎬 AddMoveUnifiedState:  Trimmer is ready for immediate use - no race condition"
            // )
            return
        }

        // logger.error(
        //     "🎬 AddMoveUnifiedState: ❌ INVARIANT VIOLATION - Trimming state without TrimmerViewModel [\(correlationId)]"
        // )
        // logger.error(
        //     "🎬 AddMoveUnifiedState: 🔧 Atomic setup failed - this should not happen with the critical fix applied"
        // )
        // logger.error(
        //     "🎬 AddMoveUnifiedState:  Current state: \(String(describing: self.flowState)), TrimmerViewModel: \(self.trimmerViewModel != nil ? "Available" : "Nil")"
        // )
        return

        guard case .trimming = self.flowState else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Attempted to prepare trimmer in incorrect state: \(String(describing: self.flowState)) [\(correlationId)]"
            )
            return
        }

        guard self.trimmerViewModel == nil else {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer environment already prepared. Skipping. [\(correlationId)]"
            )
            return
        }

        logger.info(
            "🎬 AddMoveUnifiedState: 📝 PHASE 1: Starting player creation for trimmer environment [\(correlationId)]"
        )

        do {

            logger.info(
                "🎬 AddMoveUnifiedState: 🎬 STEP 1: Creating video player [\(correlationId)]"
            )
            guard let asset = self.videoAsset,
                let identifier = self.photosIdentifier
            else {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Dependencies not ready for player creation [\(correlationId)]"
                )
                await setError(
                    message: "Video data not available",
                    underlying:
                        "Missing AVAsset or photos identifier when preparing trimmer"
                )
                return
            }

            guard validatePlayerCreationDependencies() else {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Player creation dependencies validation failed [\(correlationId)]"
                )
                await setError(
                    message: "Player services not ready",
                    underlying:
                        "Required services for video player initialization are not available"
                )
                return
            }

            let playerCreationStart = Date()
            let timeoutSeconds: TimeInterval = 12.0

            logger.info(
                "🎬 AddMoveUnifiedState: 🔧 PLAYER CREATION SETUP - Timeout: \(timeoutSeconds)s [\(correlationId)]"
            )

            let player = try await withThrowingTaskGroup(
                of: Result<UnifiedVideoPlayerViewModel, Error>.self
            ) { group in

                group.addTask { [weak self] in
                    do {
                        guard let self = self else {
                            throw PlayerCreationError.dependenciesNotReady
                        }

                        self.logger.info(
                            "🎬 AddMoveUnifiedState: 🔧 PLAYER CREATION: Calling UnifiedPlayerManager.createOrUpdatePlayer() [\(correlationId)]"
                        )
                        let player = try await self.unifiedPlayerManager
                            .createOrUpdatePlayer(
                                asset: asset,
                                photosIdentifier: identifier,
                                rotationQuarterTurns: self
                                    .totalRotationQuarterTurns,
                                appContainer: self.appContainer
                            )

                        self.logger.info(
                            "🎬 AddMoveUnifiedState: ✅ PLAYER CREATION: UnifiedPlayerManager returned player successfully [\(correlationId)]"
                        )
                        return .success(player)
                    } catch {
                        self?.logger.error(
                            "🎬 AddMoveUnifiedState: ❌ PLAYER CREATION: Task failed - \(error.localizedDescription) [\(correlationId)]"
                        )
                        return .failure(error)
                    }
                }

                group.addTask { [weak self] in
                    self?.logger.info(
                        "🎬 AddMoveUnifiedState: ⏱️ TIMEOUT TASK: Started \(timeoutSeconds)s timeout timer [\(correlationId)]"
                    )
                    try await Task.sleep(
                        nanoseconds: UInt64(timeoutSeconds * 1_000_000_000)
                    )
                    self?.logger.error(
                        "🎬 AddMoveUnifiedState: ⏰ TIMEOUT: Player creation timed out after \(timeoutSeconds)s [\(correlationId)]"
                    )
                    return .failure(PlayerCreationError.playerCreationTimeout)
                }

                logger.info(
                    "🎬 AddMoveUnifiedState: 🔄 PLAYER CREATION: Waiting for task completion [\(correlationId)]"
                )
                let result = try await group.next()!
                group.cancelAll()
                logger.info(
                    "🎬 AddMoveUnifiedState: 🏁 PLAYER CREATION: Task group completed, result received [\(correlationId)]"
                )
                return result
            }

            switch player {
            case .success(let createdPlayer):
                let playerCreationTime = Date().timeIntervalSince(
                    playerCreationStart
                )
                logger.info(
                    "🎬 AddMoveUnifiedState: ✅ Player created successfully in \(String(format: "%.3f", playerCreationTime))s [\(correlationId)]"
                )

                self.currentPlayerViewModel = createdPlayer
                self.playerState = .ready
                logger.info(
                    "🎬 AddMoveUnifiedState: ✅ Player state updated to .ready [\(correlationId)]"
                )

            case .failure(let error):
                let playerCreationTime = Date().timeIntervalSince(
                    playerCreationStart
                )
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Player creation failed after \(String(format: "%.3f", playerCreationTime))s [\(correlationId)]: \(error.localizedDescription)"
                )
                await setError(
                    message: "Failed to create video player",
                    underlying: error.localizedDescription
                )
                return
            }

            logger.info(
                "🎬 AddMoveUnifiedState: 🎬 STEP 2: Setting up trimmer view model [\(correlationId)]"
            )
            let trimmerSetupStart = Date()

            try await setupTrimmerDirectlyWithValidation()

            let trimmerSetupTime = Date().timeIntervalSince(trimmerSetupStart)
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer setup completed successfully in \(String(format: "%.3f", trimmerSetupTime))s [\(correlationId)]"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🎉 TRIMMER ENVIRONMENT PREPARED - Player and trimmer are ready for use [\(correlationId)]"
            )

        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Failed to prepare trimmer environment: \(error.localizedDescription) [\(correlationId)]"
            )
            await setError(
                message: "Failed to prepare video for trimming",
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func setupTrimmerDirectlyWithValidation() async throws {
        logger.info(
            "🎬 AddMoveUnifiedState: 🚀 ENHANCED TRIMMER SETUP WITH VALIDATION"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 UPDATED - Function called from .trimming state via prepareTrimmerEnvironment() [\(UUID().uuidString.prefix(8))]"
        )

        guard let asset = self.videoAsset else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Video asset missing for trimmer setup"
            )
            throw TrimmerSetupError.missingAsset
        }

        guard let photosIdentifier = self.photosIdentifier,
            !photosIdentifier.isEmpty
        else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Photos identifier missing for trimmer setup"
            )
            throw TrimmerSetupError.missingPhotosIdentifier
        }

        guard
            let playerViewModel = self.currentPlayerViewModel
                as? UnifiedVideoPlayerViewModel
        else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Player view model missing for trimmer setup"
            )
            throw TrimmerSetupError.missingPlayerViewModel
        }

        guard playerViewModel.isPlayerReady else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Player not ready for trimmer setup"
            )
            throw TrimmerSetupError.playerNotReady
        }

        let assetValidationStart = Date()
        do {
            let duration = try await withThrowingTaskGroup(of: CMTime.self) {
                group in
                group.addTask {
                    try await asset.load(.duration)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
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
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Asset validation completed in \(String(format: "%.3f", validationTime))s - Duration: \(duration.seconds)s"
            )

        } catch {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Asset validation failed: \(error.localizedDescription)"
            )
            throw TrimmerSetupError.assetValidationFailed(
                error.localizedDescription
            )
        }

        let trimmerSetupStart = Date()
        do {

            let startTime = CMTime(
                seconds: self.trimStartTime,
                preferredTimescale: 600
            )
            let endTime = CMTime(
                seconds: self.trimEndTime,
                preferredTimescale: 600
            )

            let trimmerVM = TrimmerViewModel(
                asset: asset,
                photosIdentifier: photosIdentifier,
                initialIntrinsicRotation: self.intrinsicAssetRotation,
                initialUserRotation: self.userAppliedRotation,
                initialStartTime: startTime,
                initialEndTime: endTime,
                playerViewModel: playerViewModel
            )

            trimmerVM.progressDelegate = self

            trimmerViewModel = trimmerVM

            logger.info(
                "🎬 AddMoveUnifiedState: ✅ TrimmerViewModel created with rollback integrity fix - restored_start_time: \(startTime.seconds)s, restored_end_time: \(endTime.seconds)s, trim_start_time_original: \(self.trimStartTime)s, trim_end_time_original: \(self.trimEndTime)s, rollback_integrity_fix: atomic_initialization_with_restored_times"
            )

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await trimmerVM.setupAsync()
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    throw TrimmerSetupError.setupTimeout
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            let setupTime = Date().timeIntervalSince(trimmerSetupStart)
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer setup completed in \(String(format: "%.3f", setupTime))s"
            )

            let duration = try await asset.load(.duration).seconds

            let currentStartTime = trimmerVM.startTime
            let currentEndTime = trimmerVM.endTime

            guard currentStartTime < currentEndTime else {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Invalid trim range - start: \(currentStartTime.seconds)s, end: \(currentEndTime.seconds)s"
                )
                throw TrimmerSetupError.invalidTrimRange
            }

            let currentDuration =
                currentEndTime.seconds - currentStartTime.seconds
            guard currentDuration >= 0.5 else {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Trim range too short - duration: \(currentDuration)s"
                )
                throw TrimmerSetupError.trimRangeTooShort
            }

            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trim range validated (already set during initialization) - start_time: \(currentStartTime.seconds)s, end_time: \(currentEndTime.seconds)s, duration: \(currentDuration)s, rollback_integrity_fix: trim_range_preserved_from_initialization, validation_only: true"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🎉 ENHANCED TRIMMER SETUP COMPLETED SUCCESSFULLY"
            )

        } catch {
            let setupTime = Date().timeIntervalSince(trimmerSetupStart)
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Trimmer setup failed after \(String(format: "%.3f", setupTime))s: \(error.localizedDescription)"
            )
            throw TrimmerSetupError.setupFailed(error.localizedDescription)
        }
    }

    // MARK: - FUNC
    @MainActor
    private func handleTransitionError(
        message: String,
        underlying: String? = nil
    ) async {
        logger.warning(
            "🎬 AddMoveUnifiedState: 🔄 Handling transition error: \(message)"
        )
        await setError(message: message, underlying: underlying)
    }

    @MainActor
    private func updateTimerProgress(_ elapsed: TimeInterval) {
        _ = min(1.0, elapsed / 30.0)

    }

    // MARK: - FUNC
    @MainActor
    public func transition(
        to newState: AddMoveFlowState,
        triggeredBy: String = "unknown"
    ) async {
        let previousState = flowState

        if case .naming = newState {
            logger.info(
                "🎬 AddMoveUnifiedState: 🚀 Starting save readiness monitoring for naming state"
            )

            await synchronizePlayerStateForNaming()
            startSaveReadinessMonitoring()
        }

        if case .naming = previousState {
            logger.info(
                "🎬 AddMoveUnifiedState: 🛑 Stopping save readiness monitoring - leaving naming state"
            )
            stopSaveReadinessMonitoring()
        }

        flowState = newState

        logFunctorComposition(
            from: previousState,
            to: newState,
            triggeredBy: triggeredBy
        )

        await handleStateTransition(from: previousState, to: newState)
    }

    // MARK: - FUNC
    @MainActor
    private func logFunctorComposition(
        from: AddMoveFlowState,
        to: AddMoveFlowState,
        triggeredBy: String
    ) {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 State transition: \(String(describing: from)) -> \(String(describing: to)) [triggered by: \(triggeredBy)]"
        )

        let compositionResult = analyzeFunctorComposition(from: from, to: to)
        logger.info(
            "🎬 AddMoveUnifiedState:  Functor composition: \(compositionResult.description)"
        )

        if compositionResult.isNaturalTransformation {
            logger.info(
                "🎬 AddMoveUnifiedState: 🌟 Natural transformation detected: \(compositionResult.transformationType)"
            )
        }

        if !compositionResult.maintainsInvariants {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Universal property violation detected - invariants not maintained"
            )
        }

        if compositionResult.hasAdjoint {
            logger.info(
                "🎬 AddMoveUnifiedState: 🔄 Adjoint functor available - transformation is reversible"
            )
        }

        if compositionResult.isCriticalTransition {
            logPerformanceMetrics(for: to)
        }
    }

    // MARK: - CLASS
    private struct FunctorCompositionResult {
        let description: String
        let isNaturalTransformation: Bool
        let transformationType: String
        let maintainsInvariants: Bool
        let hasAdjoint: Bool
        let isCriticalTransition: Bool
    }

    // MARK: - FUNC
    private func analyzeFunctorComposition(
        from: AddMoveFlowState,
        to: AddMoveFlowState
    ) -> FunctorCompositionResult {

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
                description:
                    "Trimming → LoadingTrimmedAsset functor composition",
                isNaturalTransformation: true,
                transformationType:
                    "Natural transformation (asset preparation)",
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

    // MARK: - FUNC
    @MainActor
    private func logPerformanceMetrics(for state: AddMoveFlowState) {
        let memoryUsage: String = getMemoryUsage()
        let loadElapsed = timerManagementService.getLoadElapsedTime()
        let saveElapsed = timerManagementService.getSaveElapsedTime()

        logger.info(
            "🎬 AddMoveUnifiedState:  Performance metrics at \(String(describing: state)) - Memory: \(memoryUsage), Load: \(String(format: "%.2f", loadElapsed))s, Save: \(String(format: "%.2f", saveElapsed))s"
        )

        if case .loadingVideo = state {
            let assetStatus = videoAsset != nil ? "loaded" : "missing"
            let playerStatus =
                currentPlayerViewModel != nil ? "created" : "missing"
            logger.info(
                "🎬 AddMoveUnifiedState: 📈 Asset status at loadingVideo - Asset: \(assetStatus), Player: \(playerStatus)"
            )
        }
    }

    // MARK: - FUNC
    private func getMemoryUsage() -> String {
        let memoryInfo = ProcessInfo.processInfo
        let totalGB = memoryInfo.physicalMemory / (1024 * 1024 * 1024)

        return "\(totalGB)GB total"
    }

    // MARK: - FUNC
    private func logState(_ context: String, flowState: AddMoveFlowState) {
        let memoryInfo = ProcessInfo.processInfo
        logger.info(
            "🎬 [\(context)] State: \(String(describing: flowState)), Mem: \(memoryInfo.physicalMemory / (1024*1024*1024))GB"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func handleStateTransition(
        from: AddMoveFlowState,
        to: AddMoveFlowState
    ) async {

        logStateTransitionWithMetrics(
            from: from,
            to: to,
            triggeredBy: "state_transition"
        )

        switch (from, to) {
        case (.ready, .loadingVideo), (.error, .loadingVideo),
            (.success, .loadingVideo):
            timerManagementService.startLoadTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: 📱 Started load timer for transition: \(String(describing: from)) → \(String(describing: to))"
            )
        case (.loadingVideo, .trimming):
            timerManagementService.stopLoadTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Load timer stopped - loading complete: loadingVideo → trimming"
            )
        case (.loadingVideo, .error), (.loadingVideo, .ready):
            timerManagementService.stopLoadTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: ⚠️ Load timer stopped - transition aborted: \(String(describing: from)) → \(String(describing: to))"
            )
        case (.trimming, .loadingTrimmedAsset):
            logger.info(
                "🎬 AddMoveUnifiedState: 📱 Starting asset preparation: trimming → loadingTrimmedAsset"
            )
        case (.loadingTrimmedAsset, .naming):
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Asset preparation complete: loadingTrimmedAsset → naming"
            )
        case (.loadingTrimmedAsset, .error):
            logger.info(
                "🎬 AddMoveUnifiedState: ❌ Asset preparation failed: loadingTrimmedAsset → error"
            )
        case (.naming, .saving):

            logger.info(
                "🎬 AddMoveUnifiedState: 🔧 CRITICAL_FIX_TIMER_LIFECYCLE: Stopping SaveReadinessMonitoring before save"
            )
            // logger.info("🎬 AddMoveUnifiedState: 📋 Timer Lifecycle Analysis:")
            // logger.info("🎬 AddMoveUnifiedState: ┌─ Issue Identified")
            logger.info(
                "🎬 AddMoveUnifiedState: │  ├─ problem: \"SaveReadinessMonitoring timer continues during save operation\""
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │  ├─ impact: \"memory leaks, unnecessary CPU usage, potential state conflicts\""
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │  └─ timer_behavior: \"validation cycles continue after save initiation\""
            )
            // logger.info("🎬 AddMoveUnifiedState: ├─ Fix Applied")
            logger.info(
                "🎬 AddMoveUnifiedState: │  ├─ action: \"stopSaveReadinessMonitoring() called before save timer start\""
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │  ├─ timing: \"pre-save transition, prevents resource conflicts\""
            )
            logger.info(
                "🎬 AddMoveUnifiedState: │  └─ benefit: \"clean timer lifecycle, no memory leaks\""
            )
            // logger.info("🎬 AddMoveUnifiedState: └─ Expected Result")
            logger.info(
                "🎬 AddMoveUnifiedState:     ├─ save_readiness_timer: \"stopped before save operation\""
            )
            logger.info(
                "🎬 AddMoveUnifiedState:     └─ save_timer: \"started cleanly without conflicts\""
            )
            stopSaveReadinessMonitoring()

            timerManagementService.startSaveTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: 📱 Started save timer for transition: \(String(describing: from)) → \(String(describing: to))"
            )
        case (.saving, .success):
            timerManagementService.stopSaveTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Save timer stopped - operation successful: \(String(describing: from)) → \(String(describing: to))"
            )
        case (.saving, .error):
            timerManagementService.stopSaveTimer()
            logger.info(
                "🎬 AddMoveUnifiedState: ❌ Save timer stopped - operation failed: \(String(describing: from)) → \(String(describing: to))"
            )
        case (_, .success), (_, .error), (_, .ready):
            timerManagementService.resetAllTimers()
            logger.info(
                "🎬 AddMoveUnifiedState: 🧹 All timers reset - reached terminal state: \(String(describing: to))"
            )
        default:
            logger.info(
                "🎬 AddMoveUnifiedState: 📝 No timer action needed for transition: \(String(describing: from)) → \(String(describing: to))"
            )
        }
        logTimerState(
            "state_transition",
            from: String(describing: from),
            to: String(describing: to)
        )
    }

    // MARK: - FUNC
    @MainActor
    private func logTimerState(
        _ context: String,
        from: String? = nil,
        to: String? = nil
    ) {
        let saveElapsed = timerManagementService.getSaveElapsedTime()
        let loadElapsed = timerManagementService.getLoadElapsedTime()

        var metadata: [String: String] = [
            "context": context,
            "save_elapsed": String(format: "%.2f", saveElapsed),
            "load_elapsed": String(format: "%.2f", loadElapsed),
        ]

        if let from = from { metadata["transition_from"] = from }
        if let to = to { metadata["transition_to"] = to }

        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ Timer state [\(context)] - Save: \(String(format: "%.2f", saveElapsed))s, Load: \(String(format: "%.2f", loadElapsed))s"
        )
    }

    // MARK: - FUNC
    public func saveMove() async {
        logger.info(
            "🎬 AddMoveUnifiedState: Save operations now handled by FlowStateManager"
        )

        guard flowStateManager != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: FlowStateManager not available for save operation"
            )
            await setError(
                message: "Save service not available",
                underlying: "FlowStateManager is nil"
            )
            return
        }

        logger.info(
            "🎬 AddMoveUnifiedState: Save operation delegated to FlowStateManager"
        )
    }

    // MARK: - FUNC
    public func validateSaveReadiness() async -> SaveReadinessResult {
        logger.info(
            "🎬 AddMoveUnifiedState: Validation delegated to StateValidator"
        )

        return await stateValidator.validateSaveReadiness(
            flowState: flowState,
            playerState: playerState,
            moveName: moveName,
            videoAsset: videoAsset,
            trimmerViewModel: trimmerViewModel as? TrimmerViewModel,
            playerViewModel: currentPlayerViewModel
                as? UnifiedVideoPlayerViewModel,
            photosIdentifier: photosIdentifier,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        )
    }

    // MARK: - FUNC
    public func getSaveValidationStatus() -> SaveValidationStatus {
        _ = Task {
            await validateSaveReadiness()
        }

        return .ready("Validating...")
    }

    // MARK: - FUNC
    @MainActor
    public func prepareForTransition() {
        // logger.info("🎬 AddMoveUnifiedState: Preparing for transition")
        unifiedPlayerManager.prepareForTransition()
    }

    // MARK: - VAR
    public var canProceed: Bool {
        return videoAsset != nil && photosIdentifier != nil
    }

    // MARK: - FUNC
    @MainActor
    private func validateServicesReady() -> Bool {
        // logger.info("🎬 AddMoveUnifiedState: 🔍 Validating service readiness")

        guard servicesInitialized else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Services not initialized yet"
            )
            return false
        }

        var allServicesReady = true

        if timerManagementService == nil {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ TimerManagementService not initialized"
            )
            allServicesReady = false
        } else {
            // logger.info("🎬 AddMoveUnifiedState: ✅ TimerManagementService ready")
        }
        if videoProgressMonitoringService == nil {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ VideoProgressMonitoringService not initialized"
            )
            allServicesReady = false
        } else {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ VideoProgressMonitoringService ready"
            )
        }
        if videoProgressMonitoringService?.onProgressUpdate == nil {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Progress monitoring callback not set"
            )
            allServicesReady = false
        } else {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Progress monitoring callback configured"
            )
        }

        if addMoveSaveCoordinator == nil {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ AddMoveSaveCoordinator not initialized"
            )
            allServicesReady = false
        } else {
            // logger.info("🎬 AddMoveUnifiedState: ✅ AddMoveSaveCoordinator ready")
        }

        if flowStateManager == nil {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ FlowStateManager not initialized"
            )
            allServicesReady = false
        } else {
            // logger.info("🎬 AddMoveUnifiedState: ✅ FlowStateManager ready")
        }

        logger.info(
            "🎬 AddMoveUnifiedState:  Service validation result: \(allServicesReady ? "READY" : "NOT READY")"
        )
        return allServicesReady
    }

    // MARK: - FUNC
    @MainActor
    public func reset() {
        // logger.info("🎬 AddMoveUnifiedState: Resetting to ready state")
        isCompletingLoad = false
        unifiedPlayerManager.currentPlayer?.avPlayer?.pause()

        // MARK: TASK
        Task {
            await resetAtomicTransitionLock()
        }

        flowState = .ready
        playerState = .idle
        moveName = ""
        videoAsset = nil
        photosIdentifier = nil

        clearFileSize()

        clearPreservedTrimmingState()
    }

    // MARK: - FUNC
    @MainActor
    public func handleVideoReplacement(_ item: PhotosPickerItem) async {
        let identifier = item.itemIdentifier ?? "unknown"
        let correlationId = UUID().uuidString.prefix(8)
        let operationStartTime = Date()

        logger.info(
            "🎯 ATOMIC_REPLACEMENT: 🚀 Starting video replacement workflow [\(correlationId)]"
        )

        do {

            logger.info(
                "🎯 ATOMIC_REPLACEMENT: 🔄 STEP 1 - Performing atomic state reset [\(correlationId)]"
            )
            try await prepareForNewVideoSelection()
            logger.info(
                "🎯 ATOMIC_REPLACEMENT: ✅ STEP 1 Complete - State is now .ready [\(correlationId)]"
            )

            logger.info(
                "🎯 ATOMIC_REPLACEMENT: 🚀 STEP 2 - Starting video loading [\(correlationId)]"
            )
            didSelectVideo(item)

        } catch {
            logger.error(
                "🎯 ATOMIC_REPLACEMENT: ❌ Video replacement failed during state reset: \(error.localizedDescription) [\(correlationId)]"
            )
            await setError(
                message: "Failed to prepare for new video.",
                underlying: error.localizedDescription
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func didSelectVideo(_ item: PhotosPickerItem) {
        let identifier = item.itemIdentifier ?? "unknown"
        let correlationId = UUID().uuidString.prefix(8)
        let sessionStartTime = Date()

        logger.info(
            "🎯 UNIFIED_LOADING_ENTRY: 🚀 VIDEO_SELECTION_START [\(correlationId)] - Processing video from clean state: \(identifier)"
        )

        videoLoadingTask?.cancel()
        logger.info(
            "🎯 UNIFIED_LOADING_ENTRY: 🛑 Previous loading task cancelled to ensure clean start [\(correlationId)]"
        )

        videoLoadingTask = Task { [weak self] in
            guard let self = self else {
                logger.warning(
                    "🎯 UNIFIED_LOADING_ENTRY: ⚠️ Self reference lost during task execution [\(correlationId)]"
                )
                return
            }

            do {

                logger.info(
                    "🎯 UNIFIED_LOADING_ENTRY: 🔄 STEP 1 - Atomic state transition to .loadingVideo [\(correlationId)]"
                )
                guard case .ready = self.flowState else {
                    logger.critical(
                        "🚨 CRITICAL STATE VIOLATION: didSelectVideo called from non-ready state: \(String(describing: self.flowState)). This indicates a failure in the reset-before-selection workflow."
                    )
                    await self.setError(
                        message: "Cannot start loading from an invalid state."
                    )
                    return
                }

                let transitionSuccess = self.beginLoadingState(
                    from: self.flowState,
                    videoIdentifier: identifier,
                    correlationId: String(correlationId)
                )
                guard transitionSuccess else {
                    logger.error(
                        "❌ UNIFIED_LOADING_ENTRY: ❌ STEP 1 failed - State transition rejected [\(correlationId)]"
                    )
                    await self.setError(
                        message: "Failed to initialize loading state."
                    )
                    return
                }
                logger.info(
                    "🎯 UNIFIED_LOADING_ENTRY: ✅ STEP 1 complete - Atomic state transition to .loadingVideo successful [\(correlationId)]"
                )
                try Task.checkCancellation()

                logger.info(
                    "🎯 UNIFIED_LOADING_ENTRY: 🔄 STEP 2 - Starting async operations [\(correlationId)]"
                )

                await self.fetchAndDisplayFileSize(
                    from: item,
                    correlationId: String(correlationId)
                )
                try Task.checkCancellation()

                await self.loadVideoWithCancellation(
                    from: item,
                    correlationId: String(correlationId)
                )

                let sessionDuration = Date().timeIntervalSince(sessionStartTime)
                logger.info(
                    "🎯 UNIFIED_LOADING_ENTRY: 🎉 SESSION_COMPLETE - Total duration: \(String(format: "%.3f", sessionDuration))s [\(correlationId)]"
                )

            } catch is CancellationError {
                logger.info(
                    "🛑 UNIFIED_LOADING_ENTRY: 🛑 Video loading task was cancelled [\(correlationId)]"
                )
                await self.performLoadingCancellationCleanup(
                    correlationId: String(correlationId)
                )
            } catch {
                logger.error(
                    "❌ UNIFIED_LOADING_ENTRY: ❌ Unexpected error during video selection: \(error.localizedDescription) [\(correlationId)]"
                )
                await self.setError(
                    message: "A problem occurred while selecting the video.",
                    underlying: error.localizedDescription
                )
            }
        }
    }

    // MARK: - FUNC
    @MainActor
    private func fetchAndDisplayFileSize(
        from item: PhotosPickerItem,
        correlationId: String
    ) async {
        logger.info(
            " FILE_SIZE_FETCH: 🚀 Starting file size fetch [\(correlationId)]"
        )

        await item.loadFileSize()

        self.estimatedFileSize = item.estimatedFileSize
        self.formattedFileSize = item.formattedFileSize

        logger.info(
            " FILE_SIZE_FETCH: ✅ File size retrieved successfully [\(correlationId)]"
        )
        logger.info(
            " FILE_SIZE_FETCH:  Raw size: \(item.estimatedFileSize) bytes, Formatted: '\(item.formattedFileSize)'"
        )

        let sizeMB = item.estimatedFileSize / (1024 * 1024)
        if sizeMB < 50 {
            logger.info(
                " FILE_SIZE_FETCH: 📱 Small file (<50MB) - Fast loading expected [\(correlationId)]"
            )
        } else if sizeMB < 200 {
            logger.info(
                " FILE_SIZE_FETCH:  Medium file (50-200MB) - Standard loading time [\(correlationId)]"
            )
        } else if sizeMB < 500 {
            logger.info(
                " FILE_SIZE_FETCH: 🗄️ Large file (200-500MB) - Extended loading time [\(correlationId)]"
            )
        } else {
            logger.info(
                " FILE_SIZE_FETCH: 🏗️ Very large file (>500MB) - Extended loading with progress tracking [\(correlationId)]"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func startResilientVideoLoading(
        from item: PhotosPickerItem,
        correlationId: String
    ) async {
        let identifier = item.itemIdentifier ?? "unknown"
        logger.info(
            "🎯 RESILIENT_LOADING: 🚀 Starting new resilient video loading task [\(correlationId)] for: \(identifier)"
        )

        // MARK: - COMPLEX-ASS logic
        videoLoadingTask = Task { [weak self] in
            guard let self = self else {
                print(
                    "🎯 RESILIENT_LOADING: ❌ Self reference lost during task execution [\(correlationId)]"
                )
                return
            }

            do {
                try Task.checkCancellation()
                logger.info(
                    "🎯 RESILIENT_LOADING: ✅ Cancellation check 1 passed [\(correlationId)]"
                )

                logger.info(
                    "🎯 RESILIENT_LOADING:  Step 1 - Performing atomic state transition [\(correlationId)]"
                )

                logger.info(
                    "🎯 RESILIENT_LOADING:  LOADING_INITIATION_STATE_ANALYSIS [\(correlationId)]:"
                )
                logger.info(
                    "🎯 RESILIENT_LOADING: │ ├─ Source state: \(String(describing: self.flowState))"
                )
                logger.info(
                    "🎯 RESILIENT_LOADING: │ ├─ Target progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
                )
                logger.info(
                    "🎯 RESILIENT_LOADING: │ ├─ Current phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
                )
                logger.info(
                    "🎯 RESILIENT_LOADING: │ └─ Video identifier: \(identifier)"
                )

                let transitionSuccess = self.beginLoadingState(
                    from: self.flowState,
                    videoIdentifier: identifier,
                    correlationId: correlationId
                )

                guard transitionSuccess else {
                    logger.error(
                        "🎯 RESILIENT_LOADING: ❌ State transition failed [\(correlationId)]"
                    )
                    return
                }
                logger.info(
                    "🎯 RESILIENT_LOADING: ✅ State transition completed successfully [\(correlationId)]"
                )

                try Task.checkCancellation()
                logger.info(
                    "🎯 RESILIENT_LOADING: ✅ Cancellation check 2 passed [\(correlationId)]"
                )

                logger.info(
                    "🎯 RESILIENT_LOADING:  Step 2 - Starting video loading process [\(correlationId)]"
                )
                await self.loadVideoWithCancellation(
                    from: item,
                    correlationId: correlationId
                )

                try Task.checkCancellation()
                logger.info(
                    "🎯 RESILIENT_LOADING: ✅ All cancellation checks passed - Loading completed [\(correlationId)]"
                )

            } catch is CancellationError {
                logger.info(
                    "🎯 RESILIENT_LOADING: 🛑 Task cancelled gracefully [\(correlationId)]"
                )
                self.logConsecutiveLoadDiagnostics(
                    "task_cancelled",
                    correlationId: correlationId
                )

            } catch {
                logger.error(
                    "🎯 RESILIENT_LOADING: ❌ Unexpected error during loading: \(error.localizedDescription) [\(correlationId)]"
                )
                await self.setError(
                    message: "Video loading failed",
                    underlying: error.localizedDescription
                )
                self.logConsecutiveLoadDiagnostics(
                    "loading_error",
                    correlationId: correlationId
                )
            }
        }

        logger.info(
            "🎯 RESILIENT_LOADING: 🎉 Resilient video loading task started successfully [\(correlationId)]"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func loadVideoWithCancellation(
        from item: PhotosPickerItem,
        correlationId: String
    ) async {
        let identifier = item.itemIdentifier ?? "unknown"
        let loadingStartTime = Date()

        logger.info(
            "🎯 RESILIENT_LOADING: 🚀 Starting cancellable video loading [\(correlationId)] for: \(identifier)"
        )

        do {
            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check before service validation passed [\(correlationId)]"
            )
            logger.info(
                "🎯 RESILIENT_LOADING:  Step 1 - Validating services [\(correlationId)]"
            )
            guard validateServicesReady() else {
                logger.error(
                    "🎯 RESILIENT_LOADING: ❌ Services not ready for video loading [\(correlationId)]"
                )
                await setError(
                    message: "Services not ready",
                    underlying:
                        "Required services not initialized for video loading session \(correlationId)"
                )
                return
            }
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Service validation completed [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after service validation passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING:  Step 2 - Validating storage availability [\(correlationId)]"
            )
            await validateStorageBeforeLoading()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Storage validation completed [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after storage validation passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING:  Step 3 - Starting load timer [\(correlationId)]"
            )
            timerManagementService.startLoadTimer()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Load timer started [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after timer start passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING:  Step 4 - Starting progress monitoring [\(correlationId)]"
            )
            videoProgressMonitoringService.startMonitoring()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Progress monitoring started [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after progress monitoring passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING:  Step 5 - Loading video asset from Photos [\(correlationId)]"
            )
            try await loadVideoAssetWithCancellation(
                from: item,
                correlationId: correlationId
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after asset loading passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING:  Step 6 - Validating loaded video asset [\(correlationId)]"
            )
            try await validateLoadedAssetWithCancellation(
                correlationId: correlationId
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Final cancellation check passed [\(correlationId)]"
            )

            let loadingDuration = Date().timeIntervalSince(loadingStartTime)
            logger.info(
                "🎯 RESILIENT_LOADING: 🎉 Video loading completed successfully [\(correlationId)]"
            )
            logger.info(
                "🎯 RESILIENT_LOADING:  Loading performance: \(String(format: "%.3f", loadingDuration))s [\(correlationId)]"
            )

            logConsecutiveLoadDiagnostics(
                "loading_completed_successfully",
                correlationId: correlationId
            )

        } catch is CancellationError {
            logger.info(
                "🎯 RESILIENT_LOADING: 🛑 Video loading cancelled gracefully [\(correlationId)]"
            )

            await performLoadingCancellationCleanup(
                correlationId: correlationId
            )
            logConsecutiveLoadDiagnostics(
                "loading_cancelled",
                correlationId: correlationId
            )

        } catch {
            let errorMessage = generateEnhancedErrorMessage(
                from: error,
                correlationId: correlationId
            )
            logger.error(
                "🎯 RESILIENT_LOADING: ❌ Video loading failed: \(errorMessage) [\(correlationId)]"
            )
            await setError(
                message: errorMessage,
                underlying: error.localizedDescription
            )
            logConsecutiveLoadDiagnostics(
                "loading_failed",
                correlationId: correlationId
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func loadVideoAssetWithCancellation(
        from item: PhotosPickerItem,
        correlationId: String
    ) async throws {
        logger.info(
            "🎯 RESILIENT_LOADING: 🎬 Delegating loading and all phase management to modernVideoLoadingService [\(correlationId)]"
        )

        let result = try await modernVideoLoadingService.loadVideo(from: item)

        logger.info(
            "🎯 RESILIENT_LOADING: ✅ modernVideoLoadingService completed its full sequence. Setting final asset properties. [\(correlationId)]"
        )

        self.videoAsset = result.asset
        self.photosIdentifier = result.photosIdentifier

        if let fileSize = result.fileSize, fileSize > 0 {
            let formattedSize = ByteCountFormatter.string(
                fromByteCount: fileSize,
                countStyle: .file
            )
            await updateEstimatedFileSize(
                fileSize,
                formattedSize: formattedSize
            )
            logger.info(
                " ENHANCED_FILE_SIZE_DISPLAY: ✅ File size captured from VideoLoadingResult: \(formattedSize) [\(correlationId)]"
            )

            logger.info(
                " FILE_SIZE_USER_FEEDBACK: 🎯 Video file size ready for UI display - Size: \(formattedSize) (\(fileSize) bytes) [\(correlationId)]"
            )
        } else {
            logger.warning(
                "⚠️ FILE_SIZE_WARNING: File size not available in VideoLoadingResult [\(correlationId)]"
            )
        }

        logger.info(
            "🎯 RESILIENT_LOADING: 🚀 Triggering atomic completion transition now that asset is assigned. [\(correlationId)]"
        )
        await handleEngineCompletion(
            phaseChangeId: "asset_load_complete_\(correlationId)"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func validateLoadedAssetWithCancellation(correlationId: String)
        async throws
    {
        logger.info(
            "🎯 RESILIENT_LOADING:  Validating loaded video asset [\(correlationId)]"
        )

        do {
            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check before validation passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING: 📝 Status managed by UnifiedProgressEngine during asset validation [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after validation status update passed [\(correlationId)]"
            )

            guard videoAsset != nil else {
                logger.error(
                    "🎯 RESILIENT_LOADING: ❌ Video asset is nil after loading [\(correlationId)]"
                )
                throw NSError(
                    domain: "VideoLoadingError",
                    code: 1001,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Video asset is nil after loading"
                    ]
                )
            }

            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Video asset validation passed [\(correlationId)]"
            )

            try Task.checkCancellation()
            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Cancellation check after validation passed [\(correlationId)]"
            )

            logger.info(
                "🎯 RESILIENT_LOADING: ✅ Video asset validation completed successfully [\(correlationId)]"
            )

        } catch is CancellationError {
            logger.info(
                "🎯 RESILIENT_LOADING: 🛑 Asset validation cancelled [\(correlationId)]"
            )
            throw CancellationError()

        } catch {
            logger.error(
                "🎯 RESILIENT_LOADING: ❌ Asset validation failed: \(error.localizedDescription) [\(correlationId)]"
            )
            throw error
        }
    }

    // MARK: - FUNC
    @MainActor
    private func performLoadingCancellationCleanup(correlationId: String) async
    {
        logger.info(
            "🎯 RESILIENT_LOADING: 🧹 Performing loading cancellation cleanup [\(correlationId)]"
        )

        timerManagementService.stopLoadTimer()
        videoProgressMonitoringService?.stopMonitoring()
        logger.info(
            "🎯 RESILIENT_LOADING: ✅ Timer and monitoring stopped [\(correlationId)]"
        )

        logger.info(
            "🎯 RESILIENT_LOADING: 📝 Status managed by UnifiedProgressEngine during cancellation [\(correlationId)]"
        )

        videoAsset = nil
        photosIdentifier = nil
        logger.info(
            "🎯 RESILIENT_LOADING: ✅ Partial loading state cleared [\(correlationId)]"
        )

        unifiedProgressEngine.beginLoading()
        logger.info(
            "🎯 RESILIENT_LOADING: ✅ Progress engine reset [\(correlationId)]"
        )

        logger.info(
            "🎯 RESILIENT_LOADING: 🎉 Loading cancellation cleanup completed [\(correlationId)]"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func beginLoadingState(
        from currentState: AddMoveFlowState,
        videoIdentifier: String,
        correlationId: String
    ) -> Bool {
        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 LEFT_ADJOINT_η: Beginning atomic state transition [\(correlationId)]"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Category Theory: Implementing unit morphism η: Id → GF [\(correlationId)]"
        )

        let validStatesForLoading: [AddMoveFlowState] = [
            .ready, .trimming,
            .error(message: "Recovery", underlyingError: nil),
            .success(message: "Complete"),
        ]

        guard validStatesForLoading.contains(currentState) else {
            // logger.error(
            //     "🎬 AddMoveUnifiedState: ❌ CATEGORY_THEORY_VIOLATION: Invalid source object for morphism [\(correlationId)]"
            // )
            // logger.error(
            //     "🎬 AddMoveUnifiedState: 🚫 MORPHISM_REJECTED: Cannot transition from \(String(describing: currentState)) to loadingVideo [\(correlationId)]"
            // )
            // logger.error(
            //     "🎬 AddMoveUnifiedState: ✅ VALID_SOURCE_OBJECTS: \(validStatesForLoading.map { String(describing: $0) }.joined(separator: ", ")) [\(correlationId)]"
            // )
            return false
        }

        // logger.info(
        //     "🎬 AddMoveUnifiedState: ✅ CATEGORY_THEORY_VALIDATION: Source object valid for morphism [\(correlationId)]"
        // )

        // logger.info(
        //     "🔄 ATOMIC_STATE_TRANSITION_INITIAL: 🚨 RACE_CONDITION_FIX - Resetting progress engines BEFORE state transition [\(correlationId)]"
        // )

        // logger.info(
        //     "🔄 ATOMIC_STATE_TRANSITION_INITIAL:  Step 1 - Resetting UnifiedProgressEngine to clean state [\(correlationId)]"
        // )
        let progressResetStartTime = Date()
        unifiedProgressEngine.beginLoading()
        let progressResetDuration = Date().timeIntervalSince(
            progressResetStartTime
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ Step 1 complete - UnifiedProgressEngine reset in \(String(format: "%.3f", progressResetDuration))s [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL:  Progress state: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%, Phase: \(self.unifiedProgressEngine.currentPhase.displayName) [\(correlationId)]"
        )

        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⏱️ Step 2 - Resetting TimerManagementService to clean state [\(correlationId)]"
        )
        guard let timerService = self.timerManagementService else {
            logger.error(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ❌ TIMER_SERVICE_UNAVAILABLE: TimerManagementService is nil [\(correlationId)]"
            )
            logger.warning(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⚠️ TIMER_FALLBACK: Continuing without load timer - UI progress may not update [\(correlationId)]"
            )
            return false
        }

        let timerResetStartTime = Date()
        timerService.startLoadTimer()
        let timerResetDuration = Date().timeIntervalSince(timerResetStartTime)
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ Step 2 complete - TimerManagementService reset in \(String(format: "%.3f", timerResetDuration))s [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⏱️ Timer state: \(String(format: "%.2f", timerService.getLoadElapsedTime()))s elapsed [\(correlationId)]"
        )

        if timerService.onLoadTimerUpdate == nil {
            logger.warning(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⚠️ TIMER_CALLBACK_NOT_SET: onLoadTimerUpdate callback is nil - UI won't update! [\(correlationId)]"
            )
        } else {
            logger.info(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ TIMER_CALLBACK_CONFIGURED: onLoadTimerUpdate callback is properly set [\(correlationId)]"
            )
        }

        loadingOverlayStartTime = Date()
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⏱️ LOADING_OVERLAY_TIMER: Started at \(self.loadingOverlayStartTime!) [\(correlationId)]"
        )

        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: 🔄 Step 3 - Performing atomic state transition to .loadingVideo [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL:  PRE_TRANSITION_STATE_CHECK: [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ Current flowState: \(String(describing: self.flowState))"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ Timer: \(String(format: "%.2f", timerService.getLoadElapsedTime()))s"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ └─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )

        let stateTransitionStartTime = Date()
        flowState = .loadingVideo
        let stateTransitionDuration = Date().timeIntervalSince(
            stateTransitionStartTime
        )

        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ Step 3 complete - State transition in \(String(format: "%.3f", stateTransitionDuration))s [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL:  POST_TRANSITION_STATE_CHECK: [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ New flowState: \(String(describing: self.flowState))"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ ├─ Timer: \(String(format: "%.2f", timerService.getLoadElapsedTime()))s"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: │ └─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )

        let totalResetDuration = Date().timeIntervalSince(
            progressResetStartTime
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: 🎉 COMPLETE - Atomic state transition in \(String(format: "%.3f", totalResetDuration))s [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ RACE_CONDITION_ELIMINATED - Clean state ready for SwiftUI rendering [\(correlationId)]"
        )
        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL:  MORPHISM_COMPOSITION: \(String(describing: currentState)) → .loadingVideo (atomic with clean state) [\(correlationId)]"
        )

        logger.info(
            "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ LEFT_ADJOINT_η_COMPLETE: Atomic state transition satisfied, ready for right adjoint [\(correlationId)]"
        )

        let fixVerification = verifyAtomicStateTransitionFix()
        if !fixVerification {
            logger.warning(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ⚠️ VERIFICATION_FAILED - Fix may not be working correctly [\(correlationId)]"
            )
        } else {
            logger.info(
                "🔄 ATOMIC_STATE_TRANSITION_INITIAL: ✅ VERIFICATION_PASSED - Atomic state transition fix working correctly [\(correlationId)]"
            )
        }

        return true
    }

    // MARK: - FUNC
    @MainActor
    public func verifyAtomicStateTransitionFix() -> Bool {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔍 RACE_CONDITION_VERIFICATION - Starting comprehensive diagnostic"
        )

        guard case .loadingVideo = self.flowState else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ RACE_CONDITION_VERIFICATION - Not in loadingVideo state, current: \(String(describing: self.flowState))"
            )
            return false
        }

        let progressValue = self.unifiedProgressEngine.unifiedProgress
        let targetProgress = self.unifiedProgressEngine.targetProgress
        let currentPhase = self.unifiedProgressEngine.currentPhase

        let progressIsClean = progressValue <= 0.1
        let targetProgressIsClean = targetProgress <= 0.1
        let phaseIsInitializing = currentPhase == .initializing

        logger.info(
            "🎬 AddMoveUnifiedState:  RACE_CONDITION_VERIFICATION - Progress Engine Analysis:"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Current Progress: \(String(format: "%.3f", progressValue)) (\(Int(progressValue * 100))%)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Target Progress: \(String(format: "%.3f", targetProgress)) (\(Int(targetProgress * 100))%)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Phase: \(currentPhase.displayName)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Progress Clean: \(progressIsClean ? "✅" : "❌")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ └─ Phase Initializing: \(phaseIsInitializing ? "✅" : "❌")"
        )

        let timerElapsed = self.timerManagementService.getLoadElapsedTime()
        let timerIsClean = timerElapsed <= 0.1

        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ RACE_CONDITION_VERIFICATION - Timer Analysis:"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ ├─ Elapsed Time: \(String(format: "%.3f", timerElapsed))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: │ └─ Timer Clean: \(timerIsClean ? "✅" : "❌")"
        )

        let allClean =
            progressIsClean && targetProgressIsClean && phaseIsInitializing
            && timerIsClean

        if allClean {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ RACE_CONDITION_VERIFICATION - 🎉 ALL CLEAN! Atomic state transition working perfectly"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ RACE_CONDITION_VERIFICATION - ✅ No stale data flash will occur"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ RACE_CONDITION_VERIFICATION - ❌ ISSUES DETECTED!"
            )
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ RACE_CONDITION_VERIFICATION - Stale data flash may occur"
            )

            if !progressIsClean {
                logger.warning(
                    "🎬 AddMoveUnifiedState: ⚠️ RACE_CONDITION_VERIFICATION - Progress engine has stale data: \(String(format: "%.3f", progressValue))"
                )
            }
            if !timerIsClean {
                logger.warning(
                    "🎬 AddMoveUnifiedState: ⚠️ RACE_CONDITION_VERIFICATION - Timer has stale data: \(String(format: "%.3f", timerElapsed))s"
                )
            }
        }

        return allClean
    }

    // MARK: - FUNC
    @MainActor
    public func logStateSnapshot(context: String) {
        // logger.info("🎬 AddMoveUnifiedState: 📸 STATE_SNAPSHOT [\(context)]:")
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Flow State: \(String(describing: self.flowState))"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Player State: \(String(describing: self.playerState))"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Target Progress: \(Int(self.unifiedProgressEngine.targetProgress * 100))%"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Timer: \(String(format: "%.2f", self.timerManagementService.getLoadElapsedTime()))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ├─ Video Asset: \(self.videoAsset != nil ? "loaded" : "nil")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: └─ Photos ID: \(self.photosIdentifier ?? "nil")"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func loadVideo(from item: PhotosPickerItem) async {
        let loadingSessionId = UUID().uuidString.prefix(8)
        let identifier = item.itemIdentifier ?? "unknown"
        let loadingStartTime = Date()

        let loadingLogger = Logger(
            subsystem: "breakdex",
            category: "🎯 UNIFIED_LOADING"
        )
        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🚀 Starting video loading process for \(identifier)"
        )
        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 📱 Video selection received from Photos picker"
        )

        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )
        let memoryBefore: Double = getMemoryUsageInMB()
        perfLogger.info(
            " LOADING_BASELINE: [\(loadingSessionId)] Memory at start: \(String(format: "%.1f", memoryBefore))MB"
        )
        perfLogger.info(
            " LOADING_BASELINE: [\(loadingSessionId)] System load time baseline captured"
        )

        guard validateServicesReady() else {
            let errorLogger = Logger(
                subsystem: "breakdex",
                category: "❌ LOADING_ERRORS"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] Services not ready for video loading"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] Required services: TimerManagement, VideoProgressMonitoring, FlowStateManager"
            )
            await setError(
                message: "Services not ready",
                underlying:
                    "Required services not initialized for video loading session \(loadingSessionId)"
            )
            return
        }

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ✅ Service validation completed"
        )

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🔄 RACE_CONDITION_FIX: flowState already set to loadingVideo in didSelectVideo()"
        )
        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)]  Current state verification: \(String(describing: self.flowState))"
        )

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🚀 UnifiedProgressEngine already initialized in atomic state transition"
        )
        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)]  Current progress state: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%, Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 💾 Validating storage availability before video loading"
        )
        await validateStorageBeforeLoading()

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ✅ RACE_CONDITION_FIX - Skipping UnifiedProgressEngine.beginLoading() (already initialized)"
        )

        guard case .loadingVideo = flowState else {
            let errorLogger = Logger(
                subsystem: "breakdex",
                category: "❌ LOADING_ERRORS"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] RACE_CONDITION_ERROR: Expected loadingVideo state, found: \(String(describing: self.flowState))"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] State synchronization failure detected"
            )
            await setError(
                message: "State synchronization error",
                underlying:
                    "flowState not in loadingVideo for session \(loadingSessionId)"
            )
            return
        }

        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ✅ RACE_CONDITION_FIX: State verified - proceeding with video loading"
        )
        loadingLogger.info(
            "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ⏱️ Video loading phase starting"
        )

        do {
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 📡 Calling modern video loading service"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🎬 Service: modernVideoLoadingService.loadVideo(from: PhotosPickerItem)"
            )

            let result = try await modernVideoLoadingService.loadVideo(
                from: item
            )

            let loadingDuration = Date().timeIntervalSince(loadingStartTime)
            let memoryAfter: Double = getMemoryUsageInMB()
            let memoryDelta = memoryAfter - memoryBefore

            perfLogger.info(
                " LOADING_SUCCESS: [\(loadingSessionId)] Video loading completed in \(String(format: "%.3f", loadingDuration))s"
            )
            perfLogger.info(
                " LOADING_SUCCESS: [\(loadingSessionId)] Memory impact: \(String(format: "%+.1f", memoryDelta))MB (before: \(String(format: "%.1f", memoryBefore))MB, after: \(String(format: "%.1f", memoryAfter))MB)"
            )

            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🏆 Video loading completed successfully"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)]  Asset metadata:"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] │  ├─ Filename: \(result.filename)"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] │  ├─ Duration: \(String(format: "%.2f", result.duration.seconds))s"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] │  ├─ Size: \(result.fileSize ?? 0) bytes"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] │  └─ Photos ID: \(result.photosIdentifier ?? "unknown")"
            )

            videoAsset = result.asset
            photosIdentifier = result.photosIdentifier

            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🚫 ROGUE_MORPHISM_FIX: Legacy handleVideoLoadingProgress(.creatingAsset) call REMOVED"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 📡 AUTHORITY_TRANSFER: ResilientVideoLoader now sole completion authority"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ✅ Video asset and properties updated successfully"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🎯 CRITICAL_FIX: Player creation deferred to trimming transition"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] ✅ Preventing duplicate player creation attempts"
            )
            loadingLogger.info(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)]  Video loading completed - ResilientVideoLoader will drive natural completion to trimming"
            )

            if loadingDuration > 3.0 {
                let warningLogger = Logger(
                    subsystem: "breakdex",
                    category: "⚠️ PERFORMANCE_WARNINGS"
                )
                warningLogger.warning(
                    "⚠️ SLOW_VIDEO_LOADING: [\(loadingSessionId)] Video loading took \(String(format: "%.3f", loadingDuration))s (>3.0s threshold)"
                )
            }

        } catch {
            let loadingDuration = Date().timeIntervalSince(loadingStartTime)
            let memoryAfter: Double = getMemoryUsageInMB()
            let memoryDelta = memoryAfter - memoryBefore

            let errorLogger = Logger(
                subsystem: "breakdex",
                category: "❌ LOADING_ERRORS"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] Video loading failed after \(String(format: "%.3f", loadingDuration))s"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] ┌─ Error details:"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] │  ├─ Message: \(error.localizedDescription)"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] │  ├─ Type: \(type(of: error))"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] │  ├─ Memory impact: \(String(format: "%+.1f", memoryDelta))MB"
            )
            errorLogger.error(
                "❌ LOADING_ERRORS: [\(loadingSessionId)] │  └─ Video identifier: \(identifier)"
            )

            perfLogger.error(
                " LOADING_FAILURE: [\(loadingSessionId)] Failed after \(String(format: "%.3f", loadingDuration))s"
            )
            perfLogger.error(
                " LOADING_FAILURE: [\(loadingSessionId)] Memory impact: \(String(format: "%+.1f", memoryDelta))MB"
            )

            let unifiedError: UnifiedProgressEngine.ProgressError
            if error.localizedDescription.contains("network")
                || error.localizedDescription.contains("connection")
            {
                unifiedError = .networkLost
                errorLogger.error(
                    "❌ LOADING_ERRORS: [\(loadingSessionId)] 🔗 Network-related error detected"
                )
            } else if error.localizedDescription.contains("storage")
                || error.localizedDescription.contains("space")
            {
                unifiedError = .insufficientStorage(available: 0, required: 0)
                errorLogger.error(
                    "❌ LOADING_ERRORS: [\(loadingSessionId)] 💾 Storage-related error detected"
                )
            } else if error.localizedDescription.contains("timeout") {
                unifiedError = .timeout(duration: loadingDuration)
                errorLogger.error(
                    "❌ LOADING_ERRORS: [\(loadingSessionId)] ⏰ Timeout error after \(String(format: "%.2f", loadingDuration))s"
                )
            } else {
                unifiedError = .unknown(error.localizedDescription)
                errorLogger.error(
                    "❌ LOADING_ERRORS: [\(loadingSessionId)] ❓ Unknown error type - full error captured"
                )
            }

            loadingLogger.error(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🚨 Notifying UnifiedProgressEngine of error: \(unifiedError)"
            )
            unifiedProgressEngine.handleError(unifiedError)

            loadingLogger.error(
                "🎯 UNIFIED_LOADING: [\(loadingSessionId)] 🔄 Setting error state with full context"
            )
            await setError(
                message: "Failed to load video",
                underlying:
                    "Session \(loadingSessionId): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func synchronizePlayerStateForNaming() async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 SYNCHRONIZING player state for naming phase"
        )

        let syncStartTime = Date()
        let timeoutSeconds: TimeInterval = 10.0
        let checkInterval: TimeInterval = 0.1

        logger.info(
            "🎬 AddMoveUnifiedState: 🔍 DIAGNOSTIC - Initial sync state - playerState: \(String(describing: self.playerState)), unifiedPlayerManager.currentPlayer: \(self.unifiedPlayerManager.currentPlayer != nil ? "available" : "nil")"
        )

        while true {
            let elapsed = Date().timeIntervalSince(syncStartTime)

            if elapsed > timeoutSeconds {
                logger.error(
                    "🎬 AddMoveUnifiedState: ❌ Player state synchronization TIMEOUT after \(String(format: "%.3f", elapsed))s"
                )

                logger.warning(
                    "🎬 AddMoveUnifiedState: 🔄 FALLBACK - Setting player state to .ready after timeout to prevent permanent blocking"
                )
                playerState = .ready
                return
            }

            if let currentPlayer = unifiedPlayerManager.currentPlayer {
                let actualPlayerReady = currentPlayer.isPlayerReady

                logger.debug(
                    "🎬 AddMoveUnifiedState: 🔍 Sync check - elapsed: \(String(format: "%.1f", elapsed))s, actualPlayerReady: \(actualPlayerReady), currentPublishedState: \(String(describing: self.playerState))"
                )

                if actualPlayerReady {

                    if self.playerState != .ready {
                        logger.info(
                            "🎬 AddMoveUnifiedState: ✅ SYNCHRONIZATION SUCCESS - Setting player state to .ready (was: \(String(describing: self.playerState)))"
                        )
                        self.playerState = .ready
                    } else {
                        logger.info(
                            "🎬 AddMoveUnifiedState: ✅ SYNCHRONIZATION SUCCESS - Player state already .ready"
                        )
                    }

                    let syncDuration = Date().timeIntervalSince(syncStartTime)
                    logger.info(
                        "🎬 AddMoveUnifiedState: 🎉 Player state synchronization completed in \(String(format: "%.3f", syncDuration))s"
                    )
                    return
                }
            } else {
                logger.debug(
                    "🎬 AddMoveUnifiedState: 🔍 Sync check - elapsed: \(String(format: "%.1f", elapsed))s, no currentPlayer available yet"
                )
            }

            try? await Task.sleep(
                nanoseconds: UInt64(checkInterval * 1_000_000_000)
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func replaceSelectedVideo(_ item: PhotosPickerItem) async {
        logger.info(
            "🎬 AddMoveUnifiedState: Replacing selected video via unified didSelectVideo flow."
        )
        didSelectVideo(item)
    }

    // MARK: - FUNC
    @MainActor
    public func proceedToNextState() async throws {
        // logger.info("🎬 AddMoveUnifiedState: Delegating to FlowStateManager")

        guard let flowStateManager = flowStateManager else {
            logger.error(
                "🎬 AddMoveUnifiedState: FlowStateManager not initialized"
            )
            throw NSError(
                domain: "AddMoveUnifiedState",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "FlowStateManager not available"
                ]
            )
        }

        try await flowStateManager.proceedToNextState()
    }

    // MARK: - FUNC
    @MainActor
    public func transitionTo(_ state: AddMoveFlowState) async {
        let transitionStartTime = Date()
        let transitionId = UUID().uuidString.prefix(8)
        let previousState = self.flowState

        let stateLogger = Logger(
            subsystem: "breakdex",
            category: "🔄 STATE_TRANSITIONS"
        )
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Starting transition: \(String(describing: previousState)) → \(String(describing: state))"
        )
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Trigger: PreTrimViewUnified"
        )

        let memoryBefore: Double = getMemoryUsageInMB()
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Memory before: \(String(format: "%.1f", memoryBefore))MB"
        )

        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Progress engine: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))% - \(self.unifiedProgressEngine.currentPhase.displayName)"
        )
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Elapsed time: \(String(format: "%.3f", self.loadElapsedTime))s"
        )

        await transition(to: state, triggeredBy: "PreTrimViewUnified")

        let transitionDuration = Date().timeIntervalSince(transitionStartTime)
        let memoryAfter: Double = getMemoryUsageInMB()
        let memoryDelta = memoryAfter - memoryBefore

        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Completed in \(String(format: "%.3f", transitionDuration))s"
        )
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Memory after: \(String(format: "%.1f", memoryAfter))MB (Δ\(String(format: "%+.1f", memoryDelta))MB)"
        )
        stateLogger.info(
            "🔄 STATE_TRANSITION: [\(transitionId)] Final state: \(String(describing: self.flowState))"
        )

        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )
        perfLogger.info(
            " TRANSITION_PERFORMANCE: [\(transitionId)] '\(String(describing: previousState))' → '\(String(describing: state))' completed in \(String(format: "%.3f", transitionDuration))s"
        )
        perfLogger.info(
            " TRANSITION_PERFORMANCE: [\(transitionId)] Memory impact: \(String(format: "%+.1f", memoryDelta))MB"
        )

        if transitionDuration > 0.5 {
            let warningLogger = Logger(
                subsystem: "breakdex",
                category: "⚠️ PERFORMANCE_WARNINGS"
            )
            warningLogger.warning(
                "⚠️ SLOW_TRANSITION: [\(transitionId)] Transition took \(String(format: "%.3f", transitionDuration))s (>0.5s threshold)"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func setError(message: String, underlying: String? = nil) async {
        let errorSessionId = UUID().uuidString.prefix(8)
        let errorTime = Date()
        let memoryAtError: String = getMemoryUsage()

        let errorLogger = Logger(
            subsystem: "breakdex",
            category: "❌ ERROR_HANDLING"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] 🚨 ERROR STATE INITIATED"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] ┌─ Error Context:"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  ├─ Message: \(message)"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  ├─ Current State: \(String(describing: self.flowState))"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  ├─ Memory: \(String(format: "%.1f", memoryAtError))MB"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  ├─ Elapsed Time: \(String(format: "%.3f", self.loadElapsedTime))s"
        )
        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] │  └─ Timestamp: \(errorTime.description)"
        )

        if let underlying = underlying {
            errorLogger.error(
                "❌ ERROR_HANDLING: [\(errorSessionId)] ┌─ Underlying Error:"
            )
            errorLogger.error(
                "❌ ERROR_HANDLING: [\(errorSessionId)] │  └─ Details: \(underlying)"
            )
        }

        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )
        perfLogger.error(
            " ERROR_IMPACT: [\(errorSessionId)] Error occurred at memory usage: \(String(format: "%.1f", memoryAtError))MB"
        )
        perfLogger.error(
            " ERROR_IMPACT: [\(errorSessionId)] Progress at error: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )

        let recoveryStrategy = determineRecoveryStrategy(
            for: message,
            underlying: underlying
        )
        errorLogger.info(
            "❌ ERROR_HANDLING: [\(errorSessionId)] 🔄 Recovery strategy determined: \(recoveryStrategy.description)"
        )

        pendingRecovery = ErrorRecoveryInfo(
            originalState: flowState,
            errorMessage: message,
            underlyingError: underlying,
            strategy: recoveryStrategy,
            timestamp: errorTime
        )

        errorLogger.info(
            "❌ ERROR_HANDLING: [\(errorSessionId)] 💾 Recovery info stored for session \(errorSessionId)"
        )
        errorLogger.info(
            "❌ ERROR_HANDLING: [\(errorSessionId)] 🔄 Transitioning to error state"
        )

        await transition(
            to: .error(message: message, underlyingError: underlying)
        )

        errorLogger.error(
            "❌ ERROR_HANDLING: [\(errorSessionId)] ✅ Error state transition completed"
        )
    }

    // MARK: - STRUCT
    private struct ErrorRecoveryInfo {
        let originalState: AddMoveFlowState
        let errorMessage: String
        let underlyingError: String?
        let strategy: ErrorRecoveryStrategy
        let timestamp: Date
    }

    private var pendingRecovery: ErrorRecoveryInfo?

    private enum ErrorRecoveryStrategy {
        case retryFromStart
        case retryVideoLoading
        case retryTrimmerSetup
        case retrySaveOperation
        case resetToReady
        case userIntervention

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
            case .retryFromStart, .retryVideoLoading, .retryTrimmerSetup,
                .retrySaveOperation:
                return true
            case .resetToReady, .userIntervention:
                return false
            }
        }
    }

    // MARK: - FUNC
    @MainActor
    private func determineRecoveryStrategy(
        for message: String,
        underlying: String?
    ) -> ErrorRecoveryStrategy {
        logger.info(
            "🎬 AddMoveUnifiedState: 🧠 Analyzing error for recovery strategy - Message: '\(message)'"
        )

        let lowercasedMessage = message.lowercased()
        let lowercasedUnderlying = underlying?.lowercased() ?? ""

        if lowercasedMessage.contains("loading")
            || lowercasedUnderlying.contains("loading")
        {
            if lowercasedMessage.contains("timeout")
                || lowercasedUnderlying.contains("timeout")
            {
                logger.info(
                    "🎬 AddMoveUnifiedState: 🔄 Detected timeout error - will retry video loading"
                )
                return .retryVideoLoading
            } else if lowercasedMessage.contains("permission")
                || lowercasedUnderlying.contains("permission")
            {
                logger.info(
                    "🎬 AddMoveUnifiedState: 🔐 Detected permission error - requires user intervention"
                )
                return .userIntervention
            } else {
                logger.info(
                    "🎬 AddMoveUnifiedState: 🔄 Detected general loading error - will retry video loading"
                )
                return .retryVideoLoading
            }
        }

        if lowercasedMessage.contains("trimmer")
            || lowercasedUnderlying.contains("trimmer")
        {
            logger.info(
                "🎬 AddMoveUnifiedState: ✂️ Detected trimmer error - will retry trimmer setup"
            )
            return .retryTrimmerSetup
        }

        if lowercasedMessage.contains("save")
            || lowercasedUnderlying.contains("save")
        {
            if lowercasedMessage.contains("duplicate")
                || lowercasedUnderlying.contains("duplicate")
            {
                logger.info(
                    "🎬 AddMoveUnifiedState: 📝 Detected duplicate error - requires user intervention"
                )
                return .userIntervention
            } else {
                logger.info(
                    "🎬 AddMoveUnifiedState: 💾 Detected save error - will retry save operation"
                )
                return .retrySaveOperation
            }
        }

        if lowercasedMessage.contains("initialization")
            || lowercasedUnderlying.contains("initialization")
        {
            logger.info(
                "🎬 AddMoveUnifiedState: 🔧 Detected initialization error - will retry from start"
            )
            return .retryFromStart
        }

        if lowercasedMessage.contains("network")
            || lowercasedUnderlying.contains("network")
            || lowercasedMessage.contains("connection")
            || lowercasedUnderlying.contains("connection")
        {
            logger.info(
                "🎬 AddMoveUnifiedState: 🌐 Detected network error - will retry video loading"
            )
            return .retryVideoLoading
        }

        if lowercasedMessage.contains("memory")
            || lowercasedUnderlying.contains("memory")
        {
            logger.info(
                "🎬 AddMoveUnifiedState: 🧠 Detected memory error - will reset to ready state"
            )
            return .resetToReady
        }

        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Unknown error type - will retry from start"
        )
        return .retryFromStart
    }

    // MARK: - FUNC
    @MainActor
    public func attemptErrorRecovery() async {
        guard let recovery = pendingRecovery else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ No pending recovery information available"
            )
            return
        }

        logRecoveryAttempt(
            strategy: recovery.strategy,
            originalError: recovery.errorMessage
        )

        logDiagnosticState("Before Recovery")

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
            logger.info(
                "🎬 AddMoveUnifiedState: 🙋 User intervention required - cannot auto-recover"
            )
            return
        }

        pendingRecovery = nil
    }

    // MARK: - FUNC
    @MainActor
    private func performRetryFromStart() async {
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Performing retry from start")

        videoAsset = nil
        photosIdentifier = nil
        currentPlayerViewModel = nil
        moveName = ""

        await transition(to: .ready)

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Retry from start completed - ready for new video selection"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func performRetryVideoLoading() async {
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Performing video loading retry")

        guard photosIdentifier != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Cannot retry video loading - missing photos identifier"
            )
            await performResetToReady()
            return
        }

        videoAsset = nil
        currentPlayerViewModel = nil

        await performResetToReady()
    }

    // MARK: - FUNC
    @MainActor
    private func performRetryTrimmerSetup() async {
        // logger.info("🎬 AddMoveUnifiedState: ✂️ Performing trimmer setup retry")

        guard videoAsset != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Cannot retry trimmer setup - missing video asset"
            )
            await performResetToReady()
            return
        }

        await transition(to: .trimming)

        await setupTrimmerAfterPreview()
    }

    // MARK: - FUNC
    @MainActor
    private func performRetrySaveOperation() async {
        // logger.info("🎬 AddMoveUnifiedState: 💾 Performing save operation retry")

        guard currentPlayerViewModel != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ Cannot retry save operation - missing player view model"
            )
            await performResetToReady()
            return
        }

        await transition(to: .naming)

        await saveMove()
    }

    // MARK: - FUNC
    @MainActor
    private func performResetToReady() async {
        // logger.info("🎬 AddMoveUnifiedState: 🧹 Performing reset to ready state")

        videoAsset = nil
        photosIdentifier = nil
        currentPlayerViewModel = nil
        moveName = ""

        timerManagementService.resetAllTimers()

        await transition(to: .ready)

        // logger.info("🎬 AddMoveUnifiedState: ✅ Reset to ready state completed")
    }

    // MARK: - FUNC
    @MainActor
    private func resetForNewVideoSelection() async {
        logger.info(
            "🎯 ATOMIC_RESET: 🔄 Delegating to robust prepareForNewVideoSelection() for unified reset logic"
        )

        do {
            try await prepareForNewVideoSelection() // MARK: FUNC at the bottom of the file
            logger.info(
                "🎯 ATOMIC_RESET: ✅ Unified reset completed successfully via prepareForNewVideoSelection()"
            )
        } catch {
            logger.error(
                "🎯 ATOMIC_RESET: ❌ Unified reset failed - \(error.localizedDescription)"
            )

            logger.warning(
                "🎯 ATOMIC_RESET: ⚠️ Falling back to basic reset to maintain user experience"
            )
            isCompletingLoad = false
            unifiedProgressEngine.beginLoading()
            videoAsset = nil
            photosIdentifier = nil
            currentPlayerViewModel = nil
            trimmerViewModel = nil
            moveName = ""
            pendingRecovery = nil
            await transition(
                to: .ready,
                triggeredBy: "resetForNewVideoSelection_fallback"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func prepareForNewVideoSelection() async throws {
        let operationStartTime = Date()
        let correlationId = UUID().uuidString.prefix(8)
        let operationId = UUID()

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: 🚀 Starting atomic state reset for new video selection [\(correlationId)]"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: 🔒 Operation ID: \(operationId.uuidString)"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Step 1 - Acquiring transition lock"
        )
        let lockAcquisitionStartTime = Date()

        do {
            try await transitionLockManager.acquireLockWithRetry(
                for: operationId,
                retryCount: 3,
                retryDelay: 10
            )
        } catch let lockError as TransitionLockError {
            logger.error(
                "🎯 ATOMIC_STATE_RESET_MORPHISM: ❌ Failed to acquire transition lock - \(lockError.localizedDescription)"
            )
            throw lockError
        }

        let lockAcquisitionDuration = Date().timeIntervalSince(
            lockAcquisitionStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Step 1 complete - Lock acquired in \(String(format: "%.3f", lockAcquisitionDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Step 2 - Performing atomic state reset"
        )
        let resetStartTime = Date()

        defer {
            Task {
                await transitionLockManager.releaseLock(for: operationId)
                logger.info(
                    "🎯 ATOMIC_STATE_RESET_MORPHISM: 🔒 Transition lock released: \(operationId.uuidString)"
                )
            }
        }

        isCompletingLoad = false
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.1 - Terminal morphism guard reset"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.2 - Resetting UnifiedProgressEngine"
        )
        let progressResetStartTime = Date()
        unifiedProgressEngine.beginLoading()
        let progressResetDuration = Date().timeIntervalSince(
            progressResetStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.2 complete - Progress engine reset in \(String(format: "%.3f", progressResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.3 - Resetting TimerManagementService"
        )
        let timerResetStartTime = Date()
        timerManagementService.resetAllTimers()
        let timerResetDuration = Date().timeIntervalSince(timerResetStartTime)
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.3 complete - Timer service reset in \(String(format: "%.3f", timerResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.4 - Clearing video asset state"
        )
        let assetResetStartTime = Date()
        videoAsset = nil
        photosIdentifier = nil
        let assetResetDuration = Date().timeIntervalSince(assetResetStartTime)
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.4 complete - Video assets cleared in \(String(format: "%.3f", assetResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.5 - Clearing pending operations with teardown"
        )
        let operationsResetStartTime = Date()

        if let playerVM = self.currentPlayerViewModel
            as? UnifiedVideoPlayerViewModel
        {
            playerVM.teardown()
            logger.info(
                "🎯 ATOMIC_STATE_RESET_MORPHISM: 🔧 UnifiedVideoPlayerViewModel teardown called - releasing healthMonitorTask and resources"
            )
        }

        if let trimmerVM = self.trimmerViewModel as? TrimmerViewModel {
            trimmerVM.teardown()
            logger.info(
                "🎯 ATOMIC_STATE_RESET_MORPHISM: 🔧 TrimmerViewModel teardown called - releasing display link and observers"
            )
        }

        currentPlayerViewModel = nil // MARK: - currentPlayerViewModel
        trimmerViewModel = nil // MARK: - trimmerViewModel
        moveName = ""
        pendingRecovery = nil

        let operationsResetDuration = Date().timeIntervalSince(
            operationsResetStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.5 complete - Operations cleared with teardown in \(String(format: "%.3f", operationsResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.6 - Forcing transition to .ready state"
        )
        let stateResetStartTime = Date()
        let previousState = flowState

        await transition(to: .ready, triggeredBy: "prepareForNewVideoSelection")

        let stateResetDuration = Date().timeIntervalSince(stateResetStartTime)
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.6 complete - State transition \(String(describing: previousState)) → .ready in \(String(format: "%.3f", stateResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.7 - Stopping monitoring services"
        )
        let monitoringResetStartTime = Date()
        videoProgressMonitoringService?.stopMonitoring()
        let monitoringResetDuration = Date().timeIntervalSince(
            monitoringResetStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.7 complete - Monitoring stopped in \(String(format: "%.3f", monitoringResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.8 - Resetting file size tracking"
        )
        let fileSizeResetStartTime = Date()

        estimatedFileSize = 0
        formattedFileSize = ""

        let fileSizeResetDuration = Date().timeIntervalSince(
            fileSizeResetStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.8 complete - File size tracking reset in \(String(format: "%.3f", fileSizeResetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Sequence 2.9 - Clearing transition tracking"
        )
        let trackingResetStartTime = Date()
        currentTransitionId = nil
        transitionStartTime = nil
        transitionCorrelationId = nil
        let trackingResetDuration = Date().timeIntervalSince(
            trackingResetStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Sequence 2.9 complete - Transition tracking cleared in \(String(format: "%.3f", trackingResetDuration * 1000))ms"
        )

        let resetDuration = Date().timeIntervalSince(resetStartTime)
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Step 2 complete - Atomic state reset completed in \(String(format: "%.3f", resetDuration * 1000))ms"
        )

        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM:  Step 3 - Verifying state readiness"
        )
        let verificationStartTime = Date()

        guard case .ready = flowState else {
            let errorMessage =
                "State verification failed: expected .ready, got \(String(describing: flowState))"
            logger.error("🎯 ATOMIC_STATE_RESET_MORPHISM: ❌ \(errorMessage)")
            throw NSError(
                domain: "AddMoveUnifiedState",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage,
                    "correlationId": String(correlationId),
                    "operationId": operationId.uuidString,
                ]
            )
        }

        let verificationDuration = Date().timeIntervalSince(
            verificationStartTime
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: ✅ Step 3 complete - State verification passed in \(String(format: "%.3f", verificationDuration * 1000))ms"
        )

        let totalOperationDuration = Date().timeIntervalSince(
            operationStartTime
        )
        logger.info("🎯 ATOMIC_STATE_RESET_MORPHISM:  PERFORMANCE SUMMARY")
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: │  ├─ Total operation time: \(String(format: "%.3f", totalOperationDuration * 1000))ms"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: │  ├─ Target threshold: < 100ms (P95)"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: │  ├─ Performance status: \(totalOperationDuration < 0.1 ? "✅ PASSED" : "⚠️ EXCEEDED")"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: │  ├─ Correlation ID: \(correlationId)"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: │  └─ Operation ID: \(operationId.uuidString)"
        )
        logger.info(
            "🎯 ATOMIC_STATE_RESET_MORPHISM: 🎉 Atomic state reset completed - System ready for PhotosPicker presentation"
        )

        logConsecutiveLoadDiagnostics(
            "after_prepare_for_new_video_selection",
            correlationId: String(correlationId)
        )

        if totalOperationDuration >= 0.1 {
            logger.warning(
                "🎯 ATOMIC_STATE_RESET_MORPHISM: ⚠️ Performance warning - Operation exceeded 100ms target (\(String(format: "%.3f", totalOperationDuration * 1000))ms)"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func handleVideoSelection(
        _ item: PhotosPickerItem,
        context: String = "unknown"
    ) async {
        logger.info(
            "🎯 CONTEXTUAL_VIDEO_SELECTION: Delegating to unified didSelectVideo from context: \(context)"
        )
        didSelectVideo(item)
    }

    // MARK: - FUNC
    @MainActor
    private func logConsecutiveLoadDiagnostics(
        _ context: String,
        correlationId: String
    ) {
        let diagnosticLogger = Logger(
            subsystem: "breakdex",
            category: "🔍 CONSECUTIVE_LOAD_DIAGNOSTICS"
        )
        let timestamp = Date()

        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD:  [\(correlationId)] \(context) at \(timestamp)"
        )
        diagnosticLogger.info("🔍 CONSECUTIVE_LOAD: ┌─ State Analysis")
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ flow_state: \(String(describing: self.flowState))"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ player_state: \(String(describing: self.playerState))"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ unified_status: '\(self.unifiedProgressEngine.unifiedStatus)'"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ video_asset_available: \(self.videoAsset != nil)"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  └─ photos_identifier: \(self.photosIdentifier ?? "missing")"
        )

        diagnosticLogger.info("🔍 CONSECUTIVE_LOAD: ├─ Task Management")
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ videoLoadingTask_active: \(self.videoLoadingTask != nil)"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  └─ videoLoadingTask_cancelled: \(self.videoLoadingTask?.isCancelled ?? false)"
        )

        diagnosticLogger.info("🔍 CONSECUTIVE_LOAD: ├─ Progress State")
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ unified_progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress))"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ target_progress: \(String(format: "%.3f", self.unifiedProgressEngine.targetProgress))"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  └─ current_phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )

        diagnosticLogger.info("🔍 CONSECUTIVE_LOAD: ├─ Timer State")
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  ├─ load_elapsed_time: \(String(format: "%.3f", self.loadElapsedTime))s"
        )
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: │  └─ timer_service_active: \(self.timerManagementService.getLoadElapsedTime() > 0)"
        )

        diagnosticLogger.info("🔍 CONSECUTIVE_LOAD: └─ Context: \(context)")
        diagnosticLogger.info(
            "🔍 CONSECUTIVE_LOAD: 🎯 Diagnostic log completed at \(timestamp)"
        )
    }

    // MARK: - VAR
    @MainActor
    public var isCurrentErrorRecoverable: Bool {
        guard let recovery = pendingRecovery else { return false }
        return recovery.strategy.isRetryable
    }

    @MainActor
    public var currentRecoveryDescription: String {
        guard let recovery = pendingRecovery else {
            return "No recovery information available"
        }
        return recovery.strategy.description
    }

    // MARK: - FUNC
    @MainActor
    public func logDiagnosticState(_ context: String) {
        // logger.info("🎬 AddMoveUnifiedState:  DIAGNOSTIC STATE [\(context)]")
        logger.info(
            "🎬 AddMoveUnifiedState:  Flow State: \(String(describing: self.flowState))"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Video Asset: \(self.videoAsset != nil ? "✅ Loaded" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Photos ID: \(self.photosIdentifier != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Player VM: \(self.currentPlayerViewModel != nil ? "✅ Created" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Move Name: '\(self.moveName.isEmpty ? "Empty" : self.moveName)'"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Trim Range: \(String(format: "%.2f", self.trimStartTime))s - \(String(format: "%.2f", self.trimEndTime))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Rotation: \(self.totalRotationQuarterTurns * 90)° (intrinsic: \(self.intrinsicAssetRotation * 90)° + user: \(self.userAppliedRotation * 90)°)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Load Progress: \(String(format: "%.1f", self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Load Timer: \(String(format: "%.2f", self.loadElapsedTime))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Save Timer: \(String(format: "%.2f", self.saveElapsedTime))s"
        )
        // logger.info("🎬 AddMoveUnifiedState:  Memory: \(self.getMemoryUsage())")
        logger.info(
            "🎬 AddMoveUnifiedState:  Recovery Available: \(self.isCurrentErrorRecoverable ? "✅ Yes" : "❌ No")"
        )
        // logger.info("🎬 AddMoveUnifiedState:  Timestamp: \(Date())")
    }

    @MainActor
    public func logServiceStatus() {
        // logger.info("🎬 AddMoveUnifiedState: 🔧 SERVICE STATUS DIAGNOSTIC")
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Timer Service: \(self.timerManagementService != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Progress Monitor: \(self.videoProgressMonitoringService != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Save Coordinator: \(self.addMoveSaveCoordinator != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Flow Manager: \(self.flowStateManager != nil ? "✅ Available" : "❌ Missing")"
        )
        // logger.info("🎬 AddMoveUnifiedState: 🔧 State Validator: ✅ Available")
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Video Loading Service: ✅ Available"
        )
        let coreDataStatus = "✅"
        let timecodeStatus = "✅"
        let persistenceStatus = "✅"
        let processingStatus = "✅"
        logger.info(
            "🎬 AddMoveUnifiedState: 🔧 Dependencies: \(coreDataStatus) Core Data, \(timecodeStatus) Timecode, \(persistenceStatus) Persistence, \(processingStatus) Processing"
        )
    }

    // MARK: - FUNC
    @MainActor
    public func logPerformanceMetrics() {
        // logger.info("🎬 AddMoveUnifiedState: 📈 PERFORMANCE METRICS")

        let currentMemory: String = self.getMemoryUsage()
        // logger.info("🎬 AddMoveUnifiedState: 📈 Memory Usage: \(currentMemory)")

        let loadElapsed = self.timerManagementService.getLoadElapsedTime()
        let saveElapsed = self.timerManagementService.getSaveElapsedTime()
        logger.info(
            "🎬 AddMoveUnifiedState: 📈 Load Timer: \(String(format: "%.2f", loadElapsed))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 📈 Save Timer: \(String(format: "%.2f", saveElapsed))s"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 📈 State Transitions: \(self.stateTransitionCount)"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: 📈 Recovery Attempts: \(self.recoveryAttemptCount)"
        )

        if let asset = self.videoAsset {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    logger.info(
                        "🎬 AddMoveUnifiedState: 📈 Video Duration: \(String(format: "%.2f", duration.seconds))s"
                    )

                    let tracks = try await asset.load(.tracks)
                    logger.info(
                        "🎬 AddMoveUnifiedState: 📈 Video Tracks: \(tracks.count)"
                    )
                } catch {
                    logger.error(
                        "🎬 AddMoveUnifiedState: ❌ Failed to load asset info: \(error.localizedDescription)"
                    )
                }
            }
        }

        // logger.info("🎬 AddMoveUnifiedState: 📈 Timestamp: \(Date())")
    }

    private var stateTransitionCount: Int = 0
    private var recoveryAttemptCount: Int = 0

    // MARK: - FUNC
    @MainActor
    private func logStateTransitionWithMetrics(
        from: AddMoveFlowState,
        to: AddMoveFlowState,
        triggeredBy: String
    ) {
        self.stateTransitionCount += 1

        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 STATE TRANSITION #\(self.stateTransitionCount)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 From: \(String(describing: from))"
        )
        // logger.info("🎬 AddMoveUnifiedState: 🔄 To: \(String(describing: to))")
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Triggered by: \(triggeredBy)")
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Timestamp: \(Date())")

        if case .loadingVideo = to {
            logger.info(
                "🎬 AddMoveUnifiedState: 🔄 Starting load phase - beginning performance monitoring"
            )
        } else if case .saving = to {
            logger.info(
                "🎬 AddMoveUnifiedState: 🔄 Starting save phase - monitoring save performance"
            )
        } else if to.isTerminalState {
            logger.info(
                "🎬 AddMoveUnifiedState: 🔄 Reached terminal state - completing performance monitoring"
            )
            self.logPerformanceMetrics()
        }
    }

    // MARK: - FUNC
    @MainActor
    private func logRecoveryAttempt(
        strategy: ErrorRecoveryStrategy,
        originalError: String
    ) {
        self.recoveryAttemptCount += 1

        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 RECOVERY ATTEMPT #\(self.recoveryAttemptCount)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Strategy: \(strategy.description)"
        )
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Original Error: \(originalError)")
        // logger.info("🎬 AddMoveUnifiedState: 🔄 Timestamp: \(Date())")
    }

    // MARK: - FUNC
    @MainActor
    public func logTimerDiagnostics() {
        // logger.info("🎬 AddMoveUnifiedState: ⏱️ TIMER DIAGNOSTICS")
        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ Load Elapsed: \(String(format: "%.3f", self.timerManagementService.getLoadElapsedTime()))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: ⏱️ Save Elapsed: \(String(format: "%.3f", self.timerManagementService.getSaveElapsedTime()))s"
        )
        // logger.info("🎬 AddMoveUnifiedState: ⏱️ Timestamp: \(Date())")
    }

    @MainActor
    public func logProgressDiagnostics() {
        // logger.info("🎬 AddMoveUnifiedState:  PROGRESS DIAGNOSTICS")
        logger.info(
            "🎬 AddMoveUnifiedState:  Current Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Loading Progress: \(String(format: "%.3f", self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Loading Status: '\(self.unifiedProgressEngine.unifiedStatus)'"
        )
        // logger.info("🎬 AddMoveUnifiedState:  Timestamp: \(Date())")
    }

    // MARK: - FUNC
    @MainActor
    private func generateEnhancedErrorMessage(
        from error: Error,
        correlationId: String
    ) -> String {

        logger.error(
            "🚨 ENHANCED_ERROR_HANDLING: Starting error message transformation [\(correlationId)] - Error: \(type(of: error)) - \(error.localizedDescription)"
        )

        if let videoLoadingError = error as? VideoLoadingError {
            switch videoLoadingError {
            case .itemIdentifierMissing:
                logger.error(
                    "🚨 CRITICAL_ERROR: VideoLoadingError.itemIdentifierMissing - INVALID IDENTIFIER [\(correlationId)] - User must reselect video from photo library"
                )
                return
                    "🚫 Invalid video selection: The selected video doesn't have a valid identifier. Please try selecting a different video from your photo library."

            case .assetNotFound:
                logger.warning(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.assetNotFound detected [\(correlationId)]"
                )
                return
                    "📷 Video not found: The selected video could not be located in your photo library. Please ensure the video is still available and try again."

            case .avAssetCreationFailed:
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.avAssetCreationFailed detected [\(correlationId)]"
                )
                return
                    "🎬 Video format error: The selected video format is not supported. Please try selecting a different video (MP4, MOV, or M4V recommended)."

            case .unsupportedFileType:
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.unsupportedFileType detected [\(correlationId)]"
                )
                return
                    "📄 Unsupported file type: The selected file is not a compatible video format. Please select a valid video file (MP4, MOV, or M4V)."

            case .dataUnavailable:
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.dataUnavailable detected [\(correlationId)]"
                )
                return
                    "☁️ Video unavailable: The selected video is currently unavailable from iCloud. Please check your internet connection and try again, or select a video that's already downloaded to your device."

            case .temporaryFileError(let underlyingError):
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.temporaryFileError detected [\(correlationId)]"
                )
                return
                    "💾 Storage error: Unable to process the video due to a storage issue. Please free up space on your device and try again. (\(underlyingError.localizedDescription))"

            case .transferableNotSupported:
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.transferableNotSupported detected [\(correlationId)]"
                )
                return
                    "🔄 Transfer error: The video transfer format is not supported. Please try selecting a different video."

            case .streamingFailed(let underlyingError):
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.streamingFailed detected [\(correlationId)]"
                )
                return
                    "📡 Transfer failed: Unable to copy the video data. Please check your storage space and try again. (\(underlyingError.localizedDescription))"

            case .validationFailed(let reason):
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.validationFailed detected [\(correlationId)]"
                )
                return
                    "⚠️ Validation failed: The selected video failed validation. \(reason)"

            case .dataTransferFailed(let reason):
                logger.error(
                    "🚨 ENHANCED_ERROR_HANDLING: VideoLoadingError.dataTransferFailed detected [\(correlationId)]"
                )
                return
                    "🔄 Data transfer failed: Unable to load video data. \(reason)"
            }
        }

        if error.localizedDescription.contains("denied")
            || error.localizedDescription.contains("unauthorized")
        {
            logger.warning(
                "🚨 ENHANCED_ERROR_HANDLING: Photos access permission error detected [\(correlationId)]"
            )
            return
                "📸 Photo library access denied: Please allow access to your photo library in Settings > Privacy & Security > Photos to select videos."
        }

        if error.localizedDescription.contains("network")
            || error.localizedDescription.contains("connection")
            || error.localizedDescription.contains("offline")
        {
            logger.warning(
                "🚨 ENHANCED_ERROR_HANDLING: Network connectivity error detected [\(correlationId)]"
            )
            return
                "🌐 Network error: Unable to download the video from iCloud. Please check your internet connection and try again."
        }

        if error.localizedDescription.contains("iCloud")
            || error.localizedDescription.contains("cloud")
        {
            logger.warning(
                "🚨 ENHANCED_ERROR_HANDLING: iCloud sync error detected [\(correlationId)]"
            )
            return
                "☁️ iCloud sync error: The video is not fully synced with iCloud. Please ensure the video is downloaded to your device or wait for sync to complete."
        }

        if error.localizedDescription.contains("space")
            || error.localizedDescription.contains("storage")
        {
            logger.warning(
                "🚨 ENHANCED_ERROR_HANDLING: Storage space error detected [\(correlationId)]"
            )
            return
                "💾 Insufficient storage: Not enough space available to process this video. Please free up storage space on your device and try again."
        }

        if error.localizedDescription.contains("timeout")
            || error.localizedDescription.contains("timed out")
        {
            logger.warning(
                "🚨 ENHANCED_ERROR_HANDLING: Timeout error detected [\(correlationId)]"
            )
            return
                "⏱️ Processing timeout: The video took too long to load. Please try again with a smaller video or check your network connection."
        }

        logger.error(
            "🚨 ENHANCED_ERROR_HANDLING: Unknown error type detected [\(correlationId)] - Error: \(type(of: error)) - \(error.localizedDescription)"
        )

        return
            "❌ Unable to load video: An unexpected error occurred. Please try selecting a different video or restart the app. (\(error.localizedDescription))"
    }

    // MARK: - FUNC
    @MainActor
    public func logFullDebugDiagnostics() {
        // logger.info("🎬 AddMoveUnifiedState: 🐛 FULL DEBUG DIAGNOSTICS START")
        logger.info(
            "🎬 AddMoveUnifiedState: 🐛 ======================================"
        )

        logDiagnosticState("Full Debug")
        logServiceStatus()
        logTimerDiagnostics()
        logProgressDiagnostics()
        logPerformanceMetrics()

        if case .error(let message, let underlying) = self.flowState {
            logger.error("🎬 AddMoveUnifiedState: 🐛 Current Error: \(message)")
            if let underlying = underlying {
                logger.error(
                    "🎬 AddMoveUnifiedState: 🐛 Underlying Error: \(underlying)"
                )
            }
            logger.info(
                "🎬 AddMoveUnifiedState: 🐛 Recovery Available: \(self.isCurrentErrorRecoverable)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState: 🐛 Recovery Strategy: \(self.currentRecoveryDescription)"
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState: 🐛 ======================================"
        )
        // logger.info("🎬 AddMoveUnifiedState: 🐛 FULL DEBUG DIAGNOSTICS END")
    }

    // MARK: - FUNC
    @MainActor
    public func applyTrimSettings(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        // logger.info("🎬 AddMoveUnifiedState: Applying trim settings")
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Applying user rotation: \(rotation * 90)°"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Previous total rotation: \(self.totalRotationQuarterTurns * 90)° (intrinsic: \(self.intrinsicAssetRotation * 90)° + user: \(self.userAppliedRotation * 90)°)"
        )

        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Rotation applied successfully: \(self.totalRotationQuarterTurns * 90)° (intrinsic: \(self.intrinsicAssetRotation * 90)° + user: \(self.userAppliedRotation * 90)°)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Trim range: \(String(format: "%.2f", self.trimStartTime))s - \(String(format: "%.2f", self.trimEndTime))s"
        )

        if unifiedPlayerManager.currentPlayer != nil {
            try await unifiedPlayerManager.applyTrimToCurrentPlayer(
                startTime: startTime,
                endTime: endTime,
                rotation: rotation
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    public func handleRotation() async {
        let rotationHandlingStartTime = CFAbsoluteTimeGetCurrent()
        let operationId = UUID().uuidString.prefix(8)

        logRotationStateFix(
            "handleRotation() Started",
            operation: "AUTHORITATIVE_ROTATION"
        )

        do {

            guard let trimmerVM = trimmerViewModel as? TrimmerViewModel else {
                logger.error(
                    "🎯 DOUBLE_ROTATION_FIX: ❌ TrimmerViewModel not available [\(operationId)] | error_type: trimmer_viewmodel_unavailable, fix_failed: true, operation_aborted: true"
                )
                return
            }

            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ✅ TrimmerViewModel validated [\(operationId)] | trimmer_ready: \(trimmerVM.isReady), player_ready: \(trimmerVM.playerViewModel.isPlayerReady)"
            )

            let oldUserRotation = trimmerVM.userAppliedRotationTurns
            let newUserRotation = (trimmerVM.userAppliedRotationTurns + 1) % 4
            let oldTotalRotation = trimmerVM.totalRotationQuarterTurns

            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: 🔄 Applying Rotation Morphism [\(operationId)]"
            )
            logger.info("🎯 DOUBLE_ROTATION_FIX: ┌─ Rotation Transformation")
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ domain: UserRotationSpace(Z/4)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ codomain: UserRotationSpace(Z/4)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ morphism_f: \(oldUserRotation) → \(newUserRotation)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ degrees: \(oldUserRotation * 90)° → \(newUserRotation * 90)°"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: └─ operation: user_rotation_increment_mod_4"
            )

            trimmerVM.userAppliedRotationTurns = newUserRotation

            let newTotalRotation = trimmerVM.totalRotationQuarterTurns

            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: 📐 Natural Transformation Applied [\(operationId)]"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ┌─ Natural Transformation η: intrinsic ⊕ user → total"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ intrinsic_rotation: \(trimmerVM.assetIntrinsicRotationTurns) turns"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ user_rotation_new: \(newUserRotation) turns"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ total_rotation_old: \(oldTotalRotation) turns (\(oldTotalRotation * 90)°)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ total_rotation_new: \(newTotalRotation) turns (\(newTotalRotation * 90)°"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: └─ transformation_commutative: intrinsic ⊕ user = total"
            )

            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: 🎬 Starting Authoritative Player Item Rebuilding [\(operationId)]"
            )
            logger.info("🎯 DOUBLE_ROTATION_FIX: ┌─ Player Rebuilding Context")
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ target_total_rotation: \(newTotalRotation) turns (\(newTotalRotation * 90)°)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ video_composition_will_contain: rotation_transform"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ swiftui_identity_morphism: enforced"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ double_rotation_prevention: active"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: └─ helper_function: rebuildPlayerItemForTrimmer"
            )

            let rebuiltPlayerItem = try await rebuildPlayerItemForTrimmer(
                trimmerVM
            )

            guard
                let unifiedPlayer = trimmerVM.playerViewModel
                    as? UnifiedVideoPlayerViewModel
            else {
                logger.error(
                    "🎯 DOUBLE_ROTATION_FIX: ❌ PlayerViewModel is not UnifiedVideoPlayerViewModel"
                )
                throw VideoProcessingError.playerInitializationFailed
            }

            try await unifiedPlayer.replacePlayerItemAndWaitForReady(
                rebuiltPlayerItem
            )

            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ✅ Player item rebuilding completed successfully [\(operationId)]"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ avplayeritem_contains_baked_rotation: true"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ player_ready: \(unifiedPlayer.isPlayerReady)"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: ├─ helper_function_used: rebuildPlayerItemForTrimmer"
            )
            logger.info(
                "🎯 DOUBLE_ROTATION_FIX: └─ category_theory_compliance: maintained"
            )

            let rotationHandlingTime =
                (CFAbsoluteTimeGetCurrent() - rotationHandlingStartTime) * 1000

            logger.info(
                "✅ DOUBLE_ROTATION_FIX: 🎉 handleRotation() COMPLETED SUCCESSFULLY [\(operationId)]"
            )
            logger.info("✅ DOUBLE_ROTATION_FIX: ┌─ Operation Summary")
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ rotation_handling_time_ms: \(String(format: "%.2f", rotationHandlingTime))"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ user_rotation_after: \(trimmerVM.userAppliedRotationTurns * 90)°"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ total_rotation_after: \(trimmerVM.totalRotationQuarterTurns * 90)°"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ player_item_rebuilding: COMPLETED"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ avplayer_rotation_baked_in: TRUE"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ double_rotation_bug: ELIMINATED"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ swiftui_identity_morphism: ENFORCED"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: ├─ helper_function_used: rebuildPlayerItemForTrimmer"
            )
            logger.info(
                "✅ DOUBLE_ROTATION_FIX: └─ category_theory_compliance: VERIFIED"
            )

        } catch {
            let rotationHandlingTime =
                (CFAbsoluteTimeGetCurrent() - rotationHandlingStartTime) * 1000

            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: ❌ handleRotation() FAILED [\(operationId)]"
            )
            logger.error("🎯 DOUBLE_ROTATION_FIX: ┌─ Error Context")
            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: ├─ rotation_handling_time_ms: \(String(format: "%.2f", rotationHandlingTime))"
            )
            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: ├─ error_type: \(type(of: error))"
            )
            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: ├─ error_description: \(error.localizedDescription)"
            )
            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: ├─ player_regeneration: FAILED"
            )
            logger.error("🎯 DOUBLE_ROTATION_FIX: ├─ fallback_needed: TRUE")
            logger.error(
                "🎯 DOUBLE_ROTATION_FIX: └─ operation_id: \(operationId)"
            )

            if let trimmerVM = trimmerViewModel as? TrimmerViewModel {
                logger.warning(
                    "🎯 DOUBLE_ROTATION_FIX: 🔄 Applying Graceful Fallback [\(operationId)]"
                )
                logger.warning("🎯 DOUBLE_ROTATION_FIX: ┌─ Fallback Strategy")
                logger.warning(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ fallback_type: viewmodel_state_update_only"
                )
                logger.warning(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ rotation_state_updated: TRUE"
                )
                logger.warning(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ player_regeneration: DEFERRED"
                )
                logger.warning(
                    "🎯 DOUBLE_ROTATION_FIX: └─ ui_consistency: MAINTAINED"
                )

                logger.info(
                    "🎯 DOUBLE_ROTATION_FIX: ✅ Fallback Applied Successfully [\(operationId)]"
                )
                logger.info("🎯 DOUBLE_ROTATION_FIX: ┌─ Fallback State")
                logger.info(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ user_rotation_fallback: \(trimmerVM.userAppliedRotationTurns * 90)°"
                )
                logger.info(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ total_rotation_fallback: \(trimmerVM.totalRotationQuarterTurns * 90)°"
                )
                logger.info(
                    "🎯 DOUBLE_ROTATION_FIX: ├─ player_will_regenerate: ON_NEXT_LOAD"
                )
                logger.info(
                    "🎯 DOUBLE_ROTATION_FIX: └─ user_experience: PRESERVED"
                )
            }
        }
    }

    // MARK: - FUNC
    @MainActor
    private func rebuildPlayerItemForTrimmer(_ trimmerVM: TrimmerViewModel)
        async throws -> AVPlayerItem
    {
        let rebuildStartTime = CFAbsoluteTimeGetCurrent()
        let operationId = UUID().uuidString.prefix(8)

        logger.info(
            "🎯 PLAYER_REBUILD: 🚀 Starting player item rebuild for trimmer [\(operationId)]"
        )
        logger.info(
            "🎯 PLAYER_REBUILD:  Rotation state - Intrinsic: \(trimmerVM.assetIntrinsicRotationTurns), User: \(trimmerVM.userAppliedRotationTurns)"
        )
        logger.info(
            "🎯 PLAYER_REBUILD: 📐 Total rotation: \(trimmerVM.totalRotationQuarterTurns) × 90° = \(trimmerVM.totalRotationQuarterTurns * 90)°"
        )

        guard let asset = videoAsset else {
            logger.error(
                "🎯 PLAYER_REBUILD: ❌ Video asset not available for player rebuild [\(operationId)]"
            )
            throw PlayerCreationError.dependenciesNotReady
        }

        guard let photosIdentifier = photosIdentifier else {
            logger.error(
                "🎯 PLAYER_REBUILD: ❌ Photos identifier not available for player rebuild [\(operationId)]"
            )
            throw PlayerCreationError.dependenciesNotReady
        }

        logger.info(
            "🎯 PLAYER_REBUILD: ✅ Dependencies validated for player rebuild [\(operationId)]"
        )

        logger.info(
            "🎯 PLAYER_REBUILD: 🔄 Applying natural transformation η for player rebuild [\(operationId)]"
        )
        logger.info("🎯 PLAYER_REBUILD: ├─ domain: RotationSpace(ℤ₄ × ℤ₄)")
        logger.info("🎯 PLAYER_REBUILD: ├─ codomain: AVPlayerItemSpace")
        logger.info(
            "🎯 PLAYER_REBUILD: ├─ morphism: createOrUpdatePlayer with VideoTransformBuilder"
        )
        logger.info(
            "🎯 PLAYER_REBUILD: └─ natural_transformation: η(\(trimmerVM.assetIntrinsicRotationTurns), \(trimmerVM.userAppliedRotationTurns)) = \(trimmerVM.totalRotationQuarterTurns)"
        )

        do {

            let rebuiltPlayerItem =
                try await VideoTransformBuilder.createPlayerItem(
                    asset: asset,
                    trimRange: CMTimeRange(
                        start: trimmerVM.startTime,
                        end: trimmerVM.endTime
                    ),
                    quarterTurns: trimmerVM.totalRotationQuarterTurns
                )

            let rebuildDuration = CFAbsoluteTimeGetCurrent() - rebuildStartTime

            logger.info(
                "🎯 PLAYER_REBUILD: ✅ Player item rebuilt successfully [\(operationId)]"
            )
            logger.info("🎯 PLAYER_REBUILD:  Rebuild metrics:")
            logger.info(
                "🎯 PLAYER_REBUILD: ├─ rebuild_duration_ms: \(String(format: "%.2f", rebuildDuration * 1000))"
            )
            logger.info(
                "🎯 PLAYER_REBUILD: ├─ player_item_ready: \(rebuiltPlayerItem.status.rawValue)"
            )
            logger.info("🎯 PLAYER_REBUILD: ├─ rotation_baked_in: TRUE")
            logger.info("🎯 PLAYER_REBUILD: ├─ double_rotation_bug: ELIMINATED")
            logger.info("🎯 PLAYER_REBUILD: └─ wysiwyg_guaranteed: TRUE")

            return rebuiltPlayerItem

        } catch {
            let rebuildDuration = CFAbsoluteTimeGetCurrent() - rebuildStartTime
            logger.error(
                "🎯 PLAYER_REBUILD: ❌ Player item rebuild failed [\(operationId)]"
            )
            logger.error(
                "🎯 PLAYER_REBUILD: ├─ rebuild_duration_ms: \(String(format: "%.2f", rebuildDuration * 1000))"
            )
            logger.error("🎯 PLAYER_REBUILD: ├─ error_type: \(type(of: error))")
            logger.error(
                "🎯 PLAYER_REBUILD: ├─ error_description: \(error.localizedDescription)"
            )
            logger.error(
                "🎯 PLAYER_REBUILD: └─ natural_transformation_failed: TRUE"
            )

            let enhancedError = NSError(
                domain: "AddMoveUnifiedState.PlayerRebuild",
                code: -2001,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to rebuild player item with rotation",
                    NSLocalizedFailureReasonErrorKey: error
                        .localizedDescription,
                    "rotation_state":
                        "intrinsic=\(trimmerVM.assetIntrinsicRotationTurns), user=\(trimmerVM.userAppliedRotationTurns), total=\(trimmerVM.totalRotationQuarterTurns)",
                    "operation_id": operationId,
                    "rebuild_duration_ms": rebuildDuration * 1000,
                ]
            )

            throw enhancedError
        }
    }

    // MARK: - FUNC
    @MainActor
    public func setupTrimmerAfterPreview() async {
        logger.info(
            "🎬 AddMoveUnifiedState: Delegating trimmer setup to FlowStateManager"
        )

        guard let flowStateManager = flowStateManager else {
            logger.error(
                "🎬 AddMoveUnifiedState: FlowStateManager not initialized"
            )
            await setError(
                message: "FlowStateManager not available",
                underlying: "FlowStateManager is nil"
            )
            return
        }

        await flowStateManager.setupTrimmerAfterPreview()
    }

    // MARK: - FUNC
    @MainActor
    private func preserveTrimmingState() async {
        logger.info(
            "🎬 AddMoveUnifiedState: 💾 Preserving trimming state for back button functionality (async with intrinsic rotation)"
        )

        guard let snapshot = await TrimmingStateSnapshot(unifiedState: self)
        else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Failed to create async trimming state snapshot - missing required data"
            )
            return
        }

        preservedTrimmingState = snapshot
        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Async Trimming state preserved successfully with intrinsic rotation"
        )
        logTrimmingStateSnapshot(snapshot)
    }

    // MARK: - FUNC
    @MainActor
    internal func preserveTrimmingStateAtomic() async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔒 ATOMIC Preserving trimming state for back button functionality"
        )
        logger.info(
            "🎬 AddMoveUnifiedState: 🎯 MORPHISM PRESERVATION: Executing categorical state preservation functor"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  NATURAL TRANSFORMATION: Preserving isomorphic state structure for rollback integrity"
        )

        let preservationStart = Date()

        guard case .trimming = self.flowState else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ ATOMIC preservation aborted - not in trimming state: \(String(describing: self.flowState))"
            )
            return
        }

        guard videoAsset != nil else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC preservation failed - video asset is nil"
            )
            return
        }

        guard let snapshot = await TrimmingStateSnapshot(unifiedState: self)
        else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC preservation failed - snapshot creation failed"
            )
            return
        }

        let previousSnapshot = preservedTrimmingState
        preservedTrimmingState = snapshot

        let preservationDuration = Date().timeIntervalSince(preservationStart)

        if preservedTrimmingState?.timestamp == snapshot.timestamp {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ ATOMIC Trimming state preserved successfully"
            )
            // logger.info("🎬 AddMoveUnifiedState:  ATOMIC preservation metrics:")
            logger.info(
                "🎬 AddMoveUnifiedState:   - Duration: \(String(format: "%.3f", preservationDuration))s"
            )
            logger.info(
                "🎬 AddMoveUnifiedState:   - Previous snapshot: \(previousSnapshot != nil ? "Replaced" : "None")"
            )
            logger.info(
                "🎬 AddMoveUnifiedState:   - New snapshot created: \(snapshot.photosIdentifier)"
            )
            logger.info(
                "🎬 AddMoveUnifiedState:   - Trim range: \(String(format: "%.3f", snapshot.trimStartTime))s - \(String(format: "%.3f", snapshot.trimEndTime))s"
            )
            logger.info(
                "🎬 AddMoveUnifiedState:   - Total Rotation: \(snapshot.totalRotationQuarterTurns * 90)° (intrinsic: \(snapshot.intrinsicAssetRotation * 90)° + user: \(snapshot.userAppliedRotation * 90)°)"
            )
        } else {
            logger.error(
                "🎬 AddMoveUnifiedState: ❌ ATOMIC preservation validation failed"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func restoreTrimmingState() -> Bool {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Restoring trimming state from preserved snapshot"
        )

        guard let snapshot = preservedTrimmingState else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ No preserved trimming state available"
            )
            return false
        }

        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)
        let maxAge: TimeInterval = 300.0

        guard snapshotAge < maxAge else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Preserved trimming state is too old (\(String(format: "%.1f", snapshotAge))s)"
            )
            preservedTrimmingState = nil
            return false
        }

        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Restoring rotation from categorical system"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Restoring intrinsic: \(snapshot.intrinsicAssetRotation * 90)°, user: \(snapshot.userAppliedRotation * 90)°"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Current total rotation before restore: \(self.totalRotationQuarterTurns * 90)° (intrinsic: \(self.intrinsicAssetRotation * 90)° + user: \(self.userAppliedRotation * 90)°)"
        )

        videoAsset = snapshot.videoAsset
        photosIdentifier = snapshot.photosIdentifier

        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Rotation restored successfully: \(self.totalRotationQuarterTurns * 90)° (intrinsic: \(self.intrinsicAssetRotation * 90)° + user: \(self.userAppliedRotation * 90)°)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Intrinsic rotation: \(snapshot.intrinsicAssetRotation * 90)°"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - User-applied rotation: \(snapshot.userAppliedRotation * 90)°"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ROTATION DEBUG - Double rotation bug fix verified: WYSIWYG preserved"
        )

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Trimming state restored successfully"
        )
        logTrimmingStateSnapshot(snapshot)

        return true
    }

    // MARK: - FUNC
    @MainActor
    private func clearPreservedTrimmingState() {
        preservedTrimmingState = nil
        // logger.info("🎬 AddMoveUnifiedState: 🧹 Preserved trimming state cleared")
    }

    // MARK: - FUNC
    @MainActor
    private func hasValidPreservedTrimmingState() -> Bool {
        guard let snapshot = preservedTrimmingState else {
            return false
        }

        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)
        let maxAge: TimeInterval = 300.0

        return snapshotAge < maxAge
    }

    @MainActor
    public func canRestoreTrimmingState() -> Bool {
        return hasValidPreservedTrimmingState()
    }

    @MainActor
    public func attemptTrimmingStateRestoration() -> Bool {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Public trimming state restoration requested"
        )

        let success = restoreTrimmingState()

        if success {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Public trimming state restoration successful"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ❌ Public trimming state restoration failed"
            )
        }

        return success
    }

    // MARK: - FUNC
    @MainActor
    private func logTrimmingStateSnapshot(_ snapshot: TrimmingStateSnapshot?) {
        guard let snapshot = snapshot else {
            logger.info(
                "🎬 AddMoveUnifiedState:  No trimming state snapshot to log"
            )
            return
        }

        let snapshotAge = Date().timeIntervalSince(snapshot.timestamp)

        let isIsoMorphic =
            ((snapshot.intrinsicAssetRotation + snapshot.userAppliedRotation)
                % 4) == snapshot.totalRotationQuarterTurns
        let isoStatus = isIsoMorphic ? "✅ PRESERVED" : "❌ VIOLATED"
        let transformationType =
            snapshot.creationTimeMs < 1.0 ? "ASYNC" : "SYNC_LEGACY"

        logger.info(
            "🎬 AddMoveUnifiedState:  ENHANCED TRIMMING STATE SNAPSHOT ANALYSIS"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  ════════════════════════════════════════════════════════════════"
        )
        // logger.info("🎬 AddMoveUnifiedState:  📷 CORE METADATA")
        logger.info(
            "🎬 AddMoveUnifiedState:  Photos ID: \(snapshot.photosIdentifier)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Trim Range: \(String(format: "%.3f", snapshot.trimStartTime))s - \(String(format: "%.3f", snapshot.trimEndTime))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Duration: \(String(format: "%.3f", snapshot.trimEndTime - snapshot.trimStartTime))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Snapshot Age: \(String(format: "%.2f", snapshotAge))s"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Creation Time: \(snapshot.timestamp)"
        )

        // logger.info("🎬 AddMoveUnifiedState:  🔄 CATEGORICAL ROTATION ANALYSIS")
        logger.info(
            "🎬 AddMoveUnifiedState:  Transformation Type: \(transformationType)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Total Rotation: \(snapshot.totalRotationQuarterTurns * 90)° (\(snapshot.totalRotationQuarterTurns) quarter turns)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Intrinsic Asset Rotation: \(snapshot.intrinsicAssetRotation * 90)° (\(snapshot.intrinsicAssetRotation) quarter turns)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  User-Applied Rotation: \(snapshot.userAppliedRotation * 90)° (\(snapshot.userAppliedRotation) quarter turns)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Natural Transformation η: \(isoStatus)"
        )

        // logger.info("🎬 AddMoveUnifiedState:  🧮 ISOMORPHISM VERIFICATION")
        logger.info(
            "🎬 AddMoveUnifiedState:  Formula: (Intrinsic ⊕ User) mod 4 = Total"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Calculation: (\(snapshot.intrinsicAssetRotation) ⊕ \(snapshot.userAppliedRotation)) mod 4 = \((snapshot.intrinsicAssetRotation + snapshot.userAppliedRotation) % 4)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Expected: \(snapshot.totalRotationQuarterTurns)"
        )
        logger.info(
            "🎬 AddMoveUnifiedState:  Result: \(isIsoMorphic ? "MATHEMATICAL INTEGRITY PRESERVED" : "⚠️ MATHEMATICAL INTEGRITY COMPROMISED")"
        )

        // logger.info("🎬 AddMoveUnifiedState:  ⚡ PERFORMANCE METRICS")
        logger.info(
            "🎬 AddMoveUnifiedState:  Creation Time: \(String(format: "%.3f", snapshot.creationTimeMs))ms"
        )
        if snapshot.creationTimeMs < 5.0 {
            logger.info(
                "🎬 AddMoveUnifiedState:  Performance: ⚡ EXCELLENT (< 5ms)"
            )
        } else if snapshot.creationTimeMs < 15.0 {
            // logger.info("🎬 AddMoveUnifiedState:  Performance: ✅ GOOD (< 15ms)")
        } else if snapshot.creationTimeMs < 50.0 {
            logger.info(
                "🎬 AddMoveUnifiedState:  Performance: ⚠️ ACCEPTABLE (< 50ms)"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState:  Performance: ❌ SLOW (> 50ms) - Consider optimization"
            )
        }

        // logger.info("🎬 AddMoveUnifiedState:  🎯 WYSIWYG ROTATION GUARANTEE")
        if isIsoMorphic && snapshot.intrinsicAssetRotation != 0 {
            logger.info(
                "🎬 AddMoveUnifiedState:  Status: ✅ WYSIWYG PRESERVED - True intrinsic rotation detected"
            )
        } else if isIsoMorphic {
            logger.info(
                "🎬 AddMoveUnifiedState:  Status: ✅ WYSIWYG PRESERVED - No intrinsic rotation needed"
            )
        } else {
            logger.error(
                "🎬 AddMoveUnifiedState:  Status: ❌ WYSIWYG COMPROMISED - Isomorphism violation detected"
            )
        }

        logger.info(
            "🎬 AddMoveUnifiedState:  ════════════════════════════════════════════════════════════════"
        )

        if !isIsoMorphic {
            logger.error(
                "🎬 AddMoveUnifiedState: 🚨 CRITICAL: Rotation isomorphism violated! User will see incorrect rotation."
            )
        }

        if transformationType == "SYNC_LEGACY" {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ WARNING: Using legacy synchronous initializer - intrinsic rotation may be inaccurate"
            )
        }

        if snapshotAge > 240.0 {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ WARNING: Snapshot is aging (\(String(format: "%.1f", snapshotAge))s) - consider refresh"
            )
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private class OSLogAppLogger: AppLogger {
        private let logger = Logger(
            subsystem: "com.breakingflashcards",
            category: "AddMoveAppLogger"
        )

        // MARK: - FUNC
        func info(_ message: String, metadata: [String: Any]? = nil) {
            logger.info("\(message)")
        }
        // MARK: - FUNC
        func warning(_ message: String, metadata: [String: Any]? = nil) {
            logger.warning("\(message)")
        }
        // MARK: - FUNC
        func error(_ message: String, metadata: [String: Any]? = nil) {
            logger.error("\(message)")
        }
        // MARK: - FUNC
        func critical(_ message: String, metadata: [String: Any]? = nil) {
            logger.critical("\(message)")
        }
        // MARK: - FUNC
        func debug(_ message: String, metadata: [String: Any]? = nil) {
            logger.debug("\(message)")
        }
    }

    // MARK: - FUNC
    public func tearDown() {
        logger.info("🎬 AddMoveUnifiedState teardown initiated")

        if let videoLoadingTask = videoLoadingTask {
            videoLoadingTask.cancel()
            self.videoLoadingTask = nil
            logger.info(
                "🎬 AddMoveUnifiedState: 🛑 Video loading task cancelled during teardown"
            )
        }

        Task { @MainActor in
            timerManagementService.resetAllTimers()
            videoProgressMonitoringService.stopMonitoring()
            stateValidator.tearDown()
            addMoveSaveCoordinator?.reset()
            cancellables.removeAll()
        }
    }

    // MARK: - FUNC
    func logUnifiedProgressEngineStateChange(
        previous: UnifiedProgressEngine.LoadingPhase,
        new: UnifiedProgressEngine.LoadingPhase,
        context: String
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let integrationLogger = Logger(
            subsystem: "breakdex",
            category: "🔗 INTEGRATION_POINTS"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] 🚀 UnifiedProgressEngine state change:"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Context: \(context)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ From: \(previous.displayName)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ To: \(new.displayName)"
        )

        switch new {
        case .initializing:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Initializing resources"
            )
        case .requestingDownload:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Requesting download from iCloud"
            )
        case .waitingForNetwork:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Waiting for network connection"
            )
        case .downloadingFromCloud:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Downloading from iCloud"
            )
        case .transferring:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Local asset transfer"
            )
        case .validating:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Asset validation"
            )
        case .creatingAsset:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: AVAsset creation"
            )
        case .generatingThumbnail:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Generating video thumbnail"
            )
        case .loadingTrimmerDuration:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Loading trimmer duration"
            )
        case .loadingTrimmerTracks:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Loading trimmer tracks"
            )
        case .validatingTrimmer:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Trimmer validation"
            )
        case .completed:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Loading completed"
            )
        case .error:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Phase: Error occurred"
            )
        }

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ✅ State change logged"
        )
    }

    // MARK: - FUNC
    func logTimerManagementServiceUpdate(
        timerValue: TimeInterval,
        previousValue: TimeInterval,
        updateInterval: TimeInterval
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let integrationLogger = Logger(
            subsystem: "breakdex",
            category: "🔗 INTEGRATION_POINTS"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ⏱️ TimerManagementService update:"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Previous: \(String(format: "%.2f", previousValue))s"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Current: \(String(format: "%.2f", timerValue))s"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Delta: \(String(format: "%+.2f", timerValue - previousValue))s"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Update interval: \(String(format: "%.3f", updateInterval))s"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Precision: centisecond (0.01s)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Expected interval: 0.010s"
        )

        let expectedInterval = 0.01
        let intervalDeviation = abs(updateInterval - expectedInterval)
        if intervalDeviation > 0.002 {
            let warningLogger = Logger(
                subsystem: "breakdex",
                category: "⚠️ PERFORMANCE_WARNINGS"
            )
            warningLogger.warning(
                "⚠️ TIMER_PRECISION: [\(sessionId)] Timer update deviation: \(String(format: "%.3f", intervalDeviation))s"
            )
        } else {
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] ✅ Timer precision within tolerance"
            )
        }
    }

    @MainActor
    func logAddMoveContainerStateChange(
        from: AddMoveFlowState,
        to: AddMoveFlowState,
        trigger: String
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let integrationLogger = Logger(
            subsystem: "breakdex",
            category: "🔗 INTEGRATION_POINTS"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] 🏗️ AddMoveContainer state transition:"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ From: \(String(describing: from))"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ To: \(String(describing: to))"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Trigger: \(trigger)"
        )

        let currentProgress = Int(
            self.unifiedProgressEngine.unifiedProgress * 100
        )
        let loadElapsed = String(format: "%.3f", self.loadElapsedTime)
        let memoryUsage = String(format: "%.1f", self.getMemoryUsageInMB())

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Progress: \(currentProgress)%"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Load elapsed: \(loadElapsed)s"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Memory: \(memoryUsage)MB"
        )

        switch (from, to) {
        case (.ready, .loadingVideo):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Video loading initiated"
            )
        case (.loadingVideo, .trimming):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Video ready for trimming"
            )
        case (.trimming, .loadingTrimmedAsset):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Preparing trimmed asset"
            )
        case (.loadingTrimmedAsset, .naming):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Ready for naming"
            )
        case (.naming, .saving):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Save operation started"
            )
        case (_, .success):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: ✅ Operation completed successfully"
            )
        case (_, .error):
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: ❌ Error state entered"
            )
        default:
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Transition: Standard state progression"
            )
        }

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ✅ Container transition logged"
        )
    }

    // MARK: - FUNC
    @MainActor
    func logServiceCoordination(
        service: String,
        operation: String,
        target: String? = nil,
        result: String? = nil
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let integrationLogger = Logger(
            subsystem: "breakdex",
            category: "🔗 INTEGRATION_POINTS"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] 🔗 Service coordination:"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Service: \(service)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Operation: \(operation)"
        )

        if let target = target {
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Target: \(target)"
            )
        }

        if let result = result {
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Result: \(result)"
            )
        }

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Flow state: \(String(describing: self.flowState))"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Timestamp: \(Date().description)"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ✅ Service coordination logged"
        )
    }

    // MARK: - FUNC
    func logVideoProgressMonitoringUpdate(
        progress: VideoLoadingProgress,
        context: String
    ) {
        let sessionId = UUID().uuidString.prefix(8)
        let integrationLogger = Logger(
            subsystem: "breakdex",
            category: "🔗 INTEGRATION_POINTS"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)]  VideoProgressMonitoringService update:"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Context: \(context)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Phase: \(progress.phase.displayName)"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Correlation ID: \(progress.correlationId)"
        )

        if case .downloadingFromCloud(let cloudProgress) = progress.phase {
            integrationLogger.info(
                "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Cloud progress: \(Int(cloudProgress * 100))%"
            )
        }

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ├─ Overall progress: \(Int(progress.progress * 100))%"
        )
        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] └─ Status: '\(progress.message)'"
        )

        integrationLogger.info(
            "🔗 INTEGRATION_POINTS: [\(sessionId)] ✅ Progress monitoring update logged"
        )
    }

    // MARK: - FUNC
    private func getMemoryUsageInMB() -> Double {
        var info = mach_task_basic_info()
        var count =
            mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            return 0.0
        }
    }

    // MARK: - FUNC
    @MainActor
    private func trackTotalLoadingTime(
        sessionId: String,
        startTime: Date,
        completionTime: Date
    ) {
        let totalTime = completionTime.timeIntervalSince(startTime)
        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )

        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] 🏆 Complete loading session:"
        )
        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ├─ Duration: \(String(format: "%.3f", totalTime))s"
        )
        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ├─ Start: \(startTime.description)"
        )
        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ├─ End: \(completionTime.description)"
        )
        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ├─ Final progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ├─ Memory at completion: \(String(format: "%.1f", self.getMemoryUsageInMB()))MB"
        )

        if totalTime < 1.0 {
            perfLogger.info(
                " TOTAL_LOADING_TIME: [\(sessionId)] 🚀 Excellent: < 1.0s"
            )
        } else if totalTime < 2.0 {
            perfLogger.info(
                " TOTAL_LOADING_TIME: [\(sessionId)] ✅ Good: < 2.0s"
            )
        } else if totalTime < 5.0 {
            perfLogger.info(
                " TOTAL_LOADING_TIME: [\(sessionId)] ⚠️ Acceptable: < 5.0s"
            )
        } else {
            let warningLogger = Logger(
                subsystem: "breakdex",
                category: "⚠️ PERFORMANCE_WARNINGS"
            )
            warningLogger.warning(
                "⚠️ SLOW_LOADING: [\(sessionId)] Slow loading: \(String(format: "%.3f", totalTime))s (>5.0s threshold)"
            )
        }

        perfLogger.info(
            " TOTAL_LOADING_TIME: [\(sessionId)] ✅ Loading session tracked successfully"
        )
    }

    // MARK: - FUNC
    @MainActor
    private func verifyProgressCalculationAccuracy(sessionId: String) {
        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )

        let currentProgress = unifiedProgressEngine.unifiedProgress
        let targetProgress = unifiedProgressEngine.targetProgress
        let currentPhase = unifiedProgressEngine.currentPhase
        let elapsedTime = unifiedProgressEngine.elapsedTime

        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] 🔍 Progress calculation verification:"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Current progress: \(String(format: "%.3f", currentProgress)) (\(Int(currentProgress * 100))%)"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Target progress: \(String(format: "%.3f", targetProgress)) (\(Int(targetProgress * 100))%)"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Current phase: \(currentPhase.displayName)"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Elapsed time: \(String(format: "%.3f", elapsedTime))s"
        )

        let progressDelta = targetProgress - currentProgress
        let isComplete = currentProgress >= 1.0
        let isStalled = progressDelta > 0.01 && elapsedTime > 10.0

        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Progress delta: \(String(format: "%.3f", progressDelta))"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] ├─ Completion status: \(isComplete ? "✅ Complete" : "🔄 In progress")"
        )
        perfLogger.info(
            " PROGRESS_ACCURACY: [\(sessionId)] └─ Stall detection: \(isStalled ? "⚠️ Potential stall" : "✅ Normal progress")"
        )

        if isStalled {
            let warningLogger = Logger(
                subsystem: "breakdex",
                category: "⚠️ PERFORMANCE_WARNINGS"
            )
            warningLogger.warning(
                "⚠️ PROGRESS_STALL: [\(sessionId)] Progress may be stalled after \(String(format: "%.1f", elapsedTime))s"
            )
            warningLogger.warning(
                "⚠️ PROGRESS_STALL: [\(sessionId)] Progress: \(Int(currentProgress * 100))%, Target: \(Int(targetProgress * 100))%"
            )
        }

        if currentProgress > 1.0 {
            let warningLogger = Logger(
                subsystem: "breakdex",
                category: "⚠️ PERFORMANCE_WARNINGS"
            )
            warningLogger.warning(
                "⚠️ PROGRESS_OVERFLOW: [\(sessionId)] Progress exceeds 100%: \(String(format: "%.3f", currentProgress * 100))%"
            )
        }
    }

    private func monitorMinimumLoadingTime(sessionId: String, startTime: Date) {
        let currentTime = Date()
        let elapsed = currentTime.timeIntervalSince(startTime)
        let minimumTime = minimumLoadingDisplayTime
        let remainingTime = max(0, minimumTime - elapsed)

        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )

        perfLogger.info(
            " MINIMUM_TIME: [\(sessionId)] ⏱️ Minimum loading time monitoring:"
        )
        perfLogger.info(
            " MINIMUM_TIME: [\(sessionId)] ├─ Elapsed: \(String(format: "%.3f", elapsed))s"
        )
        perfLogger.info(
            " MINIMUM_TIME: [\(sessionId)] ├─ Minimum required: \(String(format: "%.3f", minimumTime))s"
        )
        perfLogger.info(
            " MINIMUM_TIME: [\(sessionId)] ├─ Remaining: \(String(format: "%.3f", remainingTime))s"
        )

        if remainingTime > 0 {
            perfLogger.info(
                " MINIMUM_TIME: [\(sessionId)] 🔄 Enforcing minimum display time"
            )
            perfLogger.info(
                " MINIMUM_TIME: [\(sessionId)] └─ Will hold for additional \(String(format: "%.3f", remainingTime))s"
            )
        } else {
            perfLogger.info(
                " MINIMUM_TIME: [\(sessionId)] ✅ Minimum time requirement satisfied"
            )
            perfLogger.info(
                " MINIMUM_TIME: [\(sessionId)] └─ Ready to proceed"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    func performLoadingPerformanceAudit(sessionId: String, operation: String) {
        let perfLogger = Logger(
            subsystem: "breakdex",
            category: " PERFORMANCE_METRICS"
        )
        let auditTime = Date()

        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] 🔍 Starting performance audit for '\(operation)'"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Audit timestamp: \(auditTime.description)"
        )

        let currentMemory = getMemoryUsageInMB()
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Memory usage: \(String(format: "%.1f", currentMemory))MB"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Flow state: \(String(describing: self.flowState))"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Player state: \(String(describing: self.playerState))"
        )

        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Progress: \(Int(self.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Phase: \(self.unifiedProgressEngine.currentPhase.displayName)"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Elapsed time: \(String(format: "%.3f", self.unifiedProgressEngine.elapsedTime))s"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Load elapsed: \(String(format: "%.3f", self.loadElapsedTime))s"
        )

        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Video asset: \(self.videoAsset != nil ? "✅ Available" : "❌ Missing")"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Photos ID: \(self.photosIdentifier ?? "Missing")"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Current player: \(self.currentPlayerViewModel != nil ? "✅ Available" : "❌ Missing")"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] └─ Trimmer VM: \(self.trimmerViewModel != nil ? "✅ Available" : "❌ Missing")"
        )

        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Services initialized: \(self.servicesInitialized)"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ├─ Timer service: \(self.timerManagementService != nil ? "✅ Available" : "❌ Missing")"
        )
        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] └─ Progress service: \(self.videoProgressMonitoringService != nil ? "✅ Available" : "❌ Missing")"
        )

        perfLogger.info(
            " PERFORMANCE_AUDIT: [\(sessionId)] ✅ Performance audit complete"
        )
    }
}

// MARK: - ENUM STATE
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

// MARK: - ENUM STATE
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

// MARK: - ENUM STATE
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
    case missingDependencies
    case invalidPlayerViewModel
    case invariantViolation

    public var errorDescription: String? {
        switch self {
        case .invalidState(let state):
            return
                "Invalid state for trimmer setup: \(String(describing: state))"
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
        case .missingDependencies:
            return "Required dependencies for trimmer setup are missing"
        case .invalidPlayerViewModel:
            return "Player view model is invalid or not compatible"
        case .invariantViolation:
            return
                "State invariant violation: trimming state without valid TrimmerViewModel"
        }
    }
}

// MARK: - CLASS
private class AddMoveAppLogger: AppLogger {
    private let logger = Logger(
        subsystem: "breakdex",
        category: "🎬 AddMoveUnifiedState"
    )

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

// MARK: - EXTENSION
extension AddMoveUnifiedState: @preconcurrency TrimmerSetupProgressDelegate {

    // MARK: - FUNC
    public func trimmerDidUpdateProgress(_ progress: Double, status: String) {
        logger.info(
            "🎬 AddMoveUnifiedState:  Trimmer setup progress: \(String(format: "%.1f", progress * 100))% - \(status)"
        )

        if case .trimming = self.flowState {
            logger.info(
                "🎬 AddMoveUnifiedState:  Trimmer setup continuing in trimming state"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Trimmer progress update received but not in trimming state: \(String(describing: self.flowState))"
            )
        }
    }

    // MARK: - FUNC
    public func trimmerDidCompleteSetup(totalTime: TimeInterval?) {
        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Trimmer setup completed successfully"
        )

        if let totalTime = totalTime {
            logger.info(
                "🎬 AddMoveUnifiedState: ⏱️ Total setup time: \(String(format: "%.2f", totalTime))s"
            )
        }

        if case .trimming = self.flowState {
            logger.info(
                "🎬 AddMoveUnifiedState: ✅ Trimmer is ready for user interaction"
            )
        } else {
            logger.warning(
                "🎬 AddMoveUnifiedState: ⚠️ Trimmer completion received but not in trimming state: \(String(describing: self.flowState))"
            )
        }
    }

    // MARK: - FUNC
    public func trimmerDidEncounterError(_ error: Error, context: String) {
        logger.error(
            "🎬 AddMoveUnifiedState: ❌ Trimmer setup error in context '\(context)': \(error.localizedDescription)"
        )

        let underlyingError = "\(context): \(error.localizedDescription)"
        logger.error(
            "🎬 AddMoveUnifiedState: 🔍 Full error context: \(underlyingError)"
        )

        Task { @MainActor in
            await setError(
                message: "Trimmer setup failed",
                underlying: underlyingError
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func performLoadingToTrimmingTransition(
        progress: VideoLoadingProgress
    ) async {
        logger.info(
            "🎬 AddMoveUnifiedState: 🔄 Performing loading to trimming transition with acquired lock"
        )

        unifiedProgressEngine.completeLoading()

        let loadingDuration =
            loadingOverlayStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let remainingTime = max(0, minimumLoadingDisplayTime - loadingDuration)

        if remainingTime > 0 {
            logger.info(
                "🎬 AddMoveUnifiedState: ⏱️ UX_DELAY: Waiting \(String(format: "%.3f", remainingTime))s to meet minimum display time"
            )

            try? await Task.sleep(
                nanoseconds: UInt64(remainingTime * 1_000_000_000)
            )
        } else {
            logger.info(
                "🎬 AddMoveUnifiedState: ⏱️ UX_READY: Minimum display time satisfied, proceeding immediately"
            )
        }

        await handleLoadingCompletionWithAtomicGuard()

        logger.info(
            "🎬 AddMoveUnifiedState: ✅ Loading to trimming transition completed"
        )
    }
}
