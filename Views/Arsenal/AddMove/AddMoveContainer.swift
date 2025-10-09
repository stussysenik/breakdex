import AVKit
import Combine
import CoreData
import Foundation
import OSLog
import Photos
import PhotosUI
import SwiftUI

// AddMoveContainer.swift - main UI for "Select Video"

private let logger = Logger(
    subsystem: "com.breakingflashcards",
    category: "AddMoveContainer"
)

// MARK: - CLASS
struct AddMoveContainer: View {
    // MARK: - VAR PROPERTIES
    @Environment(\.managedObjectContext) private var viewContext
    @Binding private var selectedTab: TabSelection
    @ObservedObject private var unifiedState: AddMoveUnifiedState

    private var onSaveSuccess: ((Move) -> Void)?

    init(
        selectedTab: Binding<TabSelection>,
        unifiedState: AddMoveUnifiedState,
        onSaveSuccess: ((Move) -> Void)? = nil
    ) {
        logger.info(
            "🎬 CONTAINER: 🎯 CRITICAL_FIX - AddMoveContainer initialized with persistent state from AddMoveStateOwner"
        )

        let stateIdString = String(describing: ObjectIdentifier(unifiedState))
        logger.info("🎬 CONTAINER: 🎯 PERSISTENT_STATE_ID: \(stateIdString)")
        logger.info(
            "🎬 CONTAINER:  Container now receives state as @ObservedObject (no ownership)"
        )

        _selectedTab = selectedTab
        _unifiedState = ObservedObject(wrappedValue: unifiedState)
        self.onSaveSuccess = onSaveSuccess

        logger.info(
            "🎬 CONTAINER: ✅ STATE_LIFECYCLE_FIXED - Container no longer owns state object"
        )
    }

    // MARK: - BODY
    var body: some View {
        Group {
            if isValidContainerState() {
                mainContentWithModifiers
            } else {
                renderContainerFallbackUI()
            }
        }
    }

    // MARK: - VAR
    private var mainContentWithModifiers: some View {
        mainContent
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChange(of: unifiedState.flowState) { oldState, newState in
                handleStateChange(from: oldState, to: newState)
            }
    }

    // MARK: - FUNC
    private func handleViewAppear() {
        logger.info(
            "🎬 CONTAINER: View appeared with state: \(String(describing: unifiedState.flowState))"
        )
        logState("container_appear", flowState: unifiedState.flowState)

        unifiedState.onSaveSuccess = { savedMove in
            logger.info(
                "🎬 CONTAINER: 🚀 Save completion handler called with saved move"
            )

            if let move = savedMove as? Move {
                self.onSaveSuccess?(move)
            }
        }

        unifiedState.returnToTrimming = {
            logger.info("🎬 CONTAINER: 🔙 Return to trimming closure triggered")
            handleReturnToTrimming()
        }

        logger.info("🎬 CONTAINER: ✅ Return to trimming closure configured")
    }

    private func handleViewDisappear() {
        logger.info(
            "🎬 CONTAINER: View disappeared from state: \(String(describing: unifiedState.flowState))"
        )

        let currentState = unifiedState.flowState
        let shouldCleanUp: Bool = {
            switch currentState {
            case .success:

                logger.info(
                    "🎬 CONTAINER: Success state detected - postponing cleanup to allow navigation"
                )
                return false
            case .error:
                return true
            default:
                return false
            }
        }()

        if shouldCleanUp {
            logger.info(
                "🎬 CONTAINER: Workflow completed, cleaning up unified state"
            )
            unifiedState.reset()
        }
    }

    // MARK: - FUNC
    private func handleStateChange(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logger.info(
            "🎬 CONTAINER: Flow state change observed - From: \(String(describing: oldState)) To: \(String(describing: newState))"
        )

        switch (oldState, newState) {
        case (.loadingVideo, .trimming):
            logger.info(
                "🎬 CONTAINER: 🔄 Simplified transition: loadingVideo → trimming"
            )
            logger.info(
                "🎬 CONTAINER:  Memory usage at trimming entry: \(getMemoryUsage())"
            )

        case (.trimming, .loadingTrimmedAsset):
            logger.info(
                "🎬 CONTAINER: ✅ Asset preparation: trimming → loadingTrimmedAsset"
            )

        case (.loadingTrimmedAsset, .naming):
            logger.info(
                "🎬 CONTAINER: ✅ Asset ready: loadingTrimmedAsset → naming"
            )

        case (.trimming, .naming):
            logger.info("🎬 CONTAINER: ✅ Trimming complete: trimming → naming")

        case (.naming, .saving):
            logger.info("🎬 CONTAINER: ✅ Naming complete: naming → saving")

        case (.saving, .success):
            logger.info("🎬 CONTAINER: ✅ Save complete: saving → success")

        default:
            logger.info(
                "🎬 CONTAINER: 📝 Standard transition: \(String(describing: oldState)) → \(String(describing: newState))"
            )
        }

        validateStateInvariants(from: oldState, to: newState)

        traceNavigationFlow(from: oldState, to: newState)

    }

