import SwiftUI
import AVKit
import Combine
import OSLog
import PhotosUI

// MARK: - Timeout Error
struct TimeoutError: Error, LocalizedError {
    let seconds: Double

    var errorDescription: String? {
        return "Operation timed out after \(seconds) seconds"
    }

    var recoverySuggestion: String? {
        return "Please try again or check your network connection"
    }
}


// MARK: - HandleType Usage
// Using public TrimmerHandleType from TrimmerViewModel to avoid duplication


// MARK: - Isolated Trimmer Player View
/// A stable view that handles both video player display and loading state.
/// By having a stable identity, we eliminate SwiftUI view churn during state changes.
struct TrimmerPlayerView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    let isReady: Bool
    let previewRotationDegrees: Double

    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "TrimmerPlayerView")
    
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
    
    // MARK: - Computed Properties
    private var shouldShowVideoPlayer: Bool {
        return isReady && unifiedState.currentPlayerViewModel != nil
    }
    
    // MARK: - View Content
    private var videoPlayerContent: some View {
        Group {
            if unifiedState.currentPlayerViewModel != nil {
                videoPlayerWithContent
            } else {
                EmptyView()
            }
        }
    }
    
    private var videoPlayerWithContent: some View {
        CustomVideoPlayerView(
            viewModel: unifiedState.currentPlayerViewModel as! any VideoPlayerViewModelProtocol,
            shouldAutoplay: false
        )
        .rotationEffect(.degrees(previewRotationDegrees))
        .animation(.easeInOut(duration: 0.3), value: previewRotationDegrees)
        .onAppear {
            let playerViewModel = unifiedState.currentPlayerViewModel as! any VideoPlayerViewModelProtocol
            let message = "🎬 TRIMMER_PLAYER_VIEW: Showing video player - isReady: \(isReady), playerState: \(playerViewModel.state), rotation: \(unifiedState.rotationQuarterTurns), preview_degrees: \(previewRotationDegrees)"
            logger.info("\(message)")
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
            let logMessage = "🎬 TRIMMER_PLAYER_VIEW: Showing Finalizing placeholder - isReady: \(isReady), flowState: \(unifiedState.flowState), playerVM: \(unifiedState.currentPlayerViewModel != nil)"
            logger.info("\(logMessage)")
        }
    }
}

