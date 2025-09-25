import SwiftUI
import AVKit

struct ComboDetailPlayerView: View {
    let move: Move?
    
    private func getVideoAsset(for move: Move) -> AVAsset? {
        // 🎯 FIXED: Use photosIdentifier instead of deprecated videoReference
        guard let photosIdentifier = move.photosIdentifier else {
            return nil
        }

        // Use synchronous check for asset existence first
        guard PhotosAssetLoader.assetExists(with: photosIdentifier) else {
            return nil
        }

        // For UI purposes, we'll create a simple AVAsset placeholder
        // The actual video loading will happen asynchronously in the player
        // This is a temporary solution for UI compatibility
        return AVAsset(url: URL(string: "photos://\(photosIdentifier)")!)
    }
    
    var body: some View {
        if let move = move,
           let asset = getVideoAsset(for: move) {
            CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)), mode: .main, appContainer: AppContainer.shared))
                .frame(height: 300)
                .cornerRadius(10)
                .padding(.horizontal)
                .id(move.managedObjectID) // Force re-initialization when activeMove changes
        } else {
            ContentUnavailableView("No video available", systemImage: "video.slash")
                .frame(height: 300)
                .cornerRadius(10)
                .padding(.horizontal)
        }
    }
}