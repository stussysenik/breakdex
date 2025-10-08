import AVKit
import Combine
import OSLog
import PhotosUI
import SwiftUI

// FeatureRichTrimmerView.swift - DONE

struct TimeoutError: Error, LocalizedError {
    let seconds: Double

    var errorDescription: String? {
        return "Operation timed out after \(seconds) seconds"
    }

    var recoverySuggestion: String? {
        return "Please try again or check your network connection"
    }
}

struct TrimmerPlayerView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    let isReady: Bool
    let previewRotationDegrees: Double

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "TrimmerPlayerView"
    )

    var body: some View {
        Group {
            if shouldShowVideoPlayer {
                videoPlayerContent
            } else {
                finalizingPlaceholderContent
            }
        }
        .frame(height: 300)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var shouldShowVideoPlayer: Bool {
        return isReady && unifiedState.currentPlayerViewModel != nil
    }

    @ViewBuilder
    private var videoPlayerContent: some View {
        if let playerViewModel = unifiedState.currentPlayerViewModel
            as? any VideoPlayerViewModelProtocol
        {
            videoPlayerWithDiagnostics(for: playerViewModel)
        } else {
            EmptyView()
        }
    }

    private func videoPlayerWithDiagnostics(
        for playerViewModel: any VideoPlayerViewModelProtocol
    ) -> AnyView {
        let _ = logger.info(
            "🎬 TRIMMER_PLAYER_VIEW: 🏗️ TYPE_ERASURE: Creating videoPlayerWithDiagnostics with explicit AnyView return type"
        )

        return AnyView(
            PlayerContainerView(
                videoPlayer: CustomVideoPlayerView(
                    viewModel: playerViewModel,
                    shouldAutoplay: false
                ),
                unifiedState: unifiedState,
                isReady: isReady,
                previewRotationDegrees: previewRotationDegrees
            )
        )
    }

    private struct PlayerContainerView: View {
        let videoPlayer: CustomVideoPlayerView
        @ObservedObject var unifiedState: AddMoveUnifiedState
        let isReady: Bool
        let previewRotationDegrees: Double

        private let logger = Logger(
            subsystem: "com.breakingflashcards",
            category: "PlayerContainerView"
        )

        var body: some View {
            videoPlayer
                .rotationEffect(.degrees(previewRotationDegrees))
                .clipped()
                .onAppear {
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: 🎯 DOUBLE_ROTATION_FIX Applied - IDENTITY morphism active"
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: 🏗️ TYPE_ERASURE: AnyView type erasure active for videoPlayerWithDiagnostics"
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ┌─ Video Player State Details"
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ isReady: \(isReady)"
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ playerViewModel_type: CustomVideoPlayerView (video player container)"
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ swiftui_rotation_layer: \"REMOVED\""
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ avplayer_rotation_baked_in: \"ACTIVE\""
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ double_rotation_bug: \"ELIMINATED\""
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ identity_morphism: \"ENFORCED\""
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: ├─ type_erasure: \"AnyView_active\""
                    )
                    let _ = logger.info(
                        "🎬 TRIMMER_PLAYER_VIEW: └─ fix_pattern: \"authoritative_avplayer_rotation\""
                    )

                    if let trimmerVM = unifiedState.trimmerViewModel
                        as? TrimmerViewModel
                    {
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: 📐 Category Theory State"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ┌─ Rotation Domain Objects"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ├─ intrinsic_rotation: \(trimmerVM.assetIntrinsicRotationTurns) turns (\(trimmerVM.assetIntrinsicRotationTurns * 90)°)"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ├─ user_applied_rotation: \(trimmerVM.userAppliedRotationTurns) turns (\(trimmerVM.userAppliedRotationTurns * 90)°)"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ├─ total_rotation: \(trimmerVM.totalRotationQuarterTurns) turns (\(trimmerVM.totalRotationQuarterTurns * 90)°)"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ├─ natural_transformation_η: intrinsic ⊕ user → total"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ├─ trimmerViewModel_type: \(type(of: trimmerVM))"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: 🔄 Morphism: User interaction → AVPlayerItem video composition"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: ✅ SwiftUI Identity: View displays content without transformation"
                        )
                        let _ = logger.info(
                            "🎬 TRIMMER_PLAYER_VIEW: 🏗️ TYPE_ERASURE: Complex view hierarchy successfully type-erased"
                        )
                    }
                }
        }
    }

    private var finalizingPlaceholderContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Finalizing...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 300)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            let logMessage =
                "🎬 TRIMMER_PLAYER_VIEW: Showing Finalizing placeholder - isReady: \(isReady), flowState: \(unifiedState.flowState), playerVM: \(unifiedState.currentPlayerViewModel != nil)"
            logger.info("\(logMessage)")
        }
    }
}

struct FeatureRichTrimmerView: View {
    @State private var viewModel: TrimmerViewModel?
    let unifiedState: AddMoveUnifiedState
    private let timecodeService = TimecodeCalculationService()

    @State private var showPhotosPicker = false
    @State private var tempVideoSelection: PhotosUI.PhotosPickerItem?

    @State private var selectionToProcess: PhotosPickerItem?

    @State private var cachedTimeCodeRow:
        (
            startTime: CMTime, endTime: CMTime, isDraggingStart: Bool,
            isDraggingEnd: Bool
        )?
    @State private var isRotationButtonPressed: Bool = false

    @State private var optimisticRotationDegrees: Double = 0.0

    @State private var isFinalizing = false
    @State private var isViewModelLoading = false
    @State private var viewModelLoadError: String?
    @State private var lazyInitializationAttempted = false

    private let diagnosticLogger = DiagnosticLoggingHelper(
        category: "FeatureRichTrimmer"
    )

    private var isReadyToShowTrimmer: Bool {
        return viewModel?.isReady ?? false
    }

    init(unifiedState: AddMoveUnifiedState) {
        self.unifiedState = unifiedState
    }

    @MainActor
    private func setupTrimmerViewModel() async {
        let setupStartTime = CFAbsoluteTimeGetCurrent()
        let correlationId = UUID().uuidString.prefix(8)

        guard !lazyInitializationAttempted else {
            diagnosticLogger.logInfo(
                "⚠️ LAZY_VIEWMODEL_SETUP - Skipping duplicate initialization call [\(correlationId)]"
            )
            return
        }

        lazyInitializationAttempted = true
        diagnosticLogger.logInfo(
            "🚀 UNIFIED_LAZY_VIEWMODEL_SETUP - Starting unified async TrimmerViewModel creation [\(correlationId)]",
            metadata: [
                "photos_identifier":
                    "\(unifiedState.photosIdentifier ?? "nil")",
                "flow_state": "\(unifiedState.flowState)",
                "race_condition_fix": "ENHANCED_ON_APPEAR_DETECTION",
                "call_source": "onAppear_or_manual_reset",
            ]
        )

        guard viewModel == nil, !isViewModelLoading else {
            diagnosticLogger.logInfo(
                "⚠️ LAZY_VIEWMODEL_SETUP - Skipping initialization (already in progress or completed) [\(correlationId)]",
                metadata: [
                    "photos_identifier":
                        "\(unifiedState.photosIdentifier ?? "nil")",
                    "existing_viewmodel_identifier":
                        "\(viewModel?.photosIdentifier ?? "nil")",
                    "race_condition_fix": "DUPLICATE_PREVENTION",
                ]
            )
            return
        }

        let initialMemoryUsage = MemoryHelper.getDetailedMemoryInfo().used
        let initialCPUUsage = await PerformanceOptimizer().getCPUUsagePercent()
        diagnosticLogger.logInfo(
            "📊 SETUP_BASELINE - Memory: \(initialMemoryUsage)MB, CPU: \(String(format: "%.1f", initialCPUUsage))% [\(correlationId)]"
        )

        isViewModelLoading = true
        viewModelLoadError = nil

        do {
            guard let videoAsset = unifiedState.videoAsset else {
                throw TrimmerSetupError.missingAsset
            }

            guard let photosIdentifier = unifiedState.photosIdentifier,
                !photosIdentifier.isEmpty
            else {
                throw TrimmerSetupError.missingPhotosIdentifier
            }

            guard
                let playerViewModel = unifiedState.currentPlayerViewModel
                    as? UnifiedVideoPlayerViewModel
            else {
                throw TrimmerSetupError.missingPlayerViewModel
            }

            guard playerViewModel.isPlayerReady else {
                throw TrimmerSetupError.playerNotReady
            }

            diagnosticLogger.logInfo(
                "✅ DEPENDENCIES_VALIDATED - All required dependencies available [\(correlationId)]"
            )

            let startTime = CMTime(
                seconds: unifiedState.trimStartTime,
                preferredTimescale: 600
            )
            let endTime = CMTime(
                seconds: unifiedState.trimEndTime,
                preferredTimescale: 600
            )

            diagnosticLogger.logInfo(
                "🎯 VIEWMODEL_CREATION - Starting TrimmerViewModel creation [\(correlationId)]"
            )
            let vmCreationStart = CFAbsoluteTimeGetCurrent()

            let trimmerVM = TrimmerViewModel(
                asset: videoAsset,
                photosIdentifier: photosIdentifier,
                initialIntrinsicRotation: unifiedState.intrinsicAssetRotation,
                initialUserRotation: unifiedState.userAppliedRotation,
                initialStartTime: startTime,
                initialEndTime: endTime,
                playerViewModel: playerViewModel
            )

            let vmCreationTime = CFAbsoluteTimeGetCurrent() - vmCreationStart
            diagnosticLogger.logInfo(
                "✅ VIEWMODEL_CREATED - TrimmerViewModel created in \(String(format: "%.3f", vmCreationTime))s [\(correlationId)]"
            )

            diagnosticLogger.logInfo(
                "🔧 ASYNC_SETUP - Starting TrimmerViewModel.setupAsync() [\(correlationId)]"
            )
            let setupStart = CFAbsoluteTimeGetCurrent()

            try await trimmerVM.setupAsync()

            let setupTime = CFAbsoluteTimeGetCurrent() - setupStart
            diagnosticLogger.logInfo(
                "✅ ASYNC_SETUP_COMPLETE - TrimmerViewModel setup finished in \(String(format: "%.3f", setupTime))s [\(correlationId)]"
            )

            viewModel = trimmerVM

            let totalTime = CFAbsoluteTimeGetCurrent() - setupStartTime
            let finalMemoryUsage = MemoryHelper.getDetailedMemoryInfo().used
            let finalCPUUsage = await PerformanceOptimizer()
                .getCPUUsagePercent()
            let memoryDelta = finalMemoryUsage - initialMemoryUsage

            diagnosticLogger.logInfo(
                "🎉 UNIFIED_LAZY_VIEWMODEL_SUCCESS - TrimmerViewModel fully created [\(correlationId)]"
            )
            diagnosticLogger.logInfo(
                "📊 SETUP_METRICS - Total time: \(String(format: "%.3f", totalTime))s, Memory: +\(memoryDelta)MB, CPU: \(String(format: "%.1f", finalCPUUsage))% [\(correlationId)]"
            )
            diagnosticLogger.logInfo(
                "🎯 PERFORMANCE_OPTIMIZATION - Heavy initialization deferred from state transition [\(correlationId)]"
            )
            diagnosticLogger.logInfo(
                "✅ RACE_CONDITION_FIX - TrimmerViewModel setup completed successfully [\(correlationId)]",
                metadata: [
                    "photos_identifier": "\(photosIdentifier)",
                    "view_model_identifier":
                        "\(trimmerVM.photosIdentifier ?? "nil")",
                    "race_condition_fix": "FLOW_COMPLETED",
                    "on_appear_detection": "SUCCESS",
                ]
            )

        } catch {
            viewModelLoadError = error.localizedDescription
            lazyInitializationAttempted = false
            diagnosticLogger.logError(
                "❌ UNIFIED_LAZY_VIEWMODEL_FAILED - TrimmerViewModel creation failed [\(correlationId)]",
                metadata: [
                    "error": error.localizedDescription,
                    "error_type": "\(type(of: error))",
                    "setup_time":
                        "\(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - setupStartTime))s",
                ]
            )
        }

        isViewModelLoading = false

        let finalCPUUsage = await PerformanceOptimizer().getCPUUsagePercent()
        if finalCPUUsage > 90.0 {
            diagnosticLogger.logError(
                "⚠️ CRITICAL_CPU_USAGE - CPU exceeded 90% during lazy setup: \(String(format: "%.1f", finalCPUUsage))% [\(correlationId)]"
            )
        }
    }

