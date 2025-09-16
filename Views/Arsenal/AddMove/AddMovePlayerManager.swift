import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - AddMove Player Manager
// Single Responsibility: Manage VideoPlayerViewModel lifecycle and caching
@MainActor
public class AddMovePlayerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    @Published public private(set) var isPlayerReady = false
    @Published public private(set) var playerState: PlayerState = .idle
    
    // MARK: - Services
    private let videoPlayerCacheManager: VideoPlayerCacheManagerProtocol
    private let appContainer: AppContainer
    private let logger: AppLogger
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    private var playerSetupTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(
        videoPlayerCacheManager: VideoPlayerCacheManagerProtocol,
        appContainer: AppContainer,
        logger: AppLogger
    ) {
        self.videoPlayerCacheManager = videoPlayerCacheManager
        self.appContainer = appContainer
        self.logger = logger
        
        setupPlayerStateMonitoring()
    }
    
    // MARK: - Public API
    
    /// Create or retrieve cached VideoPlayerViewModel for given asset and rotation
    public func getOrCreatePlayerViewModel(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) async throws -> any VideoPlayerViewModelProtocol {
        logger.info("🎬 PLAYER_MANAGER: Getting player for rotation: \(rotationQuarterTurns)°", metadata: nil)
        
        // Check cache first
        if let cachedViewModel = videoPlayerCacheManager.getCachedPlayerViewModel(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotation: rotationQuarterTurns
        ) {
            logger.info("🎬 PLAYER_MANAGER: 🚀 Cache HIT! Using cached player", metadata: nil)
            
            await MainActor.run {
                self.currentPlayerViewModel = cachedViewModel
                self.setupPlayerMonitoring(cachedViewModel)
            }
            
            return cachedViewModel
        }
        
        // Create new player
        logger.info("🎬 PLAYER_MANAGER: Creating new player instance", metadata: nil)
        let newPlayer = UnifiedVideoPlayerViewModel(
            asset: asset,
            rotationQuarterTurns: rotationQuarterTurns,
            mode: .preview,
            appContainer: appContainer
        )
        
        // Cache the new player
        videoPlayerCacheManager.cacheVideoPlayerViewModel(
            newPlayer,
            for: asset,
            photosIdentifier: photosIdentifier,
            rotation: rotationQuarterTurns
        )
        
        await MainActor.run {
            self.currentPlayerViewModel = newPlayer
            self.setupPlayerMonitoring(newPlayer)
        }
        
        // Wait for player to be ready
        try await newPlayer.waitForReady()
        
        logger.info("🎬 PLAYER_MANAGER: ✅ Player is ready", metadata: nil)
        return newPlayer
    }
    
    /// Setup player for immediate playback
    public func setupPlayerForPlayback(
        asset: AVAsset,
        photosIdentifier: String?,
        rotationQuarterTurns: Int
    ) async throws -> any VideoPlayerViewModelProtocol {
        logger.info("🎬 PLAYER_MANAGER: Setting up player for immediate playback", metadata: nil)
        
        let playerViewModel = try await getOrCreatePlayerViewModel(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
        
        // Start playback
        playerViewModel.startPlayback()
        
        logger.info("🎬 PLAYER_MANAGER: 🎯 Player setup complete, starting playback", metadata: nil)
        return playerViewModel
    }
    
    /// Prepare player for trimming (pause current playback)
    public func preparePlayerForTrimming() {
        logger.info("🎬 PLAYER_MANAGER: Preparing player for trimming", metadata: nil)
        
        guard let playerViewModel = currentPlayerViewModel else {
            logger.warning("🎬 PLAYER_MANAGER: No active player to prepare for trimming", metadata: nil)
            return
        }
        
        playerViewModel.pauseForTrimming()
        logger.info("🎬 PLAYER_MANAGER: Player paused for trimming", metadata: nil)
    }
    
    /// Resume player after trimming
    public func resumePlayerAfterTrimming() {
        logger.info("🎬 PLAYER_MANAGER: Resuming player after trimming", metadata: nil)
        
        guard let playerViewModel = currentPlayerViewModel else {
            logger.warning("🎬 PLAYER_MANAGER: No active player to resume", metadata: nil)
            return
        }
        
        playerViewModel.resumeAfterTrimming()
        logger.info("🎬 PLAYER_MANAGER: Player resumed after trimming", metadata: nil)
    }
    
    /// Update player rotation
    public func updatePlayerRotation(_ quarterTurns: Int) {
        logger.info("🎬 PLAYER_MANAGER: Updating player rotation to: \(quarterTurns)°", metadata: nil)
        
        guard let playerViewModel = currentPlayerViewModel else {
            logger.warning("🎬 PLAYER_MANAGER: No active player to update rotation", metadata: nil)
            return
        }
        
        playerViewModel.setRotation(quarterTurns)
        logger.info("🎬 PLAYER_MANAGER: Player rotation updated", metadata: nil)
    }
    
    /// Get current player state for persistence
    public func getCurrentPlayerState() -> PlayerStateSnapshot? {
        guard let playerViewModel = currentPlayerViewModel else {
            return nil
        }
        
        return PlayerStateSnapshot(
            asset: playerViewModel.avPlayer?.currentItem?.asset,
            rotationQuarterTurns: 0, // Would need to extract from player
            isPlaying: playerViewModel.shouldPlay,
            currentTime: playerViewModel.avPlayer?.currentTime()
        )
    }
    
    /// Clear current player and reset state
    public func clearCurrentPlayer() {
        logger.info("🎬 PLAYER_MANAGER: Clearing current player", metadata: nil)
        
        if let playerViewModel = currentPlayerViewModel {
            playerViewModel.teardown()
        }
        
        Task {
            await MainActor.run {
                self.currentPlayerViewModel = nil
                self.isPlayerReady = false
                self.playerState = .idle
                self.cancellables.removeAll()
            }
        }
        
        playerSetupTask?.cancel()
        playerSetupTask = nil
    }
    
    /// Reset manager state
    public func reset() {
        logger.info("🎬 PLAYER_MANAGER: Resetting manager state", metadata: nil)
        
        clearCurrentPlayer()
        videoPlayerCacheManager.clearCache()
    }
    
    // MARK: - Private Methods
    
    private func setupPlayerStateMonitoring() {
        // Monitor player state changes
        $currentPlayerViewModel
            .compactMap { $0 }
            .sink { [weak self] playerViewModel in
                self?.setupPlayerMonitoring(playerViewModel)
            }
            .store(in: &cancellables)
    }
    
    private func setupPlayerMonitoring(_ playerViewModel: any VideoPlayerViewModelProtocol) {
        // Cancel previous monitoring
        cancellables.removeAll()
        
        // Set initial state
        handlePlayerHealthStatus(playerViewModel.healthStatus)
        handlePlaybackStateChange(playerViewModel.shouldPlay)
        
        // Note: Since the protocol doesn't have publisher properties,
        // we can't monitor changes dynamically without specific implementation
    }
    
    private func handlePlayerHealthStatus(_ status: VideoHealthStatus) {
        switch status {
        case .excellent, .good:
            isPlayerReady = true
            playerState = .ready
        case .unknown, .poor, .critical:
            isPlayerReady = false
            playerState = .loading
        }
    }
    
    private func handlePlaybackStateChange(_ shouldPlay: Bool) {
        if shouldPlay {
            playerState = .playing
        } else {
            playerState = .paused
        }
    }
}