    // MARK: - FUNC
    private func validateStateInvariants(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logger.info(
            "🎬 CONTAINER: 🔍 Validating state invariants for transition: \(String(describing: oldState)) → \(String(describing: newState))"
        )

        var invariantViolations: [String] = []

        if case .trimming = newState, unifiedState.videoAsset == nil {
            invariantViolations.append("Video asset missing in trimming state")
        }

        if case .loadingTrimmedAsset = newState,
            unifiedState.currentPlayerViewModel == nil
        {
            invariantViolations.append(
                "Player view model missing in loadingTrimmedAsset state"
            )
        }

        let loadTimerRunning = unifiedState.loadElapsedTime > 0
        if case .trimming = newState, loadTimerRunning {
            invariantViolations.append(
                "Load timer still running in trimming state"
            )
        }

        if case .success = newState, unifiedState.moveName.isEmpty {
            invariantViolations.append("Move name empty in success state")
        }

        if invariantViolations.isEmpty {
            logger.info("🎬 CONTAINER: ✅ All state invariants maintained")
        } else {
            logger.error("🎬 CONTAINER: ❌ State invariant violations detected:")
            for violation in invariantViolations {
                logger.error("🎬 CONTAINER:   - \(violation)")
            }
        }

        logInvariantMetrics(state: newState)
    }

    // MARK: - FUNC
    private func logInvariantMetrics(state: AddMoveFlowState) {
        let memoryUsage = getMemoryUsage()
        let loadElapsed = unifiedState.loadElapsedTime
        let saveElapsed = unifiedState.saveElapsedTime

        let metrics: [String: String] = [
            "state": String(describing: state),
            "memory_usage": memoryUsage,
            "load_elapsed": String(format: "%.2f", loadElapsed),
            "save_elapsed": String(format: "%.2f", saveElapsed),
            "video_asset_available": unifiedState.videoAsset != nil
                ? "true" : "false",
            "player_available": unifiedState.currentPlayerViewModel != nil
                ? "true" : "false",
        ]

        logger.info("🎬 CONTAINER:  Invariant metrics - \(metrics)")
    }

    // MARK: - FUNC
    private func traceNavigationFlow(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        logger.info(
            "🎬 CONTAINER: 🧭 Tracing navigation flow: \(String(describing: oldState)) → \(String(describing: newState))"
        )

        switch (oldState, newState) {
        case (.ready, .loadingVideo):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: User selected video"
            )

        case (.loadingVideo, .trimming):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: Video loading completed - entering trimming"
            )

