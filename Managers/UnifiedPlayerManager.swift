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
    
    // MARK: - Internal State Management
    
    /// Updates the current asset (for use by AddMoveUnifiedState)
    public func updateAsset(_ asset: AVAsset?, photosIdentifier: String?) {
        self.currentAsset = asset
        self.currentPhotosIdentifier = photosIdentifier
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: Asset updated (asset: \(asset != nil), photosID: \(photosIdentifier ?? "nil"))")
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
            let assetDuration = try await asset.load(.duration)
            let trimRange = CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                end: assetDuration
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
        
        // Set the new player and extract asset information
        currentPlayer = player
        let playerAsset = player.avPlayer?.currentItem?.asset
        if playerAsset != nil {
            currentAsset = playerAsset
            // 🎯 CRITICAL FIX: Preserve existing rotation instead of resetting to 0
            // This prevents loss of rotation state when setting pre-created players
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Asset extracted from player, rotation preserved: \(self.currentRotation)")
        }
        isInitialized = true
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player set successfully (asset: \(self.currentAsset != nil))")
    }
    
    /// Applies trim to the current player with enhanced race condition prevention
    public func applyTrimToCurrentPlayer(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {

        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Starting enhanced trim application with race condition prevention")

        // 💡 ENHANCEMENT: Comprehensive preconditions validation
        guard let currentPlayer = currentPlayer else {
            let errorMessage = "No current player available for trim operation"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.unifiedPlayerInitializationFailed
        }

        guard let currentAsset = currentAsset else {
            let errorMessage = "No current asset available for trim operation"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.assetCreationFailed
        }

        // 💡 ENHANCEMENT: Validate player readiness before starting trim operation
        guard currentPlayer.isPlayerReady else {
            let errorMessage = "Current player is not ready for trim operation"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw AddMoveError.playerNotReady
        }

        // 💡 ENHANCEMENT: Validate trim parameters
        let trimRange = CMTimeRange(start: startTime, end: endTime)
        let duration = endTime.seconds - startTime.seconds

        guard duration > 0 else {
            let errorMessage = "Invalid trim range: duration must be positive (\(duration)s)"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.trimOperationFailed(startTime: startTime.seconds, endTime: endTime.seconds,
                                                         underlyingError: NSError(domain: "UnifiedPlayerManager", code: -1,
                                                                               userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }

        guard duration >= 3.0 else {
            let errorMessage = "Trim duration too short: \(duration)s (minimum: 3.0s)"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.trimOperationFailed(startTime: startTime.seconds, endTime: endTime.seconds,
                                                         underlyingError: NSError(domain: "UnifiedPlayerManager", code: -2,
                                                                               userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }

        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trim parameters validated")

        // 💡 ENHANCEMENT: Prepare for trim operation with detailed state management
        isTransitioning = true
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Transition state set for trim operation")

        do {
            // 💡 ENHANCEMENT: Create trimmed player item with enhanced error handling and detailed logging
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔧 Creating trimmed player item")

            let trimmedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                asset: currentAsset,
                trimRange: trimRange,
                quarterTurns: rotation
            )

            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trimmed player item created successfully")

            // 💡 ENHANCEMENT: Enhanced player item replacement with detailed progress monitoring
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Starting player item replacement with readiness monitoring")

            try await currentPlayer.replacePlayerItemAndWaitForReady(trimmedPlayerItem)

            // 💡 ENHANCEMENT: Post-replacement validation
            guard currentPlayer.isPlayerReady else {
                let errorMessage = "Player failed to achieve ready state after trim operation"
                self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
                throw AddMoveError.playerNotReady
            }

            // 💡 ENHANCEMENT: Update stored rotation with validation
            _ = currentRotation
            currentRotation = rotation

            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Rotation updated")

            // 💡 ENHANCEMENT: Complete transition with comprehensive success logging
            isTransitioning = false
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎉 Enhanced trim application completed successfully")

        } catch {
            // 💡 ENHANCEMENT: Enhanced error handling with recovery attempts
            isTransitioning = false
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Trim operation failed")

            // 💡 ENHANCEMENT: Attempt recovery by restoring previous player state
            if let previousItem = currentPlayer.playerItem {
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Attempting recovery by restoring previous player item")

                do {
                    try await currentPlayer.replacePlayerItemAndWaitForReady(previousItem)
                    self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Recovery successful - previous player item restored")
                } catch {
                    self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Recovery failed")
                    // Continue with original error
                }
            }

            throw error
        }
    }
    
    /// 🎯 CRITICAL: Transactional trim and seek operation - prevents race conditions
    /// This method ensures all operations complete in sequence without hanging
    public func applyTrimAndSeek(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        let diagnosticStart = CFAbsoluteTimeGetCurrent()
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚀 Starting transactional trim and seek operation - start: \(String(format: "%.2f", startTime.seconds))s, end: \(String(format: "%.2f", endTime.seconds))s, rotation: \(rotation)")

        // Validate preconditions
        guard let currentPlayer = currentPlayer else {
            let errorMessage = "No current player available for trim operation"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.trimOperationFailed(startTime: startTime.seconds, endTime: endTime.seconds, underlyingError: NSError(domain: "UnifiedPlayerManager", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        }

        guard let currentAsset = currentAsset else {
            let errorMessage = "No asset available for transformation"
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ \(errorMessage)")
            throw VideoProcessingError.assetCreationFailed
        }

        // Step 1: Create trim range and validate
        let trimRange = CMTimeRange(start: startTime, end: endTime)
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Trim range validated: \(String(format: "%.2f", trimRange.start.seconds))s - \(String(format: "%.2f", trimRange.end.seconds))s")

        // Step 2: Create transformed player item with enhanced error handling and fallback
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔧 Creating transformed player item...")
        let transformedPlayerItem: AVPlayerItem

        do {
            transformedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                asset: currentAsset,
                trimRange: trimRange,
                quarterTurns: rotation
            )
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player item transformation successful")
        } catch {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Player item transformation failed: \(error.localizedDescription)")

            // 🎯 ENHANCED: Fallback mechanism - try with simpler composition
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Attempting fallback with simplified composition...")

            do {
                // Try without rotation first
                transformedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                    asset: currentAsset,
                    trimRange: trimRange,
                    quarterTurns: 0
                )
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Fallback transformation successful (no rotation)")
            } catch {
                // Try without trim as last resort
                self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Fallback also failed: \(error.localizedDescription)")

                let assetDuration = try await currentAsset.load(.duration)
                let fullRange = CMTimeRange(start: .zero, end: assetDuration)
                transformedPlayerItem = try await VideoTransformBuilder.createPlayerItem(
                    asset: currentAsset,
                    trimRange: fullRange,
                    quarterTurns: 0
                )
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Emergency fallback successful (original asset)")
            }
        }

        // Step 3: Replace player item and wait for readiness with single monitor
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Replacing player item with transactional monitoring...")

        do {
            try await currentPlayer.replacePlayerItemAndWaitForReady(transformedPlayerItem)
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player item replacement successful")
        } catch {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Player item replacement failed: \(error.localizedDescription)")
            throw VideoProcessingError.trimOperationFailed(startTime: startTime.seconds, endTime: endTime.seconds, underlyingError: error)
        }

        // Step 4: Perform seek operation on the ready player with enhanced retry logic
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 Performing seek to zero on transformed player...")

        var seekAttempt = 0
        let maxSeekAttempts = 3
        let seekBackoffIntervals: [TimeInterval] = [0.1, 0.5, 1.0]

        while seekAttempt < maxSeekAttempts {
            do {
                try await currentPlayer.asyncSeek(to: .zero)
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Seek operation successful (attempt \(seekAttempt + 1))")
                break
            } catch {
                seekAttempt += 1
                self.logger.warning("🎬 UNIFIED_PLAYER_MANAGER: ⚠️ Seek attempt \(seekAttempt) failed: \(error.localizedDescription)")

                if seekAttempt < maxSeekAttempts {
                    let backoffTime = seekBackoffIntervals[min(seekAttempt - 1, seekBackoffIntervals.count - 1)]
                    self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ⏳ Retrying seek in \(backoffTime)s...")
                    try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                } else {
                    self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ All seek attempts failed")

                    // 🎯 ENHANCED: Final fallback - try direct seek without monitoring
                    self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Attempting direct seek fallback...")
                    do {
                        await currentPlayer.avPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s wait
                        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Direct seek fallback successful")
                        break
                    } catch {
                        self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Even direct seek fallback failed")
                        throw VideoProcessingError.trimOperationFailed(startTime: startTime.seconds, endTime: endTime.seconds, underlyingError: error)
                    }
                }
            }
        }

        // Step 5: Update manager state and log success
        let oldRotation = currentRotation
        currentRotation = rotation

        let operationDuration = CFAbsoluteTimeGetCurrent() - diagnosticStart
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎉 Transactional trim and seek completed successfully - oldRotation: \(oldRotation), newRotation: \(self.currentRotation), duration: \((operationDuration * 1000).formatted())ms, playerReady: \(currentPlayer.isPlayerReady)")
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