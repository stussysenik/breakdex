import SwiftUI
import AVKit
import Combine
import OSLog

private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoPlayerViewModel")

// Function to log memory usage
private func logMemoryUsage(context: String) {
    let memory = os_proc_available_memory()
    let memoryMB = Double(memory) / (1024 * 1024)
    logger.info("🎬 VIDEO_PLAYER_VM: MEMORY [\(context)]: \(String(format: "%.1f", memoryMB)) MB available")
}

@MainActor
public final class VideoPlayerViewModel: ObservableObject, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: VideoPlayerViewModel, rhs: VideoPlayerViewModel) -> Bool {
        lhs.player == rhs.player && lhs.generation == rhs.generation
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(player)
        hasher.combine(generation)
    }
    
    // Static counters for debugging player instances and memory
    private static nonisolated(unsafe) var playerInstanceCount = 0
    private static nonisolated(unsafe) var viewRecomputeCount = 0
    public enum State {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }

    @Published public private(set) var state: State = .loading

    private var player: AVPlayer?
    @Published private(set) var shouldPlay: Bool = false
    private var readinessObserver: NSKeyValueObservation?

    /// Public getter for AVPlayer access (for logging and debugging)
    var avPlayer: AVPlayer? {
        player
    }
    private var buildTask: Task<Void, Never>?
    private var generation = 0
    @Published var isPlayerReady: Bool = false
    private var readinessContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var initializationContinuation: CheckedContinuation<Void, Error>?
    private var initializationTimeoutTask: Task<Void, Never>?
    private var isInitialized: Bool = false

    // MARK: - Synchronous Initialization

    /// Initialize with asset and rotation for immediate use
    /// Single Responsibility: Manage complete AVPlayer lifecycle
    public init(asset: AVAsset, rotationQuarterTurns: Int) {
        Self.viewRecomputeCount += 1
        logger.info("🎬 VIDEO_PLAYER_VM: Synchronous init with asset (Recompute #\(Self.viewRecomputeCount))")
        logMemoryUsage(context: "init_start")

        logger.info("🎬 VIDEO_PLAYER_VM: Asset type: \(type(of: asset))")
        logger.info("🎬 VIDEO_PLAYER_VM: Rotation: \(rotationQuarterTurns)°")

        // Log detailed asset information
        logger.info("🎬 VIDEO_PLAYER_VM: Asset duration: \(asset.duration.seconds) seconds")
        logger.info("🎬 VIDEO_PLAYER_VM: Asset tracks count: \(asset.tracks.count)")
        logger.info("🎬 VIDEO_PLAYER_VM: Asset isPlayable: \(asset.isPlayable)")
        logger.info("🎬 VIDEO_PLAYER_VM: Asset hasProtectedContent: \(asset.hasProtectedContent)")

        logMemoryUsage(context: "init_asset_loaded")

        // Start async setup immediately
        setupWithAsset(asset, rotationQuarterTurns: rotationQuarterTurns)
    }

    /// Legacy initializer for backward compatibility
    public init() {
        logger.info("🎬 VIDEO_PLAYER_VM: Legacy init (no asset)")
    }

    deinit {
        logger.info("🎬 VIDEO_PLAYER_VM: deinit called (Instance count was \(Self.playerInstanceCount))")
        logMemoryUsage(context: "deinit_start")
        Task { @MainActor in
            teardown()
        }
        Self.playerInstanceCount -= 1
        logger.info("🎬 VIDEO_PLAYER_VM: deinit completed (Current instance count: \(Self.playerInstanceCount))")
        logMemoryUsage(context: "deinit_end")
    }

    // MARK: - Synchronous Setup

    private func setupWithAsset(_ asset: AVAsset, rotationQuarterTurns: Int) {
        logger.info("🎬 VIDEO_PLAYER_VM: Starting synchronous setup (Generation: \(self.generation))")
        logMemoryUsage(context: "setup_start")

        buildTask?.cancel()
        self.generation &+= 1
        let currentGeneration = self.generation
        isPlayerReady = false
        isInitialized = false

        // Clean up any existing observer and timeout task
        readinessObserver?.invalidate()
        readinessObserver = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Clean up initialization related tasks
        initializationContinuation = nil
        initializationTimeoutTask?.cancel()
        initializationTimeoutTask = nil

        state = .loading
        logger.info("🎬 VIDEO_PLAYER_VM: State changed to loading (Frequency: \(Self.viewRecomputeCount))")

        buildTask = Task {
            defer { logMemoryUsage(context: "buildTask_end") }
            do {
                logger.info("🎬 VIDEO_PLAYER_VM: Creating player item")
                logMemoryUsage(context: "before_createPlayerItem")
                let playerItem = try await createPlayerItem(for: asset, quarterTurns: rotationQuarterTurns)
                logMemoryUsage(context: "after_createPlayerItem")
                if Task.isCancelled {
                    logger.info("🎬 VIDEO_PLAYER_VM: Setup cancelled (Task cancelled)")
                    return
                }

                // Fence against stale tasks
                guard currentGeneration == self.generation else {
                    logger.info("🎬 VIDEO_PLAYER_VM: Setup superseded (Generation mismatch: \(currentGeneration) vs \(self.generation))")
                    return
                }

                logger.info("🎬 VIDEO_PLAYER_VM: Creating AVPlayer (Current instance count: \(Self.playerInstanceCount))")
                logMemoryUsage(context: "before_AVPlayer_creation")
                let newPlayer = AVPlayer(playerItem: playerItem)
                Self.playerInstanceCount += 1
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer created (New instance count: \(Self.playerInstanceCount))")
                self.player = newPlayer

                // CRITICAL: Log AVPlayer state immediately after creation
                logger.info("🎬 VIDEO_PLAYER_VM: 🔍 AVPlayer created - diagnostic check")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer status: \(newPlayer.status.rawValue) (\(newPlayer.status == .readyToPlay ? "readyToPlay" : newPlayer.status == .failed ? "failed" : "unknown"))")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer currentItem exists: \(newPlayer.currentItem != nil)")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer currentItem status: \(newPlayer.currentItem?.status.rawValue ?? -1) (\(newPlayer.currentItem?.status == .readyToPlay ? "readyToPlay" : newPlayer.currentItem?.status == .failed ? "failed" : "unknown"))")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer currentItem error: \(String(describing: newPlayer.currentItem?.error))")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer timeControlStatus: \(newPlayer.timeControlStatus.rawValue)")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer rate: \(newPlayer.rate)")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer error: \(String(describing: newPlayer.error))")

                // Wait for player to be ready before transitioning to playing state
                logger.info("🎬 VIDEO_PLAYER_VM: ⏳ Waiting for AVPlayer to become ready...")
                try await waitForReadyToPlay(newPlayer, generation: currentGeneration)
                logger.info("🎬 VIDEO_PLAYER_VM: ✅ AVPlayer is now ready!")

                // Final readiness verification
                logger.info("🎬 VIDEO_PLAYER_VM: 🔍 Final readiness verification")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer status: \(newPlayer.status.rawValue) (\(newPlayer.status == .readyToPlay ? "readyToPlay" : "NOT READY"))")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayerItem status: \(newPlayer.currentItem?.status.rawValue ?? -1) (\(newPlayer.currentItem?.status == .readyToPlay ? "readyToPlay" : "NOT READY"))")
                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayerItem isPlaybackLikelyToKeepUp: \(newPlayer.currentItem?.isPlaybackLikelyToKeepUp ?? false)")

                logMemoryUsage(context: "before_state_publish")
                self.state = .playing(player: newPlayer)
                logMemoryUsage(context: "after_state_publish")
        
                // Mark as ready
                self.isPlayerReady = true
        
                // Mark initialization as complete
                self.markInitializationComplete()
        
                logger.info("🎬 VIDEO_PLAYER_VM: ✅ Setup completed, player ready")
                logMemoryUsage(context: "after_ready")

            } catch {
                logger.error("🎬 VIDEO_PLAYER_VM: Setup failed: \(error.localizedDescription)")

                if Task.isCancelled { return }
                guard currentGeneration == self.generation else { return }

                self.state = .error(message: "Failed to load video: \(error.localizedDescription)")
                self.isPlayerReady = false
                logMemoryUsage(context: "setup_error")
            }
        }
    }

    // MARK: - Legacy Methods

    func setSource(asset: AVAsset, quarterTurns: Int) {
        logger.info("🎬 VIDEO_PLAYER_VM: Legacy setSource called")
        setupWithAsset(asset, rotationQuarterTurns: quarterTurns)
    }

    func setRotation(_ quarterTurns: Int) {
        guard let asset = player?.currentItem?.asset else { return }
        setSource(asset: asset, quarterTurns: quarterTurns)
    }

    func teardown() {
        logger.info("🎬 VIDEO_PLAYER_VM: teardown called (Instance count before: \(Self.playerInstanceCount))")
        logMemoryUsage(context: "teardown_start")

        buildTask?.cancel()
        timeoutTask?.cancel()
        logger.info("🎬 VIDEO_PLAYER_VM: Tasks cancelled")

        // Clean up KVO observer
        readinessObserver?.invalidate()
        readinessObserver = nil
        logger.info("🎬 VIDEO_PLAYER_VM: KVO observer invalidated")

        // Clear timeout task reference
        timeoutTask = nil

        if let currentPlayer = player {
            currentPlayer.pause()
            logger.info("🎬 VIDEO_PLAYER_VM: Player paused")
        }
        player = nil
        Self.playerInstanceCount -= 1
        logger.info("🎬 VIDEO_PLAYER_VM: Player set to nil (Instance count now: \(Self.playerInstanceCount))")
        state = .loading
        isPlayerReady = false // Reset isPlayerReady on teardown
        isInitialized = false // Reset isInitialized on teardown

        logMemoryUsage(context: "teardown_end")
        logger.info("🎬 VIDEO_PLAYER_VM: teardown completed")
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

    // MARK: - Player Readiness Waiting

    /// Public method to wait for the player to be ready
    /// This is called from external code to ensure the player is fully set up
    func waitForReady() async throws {
        logger.info("🎬 VIDEO_PLAYER_VM: waitForReady called")
        
        // First wait for initialization to complete
        if !isInitialized {
            logger.info("🎬 VIDEO_PLAYER_VM: ⏳ Waiting for initialization to complete...")
            try await waitForInitialization()
        }
        
        guard let player = player else {
            logger.error("🎬 VIDEO_PLAYER_VM: ❌ No player available")
            throw NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No player available"])
        }
        try await waitForReadyToPlay(player, generation: generation)
    }
    
    /// Wait for the player to be initialized
    private func waitForInitialization() async throws {
        logger.info("🎬 VIDEO_PLAYER_VM: waitForInitialization called")
        
        return try await withCheckedThrowingContinuation { continuation in
            // If already initialized, resume immediately
            if isInitialized {
                logger.info("🎬 VIDEO_PLAYER_VM: ✅ Already initialized")
                continuation.resume()
                return
            }
            
            // Store the continuation for later resumption
            self.initializationContinuation = continuation
            
            // Set up timeout task
            self.initializationTimeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    logger.warning("🎬 VIDEO_PLAYER_VM: ⚠️ Initialization timeout after 10 seconds")
                    
                    // Only resume if we haven't been resumed already
                    if let cont = self.initializationContinuation {
                        self.initializationContinuation = nil
                        cont.resume(throwing: NSError(domain: "VideoPlayer", code: -5, userInfo: [NSLocalizedDescriptionKey: "Player initialization timeout after 10 seconds"]))
                    }
                } catch {
                    logger.info("🎬 VIDEO_PLAYER_VM: Initialization timeout task cancelled")
                }
            }
        }
    }
    
    /// Mark initialization as complete and resume any waiting continuations
    private func markInitializationComplete() {
        logger.info("🎬 VIDEO_PLAYER_VM: markInitializationComplete called")
        
        isInitialized = true
        
        // Cancel any timeout task
        initializationTimeoutTask?.cancel()
        initializationTimeoutTask = nil
        
        // Resume any waiting continuation
        if let continuation = initializationContinuation {
            initializationContinuation = nil
            continuation.resume()
        }
    }

    private func waitForReadyToPlay(_ player: AVPlayer, generation: Int) async throws {
        logger.info("🎬 VIDEO_PLAYER_VM: waitForReadyToPlay called (Generation: \(generation))")
        logMemoryUsage(context: "waitForReady_start")

        guard let playerItem = player.currentItem else {
            logger.error("🎬 VIDEO_PLAYER_VM: ❌ No currentItem available")
            throw NSError(domain: "VideoPlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "No player item available"])
        }

        logger.info("🎬 VIDEO_PLAYER_VM: Setting up KVO observer for AVPlayerItem.status (KVO firings will be logged)")

        // Use simple continuation for async coordination with single resumption guarantee
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false // Atomic flag to prevent double resumption
            var kvoFireCount = 0

            // Set up KVO observer for playerItem status
            self.readinessObserver = playerItem.observe(\.status, options: [.new]) { [weak self] playerItem, change in
                kvoFireCount += 1
                logger.info("🎬 VIDEO_PLAYER_VM: KVO fired #\(kvoFireCount) for status change")
                guard let self = self else {
                    if !hasResumed {
                        hasResumed = true
                        logger.error("🎬 VIDEO_PLAYER_VM: ❌ ViewModel deallocated during readiness wait (KVO #\(kvoFireCount))")
                        continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -6, userInfo: [NSLocalizedDescriptionKey: "ViewModel deallocated"]))
                    }
                    return
                }

                // Prevent double resumption
                guard !hasResumed else {
                    logger.info("🎬 VIDEO_PLAYER_VM: ⚠️ Ignoring duplicate KVO callback #\(kvoFireCount) - already resumed")
                    return
                }

                logger.info("🎬 VIDEO_PLAYER_VM: AVPlayerItem status changed to: \(playerItem.status.rawValue) (\(playerItem.status == .readyToPlay ? "readyToPlay" : playerItem.status == .failed ? "failed" : "unknown")) (KVO #\(kvoFireCount))")

                if playerItem.status == .readyToPlay {
                    logger.info("🎬 VIDEO_PLAYER_VM: ✅ AVPlayerItem is readyToPlay (KVO #\(kvoFireCount))")

                    // Additional verification for robustness
                    let playerReady = player.status == .readyToPlay
                    let playbackLikely = playerItem.isPlaybackLikelyToKeepUp

                    logger.info("🎬 VIDEO_PLAYER_VM: AVPlayer ready: \(playerReady)")
                    logger.info("🎬 VIDEO_PLAYER_VM: Playback likely to keep up: \(playbackLikely)")

                    // Mark as resumed and cancel timeout
                    hasResumed = true
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil

                    // Clean up observer before resuming
                    self.readinessObserver?.invalidate()
                    self.readinessObserver = nil

                    logger.info("🎬 VIDEO_PLAYER_VM: 🎯 KVO path won (Total firings: \(kvoFireCount)) - resuming continuation")
                    logMemoryUsage(context: "kvo_ready")
                    continuation.resume()

                } else if playerItem.status == .failed {
                    logger.error("🎬 VIDEO_PLAYER_VM: ❌ AVPlayerItem failed: \(String(describing: playerItem.error)) (KVO #\(kvoFireCount))")

                    // Mark as resumed and cancel timeout
                    hasResumed = true
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil

                    // Clean up observer before throwing
                    self.readinessObserver?.invalidate()
                    self.readinessObserver = nil

                    logger.info("🎬 VIDEO_PLAYER_VM: 🎯 KVO path won (failure, firings: \(kvoFireCount)) - resuming with error")
                    logMemoryUsage(context: "kvo_failed")
                    continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "AVPlayerItem failed to load"]))
                }
            }

            // Set up timeout task with single resumption protection
            self.timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    logger.warning("🎬 VIDEO_PLAYER_VM: ⚠️ Readiness timeout after 5 seconds (KVO firings: \(kvoFireCount))")

                    // Prevent double resumption
                    guard !hasResumed else {
                        logger.info("🎬 VIDEO_PLAYER_VM: ⚠️ Timeout fired but continuation already resumed by KVO (firings: \(kvoFireCount))")
                        return
                    }

                    // Mark as resumed
                    hasResumed = true

                    // Clean up observer on timeout
                    self.readinessObserver?.invalidate()
                    self.readinessObserver = nil

                    logger.info("🎬 VIDEO_PLAYER_VM: 🎯 Timeout path won - resuming with error (KVO firings: \(kvoFireCount))")
                    logMemoryUsage(context: "timeout")
                    continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -4, userInfo: [NSLocalizedDescriptionKey: "Player readiness timeout after 5 seconds"]))

                } catch {
                    logger.info("🎬 VIDEO_PLAYER_VM: Timeout task cancelled - KVO must have won (firings: \(kvoFireCount))")
                }
            }
        }

        logger.info("🎬 VIDEO_PLAYER_VM: ✅ Player readiness confirmed! (Generation: \(generation))")
        logMemoryUsage(context: "waitForReady_end")
    }

    // MARK: - Playback Control
    
    /// Start playback when view is ready
    public func startPlayback() {
        logger.info("🎬 VIDEO_PLAYER_VM: PlaybackStart: before_async")
        guard let player = player else {
            logger.error("🎬 VIDEO_PLAYER_VM: PlaybackStart: player is nil")
            return
        }
        
        shouldPlay = true
        player.play()
        logger.info("🎬 VIDEO_PLAYER_VM: PlaybackStart: after_async")
        logMemoryUsage(context: "after_startPlayback")
    }

}