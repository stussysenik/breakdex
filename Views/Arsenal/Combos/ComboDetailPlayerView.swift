import SwiftUI
import AVKit
import OSLog

struct ComboDetailPlayerView: View {
    let move: Move?
    @State private var player: AVPlayer?

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎬 COMBO_DETAIL_PLAYER_VIEW")

    var body: some View {
        ZStack {
            if let player = player {
                CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(player: player, mode: .main, appContainer: AppContainer.shared))
            } else if move != nil {
                // Show a loader while the asset is being fetched
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading video...")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.textSecondary)
                }
            } else {
                // Default view when no move is selected
                ContentUnavailableView("No video available", systemImage: "video.slash")
            }
        }
        .frame(height: 300)
        .background(Color.black)
        .cornerRadius(10)
        .padding(.horizontal)
        .task(id: move?.id) { // Re-run this task when the move changes
            logger.info("🎬 COMBO_DETAIL_PLAYER_VIEW: Starting video load for move '\(move?.name ?? "Unknown")'")
            player = nil // Reset the player to show the loader
            guard let identifier = move?.photosIdentifier else {
                logger.error("🎬 COMBO_DETAIL_PLAYER_VIEW: No photosIdentifier for move '\(move?.name ?? "Unknown")'")
                return
            }

            if let avAsset = await PhotosAssetLoader.fetchAsset(with: identifier) {
                logger.info("🎬 COMBO_DETAIL_PLAYER_VIEW: Video asset loaded successfully for move '\(move?.name ?? "Unknown")'")
                // Once the asset is loaded, create the player on the main thread
                await MainActor.run {
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                }
            } else {
                logger.error("🎬 COMBO_DETAIL_PLAYER_VIEW: Failed to load video asset for move '\(move?.name ?? "Unknown")'")
            }
        }
        .onDisappear {
            logger.info("🎬 COMBO_DETAIL_PLAYER_VIEW: View disappearing, cleaning up player")
            player?.pause()
            player = nil
        }
    }
}