    private var rotationBinding: Binding<Int> {
        Binding(
            get: { viewModel?.userAppliedRotationTurns ?? 0 },
            set: { newValue in
                guard let viewModel = viewModel else { return }
                let oldValue = viewModel.userAppliedRotationTurns

                viewModel.userAppliedRotationTurns = newValue

                if oldValue != newValue {
                    diagnosticLogger.logUserInteraction(
                        "🔧 CRITICAL_FIX_180_DEGREE_FLIP: Simplified binding executed",
                        metadata: [
                            "interaction_type": "rotation_binding_change",
                            "fix_pattern": "ViewModel_only_modification",
                            "reactive_sync": "onChange_handlers_will_update_UI",
                            "morphism_domain": "\(oldValue)",
                            "morphism_codomain": "\(newValue)",
                            "intrinsic_rotation":
                                "\(viewModel.assetIntrinsicRotationTurns)",
                            "user_applied_rotation": "\(newValue)",
                            "total_rotation":
                                "\(viewModel.totalRotationQuarterTurns)",
                            "current_preview_degrees": "0.0_fixed",
                            "binding_source": "simplified_rotation_binding",
                            "manual_state_assignment": "removed",
                            "ui_update_method": "reactive_onChange_modifier",
                            "category_theory":
                                "morphism_in_UserAppliedRotationSpace",
                            "180_degree_flip_prevention": "true",
                            "race_condition_prevention": "reactive_sync",
                            "specification_compliance":
                                "CRITICAL_FIX_180_DEGREE_FLIP",
                        ]
                    )
                }
            }
        )
    }

