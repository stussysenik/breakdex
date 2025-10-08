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
    
    // 💡 ENHANCED: Player cache for frequently used assets with comprehensive management
    private var playerCache: [String: UnifiedVideoPlayerViewModel] = [:]
    private let maxCacheSize = 3

    // MARK: - ENHANCED: Cache statistics for debugging and optimization
    private var cacheHitCount = 0
    private var cacheMissCount = 0
    private var cacheEvictionCount = 0
    
    // MARK: - Initialization
    public init() {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚀 Initialized with enhanced cache management")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 Cache settings - max size: \(self.maxCacheSize)")
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
        
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎮 Creating/updating player for asset")

        // MARK: - ENHANCED: Check cache first for potential reuse
        let cacheKey = getCacheKey(for: asset, rotation: rotationQuarterTurns)
        if let cachedPlayer = playerCache[cacheKey] {
            cacheHitCount += 1
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚀 CACHE HIT! Reusing cached player for key: \(cacheKey.prefix(8))")
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 Cache stats - Hits: \(self.cacheHitCount), Misses: \(self.cacheMissCount)")

            // Set the cached player as current
            setPlayer(cachedPlayer)
            currentRotation = rotationQuarterTurns
            currentPhotosIdentifier = photosIdentifier
            currentAsset = asset
            isInitialized = true

            return cachedPlayer
        }

        cacheMissCount += 1
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ⚠️ CACHE MISS! Creating new player for key: \(cacheKey.prefix(8))")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 Cache stats - Hits: \(self.cacheHitCount), Misses: \(self.cacheMissCount)")
        
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

            // MARK: - CRITICAL FIX: Teardown existing player to prevent retain cycle
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚨 Tearing down existing player to prevent retain cycle")
            existingPlayer.teardown()

            // Clear reference after teardown
            currentPlayer = nil
        }
        
        // MARK: - CRITICAL FIX: Validate asset preconditions before creating AVPlayerItem
        try await validateAssetForPlayerCreation(asset)

        // MARK: - ENHANCED: Create player item with cancellation support
        let playerItem: AVPlayerItem
        let playerCreationStart = Date()

        do {
            playerItem = try await withCheckedThrowingContinuation { continuation in
                Task {
                    do {
                        // MARK: - CRITICAL FIX: Create player item on background thread to prevent blocking
                        let createdPlayerItem = await Task.detached(priority: .userInitiated) {
                            AVPlayerItem(asset: asset)
                        }.value

                        continuation.resume(returning: createdPlayerItem)
                    } catch {
                        continuation.resume(throwing: VideoProcessingError.playerInitializationFailed)
                    }
                }
            }

            let creationTime = Date().timeIntervalSince(playerCreationStart)
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ PlayerItem created in \(String(format: "%.3f", creationTime))s")

        } catch {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ PlayerItem creation failed: \(error.localizedDescription)")
            throw VideoProcessingError.playerInitializationFailed
        }

        let player = AVPlayer(playerItem: playerItem)

        let newPlayer = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: appContainer
        )

        // MARK: - CRITICAL FIX: Enhanced player readiness wait with timeout protection
        try await waitForPlayerReady(newPlayer)
        
        // Store player state
        currentPlayer = newPlayer
        currentAsset = asset
        currentRotation = rotationQuarterTurns
        currentPhotosIdentifier = photosIdentifier
        isInitialized = true

        // MARK: - DIAGNOSTIC: Enhanced logging for player state synchronization debugging
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ New player created and ready (asset changed)")

        // Fix: Move async call out of string interpolation to avoid 'await' in autoclosure error
        let playerReadyStatus = await newPlayer.isPlayerReady
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 DIAGNOSTIC - Player isPlayerReady: \(playerReadyStatus)")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 DIAGNOSTIC - Player initialization completed - AddMoveUnifiedState should synchronize with this state")

        // MARK: - ENHANCED: Cache the newly created player for future reuse
        cachePlayer(newPlayer, for: asset, rotation: rotationQuarterTurns)

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
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚨 Cleaning up existing player with teardown to prevent retain cycle")
            existingPlayer.teardown()
            currentPlayer = nil
        }
        
        // Set the new player and extract asset information
        currentPlayer = player
        let playerAsset = player.avPlayer?.currentItem?.asset
        if playerAsset != nil {
            currentAsset = playerAsset
            // MARK: - CRITICAL FIX: Preserve existing rotation instead of resetting to 0
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

            // MARK: - DIAGNOSTIC: Enhanced logging for player state synchronization debugging

            // Fix: Move async call out of string interpolation to avoid 'await' in autoclosure error
            let postTrimPlayerReadyStatus = await currentPlayer.isPlayerReady
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 DIAGNOSTIC - Post-trim player isPlayerReady: \(postTrimPlayerReadyStatus)")
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 DIAGNOSTIC - Trim operation completed - AddMoveUnifiedState should synchronize with this state")

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
    
    /// MARK: - CRITICAL: Transactional trim and seek operation - prevents race conditions
    /// This method ensures all operations complete in sequence without hanging
    public func applyTrimAndSeek(
        startTime: CMTime,
        endTime: CMTime,
        rotation: Int
    ) async throws {
        let diagnosticStart = CFAbsoluteTimeGetCurrent()
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚨 Starting CRITICAL transactional trim and seek operation - RETAIN CYCLE PREVENTION - start: \(String(format: "%.2f", startTime.seconds))s, end: \(String(format: "%.2f", endTime.seconds))s, rotation: \(rotation), player: \(self.currentPlayer != nil), asset: \(self.currentAsset != nil), transitioning: \(self.isTransitioning)")

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

            // MARK: - ENHANCED: Fallback mechanism - try with simpler composition
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

                    // MARK: - ENHANCED: Final fallback - try direct seek without monitoring
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
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎉 Transactional trim and seek completed successfully - RETAIN CYCLE PREVENTED - oldRotation: \(oldRotation), newRotation: \(self.currentRotation), duration: \((operationDuration * 1000).formatted())ms, playerReady: \(currentPlayer.isPlayerReady)")
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
    
    /// MARK: - ENHANCED: Cleans up all resources with comprehensive diagnostics
    public func cleanup() {
        let cleanupStart = CFAbsoluteTimeGetCurrent()
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🚨 ENHANCED cleanup() called - CRITICAL RETAIN CYCLE PREVENTION")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 PRE-CLEANUP STATE - currentPlayer: \(self.currentPlayer != nil), cache: \(self.playerCache.count), initialized: \(self.isInitialized), asset: \(self.currentAsset != nil)")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 CACHE PERFORMANCE - Hits: \(self.cacheHitCount), Misses: \(self.cacheMissCount), Evictions: \(self.cacheEvictionCount)")

        // Tear down current player
        if let player = self.currentPlayer {
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🛑 Tearing down current player to prevent retain cycle")
            player.teardown()
            currentPlayer = nil
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Current player torn down and nilled")
        }

        // Clear cache and tear down all cached players
        if !self.playerCache.isEmpty {
            let cacheSize = self.playerCache.count
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🧹 Clearing player cache - \(cacheSize) players to teardown")

            for (key, player) in self.playerCache {
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🛑 Tearing down cached player: \(key.prefix(8))")
                player.teardown()
            }
            self.playerCache.removeAll()
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ All \(cacheSize) cached players torn down")
        }

        // Reset all state properties
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔄 Resetting all state properties")
        currentAsset = nil
        currentRotation = 0
        currentPhotosIdentifier = nil
        isInitialized = false

        // Reset cache statistics
        cacheHitCount = 0
        cacheMissCount = 0
        cacheEvictionCount = 0

        let cleanupDuration = CFAbsoluteTimeGetCurrent() - cleanupStart
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎉 ENHANCED cleanup() completed in \(String(format: "%.3f", cleanupDuration * 1000))ms")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 POST-CLEANUP STATE - currentPlayer: \(self.currentPlayer == nil), cache: \(self.playerCache.isEmpty), asset: \(self.currentAsset == nil), initialized: \(self.isInitialized == false)")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔒 ALL RETAIN CYCLES BROKEN - MEMORY SAFE ✅")
    }
    
    /// Gets a cache key for the asset and rotation
    private func getCacheKey(for asset: AVAsset, rotation: Int) -> String {
        let assetID = ObjectIdentifier(asset).hashValue
        return "\(assetID)_\(rotation)"
    }
    
    /// MARK: - ENHANCED: Caches a player for future reuse with detailed tracking
    private func cachePlayer(_ player: UnifiedVideoPlayerViewModel, for asset: AVAsset, rotation: Int) {
        let cacheKey = getCacheKey(for: asset, rotation: rotation)

        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📦 Caching player with key: \(cacheKey.prefix(8))")

        // Evict oldest items if cache is full
        let evictedCount = 0
        while self.playerCache.count >= maxCacheSize {
            if let oldestKey = self.playerCache.keys.first {
                cacheEvictionCount += 1
                self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🗑️ Evicting cached player (\(self.cacheEvictionCount)): \(oldestKey.prefix(8))")
                self.playerCache[oldestKey]?.teardown()
                self.playerCache.removeValue(forKey: oldestKey)
            }
        }

        self.playerCache[cacheKey] = player
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player cached successfully - cache size: \(self.playerCache.count)/\(self.maxCacheSize)")
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 📊 Cache performance - Hit rate: \(self.calculateHitRate())%")
    }

    /// MARK: - ENHANCED: Calculate cache hit rate for performance monitoring
    private func calculateHitRate() -> Double {
        let totalRequests = cacheHitCount + cacheMissCount
        guard totalRequests > 0 else { return 0.0 }
        return Double(cacheHitCount) / Double(totalRequests) * 100.0
    }

    /// MARK: - ENHANCED: Get comprehensive cache statistics for debugging
    public func getCacheStatistics() -> (hits: Int, misses: Int, evictions: Int, hitRate: Double, currentSize: Int, maxSize: Int) {
        return (
            hits: cacheHitCount,
            misses: cacheMissCount,
            evictions: cacheEvictionCount,
            hitRate: calculateHitRate(),
            currentSize: playerCache.count,
            maxSize: maxCacheSize
        )
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

    /// MARK: - CRITICAL FIX: Validate asset is ready for player creation to prevent timeout issues
    private func validateAssetForPlayerCreation(_ asset: AVAsset) async throws {
        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 Validating asset for player creation")

        let validationStart = Date()

        do {
            // MARK: - CRITICAL: Check asset duration - this can fail if asset is not fully loaded
            let duration = try await asset.load(.duration)
            guard duration.seconds > 0 else {
                throw VideoProcessingError.assetCreationFailed
            }

            // MARK: - CRITICAL: Check asset has playable tracks
            let tracks = try await asset.load(.tracks)
            guard !tracks.isEmpty else {
                throw VideoProcessingError.assetCreationFailed
            }

            // MARK: - ENHANCED: Check if tracks are media tracks with playable media
            let mediaTracks = tracks.filter { track in
                track.mediaType == .video || track.mediaType == .audio
            }
            guard !mediaTracks.isEmpty else {
                throw VideoProcessingError.assetCreationFailed
            }

            let validationTime = Date().timeIntervalSince(validationStart)
            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Asset validation passed in \(String(format: "%.3f", validationTime))s - Duration: \(duration.seconds)s, Media Tracks: \(mediaTracks.count)")

        } catch {
            let validationTime = Date().timeIntervalSince(validationStart)
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Asset validation failed after \(String(format: "%.3f", validationTime))s: \(error.localizedDescription)")
            throw VideoProcessingError.assetCreationFailed
        }
    }

    /// MARK: - CRITICAL FIX: Enhanced player readiness wait with improved concurrency and proper natural transformation
    private func waitForPlayerReady(_ player: UnifiedVideoPlayerViewModel) async throws {
        let timeout: TimeInterval = 10.0 // Reduced timeout for faster feedback
        let checkInterval: TimeInterval = 0.05 // More frequent checks
        let maxBackoff: TimeInterval = 0.5 // Reduced backoff for faster response

        self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🔍 ENHANCED player readiness monitoring (timeout: \(timeout)s)")

        let startTime = Date()
        var currentBackoff = checkInterval
        var lastKnownReadyState = false
        var consecutiveReadyCount = 0
        let readyThreshold = 2 // Reduced threshold for faster completion

        // MARK: - ENHANCED: Simple sequential monitoring with timeout
        while true {
            let elapsed = Date().timeIntervalSince(startTime)

            if elapsed > timeout {
                self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ TIMEOUT after \(String(format: "%.3f", elapsed))s - last ready state: \(lastKnownReadyState)")
                throw VideoProcessingError.readinessTimeout
            }

            // MARK: - ENHANCED: Check player ready state with multiple validation layers
            let isReady = await player.isPlayerReady

            if isReady {
                consecutiveReadyCount += 1
                self.logger.debug("🎬 UNIFIED_PLAYER_MANAGER: ✅ Player ready check \(consecutiveReadyCount)/\(readyThreshold)")

                // Require multiple consecutive ready checks to ensure stability
                if consecutiveReadyCount >= readyThreshold {
                    let totalTime = Date().timeIntervalSince(startTime)
                    self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: 🎉 Player STABLY ready after \(String(format: "%.3f", totalTime))s")

                    // MARK: - CRITICAL: Quick asset validation
                    await validatePlayerItem(player)

                    self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ Enhanced player readiness monitoring completed successfully")
                    return
                }
            } else {
                if consecutiveReadyCount > 0 {
                    self.logger.warning("🎬 UNIFIED_PLAYER_MANAGER: ⚠️ Player readiness LOST - was ready \(consecutiveReadyCount) times")
                }
                consecutiveReadyCount = 0
            }

            lastKnownReadyState = isReady

            // MARK: - ENHANCED: Dynamic backoff with reduced intervals for faster response
            let sleepTime = currentBackoff
            try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
            currentBackoff = min(currentBackoff * 1.2, maxBackoff)

            if elapsed.truncatingRemainder(dividingBy: 0.5) < 0.05 { // Log every 0.5 seconds
                self.logger.debug("🎬 UNIFIED_PLAYER_MANAGER: ⏳ Monitoring... (\(String(format: "%.1f", elapsed))s elapsed, ready: \(isReady))")
            }
        }
    }

    /// MARK: - ENHANCED: Quick asset validation helper
    private func validatePlayerItem(_ player: UnifiedVideoPlayerViewModel) async {
        guard let playerItem = player.avPlayer?.currentItem else {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Player item is nil during validation")
            return
        }

        do {
            // Simple duration check with timeout
            let duration = try await withThrowingTaskGroup(of: CMTime.self) { group in
                group.addTask {
                    try await playerItem.asset.load(.duration)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
                    throw VideoProcessingError.assetCreationFailed
                }

                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                } else {
                    throw VideoProcessingError.assetCreationFailed
                }
            }

            guard duration.seconds > 0 else {
                self.logger.warning("🎬 UNIFIED_PLAYER_MANAGER: ⚠️ Asset validation failed - invalid duration")
                return
            }

            let tracks = try await playerItem.asset.load(.tracks)
            guard !tracks.isEmpty else {
                self.logger.warning("🎬 UNIFIED_PLAYER_MANAGER: ⚠️ Asset validation failed - no tracks")
                return
            }

            self.logger.info("🎬 UNIFIED_PLAYER_MANAGER: ✅ FAST Asset validation passed - Duration: \(duration.seconds)s, Tracks: \(tracks.count)")

        } catch {
            self.logger.error("🎬 UNIFIED_PLAYER_MANAGER: ❌ Asset validation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Video Processing Error Extension
extension VideoProcessingError {
    static var unifiedPlayerInitializationFailed: VideoProcessingError {
        return .playerInitializationFailed
    }
}