// MARK: - Unified Feature-Rich Trimmer View
struct FeatureRichTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    let unifiedState: AddMoveUnifiedState // No longer observed, just for actions
    private let timecodeService = TimecodeCalculationService()

    // MARK: - Video Replacement State
    @State private var showPhotosPicker = false
    @State private var tempVideoSelection: PhotosUI.PhotosPickerItem?
    @State private var showChangeVideoConfirmation = false
    @State private var isVideoReplacementInProgress = false
    @State private var videoReplacementProgress: Double = 0.0
    @State private var videoReplacementStatus: String = ""
    @State private var lastVideoReplacementError: String?
    
    // MARK: - Video Replacement System
    
    private enum VideoReplacementState {
        case idle
        case confirming
        case preparing(progress: Double, status: String)
        case replacing(progress: Double, status: String)
        case finalizing(progress: Double, status: String)
        case ready
        case error(String)
    }
    
    @State private var videoReplacementState: VideoReplacementState = .idle
    
    // MARK: - Performance Optimization
    @State private var previewRotationDegrees: Double = 0.0
    @State private var cachedTimeCodeRow: (startTime: CMTime, endTime: CMTime, isDraggingStart: Bool, isDraggingEnd: Bool)?
    @State private var isRotationButtonPressed: Bool = false

    // MARK: - Local Loading State for Deadlock Prevention
    @State private var isFinalizing = false

    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "FeatureRichTrimmer")
    
    // MARK: - Performance Memoization
    private var rotationBinding: Binding<Int> {
        Binding(
            get: { viewModel.rotationQuarterTurns },
            set: { newValue in
                let oldValue = viewModel.rotationQuarterTurns
                // 🎯 CRITICAL FIX: Only update ViewModel state, don't trigger video rebuild
                viewModel.rotationQuarterTurns = newValue
                // Update local preview state for instant UI feedback
                previewRotationDegrees = Double(newValue * 90)

                // 🎯 DIAGNOSTIC: Log rotation changes for debugging state synchronization
                if oldValue != newValue {
                    diagnosticLogger.logUserInteraction("Rotation changed via binding", metadata: [
                        "old_rotation": "\(oldValue)",
                        "new_rotation": "\(newValue)",
                        "preview_degrees": "\(previewRotationDegrees)",
                        "unified_state_rotation": "\(unifiedState.rotationQuarterTurns)",
                        "binding_source": "rotation_button"
                    ])
                }
            }
        )
    }
    
    // MARK: - Declarative Readiness Check
    private var isReadyToShowTrimmer: Bool {
        // 🎯 CRITICAL FIX: With the new state machine, flowState == .trimming guarantees
        // that all async setup (including TrimmerViewModel) is complete and ready.
        // This eliminates the race condition between state transition and readiness checks.
        let isReady = unifiedState.flowState == .trimming
        
        // 🎯 SIMPLIFIED LOGGING: Only log when not ready for debugging
        if !isReady {
            diagnosticLogger.logWarning("⚠️ Trimmer not ready - simplified check", metadata: [
                "flow_state": "\(unifiedState.flowState)",
                "expected_state": "trimming",
                "timestamp": "\(Date())"
            ])
        }
        
        return isReady
    }
    
    // MARK: - Enhanced Time Code Display with Direct Text Views
    private var timeCodeRow: some View {
        Group {
            let trimmerVM = viewModel
            HStack {
                    // START TIME
                    Text(TimecodeFormatter.format(time: trimmerVM.startTime))
                        .font(.ibmPlexMono(size: 12, weight: trimmerVM.isDraggingStartHandle ? .medium : .regular))
                        .foregroundColor(trimmerVM.isDraggingStartHandle ? .accent : .textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: trimmerVM.isDraggingStartHandle)
                        .animation(.default, value: trimmerVM.startTime)

                    Spacer()

                    // DURATION
                    Text(TimecodeFormatter.format(time: trimmerVM.endTime - trimmerVM.startTime))
                        .font(.ibmPlexMono(size: 12, weight: trimmerVM.showMinimumDurationWarning ? .medium : .regular))
                        .foregroundColor(trimmerVM.showMinimumDurationWarning ? .buttonHard : .textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: trimmerVM.showMinimumDurationWarning)
                        .animation(.default, value: trimmerVM.startTime)
                        .animation(.default, value: trimmerVM.endTime)

                    Spacer()

                    // END TIME
                    Text(TimecodeFormatter.format(time: trimmerVM.endTime))
                        .font(.ibmPlexMono(size: 12, weight: trimmerVM.isDraggingEndHandle ? .medium : .regular))
                        .foregroundColor(trimmerVM.isDraggingEndHandle ? .accent : .textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: trimmerVM.isDraggingEndHandle)
                        .animation(.default, value: trimmerVM.endTime)
                }
            }
    }

    // MARK: - Timecode Display Components

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

    // MARK: - Legacy Force Synchronization Methods (Removed - SwiftUI handles updates naturally)
    
    init(unifiedState: AddMoveUnifiedState, viewModel: TrimmerViewModel) {
        self.unifiedState = unifiedState
        self.viewModel = viewModel

        // 🎯 CRITICAL FIX: Only log initialization once
        // SwiftUI may recreate views during state changes, but we only want one initialization log
        let logger = DiagnosticLoggingHelper(category: "FeatureRichTrimmerView")
        logger.logInfo("🎬 FeatureRichTrimmerView initialized successfully", metadata: [
            "player_ready": "\(viewModel.playerViewModel.isPlayerReady)",
            "trimmer_ready": "\(viewModel.isReady)",
            "player_state": "\(viewModel.playerViewModel.state)"
        ])
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                // MARK: - Video Player Section with Replacement Support
                Group {
                    if isVideoReplacementInProgress {
                        videoReplacementView
                    } else {
                        // TrimmerPlayerView is now created unconditionally to give it a stable identity.
                        // The loading logic is moved inside it.
                        TrimmerPlayerView(
                            unifiedState: unifiedState,
                            isReady: isReadyToShowTrimmer,
                            previewRotationDegrees: previewRotationDegrees
                        )
                    }
                }
                // MARK: - Enhanced Trimmer Interface
                Spacer()
                VStack(spacing: 8) {
                    Spacer()
                    // Minimum duration warning (positioned above timecode for better visibility)
                    if viewModel.showMinimumDurationWarning == true {
                    minimumDurationWarning
                }

                // Time code display
                timeCodeDisplay

                // Main trimmer with shoe handles
                mainTrimmerSection

                // Enhanced controls
                controlSection
                Spacer()
            }
            .padding(10)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            let playerViewModel = unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol)
            diagnosticLogger.logInfo("🎬 Body appeared", metadata: [
                "trimmer_vm_available": "true",
                "trimmer_vm_ready": "\(viewModel.isReady)",
                "show_warning": "\(viewModel.showMinimumDurationWarning)",
                "player_ready": "\(playerViewModel?.isPlayerReady ?? false)",
                "combined_ready": "\(isReadyToShowTrimmer)"
            ])

            // 🎯 CRITICAL FIX: Synchronize the local preview rotation with the view model's state.
            // This ensures that when returning from the naming view, the visual rotation
            // correctly reflects the preserved rotation value from the view model.
            let newRotationDegrees = Double(viewModel.rotationQuarterTurns * 90)
            if previewRotationDegrees != newRotationDegrees {
                diagnosticLogger.logInfo("🔄 ROTATION_SYNC: Synchronizing preview rotation on view appearance", metadata: [
                    "previous_degrees": "\(previewRotationDegrees)",
                    "target_degrees": "\(newRotationDegrees)",
                    "vm_rotation_turns": "\(viewModel.rotationQuarterTurns)",
                    "unified_state_rotation": "\(unifiedState.rotationQuarterTurns)",
                    "sync_source": "onAppear"
                ])
                previewRotationDegrees = newRotationDegrees
            }
        }
            .onDisappear {
                diagnosticLogger.logInfo("🧹 Body disappeared; cleanup completed")
            }

            // 🎯 CRITICAL: Local loading overlay preserves render layer during async operations
            if isFinalizing {
                LoadingOverlayView(progress: SimpleProgress(value: 0.8, message: "Creating asset..."), unifiedState: unifiedState)
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: Binding(
                get: { tempVideoSelection },
                set: { newItem in
                    if let newItem = newItem {
                        handleVideoSelection(newItem)
                    }
                    tempVideoSelection = newItem
                }
            ),
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .confirmationDialog("Change Video", isPresented: $showChangeVideoConfirmation) {
            Button("Change Video", role: .destructive) {
                beginVideoReplacementProcess()
            }
            Button("Cancel", role: .cancel) {
                videoReplacementState = .idle
            }
        } message: {
            Text("You have unsaved trim changes. Changing videos will discard these changes.")
        }

        // MARK: - NEW: State-Driven Alert
        // Add this modifier to the main VStack or parent container.
        .alert("Minimum Duration", isPresented: Binding(
            get: { viewModel.showMinDurationAlert },
            set: { newValue in
                if !newValue {
                    // Allow the user to dismiss the alert.
                    viewModel.showMinDurationAlert = false
                }
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            // Precise and clear messaging.
            Text("The minimum video duration is 3.000 seconds.")
        }
    }
    
    
    
    // MARK: - Time Code Display
    private var timeCodeDisplay: some View {
        VStack(spacing: 12) {
            self.timeCodeRow
        }
        .onAppear(perform: onTimeCodeDisplayAppear)
    }
    
    private func onTimeCodeDisplayAppear() {
        let trimmerVM = viewModel
        diagnosticLogger.logInfo("⏰ Time code display appeared", metadata: [
            "start_time_seconds": "\(CMTimeGetSeconds(trimmerVM.startTime))",
            "end_time_seconds": "\(CMTimeGetSeconds(trimmerVM.endTime))",
            "show_warning": "\(trimmerVM.showMinimumDurationWarning)"
        ])
    }
    
    // MARK: - Optimized Control Section
    private var controlSection: some View {
        let trimmerVM = viewModel
        let currentRotation = trimmerVM.rotationQuarterTurns
        let isExporting = trimmerVM.isExporting
        
        return HStack(spacing: 20) {
            Button("Change Video") {
                HapticManager.shared.trigger(.dragEnd)
                startVideoReplacement()
            }
            .buttonStyle(.appSecondary(size: .medium))
            .disabled(isVideoReplacementInProgress)
            
            Button(action: {
                HapticManager.shared.trigger(.frameDetent)
                let newRotation = (currentRotation + 1) % 4
                diagnosticLogger.logUserInteraction("Rotation button tapped", metadata: [
                    "button_type": "rotation",
                    "current_rotation": "\(currentRotation)",
                    "target_rotation": "\(newRotation)",
                    "current_preview_degrees": "\(previewRotationDegrees)",
                    "vm_rotation": "\(viewModel.rotationQuarterTurns)",
                    "unified_state_rotation": "\(unifiedState.rotationQuarterTurns)"
                ])

                // 🎯 CRITICAL FIX: Instant lightweight rotation preview
                // Update ViewModel state without triggering video rebuild
                viewModel.rotationQuarterTurns = newRotation
                previewRotationDegrees = Double(newRotation * 90)

                diagnosticLogger.logDebug("✅ LIGHTWEIGHT_ROTATION: Applied instant preview rotation", metadata: [
                    "new_rotation": "\(newRotation)",
                    "preview_degrees": "\(previewRotationDegrees)",
                    "vm_rotation_after": "\(viewModel.rotationQuarterTurns)",
                    "unified_state_rotation_after": "\(unifiedState.rotationQuarterTurns)",
                    "video_rebuild_triggered": "false"
                ])
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 16, weight: .medium))
                        .rotationEffect(.degrees(Double(currentRotation * 90)))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentRotation)
                    
                    Text("\(currentRotation * 90)°")
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentRotation)
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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRotationButtonPressed)
            }
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isRotationButtonPressed = pressing
                }
            }, perform: {})
            
            Button("Continue") {
                HapticManager.shared.trigger(.dragEnd)
                diagnosticLogger.logUserInteraction("Continue button tapped", metadata: [
                    "button_type": "continue",
                    "current_rotation": "\(currentRotation)",
                    "exporting": "\(isExporting)"
                ])
                
                Task {
                    // Structs don't need weak references - they're value types
                    diagnosticLogger.logDebug("🔧 MEMORY_FIX: Continue button Task started")
                    await validateAndContinue()
                }
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(isExporting || !isReadyToContinue())
        }
        .padding()
        .onAppear {
            diagnosticLogger.logInfo("🎮 Control section appeared", metadata: [
                "rotation": "\(currentRotation)",
                "exporting": "\(isExporting)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
        }
        // .overlay(
        //     Text("DEBUG: Controls")
        //         .font(.caption)
        //         .foregroundColor(.green)
        //         .background {
        //             Rectangle()
        //                 .fill(Color.black.opacity(0.7))
        //         }
        //         .padding(2),
        //     alignment: .topLeading
        // )
    }
    
    // MARK: - Main Trimmer Section
    private var mainTrimmerSection: some View {
        Group {
            let trimmerViewModel = viewModel
                HybridPreciseTrimmerView.shoe(viewModel: trimmerViewModel)
                    .onAppear(perform: onMainTrimmerAppear)
            }
    }
    
    private func onMainTrimmerAppear() {
        let videoDuration = viewModel.videoDuration
        diagnosticLogger.logInfo("🎚 Main trimmer section appeared", metadata: [
            "video_duration_seconds": "\(CMTimeGetSeconds(videoDuration))",
            "cpu_usage_percent": "\(String(format: "%.1f", diagnosticLogger.getCurrentCPUUsage()))"
        ])
    }
    
    // MARK: - Optimized Logging (Legacy - maintained for compatibility)
    private func logInfo(_ message: String) {
        diagnosticLogger.logInfo(message)
    }
    
    // MARK: - Enhanced Minimum Duration Warning
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
                    let duration = trimmerViewModel.endTime - trimmerViewModel.startTime
                    let minimum = trimmerViewModel.minimumDuration

                    Text("Current: \(timecodeService.formatTime(duration, includeMilliseconds: true)) • Minimum: \(timecodeService.formatTime(minimum, includeMilliseconds: true))")
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
            let duration = trimmerViewModel.endTime - trimmerViewModel.startTime
            let minimum = trimmerViewModel.minimumDuration
            let durationSeconds = duration.seconds
            let minimumSeconds = minimum.seconds
            diagnosticLogger.logWarning("⚠️ Enhanced minimum duration warning appeared", metadata: [
                "duration_seconds": "\(durationSeconds)",
                "minimum_seconds": "\(minimumSeconds)",
                "is_below_minimum": "\(durationSeconds < minimumSeconds)",
                "warning_type": "enhanced_visual_feedback"
            ])
        }
    }
    
    // MARK: - Video Replacement View
    private var videoReplacementView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            switch videoReplacementState {
            case .preparing(let progress, let status):
                replacementProgressView(progress: progress, status: status, icon: "gearshape.fill")
            case .replacing(let progress, let status):
                replacementProgressView(progress: progress, status: status, icon: "arrow.triangle.2.circlepath")
            case .finalizing(let progress, let status):
                replacementProgressView(progress: progress, status: status, icon: "checkmark.circle.fill")
            case .error(let errorMessage):
                replacementErrorView(message: errorMessage)
            default:
                replacementLoadingView()
            }
            
            Spacer()
        }
        .frame(height: 300)
        .background(Color.black.ignoresSafeArea())
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func replacementProgressView(progress: Double, status: String, icon: String) -> some View {
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
    
    // MARK: - Enhanced Video Replacement Methods
    
    private func hasUnsavedChanges() -> Bool {
        let trimmerVM = viewModel
        
        // Check if trim ranges have been modified from defaults
        let hasTrimChanges = trimmerVM.startTime.seconds > 0 ||
        trimmerVM.endTime.seconds < trimmerVM.videoDuration.seconds
        
        // Check if rotation has been changed from default
        let hasRotationChanges = trimmerVM.rotationQuarterTurns > 0
        
        return hasTrimChanges || hasRotationChanges
    }
    
    private func startVideoReplacement() {
        diagnosticLogger.logUserInteraction("Video replacement initiated", metadata: [
            "has_unsaved_changes": "\(hasUnsavedChanges())",
            "current_video_duration": "\(viewModel.videoDuration.seconds)",
            "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
        ])
        
        if hasUnsavedChanges() {
            videoReplacementState = .confirming
            showChangeVideoConfirmation = true
        } else {
            beginVideoReplacementProcess()
        }
    }
    
    private func beginVideoReplacementProcess() {
        isVideoReplacementInProgress = true
        videoReplacementState = .preparing(progress: 0.0, status: "Preparing video replacement...")
        
        Task {
            // Structs don't need weak references - they're value types
            diagnosticLogger.logDebug("🔧 MEMORY_FIX: Video replacement Task started")
            await performVideoReplacement()
        }
    }
    
    private func performVideoReplacement() async {
        diagnosticLogger.startTiming("video_replacement")
        
        do {
            // Phase 1: Preparation
            try await prepareVideoReplacement()
            
            // Phase 2: Show picker
            await showVideoPicker()
            
        } catch {
            await handleVideoReplacementError(error)
        }
    }
    
    private func prepareVideoReplacement() async throws {
        await updateReplacementProgress(0.2, status: "Validating current state...")
        
        // Validate current state can be safely replaced
        guard unifiedState.currentPlayerViewModel != nil else {
            throw NSError(domain: "FeatureRichTrimmerView", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No current video player available"
            ])
        }
        
        await updateReplacementProgress(0.4, status: "Saving current state...")

        // Save current trim settings for potential restoration
        _ = getCurrentTrimSettings()
        
        await updateReplacementProgress(0.6, status: "Preparing video picker...")
        
        // Memory optimization before loading new video
        await optimizeMemoryForReplacement()
        
        await updateReplacementProgress(0.8, status: "Ready for selection...")
        
        diagnosticLogger.logInfo("✅ Video replacement preparation completed")
    }
    
    private func showVideoPicker() async {
        await MainActor.run {
            videoReplacementState = .ready
            showPhotosPicker = true
        }
    }
    
    private func handleVideoSelection(_ item: PhotosUI.PhotosPickerItem) {
        diagnosticLogger.logUserInteraction("Video selected for replacement", metadata: [
            "item_identifier": "\(item.itemIdentifier ?? "unknown")",
            "current_progress": "\(videoReplacementProgress)"
        ])

        // Start replacement process
        Task {
            // Structs don't need weak references - they're value types
            diagnosticLogger.logDebug("🔧 MEMORY_FIX: Process video replacement Task started")
            await processVideoReplacement(item)
        }
    }
    
    private func processVideoReplacement(_ item: PhotosUI.PhotosPickerItem) async {
        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 🚀 Starting video replacement process")
        isVideoReplacementInProgress = true
        videoReplacementState = .replacing(progress: 0.0, status: "Loading new video...")

        do {
            // Phase 1: Load new video
            diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 📥 Phase 1 - Loading new video")
            await updateReplacementProgress(0.2, status: "Transferring video...")

            // Load the new video through unified state by converting to custom type
            let customItem = PhotosPickerItem(item: item)
            // ✨ FIX: Use the new dedicated replacement method instead of didSelectVideo
            diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 🎯 Calling replaceSelectedVideo method")
            await unifiedState.replaceSelectedVideo(customItem)

            // Phase 2: Wait for video to be ready
            diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ⏳ Phase 2 - Waiting for video to be ready")
            await updateReplacementProgress(0.5, status: "Processing video...")

            diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 🔍 Waiting for unified state to reach trimming with ready player")
            try await waitForVideoReady()
            
            // Phase 3: Finalize replacement
            await updateReplacementProgress(0.8, status: "Finalizing replacement...")
            
            await finalizeVideoReplacement()
            
            await updateReplacementProgress(1.0, status: "Replacement complete!")
            
            // Brief delay to show completion
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Reset state
            await resetVideoReplacementState()
            
            diagnosticLogger.stopTiming("video_replacement")
            diagnosticLogger.logInfo("✅ Video replacement completed successfully")
            
        } catch {
            await handleVideoReplacementError(error)
        }
    }
    
    private func waitForVideoReady() async throws {
        let timeout: TimeInterval = 30.0
        let startTime = Date()

        diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ⏱️ Starting video readiness check with \(timeout)s timeout")

        while Date().timeIntervalSince(startTime) < timeout {
            let currentState = unifiedState.flowState
            let hasPlayer = unifiedState.currentPlayerViewModel != nil

            diagnosticLogger.logDebug("🔄 TRIMMER_VIEW: 🔍 Checking readiness - State: \(currentState), Player: \(hasPlayer)")

            // Check if video is ready
            if currentState == .trimming && hasPlayer {

                let isPlayerReady = (unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol))?.isPlayerReady ?? false
                let isTrimmerReady = viewModel.isReady

                diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: ✅ Conditions met - PlayerReady: \(isPlayerReady), TrimmerReady: \(isTrimmerReady)")

                if isPlayerReady && isTrimmerReady {
                    diagnosticLogger.logInfo("✅ Video ready after replacement")
                    diagnosticLogger.logInfo("🔄 TRIMMER_VIEW: 🎉 Video replacement successful!")
                    return
                }
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        diagnosticLogger.logError("🔄 TRIMMER_VIEW: ⏰ Video replacement timed out after \(timeout)s")
        throw NSError(domain: "FeatureRichTrimmerView", code: -2, userInfo: [
            NSLocalizedDescriptionKey: "Video replacement timed out"
        ])
    }
    
    private func finalizeVideoReplacement() async {
        videoReplacementState = .finalizing(progress: 0.5, status: "Applying default trim settings...")

        // 🗑️ REMOVED redundant applyTrimSettings call - AddMoveUnifiedState.loadVideo()
        // already handles state reset correctly for the new video asset. Using trimmerVM.videoDuration
        // here was causing stale state issues with the old video's duration.
        diagnosticLogger.logInfo("🔧 Video replacement finalized - using unifiedState.loadVideo() for state reset", metadata: [
            "function": "finalizeVideoReplacement"
        ])

        // Reset local state
        await MainActor.run {
            isRotationButtonPressed = false
            videoReplacementState = .finalizing(progress: 1.0, status: "Replacement complete!")
        }
    }

    private func handleVideoReplacementError(_ error: Error) async {
        let errorMessage = error.localizedDescription
        
        await MainActor.run {
            videoReplacementState = .error(errorMessage)
            lastVideoReplacementError = errorMessage
        }
        
        diagnosticLogger.logError("Video replacement failed", error: error, metadata: [
            "error_message": errorMessage,
            "replacement_state": "\(videoReplacementState)",
            "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
        ])
    }
    
    private func retryVideoReplacement() {
        diagnosticLogger.logUserInteraction("Retrying video replacement", metadata: [
            "last_error": "\(lastVideoReplacementError ?? "none")"
        ])
        
        // Reset error state and try again
        Task {
            diagnosticLogger.logDebug("🔧 MEMORY_FIX: Reset video replacement state Task started")
            await resetVideoReplacementState()
            try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay
            startVideoReplacement()
        }
    }
    
    private func resetVideoReplacementState() async {
        await MainActor.run {
            isVideoReplacementInProgress = false
            videoReplacementProgress = 0.0
            videoReplacementStatus = ""
            videoReplacementState = .idle
            lastVideoReplacementError = nil
            tempVideoSelection = nil
        }
    }
    
    private func updateReplacementProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            videoReplacementProgress = progress
            videoReplacementStatus = status
            
            // Update state based on current phase
            switch videoReplacementState {
            case .preparing:
                videoReplacementState = .preparing(progress: progress, status: status)
            case .replacing:
                videoReplacementState = .replacing(progress: progress, status: status)
            case .finalizing:
                videoReplacementState = .finalizing(progress: progress, status: status)
            default:
                break
            }
        }
    }
    
    private func getCurrentTrimSettings() -> (startTime: Double, endTime: Double, rotation: Int) {
        let trimmerVM = viewModel
        
        return (
            startTime: trimmerVM.startTime.seconds,
            endTime: trimmerVM.endTime.seconds,
            rotation: trimmerVM.rotationQuarterTurns
        )
    }
    
    private func optimizeMemoryForReplacement() async {
        // Clear any cached data to free memory
        await MainActor.run {
            cachedTimeCodeRow = nil
        }
        
        // Additional memory optimization could be added here
        diagnosticLogger.logDebug("🧹 Memory optimization completed for video replacement")
    }
    
    // MARK: - Continue Button Methods
    private func isReadyToContinue() -> Bool {
        let trimmerVM = viewModel

        // Check if we have valid duration first
        let hasValidDuration = trimmerVM.videoDuration.seconds > 0
        if !hasValidDuration {
            diagnosticLogger.logDebug("⚠️ Cannot continue - video duration not yet loaded", metadata: [
                "duration_seconds": "\(trimmerVM.videoDuration.seconds)",
                "trimmer_ready": "\(trimmerVM.isReady)"
            ])
            return false
        }

        // Use TimecodeCalculationService for comprehensive validation
        let timecodeResult = timecodeService.calculateTimecode(
            startTime: trimmerVM.startTime,
            endTime: trimmerVM.endTime,
            assetDuration: trimmerVM.videoDuration,
            frameRate: trimmerVM.currentFrameRate
        )

        // Validate trim range is valid using timecode service
        var validationErrors: [TimecodeValidationError] = []
        let hasValidTrimRange = timecodeService.validateTimecodeRange(
            startTime: trimmerVM.startTime,
            endTime: trimmerVM.endTime,
            assetDuration: trimmerVM.videoDuration,
            errors: &validationErrors
        )

        // Validate minimum duration requirement using timecode result
        let meetsMinimumDuration = !timecodeResult.isDurationTooShort

        // Validate player and trimmer are ready
        let readyStatus = "meets_min_duration: \(meetsMinimumDuration), valid_trim_range: \(hasValidTrimRange), components_ready: \(isReadyToShowTrimmer), valid_duration: \(hasValidDuration)"

        if !isReadyToShowTrimmer {
            diagnosticLogger.logDebug("⏳ Waiting for components to be ready", metadata: [
                "validation": readyStatus,
                "player_ready": "\((unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol))?.isPlayerReady ?? false)",
                "trimmer_ready": "\(trimmerVM.isReady)",
                "duration_seconds": "\(trimmerVM.videoDuration.seconds)"
            ])
        }

        if !meetsMinimumDuration {
            diagnosticLogger.logDebug("⚠️ Cannot continue - minimum duration not met", metadata: [
                "validation": readyStatus,
                "current_duration": "\(timecodeResult.duration.seconds)",
                "minimum_duration": "\(timecodeResult.minimumDuration.seconds)",
                "validation_errors": "\(timecodeResult.validationErrors.map { $0.localizedDescription })"
            ])
        }

        if !hasValidTrimRange {
            diagnosticLogger.logDebug("⚠️ Cannot continue - invalid trim range", metadata: [
                "validation": readyStatus,
                "start_time": "\(trimmerVM.startTime.seconds)",
                "end_time": "\(trimmerVM.endTime.seconds)",
                "video_duration": "\(trimmerVM.videoDuration.seconds)",
                "validation_errors": "\(timecodeResult.validationErrors.map { $0.localizedDescription })"
            ])
        }

        let isReady = hasValidDuration && meetsMinimumDuration && hasValidTrimRange && isReadyToShowTrimmer

        if isReady {
            diagnosticLogger.logInfo("✅ Ready to continue", metadata: [
                "validation": readyStatus,
                "duration": "\(timecodeResult.duration.seconds)",
                "rotation": "\(trimmerVM.rotationQuarterTurns)",
                "video_duration": "\(trimmerVM.videoDuration.seconds)",
                "timecode_valid": "\(timecodeResult.isValid)",
                "frame_precision": "\(timecodeResult.durationFrames) frames"
            ])
        }

        return isReady
    }
    
    private func validateAndContinue() async {
        diagnosticLogger.startTiming("validate_and_continue")

        // Final validation before proceeding
        guard isReadyToContinue() else {
            diagnosticLogger.logError("❌ Continue validation failed", metadata: [
                "player_ready": "\((unifiedState.currentPlayerViewModel as? (any VideoPlayerViewModelProtocol))?.isPlayerReady ?? false)",
                "trimmer_ready": "\(viewModel.isReady)",
                "combined_ready": "\(isReadyToShowTrimmer)"
            ])
            diagnosticLogger.stopTiming("validate_and_continue")
            return
        }

        // 🎯 CRITICAL: Show local loading overlay to preserve render layer
        await MainActor.run {
            isFinalizing = true
        }

        // 🎯 ATOMIC FIX: Simplified approach - unified state handles entire transition
        // This eliminates the race condition by centralizing all logic in proceedToNextState
        do {
            diagnosticLogger.logInfo("🚀 Starting atomic state transition from trimmer view", metadata: [
                "current_flow_state": "\(unifiedState.flowState)",
                "target_state": "naming",
                "race_condition_prevention": "atomic_transition",
                "local_overlay_active": "\(isFinalizing)",
                "processing_method": "centralized"
            ])

            // 🎯 ATOMIC FIX: Simply tell the state machine to proceed
            // All asset preparation and transition logic is now centralized in proceedToNextState
            try await unifiedState.proceedToNextState()

            diagnosticLogger.stopTiming("validate_and_continue")
            diagnosticLogger.logInfo("🎉 Successfully triggered atomic state transition", metadata: [
                "final_flow_state": "\(unifiedState.flowState)",
                "transition_method": "proceedToNextState",
                "race_condition_prevention": "atomic",
                "asset_processing_method": "centralized",
                "finalization_successful": "true"
            ])

        } catch let timeoutError as TimeoutError {
            diagnosticLogger.logError("⏰ Atomic state transition timed out", error: timeoutError)
            // No need to call setError here - unifiedState handles its own error state
            diagnosticLogger.stopTiming("validate_and_continue")
        } catch {
            diagnosticLogger.logError("❌ Failed during atomic state transition", error: error)
            // No need to call setError here - unifiedState handles its own error state
            diagnosticLogger.stopTiming("validate_and_continue")
        }

        // 🎯 CRITICAL: Hide local loading overlay when done
        await MainActor.run {
            isFinalizing = false
        }
    }
}