        case (.trimming, .loadingTrimmedAsset):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: User completed trimming"
            )

        case (.trimming, .naming):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: User completed trimming"
            )

        case (.naming, .saving):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: User initiated save"
            )

        case (.saving, .success):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: Save completed - ready for navigation to MoveDetailView"
            )

        case (.success, _):
            logger.info(
                "🎬 CONTAINER: 🎯 Navigation milestone: Exiting success state - navigation flow complete"
            )

        default:
            logger.info(
                "🎬 CONTAINER: 📝 Navigation step: \(String(describing: oldState)) → \(String(describing: newState))"
            )
        }

        traceFunctorCompositionPath(from: oldState, to: newState)
    }

    // MARK: - FUNC
    private func traceFunctorCompositionPath(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState
    ) {
        let path = FunctorPathAnalyzer.analyzePath(from: oldState, to: newState)
        logger.info(
            "🎬 CONTAINER: 📐 Functor composition path: \(path.description)"
        )

        if path.hasNaturalTransformations {
            logger.info(
                "🎬 CONTAINER: 🌟 Path contains natural transformations: \(path.naturalTransformations.joined(separator: " → "))"
            )
        }

        if path.isReversible {
            logger.info(
                "🎬 CONTAINER: 🔄 Path is reversible - adjoint functors available"
            )
        }
    }

    private var mainContent: some View {
        AnyView(
            VStack(spacing: 0) {
                switch unifiedState.flowState {
                case .ready:

                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering ready state - AddMoveSelectClipViewUnified"
                    )
                    AddMoveSelectClipViewUnified(unifiedState: unifiedState)

                case .loadingVideo:
                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering loadingVideo state - LoadingOverlayView with unified state (progress decoupled)"
                    )
                    LoadingOverlayView(unifiedState: unifiedState)

                case .trimming:

                    let _ = logger.info(
                        "🎬 CONTAINER: 🚀 PERFORMANCE_OPTIMIZATION - Creating FeatureRichTrimmerView with lazy ViewModel initialization"
                    )

                    FeatureRichTrimmerView(unifiedState: unifiedState)

                        .id(unifiedState.photosIdentifier ?? UUID().uuidString)
                        .onAppear {

                            let _ = logger.info(
                                "🎬 CONTAINER: ✅ LAZY_INITIALIZATION: FeatureRichTrimmerView appeared - ViewModel will be created lazily"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: 🎯 PERFORMANCE_OPTIMIZATION: Heavy initialization deferred to prevent CPU/memory spikes"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: 🏗️ LAZY_ARCHITECTURE: TrimmerViewModel creation moved to FeatureRichTrimmerView.onAppear"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ┌─ Lazy Initialization Details"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ photos_identifier: \(unifiedState.photosIdentifier ?? "missing")"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ video_asset: \(unifiedState.videoAsset != nil ? "available" : "missing")"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ player_viewmodel: \(unifiedState.currentPlayerViewModel != nil ? "available" : "missing")"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ trim_start_time: \(String(format: "%.3f", unifiedState.trimStartTime))s"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ trim_end_time: \(String(format: "%.3f", unifiedState.trimEndTime))s"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ intrinsic_rotation: \(unifiedState.intrinsicAssetRotation * 90)°"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: ├─ user_rotation: \(unifiedState.userAppliedRotation * 90)°"
                            )
                            let _ = logger.info(
                                "🎬 CONTAINER: └─ performance_target: <250ms transition, <90% CPU usage"
                            )
                        }

                case .loadingTrimmedAsset(let progress):
                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering loadingTrimmedAsset state - LoadingView with progress: \(String(format: "%.1f", progress.value * 100))%, status: \(progress.message)"
                    )
                    LoadingView(
                        progress: progress.value,
                        status: progress.message,
                        unifiedState: unifiedState
                    )

                case .naming:
                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering naming state - NameMoveViewUnified"
                    )
                    NameMoveViewUnified(unifiedState: unifiedState)

                case .saving:
                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering saving state - SavingViewWithProgress"
                    )
                    SavingViewWithProgress(unifiedState: unifiedState)

                case .success(let message):
                    let _ = logger.info(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering success state - SuccessView with message: \(message)"
                    )
                    SuccessView(message: message) {
                        Task {
                            let _ = logger.info(
                                "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Success view completion callback triggered"
                            )
                            unifiedState.reset()
                        }
                    }

                case .error(let message, let underlying):
                    let _ = logger.error(
                        "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Rendering error state - ErrorView with message: \(message), underlying: \(underlying ?? "none")"
                    )
                    ErrorView(
                        message: message,
                        onRetry: {
                            let _ = logger.info(
                                "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Error retry callback triggered"
                            )
                            Task {
                                await unifiedState.clearError()
                            }
                        },
                        onCancel: {
                            let _ = logger.info(
                                "🎬 CONTAINER: 🏗️ TYPE_ERASURE: Error cancel callback triggered"
                            )
                            Task {
                                unifiedState.reset()
                            }
                            selectedTab = .arsenal
                        }
                    )
                }
            }

            .onAppear {
                let _ = logger.info(
                    "🎬 CONTAINER: 🏗️ TYPE_ERASURE: mainContent AnyView appeared successfully - type erasure active"
                )
            }
        )
    }

    // MARK: - FUNC
    private func isValidContainerState() -> Bool {
        let stateValid = isValidFlowState(unifiedState.flowState)
        let tabValid = isTabValid()
        return stateValid && tabValid
    }

    // MARK: - FUNC
    private func isValidFlowState(_ state: AddMoveFlowState) -> Bool {
        return true
    }

    // MARK: - FUNC
    private func isTabValid() -> Bool {
        return selectedTab == .add
    }

    // MARK: - FUNC
    @MainActor
    private func handleReturnToTrimming() {
        logger.info(
            "🎬 CONTAINER: 🔙 Handling return to trimming from naming state"
        )
        logger.info(
            "🎬 CONTAINER:  Current state: \(String(describing: unifiedState.flowState))"
        )

        logCurrentStateDetails("BACK_BUTTON_PRESSED")

        guard case .naming = unifiedState.flowState else {
            logger.warning(
                "🎬 CONTAINER: ⚠️ Cannot return to trimming - not in naming state: \(String(describing: unifiedState.flowState))"
            )
            return
        }

        guard validateTrimmingReconstructionData() else {
            logger.error(
                "🎬 CONTAINER: ❌ Cannot return to trimming - missing required data"
            )
            Task {
                await unifiedState.setError(
                    message: "Cannot return to trimming",
                    underlying: "Missing video data"
                )
            }
            return
        }

        logger.info(
            "🎬 CONTAINER: ✅ Validation passed - beginning trimming reconstruction"
        )

        Task {
            await performReturnToTrimmingTransition()
        }
    }

    // MARK: - FUNC
    @MainActor
    private func validateTrimmingReconstructionData() -> Bool {
        logger.info("🎬 CONTAINER: 🔍 Validating trimming reconstruction data")

        if unifiedState.canRestoreTrimmingState() {
            logger.info(
                "🎬 CONTAINER: 🔄 Preserved trimming state available - attempting restoration"
            )

            if unifiedState.attemptTrimmingStateRestoration() {
                logger.info(
                    "🎬 CONTAINER: ✅ Trimming state restored from preserved data"
                )
                logCurrentStateDetails("AFTER_PRESERVED_RESTORATION")
                return true
            } else {
                logger.warning(
                    "🎬 CONTAINER: ⚠️ Failed to restore trimming state from preserved data"
                )
                logCurrentStateDetails("PRESERVED_RESTORATION_FAILED")
            }
        } else {
            logger.info(
                "🎬 CONTAINER: 📝 No preserved trimming state available - validating current data"
            )
        }

        var validationResults: [String: Bool] = [:]

        if unifiedState.videoAsset != nil {
            validationResults["videoAsset"] = true
            logger.info("🎬 CONTAINER: ✅ Video asset available")
        } else {
            validationResults["videoAsset"] = false
            logger.error("🎬 CONTAINER: ❌ Video asset missing")
        }

        if let photosId = unifiedState.photosIdentifier, !photosId.isEmpty {
            validationResults["photosIdentifier"] = true
            logger.info(
                "🎬 CONTAINER: ✅ Photos identifier available: \(photosId)"
            )
        } else {
            validationResults["photosIdentifier"] = false
            logger.error("🎬 CONTAINER: ❌ Photos identifier missing")
        }

        if unifiedState.currentPlayerViewModel != nil {
            validationResults["currentPlayerViewModel"] = true
            logger.info("🎬 CONTAINER: ✅ Current player view model available")
        } else {
            validationResults["currentPlayerViewModel"] = false
            logger.error("🎬 CONTAINER: ❌ Current player view model missing")
        }

        if unifiedState.trimStartTime >= 0
            && unifiedState.trimEndTime > unifiedState.trimStartTime
        {
            validationResults["trimTimeValues"] = true
            logger.info(
                "🎬 CONTAINER: ✅ Trim time values valid: \(String(format: "%.2f", unifiedState.trimStartTime))s - \(String(format: "%.2f", unifiedState.trimEndTime))s"
            )
        } else {
            validationResults["trimTimeValues"] = false
            logger.error(
                "🎬 CONTAINER: ❌ Invalid trim time values: start=\(unifiedState.trimStartTime), end=\(unifiedState.trimEndTime)"
            )
        }

        let allValid = validationResults.values.allSatisfy { $0 }
        logger.info(
            "🎬 CONTAINER:  Trimming reconstruction validation result: \(allValid ? "✅ PASSED" : "❌ FAILED")"
        )

        return allValid
    }

    // MARK: - FUNC
    @MainActor
    private func performReturnToTrimmingTransition() async {
        logger.info("🎬 CONTAINER: 🚀 Starting return to trimming transition")
        let transitionStartTime = Date()

        logger.info(
            "🎬 CONTAINER: 🔄 Delegating to FlowStateManager for rollback"
        )
        await unifiedState.flowStateManager?.rollbackToTrimming()

        let transitionTime = Date().timeIntervalSince(transitionStartTime)
        logger.info(
            "🎬 CONTAINER: ✅ Return to trimming transition completed in \(String(format: "%.3f", transitionTime))s"
        )

        if case .trimming = unifiedState.flowState {
            logger.info(
                "🎬 CONTAINER: ✅ Successfully returned to trimming state"
            )

            logTrimmingStateReconstruction()
        } else {
            logger.error(
                "🎬 CONTAINER: ❌ Failed to transition to trimming state - current: \(String(describing: unifiedState.flowState))"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func cleanupNamingState() async {
        logger.info("🎬 CONTAINER: 🧹 Cleaning up naming state")

        unifiedState.moveName = ""
        logger.info("🎬 CONTAINER: 🧹 Move name cleared")

        unifiedState.saveElapsedTime = 0.0
        unifiedState.saveProgress = 0.0
        logger.info("🎬 CONTAINER: 🧹 Save timers reset")

        unifiedState.saveReadiness = nil
        logger.info("🎬 CONTAINER: 🧹 Save readiness validation cleared")
    }

    // MARK: - FUNC
    @MainActor
    private func reconstructTrimmerIfNeeded() async {
        logger.info(
            "🎬 CONTAINER: 🔧 Checking if trimmer reconstruction is needed"
        )

        if let existingTrimmer = unifiedState.trimmerViewModel
            as? TrimmerViewModel
        {
            logger.info(
                "🎬 CONTAINER: ✅ Existing trimmer view model found - validating"
            )

            if await validateTrimmerViewModel(existingTrimmer) {
                logger.info(
                    "🎬 CONTAINER: ✅ Existing trimmer view model is valid - updating time values"
                )

                let duration = try? await unifiedState.videoAsset?.load(
                    .duration
                )
                let totalDuration = duration?.seconds ?? 0.0
                let startTime = CMTime(
                    seconds: unifiedState.trimStartTime,
                    preferredTimescale: 600
                )
                let endTime = CMTime(
                    seconds: unifiedState.trimEndTime > 0
                        ? unifiedState.trimEndTime : totalDuration,
                    preferredTimescale: 600
                )

                existingTrimmer.startTime = startTime
                existingTrimmer.endTime = endTime

                logger.info(
                    "🎬 CONTAINER: ✅ Trimmer time values updated: \(startTime.seconds)s - \(endTime.seconds)s"
                )
            } else {
                logger.warning(
                    "🎬 CONTAINER: ⚠️ Existing trimmer view model invalid - recreating"
                )
                await createNewTrimmerViewModel()
            }
        } else {
            logger.info(
                "🎬 CONTAINER: 📝 No existing trimmer view model - creating new one"
            )
            await createNewTrimmerViewModel()
        }
    }

    // MARK: - FUNC
    @MainActor
    private func validateTrimmerViewModel(_ trimmerVM: TrimmerViewModel) async
        -> Bool
    {
        logger.info("🎬 CONTAINER: 🔍 Validating trimmer view model")

        do {
            let trimmerAssetDuration = try await trimmerVM.asset.load(.duration)
            let currentAssetDuration =
                try await unifiedState.videoAsset?.load(.duration)
                ?? CMTime.zero

            let durationMatch =
                abs(trimmerAssetDuration.seconds - currentAssetDuration.seconds)
                < 0.1
            logger.info(
                "🎬 CONTAINER:  Asset duration comparison - Trimmer: \(String(format: "%.2f", trimmerAssetDuration.seconds))s, Current: \(String(format: "%.2f", currentAssetDuration.seconds))s"
            )

            if durationMatch {
                logger.info("🎬 CONTAINER: ✅ Trimmer asset validation passed")
                return true
            } else {
                logger.warning(
                    "🎬 CONTAINER: ⚠️ Trimmer asset duration mismatch - needs reconstruction"
                )
                return false
            }
        } catch {
            logger.error(
                "🎬 CONTAINER: ❌ Trimmer validation failed: \(error.localizedDescription)"
            )
            return false
        }
    }

    // MARK: - FUNC
    @MainActor
    private func createNewTrimmerViewModel() async {
        logger.info("🎬 CONTAINER: 🔨 Creating new trimmer view model")

        guard let videoAsset = unifiedState.videoAsset,
            let photosIdentifier = unifiedState.photosIdentifier,
            let playerViewModel = unifiedState.currentPlayerViewModel
                as? UnifiedVideoPlayerViewModel
        else {
            logger.error(
                "🎬 CONTAINER: ❌ Cannot create trimmer - missing required dependencies"
            )
            return
        }

        do {

            let duration = try await videoAsset.load(.duration).seconds
            let startTime = CMTime(
                seconds: unifiedState.trimStartTime >= 0
                    ? unifiedState.trimStartTime : 0,
                preferredTimescale: 600
            )
            let endTime = CMTime(
                seconds: unifiedState.trimEndTime > 0
                    ? unifiedState.trimEndTime : duration,
                preferredTimescale: 600
            )

            let newTrimmerVM = TrimmerViewModel(
                asset: videoAsset,
                photosIdentifier: photosIdentifier,
                initialIntrinsicRotation: unifiedState.intrinsicAssetRotation,
                initialUserRotation: unifiedState.userAppliedRotation,
                initialStartTime: startTime,
                initialEndTime: endTime,
                playerViewModel: playerViewModel
            )

            newTrimmerVM.progressDelegate = unifiedState

            unifiedState.trimmerViewModel = newTrimmerVM

            logger.info(
                "🎬 CONTAINER: ✅ Created new TrimmerViewModel with rollback integrity fix - start_time: \(startTime.seconds)s, end_time: \(endTime.seconds)s, rotation: \(unifiedState.totalRotationQuarterTurns * 90)°, rollback_integrity_fix: atomic_initialization_with_restored_times"
            )

            logger.info(
                "🎬 CONTAINER: ✅ New trimmer view model created and configured"
            )
            logger.info(
                "🎬 CONTAINER:  Trim range set: \(startTime.seconds)s - \(endTime.seconds)s"
            )

        } catch {
            logger.error(
                "🎬 CONTAINER: ❌ Failed to create new trimmer view model: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - FUNC
    @MainActor
    private func logTrimmingStateReconstruction() {
        logger.info("🎬 CONTAINER:  TRIMMING STATE RECONSTRUCTION SUMMARY")
        logger.info("🎬 CONTAINER:  ======================================")
        logger.info(
            "🎬 CONTAINER:  Flow State: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 CONTAINER:  Video Asset: \(unifiedState.videoAsset != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 CONTAINER:  Photos ID: \(unifiedState.photosIdentifier ?? "❌ Missing")"
        )
        logger.info(
            "🎬 CONTAINER:  Player VM: \(unifiedState.currentPlayerViewModel != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 CONTAINER:  Trimmer VM: \(unifiedState.trimmerViewModel != nil ? "✅ Available" : "❌ Missing")"
        )
        logger.info(
            "🎬 CONTAINER:  Trim Range: \(String(format: "%.2f", unifiedState.trimStartTime))s - \(String(format: "%.2f", unifiedState.trimEndTime))s"
        )
        logger.info(
            "🎬 CONTAINER:  Rotation: \(unifiedState.totalRotationQuarterTurns * 90)°"
        )
        logger.info(
            "🎬 CONTAINER:  Move Name: '\(unifiedState.moveName.isEmpty ? "Empty" : unifiedState.moveName)'"
        )
        logger.info("🎬 CONTAINER:  Timestamp: \(Date())")
        logger.info("🎬 CONTAINER:  ======================================")
        logger.info("🎬 CONTAINER:  TRIMMING STATE RECONSTRUCTION COMPLETE")
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
    private func logCurrentStateDetails(_ context: String) {
        logger.info("🎬 CONTAINER:  DIAGNOSTIC STATE LOG [\(context)]")
        logger.info("🎬 CONTAINER:  ======================================")

        logger.info(
            "🎬 CONTAINER:  Flow State: \(String(describing: unifiedState.flowState))"
        )
        logger.info(
            "🎬 CONTAINER:  Player State: \(String(describing: unifiedState.playerState))"
        )

        if let asset = unifiedState.videoAsset {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    logger.info(
                        "🎬 CONTAINER:  Video Asset: ✅ Available - Duration: \(String(format: "%.2f", duration.seconds))s"
                    )
                } catch {
                    logger.info(
                        "🎬 CONTAINER:  Video Asset: ✅ Available - Duration: Load failed (\(error.localizedDescription))"
                    )
                }
            }
        } else {
            logger.info("🎬 CONTAINER:  Video Asset: ❌ Missing")
        }

        logger.info(
            "🎬 CONTAINER:  Photos ID: \(unifiedState.photosIdentifier ?? "❌ Missing")"
        )

        if let playerVM = unifiedState.currentPlayerViewModel {
            logger.info(
                "🎬 CONTAINER:  Player VM: ✅ Available - Type: \(type(of: playerVM))"
            )

            if let unifiedPlayerVM = playerVM as? UnifiedVideoPlayerViewModel {
                logger.info(
                    "🎬 CONTAINER:  Unified Player: Ready: \(unifiedPlayerVM.isPlayerReady), Has Player: \(unifiedPlayerVM.avPlayer != nil)"
                )
            }
        } else {
            logger.info("🎬 CONTAINER:  Player VM: ❌ Missing")
        }

        if let trimmerVM = unifiedState.trimmerViewModel {
            logger.info(
                "🎬 CONTAINER:  Trimmer VM: ✅ Available - Type: \(type(of: trimmerVM))"
            )
        } else {
            logger.info("🎬 CONTAINER:  Trimmer VM: ❌ Missing")
        }

        logger.info(
            "🎬 CONTAINER:  Trim Range: \(String(format: "%.2f", unifiedState.trimStartTime))s - \(String(format: "%.2f", unifiedState.trimEndTime))s"
        )
        logger.info(
            "🎬 CONTAINER:  Rotation: \(unifiedState.totalRotationQuarterTurns * 90)°"
        )

        logger.info(
            "🎬 CONTAINER:  Move Name: '\(unifiedState.moveName.isEmpty ? "Empty" : unifiedState.moveName)'"
        )

        logger.info(
            "🎬 CONTAINER:  Load Progress: \(String(format: "%.1f", unifiedState.unifiedProgressEngine.unifiedProgress * 100))%"
        )
        logger.info(
            "🎬 CONTAINER:  Load Timer: \(String(format: "%.2f", unifiedState.loadElapsedTime))s"
        )
        logger.info(
            "🎬 CONTAINER:  Save Timer: \(String(format: "%.2f", unifiedState.saveElapsedTime))s"
        )

        logger.info("🎬 CONTAINER:  Memory: \(getMemoryUsage())")

        logger.info("🎬 CONTAINER:  Timestamp: \(Date())")
        logger.info("🎬 CONTAINER:  ======================================")
    }

    // MARK: - FUNC
    private func getMemoryUsage() -> String {
        let memoryInfo = ProcessInfo.processInfo
        let totalGB = memoryInfo.physicalMemory / (1024 * 1024 * 1024)
        return "\(totalGB)GB"
    }

    // MARK: - FUNC
    private func renderContainerFallbackUI() -> some View {
        VStack {
            Spacer()
            Text("Unable to load video interface")
                .font(.headline)
                .foregroundColor(.white)
            Text("Please restart the app")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Restart") {
                unifiedState.reset()
                selectedTab = .add
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}
// MARK: STRUCT
struct PreviewToTrimTransitionView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var hasTriggeredSetup = false

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "PreviewToTrimTransition"
    )

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)

            VStack(spacing: 8) {
                Text("Preparing Trimmer")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Setting up video trimming tools...")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            logger.info(
                "🎬 PREVIEW_TO_TRIM: 🚀 Transition view appeared - checking if setup needed"
            )

            if !hasTriggeredSetup {
                hasTriggeredSetup = true
                logger.info("🎬 PREVIEW_TO_TRIM: 📡 Triggering trimmer setup")

                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await unifiedState.setupTrimmerAfterPreview()
                }
            } else {
                logger.info(
                    "🎬 PREVIEW_TO_TRIM: ℹ️ Setup already triggered, skipping"
                )
            }
        }
        .onDisappear {
            logger.info("🎬 PREVIEW_TO_TRIM: Transition view disappeared")

            hasTriggeredSetup = false
        }
        .onChange(of: unifiedState.flowState) { _, newState in
            logger.info(
                "🎬 CONTAINER: State changed to \(String(describing: newState))"
            )

            if case .trimming = newState {
                hasTriggeredSetup = false
            }
        }
    }
}

