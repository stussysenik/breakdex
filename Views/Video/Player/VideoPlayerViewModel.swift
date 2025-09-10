import SwiftUI
import AVKit
import Combine

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    enum State {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }

    @Published private(set) var state: State = .loading

    private var player: AVPlayer?
    private var buildTask: Task<Void, Never>?
    private var generation = 0

    deinit {
        teardown()
    }

    func setSource(asset: AVAsset, quarterTurns: Int) {
        buildTask?.cancel()
        generation &+= 1
        let currentGeneration = generation

        state = .loading

        buildTask = Task {
            do {
                let playerItem = try await createPlayerItem(for: asset, quarterTurns: quarterTurns)
                if Task.isCancelled { return }

                // Fence against stale tasks
                guard currentGeneration == self.generation else { return }

                let newPlayer = AVPlayer(playerItem: playerItem)
                self.player = newPlayer
                self.state = .playing(player: newPlayer)
                newPlayer.play()
            } catch {
                if Task.isCancelled { return }
                guard currentGeneration == self.generation else { return }
                self.state = .error(message: "Failed to load video: \(error.localizedDescription)")
            }
        }
    }

    func setRotation(_ quarterTurns: Int) {
        guard let asset = player?.currentItem?.asset else { return }
        setSource(asset: asset, quarterTurns: quarterTurns)
    }

    func teardown() {
        buildTask?.cancel()
        player?.pause()
        player = nil
        state = .loading
    }

    private func createPlayerItem(for asset: AVAsset, quarterTurns: Int) async throws -> AVPlayerItem {
        if quarterTurns == 0 {
            return AVPlayerItem(asset: asset)
        } else {
            let result = try await VideoTransformBuilder.build(asset: asset, quarterTurns: quarterTurns)
            let item = AVPlayerItem(asset: result.composition)
            item.videoComposition = result.videoComposition
            return item
        }
    }
}