// MARK: - Shoe Handle Component
struct ShoeHandle: View {
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Background capsule (IBM Carbon design)
            Capsule()
                .fill(Color.cardBackground.opacity(0.9))
                .frame(width: 40, height: 40)
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? Color.accent : Color.accent.opacity(0.6),
                            lineWidth: isActive ? 3 : 2
                        )
                )
                .shadow(
                    color: isActive ? Color.accent.opacity(0.4) : Color.black.opacity(0.2),
                    radius: isActive ? 6 : 4,
                    x: 0,
                    y: isActive ? 3 : 2
                )
            
            // Shoe emoji with subtle background
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

// MARK: - Time Code Label
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
            .font(.ibmPlexMono(size: 11, weight: isActive ? .medium : .regular))
            .foregroundColor(isActive ? Color.accent : Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? Color.accent.opacity(0.15) : Color.clear)
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Duration Label
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

            Text(timecodeService.formatTime(duration, includeMilliseconds: true))
                .font(.ibmPlexMono(size: 11, weight: showWarning ? .medium : .regular))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showWarning)
    }
}

// MARK: - Time Progress Bar
struct TimeProgressBar: View {
    let currentRange: ClosedRange<CMTime>
    let totalDuration: CMTime
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                
                // Selected range
                Capsule()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(
                        width: calculateWidth(currentRange, totalDuration, in: geometry),
                        height: 4
                    )
                    .offset(x: calculateOffset(currentRange.lowerBound, totalDuration, in: geometry))
            }
        }
        .frame(height: 8)
    }
    
    private func calculateWidth(_ range: ClosedRange<CMTime>, _ total: CMTime, in geometry: GeometryProxy) -> CGFloat {
        let percentage = (range.upperBound.seconds - range.lowerBound.seconds) / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }
    
    private func calculateOffset(_ time: CMTime, _ total: CMTime, in geometry: GeometryProxy) -> CGFloat {
        let percentage = time.seconds / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }
}