// MARK: - STRUCT
struct AddMoveSelectClipViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosUI.PhotosPickerItem?

    var body: some View {
        VStack {
            Spacer()

            Button("Select Video") {
                showPhotosPicker = true
            }
            .font(.custom("IBMPlexMono-Regular", size: 18))
            .buttonStyle(.appAccent(size: .large))

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $tempSelection,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: tempSelection) { _, newItem in
            if let newItem = newItem {
                let customItem = PhotosPickerItem(item: newItem)
                unifiedState.didSelectVideo(customItem)
                tempSelection = nil
            }
        }
    }
}

// MARK: - STRUCT
struct LoadingView: View {
    let progress: Double
    let status: String
    @ObservedObject var unifiedState: AddMoveUnifiedState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(status)
                .progressViewStyle(.circular)

            Text("\(Int(progress * 100))%")
                .font(.ibmPlexMono(size: 14, weight: .regular))
                .foregroundColor(.textSecondary)

            VStack(spacing: 6) {

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.textSecondary.opacity(0.8))
                    Text(formatTime(unifiedState.loadElapsedTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.textSecondary.opacity(0.8))
                }

                if !unifiedState.formattedFileSize.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundColor(.textSecondary.opacity(0.8))
                        Text(unifiedState.formattedFileSize)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.textSecondary.opacity(0.8))
                    }
                }
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    // MARK: - FUNC
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - STRUCT
struct SavingViewWithProgress: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "SavingViewWithProgress"
    )

    var body: some View {

        AnyView(
            VStack {
                Spacer()

                savingStatusView()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                            .shadow(
                                color: .black.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    )

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .onAppear {

                logger.info("⏱️ SAVING_VIEW: Saving view appeared")
                logger.info(
                    "🎬 SAVING_VIEW: Save operation started - timer now managed by unified state"
                )
            }
            .onDisappear {
                logger.info("⏱️ SAVING_VIEW: Saving view disappeared")
                logger.info(
                    "🎬 SAVING_VIEW: Save operation completed - timer managed by unified state"
                )
            }
        )
    }
    // MARK: - FUNC
    private func savingStatusView() -> some View {
        VStack(spacing: 20) {
            headerView()
            progressView()
        }
    }
    // MARK: - FUNC
    private func headerView() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                    .frame(width: 24, height: 24)

                Text("Saving Move...")
                    .font(.headline)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))

                Text(formatTime(unifiedState.saveElapsedTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    // MARK: - FUNC
    private func progressView() -> some View {

        AnyView(
            Group {
                if unifiedState.saveProgress > 0 {
                    VStack(spacing: 8) {
                        ProgressView(
                            value: unifiedState.saveProgress,
                            total: 1.0
                        )
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                        .tint(.blue)
                        HStack(spacing: 4) {
                            Text("\(Int(unifiedState.saveProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Text("Processing video...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Text("Processing your video and metadata...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
            }
        )
    }

    // MARK: - FUNC
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - STRUCT
struct SavingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Saving Move...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - STRUCT
struct SuccessView: View {
    let message: String
    let onDone: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Done") {
                onDone()
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - STRUCT
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            HStack {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.appPrimary(size: .medium))

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.appSecondary(size: .medium))
            }
            .padding(.top)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - SWIFT UI PREVIEW
#Preview {
    // MARK: - STRUCT
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add
        @StateObject private var unifiedState: AddMoveUnifiedState = {
            let appContainer = AppContainer.shared
            return AddMoveUnifiedState(
                unifiedPlayerManager: UnifiedPlayerManager(),
                modernVideoLoadingService: appContainer
                    .modernVideoLoadingService,
                videoProcessingPipeline: appContainer.videoProcessingPipeline,
                timecodeCalculationService: TimecodeCalculationService(),
                persistentContainer: PersistenceController.shared.container,
                movePersistenceService: appContainer.movePersistenceService,
                appContainer: appContainer
            )
        }()
        var body: some View {
            AddMoveStateOwner(
                selectedTab: $selectedTab,
                unifiedState: unifiedState
            )
            .environment(
                \.managedObjectContext,
                PersistenceController.shared.container.viewContext
            )
            .preferredColorScheme(.dark)
        }
    }
    return PreviewWrapper()
}
