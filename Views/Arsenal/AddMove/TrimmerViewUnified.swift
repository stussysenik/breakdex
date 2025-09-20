import SwiftUI
import AVFoundation
import Combine
import OSLog

private let logger = Logger(subsystem: "com.breakingflashcards", category: "TrimmerViewUnified")

/// State-driven Trimmer view that uses AddMoveUnifiedState
/// Eliminates direct ViewModel dependencies and State Object Churn
struct TrimmerViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    
    // MARK: - State
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    private var canProceed: Bool {
        unifiedState.canProceed && unifiedState.trimmerViewModel?.isValidTrim == true
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let playerViewModel = unifiedState.currentPlayerViewModel,
               let trimmerViewModel = unifiedState.trimmerViewModel {
                mainContent(with: playerViewModel, trimmerViewModel: trimmerViewModel)
            } else {
                loadingView
            }
        }
        .onAppear {
            logger.info("🎬 TRIMMER_UNIFIED: View appeared - trimmer available: \(unifiedState.trimmerViewModel != nil)")
        }
        .onDisappear {
            logger.info("🎬 TRIMMER_UNIFIED: View disappeared - preparing for transition")
            unifiedState.prepareForTransition()
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private func mainContent(with playerViewModel: UnifiedVideoPlayerViewModel, trimmerViewModel: TrimmerViewModel) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARK: - Video Player Section
            Group {
                if playerViewModel.isPlayerReady {
                    TrimmerPlayerViewUnified(playerViewModel: playerViewModel)
                } else {
                    loadingState
                }
            }
            
            Spacer()
            
            // MARK: - Trimmer Interface
            VStack(spacing: 8) {
                Spacer()
                
                // Time code display
                timeCodeDisplay(with: trimmerViewModel)
                
                // Main trimmer with handles
                mainTrimmerSection(with: trimmerViewModel)
                
                // Control buttons
                controlSection
                
                // Minimum duration warning
                if trimmerViewModel.showMinimumDurationWarning {
                    minimumDurationWarning
                }
                
                Spacer()
            }
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }
    
    // MARK: - UI Components
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Preparing trimmer...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading video player...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .frame(height: 300)
        .background(Color.black.ignoresSafeArea())
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func timeCodeDisplay(with trimmerViewModel: TrimmerViewModel) -> some View {
        HStack {
            Text(formatTime(trimmerViewModel.startTime.seconds))
                .font(.caption)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(formatTime(trimmerViewModel.endTime.seconds))
                .font(.caption)
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal)
    }
    
    private func mainTrimmerSection(with trimmerViewModel: TrimmerViewModel) -> some View {
        VStack(spacing: 4) {
            // Timeline scrubber
            TimelineScrubberUnified(
                trimmerViewModel: trimmerViewModel,
                onTimeChange: { newTime in
                    handleTimeChange(newTime)
                }
            )
            
            // Handle area with enhanced interaction
            GeometryReader { geometry in
                ZStack {
                    // Timeline track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // Selected range
                    let startX = calculateHandlePosition(trimmerViewModel.startTime, duration: trimmerViewModel.duration, geometryWidth: geometry.size.width)
                    let endX = calculateHandlePosition(trimmerViewModel.endTime, duration: trimmerViewModel.duration, geometryWidth: geometry.size.width)
                    
                    Rectangle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: endX - startX, height: 4)
                        .position(x: (startX + endX) / 2, y: 2)
                    
                    // Handle for start time
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .position(x: startX, y: 20)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newTime = calculateTimeFromPosition(value.location.x, duration: trimmerViewModel.duration, geometryWidth: geometry.size.width)
                                    let clampedTime = max(CMTime.zero, min(trimmerViewModel.endTime - CMTime(seconds: 1, preferredTimescale: 600), newTime))
                                    trimmerViewModel.startTime = clampedTime
                                }
                        )
                    
                    // Handle for end time
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .position(x: endX, y: 20)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newTime = calculateTimeFromPosition(value.location.x, duration: trimmerViewModel.duration, geometryWidth: geometry.size.width)
                                    let clampedTime = max(trimmerViewModel.startTime + CMTime(seconds: 1, preferredTimescale: 600), min(trimmerViewModel.duration, newTime))
                                    trimmerViewModel.endTime = clampedTime
                                }
                        )
                }
            }
            .frame(height: 40)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    private func calculateHandlePosition(_ time: CMTime, duration: CMTime, geometryWidth: CGFloat) -> CGFloat {
        return CGFloat(time.seconds / duration.seconds) * geometryWidth
    }
    
    private func calculateTimeFromPosition(_ position: CGFloat, duration: CMTime, geometryWidth: CGFloat) -> CMTime {
        return CMTime(seconds: (position / geometryWidth) * duration.seconds, preferredTimescale: 600)
    }
    
    private var controlSection: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: {
                handleBackButton()
            }) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back")
                }
            }
            .buttonStyle(.appSecondary(size: .small))
            
            Spacer()
            
            // Rotation controls
            HStack(spacing: 8) {
                Button(action: {
                    handleRotationChange(-1)
                }) {
                    Image(systemName: "rotate.left")
                }
                .buttonStyle(.appSecondary(size: .small))
                
                Text("\(unifiedState.rotationQuarterTurns * 90)°")
                    .font(.caption)
                    .foregroundColor(.textPrimary)
                
                Button(action: {
                    handleRotationChange(1)
                }) {
                    Image(systemName: "rotate.right")
                }
                .buttonStyle(.appSecondary(size: .small))
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                handleContinue()
            }) {
                Text("Continue")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.appPrimary(size: .small))
            .disabled(!canProceed)
        }
        .padding(.horizontal)
    }
    
    private var minimumDurationWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("Video must be at least 1 second long")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Action Handlers
    
    private func handleTimeChange(_ newTime: TimeInterval) {
        logger.debug("🎬 TRIMMER_UNIFIED: Time changed to \(newTime)")
        // Additional time change handling if needed
    }
    
    private func handleBackButton() {
        logger.info("🎬 TRIMMER_UNIFIED: Back button tapped")
        
        // Pause player
        unifiedState.currentPlayerViewModel?.avPlayer?.pause()
        
        // Return to preview state
        unifiedState.transitionTo(.previewing)
    }
    
    private func handleRotationChange(_ delta: Int) {
        logger.info("🎬 TRIMMER_UNIFIED: Rotation change requested: \(delta)")
        
        let newRotation = unifiedState.rotationQuarterTurns + delta
        let clampedRotation = max(0, min(3, newRotation)) // 0-3 quarter turns
        
        guard clampedRotation != unifiedState.rotationQuarterTurns else { return }
        
        Task {
            do {
                // Apply rotation with current trim settings
                try await unifiedState.applyTrimSettings(
                    startTime: unifiedState.trimStartTime,
                    endTime: unifiedState.trimEndTime,
                    rotation: clampedRotation
                )
                
                // Update trimmer view model
                unifiedState.trimmerViewModel?.rotationQuarterTurns = clampedRotation
                
                logger.info("🎬 TRIMMER_UNIFIED: Rotation updated to \(clampedRotation * 90)°")
            } catch {
                unifiedState.setError(message: "Failed to apply rotation", underlying: error.localizedDescription)
            }
        }
    }
    
    private func handleContinue() {
        logger.info("🎬 TRIMMER_UNIFIED: Continue button tapped")
        
        guard let trimmerViewModel = unifiedState.trimmerViewModel else {
            unifiedState.setError(message: "Trimmer not ready")
            return
        }
        
        // Validate trim range
        guard trimmerViewModel.isValidTrim else {
            unifiedState.setError(message: "Invalid trim range")
            return
        }
        
        // Apply final trim settings
        Task {
            do {
                try await unifiedState.applyTrimSettings(
                    startTime: trimmerViewModel.startTime.seconds,
                    endTime: trimmerViewModel.endTime.seconds,
                    rotation: trimmerViewModel.rotationQuarterTurns
                )
                
                // Transition to naming state
                unifiedState.transitionTo(.naming)
                
                logger.info("🎬 TRIMMER_UNIFIED: Transitioned to naming state")
            } catch {
                unifiedState.setError(message: "Failed to apply trim settings", underlying: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

/// Simplified player view for trimmer
struct TrimmerPlayerViewUnified: View {
    @ObservedObject var playerViewModel: UnifiedVideoPlayerViewModel
    
    var body: some View {
        CustomVideoPlayerView(viewModel: playerViewModel)
            .frame(height: 300)
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

/// Simplified timeline scrubber for trimmer
struct TimelineScrubberUnified: View {
    @ObservedObject var trimmerViewModel: TrimmerViewModel
    let onTimeChange: (TimeInterval) -> Void
    
    var body: some View {
        EmptyView() // Simplified for now - timeline scrubbing handled in main section
    }
}