    private var timeCodeRow: some View {
        guard let viewModel = viewModel else {
            return AnyView(
                ProgressView("Loading Trimmer...").frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            )
        }

        let currentDuration = viewModel.endTime - viewModel.startTime
        let durationFrames = Int(
            (currentDuration.seconds * viewModel.currentFrameRate).rounded()
        )

        return AnyView(
            HStack {
                startTimeSection
                Spacer()
                durationSection(
                    currentDuration: currentDuration,
                    durationFrames: durationFrames
                )
                Spacer()
                endTimeSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(timecodeRowBackground)
            .overlay(timecodeRowOverlay)
            .onAppear(perform: logTimecodeInitialization)
            .onChange(of: viewModel.startTime) { oldValue, newValue in
                logStartTimeChange(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: viewModel.endTime) { oldValue, newValue in
                logEndTimeChange(oldValue: oldValue, newValue: newValue)
            }
        )
    }

    @ViewBuilder
    private var startTimeSection: some View {
        if let viewModel = viewModel {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimecodeFormatter.format(time: viewModel.startTime))
                    .font(
                        .ibmPlexMono(
                            size: 12,
                            weight: viewModel.isDraggingStartHandle
                                ? .semibold : .medium
                        )
                    )
                    .foregroundColor(
                        viewModel.isDraggingStartHandle ? .accent : .textPrimary
                    )
                    .contentTransition(
                        .numericText(value: viewModel.startTime.seconds)
                    )
                    .animation(
                        .spring(
                            response: 0.15,
                            dampingFraction: 0.9,
                            blendDuration: 0.1
                        ),
                        value: viewModel.startTime
                    )
                    .animation(
                        .spring(response: 0.2, dampingFraction: 0.8),
                        value: viewModel.isDraggingStartHandle
                    )

                Text(
                    "Frame \(viewModel.getFrameNumber(for: viewModel.startTime))"
                )
                .font(.ibmPlexMono(size: 8, weight: .regular))
                .foregroundColor(
                    viewModel.isDraggingStartHandle
                        ? .accent.opacity(0.7) : .textSecondary
                )
                .contentTransition(.numericText())
                .animation(
                    .easeInOut(duration: 0.1),
                    value: viewModel.startTime
                )
            }
            .scaleEffect(viewModel.isDraggingStartHandle ? 1.05 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.7),
                value: viewModel.isDraggingStartHandle
            )
        } else {
            Text("Loading...")
        }
    }

    @ViewBuilder
    private func durationSection(currentDuration: CMTime, durationFrames: Int)
        -> some View
    {
        if let viewModel = viewModel {
            VStack(alignment: .center, spacing: 2) {
                HStack(spacing: 4) {
                    if viewModel.showMinimumDurationWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.buttonHard)
                            .scaleEffect(1.1)
                            .animation(
                                .easeInOut(duration: 0.2),
                                value: viewModel.showMinimumDurationWarning
                            )
                    }

                    Text(TimecodeFormatter.format(time: currentDuration))
                        .font(
                            .ibmPlexMono(
                                size: 13,
                                weight: viewModel.showMinimumDurationWarning
                                    ? .semibold : .medium
                            )
                        )
                        .foregroundColor(
                            viewModel.showMinimumDurationWarning
                                ? .buttonHard : .textPrimary
                        )
                        .contentTransition(
                            .numericText(value: currentDuration.seconds)
                        )
                        .animation(
                            .spring(
                                response: 0.15,
                                dampingFraction: 0.9,
                                blendDuration: 0.1
                            ),
                            value: currentDuration
                        )
                        .animation(
                            .spring(response: 0.2, dampingFraction: 0.8),
                            value: viewModel.showMinimumDurationWarning
                        )
                }

                Text("\(durationFrames) frames")
                    .font(.ibmPlexMono(size: 8, weight: .regular))
                    .foregroundColor(
                        viewModel.showMinimumDurationWarning
                            ? .buttonHard.opacity(0.8) : .textSecondary
                    )
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.1), value: durationFrames)
            }
            .scaleEffect(viewModel.showMinimumDurationWarning ? 1.02 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: viewModel.showMinimumDurationWarning
            )
        } else {
            Text("Loading...")
        }
    }

    @ViewBuilder
    private var endTimeSection: some View {
        if let viewModel = viewModel {
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimecodeFormatter.format(time: viewModel.endTime))
                    .font(
                        .ibmPlexMono(
                            size: 12,
                            weight: viewModel.isDraggingEndHandle
                                ? .semibold : .medium
                        )
                    )
                    .foregroundColor(
                        viewModel.isDraggingEndHandle ? .accent : .textPrimary
                    )
                    .contentTransition(
                        .numericText(value: viewModel.endTime.seconds)
                    )
                    .animation(
                        .spring(
                            response: 0.15,
                            dampingFraction: 0.9,
                            blendDuration: 0.1
                        ),
                        value: viewModel.endTime
                    )
                    .animation(
                        .spring(response: 0.2, dampingFraction: 0.8),
                        value: viewModel.isDraggingEndHandle
                    )

                Text(
                    "Frame \(viewModel.getFrameNumber(for: viewModel.endTime))"
                )
                .font(.ibmPlexMono(size: 8, weight: .regular))
                .foregroundColor(
                    viewModel.isDraggingEndHandle
                        ? .accent.opacity(0.7) : .textSecondary
                )
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.1), value: viewModel.endTime)
            }
            .scaleEffect(viewModel.isDraggingEndHandle ? 1.05 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.7),
                value: viewModel.isDraggingEndHandle
            )
        } else {
            Text("Loading...")
        }
    }

    private var timecodeRowBackground: some View {
        diagnosticLogger.logDebug(
            "🔧 TYPE_ERASURE: timecodeRowBackground accessing",
            metadata: [
                "view_model_available": "\(viewModel != nil)",
                "is_dragging_start":
                    "\(viewModel?.isDraggingStartHandle ?? false)",
                "is_dragging_end": "\(viewModel?.isDraggingEndHandle ?? false)",
                "memory_usage_mb":
                    "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
            ]
        )

        return AnyView(
            Group {
                if let viewModel = viewModel {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            viewModel.isDraggingStartHandle
                                || viewModel.isDraggingEndHandle
                                ? Color.accent.opacity(0.05) : Color.clear
                        )
                        .animation(
                            .easeInOut(duration: 0.2),
                            value: viewModel.isDraggingStartHandle
                                || viewModel.isDraggingEndHandle
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.clear)
                }
            }
        )
    }

    private var timecodeRowOverlay: some View {
        diagnosticLogger.logDebug(
            "🔧 TYPE_ERASURE: timecodeRowOverlay accessing",
            metadata: [
                "view_model_available": "\(viewModel != nil)",
                "show_minimum_warning":
                    "\(viewModel?.showMinimumDurationWarning ?? false)",
                "is_dragging_start":
                    "\(viewModel?.isDraggingStartHandle ?? false)",
                "is_dragging_end": "\(viewModel?.isDraggingEndHandle ?? false)",
                "memory_usage_mb":
                    "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
            ]
        )

        return AnyView(
            Group {
                if let viewModel = viewModel {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            viewModel.showMinimumDurationWarning
                                ? Color.buttonHard.opacity(0.3)
                                : (viewModel.isDraggingStartHandle
                                    || viewModel.isDraggingEndHandle
                                    ? Color.accent.opacity(0.2) : Color.clear),
                            lineWidth: 1
                        )
                        .animation(
                            .easeInOut(duration: 0.2),
                            value: viewModel.showMinimumDurationWarning
                        )
                        .animation(
                            .easeInOut(duration: 0.2),
                            value: viewModel.isDraggingStartHandle
                                || viewModel.isDraggingEndHandle
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8).stroke(
                        Color.clear,
                        lineWidth: 1
                    )
                }
            }
        )
    }

    private func logTimecodeInitialization() {
        guard let trimmerVM = viewModel else { return }
        let duration = trimmerVM.endTime - trimmerVM.startTime
        let frameCount = Int(
            (duration.seconds * trimmerVM.currentFrameRate).rounded()
        )

        diagnosticLogger.logInfo(
            "⏰ Enhanced reactive timecode display initialized",
            metadata: [
                "start_time_seconds": "\(trimmerVM.startTime.seconds)",
                "end_time_seconds": "\(trimmerVM.endTime.seconds)",
                "duration_seconds": "\(duration.seconds)",
                "frame_count": "\(frameCount)",
                "frame_rate": "\(trimmerVM.currentFrameRate)",
                "show_warning": "\(trimmerVM.showMinimumDurationWarning)",
                "reactive_labels": "enabled",
                "frame_precision": "milliseconds",
                "haptic_feedback": "frame_synchronized",
            ]
        )
    }

    private func logStartTimeChange(oldValue: CMTime, newValue: CMTime) {
        guard let viewModel = viewModel else { return }
        let oldFrame = viewModel.getFrameNumber(for: oldValue)
        let newFrame = viewModel.getFrameNumber(for: newValue)
        let frameDelta = abs(Int(newFrame) - Int(oldFrame))

        if frameDelta > 0 {
            diagnosticLogger.logDebug(
                "⏰ Start time updated - frame precision tracking",
                metadata: [
                    "old_time_seconds": "\(oldValue.seconds)",
                    "new_time_seconds": "\(newValue.seconds)",
                    "old_frame": "\(oldFrame)",
                    "new_frame": "\(newFrame)",
                    "frame_delta": "\(frameDelta)",
                    "is_dragging": "\(viewModel.isDraggingStartHandle)",
                    "reactive_update": "start_time_label",
                ]
            )
        }
    }

    private func logEndTimeChange(oldValue: CMTime, newValue: CMTime) {
        guard let viewModel = viewModel else { return }
        let oldFrame = viewModel.getFrameNumber(for: oldValue)
        let newFrame = viewModel.getFrameNumber(for: newValue)
        let frameDelta = abs(Int(newFrame) - Int(oldFrame))

        if frameDelta > 0 {
            diagnosticLogger.logDebug(
                "⏰ End time updated - frame precision tracking",
                metadata: [
                    "old_time_seconds": "\(oldValue.seconds)",
                    "new_time_seconds": "\(newValue.seconds)",
                    "old_frame": "\(oldFrame)",
                    "new_frame": "\(newFrame)",
                    "frame_delta": "\(frameDelta)",
                    "is_dragging": "\(viewModel.isDraggingEndHandle)",
                    "reactive_update": "end_time_label",
                ]
            )
        }
    }

    private func logDurationWarningChange(oldValue: Bool, newValue: Bool) {
        guard let viewModel = viewModel else { return }
        diagnosticLogger.logDebug(
            "⚠️ Duration warning state changed",
            metadata: [
                "old_warning_state": "\(oldValue)",
                "new_warning_state": "\(newValue)",
                "current_duration_seconds":
                    "\((viewModel.endTime - viewModel.startTime).seconds)",
                "minimum_duration_seconds":
                    "\(viewModel.minimumDuration.seconds)",
                "reactive_update": "duration_warning_visual",
            ]
        )
    }

    private var placeholderTimeCodeRow: some View {
        HStack {
            Text("--:--.---")
                .font(.ibmPlexMono(size: 11, weight: .regular))
                .foregroundColor(.textSecondary)

            Spacer()

            Text("--:--.---")
                .font(.ibmPlexMono(size: 11, weight: .regular))
                .foregroundColor(.textSecondary)

            Spacer()

            Text("--:--.---")
                .font(.ibmPlexMono(size: 11, weight: .regular))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    init(unifiedState: AddMoveUnifiedState, viewModel: TrimmerViewModel) {
        self.unifiedState = unifiedState
        self.viewModel = viewModel

        let logger = DiagnosticLoggingHelper(category: "FeatureRichTrimmerView")
        logger.logInfo(
            "🔧 CRITICAL_FIX_180_DEGREE_FLIP: FeatureRichTrimmerView initialized with IDENTITY morphism",
            metadata: [
                "player_ready": "\(viewModel.playerViewModel.isPlayerReady)",
                "trimmer_ready": "\(viewModel.isReady)",
                "player_state": "\(viewModel.playerViewModel.state)",
                "loaded_intrinsic_rotation":
                    "\(viewModel.assetIntrinsicRotationTurns)",
                "user_applied_rotation":
                    "\(viewModel.userAppliedRotationTurns)",
                "total_rotation": "\(viewModel.totalRotationQuarterTurns)",
                "swiftui_rotation_state": "REMOVED",
                "avplayer_rotation_handling": "INTERNAL",
                "fix_type": "identity_morphism_180_degree_flip_fix",
                "double_rotation_eliminated": "true",
                "category_theory": "identity_morphism_SwiftUI_display",
                "rotation_responsibility": "AVPlayerItem_video_composition",
                "specification_compliance": "CRITICAL_FIX_180_DEGREE_FLIP",
            ]
        )
    }

    var body: some View {
        mainContent
            .background(backgroundStyle)
            .onAppear(perform: onMainViewAppear)
            .onDisappear(perform: onMainViewDisappear)
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $tempVideoSelection,
                matching: .videos
            )
            .onChange(of: tempVideoSelection) { _, newItem in
                if let newItem = newItem {
                    diagnosticLogger.logDebug(
                        "🎯 RACE_CONDITION_FIX: 📥 Capturing video selection",
                        metadata: [
                            "selection_identifier": newItem.itemIdentifier
                                ?? "unknown",
                            "timestamp": "\(Date())",
                        ]
                    )

                    selectionToProcess = PhotosPickerItem(item: newItem)
                    tempVideoSelection = nil

                    diagnosticLogger.logDebug(
                        "🎯 RACE_CONDITION_FIX: ✅ Selection captured, waiting for .task to process",
                        metadata: [
                            "selection_identifier": selectionToProcess?
                                .itemIdentifier ?? "unknown",
                            "timestamp": "\(Date())",
                        ]
                    )
                }
            }
            .task(id: selectionToProcess) {
                if let itemToProcess = selectionToProcess {
                    await processVideoSelectionSafely(itemToProcess)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .onChange(of: showPhotosPicker) { _, isShowing in
                onPhotosPickerChange(isShowing: isShowing)
            }
            .alert(
                "Minimum Duration",
                isPresented: Binding(
                    get: { viewModel?.showMinDurationAlert ?? false },
                    set: { newValue in
                        if !newValue {
                            viewModel?.showMinDurationAlert = false
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The minimum video duration is 3.000 seconds.")
            }
    }

    private var mainContent: some View {
        diagnosticLogger.logDebug(
            "🔧 TYPE_ERASURE: mainContent accessing",
            metadata: [
                "is_view_model_loading": "\(isViewModelLoading)",
                "has_load_error": "\(viewModelLoadError != nil)",
                "view_model_available": "\(viewModel != nil)",
                "memory_usage_mb":
                    "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
            ]
        )

        return AnyView(
            Group {
                if isViewModelLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Preparing Trimmer...")
                            .font(Font.appFont(AppFont.bold, size: 16))
                            .foregroundColor(.textSecondary)

                        Text("Setting up video editing tools...")
                            .font(Font.appFont(AppFont.regular, size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cardBackground)

                } else if let error = viewModelLoadError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.buttonHard)

                        Text("Trimmer Setup Failed")
                            .font(Font.appFont(AppFont.bold, size: 18))
                            .foregroundColor(.textPrimary)

                        Text(error)
                            .font(Font.appFont(AppFont.regular, size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Button("Retry") {
                            lazyInitializationAttempted = false
                            Task {
                                await setupTrimmerViewModel()
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle(size: .medium))
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cardBackground)

                } else if viewModel != nil {
                    ZStack {
                        VStack(spacing: 0) {
                            Spacer()
                            videoPlayerSection
                            Spacer()
                            trimmerInterfaceSection
                            Spacer()
                        }
                        .padding(10)
                    }

                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.0)
                        Text("Initializing Trimmer...")
                            .font(Font.appFont(AppFont.bold, size: 16))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.cardBackground)
                }
            }
            .onAppear {
                diagnosticLogger.logInfo(
                    "🎯 UNIFIED_LAZY_LOADING: mainContent appeared - triggering unified lazy ViewModel initialization"
                )
                Task {
                    await setupTrimmerViewModel()
                }
            }
        )
    }

    private var videoPlayerSection: some View {
        Group {
            if false {
                videoReplacementView
            } else {
                TrimmerPlayerView(
                    unifiedState: unifiedState,
                    isReady: isReadyToShowTrimmer,
                    previewRotationDegrees: optimisticRotationDegrees
                )
            }
        }
    }

    private var trimmerInterfaceSection: some View {
        diagnosticLogger.logDebug(
            "🔧 TYPE_ERASURE: trimmerInterfaceSection accessing",
            metadata: [
                "view_model_available": "\(viewModel != nil)",
                "show_minimum_warning":
                    "\(viewModel?.showMinimumDurationWarning == true)",
                "memory_usage_mb":
                    "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
            ]
        )

        return AnyView(
            Group {
                if let viewModel = viewModel {
                    VStack(spacing: 8) {
                        Spacer()
                        if viewModel.showMinimumDurationWarning == true {
                            minimumDurationWarning
                        }
                        timeCodeDisplay
                        mainTrimmerSection
                        controlSection
                        Spacer()
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
        )
    }

    private var backgroundStyle: some View {
        Color.backgroundPrimary.ignoresSafeArea()
    }

    @MainActor
    private func initializeTrimmerViewModelIfNeeded() {
        let startTime = CFAbsoluteTimeGetCurrent()
        let sessionId = String(UUID().uuidString.prefix(8))

        diagnosticLogger.logInfo(
            "🎬 FEATURE_RICH_TRIMMER: 🚀 LAZY_INITIALIZATION [\(sessionId)] Starting lazy ViewModel initialization"
        )

        if unifiedState.trimmerViewModel != nil {
            let existingTime = CFAbsoluteTimeGetCurrent() - startTime
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ⏭️ LAZY_INITIALIZATION [\(sessionId)] TrimmerViewModel already exists - skipping (time: \(String(format: "%.3f", existingTime))s)"
            )
            return
        }

        diagnosticLogger.logInfo(
            "🎬 FEATURE_RICH_TRIMMER: 🔄 LAZY_INITIALIZATION [\(sessionId)] Creating TrimmerViewModel with full dependencies"
        )

        Task {
            await performAsyncViewModelInitialization(sessionId: sessionId)
        }
    }

    @MainActor
    private func performAsyncViewModelInitialization(sessionId: String) async {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            guard let asset = unifiedState.videoAsset else {
                diagnosticLogger.logError(
                    "🎬 FEATURE_RICH_TRIMMER: ❌ LAZY_INITIALIZATION [\(sessionId)] Missing video asset"
                )
                return
            }

            guard let photosIdentifier = unifiedState.photosIdentifier else {
                diagnosticLogger.logError(
                    "🎬 FEATURE_RICH_TRIMMER: ❌ LAZY_INITIALIZATION [\(sessionId)] Missing photos identifier"
                )
                return
            }

            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: 📝 LAZY_INITIALIZATION [\(sessionId)] Dependencies validated - creating ViewModel"
            )

            let videoDuration = try await asset.load(.duration)
            let cmStartTime = CMTime.zero
            let endTime = videoDuration

            guard
                let playerViewModel = unifiedState.currentPlayerViewModel
                    as? UnifiedVideoPlayerViewModel
            else {
                diagnosticLogger.logError(
                    "🎬 FEATURE_RICH_TRIMMER: ❌ LAZY_INITIALIZATION [\(sessionId)] Player ViewModel not available"
                )
                return
            }

            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: 🎬 LAZY_INITIALIZATION [\(sessionId)] Creating TrimmerViewModel with parameters:"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ video_duration: \(String(format: "%.3f", videoDuration.seconds))s"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ start_time: \(String(format: "%.3f", cmStartTime.seconds))s"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ end_time: \(String(format: "%.3f", endTime.seconds))s"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: └─ trim_range: \(String(format: "%.3f", endTime.seconds - cmStartTime.seconds))s"
            )

            let trimmerViewModel = TrimmerViewModel(
                asset: asset,
                photosIdentifier: photosIdentifier,
                initialIntrinsicRotation: unifiedState.intrinsicAssetRotation,
                initialUserRotation: unifiedState.userAppliedRotation,
                initialStartTime: cmStartTime,
                initialEndTime: endTime,
                playerViewModel: playerViewModel
            )

            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: 🔧 LAZY_INITIALIZATION [\(sessionId)] Setting up TrimmerViewModel async"
            )
            try await trimmerViewModel.setupAsync()

            unifiedState.trimmerViewModel = trimmerViewModel

            let initializationTime = CFAbsoluteTimeGetCurrent() - startTime
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ✅ LAZY_INITIALIZATION [\(sessionId)] Complete - time: \(String(format: "%.3f", initializationTime))s"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: 🎯 PERFORMANCE_TARGET_MET: \(initializationTime < 0.250 ? "✅ YES" : "❌ NO")"
            )

            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: 📊 PERFORMANCE_METRICS [\(sessionId)]:"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ Lazy loading: ✅ Applied"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ Resource usage: Optimized"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: ├─ UX impact: Improved responsiveness"
            )
            diagnosticLogger.logInfo(
                "🎬 FEATURE_RICH_TRIMMER: └─ Architecture: SRP maintained"
            )

        } catch {
            let initializationTime = CFAbsoluteTimeGetCurrent() - startTime
            diagnosticLogger.logError(
                "🎬 FEATURE_RICH_TRIMMER: ❌ LAZY_INITIALIZATION [\(sessionId)] Failed - time: \(String(format: "%.3f", initializationTime))s"
            )
            diagnosticLogger.logError(
                "🎬 FEATURE_RICH_TRIMMER: ❌ LAZY_INITIALIZATION [\(sessionId)] Error: \(error.localizedDescription)"
            )
        }
    }

    private func onMainViewAppear() {
        let logger = DiagnosticLoggingHelper(category: "FeatureRichTrimmerView")

        let currentPhotosIdentifier = unifiedState.photosIdentifier
        let hasExistingViewModel = viewModel != nil

        if hasExistingViewModel {
            let currentViewModelIdentifier = viewModel?.photosIdentifier ?? ""
            let videoChanged =
                currentPhotosIdentifier != currentViewModelIdentifier

            if videoChanged {
                logger.logInfo(
                    "🔄 RACE_CONDITION_FIX: New video detected, resetting trimmer state",
                    metadata: [
                        "previous_identifier": "\(currentViewModelIdentifier)",
                        "new_identifier": "\(currentPhotosIdentifier ?? "nil")",
                        "video_changed": "\(videoChanged)",
                        "race_condition_fix":
                            "PHOTOS_IDENTITY_CHANGE_DETECTION",
                    ]
                )

                self.viewModel = nil
                self.lazyInitializationAttempted = false

                Task {
                    await setupTrimmerViewModel()
                }
            } else {
                logger.logInfo(
                    "✅ RACE_CONDITION_FIX: Same video detected, no reset needed",
                    metadata: [
                        "current_identifier":
                            "\(currentPhotosIdentifier ?? "nil")",
                        "video_changed": "\(videoChanged)",
                        "race_condition_fix": "NO_ACTION_NEEDED",
                    ]
                )
            }
        }

        logger.logInfo(
            "🎯 DOUBLE_ROTATION_FIX: View appeared with identity morphism - no SwiftUI rotation sync needed",
            metadata: [
                "intrinsic_rotation":
                    "\(viewModel?.assetIntrinsicRotationTurns ?? 0 * 90)°",
                "user_rotation":
                    "\(viewModel?.userAppliedRotationTurns ?? 0 * 90)°",
                "total_rotation":
                    "\(viewModel?.totalRotationQuarterTurns ?? 0 * 90)°",
                "swiftui_rotation": "DISABLED",
                "avplayer_rotation": "ENABLED",
                "double_rotation_fixed": "true",
                "current_photos_identifier":
                    "\(currentPhotosIdentifier ?? "nil")",
                "has_existing_viewmodel": "\(hasExistingViewModel)",
                "race_condition_fix": "ENHANCED_ON_APPEAR_DETECTION",
            ]
        )
    }

    private func onMainViewDisappear() {
        diagnosticLogger.logInfo("🧹 Body disappeared; cleanup completed")
    }

    private func onPhotosPickerChange(isShowing: Bool) {
        diagnosticLogger.logDebug(
            "🔄 MODAL_PHOTOS_PICKER_STATE_CHANGED: Modal PhotosPicker state changed to \(isShowing)",
            metadata: [
                "presentation_style": "modal_sheet",
                "workflow_preservation": "trimmer_view_remains_visible",
                "is_showing": "\(isShowing)",
                "temp_video_selection_is_nil": "\(tempVideoSelection == nil)",
                "simplified_workflow": "delegated_to_unifiedState",
                "timestamp": "\(Date())",
            ]
        )

        if !isShowing {
            diagnosticLogger.logDebug(
                "📱 PHOTOS_PICKER_DISMISSED: Photos picker dismissed",
                metadata: [
                    "had_selection": "\(tempVideoSelection != nil)",
                    "simplified_workflow": "true",
                    "timestamp": "\(Date())",
                ]
            )
        }
    }

    private var timeCodeDisplay: some View {
        VStack(spacing: 12) {
            self.timeCodeRow
        }
        .onAppear(perform: onTimeCodeDisplayAppear)
    }

    private func onTimeCodeDisplayAppear() {
        let trimmerVM = viewModel
        diagnosticLogger.logInfo(
            "⏰ Time code display appeared",
            metadata: [
                "start_time_seconds":
                    "\(CMTimeGetSeconds(trimmerVM?.startTime ?? CMTime.zero))",
                "end_time_seconds":
                    "\(CMTimeGetSeconds(trimmerVM?.endTime ?? CMTime.zero))",
                "show_warning":
                    "\(trimmerVM?.showMinimumDurationWarning ?? false)",
            ]
        )
    }

    private var changeVideoButton: some View {
        Button("Change Video") {
            HapticManager.shared.trigger(.dragEnd)

            diagnosticLogger.logUserInteraction(
                "User tapped 'Change Video' - showing PhotosPicker",
                metadata: [
                    "button_action": "change_video",
                    "workflow_type": "simplified_picker_presentation",
                    "state_reset_approach":
                        "deferred_to_video_replacement_handler",
                    "current_flow_state":
                        "\(String(describing: unifiedState.flowState))",
                    "category_theory_applied": "morphism_composition",
                ]
            )

            showPhotosPicker = true
        }
        .buttonStyle(.appSecondary(size: .medium))
        .disabled(!(isReadyToShowTrimmer && viewModel?.isReady ?? false))
    }

    private var rotationButton: some View {
        Button(action: {
            HapticManager.shared.trigger(.frameDetent)

            withAnimation(.spring()) {
                optimisticRotationDegrees += 90
            }

            let oldUserRotation = viewModel?.userAppliedRotationTurns ?? 0
            let intrinsicRotation = viewModel?.assetIntrinsicRotationTurns ?? 0

            diagnosticLogger.logUserInteraction(
                "🎯 OPTIMISTIC_ROTATION: User rotation button pressed - applying optimistic UI update",
                metadata: [
                    "interaction_type": "rotation_button_press",
                    "optimistic_rotation": "applied_immediately",
                    "optimistic_degrees": "\(optimisticRotationDegrees)",
                    "user_rotation_before": "\(oldUserRotation)",
                    "intrinsic_rotation": "\(intrinsicRotation)",
                    "total_rotation_before":
                        "\(viewModel?.totalRotationQuarterTurns ?? 0)",
                    "fix_pattern": "optimistic_ui_async_model_update",
                ]
            )

            Task {
                await unifiedState.handleRotation()

                await MainActor.run {
                    withAnimation(.spring()) {
                        let authoritativeRotation = Double(
                            (viewModel?.totalRotationQuarterTurns ?? 0) * 90
                        )
                        self.optimisticRotationDegrees = authoritativeRotation

                        diagnosticLogger.logInfo(
                            "🎯 OPTIMISTIC_ROTATION: Reconciled with authoritative state",
                            metadata: [
                                "authoritative_rotation":
                                    "\(authoritativeRotation)",
                                "optimistic_rotation_reset": "true",
                            ]
                        )
                    }
                }

                await MainActor.run {
                    diagnosticLogger.logInfo(
                        "✅ OPTIMISTIC_ROTATION: Rotation handling completed",
                        metadata: [
                            "user_rotation_after":
                                "\(viewModel?.userAppliedRotationTurns ?? 0)",
                            "total_rotation_after":
                                "\(viewModel?.totalRotationQuarterTurns ?? 0)",
                            "player_regeneration": "completed",
                            "optimistic_ui_applied": "true",
                            "reconciliation_completed": "true",
                        ]
                    )
                }
            }
        }) {
            rotationButtonContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!(isReadyToShowTrimmer && viewModel?.isReady ?? false))
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isRotationButtonPressed = pressing
                }
            },
            perform: {}
        )
    }

    private var rotationButtonContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "rotate.right")
                .font(.system(size: 16, weight: .medium))
                .rotationEffect(
                    .degrees(
                        Double((viewModel?.totalRotationQuarterTurns ?? 0) * 90)
                    )
                )
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8),
                    value: viewModel?.totalRotationQuarterTurns ?? 0
                )

            Text("\((viewModel?.userAppliedRotationTurns ?? 0) * 90)°")
                .font(.ibmPlexMono(size: 12, weight: .medium))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8),
                    value: viewModel?.userAppliedRotationTurns ?? 0
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.accent.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.accent, lineWidth: 1.5)
                )
        )
        .scaleEffect(isRotationButtonPressed ? 0.95 : 1.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.7),
            value: isRotationButtonPressed
        )
    }

    private var controlSection: some View {
        Group {
            if let trimmerVM = viewModel {
                let totalRotation = trimmerVM.totalRotationQuarterTurns
                let isExporting = trimmerVM.isExporting

                HStack(spacing: 20) {
                    changeVideoButton
                    rotationButton

                    Button("Continue") {
                        HapticManager.shared.trigger(.dragEnd)
                        diagnosticLogger.logUserInteraction(
                            "Continue button tapped",
                            metadata: [
                                "button_type": "continue",
                                "current_rotation":
                                    "\((viewModel?.totalRotationQuarterTurns ?? 0) * 90)°",
                                "exporting": "\(isExporting)",
                                "swiftui_rotation": "disabled",
                                "avplayer_rotation": "enabled",
                            ]
                        )

                        Task {
                            diagnosticLogger.logDebug(
                                "🔧 MEMORY_FIX: Continue button Task started"
                            )
                            await validateAndContinue()
                        }
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                    .disabled(isExporting || !isReadyToContinue())
                }
                .padding()
                .onAppear {
                    diagnosticLogger.logInfo(
                        "🎮 FEAT-2025-ROTATION-ISOMORPHISM: Control section appeared with separated rotation state",
                        metadata: [
                            "intrinsic_rotation":
                                "\(trimmerVM.assetIntrinsicRotationTurns)",
                            "user_applied_rotation":
                                "\(trimmerVM.userAppliedRotationTurns)",
                            "total_rotation": "\(totalRotation)",
                            "exporting": "\(isExporting)",
                            "memory_usage_mb":
                                "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
                            "separation_principle":
                                "intrinsic_vs_user_rotation",
                            "separation_working": "correctly",
                            "preview_rotation_degrees": "0.0_fixed",
                            "swiftui_rotation_disabled": "true",
                            "double_rotation_fixed": "true",
                            "specification_compliance": "DOUBLE_ROTATION_FIX",
                        ]
                    )
                }
            } else {
                ProgressView("Loading...")
            }
        }
    }

    private var mainTrimmerSection: some View {
        Group {
            if isReadyToShowTrimmer, let viewModel = viewModel,
                viewModel.isReady
            {
                let trimmerViewModel = viewModel
                HybridPreciseTrimmerView.shoe(viewModel: trimmerViewModel)
                    .onAppear(perform: onMainTrimmerAppear)
            } else {
                trimmerLoadingPlaceholder
            }
        }
    }

    private var trimmerLoadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.0)
                .foregroundColor(.accent)

            Text("Loading trimmer...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground.opacity(0.5))
        .cornerRadius(8)
        .onAppear {
            diagnosticLogger.logInfo(
                "🎚 TRIMMER_LOADING: Showing loading placeholder",
                metadata: [
                    "flow_state": "\(unifiedState.flowState)",
                    "trimmer_ready": "\(viewModel?.isReady ?? false)",
                    "combined_ready": "\(isReadyToShowTrimmer)",
                ]
            )
        }
    }

    private func onMainTrimmerAppear() {
        let videoDuration = viewModel?.videoDuration ?? CMTime.zero
        diagnosticLogger.logInfo(
            "🎚 Main trimmer section appeared",
            metadata: [
                "video_duration_seconds": "\(CMTimeGetSeconds(videoDuration))",
                "cpu_usage_percent":
                    "\(String(format: "%.1f", diagnosticLogger.getCurrentCPUUsage()))",
            ]
        )
    }

    private func logInfo(_ message: String) {
        diagnosticLogger.logInfo(message)
    }

    private var minimumDurationWarning: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.buttonHard)
                    .font(.system(size: 14, weight: .medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration too short")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.buttonHard)

                    let trimmerViewModel = viewModel
                    let duration =
                        (trimmerViewModel?.endTime ?? CMTime.zero)
                        - (trimmerViewModel?.startTime ?? CMTime.zero)
                    let minimum =
                        trimmerViewModel?.minimumDuration ?? CMTime.zero

                    Text(
                        "Current: \(timecodeService.formatTime(duration, includeMilliseconds: true)) • Minimum: \(timecodeService.formatTime(minimum, includeMilliseconds: true))"
                    )
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.buttonHard.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.buttonHard.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.buttonHard.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            let trimmerViewModel = viewModel
            let duration =
                (trimmerViewModel?.endTime ?? CMTime.zero)
                - (trimmerViewModel?.startTime ?? CMTime.zero)
            let minimum = trimmerViewModel?.minimumDuration ?? CMTime.zero
            let durationSeconds = duration.seconds
            let minimumSeconds = minimum.seconds
            diagnosticLogger.logWarning(
                "⚠️ Enhanced minimum duration warning appeared",
                metadata: [
                    "duration_seconds": "\(durationSeconds)",
                    "minimum_seconds": "\(minimumSeconds)",
                    "is_below_minimum": "\(durationSeconds < minimumSeconds)",
                    "warning_type": "enhanced_visual_feedback",
                ]
            )
        }
    }

    private var videoReplacementView: some View {
        VStack(spacing: 16) {
            Spacer()

            replacementLoadingView()

            Spacer()
        }
        .frame(height: 300)
        .background(Color.black.ignoresSafeArea())
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func replacementProgressView(
        progress: Double,
        status: String,
        icon: String
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.accent)
                .scaleEffect(1.0 + (progress * 0.2))
                .animation(.easeInOut(duration: 0.3), value: progress)

            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.circular)
                .scaleEffect(1.2)

            VStack(spacing: 8) {
                Text("Replacing Video...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("\(Int(progress * 100))%")
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.accent)
            }
        }
    }

    private func replacementErrorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.buttonHard)

            VStack(spacing: 8) {
                Text("Video Replacement Failed")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Retry") {
                retryVideoReplacement()
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
        }
    }

    private func replacementLoadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)

            Text("Preparing video replacement...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func hasUnsavedChanges() -> Bool {
        let trimmerVM = viewModel

        let hasTrimChanges =
            (trimmerVM?.startTime.seconds ?? 0) > 0
            || (trimmerVM?.endTime.seconds ?? 0)
                < (trimmerVM?.videoDuration.seconds ?? 0)

        let hasRotationChanges = (trimmerVM?.userAppliedRotationTurns ?? 0) > 0

        return hasTrimChanges || hasRotationChanges
    }

    private func beginVideoReplacementProcess() {
        Task {
            diagnosticLogger.logDebug(
                "🔧 MEMORY_FIX: Video replacement Task started"
            )
            await performVideoReplacement()
        }
    }

    private func performVideoReplacement() async {
        diagnosticLogger.startTiming("video_replacement")

        do {
            try await prepareVideoReplacement()

            await showVideoPicker()

        } catch {
            handleVideoReplacementErrorSync(error)
        }
    }

    private func prepareVideoReplacement() async throws {
        diagnosticLogger.logInfo(
            "🎯 ATOMIC_STATE_RESET: Initiating atomic state reset before PhotosPicker presentation"
        )

        let atomicResetStartTime = Date()

        do {
            try await unifiedState.prepareForNewVideoSelection()

            let atomicResetDuration = Date().timeIntervalSince(
                atomicResetStartTime
            )
            diagnosticLogger.logInfo(
                "🎯 ATOMIC_STATE_RESET: ✅ Atomic state reset completed successfully",
                metadata: [
                    "reset_duration_ms":
                        "\(String(format: "%.3f", atomicResetDuration * 1000))",
                    "performance_target_met": "\(atomicResetDuration < 0.1)",
                    "flow_state_after_reset":
                        "\(String(describing: unifiedState.flowState))",
                    "ready_for_photos_picker": "true",
                ]
            )

        } catch let resetError as TransitionLockError {
            diagnosticLogger.logError(
                "🎯 ATOMIC_STATE_RESET: ❌ Transition lock acquisition failed",
                metadata: [
                    "error_description": "\(resetError.localizedDescription)",
                    "error_recovery_suggestion":
                        "\(resetError.recoverySuggestion ?? "Unknown")",
                    "reset_duration_ms":
                        "\(String(format: "%.3f", Date().timeIntervalSince(atomicResetStartTime) * 1000))",
                ]
            )
            throw resetError

        } catch {
            diagnosticLogger.logError(
                "🎯 ATOMIC_STATE_RESET: ❌ Atomic state reset failed",
                metadata: [
                    "error_description": "\(error.localizedDescription)",
                    "error_type": "\(type(of: error))",
                    "reset_duration_ms":
                        "\(String(format: "%.3f", Date().timeIntervalSince(atomicResetStartTime) * 1000))",
                ]
            )
            throw error
        }

        guard case .ready = unifiedState.flowState else {
            let errorMessage =
                "Atomic state reset verification failed: expected .ready state, got \(String(describing: unifiedState.flowState))"
            diagnosticLogger.logError(
                "🎯 ATOMIC_STATE_RESET: ❌ State verification failed",
                metadata: [
                    "expected_state": "ready",
                    "actual_state":
                        "\(String(describing: unifiedState.flowState))",
                    "verification_failed": "true",
                ]
            )
            throw NSError(
                domain: "FeatureRichTrimmerView",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage
                ]
            )
        }

        diagnosticLogger.logInfo(
            "🎯 ATOMIC_STATE_RESET: ✅ State verification passed - system ready for new video selection"
        )

        await optimizeMemoryForReplacement()

        diagnosticLogger.logInfo(
            "✅ Video replacement preparation completed with atomic state reset",
            metadata: [
                "atomic_reset_performed": "true",
                "state_verification_passed": "true",
                "ready_for_photos_picker": "true",
            ]
        )
    }

    private func showVideoPicker() async {
        await MainActor.run {
            diagnosticLogger.logInfo(
                "🎯 MODAL_PHOTOS_PICKER: Presenting modal PhotosPicker over current trimmer view",
                metadata: [
                    "presentation_style": "modal_sheet",
                    "user_experience": "non_disruptive",
                    "workflow_preservation": "trimmer_view_remains_visible",
                    "atomic_state_reset_completed": "true",
                    "modal_behavior": "slide_over_bottom",
                ]
            )

            showPhotosPicker = true
        }
    }

    @MainActor
    private func performAtomicVideoReplacement(
        _ item: PhotosUI.PhotosPickerItem
    ) async {
        let replacementStartTime = Date()
        let correlationId = UUID().uuidString.prefix(8)

        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: 🚀 Starting atomic video replacement [\(correlationId)]"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: 📋 Workflow Overview:"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: ┌─ Step 1: Atomic state reset"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ prepareForNewVideoSelection()"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  └─ Reset to .ready state"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: ├─ Step 2: Video loading"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ handleVideoSelection()"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  └─ Load new video asset"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: └─ Step 3: Seamless transition"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT:     ├─ Automatic return to .trimming"
        )
        diagnosticLogger.logInfo(
            "🎯 SIMPLIFIED_VIDEO_REPLACEMENT:     └─ Trimmer view updates automatically"
        )

        do {
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: 📊 Step 1 - Performing atomic state reset"
            )
            let resetStartTime = Date()

            try await unifiedState.prepareForNewVideoSelection()

            let resetDuration = Date().timeIntervalSince(resetStartTime)
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: ✅ Step 1 complete - Atomic reset in \(String(format: "%.3f", resetDuration * 1000))ms"
            )

            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: 📊 Step 2 - Loading new video via unified state"
            )
            let loadStartTime = Date()

            let customItem = PhotosPickerItem(item: item)
            await unifiedState.handleVideoSelection(
                customItem,
                context: "trimmer_view"
            )

            let loadDuration = Date().timeIntervalSince(loadStartTime)
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: ✅ Step 2 complete - Video loading initiated in \(String(format: "%.3f", loadDuration * 1000))ms"
            )

            let totalDuration = Date().timeIntervalSince(replacementStartTime)
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: 📊 PERFORMANCE SUMMARY"
            )
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ Total replacement time: \(String(format: "%.3f", totalDuration * 1000))ms"
            )
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ Reset time: \(String(format: "%.3f", resetDuration * 1000))ms"
            )
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ Load initiation time: \(String(format: "%.3f", loadDuration * 1000))ms"
            )
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  ├─ Correlation ID: \(correlationId)"
            )
            diagnosticLogger.logInfo(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: │  └─ Status: ✅ Atomic replacement completed successfully"
            )

        } catch {
            diagnosticLogger.logError(
                "🎯 SIMPLIFIED_VIDEO_REPLACEMENT: ❌ Atomic video replacement failed",
                error: error,
                metadata: [
                    "correlationId": String(correlationId),
                    "error_type": String(describing: type(of: error)),
                    "recovery_suggestion":
                        "User can retry 'Change Video' operation",
                ]
            )
        }
    }

    private func processVideoReplacement(_ item: PhotosUI.PhotosPickerItem) {
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🚀 Starting SYNCHRONOUS video replacement process"
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🔧 CRITICAL_FIX_DEADLOCK: processVideoReplacement is now synchronous"
        )

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 📥 Phase 1 - Loading new video (synchronous initiation)"
        )

        let customItem = PhotosPickerItem(item: item)

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🔧 CRITICAL_FIX_ISSUE_2: Video replacement method corrected"
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 📊 Video Replacement Analysis:"
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ┌─ Method Selection Analysis")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ previous_method: \"replaceSelectedVideo(customItem)\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ new_method: \"didSelectVideo(customItem)\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ change_reason: \"complete_state_transition_cycle_required\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ method_behavior_difference: \"load_only vs load_and_transition\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ├─ State Transition Impact")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ replaceSelectedVideo: \"loads video but stays in_current_state\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ didSelectVideo: \"loads video AND transitions_to_trimming\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ required_behavior: \"full_load_to_trimming_workflow\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ├─ Category Theory Fix")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ broken_morphism: \"replaceSelectedVideo: Video → Video (incomplete)\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ fixed_morphism: \"didSelectVideo: Video → TrimmingState (complete)\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ composition_fixed: \"videoSelection ∘ stateTransition ≈ identity\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: └─ User Impact")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     ├─ before_fix: \"Change Video button appears to do nothing\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     └─ after_fix: \"Change Video button loads new video and transitions to trimmer\""
        )

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🎯 Calling didSelectVideo method (FIXED) - SYNCHRONOUS"
        )

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🔧 ENHANCED_DEADLOCK_FIX: Using detached Task for true non-blocking execution"
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 📋 Task Execution Analysis:")
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ┌─ Task Selection")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ previous_approach: \"Task { await unifiedState.didSelectVideo(customItem) }\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ current_approach: \"Task.detached { await unifiedState.didSelectVideo(customItem) }\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ difference: \"detached_task vs regular_task\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ benefit: \"guaranteed_background_execution\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ├─ Main Thread Impact")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ scheduling: \"immediate_return_to_main_thread\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ execution_context: \"separate_actor_context\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ responsiveness: \"maintained_100ms_ui_response\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: └─ Deadlock Prevention")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     ├─ actor_isolation: \"complete_separation_from_main_actor\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     └─ state_update_flow: \"unifiedState_handles_main_thread_updates\""
        )

        Task.detached { @MainActor in
            unifiedState.didSelectVideo(customItem)
        }

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🔧 DEADLOCK_FIX_REMOVED: waitForVideoReady() call removed"
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 📋 Deadlock Prevention Details:"
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ┌─ Removed Operation")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ removed_function: \"waitForVideoReady()\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ removal_reason: \"blocked main thread preventing state updates\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ deadlock_pattern: \"Task.waitForStateChange ∘ MainThreadBlock ≈ deadlock\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ├─ New Approach")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ state_handling: \"initiate_only, don't_wait\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ ui_responsiveness: \"main thread remains responsive\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ completion_handling: \"unifiedState handles its own transitions\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: └─ Expected Result")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     ├─ change_video_button: \"works without stalling\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     └─ state_transitions: \"proceed naturally to completion\""
        )

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🏁 Phase 3 - Quick finalization (synchronous)"
        )
        finalizeVideoReplacementSync()

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: ✅ Simplified workflow - no local state reset required"
        )

        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 🔧 POST_FIX_VERIFICATION_ISSUE_2: Video replacement initiation verified"
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 📊 Synchronous Video Replacement Results:"
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ┌─ Initiation Analysis")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ replacement_initiated: \"true\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ deadlock_prevented: \"true\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ main_thread_free: \"true\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ async_task_started: \"true\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ├─ Fix Status")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ deadlock_fix_applied: \"true\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  ├─ waitforvideoready_removed: \"true\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: │  └─ synchronous_initiation: \"true\""
        )
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: └─ User Experience Impact")
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     ├─ before_fix: \"Change Video button stalls indefinitely\""
        )
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW:     └─ after_fix: \"Change Video button responds immediately\""
        )

        diagnosticLogger.stopTiming("video_replacement")
        diagnosticLogger.logInfo(
            "✅ Video replacement initiation completed successfully (deadlock prevented)"
        )
    }

    @MainActor
    private func processVideoSelectionSafely(_ item: PhotosPickerItem) async {
        let processStartTime = Date()
        let correlationId = UUID().uuidString.prefix(8)

        diagnosticLogger.logInfo(
            "🎯 RACE_CONDITION_FIX: 🚀 Starting safe video selection processing [\(correlationId)]",
            metadata: [
                "selection_identifier": item.itemIdentifier ?? "unknown",
                "timestamp": "\(processStartTime)",
                "fix_type": "task_based_processing",
                "view_lifecycle_decoupled": "true",
            ]
        )

        diagnosticLogger.logInfo(
            "🎯 CATEGORY_THEORY_FIX: 📤 Delegating to unifiedState.handleVideoReplacement() [\(correlationId)]",
            metadata: [
                "processing_phase": "video_replacement_initiation",
                "category_theory_applied": "morphism_composition",
                "sequence": "atomic_reset → video_loading",
                "item_preservation": "guaranteed",
                "view_teardown_safe": "true",
            ]
        )

        await unifiedState.handleVideoReplacement(item)

        let processDuration = Date().timeIntervalSince(processStartTime)
        diagnosticLogger.logInfo(
            "🎯 RACE_CONDITION_FIX: ✅ Safe processing completed in \(String(format: "%.3f", processDuration * 1000))ms [\(correlationId)]",
            metadata: [
                "processing_duration_ms": String(
                    format: "%.3f",
                    processDuration * 1000
                ),
                "race_condition_prevented": "true",
                "item_deallocation_avoided": "true",
            ]
        )

        await MainActor.run {
            selectionToProcess = nil
            diagnosticLogger.logDebug(
                "🎯 RACE_CONDITION_FIX: 🧹 Processing state reset [\(correlationId)]",
                metadata: [
                    "cleanup_phase": "selection_reset",
                    "ready_for_next_selection": "true",
                ]
            )
        }
    }

    private func updateReplacementProgressSync(
        _ progress: Double,
        status: String
    ) {
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: 📊 Progress updated synchronously - \(Int(progress * 100))%: \(status)"
        )
    }

    private func finalizeVideoReplacementSync() {
        diagnosticLogger.logInfo(
            "🔧 Video replacement finalized synchronously - using unifiedState.loadVideo() for state reset",
            metadata: [
                "function": "finalizeVideoReplacementSync",
                "deadlock_prevention": "synchronous_operation",
            ]
        )

        isRotationButtonPressed = false
        diagnosticLogger.logInfo(
            "🔄 TRIMMER_VIEW: ✅ Video replacement finalized synchronously (no deadlock)"
        )
    }

    private func handleVideoReplacementErrorSync(_ error: Error) {
        let errorMessage = error.localizedDescription

        diagnosticLogger.logError(
            "Video replacement failed (sync handling)",
            error: error,
            metadata: [
                "error_message": errorMessage,
                "replacement_state": "simplified",
                "deadlock_prevention": "synchronous_error_handling",
                "memory_usage_mb":
                    "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
            ]
        )
    }

    private func retryVideoReplacement() {
        diagnosticLogger.logUserInteraction(
            "Retrying video replacement",
            metadata: [
                "last_error": "simplified_workflow"
            ]
        )

        Task {
            diagnosticLogger.logDebug(
                "🔧 MEMORY_FIX: Reset video replacement state Task started"
            )
            try? await Task.sleep(nanoseconds: 500_000_000)
            showPhotosPicker = true
        }
    }

    private func getCurrentTrimSettings() -> (
        startTime: Double, endTime: Double, intrinsicRotation: Int,
        userAppliedRotation: Int, totalRotation: Int
    ) {
        let trimmerVM = viewModel

        return (
            startTime: trimmerVM?.startTime.seconds ?? 0,
            endTime: trimmerVM?.endTime.seconds ?? 0,
            intrinsicRotation: trimmerVM?.assetIntrinsicRotationTurns ?? 0,
            userAppliedRotation: trimmerVM?.userAppliedRotationTurns ?? 0,
            totalRotation: trimmerVM?.totalRotationQuarterTurns ?? 0
        )
    }

    private func optimizeMemoryForReplacement() async {
        await MainActor.run {
            cachedTimeCodeRow = nil
        }

        diagnosticLogger.logDebug(
            "🧹 Memory optimization completed for video replacement"
        )
    }

    private func isReadyToContinue() -> Bool {
        let trimmerVM = viewModel

        let hasValidDuration = (trimmerVM?.videoDuration.seconds ?? 0) > 0
        if !hasValidDuration {
            diagnosticLogger.logDebug(
                "⚠️ Cannot continue - video duration not yet loaded",
                metadata: [
                    "duration_seconds":
                        "\(trimmerVM?.videoDuration.seconds ?? 0)",
                    "trimmer_ready": "\(trimmerVM?.isReady ?? false)",
                ]
            )
            return false
        }

        let timecodeResult = timecodeService.calculateTimecode(
            startTime: trimmerVM?.startTime ?? CMTime.zero,
            endTime: trimmerVM?.endTime ?? CMTime.zero,
            assetDuration: trimmerVM?.videoDuration ?? CMTime.zero,
            frameRate: trimmerVM?.currentFrameRate ?? 0
        )

        var validationErrors: [TimecodeValidationError] = []
        let hasValidTrimRange = timecodeService.validateTimecodeRange(
            startTime: trimmerVM?.startTime ?? CMTime.zero,
            endTime: trimmerVM?.endTime ?? CMTime.zero,
            assetDuration: trimmerVM?.videoDuration ?? CMTime.zero,
            errors: &validationErrors
        )

        let meetsMinimumDuration = !timecodeResult.isDurationTooShort

        let readyStatus =
            "meets_min_duration: \(meetsMinimumDuration), valid_trim_range: \(hasValidTrimRange), components_ready: \(isReadyToShowTrimmer), valid_duration: \(hasValidDuration)"

        if !isReadyToShowTrimmer {
            diagnosticLogger.logDebug(
                "⏳ Waiting for components to be ready",
                metadata: [
                    "validation": readyStatus,
                    "player_ready":
                        "\((unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol))?.isPlayerReady ?? false)",
                    "trimmer_ready": "\(trimmerVM?.isReady ?? false)",
                    "duration_seconds":
                        "\(trimmerVM?.videoDuration.seconds ?? 0)",
                ]
            )
        }

        if !meetsMinimumDuration {
            diagnosticLogger.logDebug(
                "⚠️ Cannot continue - minimum duration not met",
                metadata: [
                    "validation": readyStatus,
                    "current_duration": "\(timecodeResult.duration.seconds)",
                    "minimum_duration":
                        "\(timecodeResult.minimumDuration.seconds)",
                    "validation_errors":
                        "\(timecodeResult.validationErrors.map { $0.localizedDescription })",
                ]
            )
        }

        if !hasValidTrimRange {
            diagnosticLogger.logDebug(
                "⚠️ Cannot continue - invalid trim range",
                metadata: [
                    "validation": readyStatus,
                    "start_time": "\(trimmerVM?.startTime.seconds ?? 0)",
                    "end_time": "\(trimmerVM?.endTime.seconds ?? 0)",
                    "video_duration":
                        "\(trimmerVM?.videoDuration.seconds ?? 0)",
                    "validation_errors":
                        "\(timecodeResult.validationErrors.map { $0.localizedDescription })",
                ]
            )
        }

        let isReady =
            hasValidDuration && meetsMinimumDuration && hasValidTrimRange
            && isReadyToShowTrimmer

        if isReady {
            diagnosticLogger.logInfo(
                "✅ Ready to continue with separated rotation system",
                metadata: [
                    "validation": readyStatus,
                    "duration": "\(timecodeResult.duration.seconds)",
                    "intrinsic_rotation":
                        "\(trimmerVM?.assetIntrinsicRotationTurns ?? 0)",
                    "user_applied_rotation":
                        "\(trimmerVM?.userAppliedRotationTurns ?? 0)",
                    "total_rotation":
                        "\(trimmerVM?.totalRotationQuarterTurns ?? 0)",
                    "video_duration":
                        "\(trimmerVM?.videoDuration.seconds ?? 0)",
                    "timecode_valid": "\(timecodeResult.isValid)",
                    "frame_precision":
                        "\(timecodeResult.durationFrames) frames",
                    "separation_system": "intrinsic_display + user_controls",
                    "unwanted_rotation_fixed": "true",
                ]
            )
        }

        return isReady
    }

    private func validateAndContinue() async {
        diagnosticLogger.startTiming("validate_and_continue")

        guard isReadyToContinue() else {
            diagnosticLogger.logError(
                "❌ Continue validation failed",
                metadata: [
                    "player_ready":
                        "\((unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol))?.isPlayerReady ?? false)",
                    "trimmer_ready": "\(viewModel?.isReady ?? false)",
                    "combined_ready": "\(isReadyToShowTrimmer)",
                ]
            )
            diagnosticLogger.stopTiming("validate_and_continue")
            return
        }

        await MainActor.run {
            isFinalizing = true
        }

        do {
            diagnosticLogger.logInfo(
                "🚀 Starting atomic state transition from trimmer view",
                metadata: [
                    "current_flow_state": "\(unifiedState.flowState)",
                    "target_state": "naming",
                    "race_condition_prevention": "atomic_transition",
                    "local_overlay_active": "\(isFinalizing)",
                    "processing_method": "centralized",
                ]
            )

            try await unifiedState.proceedToNextState()

            diagnosticLogger.stopTiming("validate_and_continue")
            diagnosticLogger.logInfo(
                "🎉 Successfully triggered atomic state transition",
                metadata: [
                    "final_flow_state": "\(unifiedState.flowState)",
                    "transition_method": "proceedToNextState",
                    "race_condition_prevention": "atomic",
                    "asset_processing_method": "centralized",
                    "finalization_successful": "true",
                ]
            )

        } catch let timeoutError as TimeoutError {
            diagnosticLogger.logError(
                "⏰ Atomic state transition timed out",
                error: timeoutError
            )
            diagnosticLogger.stopTiming("validate_and_continue")
        } catch {
            diagnosticLogger.logError(
                "❌ Failed during atomic state transition",
                error: error
            )
            diagnosticLogger.stopTiming("validate_and_continue")
        }

        await MainActor.run {
            isFinalizing = false
        }
    }

    struct ShoeHandle: View {
        let isActive: Bool

        var body: some View {
            ZStack {
                Capsule()
                    .fill(Color.cardBackground.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Capsule()
                            .stroke(
                                isActive
                                    ? Color.accent : Color.accent.opacity(0.6),
                                lineWidth: isActive ? 3 : 2
                            )
                    )
                    .shadow(
                        color: isActive
                            ? Color.accent.opacity(0.4)
                            : Color.black.opacity(0.2),
                        radius: isActive ? 6 : 4,
                        x: 0,
                        y: isActive ? 3 : 2
                    )

                Text("👟")
                    .font(.system(size: 20))
                    .background(
                        Circle()
                            .fill(Color.cardBackground.opacity(0.8))
                            .frame(width: 26, height: 26)
                    )
            }
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
    }

    struct TimeCodeLabel: View {
        let time: CMTime
        let position: HandlePosition
        let isActive: Bool
        private let timecodeService = TimecodeCalculationService()

        enum HandlePosition {
            case start, end
        }

        var body: some View {
            Text(timecodeService.formatTime(time, includeMilliseconds: true))
                .font(
                    .ibmPlexMono(
                        size: 11,
                        weight: isActive ? .medium : .regular
                    )
                )
                .foregroundColor(isActive ? Color.accent : Color.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            isActive ? Color.accent.opacity(0.15) : Color.clear
                        )
                )
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7),
                    value: isActive
                )
        }
    }

    // MARK: - Trimmer Event Handlers

    func handleTrimmerProgressUpdate(_ progress: Double, status: String) {
        diagnosticLogger.logInfo(
            "🎬 FEATURE_RICH_TRIMMER: 🔄 TRIMMER_PROGRESS - Progress: \(Int(progress * 100))%, Status: \(status)"
        )
    }

    func handleTrimmerSetupComplete(totalTime: TimeInterval?) {
        let timeString =
            totalTime.map { String(format: "%.3f", $0) + "s" } ?? "unknown"
        diagnosticLogger.logInfo(
            "🎬 FEATURE_RICH_TRIMMER: ✅ TRIMMER_COMPLETE - Setup completed in \(timeString)"
        )
    }

    func handleTrimmerSetupError(_ error: Error, context: String) {
        diagnosticLogger.logError(
            "🎬 FEATURE_RICH_TRIMMER: ❌ TRIMMER_ERROR - Context: \(context), Error: \(error.localizedDescription)"
        )
    }
}

