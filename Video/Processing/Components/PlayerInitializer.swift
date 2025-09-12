import Foundation
import AVFoundation

@MainActor
public class PlayerInitializer {
    
    public enum PlayerInitializerError: Error, LocalizedError {
        case playerCreationFailed
        case playerItemCreationFailed
        
        public var errorDescription: String? {
            switch self {
            case .playerCreationFailed:
                return "Failed to create AVPlayer instance."
            case .playerItemCreationFailed:
                return "Failed to create AVPlayerItem instance."
            }
        }
    }
    
    public func createPlayer(from asset: AVAsset, quarterTurns: Int = 0) async throws -> AVPlayer {
        let playerItem = try await createPlayerItem(from: asset, quarterTurns: quarterTurns)
        let player = AVPlayer(playerItem: playerItem)
        
        return player
    }
    
    public func createPlayerItem(from asset: AVAsset, quarterTurns: Int = 0) async throws -> AVPlayerItem {
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