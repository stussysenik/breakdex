import SwiftUI
import AVKit
import Combine
import OSLog

@MainActor
public final class UpdatedVideoPlayerViewModel: ObservableObject, VideoPlayerViewModelProtocol, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: UpdatedVideoPlayerViewModel, rhs: UpdatedVideoPlayerViewModel) -> Bool {
        lhs.coordinator.state == rhs.coordinator.state
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinator.state)
    }
    
    // MARK: - Public Properties
    
    public enum State: Hashable {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }
    
    @Published public private(set) var state: State = .loading
    @Published public private(set) var shouldPlay: Bool = false
    @Published public private(set) var healthStatus: VideoHealthStatus = .unknown
    
    // MARK: - Private Properties
    
    private let coordinator: UpdatedVideoCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let logger: AppLogger
    private let videoHealthMonitor: VideoHealthMonitor
    private let memoryManager: MemoryManager
    private let memoryLogger = CentralizedMemoryLogger.shared
    private let playerStateMonitor: PlayerStateMonitor
    private var correlationId: String?
    
    // MARK: - Public Accessors
    
    /// Public getter for AVPlayer access (for logging and debugging)
    public var avPlayer: AVPlayer? {
        if case .ready(let player) = coordinator.state {
            return player
        }
        return nil
    }
    
    public var isPlayerReady: Bool {
        if case .ready = coordinator.state {
            return true
        }
        return false
    }
    
    // MARK: - Initialization
    
    /// Initialize with asset and rotation for immediate use
    internal init(asset: AVAsset, rotationQuarterTurns: Int = 0, appContainer: AppContainer) {
        self.logger = appContainer.logger
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        self.memoryManager = appContainer.memoryManager
        
        // Generate correlation ID for this player instance
        correlationId = memoryLogger.generateCorrelationId(for: "VideoPlayer")
        
        // Create the coordinator with dependencies from the container
        self.coordinator = UpdatedVideoCoordinator(
            assetLoader: UpdatedVideoAssetLoader(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            playerInitializer: PlayerInitializer(),
            readinessMonitor: ReadinessMonitor(),
            memoryManager: appContainer.memoryManager,
            logger: appContainer.logger
        )
        
        // Initialize player state monitor
        self.playerStateMonitor = PlayerStateMonitor()
        
        // Subscribe to coordinator state changes
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinatorState in
                guard let self = self else { return }
                self.updateState(from: coordinatorState)
            }
            .store(in: &cancellables)
        
        // Subscribe to video health status reports
        Task {
            for await report in videoHealthMonitor.getHealthStatusReports() {
                await MainActor.run {
                    handleHealthStatusChange(report.status)
                }
            }
        }
        
        // Load the video using the already loaded asset
        Task {
            // Use the passed asset directly instead of reloading it
            await coordinator.loadVideo(from: .asset(asset), quarterTurns: rotationQuarterTurns)
            
            // Start health monitoring for the loaded asset
            videoHealthMonitor.startMonitoring(asset: asset)
        }
    }
    
    /// Legacy initializer for backward compatibility
    internal init(appContainer: AppContainer) {
        self.logger = appContainer.logger
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        self.memoryManager = appContainer.memoryManager
        
        // Generate correlation ID for this player instance
        correlationId = memoryLogger.generateCorrelationId(for: "VideoPlayer")
        
        // Create the coordinator with dependencies from the container
        self.coordinator = UpdatedVideoCoordinator(
            assetLoader: UpdatedVideoAssetLoader(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            playerInitializer: PlayerInitializer(),
            readinessMonitor: ReadinessMonitor(),
            memoryManager: appContainer.memoryManager,
            logger: appContainer.logger
        )
        
        // Initialize player state monitor
        self.playerStateMonitor = PlayerStateMonitor()
        
        // Subscribe to coordinator state changes
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinatorState in
                self?.updateState(from: coordinatorState)
            }
            .store(in: &cancellables)
        
        // Subscribe to video health status reports
        Task {
            for await report in videoHealthMonitor.getHealthStatusReports() {
                await MainActor.run {
                    handleHealthStatusChange(report.status)
                }
            }
        }
    }
    
    deinit {
        logger.info("🎬 VIDEO_PLAYER_VIEWMODEL: Deinitializing", metadata: nil)
        
        // Cancel all subscriptions synchronously to prevent retain cycles
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Schedule async cleanup for main actor methods
        Task { @MainActor in
            playerStateMonitor.stop()
            coordinator.teardown()
            videoHealthMonitor.stopMonitoring()
            logger.info("🎬 VIDEO_PLAYER_VIEWMODEL: Cleanup completed", metadata: nil)
        }
    }
    
    // MARK: - State Management
    
    private func updateState(from coordinatorState: UpdatedVideoCoordinator.State) {
        switch coordinatorState {
        case .loading:
            state = .loading
        case .ready(let player):
            state = .playing(player: player)
        case .error(let videoError):
            state = .error(message: videoError.errorDescription ?? "Unknown error")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load video from a Photos identifier
    public func loadVideo(fromPhotosIdentifier identifier: String, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .photos(identifier: identifier), quarterTurns: quarterTurns)
            
            // Start health monitoring for the loaded asset
            if case .playing(let player) = state,
               let currentItem = player.currentItem {
                videoHealthMonitor.startMonitoring(asset: currentItem.asset)
            }
        }
    }
    
    /// Load video from a URL
    public func loadVideo(fromURL url: URL, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .url(url), quarterTurns: quarterTurns)
            
            // Start health monitoring for the loaded asset
            if case .playing(let player) = state,
               let currentItem = player.currentItem {
                videoHealthMonitor.startMonitoring(asset: currentItem.asset)
            }
        }
    }
    
    /// Load video from a Move object
    public func loadVideo(fromMove move: Move, quarterTurns: Int = 0) {
        Task {
            await coordinator.loadVideo(from: .move(move), quarterTurns: quarterTurns)
            
            // Start health monitoring for the loaded asset
            if case .playing(let player) = state,
               let currentItem = player.currentItem {
                videoHealthMonitor.startMonitoring(asset: currentItem.asset)
            }
        }
    }
    
    /// Set video rotation
    public func setRotation(_ quarterTurns: Int) {
        // We need to reload the video with the new rotation
        // For now, this is a simplified implementation
        // In a real implementation, we would preserve the current asset and just change the rotation
        if case .playing(let player) = state,
           let currentItem = player.currentItem,
           let urlAsset = currentItem.asset as? AVURLAsset {
            loadVideo(fromURL: urlAsset.url, quarterTurns: quarterTurns)
        }
    }
    
    /// Start playback
    public func startPlayback() {
        coordinator.startPlayback()
    }
    
    /// Teardown the player
    public func teardown() {
        Task { @MainActor in
            coordinator.teardown()
            videoHealthMonitor.stopMonitoring()
        }
        state = .loading
        shouldPlay = false
        healthStatus = VideoHealthStatus.unknown
    }
    
    /// Pause the player for trimming (preserves resources for instant resume)
    public func pauseForTrimming() {
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: pauseForTrimming() called", metadata: nil)
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Current state: \(String(describing: state))", metadata: nil)
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Thread: \(Thread.isMainThread ? "Main" : "Background")", metadata: nil)
        
        Task { @MainActor in
            if case .playing(let player) = state {
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Pausing AVPlayer for trimming", metadata: nil)
                let currentTime = player.currentTime()
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Current playback time: \(currentTime.seconds)s", metadata: nil)
                
                player.pause()
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ AVPlayer paused successfully", metadata: nil)
                
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Pausing video health monitoring", metadata: nil)
                videoHealthMonitor.pauseMonitoring()
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ Video health monitoring paused", metadata: nil)
                
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: 📊 Memory after pause: \(memoryManager.getAvailableMemory() / (1024*1024)) MB available", metadata: nil)
            } else {
                logger.warning("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ⚠️ Player not in playing state, cannot pause for trimming", metadata: nil)
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: State was: \(String(describing: state))", metadata: nil)
            }
        }
        
        shouldPlay = false
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ pauseForTrimming() completed", metadata: nil)
    }
    
    /// Resume the player after trimming (instant playback)
    public func resumeAfterTrimming() {
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: resumeAfterTrimming() called", metadata: nil)
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Current state: \(String(describing: state))", metadata: nil)
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: shouldPlay: \(shouldPlay)", metadata: nil)
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Thread: \(Thread.isMainThread ? "Main" : "Background")", metadata: nil)
        
        Task { @MainActor in
            if case .playing(let player) = state {
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Resuming video health monitoring", metadata: nil)
                videoHealthMonitor.resumeMonitoring()
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ Video health monitoring resumed", metadata: nil)
                
                if shouldPlay {
                    logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: Starting playback after trimming", metadata: nil)
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    player.play()
                    logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ AVPlayer play() called", metadata: nil)
                    
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let resumeTime = (endTime - startTime) * 1000
                    logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ⚡ Resume operation completed in \(String(format: "%.2f", resumeTime))ms", metadata: nil)
                    
                    logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: 📊 Memory after resume: \(memoryManager.getAvailableMemory() / (1024*1024)) MB available", metadata: nil)
                } else {
                    logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: shouldPlay=false, not starting playback", metadata: nil)
                }
            } else {
                logger.warning("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ⚠️ Player not in playing state, cannot resume after trimming", metadata: nil)
                logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: State was: \(String(describing: state))", metadata: nil)
            }
        }
        
        logger.info("🎬 UPDATED_VIDEO_PLAYER_VIEWMODEL: ✅ resumeAfterTrimming() completed", metadata: nil)
    }
    
    /// Wait for the player to be ready with atomic continuation management
    public func waitForReady() async throws {
        print("🔄 UPDATED_VIDEO_PLAYER_VIEWMODEL: waitForReady() called")
        print("📊 UPDATED_VIDEO_PLAYER_VIEWMODEL: Current state: \(String(describing: state))")
        
        // Check if already ready
        if case .playing(let player) = state {
            print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Player in playing state, monitoring readiness")
            try await playerStateMonitor.waitForPlayerReady(player)
            print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Player readiness confirmed")
            return
        }
        
        // Also check if coordinator is ready (state update might be in progress)
        if case .ready(let player) = coordinator.state {
            print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Coordinator in ready state, monitoring readiness")
            try await playerStateMonitor.waitForPlayerReady(player)
            print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Coordinator readiness confirmed")
            return
        }
        
        print("⏳ UPDATED_VIDEO_PLAYER_VIEWMODEL: Player not in playing state, setting up state monitoring")
        
        // Set up monitoring for state changes
        return try await withCheckedThrowingContinuation { continuation in
            print("📡 UPDATED_VIDEO_PLAYER_VIEWMODEL: Setting up state change monitoring")
            let cancellable = $state
                .dropFirst() // Skip the current value
                .sink { [weak self] newState in
                    print("📊 UPDATED_VIDEO_PLAYER_VIEWMODEL: State changed to: \(String(describing: newState))")
                    self?.handleStateChange(newState, continuation: continuation)
                }
            
            // Store the cancellable to keep it alive
            self.cancellables.insert(cancellable)
            print("📡 UPDATED_VIDEO_PLAYER_VIEWMODEL: State monitoring setup complete")
            
            // Set up timeout
            Task { @MainActor [weak self] in
                do {
                    print("⏰ UPDATED_VIDEO_PLAYER_VIEWMODEL: Starting 30s timeout timer")
                    try await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds
                    print("⏰ UPDATED_VIDEO_PLAYER_VIEWMODEL: Timeout reached")
                    
                    cancellable.cancel()
                    self?.cancellables.remove(cancellable)
                    
                    // Only resume if still pending (atomic check)
                    if let monitor = self?.playerStateMonitor,
                       monitor.isPending {
                        print("❌ UPDATED_VIDEO_PLAYER_VIEWMODEL: Timeout - player never became ready")
                        continuation.resume(throwing: PlayerStateMonitor.MonitorError.timeoutExceeded)
                    } else {
                        print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Timeout avoided - continuation already completed")
                    }
                } catch {
                    // Task was cancelled, monitoring must have completed
                    print("✅ UPDATED_VIDEO_PLAYER_VIEWMODEL: Timeout task cancelled - monitoring completed")
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func handleStateChange(
        _ newState: State,
        continuation: CheckedContinuation<Void, Error>
    ) {
        switch newState {
        case .playing(let player):
            print("🎮 UPDATED_VIDEO_PLAYER_VIEWMODEL: State changed to playing, monitoring player readiness")
            // Player is ready, monitor its actual readiness
            Task { @MainActor [weak self] in
                do {
                    print("🎮 UPDATED_VIDEO_PLAYER_VIEWMODEL: Starting player readiness monitoring")
                    try await self?.playerStateMonitor.waitForPlayerReady(player)
                    print("🎉 UPDATED_VIDEO_PLAYER_VIEWMODEL: Player ready, resuming waitForReady continuation")
                    continuation.resume()
                } catch {
                    print("❌ UPDATED_VIDEO_PLAYER_VIEWMODEL: Player readiness failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
        case .error(let message):
            print("❌ UPDATED_VIDEO_PLAYER_VIEWMODEL: State changed to error: \(message), resuming with error")
            continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            
        case .loading:
            print("⏳ UPDATED_VIDEO_PLAYER_VIEWMODEL: State changed to loading, continuing to wait")
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func handleHealthStatusChange(_ healthStatus: VideoHealthStatus) {
        self.healthStatus = healthStatus
        
        // Log health status change
        memoryLogger.logMemoryEvent(
            event: "Video health status changed to \(healthStatus)",
            correlationId: correlationId,
            component: "VideoPlayer",
            metadata: ["healthStatus": healthStatus.rawValue]
        )
        
        // Implement automatic recovery actions based on health reports
        switch healthStatus {
        case .critical:
            // For critical health status, attempt recovery
            attemptRecovery()
        case .poor:
            // For poor health status, log a warning but continue playing
            memoryLogger.logMemoryWarning(
                message: "Video health is poor",
                correlationId: correlationId,
                component: "VideoPlayer",
                metadata: ["healthStatus": healthStatus.rawValue]
            )
        case .good, .excellent:
            // Good or excellent health, no action needed
            break
        case .unknown:
            // Unknown health status, no action needed
            break
        }
    }
    
    private func attemptRecovery() {
        memoryLogger.logMemoryEvent(
            event: "Attempting video recovery",
            correlationId: correlationId,
            component: "VideoPlayer",
            metadata: nil
        )
        
        // Get current player state
        guard case .playing(let player) = state,
              let currentItem = player.currentItem else {
            return
        }
        
        // Get current playback time
        let currentTime = player.currentTime()
        
        // Pause playback
        player.pause()
        
        // Clear memory
        memoryLogger.logCacheClearing(
            correlationId: correlationId,
            component: "VideoPlayer",
            details: "Clearing cache as part of recovery"
        )
        
        // Reinitialize the player with the same asset
        Task {
            // Create a new player item with the same asset
            let newPlayerItem = AVPlayerItem(asset: currentItem.asset)
            
            // Replace the current item
            player.replaceCurrentItem(with: newPlayerItem)
            
            // Seek to the previous time
            player.seek(to: currentTime)
            
            // Resume playback if it was playing before
            if shouldPlay {
                player.play()
            }
            
            memoryLogger.logMemoryEvent(
                event: "Video recovery completed",
                correlationId: correlationId,
                component: "VideoPlayer",
                metadata: nil
            )
        }
    }
    
    // MARK: - Legacy Methods
    
    /// Legacy method for backward compatibility
    func setSource(asset: AVAsset, quarterTurns: Int) {
        // Use the passed asset directly instead of reloading it
        Task {
            await coordinator.loadVideo(from: .asset(asset), quarterTurns: quarterTurns)
            
            // Start health monitoring for the loaded asset
            videoHealthMonitor.startMonitoring(asset: asset)
        }
    }
}