// import AVFoundation
// import SwiftUI
// import Combine

// // MARK: - Unified Player Manager
// /// Unified video player manager for consistent video playback across the app
// /// Provides a clean interface for video player operations with state management
// @MainActor
// class UnifiedPlayerManager: ObservableObject {

//     // MARK: - Published Properties
//     @Published var isPlaying: Bool = false
//     @Published var currentTime: TimeInterval = 0.0
//     @Published var duration: TimeInterval = 0.0
//     @Published var playbackRate: Float = 1.0
//     @Published var volume: Float = 1.0
//     @Published var isLooping: Bool = false

//     // MARK: - Private Properties
//     private var player: AVPlayer?
//     private var playerItem: AVPlayerItem?
//     private var timeObserver: Any?
//     private var cancellables = Set<AnyCancellable>()

//     // MARK: - Initialization
//     init() {
//         setupNotifications()
//     }

//     deinit {
//         Task { @MainActor in
//             cleanup()
//         }
//     }

//     // MARK: - Public Methods

//     /// Load a video asset for playback
//     /// - Parameter asset: The AVAsset to load
//     func loadAsset(_ asset: AVAsset) {
//         // Clean up previous player
//         cleanupPlayer()

//         // Create new player item and player
//         playerItem = AVPlayerItem(asset: asset)
//         player = AVPlayer(playerItem: playerItem)

//         // Setup time observer
//         setupTimeObserver()

//         // Load duration
//         Task {
//             do {
//                 let loadedDuration = try await asset.load(.duration)
//                 await MainActor.run {
//                     self.duration = loadedDuration.seconds
//                 }
//             } catch {
//                 Logger.unifiedPlayerManager.error("Failed to load video duration: \(error.localizedDescription)")
//             }
//         }

//         Logger.unifiedPlayerManager.info("Video asset loaded successfully")
//     }

//     /// Play the currently loaded video
//     func play() {
//         guard let player = player else {
//             Logger.unifiedPlayerManager.warning("No player available for playback")
//             return
//         }

//         player.play()
//         isPlaying = true
//         Logger.unifiedPlayerManager.info("Video playback started")
//     }

//     /// Pause the currently playing video
//     func pause() {
//         guard let player = player else {
//             Logger.unifiedPlayerManager.warning("No player available for pausing")
//             return
//         }

//         player.pause()
//         isPlaying = false
//         Logger.unifiedPlayerManager.info("Video playback paused")
//     }

//     /// Toggle play/pause state
//     func togglePlayPause() {
//         if isPlaying {
//             pause()
//         } else {
//             play()
//         }
//     }

//     /// Seek to a specific time
//     /// - Parameter time: The time to seek to in seconds
//     func seek(to time: TimeInterval) {
//         guard let player = player else {
//             Logger.unifiedPlayerManager.warning("No player available for seeking")
//             return
//         }

//         let cmTime = CMTime(seconds: time, preferredTimescale: 600)
//         player.seek(to: cmTime) { [weak self] completed in
//             if completed {
//                 Task { @MainActor in
//                     self?.currentTime = time
//                 }
//                 Logger.unifiedPlayerManager.info("Seek completed to time: \(time)s")
//             } else {
//                 Logger.unifiedPlayerManager.warning("Seek failed to time: \(time)s")
//             }
//         }
//     }

//     /// Set the playback rate
//     /// - Parameter rate: The playback rate (1.0 = normal speed)
//     func setPlaybackRate(_ rate: Float) {
//         guard let player = player else { return }
//         player.rate = rate
//         playbackRate = rate
//     }

//     /// Set the volume
//     /// - Parameter volume: The volume level (0.0 to 1.0)
//     func setVolume(_ volume: Float) {
//         guard let player = player else { return }
//         player.volume = volume
//         self.volume = volume
//     }

//     /// Get the current AVPlayer instance
//     /// - Returns: The current AVPlayer if available
//     func getPlayer() -> AVPlayer? {
//         return player
//     }

//     // MARK: - Private Methods

//     private func setupTimeObserver() {
//         guard let player = player else { return }

//         let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
//         timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
//             Task { @MainActor in
//                 self?.currentTime = time.seconds
//             }
//         }
//     }

//     private func setupNotifications() {
//         NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
//             .sink { [weak self] _ in
//                 Task { @MainActor in
//                     self?.handlePlaybackEnd()
//                 }
//             }
//             .store(in: &cancellables)
//     }

//     private func handlePlaybackEnd() {
//         isPlaying = false
//         currentTime = duration

//         if isLooping {
//             seek(to: 0)
//             play()
//         }

//         Logger.unifiedPlayerManager.info("Video playback ended")
//     }

//     private func cleanupPlayer() {
//         if let timeObserver = timeObserver {
//             player?.removeTimeObserver(timeObserver)
//             self.timeObserver = nil
//         }

//         player?.pause()
//         player = nil
//         playerItem = nil

//         // Reset state
//         isPlaying = false
//         currentTime = 0.0
//         duration = 0.0
//         playbackRate = 1.0
//     }

//     private func cleanup() {
//         cleanupPlayer()
//         cancellables.removeAll()
//     }
// }

// // MARK: - Logger Extension
// extension Logger {
//     static let unifiedPlayerManager = Logger(subsystem: "com.breakingflashcards", category: "🎬 UNIFIED_PLAYER_MANAGER")
// }