// MARK: - Hybrid Precise Trimmer (Integrated)
struct HybridPreciseTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    private let timecodeService = TimecodeCalculationService()

    // Custom handle views
    var startHandleView: AnyView?
    var endHandleView: AnyView?
    
    private let handleWidth: CGFloat = 44
    
    // Haptic Feedback State
    @State private var lastHapticTime: CMTime = .zero
    @State private var hapticFrameCounter: Int = 0
    
    // Haptic Feedback Generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
            let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)
            
            let startDragGesture = drag(handle: .start, in: geometry)
            let endDragGesture = drag(handle: .end, in: geometry)
            
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: trackWidth, height: 6)
                    .offset(x: handleWidth/2)
                
                // Active range - Apple blue color
                Capsule()
                    .fill(Color(red: 0/255, green: 122/255, blue: 255/255)) // Apple blue
                    .frame(width: endX - startX, height: 6)
                    .offset(x: startX + handleWidth/2)
                
                // Start handle
                if let startView = startHandleView {
                    handle(content: startView)
                        .offset(x: startX)
                        .gesture(startDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle))
                        .offset(x: startX)
                        .gesture(startDragGesture)
                }
                
                // End handle
                if let endView = endHandleView {
                    handle(content: endView)
                        .offset(x: endX)
                        .gesture(endDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle)) // Changed to shoe emoji
                        .offset(x: endX)
                        .gesture(endDragGesture)
                }
            }
        }
        .coordinateSpace(name: "track")
        .frame(height: 60)
        .onAppear {
            viewModel.startCoalescing()
            // startFrameAnimation() removed - no longer needed with simplified animation system
            
            let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
            logger.logDebug("🎬 HybridPreciseTrimmerView appeared", metadata: [
                "frame_rate": "\(viewModel.currentFrameRate)",
                "total_frames": "\(viewModel.totalFrames)",
                "minimum_duration": "\(viewModel.minimumDuration.seconds)"
            ])
        }
        .onDisappear {
            viewModel.stopCoalescing()
            // stopFrameAnimation() removed - no longer needed with simplified animation system
            
            let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
            logger.logDebug("🧹 HybridPreciseTrimmerView disappeared - cleanup completed")
        }
    }
    
    private func handle(content: some View) -> some View {
        content
    }
    
    // MARK: - Coordinate System
    
    private func timeToXLeft(_ t: CMTime, trackWidth: CGFloat) -> CGFloat {
        guard viewModel.videoDuration.seconds > 0 else { return 0 }
        let p = t.seconds / viewModel.videoDuration.seconds
        return CGFloat(p) * trackWidth
    }
    
    private func xLeftToTime(_ x: CGFloat, trackWidth: CGFloat) -> CMTime {
        let clamped = max(0, min(x, trackWidth))
        let seconds = Double(clamped / trackWidth) * viewModel.videoDuration.seconds
        let time = CMTime(seconds: seconds, preferredTimescale: viewModel.videoDuration.timescale)
        return timecodeService.snapToFrame(time: time, frameRate: viewModel.currentFrameRate)
    }
    
    private func minDistancePx(_ g: GeometryProxy) -> CGFloat {
        let trackWidth = g.size.width - handleWidth
        let pps = trackWidth / viewModel.videoDuration.seconds
        return pps * viewModel.minimumDuration.seconds
    }
    
    // Conversion function no longer needed - using TrimmerHandleType directly
    
    private func drag(handle: TrimmerHandleType, in g: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { value in
                let trackWidth = g.size.width - handleWidth
                let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")

                if handle == .start && !viewModel.isDraggingStartHandle {
                    viewModel.isDraggingStartHandle = true
                    viewModel.startCoalescing()
                    // startFrameAnimation() removed - no longer needed with simplified animation system
                    HapticManager.shared.trigger(.dragStart)

                    logger.logDebug("🚀 Start handle drag began", metadata: [
                        "initial_position": "\(value.location.x)",
                        "track_width": "\(trackWidth)",
                        "handle_type": "start",
                        "current_time": "\(viewModel.startTime.seconds)",
                        "formatted_time": "\(TimecodeFormatter.format(time: viewModel.startTime))",
                        "video_duration": "\(viewModel.videoDuration.seconds)",
                        "minimum_duration": "\(viewModel.minimumDuration.seconds)",
                        "is_dragging_end": "\(viewModel.isDraggingEndHandle)",
                        "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
                    ])
                } else if handle == .end && !viewModel.isDraggingEndHandle {
                    viewModel.isDraggingEndHandle = true
                    viewModel.startCoalescing()
                    // startFrameAnimation() removed - no longer needed with simplified animation system
                    HapticManager.shared.trigger(.dragStart)

                    logger.logDebug("🚀 End handle drag began", metadata: [
                        "initial_position": "\(value.location.x)",
                        "track_width": "\(trackWidth)",
                        "handle_type": "end",
                        "current_time": "\(viewModel.endTime.seconds)",
                        "formatted_time": "\(TimecodeFormatter.format(time: viewModel.endTime))",
                        "video_duration": "\(viewModel.videoDuration.seconds)",
                        "minimum_duration": "\(viewModel.minimumDuration.seconds)",
                        "is_dragging_start": "\(viewModel.isDraggingStartHandle)",
                        "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
                    ])
                }

                let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
                let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)
                let minPx = minDistancePx(g)
                
                // finger-aligned center -> left-edge
                var proposedLeft = value.location.x - handleWidth/2
                proposedLeft = max(0, min(proposedLeft, trackWidth))
                
                // Enhanced bumper - physical bump implementation with frame accuracy
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

                // Trigger enhanced haptic feedback for physical bump
                if oldProposedLeft != proposedLeft {
                    HapticManager.shared.trigger(.dragEnd)
                    viewModel.triggerBoundaryHaptic()

                    let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
                    logger.logDebug("🛑 Boundary bump triggered", metadata: [
                        "handle": "\(handle)",
                        "old_position": "\(oldProposedLeft)",
                        "new_position": "\(proposedLeft)",
                        "boundary_hit": "true",
                        "physical_boundary": "\(hitPhysicalBoundary)"
                    ])
                }

                // Prevent handle movement beyond physical boundaries
                if hitPhysicalBoundary {
                    // Convert boundary position to time for validation
                    let boundaryTime = xLeftToTime(proposedLeft, trackWidth: trackWidth)
                    let snappedBoundaryTime = viewModel.snapToFrame(boundaryTime)

                    // Force the handle to stay at the boundary
                    viewModel.proposeTime(snappedBoundaryTime, for: handle)

                    let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
                    logger.logDebug("🚫 Physical boundary enforced", metadata: [
                        "handle": "\(handle)",
                        "boundary_position": "\(proposedLeft)",
                        "boundary_time": "\(snappedBoundaryTime.seconds)",
                        "minimum_duration": "\(viewModel.minimumDuration.seconds)"
                    ])

                    // Skip the rest of the drag processing for this frame
                    return
                }
                
                // Convert to time and apply frame snapping
                let proposedTime = xLeftToTime(proposedLeft, trackWidth: trackWidth)
                let snappedTime = viewModel.snapToFrame(proposedTime)

                // Enhanced reactive UI logging
                let currentFrame = viewModel.getFrameNumber(for: snappedTime)
                let lastFrame = viewModel.getFrameNumber(for: handle == .start ? viewModel.startTime : viewModel.endTime)
                let frameDelta = abs(currentFrame - lastFrame)
                let timeDelta = abs(snappedTime.seconds - (handle == .start ? viewModel.startTime.seconds : viewModel.endTime.seconds))
                let currentDuration = viewModel.endTime - viewModel.startTime
                let newDuration = handle == .start ? viewModel.endTime - snappedTime : snappedTime - viewModel.startTime
                let durationDelta = abs(newDuration.seconds - currentDuration.seconds)

                // Log significant frame movements and UI updates
                if frameDelta > 0 {
                    let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
                    logger.logDebug("🎬 Handle drag processing UI update", metadata: [
                        "handle": "\(handle)",
                        "current_frame": "\(currentFrame)",
                        "last_frame": "\(lastFrame)",
                        "frame_delta": "\(frameDelta)",
                        "time_delta_ms": "\(timeDelta * 1000)",
                        "current_time": "\(snappedTime.seconds)",
                        "formatted_time": "\(TimecodeFormatter.format(time: snappedTime))",
                        "current_duration": "\(currentDuration.seconds)",
                        "new_duration": "\(newDuration.seconds)",
                        "duration_delta_ms": "\(durationDelta * 1000)",
                        "pixel_position": "\(proposedLeft)",
                        "track_percentage": "\(String(format: "%.2f", proposedLeft / trackWidth * 100))%",
                        "ui_update_trigger": "\(frameDelta > 1 ? "significant" : "minor")",
                        "coalescing_active": "\(viewModel.isDraggingStartHandle || viewModel.isDraggingEndHandle)",
                        "boundary_enforcement": "active"
                    ])
                }

                viewModel.proposeTime(snappedTime, for: handle)

                // Enhanced frame-synchronized haptic feedback
                triggerFrameSynchronizedHaptic(at: snappedTime, for: handle)
            }
            .onEnded { value in
                let trackWidth = g.size.width - handleWidth
                var xLeft = value.location.x - handleWidth/2
                xLeft = max(0, min(xLeft, trackWidth))

                // Convert to time and apply frame snapping for final commit
                let proposedTime = xLeftToTime(xLeft, trackWidth: trackWidth)
                let snappedTime = viewModel.snapToFrame(proposedTime)
                let finalFrame = viewModel.getFrameNumber(for: snappedTime)

                // Enhanced end drag logging
                let startTimeBefore = viewModel.startTime
                let endTimeBefore = viewModel.endTime
                let durationBefore = viewModel.endTime - viewModel.startTime

                viewModel.commitTime(snappedTime, for: handle)

                // stopFrameAnimation() removed - no longer needed with simplified animation system

                if handle == .start {
                    viewModel.isDraggingStartHandle = false
                } else {
                    viewModel.isDraggingEndHandle = false
                }

                viewModel.stopCoalescing()
                HapticManager.shared.trigger(.dragEnd)

                // Calculate final state changes
                let durationAfter = viewModel.endTime - viewModel.startTime
                let durationDelta = abs(durationAfter.seconds - durationBefore.seconds)
                let finalTrackPosition = xLeft / trackWidth
                let memoryUsage = MemoryHelper.getDetailedMemoryInfo()

                let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
                logger.logDebug("✅ Handle drag ended", metadata: [
                    "handle": "\(handle)",
                    "final_position": "\(xLeft)",
                    "final_frame": "\(finalFrame)",
                    "final_time": "\(snappedTime.seconds)",
                    "formatted_time": "\(TimecodeFormatter.format(time: snappedTime))",
                    "start_time_before": "\(startTimeBefore.seconds)",
                    "end_time_before": "\(endTimeBefore.seconds)",
                    "start_time_after": "\(viewModel.startTime.seconds)",
                    "end_time_after": "\(viewModel.endTime.seconds)",
                    "duration_before": "\(durationBefore.seconds)",
                    "duration_after": "\(durationAfter.seconds)",
                    "duration_delta_ms": "\(durationDelta * 1000)",
                    "track_percentage": "\(String(format: "%.2f", finalTrackPosition * 100))%",
                    "warning_state": "\(viewModel.showMinimumDurationWarning)",
                    "validation_success": "\(viewModel.isValidTrim)",
                    "coalescing_stopped": "true",
                    "memory_usage_mb": "\(memoryUsage.used)",
                    "memory_pressure": "\(memoryUsage.percentage)"
                ])
            }
    }
    
    // MARK: - Enhanced Frame-Synchronized Haptic Feedback
    private func triggerFrameSynchronizedHaptic(at time: CMTime, for handle: TrimmerHandleType) {
        let frameNumber = viewModel.getFrameNumber(for: time)
        let lastFrameNumber = viewModel.getFrameNumber(for: lastHapticTime)
        let frameDelta = abs(frameNumber - lastFrameNumber)

        // Trigger haptic every 3 frames (approximately every 50ms at 60fps)
        if frameDelta >= 3 {
            // Use frameDetent for frame-synchronized feedback
            HapticManager.shared.trigger(.frameDetent)
            lastHapticTime = time
            hapticFrameCounter += 1

            let timeSinceLastHaptic = abs(time.seconds - lastHapticTime.seconds)
            let currentDuration = viewModel.endTime - viewModel.startTime
            let memoryUsage = MemoryHelper.getDetailedMemoryInfo()

            let logger = DiagnosticLoggingHelper(category: "HybridPreciseTrimmerView")
            logger.logDebug("📳 Frame-synchronized haptic triggered", metadata: [
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
                "sync_quality": timeSinceLastHaptic < 0.1 ? "excellent" : (timeSinceLastHaptic < 0.2 ? "good" : "poor"),
                "memory_usage_mb": "\(memoryUsage.used)",
                "ui_responsive": "true"
            ])
        }
    }
}

// MARK: - Convenience Initializers for Common Handle Styles
extension HybridPreciseTrimmerView {
    // Default initializer with shoe emoji
    init(viewModel: TrimmerViewModel) {
        self.viewModel = viewModel
        self.startHandleView = nil
        self.endHandleView = nil
    }
    
    // Shoe handles - our new default
    static func shoe(viewModel: TrimmerViewModel) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel
        )
    }
    
    // Custom view handles
    static func custom(viewModel: TrimmerViewModel,
                       startView: some View,
                       endView: some View) -> HybridPreciseTrimmerView {
        // FIX: The original implementation was empty and ignored the parameters.
        // This corrected version properly uses the views.
        var view = HybridPreciseTrimmerView(viewModel: viewModel)
        view.startHandleView = AnyView(startView)
        view.endHandleView = AnyView(endView)
        return view
    }
}
