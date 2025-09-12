import Foundation
import AVFoundation
import OSLog

@MainActor
public class PreviewOptimizedVideoPlayerInitializer {
    
    public enum PlayerInitializerError: Error, LocalizedError {
        case playerCreationFailed
        case playerItemCreationFailed
        case memoryLimitExceeded(used: Int64, available: Int64)
        
        public var errorDescription: String? {
            switch self {
            case .playerCreationFailed:
                return "Failed to create AVPlayer instance."
            case .playerItemCreationFailed:
                return "Failed to create AVPlayerItem instance."
            case .memoryLimitExceeded(let used, let available):
                return "Memory limit exceeded. Used: \(used)MB, Available: \(available)MB"
            }
        }
    }
    
    private let memoryManager: MemoryManager
    private let logger: AppLogger
    
    init(memoryManager: MemoryManager, logger: AppLogger) {
        self.memoryManager = memoryManager
        self.logger = logger
    }
    
    public func createPlayer(from asset: AVAsset, quarterTurns: Int = 0) async throws -> AVPlayer {
        // Check memory before creating player with stricter threshold for preview
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 50 * 1024 * 1024 // 50MB (stricter for preview)
        
        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory before creating preview player: \(availableMemory / (1024 * 1024))MB", metadata: nil)
            memoryManager.clearCache()
            
            // If still low, throw error
            if memoryManager.getAvailableMemory() < memoryThreshold {
                let error = PlayerInitializerError.memoryLimitExceeded(
                    used: memoryManager.getUsedMemory() / (1024 * 1024),
                    available: availableMemory / (1024 * 1024)
                )
                logger.error("❌ Memory limit exceeded for preview player: \(error.localizedDescription)", metadata: nil)
                throw error
            }
        }
        
        let playerItem = try await createPlayerItem(from: asset, quarterTurns: quarterTurns)
        let player = AVPlayer(playerItem: playerItem)
        
        // Apply preview-specific player optimizations
        await optimizePlayerForPreview(player)
        
        return player
    }
    
    public func createPlayerItem(from asset: AVAsset, quarterTurns: Int = 0) async throws -> AVPlayerItem {
        if quarterTurns == 0 {
            let playerItem = AVPlayerItem(asset: asset)
            
            // Apply preview-specific optimizations to the player item
            await optimizePlayerItemForPreview(playerItem)
            
            return playerItem
        } else {
            // For rotated videos, we need to create a composition with transformations
            // but still with preview optimizations
            let result = try await VideoTransformBuilder.build(asset: asset, quarterTurns: quarterTurns)
            let item = AVPlayerItem(asset: result.composition)
            item.videoComposition = result.videoComposition
            
            // Apply preview-specific optimizations to the transformed player item
            await optimizePlayerItemForPreview(item)
            
            return item
        }
    }
    
    // MARK: - Private Methods
    
    private func optimizePlayerForPreview(_ player: AVPlayer) async {
        // Set lower quality for preview
        // Note: appliesMediaSelectionCriteriaAutomatically is not available in AVPlayer
        // This property is only available in AVPlayerItem
        
        // Configure player for lower memory usage
        if let playerItem = player.currentItem {
            // Set lower bitrate for preview
            playerItem.preferredPeakBitRate = 2_000_000 // 2 Mbps for preview
            
            // Set smaller buffer for faster loading
            playerItem.preferredForwardBufferDuration = 1.0
            
            // Disable automatic media selection to reduce memory usage
            do {
                if let mediaSelectionGroup = try await playerItem.asset.loadMediaSelectionGroup(for: .visual) {
                    // AVMediaSelectionOption doesn't have an array() method
                    // We'll use nil instead of an array to indicate no specific option
                    playerItem.select(nil, in: mediaSelectionGroup)
                }
            } catch {
                logger.warning("⚠️ Failed to load media selection group: \(error.localizedDescription)", metadata: nil)
            }
        }
        
        logger.info("✅ Applied preview optimizations to player", metadata: nil)
    }
    
    private func optimizePlayerItemForPreview(_ playerItem: AVPlayerItem) async {
        // Set lower bitrate for preview
        playerItem.preferredPeakBitRate = 2_000_000 // 2 Mbps for preview
        
        // Set smaller buffer for faster loading
        playerItem.preferredForwardBufferDuration = 1.0
        
        // Set lower resolution if available
        let videoTracks = try? await playerItem.asset.loadTracks(withMediaType: .video)
        if !(videoTracks?.isEmpty ?? true) {
            // The asset loader already handles lower quality for preview
            // but we can apply additional player item-specific optimizations here
            
            // This would require custom video composition to enforce resolution
            // For now, we rely on the asset loader's optimizations
        }
        
        // Configure audio for preview (lower quality)
        let audioTracks = try? await playerItem.asset.loadTracks(withMediaType: .audio)
        if !(audioTracks?.isEmpty ?? true) {
            // Audio optimizations could be applied here if needed
        }
        
        // Disable automatic media selection to reduce memory usage
        // Note: appliesMediaSelectionCriteriaAutomatically was deprecated in iOS 16
        // and automaticallySelectedMediaCharacteristics is not available in current iOS version
        // We'll handle media selection manually when needed
        
        logger.info("✅ Applied preview optimizations to player item", metadata: nil)
    }
}

// MARK: - Preview Optimized Video Transform Builder
extension VideoTransformBuilder {
    static func buildForPreview(asset: AVAsset, quarterTurns: Int) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition) {
        // Use the standard transform builder but with preview-specific optimizations
        let result = try await build(asset: asset, quarterTurns: quarterTurns)
        
        // Apply preview-specific optimizations to the video composition
        result.videoComposition.renderScale = 0.5 // Lower render scale for preview
        
        // Set lower frame rate for preview if possible
        if let videoTrack = (try? await asset.loadTracks(withMediaType: .video))?.first {
            let originalFrameRate = try? await videoTrack.load(.nominalFrameRate)
            let previewFrameRate = min(originalFrameRate ?? 30.0, 30.0) // Cap at 30fps for preview
            
            // This would require custom video composition to adjust frame rate
            // For now, we just log the optimization
            // Use the logger instance instead of creating a new Logger
            let logger = Logger(subsystem: "com.breakingflashcards", category: "PreviewOptimizedPlayerInitializer")
            logger.info("Preview frame rate: \(previewFrameRate) (original: \(originalFrameRate ?? 0.0))")
        }
        
        return result
    }
}