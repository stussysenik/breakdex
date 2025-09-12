import SwiftUI
import AVKit
import Combine
import OSLog

@MainActor
public final class PreviewOptimizedVideoPlayerViewModel: ObservableObject, VideoPlayerViewModelProtocol, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: PreviewOptimizedVideoPlayerViewModel, rhs: PreviewOptimizedVideoPlayerViewModel) -> Bool {
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
    
    private let coordinator: PreviewOptimizedVideoCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let logger: AppLogger
    private let videoHealthMonitor: VideoHealthMonitor
    private let memoryLogger = CentralizedMemoryLogger.shared
    private let memoryManager: MemoryManager
    private var correlationId: String?
    private var memoryCheckTimer: Timer?
    
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
        correlationId = memoryLogger.generateCorrelationId(for: "PreviewVideoPlayer")
        
        // Create the coordinator with preview-optimized dependencies
        self.coordinator = PreviewOptimizedVideoCoordinator(
            assetLoader: PreviewOptimizedVideoAssetLoader(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            playerInitializer: PreviewOptimizedVideoPlayerInitializer(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            readinessMonitor: PreviewOptimizedReadinessMonitor(),
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
        
        // Start periodic memory checks for preview
        startMemoryChecks()
        
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
        correlationId = memoryLogger.generateCorrelationId(for: "PreviewVideoPlayer")
        
        // Create the coordinator with preview-optimized dependencies
        self.coordinator = PreviewOptimizedVideoCoordinator(
            assetLoader: PreviewOptimizedVideoAssetLoader(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            playerInitializer: PreviewOptimizedVideoPlayerInitializer(
                memoryManager: appContainer.memoryManager,
                logger: appContainer.logger
            ),
            readinessMonitor: PreviewOptimizedReadinessMonitor(),
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
        
        // Start periodic memory checks for preview
        startMemoryChecks()
    }
    
    deinit {
        Task { @MainActor in
            coordinator.teardown()
            videoHealthMonitor.stopMonitoring()
            memoryCheckTimer?.invalidate()
            memoryCheckTimer = nil
        }
    }
    
    // MARK: - State Management
    
    private func updateState(from coordinatorState: PreviewOptimizedVideoCoordinator.State) {
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
    
    /// Teardown the player with aggressive cleanup for preview
    public func teardown() {
        Task { @MainActor in
            coordinator.teardown()
            videoHealthMonitor.stopMonitoring()
            memoryCheckTimer?.invalidate()
            memoryCheckTimer = nil
            
            // Aggressive memory cleanup for preview
            memoryManager.clearCache()
            memoryManager.clearCache()
        }
        state = .loading
        shouldPlay = false
        healthStatus = VideoHealthStatus.unknown
    }
    
    /// Wait for the player to be ready with shorter timeout for preview
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
            
            // Set up a timeout with shorter duration for preview
            Task {
                try await Task.sleep(nanoseconds: 15 * 1_000_000_000) // 15 seconds (shorter for preview)
                cancellable.cancel()
                self.cancellables.remove(cancellable)
                continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Preview player readiness timeout"]))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startMemoryChecks() {
        // Set up periodic memory checks for preview with shorter interval
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryAndOptimize()
            }
        }
    }
    
    private func checkMemoryAndOptimize() {
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 30 * 1024 * 1024 // 30MB threshold for preview
        
        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory during preview: \(availableMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
            
            // If player is ready, apply more aggressive optimizations
            if case .playing(let player) = state {
                // Reduce quality further
                player.currentItem?.preferredPeakBitRate = 1_000_000 // Reduce to 1 Mbps
                player.currentItem?.preferredForwardBufferDuration = 0.5 // Reduce buffer further
                
                // Pause playback to free up memory
                player.pause()
                
                logger.info("⚠️ Applied aggressive memory optimizations for preview", metadata: ["correlationId": correlationId ?? "unknown"])
            }
            
            // Clear cache
            memoryManager.clearCache()
            
            // Log memory event
            memoryLogger.logMemoryWarning(
                message: "Low memory during preview: \(availableMemory / (1024 * 1024))MB",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
                metadata: ["availableMemory": availableMemory]
            )
        }
    }
    
    private func handleHealthStatusChange(_ healthStatus: VideoHealthStatus) {
        self.healthStatus = healthStatus
        
        // Log health status change
        memoryLogger.logMemoryEvent(
            event: "Preview video health status changed to \(healthStatus)",
            correlationId: correlationId,
            component: "PreviewVideoPlayer",
            metadata: ["healthStatus": healthStatus.rawValue]
        )
        
        // Implement more aggressive automatic recovery actions based on health reports for preview
        switch healthStatus {
        case .critical:
            // For critical health status, attempt immediate recovery
            attemptRecovery()
        case .poor:
            // For poor health status, apply optimizations immediately
            applyOptimizations()
            
            memoryLogger.logMemoryWarning(
                message: "Preview video health is poor",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
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
    
    private func applyOptimizations() {
        // Apply optimizations without full recovery
        if case .playing(let player) = state,
           let currentItem = player.currentItem {
            // Reduce quality
            currentItem.preferredPeakBitRate = 1_500_000 // 1.5 Mbps
            currentItem.preferredForwardBufferDuration = 0.8 // Smaller buffer
            
            memoryLogger.logMemoryEvent(
                event: "Applied optimizations to preview player",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
                metadata: nil
            )
        }
    }
    
    private func attemptRecovery() {
        memoryLogger.logMemoryEvent(
            event: "Attempting preview video recovery",
            correlationId: correlationId,
            component: "PreviewVideoPlayer",
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
        
        // Clear memory aggressively
        memoryLogger.logCacheClearing(
            correlationId: correlationId,
            component: "PreviewVideoPlayer",
            details: "Clearing cache as part of preview recovery"
        )
        memoryManager.clearCache()
        memoryManager.clearCache()
        
        // Reinitialize the player with the same asset but with preview optimizations
        Task {
            // Create a new player item with the same asset
            let newPlayerItem = AVPlayerItem(asset: currentItem.asset)
            
            // Apply preview optimizations
            newPlayerItem.preferredPeakBitRate = 1_000_000 // 1 Mbps for recovery
            newPlayerItem.preferredForwardBufferDuration = 0.5 // Smaller buffer for recovery
            
            // Replace the current item
            player.replaceCurrentItem(with: newPlayerItem)
            
            // Seek to the previous time
            player.seek(to: currentTime)
            
            // Resume playback if it was playing before
            if shouldPlay {
                player.play()
            }
            
            memoryLogger.logMemoryEvent(
                event: "Preview video recovery completed",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
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