// MARK: - Player States
public enum PlayerState {
    case idle
    case loading
    case ready
    case playing
    case paused
    case error(String)
    case unknown
}

// MARK: - Player State Snapshot
public struct PlayerStateSnapshot {
    public let asset: AVAsset?
    public let rotationQuarterTurns: Int
    public let isPlaying: Bool
    public let currentTime: CMTime?
    
    public init(
        asset: AVAsset?,
        rotationQuarterTurns: Int,
        isPlaying: Bool,
        currentTime: CMTime?
    ) {
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.isPlaying = isPlaying
        self.currentTime = currentTime
    }
}

// MARK: - Player Manager Protocol
@MainActor
public protocol AddMovePlayerManagerProtocol: ObservableObject {
    var currentPlayerViewModel: (any VideoPlayerViewModelProtocol)? { get }
    var isPlayerReady: Bool { get }
    var playerState: PlayerState { get }
    
    func getOrCreatePlayerViewModel(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int) async throws -> any VideoPlayerViewModelProtocol
    func setupPlayerForPlayback(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int) async throws -> any VideoPlayerViewModelProtocol
    func preparePlayerForTrimming()
    func resumePlayerAfterTrimming()
    func updatePlayerRotation(_ quarterTurns: Int)
    func getCurrentPlayerState() -> PlayerStateSnapshot?
    func clearCurrentPlayer()
    func reset()
}

// MARK: - Conformance
extension AddMovePlayerManager: AddMovePlayerManagerProtocol {}