import AVFoundation
import AVKit
import Combine
import OSLog
import SwiftUI

// MARK: - Shared Video Player
/// Clean, reusable video player component for consistent video playback across features
@MainActor
public class SharedVideoPlayer: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var isPlaying = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var duration: Double = 0.0
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var isReady = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SharedVideoPlayer")
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private let mode: PlayerMode

    // MARK: - Player Modes
    public enum PlayerMode {
        case main      // Full-featured player for primary video content
        case preview   // Lightweight player for previews/thumbnails
    }

    // MARK: - Player States
    public enum PlayerState: Equatable {
        case idle
        case loading(progress: Double, message: String)
        case ready
        case playing
        case paused
        case ended
        case error(message: String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        var canPlay: Bool {
            switch self {
            case .ready, .paused, .ended: return true
            default: return false
            }
        }

        var canPause: Bool {
            switch self {
            case .playing: return true
            default: return false
            }
        }
    }

    // MARK: - Initialization
    public init(mode: PlayerMode = .main) {
        self.mode = mode
        logger.info("🎬 SharedVideoPlayer initialized with mode: \(mode)")
    }

    deinit {
        // Cleanup resources synchronously in deinit
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        cancellables.removeAll()

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    // MARK: - Public Methods

    /// Load video from AVAsset
    /// - Parameter asset: The video asset to load
    public func loadVideo(_ asset: AVAsset) async {
        logger.info("🎬 Loading video asset")

        await MainActor.run {
            state = .loading(progress: 0.0, message: "Loading video...")
            errorMessage = nil
        }

        do {
            // Load asset duration
            let assetDuration = try await asset.load(.duration)

            await MainActor.run {
                duration = assetDuration.seconds

                // Create player and player item
                playerItem = AVPlayerItem(asset: asset)
                player = AVPlayer(playerItem: playerItem)

                // Setup observers
                setupPlayerObservers()
                setupTimeObserver()

                state = .ready
                isReady = true

                logger.info("✅ Video loaded successfully, duration: \(duration)s")
            }
        } catch {
            await MainActor.run {
                state = .error(message: "Failed to load video: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                logger.error("❌ Failed to load video: \(error.localizedDescription)")
            }
        }
    }

    /// Start video playback
    public func play() {
        guard state.canPlay, let player = player else {
            logger.warning("⚠️ Cannot play - player not ready")
            return
        }

        logger.info("▶️ Starting playback")
        player.play()

        Task { @MainActor in
            state = .playing
            isPlaying = true
        }
    }

    /// Pause video playback
    public func pause() {
        guard state.canPause, let player = player else {
            logger.warning("⚠️ Cannot pause - player not playing")
            return
        }

        logger.info("⏸️ Pausing playback")
        player.pause()

        Task { @MainActor in
            state = .paused
            isPlaying = false
        }
    }

    /// Stop video playback and reset to beginning
    public func stop() {
        guard let player = player else { return }

        logger.info("⏹️ Stopping playback")
        player.pause()
        player.seek(to: .zero)

        Task { @MainActor in
            state = .ready
            isPlaying = false
            currentTime = 0.0
            progress = 0.0
        }
    }

    /// Seek to specific time
    /// - Parameter time: Time in seconds
    public func seek(to time: Double) {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)

        logger.info("⏩ Seeking to \(time)s")
    }

    /// Toggle between play and pause
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Set volume
    /// - Parameter volume: Volume level (0.0 - 1.0)
    public func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    /// Set mute state
    /// - Parameter muted: Whether to mute the player
    public func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    /// Cleanup resources
    public func cleanup() {
        logger.info("🧹 Cleaning up video player resources")

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        cancellables.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil

        Task { @MainActor in
            state = .idle
            isReady = false
            isPlaying = false
        }
    }

    // MARK: - Private Methods

    private func setupPlayerObservers() {
        guard let playerItem = playerItem else { return }

        // Observe player item status
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                Task { @MainActor in
                    self?.handlePlayerItemStatusChange(status)
                }
            }
            .store(in: &cancellables)

        // Observe playback buffer
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] isLikelyToKeepUp in
                Task { @MainActor in
                    self?.handleBufferChange(isLikelyToKeepUp)
                }
            }
            .store(in: &cancellables)

        // Observe player rate (play/pause)
        if let player = player {
            player.publisher(for: \.rate)
                .sink { [weak self] rate in
                    Task { @MainActor in
                        self?.handleRateChange(rate)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            logger.info("✅ Player item ready to play")
            if state.isLoading {
                state = .ready
            }
        case .failed:
            let errorMessage = playerItem?.error?.localizedDescription ?? "Unknown playback error"
            logger.error("❌ Player item failed: \(errorMessage)")
            state = .error(message: errorMessage)
            self.errorMessage = errorMessage
        case .unknown:
            logger.info("📡 Player item status unknown")
        @unknown default:
            logger.warning("⚠️ Unknown player item status: \(status.rawValue)")
        }
    }

    private func handleBufferChange(_ isLikelyToKeepUp: Bool) {
        if !isLikelyToKeepUp && isPlaying {
            logger.info("⏳ Buffering...")
            // Could show buffering indicator here
        }
    }

    private func handleRateChange(_ rate: Float) {
        let wasPlaying = isPlaying
        let isCurrentlyPlaying = rate > 0

        if wasPlaying != isCurrentlyPlaying {
            isPlaying = isCurrentlyPlaying

            if isCurrentlyPlaying, case .ready = state {
                state = .playing
            } else if !isCurrentlyPlaying, case .playing = state {
                state = .paused
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        currentTime = time.seconds
        progress = duration > 0 ? currentTime / duration : 0.0

        // Check if video ended
        if progress >= 1.0 && isPlaying {
            state = .ended
            isPlaying = false
            logger.info("🏁 Video playback ended")
        }
    }
}

// MARK: - Convenience Extensions
public extension SharedVideoPlayer {
    /// Get current playback time as formatted string (MM:SS)
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// Get duration as formatted string (MM:SS)
    var durationString: String {
        return formatTime(duration)
    }

    /// Get remaining time as formatted string (MM:SS)
    var remainingTimeString: String {
        return formatTime(max(0, duration - currentTime))
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}