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
    
    
    @ViewBuilder
    private var mainContentView: some View {
        if let playerViewModel = unifiedState.currentPlayerViewModel {
            mainContent(with: playerViewModel)
        } else {
            Text("Player not available")
                .foregroundColor(.white)
                .padding()
        }
    }
    
    // MARK: - Computed Properties
    private var canSave: Bool {
        !moveName.trimmingCharacters(in: .whitespaces).isEmpty &&
        unifiedState.currentPlayerViewModel != nil
    }
    
    // MARK: - Body
    var body: some View {
        // 🎯 DEFENSIVE FIX: Ensure the player view model is available before rendering.
        // This makes the view more robust against unexpected state inconsistencies.
        Group {
            if unifiedState.currentPlayerViewModel != nil {
                mainContentView
                    .onAppear {
                        logger.info("🎬 NAME_MOVE_UNIFIED: View appeared - player available: \(unifiedState.currentPlayerViewModel != nil)")
                        setupInitialState()
                        
                        // 🎯 CRITICAL FIX: Integrate with state lifecycle hooks
                        // This ensures proper cleanup and prevents race conditions
                        unifiedState.completeTransition()
                        
                        // 🎯 CRITICAL FIX: Start save readiness monitoring for real-time validation
                        unifiedState.startSaveReadinessMonitoring()
                        
                        // 🎯 CRITICAL FIX: Player is already pre-configured with trimmed asset
                        // No seek operation needed - AVComposition starts at CMTime.zero
                        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Player is pre-configured with trimmed asset. No seek needed.")
                        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ State lifecycle integration completed")
                    }
                    .onDisappear {
                        logger.info("🎬 NAME_MOVE_UNIFIED: View disappeared - preparing for transition")
                        
                        // 🎯 CRITICAL FIX: Stop save readiness monitoring to prevent memory leaks
                        unifiedState.stopSaveReadinessMonitoring()
                        
                        // 🎯 CRITICAL FIX: Prepare for transition with enhanced cleanup
                        unifiedState.prepareForTransition()
                        
                        logger.info("🎬 NAME_MOVE_UNIFIED: ✅ Enhanced state lifecycle cleanup completed")
                    }
            } else {
                // Render a fallback UI if the player is not ready, preventing a crash.
                loadingView
                    .onAppear {
                        logger.warning("⚠️ NAME_MOVE_UNIFIED: Appeared without a player view model. Flow state: \(String(describing: unifiedState.flowState))")
                    }
            }
        }
        .sheet(isPresented: $isShowingPreview) {
            if let playerViewModel = unifiedState.currentPlayerViewModel {
                PreviewSheet(
                    playerViewModel: playerViewModel,
                    startTime: CMTime(seconds: unifiedState.trimStartTime, preferredTimescale: 600),
                    endTime: CMTime(seconds: unifiedState.trimEndTime, preferredTimescale: 600),
                    rotationQuarterTurns: unifiedState.rotationQuarterTurns,
                    onDismiss: {
                        isShowingPreview = false
                    }
                )
            }
        }
    }
    
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
//            Text("Name Your Move")
//                .font(.headline)
//                .foregroundColor(.white)
            Spacer()
//            Button(action: {
//                isShowingPreview = true
//            }) {
//                Text("Preview")
//                    .font(.headline)
//                    .foregroundColor(.blue)
//            }
        }
        .padding()
    }
    
    private func renderVideoPreview(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 8) {
//            Text("Preview")
//                .font(.subheadline)
//                .foregroundColor(.gray)
            
            CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false, shouldAutoplay: false)
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
            
            // Trim info
            HStack {
                Text("Duration: \(TimecodeFormatter.format(time: CMTimeSubtract(CMTime(seconds: unifiedState.trimEndTime, preferredTimescale: 600), CMTime(seconds: unifiedState.trimStartTime, preferredTimescale: 600))))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if unifiedState.rotationQuarterTurns > 0 {
                    Text("Rotation: \(unifiedState.rotationQuarterTurns * 90)°")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private func renderNameInput() -> some View {
        VStack(spacing: 12) {
//            Text("Move Name")
//                .font(.ibmPlexMono(size: 16, weight: .medium))
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal)
//                .accessibilityHidden(true)

            TextField("", text: $moveName, prompt: Text("Enter move name").foregroundColor(.gray.opacity(0.7)))
//                .textFieldStyle(.squareBorder)
                .font(.ibmPlexMono(size: 18))
                .padding(.horizontal)
                .onChange(of: moveName) { _, newValue in
                    logger.info("🎬 NAME_MOVE_UNIFIED: Text changed to '\(newValue)' - canSave: \(canSave)")
                    unifiedState.moveName = newValue
                }
                .accessibilityLabel("Move Name")
                .accessibilityHint("Enter a descriptive name for your move")
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.done)
        }
    }
    
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
    
    
    
    
    // MARK: - Action Handlers
    
    private func setupInitialState() {
        // Initialize with current move name from unified state
        moveName = unifiedState.moveName
        logger.info("🎬 NAME_MOVE_UNIFIED: Initial setup completed")
        
        // Log current state
        logger.info("🎬 NAME_MOVE_UNIFIED: Current state - move_name: '\(moveName)', player_available: \(unifiedState.currentPlayerViewModel != nil)")
    }
    
    private func handleBackButton() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Back button tapped")
        
        // Pause player
        unifiedState.currentPlayerViewModel?.avPlayer?.pause()
        
        // Return to trimming state
        Task {
            await unifiedState.transitionTo(.trimming)
        }
    }
    
    private func handleCancel() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Cancel button tapped")
        
        // Show confirmation dialog
        // For now, just go back to ready state
        Task {
            unifiedState.reset()
        }
    }
    
    private func handleSave() {
        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            Task {
                await unifiedState.setError(message: "Please enter a move name")
            }
            return
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: Save button tapped for '\(moveName)'")

        // 🎯 CRITICAL FIX: Save timer is now managed by AddMoveUnifiedState to prevent memory leaks
        // Call unified state's saveMove() function which handles the entire save process including timing
        Task {
            await unifiedState.saveMove()
        }
    }
    
    // MARK: - Utility Methods

    // Format seconds to MM:SS format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
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
