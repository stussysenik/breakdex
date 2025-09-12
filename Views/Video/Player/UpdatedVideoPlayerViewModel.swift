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
    private let memoryLogger = CentralizedMemoryLogger.shared
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
        
        // Teardown coordinator and stop monitoring using weak self to prevent retain cycles
        Task { @MainActor [weak self] in
            self?.coordinator.teardown()
            self?.videoHealthMonitor.stopMonitoring()
            self?.logger.info("🎬 VIDEO_PLAYER_VIEWMODEL: Cleanup completed", metadata: nil)
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
    
    /// Wait for the player to be ready
    public func waitForReady() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Check if already ready
            if case .playing = state {
                continuation.resume()
                return
            }
            
            // Set up a publisher to listen for state changes
            let cancellable = $state
                .dropFirst() // Skip the current value
                .sink { newState in
                    if case .playing = newState {
                        continuation.resume()
                    } else if case .error(let message) = newState {
                        continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                    }
                }
            
            // Store the cancellable to keep it alive
            self.cancellables.insert(cancellable)
            
            // Set up a timeout in case the player never becomes ready
            Task {
                try await Task.sleep(nanoseconds: 30 * 1_000_000_000) // 30 seconds
                cancellable.cancel()
                self.cancellables.remove(cancellable)
                continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Player readiness timeout"]))
            }
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