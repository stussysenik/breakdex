import SwiftUI
import AVFoundation
import OSLog

// MARK: - Unified Player Manager
/// A persistent manager for the unified video player that survives view transitions
@MainActor
public class UnifiedPlayerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentPlayer: UnifiedVideoPlayerViewModel?
    @Published public private(set) var isTransitioning = false
    @Published public private(set) var currentAsset: AVAsset?
    @Published public private(set) var currentRotation: Int = 0
    @Published public private(set) var currentPhotosIdentifier: String?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "UnifiedPlayerManager")
    private var isInitialized = false
    
    // MARK: - Initialization
    public init() {
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Initialized")
    }
    
    // MARK: - Public API
    
    /// Creates or updates the unified player with the specified asset
    public func createOrUpdatePlayer(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int,
        appContainer: AppContainer
    ) async throws -> UnifiedVideoPlayerViewModel {
        
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Creating/updating player for asset")
        
        // Check if we can reuse existing player
        if let existingPlayer = currentPlayer,
           currentAsset == asset,
           currentRotation == rotationQuarterTurns {
            logger.info("🎬 UNIFIED_PLAYER_MANAGER: Reusing existing player")
            return existingPlayer
        }
        
        // Cleanup existing player if needed
        if let existingPlayer = currentPlayer {
            logger.info("🎬 UNIFIED_PLAYER_MANAGER: Cleaning up existing player")
            existingPlayer.teardown()
        }
        
        // Create new player
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        let newPlayer = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: appContainer
        )
        
        // Wait for player to be ready
        try await waitForPlayerReady(newPlayer)
        
        // Store player state
        currentPlayer = newPlayer
        currentAsset = asset
        currentRotation = rotationQuarterTurns
        currentPhotosIdentifier = photosIdentifier
        isInitialized = true
        
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player created and ready")
        return newPlayer
    }
    
    /// Gets the current player if available and ready
    public func getCurrentPlayer() -> UnifiedVideoPlayerViewModel? {
        guard let player = currentPlayer,
              player.isPlayerReady else {
            logger.warning("🎬 UNIFIED_PLAYER_MANAGER: No ready player available")
            return nil
        }
        return player
    }
    
    /// Applies trim to the current player
    public func applyTrimToCurrentPlayer(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Applying trim to current player")
        
        guard let currentPlayer = currentPlayer,
              let currentAsset = currentAsset else {
            logger.error("🎬 UNIFIED_PLAYER_MANAGER: No player or asset available for trim")
            throw VideoProcessingError.unifiedPlayerInitializationFailed
        }
        
        let trimRange = CMTimeRange(start: startTime, end: endTime)
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Trim range: \(startTime.seconds) - \(endTime.seconds)")
        
        // Create trimmed player item
        let trimmedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
            asset: currentAsset,
            trimRange: trimRange,
            quarterTurns: rotation
        )
        
        // Replace player item and wait for readiness
        try await currentPlayer.replacePlayerItemAndWaitForReady(trimmedPlayerItem)
        
        // Update stored rotation
        currentRotation = rotation
        
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trim applied successfully")
    }
    
    /// Prepares for a state transition
    public func prepareForTransition() {
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Preparing for transition")
        isTransitioning = true
        currentPlayer?.avPlayer?.pause()
    }
    
    /// Completes a state transition
    public func completeTransition() {
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Completing transition")
        isTransitioning = false
    }
    
    /// Cleans up all resources
    public func cleanup() {
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: Cleaning up resources")
        
        if let player = currentPlayer {
            player.teardown()
            currentPlayer = nil
        }
        
        currentAsset = nil
        currentRotation = 0
        currentPhotosIdentifier = nil
        isInitialized = false
        
        logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Cleanup completed")
    }
    
    // MARK: - Private Methods
    
    /// Waits for player to be ready with timeout
    private func waitForPlayerReady(_ player: UnifiedVideoPlayerViewModel) async throws {
        let timeout: TimeInterval = 10.0
        
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                // Wait for player to be ready
                repeat {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                } while await !player.isPlayerReady
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw VideoProcessingError.readinessTimeout
            }
            
            for try await _ in group {
                return
            }
        }
    }
}

// MARK: - Video Processing Error Extension
extension VideoProcessingError {
    static var unifiedPlayerInitializationFailed: VideoProcessingError {
        return .playerInitializationFailed
    }
}