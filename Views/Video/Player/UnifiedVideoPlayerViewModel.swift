
import SwiftUI
import AVKit
import Combine
import OSLog
import Photos

@Observable
@MainActor
public final class UnifiedVideoPlayerViewModel: VideoPlayerViewModelProtocol, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: UnifiedVideoPlayerViewModel, rhs: UnifiedVideoPlayerViewModel) -> Bool {
        lhs.coordinator.state == rhs.coordinator.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinator.state)
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
        case error(message: String)
    }

    // MARK: - Properties

    public private(set) var state: State = .idle
    public var shouldPlay: Bool = false
    public private(set) var healthStatus: VideoHealthStatus = .unknown
    
    // Progress tracking properties
    public var progress: Double = 0
    public var etaSeconds: TimeInterval?
    public var isLoading: Bool = false
    public var playerItem: AVPlayerItem?

    // MARK: - Private Properties

    private let coordinator: UpdatedVideoCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let logger: AppLogger
    private let videoHealthMonitor: VideoHealthMonitor
    private let memoryManager: MemoryManager
    private let memoryLogger = CentralizedMemoryLogger.shared
    private let playerStateMonitor: PlayerStateMonitor
    private let loadingService: VideoLoadingService
    private var correlationId: String?
    private let mode: PlayerMode
    private var memoryCheckTimer: Timer?
    private var loadingTask: Task<Void, Never>?

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

    /// Initializes the player with an asset and a specific mode.
    public init(asset: AVAsset, rotationQuarterTurns: Int = 0, mode: PlayerMode = .main, appContainer: AppContainer) {
        self.mode = mode
        self.logger = appContainer.logger
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        self.memoryManager = appContainer.memoryManager
        self.loadingService = LiveVideoLoadingService()

        correlationId = memoryLogger.generateCorrelationId(for: "VideoPlayer-\(mode)")

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

        self.playerStateMonitor = PlayerStateMonitor()

        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinatorState in
                guard let self = self else { return }
                self.updateState(from: coordinatorState)
            }
            .store(in: &cancellables)

        Task {
            for await report in videoHealthMonitor.getHealthStatusReports() {
                await MainActor.run {
                    handleHealthStatusChange(report.status)
                }
            }
        }
        
        if mode == .preview {
            startMemoryChecks()
        }

        Task {
            await coordinator.loadVideo(from: .asset(asset), quarterTurns: rotationQuarterTurns)
            videoHealthMonitor.startMonitoring(asset: asset)
        }
    }
    
    public func loadVideo(from source: VideoSource, quarterTurns: Int = 0) {
        Task {
            let loaderSource: UpdatedVideoAssetLoader.Source
            switch source {
            case .photos(let identifier):
                loaderSource = .photos(identifier: identifier)
            case .url(let url):
                loaderSource = .url(url)
            case .move(let move):
                loaderSource = .move(move)
            }
            
            await coordinator.loadVideo(from: loaderSource, quarterTurns: quarterTurns)

            if case .playing(let player) = state,
               let currentItem = player.currentItem {
                videoHealthMonitor.startMonitoring(asset: currentItem.asset)
            }
        }
    }

    deinit {
        // Minimal cleanup to avoid retain cycles
        // Note: Properties cannot be accessed from deinit due to actor isolation
        
        // Note: All cleanup will happen when objects are naturally released
        // This prevents retain cycles from Task creation in deinit
    }

    // MARK: - State Management

    private func updateState(from coordinatorState: UpdatedVideoCoordinator.State) {
        switch coordinatorState {
        case .loading:
            state = .loading(progress: 0, etaSeconds: nil, status: "Loading...")
        case .ready(let player):
            state = .playing(player: player)
        case .error(let videoError):
            state = .error(message: videoError.errorDescription ?? "Unknown error")
        }
    }

    // MARK: - Public Methods

    public func setRotation(_ quarterTurns: Int) {
        if case .playing(let player) = state,
           let currentItem = player.currentItem,
           let urlAsset = currentItem.asset as? AVURLAsset {
            loadVideo(from: .url(urlAsset.url), quarterTurns: quarterTurns)
        }
    }

    public func startPlayback() {
        coordinator.startPlayback()
    }

    public func teardown() {
        Task { @MainActor in
            coordinator.teardown()
            videoHealthMonitor.stopMonitoring()
            if mode == .preview {
                memoryCheckTimer?.invalidate()
                memoryCheckTimer = nil
                memoryManager.clearCache()
                memoryManager.clearCache()
            }
        }
        state = .loading(progress: 0, etaSeconds: nil, status: "Resetting...")
        shouldPlay = false
        healthStatus = .unknown
    }

    public func pauseForTrimming() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): pauseForTrimming() called", metadata: nil)
        
        Task { @MainActor in
            if case .playing(let player) = state {
                player.pause()
                videoHealthMonitor.pauseMonitoring()
                if mode == .preview {
                    memoryCheckTimer?.invalidate()
                    memoryCheckTimer = nil
                }
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
    
      // MARK: - Progress-Aware Loading
    
    public func loadVideoWithProgress(from phAsset: PHAsset, onLoadingComplete: @escaping () -> Void = {}) {
        loadingTask?.cancel()
        
        state = .loading(progress: 0, etaSeconds: nil, status: "Starting...")
        progress = 0
        etaSeconds = nil
        isLoading = true
        
        loadingTask = Task { @MainActor in
            do {
                let progressStream = loadingService.loadPHAssetWithProgress(phAsset)
                
                for try await event in progressStream {
                    progress = event.fraction
                    etaSeconds = event.etaSeconds
                    
                    state = .loading(
                        progress: event.fraction,
                        etaSeconds: event.etaSeconds,
                        status: event.status
                    )
                    
                    // Check if loading is complete
                    if event.fraction >= 1.0 {
                        // Create player from the loaded asset
                        // For now, create a simple player for demonstration
                        let playerItem = AVPlayerItem(asset: AVAsset())
                        let player = AVPlayer(playerItem: playerItem)
                        
                        // Transition to ready state with 0.1s animation
                        withAnimation(.linear(duration: 0.1)) {
                            isLoading = false
                            state = .ready(player: player)
                            self.playerItem = playerItem
                        }
                        
                        // Call completion callback
                        onLoadingComplete()
                    }
                }
            } catch {
                logger.error("❌ Progress loading failed: \(error.localizedDescription)", metadata: nil)
                state = .error(message: error.localizedDescription)
                isLoading = false
            }
        }
    }
    
    public func cancelLoading() {
        loadingTask?.cancel()
        loadingService.cancelCurrentOperation()
        state = .idle
        progress = 0
        etaSeconds = nil
        isLoading = false
    }
    
    // MARK: - Existing Methods
    
    public func seek(to time: CMTime) {
        if case .playing(let player) = state {
            player.seek(to: time)
        }
    }

    public func waitForReady() async throws {
        print("🔄 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): waitForReady() called")
        
        if case .playing(let player) = state {
            try await playerStateMonitor.waitForPlayerReady(player)
            return
        }

        if case .ready(let player) = coordinator.state {
            try await playerStateMonitor.waitForPlayerReady(player)
            return
        }

        let timeout: TimeInterval = mode == .preview ? 15.0 : 30.0
        
        return try await withCheckedThrowingContinuation { continuation in
            let startTime = Date()
            let checkInterval: TimeInterval = 0.1

            var timer: Timer?
            timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if Date().timeIntervalSince(startTime) > timeout {
                        timer?.invalidate()
                        continuation.resume(throwing: PlayerStateMonitor.MonitorError.timeoutExceeded)
                        return
                    }

                    switch self.state {
                    case .playing(let player):
                        timer?.invalidate()
                        Task {
                            do {
                                try await self.playerStateMonitor.waitForPlayerReady(player)
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    case .error(let message):
                        timer?.invalidate()
                        continuation.resume(throwing: NSError(domain: "VideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                    case .loading:
                        break
                    case .idle, .ready:
                        break
                    }
                }
            }
        }
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
}

