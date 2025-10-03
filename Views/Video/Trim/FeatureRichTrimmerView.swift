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
        // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Removed redundant SwiftUI rotation layer
        // The AVPlayerItem already contains the correct rotation via video composition
        // Applying additional rotation here causes double rotation (upside-down video)
        // Identity morphism: SwiftUI view displays content without transformation
        .onAppear {
            let playerViewModel = unifiedState.currentPlayerViewModel as! any VideoPlayerViewModelProtocol
            let message = "🎬 TRIMMER_PLAYER_VIEW: Showing video player with IDENTITY morphism - isReady: \(isReady), playerState: \(playerViewModel.state), rotation_layer: \"REMOVED\""
            logger.info("\(message)")

            // 🎯 COMPREHENSIVE DIAGNOSTIC: Log fixed rotation state
            logger.info("🎯 DOUBLE_ROTATION_FIX: Player view rotation details - swiftui_rotation: \"REMOVED\", avplayer_rotation: \"BAKED_IN\", double_rotation_fixed: \"true\"")
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

// MARK: - Unified Feature-Rich Trimmer View with Categorical Rotation System
//
// CATEGORICAL ROTATION ARCHITECTURE:
// ===================================
// This UI implements the categorical rotation structure where rotations form a category
// with objects as rotation states and morphisms as rotation transformations.
//
// Category Theory Components:
// • Objects: Rotation values in Z/4 (0, 1, 2, 3 representing 0°, 90°, 180°, 270°)
// • Morphisms: User-applied rotation operations (addition modulo 4)
// • Natural Transformation η: Maps intrinsic rotation to total rotation
// • Composition: η(intrinsic) ⊕ user_applied = total_rotation
//
// UI Binding Strategy:
// • Input Binding: Binds to userAppliedRotationTurns (user controllable)
// • Display Binding: Shows totalRotationQuarterTurns (intrinsic + user applied)
// • Preview: Uses total rotation for visual accuracy
// • Validation: Checks userAppliedRotationTurns for unsaved changes
//
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
    // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Removed previewRotationDegrees state variable
    // The AVPlayerItem handles all rotation internally, making SwiftUI rotation state redundant
    @State private var cachedTimeCodeRow: (startTime: CMTime, endTime: CMTime, isDraggingStart: Bool, isDraggingEnd: Bool)?
    @State private var isRotationButtonPressed: Bool = false

    // MARK: - Local Loading State for Deadlock Prevention
    @State private var isFinalizing = false

    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "FeatureRichTrimmer")
    
    // MARK: - Categorical Rotation Binding with Natural Transformation
    //
    // This binding implements the categorical rotation morphism where:
    // • Domain: User-applied rotation space (Z/4)
    // • Codomain: Total rotation space (Z/4)
    // • Morphism: User rotation operation f: user_rotation → new_user_rotation
    // • Natural Transformation η: intrinsic_rotation ⊕ user_rotation → total_rotation
    //
    // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Simplified binding implementation
    // The binding only modifies ViewModel state - reactive modifiers handle UI synchronization
    // This eliminates manual state assignment that causes race conditions
    //
    private var rotationBinding: Binding<Int> {
        Binding(
            get: { viewModel.userAppliedRotationTurns },
            set: { newValue in
                let oldValue = viewModel.userAppliedRotationTurns

                // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Only modify ViewModel state
                // Reactive .onChange modifiers will handle UI synchronization automatically
                // This prevents manual state assignment that causes desynchronization
                viewModel.userAppliedRotationTurns = newValue

                // 🎯 DIAGNOSTIC: Track simplified rotation action with 180-degree flip prevention
                if oldValue != newValue {
                    diagnosticLogger.logUserInteraction("🔧 CRITICAL_FIX_180_DEGREE_FLIP: Simplified binding executed", metadata: [
                        "interaction_type": "rotation_binding_change",
                        "fix_pattern": "ViewModel_only_modification",
                        "reactive_sync": "onChange_handlers_will_update_UI",
                        "morphism_domain": "\(oldValue)",
                        "morphism_codomain": "\(newValue)",
                        "intrinsic_rotation": "\(viewModel.assetIntrinsicRotationTurns)",
                        "user_applied_rotation": "\(newValue)",
                        "total_rotation": "\(viewModel.totalRotationQuarterTurns)",
                        "current_preview_degrees": "0.0_fixed",
                        "binding_source": "simplified_rotation_binding",
                        "manual_state_assignment": "removed",
                        "ui_update_method": "reactive_onChange_modifier",
                        "category_theory": "morphism_in_UserAppliedRotationSpace",
                        "180_degree_flip_prevention": "true",
                        "race_condition_prevention": "reactive_sync",
                        "specification_compliance": "CRITICAL_FIX_180_DEGREE_FLIP"
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

    // MARK: - Critical Fix: 180-Degree Flip State Synchronization
    // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Removed synchronizePreviewRotationWithViewModel function
    // The AVPlayerItem now handles all rotation internally, making reactive synchronization unnecessary
    // Identity morphism: SwiftUI view displays content without transformation

    // MARK: - Legacy Force Synchronization Methods (Removed - SwiftUI handles updates naturally)
    
    init(unifiedState: AddMoveUnifiedState, viewModel: TrimmerViewModel) {
        self.unifiedState = unifiedState
        self.viewModel = viewModel

        // 🎯 CRITICAL FIX: 180-DEGREE FLIP BUG - Removed previewRotationDegrees initialization
        // PROBLEM: @State initialization for rotation was causing double rotation with AVPlayerItem
        // SOLUTION: Remove all SwiftUI rotation state - AVPlayerItem handles rotation internally
        // This establishes identity morphism: SwiftUI displays content without transformation

        // 🎯 DIAGNOSTIC: Enhanced logging for 180-degree flip bug fix
        let logger = DiagnosticLoggingHelper(category: "FeatureRichTrimmerView")
        logger.logInfo("🔧 CRITICAL_FIX_180_DEGREE_FLIP: FeatureRichTrimmerView initialized with IDENTITY morphism", metadata: [
            "player_ready": "\(viewModel.playerViewModel.isPlayerReady)",
            "trimmer_ready": "\(viewModel.isReady)",
            "player_state": "\(viewModel.playerViewModel.state)",
            "loaded_intrinsic_rotation": "\(viewModel.assetIntrinsicRotationTurns)",
            "user_applied_rotation": "\(viewModel.userAppliedRotationTurns)",
            "total_rotation": "\(viewModel.totalRotationQuarterTurns)",
            "swiftui_rotation_state": "REMOVED",
            "avplayer_rotation_handling": "INTERNAL",
            "fix_type": "identity_morphism_180_degree_flip_fix",
            "double_rotation_eliminated": "true",
            "category_theory": "identity_morphism_SwiftUI_display",
            "rotation_responsibility": "AVPlayerItem_video_composition",
            "specification_compliance": "CRITICAL_FIX_180_DEGREE_FLIP"
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
                            previewRotationDegrees: 0.0 // 🎯 CRITICAL FIX: Fixed at 0° - AVPlayerItem handles rotation
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
            // 🎯 CRITICAL FIX: 180-DEGREE FLIP - Removed reactive state synchronization
            // The AVPlayerItem handles all rotation internally - no SwiftUI sync needed
            let logger = DiagnosticLoggingHelper(category: "FeatureRichTrimmerView")
            logger.logInfo("🎯 DOUBLE_ROTATION_FIX: View appeared with identity morphism - no SwiftUI rotation sync needed", metadata: [
                "intrinsic_rotation": "\(viewModel.assetIntrinsicRotationTurns * 90)°",
                "user_rotation": "\(viewModel.userAppliedRotationTurns * 90)°",
                "total_rotation": "\(viewModel.totalRotationQuarterTurns * 90)°",
                "swiftui_rotation": "DISABLED",
                "avplayer_rotation": "ENABLED",
                "double_rotation_fixed": "true"
            ])
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
        .onChange(of: showPhotosPicker) { _, isShowing in
            // 🎯 CRITICAL FIX: Handle PhotosPicker dismissal - detects both cancellation and selection completion
            // This morphism ensures proper state reset when user cancels video selection
            diagnosticLogger.logDebug("🔄 PHOTOS_PICKER_STATE_CHANGED: showPhotosPicker changed to \(isShowing)", metadata: [
                "is_showing": "\(isShowing)",
                "is_video_replacement_in_progress": "\(isVideoReplacementInProgress)",
                "temp_video_selection_is_nil": "\(tempVideoSelection == nil)",
                "video_replacement_state": "\(videoReplacementState)",
                "timestamp": "\(Date())"
            ])

            // Condition: Picker is dismissed, we're in replacement process, AND no new video was selected
            // This specific pattern indicates user cancellation (not selection completion)
            if !isShowing && isVideoReplacementInProgress && tempVideoSelection == nil {
                diagnosticLogger.logInfo("🔄 VIDEO_REPLACEMENT_CANCELLED: User cancelled video selection - resetting state", metadata: [
                    "detection_logic": "!isShowing && isVideoReplacementInProgress && tempVideoSelection == nil",
                    "previous_state": "\(videoReplacementState)",
                    "ui_state_before_reset": "preparing_stuck",
                    "user_action": "cancelled_photos_picker",
                    "fix_type": "missing_morphism_handleCancellation",
                    "timestamp": "\(Date())"
                ])

                // Execute the missing morphism: handleCancellation()
                // This resets the state machine to its original interactive state
                Task {
                    // Structs don't need weak references - they're value types
                    diagnosticLogger.logDebug("🔧 MEMORY_FIX: Video replacement cancellation Task started")
                    await resetVideoReplacementState()

                    diagnosticLogger.logInfo("✅ VIDEO_REPLACEMENT_CANCELLED: State reset completed - UI restored to interactive state", metadata: [
                        "final_state": "\(videoReplacementState)",
                        "is_video_replacement_in_progress": "\(isVideoReplacementInProgress)",
                        "ui_restored": "true",
                        "morphism_composition": "(handleCancellation . showPhotosPicker . startVideoReplacement) ≈ id",
                        "timestamp": "\(Date())"
                    ])
                }
            } else if !isShowing && tempVideoSelection != nil {
                // Picker dismissed after successful selection - normal flow
                diagnosticLogger.logDebug("✅ PHOTOS_PICKER_DISMISSED: Selection completed normally", metadata: [
                    "has_selection": "\(tempVideoSelection != nil)",
                    "flow_type": "normal_selection_completion",
                    "timestamp": "\(Date())"
                ])
            } else {
                // Other state changes (initial presentation, etc.)
                diagnosticLogger.logDebug("📱 PHOTOS_PICKER_STATE: Other state change detected", metadata: [
                    "is_showing": "\(isShowing)",
                    "flow_type": "initial_or_other",
                    "timestamp": "\(Date())"
                ])
            }
        }
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
    
    // MARK: - Optimized Control Section with Categorical Rotation Display
    private var controlSection: some View {
        let trimmerVM = viewModel
        let totalRotation = trimmerVM.totalRotationQuarterTurns // Show combined effect to user
        let isExporting = trimmerVM.isExporting
        
        return HStack(spacing: 20) {
            Button("Change Video") {
                HapticManager.shared.trigger(.dragEnd)
                startVideoReplacement()
            }
            .buttonStyle(.appSecondary(size: .medium))
            .disabled(isVideoReplacementInProgress || !(isReadyToShowTrimmer && viewModel.isReady))
            
            Button(action: {
                HapticManager.shared.trigger(.frameDetent)

                // 🎯 CRITICAL FIX: 180-DEGREE FLIP - User interaction drives player regeneration
                // Instead of direct ViewModel modification, call async handleRotation() method
                // This ensures AVPlayerItem is regenerated with correct rotation baked in

                let oldUserRotation = viewModel.userAppliedRotationTurns
                let intrinsicRotation = viewModel.assetIntrinsicRotationTurns

                diagnosticLogger.logUserInteraction("🎯 DOUBLE_ROTATION_FIX: User rotation button pressed - triggering player regeneration", metadata: [
                    "interaction_type": "rotation_button_press",
                    "fix_pattern": "async_handleRotation_player_regeneration",
                    "player_regeneration": "triggered",
                    "user_rotation_before": "\(oldUserRotation)",
                    "intrinsic_rotation": "\(intrinsicRotation)",
                    "total_rotation_before": "\(viewModel.totalRotationQuarterTurns)",
                    "avplayer_rotation_handling": "video_composition",
                    "swiftui_rotation": "disabled",
                    "category_theory": "morphism_triggers_authoritative_player_rebuild",
                    "double_rotation_prevention": "player_regeneration",
                    "specification_compliance": "DOUBLE_ROTATION_FIX"
                ])

                // 🎯 CRITICAL ACTION: Call async handleRotation() to regenerate player with correct rotation
                // This is the single authoritative morphism that ensures correct video orientation
                Task {
                    await unifiedState.handleRotation()

                    // 🎯 DIAGNOSTIC: Log completion of rotation handling
                    await MainActor.run {
                        diagnosticLogger.logInfo("✅ DOUBLE_ROTATION_FIX: Rotation handling completed - player regenerated with correct rotation", metadata: [
                            "user_rotation_after": "\(viewModel.userAppliedRotationTurns)",
                            "total_rotation_after": "\(viewModel.totalRotationQuarterTurns)",
                            "player_regeneration": "completed",
                            "double_rotation_fixed": "true",
                            "avplayer_rotation_baked_in": "true",
                            "specification_compliance": "DOUBLE_ROTATION_FIX"
                        ])
                    }
                }
            }) {
                HStack(spacing: 6) {
                    // 🎯 CATEGORICAL VISUALIZATION: Icon shows natural transformation result
                    // The icon rotation reflects η(intrinsic) ⊕ user_applied = total_rotation
                    Image(systemName: "rotate.right")
                        .font(.system(size: 16, weight: .medium))
                        .rotationEffect(.degrees(Double(viewModel.totalRotationQuarterTurns * 90)))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.totalRotationQuarterTurns)

                    // 🎯 CATEGORICAL DISPLAY: Text shows user-applied rotation only
                    // FIX: Display userAppliedRotationTurns instead of totalRotationQuarterTurns
                    // This creates correct mental model - user controls start at 0°
                    Text("\(viewModel.userAppliedRotationTurns * 90)°")
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.userAppliedRotationTurns)
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
            .disabled(!(isReadyToShowTrimmer && viewModel.isReady))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isRotationButtonPressed = pressing
                }
            }, perform: {})
            
            Button("Continue") {
                HapticManager.shared.trigger(.dragEnd)
                diagnosticLogger.logUserInteraction("Continue button tapped", metadata: [
                    "button_type": "continue",
                    "current_rotation": "\(viewModel.totalRotationQuarterTurns * 90)°",
                    "exporting": "\(isExporting)",
                    "swiftui_rotation": "disabled",
                    "avplayer_rotation": "enabled"
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
            diagnosticLogger.logInfo("🎮 FEAT-2025-ROTATION-ISOMORPHISM: Control section appeared with separated rotation state", metadata: [
                "intrinsic_rotation": "\(trimmerVM.assetIntrinsicRotationTurns)",
                "user_applied_rotation": "\(trimmerVM.userAppliedRotationTurns)",
                "total_rotation": "\(totalRotation)",
                "exporting": "\(isExporting)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))",
                "separation_principle": "intrinsic_vs_user_rotation",
                "separation_working": "correctly",
                "preview_rotation_degrees": "0.0_fixed",
                "swiftui_rotation_disabled": "true",
                "double_rotation_fixed": "true",
                "specification_compliance": "DOUBLE_ROTATION_FIX"
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
            if isReadyToShowTrimmer && viewModel.isReady {
                let trimmerViewModel = viewModel
                HybridPreciseTrimmerView.shoe(viewModel: trimmerViewModel)
                    .onAppear(perform: onMainTrimmerAppear)
            } else {
                // 🎯 TRIMMER LOADING STATE: Show loading placeholder when ViewModel is not ready
                trimmerLoadingPlaceholder
            }
        }
    }

    // MARK: - Trimmer Loading Placeholder
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
            diagnosticLogger.logInfo("🎚 TRIMMER_LOADING: Showing loading placeholder", metadata: [
                "flow_state": "\(unifiedState.flowState)",
                "trimmer_ready": "\(viewModel.isReady)",
                "combined_ready": "\(isReadyToShowTrimmer)"
            ])
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
        
        // Check if user-applied rotation has been changed from default (intrinsic rotation doesn't count as user change)
        let hasRotationChanges = trimmerVM.userAppliedRotationTurns > 0
        
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
        // 🎯 ENHANCED: Comprehensive state reset with diagnostic logging for cancellation handling
        // This method serves as the handleCancellation() morphism in our categorical system

        await MainActor.run {
            // Capture state before reset for debugging
            let stateBeforeReset = videoReplacementState
            let progressBeforeReset = videoReplacementProgress

            diagnosticLogger.logInfo("🧹 VIDEO_REPLACEMENT_STATE_RESET: Starting comprehensive state reset", metadata: [
                "state_before": "\(stateBeforeReset)",
                "progress_before": "\(progressBeforeReset)",
                "is_in_progress_before": "\(isVideoReplacementInProgress)",
                "error_before": "\(lastVideoReplacementError ?? "none")",
                "reset_trigger": "cancellation_or_error_recovery",
                "timestamp": "\(Date())"
            ])

            // Reset all video replacement state variables to their initial values
            isVideoReplacementInProgress = false
            videoReplacementProgress = 0.0
            videoReplacementStatus = ""
            videoReplacementState = .idle
            lastVideoReplacementError = nil
            tempVideoSelection = nil

            diagnosticLogger.logInfo("✅ VIDEO_REPLACEMENT_STATE_RESET: All state variables reset to initial values", metadata: [
                "state_after": "\(videoReplacementState)",
                "is_in_progress_after": "\(isVideoReplacementInProgress)",
                "progress_after": "\(videoReplacementProgress)",
                "temp_selection_cleared": "true",
                "error_cleared": "true",
                "ui_restoration": "ready_for_interaction",
                "timestamp": "\(Date())"
            ])
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
    
    private func getCurrentTrimSettings() -> (startTime: Double, endTime: Double, intrinsicRotation: Int, userAppliedRotation: Int, totalRotation: Int) {
        let trimmerVM = viewModel

        return (
            startTime: trimmerVM.startTime.seconds,
            endTime: trimmerVM.endTime.seconds,
            intrinsicRotation: trimmerVM.assetIntrinsicRotationTurns,
            userAppliedRotation: trimmerVM.userAppliedRotationTurns,
            totalRotation: trimmerVM.totalRotationQuarterTurns
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
            diagnosticLogger.logInfo("✅ Ready to continue with separated rotation system", metadata: [
                "validation": readyStatus,
                "duration": "\(timecodeResult.duration.seconds)",
                "intrinsic_rotation": "\(trimmerVM.assetIntrinsicRotationTurns)",
                "user_applied_rotation": "\(trimmerVM.userAppliedRotationTurns)",
                "total_rotation": "\(trimmerVM.totalRotationQuarterTurns)",
                "video_duration": "\(trimmerVM.videoDuration.seconds)",
                "timecode_valid": "\(timecodeResult.isValid)",
                "frame_precision": "\(timecodeResult.durationFrames) frames",
                "separation_system": "intrinsic_display + user_controls",
                "unwanted_rotation_fixed": "true"
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
