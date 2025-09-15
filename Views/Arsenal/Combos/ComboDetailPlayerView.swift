import SwiftUI
import AVKit

struct ComboDetailPlayerView: View {
    let move: Move?
    
    private func getVideoAsset(for move: Move) -> AVAsset? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return AVURLAsset(url: url)
    }
    
    var body: some View {
        if let move = move,
           let asset = getVideoAsset(for: move) {
            CustomVideoPlayerView(viewModel: UnifiedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: Int(move.rotationQuarterTurns), mode: .main, appContainer: AppContainer.shared))
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