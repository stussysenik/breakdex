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
    
    // 💡 SOLUTION: Player cache for frequently used assets
    private var playerCache: [String: UnifiedVideoPlayerViewModel] = [:]
    private let maxCacheSize = 3
    
    // MARK: - Initialization
    public init() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Initialized")
    }
    
    // MARK: - Public API
    
    /// Creates or updates the unified player with the specified asset
    public func createOrUpdatePlayer(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int,
        appContainer: AppContainer
    ) async throws -> UnifiedVideoPlayerViewModel {
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Creating/updating player for asset")
        
        // 💡 SOLUTION: Preserve player across view transitions unless asset truly changes
        if let existingPlayer = currentPlayer,
           currentAsset == asset,
           currentRotation == rotationQuarterTurns {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Reusing existing player - no changes needed")
            return existingPlayer
        }
        
        // If only rotation changes, preserve the player and just update rotation
        if let existingPlayer = currentPlayer,
           currentAsset == asset,
           currentRotation != rotationQuarterTurns {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Updating rotation only - preserving player")
            
            // Apply new rotation to existing player
            let trimRange = CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                end: asset.duration
            )
            
            let transformedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns
            )
            
            // Replace player item without destroying the player
            try await existingPlayer.replacePlayerItemAndWaitForReady(transformedPlayerItem)
            
            // Update stored rotation
            currentRotation = rotationQuarterTurns
            
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Rotation updated, player preserved")
            return existingPlayer
        }
        
        // Only create new player if asset actually changes
        if let existingPlayer = currentPlayer {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Asset changed - creating new player")
            
            // Pause current player before transition
            existingPlayer.avPlayer?.pause()
            
            // Don't teardown - preserve for potential cache reuse
        }
        
        // Create new player with optimized lifecycle
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        let newPlayer = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: appContainer
        )
        
        // Wait for player to be ready with timeout protection
        try await waitForPlayerReady(newPlayer)
        
        // Store player state
        currentPlayer = newPlayer
        currentAsset = asset
        currentRotation = rotationQuarterTurns
        currentPhotosIdentifier = photosIdentifier
        isInitialized = true
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ New player created and ready (asset changed)")
        return newPlayer
    }
    
    /// Gets the current player if available and ready
    public func getCurrentPlayer() -> UnifiedVideoPlayerViewModel? {
        guard let player = currentPlayer,
              player.isPlayerReady else {
            self.logger.warning("🎬 UNIFIED_PLAYER_MANAGER: No ready player available")
            return nil
        }
        return player
    }
    
    /// Sets a pre-created player as the current player
    public func setPlayer(_ player: UnifiedVideoPlayerViewModel) {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Setting pre-created player")
        
        // Clean up existing player if any
        if let existingPlayer = currentPlayer {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Cleaning up existing player")
            existingPlayer.avPlayer?.pause()
            // Don't teardown - preserve for potential cache reuse
        }
        
        // Set the new player
        currentPlayer = player
        isInitialized = true
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player set successfully")
    }
    
    /// Applies trim to the current player
    public func applyTrimToCurrentPlayer(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Applying trim to current player")
        
        guard let currentPlayer = currentPlayer,
              let currentAsset = currentAsset else {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: No player or asset available for trim")
            throw VideoProcessingError.unifiedPlayerInitializationFailed
        }
        
        let trimRange = CMTimeRange(start: startTime, end: endTime)
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Trim range: \(startTime.seconds) - \(endTime.seconds)")
        
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
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trim applied successfully")
    }
    
    /// Applies trim and rotation to the current player for previewing in NameMoveView
    public func applyTrimAndRotationForPreview(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Applying trim and rotation for preview")
        
        guard let currentAsset = currentAsset else {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: No asset available for transformation")
            throw VideoProcessingError.assetCreationFailed
        }
        
        let trimRange = CMTimeRange(start: startTime, end: endTime)
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Preview transform - Trim: \(startTime.seconds)-\(endTime.seconds), Rotation: \(rotation * 90)°")
        
        // Use existing builder to create transformed player item
        let transformedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
            asset: currentAsset,
            trimRange: trimRange,
            quarterTurns: rotation
        )
        
        // Replace the player's current item and wait for it to be ready
        try await currentPlayer?.replacePlayerItemAndWaitForReady(transformedPlayerItem)
        
        // Update the manager's state to reflect the new rotation
        currentRotation = rotation
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trim and rotation applied successfully for preview")
    }
    
    /// Prepares for a state transition
    public func prepareForTransition() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Preparing for transition")
        isTransitioning = true
        currentPlayer?.avPlayer?.pause()
    }
    
    /// Completes a state transition
    public func completeTransition() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Completing transition")
        isTransitioning = false
    }
    
    /// Cleans up all resources
    public func cleanup() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Cleaning up resources")
        
        // Tear down current player
        if let player = currentPlayer {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Tearing down current player")
            player.teardown()
            currentPlayer = nil
        }
        
        // Clear cache and tear down all cached players
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Clearing player cache")
        for (key, player) in playerCache {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Tearing down cached player: \(key.prefix(8))")
            player.teardown()
        }
        playerCache.removeAll()
        
        currentAsset = nil
        currentRotation = 0
        currentPhotosIdentifier = nil
        isInitialized = false
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Cleanup completed")
    }
    
    /// Gets a cache key for the asset and rotation
    private func getCacheKey(for asset: AVAsset, rotation: Int) -> String {
        let assetID = ObjectIdentifier(asset).hashValue
        return "\(assetID)_\(rotation)"
    }
    
    /// Caches a player for future reuse
    private func cachePlayer(_ player: UnifiedVideoPlayerViewModel, for asset: AVAsset, rotation: Int) {
        let cacheKey = getCacheKey(for: asset, rotation: rotation)
        
        // Evict oldest items if cache is full
        while playerCache.count >= maxCacheSize {
            if let oldestKey = playerCache.keys.first {
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Evicting cached player: \(oldestKey.prefix(8))")
                playerCache[oldestKey]?.teardown()
                playerCache.removeValue(forKey: oldestKey)
            }
        }
        
        playerCache[cacheKey] = player
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Cached player: \(cacheKey.prefix(8))")
    }
    
    /// Prepares for view transition - preserves player
    public func prepareForViewTransition() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Preparing for view transition")
        
        // Pause player but don't teardown - preserve across transitions
        currentPlayer?.avPlayer?.pause()
        isTransitioning = true
    }
    
    /// Completes view transition - resumes player if appropriate
    public func completeViewTransition() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Completing view transition")
        isTransitioning = false
        
        // Player is preserved and ready for the next view
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player preserved across transition")
    }
    
    // MARK: - Private Methods
    
    /// Waits for player to be ready with improved timeout and backoff
    private func waitForPlayerReady(_ player: UnifiedVideoPlayerViewModel) async throws {
        let timeout: TimeInterval = 15.0 // Increased timeout for reliability
        let checkInterval: TimeInterval = 0.1 // 100ms initial check
        let maxBackoff: TimeInterval = 1.0 // Maximum backoff to 1 second
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Waiting for player readiness (timeout: \(timeout)s)")
        
        let startTime = Date()
        var currentBackoff = checkInterval
        
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                // Wait for player to be ready with exponential backoff
                while await !player.isPlayerReady {
                    let elapsed = Date().timeIntervalSince(startTime)
                    
                    if elapsed > timeout {
                        self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: Player readiness timeout after \(elapsed)s")
                        throw VideoProcessingError.readinessTimeout
                    }
                    
                    // Exponential backoff to reduce CPU usage during long waits
                    try await Task.sleep(nanoseconds: UInt64(currentBackoff * 1_000_000_000))
                    currentBackoff = min(currentBackoff * 1.5, maxBackoff) // Exponential backoff with ceiling
                    
                    self.logger.debug("🎬 UNIFIED_PLAYER_MANAGER: Still waiting for player readiness... (\(String(format: "%.1f", elapsed))s elapsed)")
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player became ready after \(String(format: "%.2f", totalTime))s")
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: Hard timeout reached after \(timeout)s")
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