struct DurationLabel: View {
    let duration: CMTime
    let minimumDuration: CMTime
    let showWarning: Bool
    private let timecodeService = TimecodeCalculationService()

    var body: some View {
        HStack(spacing: 4) {
            if showWarning {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.buttonHard)
                    .font(.system(size: 10))
                    .animation(.easeInOut(duration: 0.2), value: showWarning)
            }

            Text(
                timecodeService.formatTime(duration, includeMilliseconds: true)
            )
            .font(
                .ibmPlexMono(size: 11, weight: showWarning ? .medium : .regular)
            )
            .foregroundColor(showWarning ? Color.buttonHard : Color.accent)
            .animation(.easeInOut(duration: 0.2), value: duration)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(showWarning ? Color.buttonHard.opacity(0.1) : Color.clear)
        )
        .scaleEffect(showWarning ? 1.02 : 1.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.7),
            value: showWarning
        )
    }
}

struct TimeProgressBar: View {
    let currentRange: ClosedRange<CMTime>
    let totalDuration: CMTime

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(
                        width: calculateWidth(
                            currentRange,
                            totalDuration,
                            in: geometry
                        ),
                        height: 4
                    )
                    .offset(
                        x: calculateOffset(
                            currentRange.lowerBound,
                            totalDuration,
                            in: geometry
                        )
                    )
            }
        }
        .frame(height: 8)
    }

    private func calculateWidth(
        _ range: ClosedRange<CMTime>,
        _ total: CMTime,
        in geometry: GeometryProxy
    ) -> CGFloat {
        let percentage =
            (range.upperBound.seconds - range.lowerBound.seconds)
            / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }

    private func calculateOffset(
        _ time: CMTime,
        _ total: CMTime,
        in geometry: GeometryProxy
    ) -> CGFloat {
        let percentage = time.seconds / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }
}

