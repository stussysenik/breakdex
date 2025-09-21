
import SwiftUI
import AVKit
import Combine
import OSLog
import Photos

@Observable
@MainActor
public final class UnifiedVideoPlayerViewModel: VideoPlayerViewModelProtocol, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: UnifiedVideoPlayerViewModel, rhs: UnifiedVideoPlayerViewModel) -> Bool {
        lhs.state == rhs.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(state)
    }

    // MARK: - Enums

    /// Defines the operational mode of the player, allowing for context-specific optimizations.
    public enum PlayerMode {
        /// Full-featured mode for general playback.
        case main
        /// Lightweight mode optimized for fast previews, like in the Add Move flow.
        case preview
    }

    /// Represents the current state of the player.
    public enum State: Hashable {
        case idle
        case loading(progress: Double, etaSeconds: TimeInterval?, status: String)
        case ready(player: AVPlayer)
        case playing(player: AVPlayer)
        case paused(player: AVPlayer)
        case error(message: String)
    }

    // MARK: - Properties

    public private(set) var state: State = .idle
    public var shouldPlay: Bool = false
    public private(set) var healthStatus: VideoHealthStatus = .unknown
    
    public var playerItem: AVPlayerItem?

    // MARK: - Private Properties

    private let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()
    private let logger: AppLogger
    private let videoHealthMonitor: VideoHealthMonitor
    private let memoryManager: MemoryManager
    private let memoryLogger = CentralizedMemoryLogger.shared
    private var correlationId: String?
    private let mode: PlayerMode
    private var memoryCheckTimer: Timer?
    private var healthMonitorTask: Task<Void, Never>?

    // MARK: - Public Accessors

    /// Public getter for AVPlayer access (for logging and debugging)
    public var avPlayer: AVPlayer? {
        switch state {
        case .ready(let player), .playing(let player):
            return player
        default:
            return nil
        }
    }

    public var isPlayerReady: Bool {
        switch state {
        case .ready, .playing, .paused:
            return true
        default:
            return false
        }
    }

    public var currentTime: CMTime? {
        switch state {
        case .ready(let player), .playing(let player), .paused(let player):
            return player.currentTime()
        default:
            return nil
        }
    }

    // MARK: - Initialization

    /// Initializes the player with a pre-loaded player and a specific mode.
    public init(player: AVPlayer, mode: PlayerMode = .main, appContainer: AppContainer) {
        self.player = player // Assign to the new stored property
        self.state = .ready(player: self.player) // Use the stored property for the initial state
        self.playerItem = player.currentItem
        self.mode = mode
        self.logger = appContainer.logger
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        self.memoryManager = appContainer.memoryManager
        
        correlationId = memoryLogger.generateCorrelationId(for: "VideoPlayer-\(mode)")
        
        // Start monitoring the health of the provided asset
        if let asset = player.currentItem?.asset {
            videoHealthMonitor.startMonitoring(asset: asset)
        }
        
        healthMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            for await report in self.videoHealthMonitor.getHealthStatusReports() {
                await MainActor.run {
                    self.handleHealthStatusChange(report.status)
                }
            }
        }
        
        if mode == .preview {
            startMemoryChecks()
        }
    }
    

    deinit {
        // The Task in deinit was causing retain cycles - cleanup is now handled in teardown()
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): deinit called", metadata: nil)
    }

    // MARK: - State Management


    // MARK: - Public Methods


    public func startPlayback() {
        if case .ready(let player) = state {
            // Defensive check: Only attempt to play if the item is actually ready
            if let currentItem = player.currentItem, currentItem.status == .readyToPlay {
                player.play()
                self.state = .playing(player: player)
            } else {
                // If not ready, log it. The async loader in NameMoveView should prevent this,
                // but this makes our ViewModel safer.
                logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): startPlayback() called, but item is not ready (status: \(player.currentItem?.status.rawValue ?? -1)). Waiting for readiness.", metadata: nil)
            }
        } else if case .playing(let player) = state {
            player.play()
        }
    }

    public func teardown() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): teardown() called", metadata: ["correlationId": correlationId ?? "unknown"])
        
        // Cancel the health monitor task to break retain cycle
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
        
        player.pause()
        player.replaceCurrentItem(with: nil)
        videoHealthMonitor.stopMonitoring()
        if mode == .preview {
            memoryCheckTimer?.invalidate()
            memoryCheckTimer = nil
            memoryManager.clearCache()
        }
        state = .idle
        shouldPlay = false
        healthStatus = .unknown
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): teardown() completed", metadata: ["correlationId": correlationId ?? "unknown"])
    }
    
    // 💡 SOLUTION: Replace player item and wait for readiness with timeout
    public func replacePlayerItemAndWaitForReady(_ newItem: AVPlayerItem) async throws {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Replacing player item and waiting for readiness", metadata: ["correlationId": correlationId ?? "unknown"])
        
        // Pause current playback
        player.pause()
        
        // Replace the player item
        player.replaceCurrentItem(with: newItem)
        self.playerItem = newItem
        
        // Wait for the new item to become ready with timeout
        let monitor = PlayerItemStatusMonitor(playerItem: newItem)
        try await monitor.awaitReadyAndBuffered(timeout: 10.0) { [weak self] progress in
            guard let self = self else { return }
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): Replace buffer progress: \(Int(progress * 100))%", metadata: ["correlationId": self.correlationId ?? "unknown"])
        }
        
        // Update state to ready
        state = .ready(player: player)
        
        // Restart health monitoring with new asset
        videoHealthMonitor.stopMonitoring()
        videoHealthMonitor.startMonitoring(asset: newItem.asset)
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Player item replaced and ready", metadata: ["correlationId": correlationId ?? "unknown"])
    }

    public func pauseForTrimming() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): pauseForTrimming() called", metadata: nil)

        Task { @MainActor in
            switch state {
            case .playing(let player):
                player.pause()
                videoHealthMonitor.pauseMonitoring()
                if mode == .preview {
                    memoryCheckTimer?.invalidate()
                    memoryCheckTimer = nil
                }
                state = .paused(player: player)
            case .ready(let player):
                player.pause()
                videoHealthMonitor.pauseMonitoring()
                state = .paused(player: player)
            case .paused(_):
                // Already paused, do nothing
                break
            default:
                break
            }
        }
        shouldPlay = false
    }

    public func resumeAfterTrimming() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): resumeAfterTrimming() called", metadata: nil)

        Task { @MainActor in
            if case .playing(let player) = state {
                videoHealthMonitor.resumeMonitoring()
                if mode == .preview {
                    startMemoryChecks()
                }
                if shouldPlay {
                    player.play()
                }
            }
        }
    }
    
    /// Re-primes the player with a given asset if the current state is idle.
    /// This is used to recover from a premature teardown during view transitions.
    public func primeWithAsset(_ asset: AVAsset) async {
        guard case .idle = state else {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): primeWithAsset called, but player is not idle. Skipping.", metadata: ["currentState": "\(state)"])
            return
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Re-priming player from idle state.", metadata: ["correlationId": correlationId ?? "unknown"])

        let newPlayerItem = AVPlayerItem(asset: asset)
        self.player.replaceCurrentItem(with: newPlayerItem)
        self.playerItem = newPlayerItem
        
        // 🚨 FIX: Instead of a simple sleep, we will now explicitly wait for the player item's status
        // to become .readyToPlay, ensuring the video is actually playable.
        
        do {
            // Wait for the item to be ready using the robust PlayerItemStatusMonitor.
            let monitor = PlayerItemStatusMonitor(playerItem: newPlayerItem)
            try await monitor.awaitReadyAndBuffered(timeout: 5.0) { progress in
                self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): Re-priming buffer progress: \(Int(progress * 100))%", metadata: ["correlationId": self.correlationId ?? "unknown"])
            }
            
            // If the above line doesn't throw, the item is ready.
            self.state = .ready(player: self.player)
            videoHealthMonitor.startMonitoring(asset: asset)
            logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player successfully re-primed and item status is ready.", metadata: ["correlationId": correlationId ?? "unknown"])
            
        } catch {
            // If it times out or fails, set an error state.
            self.state = .error(message: "Failed to make video player ready after re-priming.")
            logger.error("❌ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player item failed to become ready. Status: \(newPlayerItem.status.rawValue), Error: \(error.localizedDescription)", metadata: ["correlationId": correlationId ?? "unknown"])
        }
    }
    
    
    // MARK: - Existing Methods
    
    public func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func waitForReady() async throws {
        // Since we're initialized with a ready player, this is mostly a no-op
        // but we can still check if the player is actually ready
        // We always have a player now, so this check is just for consistency
        
        // For simplicity, we'll just return immediately since the player should be ready
        // In a more complex implementation, you might want to verify player status here
        return
    }

    // MARK: - Private Helper Methods

    private func handleHealthStatusChange(_ healthStatus: VideoHealthStatus) {
        self.healthStatus = healthStatus
        memoryLogger.logMemoryEvent(
            event: "Video health status changed to \(healthStatus)",
            correlationId: correlationId,
            component: "VideoPlayer-\(mode)",
            metadata: ["healthStatus": healthStatus.rawValue]
        )

        switch healthStatus {
        case .critical:
            attemptRecovery()
        case .poor:
            if mode == .preview {
                applyOptimizations()
            }
            memoryLogger.logMemoryWarning(
                message: "Video health is poor",
                correlationId: correlationId,
                component: "VideoPlayer-\(mode)",
                metadata: ["healthStatus": healthStatus.rawValue]
            )
        default:
            break
        }
    }

    private func attemptRecovery() {
        memoryLogger.logMemoryEvent(
            event: "Attempting video recovery",
            correlationId: correlationId,
            component: "VideoPlayer-\(mode)"
        )

        guard case .playing(let player) = state, let currentItem = player.currentItem else { return }
        let currentTime = player.currentTime()
        player.pause()

        if mode == .preview {
            memoryManager.clearCache()
        }

        Task {
            let newPlayerItem = AVPlayerItem(asset: currentItem.asset)
            if mode == .preview {
                newPlayerItem.preferredPeakBitRate = 1_000_000
                newPlayerItem.preferredForwardBufferDuration = 0.5
            }
            player.replaceCurrentItem(with: newPlayerItem)
            player.seek(to: currentTime)
            if shouldPlay {
                player.play()
            }
            memoryLogger.logMemoryEvent(
                event: "Video recovery completed",
                correlationId: correlationId,
                component: "VideoPlayer-\(mode)"
            )
        }
    }
    
    private func startMemoryChecks() {
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryAndOptimize()
            }
        }
    }

    private func checkMemoryAndOptimize() {
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 30 * 1024 * 1024

        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory during preview: \(availableMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
            if case .playing(let player) = state {
                player.currentItem?.preferredPeakBitRate = 1_000_000
                player.currentItem?.preferredForwardBufferDuration = 0.5
                player.pause()
            }
            memoryManager.clearCache()
            memoryLogger.logMemoryWarning(
                message: "Low memory during preview: \(availableMemory / (1024 * 1024))MB",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
                metadata: ["availableMemory": availableMemory]
            )
        }
    }
    
    private func applyOptimizations() {
        if case .playing(let player) = state, let currentItem = player.currentItem {
            currentItem.preferredPeakBitRate = 1_500_000
            currentItem.preferredForwardBufferDuration = 0.8
            memoryLogger.logMemoryEvent(
                event: "Applied optimizations to preview player",
                correlationId: correlationId,
                component: "PreviewVideoPlayer"
            )
        }
    }
    
    // MARK: - VideoPlayerViewModelProtocol Implementation
    
    public func loadVideo(from source: VideoSource, quarterTurns: Int) async throws {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): loadVideo() called", metadata: [
            "source": "\(source)",
            "quarterTurns": quarterTurns,
            "correlationId": correlationId ?? "unknown"
        ])
        
        guard case .photos(let identifier) = source else {
            let errorMessage = "Unsupported video source type."
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Unsupported source type - \(source)", metadata: [
                "correlationId": correlationId ?? "unknown",
                "source": "\(source)"
            ])
            self.state = .error(message: errorMessage)
            throw NSError(domain: "UnifiedVideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Loading video from Photos", metadata: [
            "identifier": identifier,
            "correlationId": correlationId ?? "unknown"
        ])
        
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            let errorMessage = "Could not find PHAsset with identifier: \(identifier)."
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): PHAsset not found", metadata: [
                "correlationId": correlationId ?? "unknown",
                "identifier": identifier
            ])
            self.state = .error(message: errorMessage)
            throw NSError(domain: "UnifiedVideoPlayerViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): PHAsset found successfully", metadata: [
            "assetDuration": phAsset.duration,
            "assetMediaType": "\(phAsset.mediaType)",
            "correlationId": correlationId ?? "unknown"
        ])

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Creating LiveVideoLoadingService", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        let loadingService = LiveVideoLoadingService(memoryManager: memoryManager, logger: logger) // As per 2. plan.md, this is the main loading service
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Starting video loading stream", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        let progressStream = loadingService.loadPHAssetWithProgress(phAsset)

        do {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Entering progress stream processing", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            for try await event in progressStream {
                await MainActor.run {
                    switch event {
                    case .progress(let fraction, let status):
                        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Progress update", metadata: [
                            "progress": fraction,
                            "status": status,
                            "correlationId": correlationId ?? "unknown"
                        ])
                        self.state = .loading(progress: fraction, etaSeconds: nil, status: status)
                    case .success(let asset):
                        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Loading successful", metadata: [
                            "assetDuration": CMTimeGetSeconds(asset.duration),
                            "correlationId": correlationId ?? "unknown"
                        ])

                        // Create a new AVPlayerItem from the loaded asset
                        let newPlayerItem = AVPlayerItem(asset: asset)
                        
                        // Diagnostic Check: Log before replacement
                        logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player reference is valid. Replacing item.", metadata: ["correlationId": correlationId ?? "unknown"])

                        // Use the stable `self.player` reference to replace the item
                        self.player.replaceCurrentItem(with: newPlayerItem)
                        self.playerItem = newPlayerItem
                        
                        // Diagnostic Check: Log after replacement and transition to ready state
                        logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player item replaced successfully. Transitioning to ready state.", metadata: ["correlationId": correlationId ?? "unknown"])
                        self.state = .ready(player: self.player)
                        
                        videoHealthMonitor.startMonitoring(asset: asset)
                    }
                }
            }
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Progress stream completed successfully", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
        } catch {
            let errorMessage = "Failed to load video asset: \(error.localizedDescription)"
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Video loading failed", metadata: [
                "error": error.localizedDescription,
                "correlationId": correlationId ?? "unknown"
            ])
            self.state = .error(message: errorMessage)
            throw error
        }
    }
    
    public func setRotation(_ quarterTurns: Int) {
        // Rotation is handled by the asset transform during initialization
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): setRotation(\(quarterTurns)) called", metadata: ["quarterTurns": quarterTurns])
    }
}


