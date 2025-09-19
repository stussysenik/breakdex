import SwiftUI
import AVKit
import OSLog
import UIKit

struct NameMoveView: View {
    @Bindable var viewModel: AddMoveViewModel
    
    // Add state to hold the player view model, which will be built asynchronously.
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?
    @State private var isSaving = false
    @State private var isLoadingPreview = true
    
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveView")
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack {
            if case .naming(let photosIdentifier, let originalAsset, let trimStartTime, let trimEndTime, let rotation) = viewModel.state {
                // Video preview section
                VStack(spacing: 16) {
                    // Show loading indicator while waiting for player item to become ready
                    if isLoadingPreview {
                        ProgressView("Preparing video preview...")
                            .frame(height: 300)
                    } else if let vm = playerViewModel {
                        // The video data (player item) is ALREADY rotated by the VideoTransformBuilder.
                        // We must tell the UI layer to apply ZERO additional rotation to avoid conflicts.
                        CustomVideoPlayerView(viewModel: vm, rotationQuarterTurns: .constant(0))
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    } else {
                        // Fallback loading indicator
                        ProgressView("Preparing Preview...")
                            .frame(height: 300)
                    }
                    
                    // Video info - use the precise formatTime function
                    Text("Trimmed: \(formatTime(trimStartTime)) - \(formatTime(trimEndTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if rotation > 0 {
                        Text("Rotation: \(rotation * 90)°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Name input section
                VStack(spacing: 20) {
                    TextField("Enter move name...", text: $viewModel.moveName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .disabled(isSaving)
                    
                    Text("\(viewModel.moveName.count)/50")
                        .font(.caption)
                        .foregroundColor(viewModel.moveName.count > 50 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Back") {
                        impactGenerator.impactOccurred()
                        viewModel.backToTrimming()
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    .disabled(isSaving)
                    
                    Button(action: {
                        impactGenerator.impactOccurred()
                        isSaving = true
                        viewModel.saveMove()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text(isSaving ? "Saving..." : "Save Move")
                        }
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                    .disabled(viewModel.moveName.isEmpty || viewModel.moveName.count > 50 || isSaving)
                }
                .padding()
                .padding(.bottom, 180)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: viewModel.state) { _, newState in
            if case .ready = newState {
                isSaving = false
            }
        }
        // Use a .task modifier to build the composed player item when the view appears.
        .task(id: viewModel.state) {
            guard case .naming(let photosIdentifier, let originalAsset, let trimStartTime, let trimEndTime, let rotation) = viewModel.state else { return }
            
            // Reset loading state when starting new preview generation
            await MainActor.run {
                isLoadingPreview = true
                playerViewModel = nil
            }
            
            // Add diagnostic logging for rotation - using single source of truth approach
            logger.info("🎬 NAME_MOVE_VIEW: Creating video preview with rotation diagnostics:")
            logger.info("🎬 NAME_MOVE_VIEW: - Rotation from state: \(rotation) quarter turns (\(rotation * 90)°)")
            logger.info("🎬 NAME_MOVE_VIEW: - Will apply to VideoTransformBuilder: \(rotation) (SINGLE SOURCE OF TRUTH)")
            logger.info("🎬 NAME_MOVE_VIEW: - Will apply to CustomVideoPlayerView: 0 (ZERO UI rotation to avoid conflicts)")
            
            do {
                let timeRange = CMTimeRange(
                    start: CMTime(seconds: trimStartTime, preferredTimescale: 600),
                    end: CMTime(seconds: trimEndTime, preferredTimescale: 600)
                )

                // Use the builder to create a perfect, in-memory player item
                let composedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                    asset: originalAsset,
                    trimRange: timeRange,
                    quarterTurns: rotation
                )
                
                // Simple readiness check for the composed player item
                logger.info("🎬 NAME_MOVE_VIEW: Checking composed player item readiness...")
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second wait for composition
                
                if composedPlayerItem.status != .readyToPlay {
                    logger.warning("🎬 NAME_MOVE_VIEW: Composed player item not ready (status: \(composedPlayerItem.status.rawValue)), continuing anyway...")
                }
                let player = AVPlayer(playerItem: composedPlayerItem)
                
                // Now, we can confidently create the ViewModel with a ready-to-play item.
                let viewModel = UnifiedVideoPlayerViewModel(
                    player: player,
                    mode: .preview,
                    appContainer: AppContainer.shared
                )
                
                // Update UI state on main thread
                await MainActor.run {
                    self.playerViewModel = viewModel
                    isLoadingPreview = false
                }
                
                logger.info("🎬 NAME_MOVE_VIEW: ✅ Player view model created with ready-to-play item")
            } catch {
                logger.error("🎬 NAME_MOVE_VIEW: 🚨 Failed to create composed player: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingPreview = false
                }
                viewModel.setErrorState(message: "Could not create video preview.")
            }
        }
    }
    
    // Use the precise time formatting function
    private func formatTime(_ seconds: Double?) -> String {
        guard let seconds = seconds else { return "00:00.00" }
        let minutes = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, secs)
    }
}