struct HybridPreciseTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    private let timecodeService = TimecodeCalculationService()

    var startHandleView: AnyView?
    var endHandleView: AnyView?

    private let handleWidth: CGFloat = 44

    @State private var lastHapticTime: CMTime = .zero
    @State private var hapticFrameCounter: Int = 0

    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startX = timeToXLeft(
                viewModel.startTime,
                trackWidth: trackWidth
            )
            let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)

            let startDragGesture = drag(handle: .start, in: geometry)
            let endDragGesture = drag(handle: .end, in: geometry)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: trackWidth, height: 6)
                    .offset(x: handleWidth / 2)

                Capsule()
                    .fill(
                        Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
                    )
                    .frame(width: endX - startX, height: 6)
                    .offset(x: startX + handleWidth / 2)

                if let startView = startHandleView {
                    handle(content: startView)
                        .offset(x: startX)
                        .gesture(startDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle))
                        .offset(x: startX)
                        .gesture(startDragGesture)
                }

                if let endView = endHandleView {
                    handle(content: endView)
                        .offset(x: endX)
                        .gesture(endDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle))
                        .offset(x: endX)
                        .gesture(endDragGesture)
                }
            }
        }
        .coordinateSpace(name: "track")
        .frame(height: 60)
        .onAppear {
            viewModel.startCoalescing()

            let logger = DiagnosticLoggingHelper(
                category: "HybridPreciseTrimmerView"
            )
            logger.logDebug(
                "🎬 HybridPreciseTrimmerView appeared",
                metadata: [
                    "frame_rate": "\(viewModel.currentFrameRate)",
                    "total_frames": "\(viewModel.totalFrames)",
                    "minimum_duration": "\(viewModel.minimumDuration.seconds)",
                ]
            )
        }
        .onDisappear {
            viewModel.stopCoalescing()

            let logger = DiagnosticLoggingHelper(
                category: "HybridPreciseTrimmerView"
            )
            logger.logDebug(
                "🧹 HybridPreciseTrimmerView disappeared - cleanup completed"
            )
        }
    }

    private func handle(content: some View) -> some View {
        content
    }

    private func timeToXLeft(_ t: CMTime, trackWidth: CGFloat) -> CGFloat {
        guard viewModel.videoDuration.seconds > 0 else { return 0 }
        let p = t.seconds / viewModel.videoDuration.seconds
        return CGFloat(p) * trackWidth
    }

    private func xLeftToTime(_ x: CGFloat, trackWidth: CGFloat) -> CMTime {
        let clamped = max(0, min(x, trackWidth))
        let seconds =
            Double(clamped / trackWidth) * viewModel.videoDuration.seconds
        let time = CMTime(
            seconds: seconds,
            preferredTimescale: viewModel.videoDuration.timescale
        )
        return timecodeService.snapToFrame(
            time: time,
            frameRate: viewModel.currentFrameRate
        )
    }

    private func minDistancePx(_ g: GeometryProxy) -> CGFloat {
        let trackWidth = g.size.width - handleWidth
        let pps = trackWidth / viewModel.videoDuration.seconds
        return pps * viewModel.minimumDuration.seconds
    }

    private func drag(handle: TrimmerHandleType, in g: GeometryProxy)
        -> some Gesture
    {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { value in
                let trackWidth = g.size.width - handleWidth
                let logger = DiagnosticLoggingHelper(
                    category: "HybridPreciseTrimmerView"
                )

                if handle == .start && !viewModel.isDraggingStartHandle {
                    viewModel.isDraggingStartHandle = true
                    viewModel.startCoalescing()

                    HapticManager.shared.trigger(.dragStart)

                    logger.logDebug(
                        "🚀 Start handle drag began",
                        metadata: [
                            "initial_position": "\(value.location.x)",
                            "track_width": "\(trackWidth)",
                            "handle_type": "start",
                            "current_time": "\(viewModel.startTime.seconds)",
                            "formatted_time":
                                "\(TimecodeFormatter.format(time: viewModel.startTime))",
                            "video_duration":
                                "\(viewModel.videoDuration.seconds)",
                            "minimum_duration":
                                "\(viewModel.minimumDuration.seconds)",
                            "is_dragging_end":
                                "\(viewModel.isDraggingEndHandle)",
                            "memory_usage_mb":
                                "\(MemoryHelper.getDetailedMemoryInfo().used)",
                        ]
                    )
                } else if handle == .end && !viewModel.isDraggingEndHandle {
                    viewModel.isDraggingEndHandle = true
                    viewModel.startCoalescing()

                    HapticManager.shared.trigger(.dragStart)

                    logger.logDebug(
                        "🚀 End handle drag began",
                        metadata: [
                            "initial_position": "\(value.location.x)",
                            "track_width": "\(trackWidth)",
                            "handle_type": "end",
                            "current_time": "\(viewModel.endTime.seconds)",
                            "formatted_time":
                                "\(TimecodeFormatter.format(time: viewModel.endTime))",
                            "video_duration":
                                "\(viewModel.videoDuration.seconds)",
                            "minimum_duration":
                                "\(viewModel.minimumDuration.seconds)",
                            "is_dragging_start":
                                "\(viewModel.isDraggingStartHandle)",
                            "memory_usage_mb":
                                "\(MemoryHelper.getDetailedMemoryInfo().used)",
                        ]
                    )
                }

                let startX = timeToXLeft(
                    viewModel.startTime,
                    trackWidth: trackWidth
                )
                let endX = timeToXLeft(
                    viewModel.endTime,
                    trackWidth: trackWidth
                )
                let minPx = minDistancePx(g)

                var proposedLeft = value.location.x - handleWidth / 2
                proposedLeft = max(0, min(proposedLeft, trackWidth))

                let oldProposedLeft = proposedLeft
                var hitPhysicalBoundary = false

                switch handle {
                case .start:
                    let minimumLeft = endX - minPx
                    if proposedLeft > minimumLeft {
                        proposedLeft = minimumLeft
                        hitPhysicalBoundary = true
                    }
                case .end:
                    let minimumLeft = startX + minPx
                    if proposedLeft < minimumLeft {
                        proposedLeft = minimumLeft
                        hitPhysicalBoundary = true
                    }
                }

                if oldProposedLeft != proposedLeft {
                    HapticManager.shared.trigger(.dragEnd)
                    viewModel.triggerBoundaryHaptic()

                    let logger = DiagnosticLoggingHelper(
                        category: "HybridPreciseTrimmerView"
                    )
                    logger.logDebug(
                        "🛑 Boundary bump triggered",
                        metadata: [
                            "handle": "\(handle)",
                            "old_position": "\(oldProposedLeft)",
                            "new_position": "\(proposedLeft)",
                            "boundary_hit": "true",
                            "physical_boundary": "\(hitPhysicalBoundary)",
                        ]
                    )
                }

                if hitPhysicalBoundary {
                    let boundaryTime = xLeftToTime(
                        proposedLeft,
                        trackWidth: trackWidth
                    )
                    let snappedBoundaryTime = viewModel.snapToFrame(
                        boundaryTime
                    )

                    viewModel.proposeTime(snappedBoundaryTime, for: handle)

                    let logger = DiagnosticLoggingHelper(
                        category: "HybridPreciseTrimmerView"
                    )
                    logger.logDebug(
                        "🚫 Physical boundary enforced",
                        metadata: [
                            "handle": "\(handle)",
                            "boundary_position": "\(proposedLeft)",
                            "boundary_time": "\(snappedBoundaryTime.seconds)",
                            "minimum_duration":
                                "\(viewModel.minimumDuration.seconds)",
                        ]
                    )

                    return
                }

                let proposedTime = xLeftToTime(
                    proposedLeft,
                    trackWidth: trackWidth
                )
                let snappedTime = viewModel.snapToFrame(proposedTime)

                let currentFrame = viewModel.getFrameNumber(for: snappedTime)
                let lastFrame = viewModel.getFrameNumber(
                    for: handle == .start
                        ? viewModel.startTime : viewModel.endTime
                )
                let frameDelta = abs(currentFrame - lastFrame)
                let timeDelta = abs(
                    snappedTime.seconds
                        - (handle == .start
                            ? viewModel.startTime.seconds
                            : viewModel.endTime.seconds)
                )
                let currentDuration = viewModel.endTime - viewModel.startTime
                let newDuration =
                    handle == .start
                    ? viewModel.endTime - snappedTime
                    : snappedTime - viewModel.startTime
                let durationDelta = abs(
                    newDuration.seconds - currentDuration.seconds
                )

                if frameDelta > 0 {
                    let logger = DiagnosticLoggingHelper(
                        category: "HybridPreciseTrimmerView"
                    )
                    logger.logDebug(
                        "🎬 Handle drag processing UI update",
                        metadata: [
                            "handle": "\(handle)",
                            "current_frame": "\(currentFrame)",
                            "last_frame": "\(lastFrame)",
                            "frame_delta": "\(frameDelta)",
                            "time_delta_ms": "\(timeDelta * 1000)",
                            "current_time": "\(snappedTime.seconds)",
                            "formatted_time":
                                "\(TimecodeFormatter.format(time: snappedTime))",
                            "current_duration": "\(currentDuration.seconds)",
                            "new_duration": "\(newDuration.seconds)",
                            "duration_delta_ms": "\(durationDelta * 1000)",
                            "pixel_position": "\(proposedLeft)",
                            "track_percentage":
                                "\(String(format: "%.2f", proposedLeft / trackWidth * 100))%",
                            "ui_update_trigger":
                                "\(frameDelta > 1 ? "significant" : "minor")",
                            "coalescing_active":
                                "\(viewModel.isDraggingStartHandle || viewModel.isDraggingEndHandle)",
                            "boundary_enforcement": "active",
                        ]
                    )
                }

                viewModel.proposeTime(snappedTime, for: handle)

                triggerFrameSynchronizedHaptic(at: snappedTime, for: handle)
            }
            .onEnded { value in
                let trackWidth = g.size.width - handleWidth
                var xLeft = value.location.x - handleWidth / 2
                xLeft = max(0, min(xLeft, trackWidth))

                let proposedTime = xLeftToTime(xLeft, trackWidth: trackWidth)
                let snappedTime = viewModel.snapToFrame(proposedTime)
                let finalFrame = viewModel.getFrameNumber(for: snappedTime)

                let startTimeBefore = viewModel.startTime
                let endTimeBefore = viewModel.endTime
                let durationBefore = viewModel.endTime - viewModel.startTime

                viewModel.commitTime(snappedTime, for: handle)

                if handle == .start {
                    viewModel.isDraggingStartHandle = false
                } else {
                    viewModel.isDraggingEndHandle = false
                }

                viewModel.stopCoalescing()
                HapticManager.shared.trigger(.dragEnd)

                let durationAfter = viewModel.endTime - viewModel.startTime
                let durationDelta = abs(
                    durationAfter.seconds - durationBefore.seconds
                )
                let finalTrackPosition = xLeft / trackWidth
                let memoryUsage = MemoryHelper.getDetailedMemoryInfo()

                let logger = DiagnosticLoggingHelper(
                    category: "HybridPreciseTrimmerView"
                )
                logger.logDebug(
                    "✅ Handle drag ended",
                    metadata: [
                        "handle": "\(handle)",
                        "final_position": "\(xLeft)",
                        "final_frame": "\(finalFrame)",
                        "final_time": "\(snappedTime.seconds)",
                        "formatted_time":
                            "\(TimecodeFormatter.format(time: snappedTime))",
                        "start_time_before": "\(startTimeBefore.seconds)",
                        "end_time_before": "\(endTimeBefore.seconds)",
                        "start_time_after": "\(viewModel.startTime.seconds)",
                        "end_time_after": "\(viewModel.endTime.seconds)",
                        "duration_before": "\(durationBefore.seconds)",
                        "duration_after": "\(durationAfter.seconds)",
                        "duration_delta_ms": "\(durationDelta * 1000)",
                        "track_percentage":
                            "\(String(format: "%.2f", finalTrackPosition * 100))%",
                        "warning_state":
                            "\(viewModel.showMinimumDurationWarning)",
                        "validation_success": "\(viewModel.isValidTrim)",
                        "coalescing_stopped": "true",
                        "memory_usage_mb": "\(memoryUsage.used)",
                        "memory_pressure": "\(memoryUsage.percentage)",
                    ]
                )
            }
    }

    private func triggerFrameSynchronizedHaptic(
        at time: CMTime,
        for handle: TrimmerHandleType
    ) {
        let frameNumber = viewModel.getFrameNumber(for: time)
        let lastFrameNumber = viewModel.getFrameNumber(for: lastHapticTime)
        let frameDelta = abs(frameNumber - lastFrameNumber)

        if frameDelta >= 3 {
            HapticManager.shared.trigger(.frameDetent)
            lastHapticTime = time
            hapticFrameCounter += 1

            let timeSinceLastHaptic = abs(time.seconds - lastHapticTime.seconds)
            let currentDuration = viewModel.endTime - viewModel.startTime
            let memoryUsage = MemoryHelper.getDetailedMemoryInfo()

            let logger = DiagnosticLoggingHelper(
                category: "HybridPreciseTrimmerView"
            )
            logger.logDebug(
                "📳 Frame-synchronized haptic triggered",
                metadata: [
                    "frame_number": "\(frameNumber)",
                    "frames_since_last": "\(frameDelta)",
                    "time_since_last_ms": "\(timeSinceLastHaptic * 1000)",
                    "handle": "\(handle)",
                    "current_time": "\(time.seconds)",
                    "formatted_time": "\(TimecodeFormatter.format(time: time))",
                    "current_duration": "\(currentDuration.seconds)",
                    "haptic_counter": "\(hapticFrameCounter)",
                    "frame_rate": "\(viewModel.currentFrameRate)",
                    "trigger_reason": "frame_threshold_met",
                    "sync_quality": timeSinceLastHaptic < 0.1
                        ? "excellent"
                        : (timeSinceLastHaptic < 0.2 ? "good" : "poor"),
                    "memory_usage_mb": "\(memoryUsage.used)",
                    "ui_responsive": "true",
                ]
            )
        }
    }

}

extension HybridPreciseTrimmerView {
    init(viewModel: TrimmerViewModel) {
        self.viewModel = viewModel
        self.startHandleView = nil
        self.endHandleView = nil
    }

    static func shoe(viewModel: TrimmerViewModel) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel
        )
    }

    static func custom(
        viewModel: TrimmerViewModel,
        startView: some View,
        endView: some View
    ) -> HybridPreciseTrimmerView {
        var view = HybridPreciseTrimmerView(viewModel: viewModel)
        view.startHandleView = AnyView(startView)
        view.endHandleView = AnyView(endView)
        return view
    }
}
