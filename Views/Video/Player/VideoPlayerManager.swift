import AVFoundation
import Combine
import OSLog

@MainActor
public class VideoPlayerManager: ObservableObject {
    // MARK: - Public Properties
    
    /// The single, shared AVPlayer instance that persists across view transitions
    public let player = AVPlayer()
    
    /// Published state to track player readiness
    @Published public private(set) var isPlayerReady: Bool = false
    
    /// Published state for player status
    @Published public private(set) var playerStatus: AVPlayer.Status = .unknown
    
    /// Current asset being loaded
    @Published public private(set) var currentAsset: AVURLAsset?
    
    // MARK: - Private Properties
    
    /// Cache to hold prepared video assets to prevent redundant data fetching
    private let assetCache = NSCache<NSURL, AVURLAsset>()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Logger for debugging
    private let logger = AppContainer.shared.logger
    
    // MARK: - Initialization
    
    public init() {
        setupPlayerObservation()
        setupAssetCache()
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Initialized", metadata: nil)
    }
    
    deinit {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Deinitializing", metadata: nil)
        Task { @MainActor in
            teardownPlayer()
        }
    }
    
    // MARK: - Public Methods
    
    /// Prepare the player for a specific video URL
    /// This method ensures the player is ready and cached for instant access
    public func preparePlayer(for url: URL) {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Preparing player for URL: \(url.lastPathComponent)", metadata: nil)
        
        let asset: AVURLAsset
        
        // Check cache for the asset first
        if let cachedAsset = assetCache.object(forKey: url as NSURL) {
            logger.info("🎬 VIDEO_PLAYER_MANAGER: Cache HIT! Using cached asset", metadata: nil)
            asset = cachedAsset
        } else {
            logger.info("🎬 VIDEO_PLAYER_MANAGER: Cache MISS! Creating new asset", metadata: nil)
            // If not cached, create a new asset and cache it
            asset = AVURLAsset(url: url)
            assetCache.setObject(asset, forKey: url as NSURL)
        }
        
        // Update current asset
        currentAsset = asset
        
        // Create the player item and replace the current one
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)
        
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Player item replaced with new asset", metadata: nil)
    }
    
    /// Prepare the player for an existing AVAsset
    public func preparePlayer(for asset: AVAsset) {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Preparing player for existing asset", metadata: nil)
        
        guard let urlAsset = asset as? AVURLAsset else {
            logger.error("🎬 VIDEO_PLAYER_MANAGER: Asset is not a URL asset, cannot prepare", metadata: nil)
            return
        }
        
        preparePlayer(for: urlAsset.url)
    }
    
    /// Start playback
    public func startPlayback() {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Starting playback", metadata: nil)
        
        if isPlayerReady {
            player.play()
            logger.info("🎬 VIDEO_PLAYER_MANAGER: Playback started", metadata: nil)
        } else {
            logger.warning("🎬 VIDEO_PLAYER_MANAGER: Player not ready, cannot start playback", metadata: nil)
        }
    }
    
    /// Pause playback
    public func pausePlayback() {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Pausing playback", metadata: nil)
        player.pause()
    }
    
    /// Get current playback time
    public var currentTime: CMTime {
        return player.currentTime()
    }
    
    /// Seek to specific time
    public func seek(to time: CMTime) {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Seeking to time: \(time.seconds)s", metadata: nil)
        player.seek(to: time)
    }
    
    /// Explicitly called ONLY when the entire video workflow is finished
    public func teardownPlayer() {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Tearing down player", metadata: nil)
        
        // Pause playback
        player.pause()
        
        // Replace current item with nil to release resources
        player.replaceCurrentItem(with: nil)
        
        // Clear current asset
        currentAsset = nil
        
        // Reset state
        isPlayerReady = false
        playerStatus = .unknown
        
        // Optionally, you can clear the cache if needed
        // assetCache.removeAllObjects()
        
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Teardown completed", metadata: nil)
    }
    
    // MARK: - Private Methods
    
    /// Set up observation of player status changes
    private func setupPlayerObservation() {
        // Observe player status changes
        player.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.handlePlayerStatusChange(status)
            }
            .store(in: &cancellables)
        
        // Observe current item status changes
        player.publisher(for: \.currentItem?.status)
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.handlePlayerItemStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    /// Set up asset cache configuration
    private func setupAssetCache() {
        // Configure cache to respect system memory pressure
        assetCache.countLimit = 10 // Limit to 10 cached assets
        assetCache.totalCostLimit = 500 * 1024 * 1024 // 500MB total cost limit
        
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Asset cache configured (count: 10, cost: 500MB)", metadata: nil)
    }
    
    /// Handle player status changes
    private func handlePlayerStatusChange(_ status: AVPlayer.Status) {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Player status changed to: \(statusString(for: status))", metadata: nil)
        
        playerStatus = status
        
        switch status {
        case .readyToPlay:
            // Don't set ready until item is also ready
            if player.currentItem?.status == .readyToPlay {
                updatePlayerReadiness(true)
            }
        case .failed:
            logger.error("🎬 VIDEO_PLAYER_MANAGER: Player failed with error: \(String(describing: player.error))", metadata: nil)
            updatePlayerReadiness(false)
        case .unknown:
            updatePlayerReadiness(false)
        @unknown default:
            logger.warning("🎬 VIDEO_PLAYER_MANAGER: Unknown player status: \(status.rawValue)", metadata: nil)
            updatePlayerReadiness(false)
        }
    }
    
    /// Handle player item status changes
    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) {
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Player item status changed to: \(itemStatusString(for: status))", metadata: nil)
        
        switch status {
        case .readyToPlay:
            // Player is ready when both player and item are ready
            if player.status == .readyToPlay {
                updatePlayerReadiness(true)
            }
        case .failed:
            logger.error("🎬 VIDEO_PLAYER_MANAGER: Player item failed with error: \(String(describing: player.currentItem?.error))", metadata: nil)
            updatePlayerReadiness(false)
        case .unknown:
            updatePlayerReadiness(false)
        @unknown default:
            logger.warning("🎬 VIDEO_PLAYER_MANAGER: Unknown player item status: \(status.rawValue)", metadata: nil)
            updatePlayerReadiness(false)
        }
    }
    
    /// Update player readiness state
    private func updatePlayerReadiness(_ isReady: Bool) {
        guard isPlayerReady != isReady else { return }
        
        isPlayerReady = isReady
        logger.info("🎬 VIDEO_PLAYER_MANAGER: Player readiness changed to: \(isReady)", metadata: nil)
        
        if isReady {
            logger.info("🎬 VIDEO_PLAYER_MANAGER: ✅ Player is ready for playback", metadata: nil)
            logger.info("🎬 VIDEO_PLAYER_MANAGER: Duration: \(String(describing: player.currentItem?.duration.seconds))s", metadata: nil)
        } else {
            logger.info("🎬 VIDEO_PLAYER_MANAGER: ⏳ Player is not ready", metadata: nil)
        }
    }
    
    /// Convert player status to string for logging
    private func statusString(for status: AVPlayer.Status) -> String {
        switch status {
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        case .unknown: return "unknown"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
    
    /// Convert player item status to string for logging
    private func itemStatusString(for status: AVPlayerItem.Status) -> String {
        switch status {
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        case .unknown: return "unknown"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}