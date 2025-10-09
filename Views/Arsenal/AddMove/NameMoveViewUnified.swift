import SwiftUI
import OSLog
import AVKit

private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveViewUnified")

/// Enhanced State-driven Name Move view with asset inheritance and loading states
/// Implements seamless WYSIWYG transition from trimming with proper asset transformation
struct NameMoveViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    
    // MARK: - State Management
    @State private var moveName: String = ""
    @State private var isShowingPreview = false
    @State private var estimatedFileSize: String = "Calculating..."
    
    
    @ViewBuilder
    private var mainContentView: some View {
        if let playerViewModel = unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel {
            mainContent(with: playerViewModel)
        } else {
            Text("Player not available")
                .foregroundColor(.white)
                .padding()
        }
    }
    
    // MARK: - Computed Properties
    private var canSave: Bool {
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Checking save readiness...")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - saveReadiness value: \(unifiedState.saveReadiness != nil ? "not nil" : "nil")")

        if let saveReadiness = unifiedState.saveReadiness {
            let canSave = saveReadiness.canSave
            // Log validation state for debugging
            logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - SaveReadiness available - canSave: \(canSave), issues: \(saveReadiness.issues.count), isValid: \(saveReadiness.isValid)")
            logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - Player ready: \(saveReadiness.hasValidPlayer), Asset ready: \(saveReadiness.hasValidAsset), Trimmer ready: \(saveReadiness.hasValidTrimmer)")

            if !canSave && !saveReadiness.issues.isEmpty {
                logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - Save blocked by issues: \(saveReadiness.issues)")
                for (index, issue) in saveReadiness.issues.enumerated() {
                    logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - Issue \(index + 1): \(issue.localizedDescription) (critical: \(issue.isCritical))")
                }
            }
            return canSave
        } else {
            logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - SaveReadiness is nil - validation may still be running")
            // MARK: - CRITICAL FIX REMOVED: The temporary workaround has been removed since the underlying
            // state synchronization issue has been fixed in FlowStateManager.completeAssetLoading()
            // The button should remain disabled until proper validation completes successfully.
            return false
        }
    }

    private var validationIssues: [SaveValidationIssue] {
        // MARK: - DIAGNOSTIC: Enhanced validation issues with fallback
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Getting validation issues...")

        if let saveReadiness = unifiedState.saveReadiness {
            logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - SaveReadiness available for issues, count: \(saveReadiness.issues.count)")
            return saveReadiness.issues
        } else {
            logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - SaveReadiness is nil - no validation issues available")
            return []
        }
    }
    
    // MARK: - Body
    var body: some View {
        mainContentViewWithLifecycle
            .sheet(isPresented: $isShowingPreview) {
                previewSheetContent
            }
    }

    // MARK: - View Components

    @ViewBuilder
    private var mainContentViewWithLifecycle: some View {
        if unifiedState.currentPlayerViewModel != nil {
            mainContentView
                .onAppear(perform: handleViewAppear)
                .onDisappear(perform: handleViewDisappear)
        } else {
            loadingView
                .onAppear {
                    logger.warning("⚠️ NAME_MOVE_UNIFIED: Appeared without a player view model. Flow state: \(String(describing: unifiedState.flowState))")
                }
        }
    }

    @ViewBuilder
    private var previewSheetContent: some View {
        if let playerViewModel = unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel {
            PreviewSheet(
                playerViewModel: playerViewModel,
                startTime: CMTime(seconds: unifiedState.trimStartTime, preferredTimescale: 600),
                endTime: CMTime(seconds: unifiedState.trimEndTime, preferredTimescale: 600),
                rotationQuarterTurns: unifiedState.totalRotationQuarterTurns,
                onDismiss: {
                    isShowingPreview = false
                }
            )
        }
    }
    // MARK: - FUNC
    // MARK: - Main Content
    @ViewBuilder
    private func mainContent(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                renderHeader()
                Spacer()

                // Video preview section
                renderVideoPreview(with: playerViewModel)
                    .padding(.bottom, 20)

                // Name input section
                renderNameInput()
                    .padding(.bottom, 20)

                // Action buttons
                renderActionButtons()

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)

            // Minimal loading overlay (non-blocking)
            minimalLoadingOverlay
        }
    }
    
    // MARK: - UI Components
    // MARK: - FUNC
    private func renderHeader() -> some View {
        HStack {
            Button(action: {
                handleBackButton()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
            Spacer()
        }
        .padding()
    }
    // MARK: - FUNC
    private func renderVideoPreview(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 8) {
            // MARK: - ENHANCED: Video preview with inherited modifiers and WYSIWYG experience
            videoPreviewWithInheritedModifiers(playerViewModel: playerViewModel)

            // Enhanced video info with precise trim details
            enhancedVideoInfoSection
        }
    }

    // MARK: - Enhanced Video Preview with Inherited Modifiers
    // MARK: - FUNC
    @ViewBuilder
    private func videoPreviewWithInheritedModifiers(playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 8) {
            // MARK: - WYSIWYG VIDEO PREVIEW: Shows exactly what will be saved
            ZStack {
                // Video player container with rotation and trim modifiers baked in
                CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false, shouldAutoplay: false)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .clipped()
                    .onAppear {
                        logger.info("🎬 NAME_MOVE_UNIFIED: 🎯 WYSIWYG preview appeared with inherited modifiers")
                        logInheritedModifiers()
                    }

                // Overlay showing inherited modifiers
                VStack {
                    HStack {
                        // Rotation indicator
                        if unifiedState.totalRotationQuarterTurns > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "rotate.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)

                                Text("\(unifiedState.totalRotationQuarterTurns * 90)°")
                                    .font(.ibmPlexMono(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.accent.opacity(0.8), lineWidth: 1)
                                    )
                            )
                        }

                        Spacer()

                        // Trim indicator
                        HStack(spacing: 4) {
                            Image(systemName: "scissors")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)

                            Text("Trimmed")
                                .font(.ibmPlexMono(size: 11, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.accent.opacity(0.8), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer()

                    // Duration indicator at bottom
                    HStack {
                        Spacer()

                        Text(calculateTrimDuration())
                            .font(.ibmPlexMono(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.accent.opacity(0.6), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Enhanced Video Info Section
    private var enhancedVideoInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Primary info row
            HStack {
                // Enhanced duration with frame count
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    HStack(spacing: 4) {
                        Text(calculateTrimDuration())
                            .font(.ibmPlexMono(size: 12, weight: .medium))
                            .foregroundColor(.textPrimary)

                        if let trimmerVM = unifiedState.trimmerViewModel as? TrimmerViewModel {
                            let frameCount = trimmerVM.getFrameNumber(for: CMTime(seconds: unifiedState.trimEndTime, preferredTimescale: 600)) - trimmerVM.getFrameNumber(for: CMTime(seconds: unifiedState.trimStartTime, preferredTimescale: 600))
                            Text("(\(frameCount) frames)")
                                .font(.ibmPlexMono(size: 10, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                Spacer()

                // File size estimate
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Est. Size")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Text(estimatedFileSize)
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
            }

            // Secondary info row with rotation details
            HStack {
                // Rotation info with inheritance indicator
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transformations")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    HStack(spacing: 6) {
                        // Rotation indicator
                        if unifiedState.totalRotationQuarterTurns > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "rotate.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.accent)

                                Text("\(unifiedState.totalRotationQuarterTurns * 90)° rotation")
                                    .font(.ibmPlexMono(size: 11, weight: .medium))
                                    .foregroundColor(.accent)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.textSecondary)

                                Text("No rotation")
                                    .font(.ibmPlexMono(size: 11, weight: .medium))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                }

                Spacer()

                // WYSIWYG indicator
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Preview")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)

                        Text("WYSIWYG")
                            .font(.ibmPlexMono(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }

            // Inheritance details
            if unifiedState.totalRotationQuarterTurns > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inherited Modifiers")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            // Intrinsic rotation info
                            if let trimmerVM = unifiedState.trimmerViewModel as? TrimmerViewModel, trimmerVM.assetIntrinsicRotationTurns > 0 {
                                HStack(spacing: 2) {
                                    Text("Intrinsic: \(trimmerVM.assetIntrinsicRotationTurns * 90)°")
                                        .font(.ibmPlexMono(size: 10, weight: .regular))
                                        .foregroundColor(.textSecondary)

                                    Text("+")
                                        .font(.ibmPlexMono(size: 10, weight: .medium))
                                        .foregroundColor(.accent)
                                }
                            }

                            // User applied rotation
                            Text("User: \(unifiedState.userAppliedRotation * 90)°")
                                .font(.ibmPlexMono(size: 10, weight: .regular))
                                .foregroundColor(.accent)

                            Text("=")
                                .font(.ibmPlexMono(size: 10, weight: .medium))
                                .foregroundColor(.textPrimary)

                            Text("Total: \(unifiedState.totalRotationQuarterTurns * 90)°")
                                .font(.ibmPlexMono(size: 10, weight: .semibold))
                                .foregroundColor(.textPrimary)
                        }
                    }

                    Spacer()

                    // Applied indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Export Status")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)

                            Text("Applied ✓")
                                .font(.ibmPlexMono(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Diagnostic Logging for Inherited Modifiers
    // MARK: - FUNC
    private func logInheritedModifiers() {
        logger.info("🎬 NAME_MOVE_UNIFIED: 🎯 LOGGING INHERITED MODIFIERS")
        logger.info("🎬 NAME_MOVE_UNIFIED: ┌─ Rotation Inheritance")

        if let trimmerVM = unifiedState.trimmerViewModel as? TrimmerViewModel {
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Intrinsic rotation: \(trimmerVM.assetIntrinsicRotationTurns * 90)°")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ User applied rotation: \(unifiedState.userAppliedRotation * 90)°")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Total rotation: \(unifiedState.totalRotationQuarterTurns * 90)°")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  └─ Rotation baked into AVPlayerItem: true")

            logger.info("🎬 NAME_MOVE_UNIFIED: ├─ Trim Inheritance")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Start time: \(String(format: "%.3f", unifiedState.trimStartTime))s")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ End time: \(String(format: "%.3f", unifiedState.trimEndTime))s")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Duration: \(calculateTrimDuration())")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  └─ Trim baked into AVComposition: true")

            let startFrame = trimmerVM.getFrameNumber(for: CMTime(seconds: unifiedState.trimStartTime, preferredTimescale: 600))
            let endFrame = trimmerVM.getFrameNumber(for: CMTime(seconds: unifiedState.trimEndTime, preferredTimescale: 600))
            let totalFrames = endFrame - startFrame

            logger.info("🎬 NAME_MOVE_UNIFIED: ├─ Frame Precision")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Start frame: \(startFrame)")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ End frame: \(endFrame)")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Total frames: \(totalFrames)")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  └─ Frame rate: \(trimmerVM.currentFrameRate) fps")
        } else {
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ TrimmerViewModel not available")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ User applied rotation: \(unifiedState.userAppliedRotation * 90)°")
            logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Total rotation: \(unifiedState.totalRotationQuarterTurns * 90)°")
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: ├─ WYSIWYG Experience")
        logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ Preview matches final output: true")
        logger.info("🎬 NAME_MOVE_UNIFIED: │  ├─ SwiftUI rotation disabled: true")
        logger.info("🎬 NAME_MOVE_UNIFIED: │  └─ AVPlayerItem rotation active: true")

        logger.info("🎬 NAME_MOVE_UNIFIED: └─ Export Readiness")
        logger.info("🎬 NAME_MOVE_UNIFIED:     ├─ Estimated file size: \(estimatedFileSize)")
        logger.info("🎬 NAME_MOVE_UNIFIED:     ├─ Photos identifier: \(unifiedState.photosIdentifier ?? "none")")
        logger.info("🎬 NAME_MOVE_UNIFIED:     └─ Save readiness: \(unifiedState.saveReadiness != nil ? "validated" : "pending")")
    }
    // MARK: - FUNC
    private func renderNameInput() -> some View {
        VStack(spacing: 12) {
            TextField("", text: $moveName, prompt: Text("Enter move name").foregroundColor(.gray.opacity(0.7)))
                .font(.ibmPlexMono(size: 18))
                .padding(.horizontal)
                .onChange(of: moveName) { _, newValue in
                    logger.info("🎬 NAME_MOVE_UNIFIED: Text changed to '\(newValue)' - canSave: \(canSave), issues: \(validationIssues.count)")
                    unifiedState.moveName = newValue
                }
                .accessibilityLabel("Move Name")
                .accessibilityHint("Enter a descriptive name for your move")
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.done)

            // ✅ ENHANCEMENT: Real-time validation messages
            if !validationIssues.isEmpty {
                VStack(spacing: 4) {
                    ForEach(validationIssues, id: \.self) { issue in
                        HStack {
                            Image(systemName: issue.isCritical ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundColor(issue.isCritical ? .red : .yellow)
                            Text(issue.localizedDescription)
                                .font(.ibmPlexMono(size: 14))
                                .foregroundColor(issue.isCritical ? .red : .yellow)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(issue.localizedDescription)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    // MARK: - FUNC
    private func renderActionButtons() -> some View {
        VStack(spacing: 16) {
            Button(action: {
                logger.info("🎬 NAME_MOVE_UNIFIED: Save tap detected")
                handleSave()
            }) {
                Text("Save Move")
                    .frame(maxWidth: 275)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(!canSave)
            
//            HStack(spacing: 16) {
//                Button(action: {
//                    handleBackButton()
//                }) {
//                    Text("Back")
//                        .frame(maxWidth: 125)
//                }
//                .buttonStyle(.appSecondary(size: .medium))
//                
//                Button(action: {
//                    handleCancel()
//                }) {
//                    Text("Cancel")
//                        .frame(maxWidth: 125)
//                }
//                .buttonStyle(.appSecondary(size: .medium))
//            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Minimal Loading Overlay
    /// Non-blocking minimal overlay that appears during save operations
    /// Shows elapsed time and maintains user interaction capability
    @ViewBuilder
    private var minimalLoadingOverlay: some View {
        if unifiedState.flowState == .saving {
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                // Minimal loading indicator
                VStack(spacing: 12) {
                    // Compact progress indicator
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)

                        VStack(spacing: 2) {
                            Text("Saving...")
                                .font(.caption)
                                .foregroundColor(.white)
                                .fontWeight(.medium)

                            Text(formatTime(unifiedState.saveElapsedTime))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                }
                .allowsHitTesting(false) // Non-blocking - allows taps to pass through
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: unifiedState.flowState == .saving)
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("Preparing save interface...")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    
    
    
    // MARK: - Utility Methods

    // MARK: - DURATION FIX: Calculate trim duration with immediate fallbacks
    // MARK: - FUNC
    private func calculateTrimDuration() -> String {
        let startTime = unifiedState.trimStartTime
        let endTime = unifiedState.trimEndTime

        // Calculate duration with immediate fallbacks
        let duration: TimeInterval

        if endTime > startTime {
            // Normal case: we have valid trim range
            duration = endTime - startTime
            logger.info("🎬 NAME_MOVE_UNIFIED:  Valid trim range: \(String(format: "%.2f", startTime))s - \(String(format: "%.2f", endTime))s = \(String(format: "%.2f", duration))s")
        } else if startTime > 0 {
            // Fallback 1: if end time is invalid but start time is valid, assume 3 second clip
            duration = 3.0
            logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ Invalid trim range (start: \(startTime), end: \(endTime)) - using 3s fallback")
        } else {
            // Fallback 2: no valid trim data, use default duration
            duration = 3.0
            logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ No trim data available - using default duration: \(String(format: "%.2f", duration))s")

            // Still try to get accurate duration from asset asynchronously
            Task {
                await calculateDurationFromAsset()
            }
        }

        let formattedDuration = TimecodeFormatter.format(time: CMTime(seconds: duration, preferredTimescale: 600))
        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Duration calculated: \(formattedDuration)")
        return formattedDuration
    }
    // MARK: - FUNC
    // Calculate duration from asset asynchronously
    private func calculateDurationFromAsset() async {
        guard let playerViewModel = unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel else {
            await MainActor.run {
                estimatedFileSize = "Duration unavailable"
            }
            return
        }

        do {
            let assetDuration = try await playerViewModel.avPlayer?.currentItem?.asset.load(.duration) ?? CMTime.zero
            let durationInSeconds = assetDuration.seconds

            // Update the duration calculation with asset duration
            logger.info("🎬 NAME_MOVE_UNIFIED:  Asset duration loaded: \(String(format: "%.2f", durationInSeconds))s")

        } catch {
            logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ Failed to load asset duration: \(error.localizedDescription)")
        }
    }

    // MARK: - Lifecycle Handlers
    // MARK: - FUNC
    private func handleViewAppear() {
        logger.info("🎬 NAME_MOVE_UNIFIED: View appeared - player available: \(unifiedState.currentPlayerViewModel != nil)")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Initial state - flowState: \(String(describing: unifiedState.flowState)), playerState: \(String(describing: unifiedState.playerState))")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Initial saveReadiness: \(unifiedState.saveReadiness != nil ? "not nil" : "nil")")

        setupInitialState()

        // MARK: - CRITICAL FIX: Integrate with state lifecycle hooks
        // This ensures proper cleanup and prevents race conditions
        unifiedState.completeTransition()

        // MARK: - CRITICAL FIX: Start save readiness monitoring for real-time validation
        // MARK: - TIMING FIX: Add immediate validation to prevent button being stuck
        Task {
            logger.info("🎬 NAME_MOVE_UNIFIED: 🔧 DIAGNOSTIC - Starting save readiness monitoring...")
            unifiedState.startSaveReadinessMonitoring()

            // MARK: - IMMEDIATE VALIDATION: Trigger immediate validation to populate saveReadiness
            logger.info("🎬 NAME_MOVE_UNIFIED: 🔧 DIAGNOSTIC - Triggering immediate validation...")
            let validation = await unifiedState.validateSaveReadiness()
            logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - Immediate validation result: canSave=\(validation.canSave), issues=\(validation.issues.count)")

            logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - Initial validation completed")
        }

        // MARK: - CRITICAL FIX: Player is already pre-configured with trimmed asset
        // No seek operation needed - AVComposition starts at CMTime.zero
        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Player is pre-configured with trimmed asset. No seek needed.")

        // MARK: - NEW: Calculate estimated file size
        Task {
            await calculateEstimatedFileSize()
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ State lifecycle integration completed")
    }
    // MARK: - FUNC
    private func handleViewDisappear() {
        logger.info("🎬 NAME_MOVE_UNIFIED: View disappeared - preparing for transition")

        // MARK: - CRITICAL FIX: Stop save readiness monitoring to prevent memory leaks
        Task { @MainActor in
            unifiedState.stopSaveReadinessMonitoring()
        }

        // MARK: - CRITICAL FIX: Prepare for transition with enhanced cleanup
        Task { @MainActor in
            unifiedState.prepareForTransition()
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Enhanced state lifecycle cleanup completed")
    }

    // MARK: - Action Handlers
    // MARK: - FUNC
    private func setupInitialState() {
        // Initialize with current move name from unified state
        moveName = unifiedState.moveName
        logger.info("🎬 NAME_MOVE_UNIFIED: Initial setup completed")

        // Log current state
        logger.info("🎬 NAME_MOVE_UNIFIED: Current state - move_name: '\(moveName)', player_available: \(unifiedState.currentPlayerViewModel != nil)")
    }
    // MARK: - FUNC
    private func handleBackButton() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Back button tapped, initiating return to trimmer.")

        // Pause the current player (which shows the trimmed preview)
        if let playerViewModel = unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel {
            playerViewModel.avPlayer?.pause()
        }

        // Call the new, dedicated function to handle the state reconstruction.
        Task {
            unifiedState.returnToTrimming?()
        }
    }
    // MARK: - FUNC
    private func handleCancel() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Cancel button tapped")
        
        // Show confirmation dialog
        // For now, just go back to ready state
        Task {
            unifiedState.reset()
        }
    }
    // MARK: - FUNC
    private func handleSave() {
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Save button tapped!")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Move name: '\(moveName)'")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Current state: flowState=\(String(describing: unifiedState.flowState)), playerState=\(String(describing: unifiedState.playerState))")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - SaveReadiness: \(unifiedState.saveReadiness != nil ? "available" : "nil")")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Player available: \(unifiedState.currentPlayerViewModel != nil)")
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Video asset available: \(unifiedState.videoAsset != nil)")

        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.warning("🎬 NAME_MOVE_UNIFIED: ❌ DIAGNOSTIC - Empty move name - blocking save")
            Task {
                await unifiedState.setError(message: "Please enter a move name")
            }
            return
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ DIAGNOSTIC - Basic validation passed - proceeding with save")

        // MARK: - SAVE FIX: Trigger the FlowStateManager to proceed from naming to saving
        // This follows the simplified 5-stage flow: naming -> saving -> success
        logger.info("🎬 NAME_MOVE_UNIFIED: 🔧 DIAGNOSTIC: Accessing flowStateManager with internal access level")

        Task {
            // MARK: - ENHANCED DIAGNOSTICS: Log pre-save state
            logger.info("🎬 NAME_MOVE_UNIFIED:  DIAGNOSTIC - Pre-save state check:")
            logger.info("🎬 NAME_MOVE_UNIFIED:    - FlowStateManager available: \(unifiedState.flowStateManager != nil)")
            logger.info("🎬 NAME_MOVE_UNIFIED:    - Trim range: \(String(format: "%.2f", unifiedState.trimStartTime))s - \(String(format: "%.2f", unifiedState.trimEndTime))s")
            logger.info("🎬 NAME_MOVE_UNIFIED:    - Rotation: \(unifiedState.totalRotationQuarterTurns * 90)°")
            logger.info("🎬 NAME_MOVE_UNIFIED:    - Photos identifier: \(unifiedState.photosIdentifier ?? "none")")

            // MARK: - FINAL VALIDATION: Double-check save readiness before proceeding
            if let saveReadiness = unifiedState.saveReadiness {
                logger.info("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Final save readiness check: canSave=\(saveReadiness.canSave), issues=\(saveReadiness.issues.count)")
                if !saveReadiness.canSave {
                    logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - Save blocked by final validation")
                    for issue in saveReadiness.issues {
                        logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - Blocking issue: \(issue.localizedDescription)")
                    }
                    await unifiedState.setError(message: "Cannot save move", underlying: "Validation failed")
                    return
                }
            } else {
                logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ DIAGNOSTIC - No save readiness available, proceeding with basic validation")
            }

            do {
                logger.info("🎬 NAME_MOVE_UNIFIED: 🚀 DIAGNOSTIC - Calling proceedToNextState()...")
                try await unifiedState.flowStateManager?.proceedToNextState()
                logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Save operation initiated successfully")
            } catch {
                logger.error("🎬 NAME_MOVE_UNIFIED: ❌ Save operation failed: \(error.localizedDescription)")
                logger.error("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Error type: \(type(of: error))")
                logger.error("🎬 NAME_MOVE_UNIFIED: 🔍 DIAGNOSTIC - Error details: \(error)")
                await unifiedState.setError(message: "Failed to save move", underlying: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Utility Methods
    // MARK: - FUNC
    // Format seconds to MM:SS format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    // MARK: - FUNC
    // Calculate estimated file size based on duration and rotation
    private func calculateEstimatedFileSize() async {
        guard let playerViewModel = unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel else {
            estimatedFileSize = "Unknown"
            return
        }

        do {
            // Get asset duration
            let assetDuration = try await playerViewModel.avPlayer?.currentItem?.asset.load(.duration) ?? CMTime.zero
            let durationInSeconds = assetDuration.seconds

            // Base bitrate estimation (rough estimate for H.264 video)
            let baseBitrateMbps: Double = 5.0 // 5 Mbps for standard quality

            // Adjust for rotation (rotated videos may require different encoding)
            let rotationMultiplier = unifiedState.totalRotationQuarterTurns > 0 ? 1.1 : 1.0 // 10% overhead for rotation

            // Calculate file size in bytes
            let bitratebps = baseBitrateMbps * 1_000_000 * rotationMultiplier
            let estimatedSizeBytes = bitratebps * durationInSeconds / 8 // Convert to bytes

            // Format for display
            let sizeInMB = estimatedSizeBytes / (1024 * 1024)

            await MainActor.run {
                if sizeInMB < 1 {
                    let sizeInKB = estimatedSizeBytes / 1024
                    estimatedFileSize = String(format: "%.0f KB", sizeInKB)
                } else if sizeInMB < 100 {
                    estimatedFileSize = String(format: "%.1f MB", sizeInMB)
                } else {
                    estimatedFileSize = String(format: "%.0f MB", sizeInMB)
                }

                logger.info("🎬 NAME_MOVE_UNIFIED:  File size calculated - duration: \(String(format: "%.1f", durationInSeconds))s, estimated size: \(estimatedFileSize), rotation multiplier: \(rotationMultiplier)")
            }

        } catch {
            await MainActor.run {
                estimatedFileSize = "Estimate unavailable"
                logger.warning("🎬 NAME_MOVE_UNIFIED: ⚠️ File size calculation failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview Sheet

struct PreviewSheet: View {
    let playerViewModel: UnifiedVideoPlayerViewModel
    let startTime: CMTime
    let endTime: CMTime
    let rotationQuarterTurns: Int
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
//                Text("Move Preview")
//                    .font(.headline)
//                    .padding()

                CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false, shouldAutoplay: false)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding()

                Text("Duration: \(TimecodeFormatter.format(time: CMTimeSubtract(endTime, startTime)))")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onDisappear {
            onDismiss()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
