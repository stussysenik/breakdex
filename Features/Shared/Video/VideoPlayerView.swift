// import SwiftUI
// import AVKit
// import AVFoundation

// // MARK: - Shared Video Player View
// /// Clean, reusable SwiftUI video player view for consistent video UI across features
// public struct SharedVideoPlayerView: View {
//     // MARK: - Properties
//     @StateObject private var player: SharedVideoPlayer
//     @State private var showFullscreen = false
//     @State private var isMuted = false
//     @State private var showControls = true
//     @State private var controlsTimer: Timer?

//     private let configuration: PlayerConfiguration
//     private let onPlayerReady: (() -> Void)?
//     private let onPlaybackComplete: (() -> Void)?

//     // MARK: - Player Configuration
//     public struct PlayerConfiguration {
//         let autoplay: Bool
//         let showControls: Bool
//         let allowFullscreen: Bool
//         let allowMute: Bool
//         let controlsAutoHide: Bool
//         let backgroundColor: Color

//         public init(
//             autoplay: Bool = false,
//             showControls: Bool = true,
//             allowFullscreen: Bool = true,
//             allowMute: Bool = true,
//             controlsAutoHide: Bool = true,
//             backgroundColor: Color = .black
//         ) {
//             self.autoplay = autoplay
//             self.showControls = showControls
//             self.allowFullscreen = allowFullscreen
//             self.allowMute = allowMute
//             self.controlsAutoHide = controlsAutoHide
//             self.backgroundColor = backgroundColor
//         }

//         public static let `default` = PlayerConfiguration()
//         public static let preview = PlayerConfiguration(
//             autoplay: true,
//             showControls: false,
//             allowFullscreen: false,
//             allowMute: false,
//             controlsAutoHide: false
//         )
//         public static let minimal = PlayerConfiguration(
//             autoplay: false,
//             showControls: true,
//             allowFullscreen: false,
//             allowMute: true,
//             controlsAutoHide: false
//         )
//     }

//     // MARK: - Initialization
//     public init(
//         asset: AVAsset,
//         configuration: PlayerConfiguration = .default,
//         onPlayerReady: (() -> Void)? = nil,
//         onPlaybackComplete: (() -> Void)? = nil
//     ) {
//         self._player = StateObject(wrappedValue: SharedVideoPlayer())
//         self.configuration = configuration
//         self.onPlayerReady = onPlayerReady
//         self.onPlaybackComplete = onPlaybackComplete
//     }

//     public init(
//         player: SharedVideoPlayer,
//         configuration: PlayerConfiguration = .default,
//         onPlayerReady: (() -> Void)? = nil,
//         onPlaybackComplete: (() -> Void)? = nil
//     ) {
//         self._player = StateObject(wrappedValue: player)
//         self.configuration = configuration
//         self.onPlayerReady = onPlayerReady
//         self.onPlaybackComplete = onPlaybackComplete
//     }

//     // MARK: - Body
//     public var body: some View {
//         ZStack {
//             // Background
//             configuration.backgroundColor
//                 .ignoresSafeArea()

//             // Video Content
//             videoContent

//             // Controls
//             if configuration.showControls && showControls {
//                 controlsOverlay
//             }

//             // Loading indicator
//             if player.state.isLoading {
//                 loadingOverlay
//             }

//             // Error overlay
//             if case .error = player.state {
//                 errorOverlay
//             }
//         }
//         .onAppear {
//             Task {
//                 // Note: Asset loading would need to be handled differently
//                 // since the view doesn't have direct access to the asset here
//                 if configuration.autoplay && player.state.canPlay {
//                     player.play()
//                 }
//             }
//         }
//         .onDisappear {
//             player.cleanup()
//         }
//         .onChange(of: player.state) {
//             if case .ready = player.state {
//                 onPlayerReady?()
//             }

//             if case .ended = player.state {
//                 onPlaybackComplete?()
//             }

//             // Reset controls timer when state changes
//             if configuration.controlsAutoHide {
//                 resetControlsTimer()
//             }
//         }
//         .onTapGesture {
//             if configuration.controlsAutoHide {
//                 toggleControlsVisibility()
//             }
//         }
//         .fullScreenCover(isPresented: $showFullscreen) {
//             if let avPlayer = getPlayerInstance() {
//                 FullscreenVideoPlayer(player: avPlayer, isPresented: $showFullscreen)
//             }
//         }
//     }

//     // MARK: - View Components

//     @ViewBuilder
//     private var videoContent: some View {
//         if player.isReady, let avPlayer = getPlayerInstance() {
//             VideoPlayer(player: avPlayer)
//                 .onAppear {
//                     setupControlsTimer()
//                 }
//         } else {
//             Rectangle()
//                 .fill(Color.gray.opacity(0.3))
//         }
//     }

//     @ViewBuilder
//     private var controlsOverlay: some View {
//         VStack {
//             Spacer()

//             HStack {
//                 Spacer()

//                 // Play/Pause button
//                 Button {
//                     player.togglePlayPause()
//                 } label: {
//                     Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
//                         .font(.largeTitle)
//                         .foregroundColor(.white)
//                         .background(Color.black.opacity(0.5))
//                         .clipShape(Circle())
//                 }

//                 Spacer()

//                 // Time display
//                 Text("\(player.currentTimeString) / \(player.durationString)")
//                     .font(.caption)
//                     .foregroundColor(.white)
//                     .padding(.horizontal, 8)
//                     .padding(.vertical, 4)
//                     .background(Color.black.opacity(0.5))
//                     .cornerRadius(4)

//                 Spacer()

//                 // Control buttons
//                 HStack(spacing: 16) {
//                     if configuration.allowMute {
//                         Button {
//                             isMuted.toggle()
//                             player.setMuted(isMuted)
//                         } label: {
//                             Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
//                                 .font(.title2)
//                                 .foregroundColor(.white)
//                         }
//                     }

//                     if configuration.allowFullscreen {
//                         Button {
//                             showFullscreen = true
//                         } label: {
//                             Image(systemName: "arrow.up.left.and.arrow.down.right")
//                                 .font(.title2)
//                                 .foregroundColor(.white)
//                         }
//                     }
//                 }
//                 .padding(.horizontal)
//                 .padding(.vertical, 8)
//                 .background(Color.black.opacity(0.5))
//                 .cornerRadius(8)

//                 Spacer()
//             }
//             .padding(.horizontal)
//             .padding(.bottom, 8)
//         }
//     }

//     @ViewBuilder
//     private var loadingOverlay: some View {
//         VStack(spacing: 16) {
//             ProgressView()
//                 .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                 .scaleEffect(1.5)

//             Text(player.state.isLoading ? "Loading video..." : "Preparing...")
//                 .font(.subheadline)
//                 .foregroundColor(.white)

//             if player.progress > 0 {
//                 Text("\(Int(player.progress * 100))%")
//                     .font(.caption)
//                     .foregroundColor(.white.opacity(0.8))
//             }
//         }
//         .frame(maxWidth: .infinity, maxHeight: .infinity)
//         .background(Color.black.opacity(0.7))
//     }

//     @ViewBuilder
//     private var errorOverlay: some View {
//         VStack(spacing: 16) {
//             Image(systemName: "video.slash.fill")
//                 .font(.system(size: 48))
//                 .foregroundColor(.white.opacity(0.8))

//             Text(player.errorMessage ?? "Video playback error")
//                 .font(.headline)
//                 .foregroundColor(.white)
//                 .multilineTextAlignment(.center)

//             Button("Retry") {
//                 // Note: This would need the asset to be available again
//                 // Implementation would depend on how the view is used
//             }
//             .buttonStyle(.borderedProminent)
//         }
//         .frame(maxWidth: .infinity, maxHeight: .infinity)
//         .background(Color.black.opacity(0.8))
//     }

//     // MARK: - Private Methods

//     private func getPlayerInstance() -> AVPlayer? {
//         // This is a placeholder - the actual implementation would need
//         // to expose the AVPlayer from SharedVideoPlayer
//         return nil
//     }

//     private func setupControlsTimer() {
//         guard configuration.controlsAutoHide else { return }

//         controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
//             Task { @MainActor in
//                 withAnimation(.easeInOut(duration: 0.3)) {
//                     showControls = false
//                 }
//             }
//         }
//     }

//     private func resetControlsTimer() {
//         controlsTimer?.invalidate()
//         if showControls {
//             setupControlsTimer()
//         }
//     }

//     private func toggleControlsVisibility() {
//         withAnimation(.easeInOut(duration: 0.3)) {
//             showControls.toggle()
//         }

//         if showControls {
//             setupControlsTimer()
//         } else {
//             controlsTimer?.invalidate()
//         }
//     }
// }

// // MARK: - Fullscreen Video Player
// private struct FullscreenVideoPlayer: View {
//     let player: AVPlayer
//     @Binding var isPresented: Bool

//     var body: some View {
//         ZStack {
//             Color.black.ignoresSafeArea()

//             VideoPlayer(player: player)

//             VStack {
//                 HStack {
//                     Button {
//                         isPresented = false
//                     } label: {
//                         Image(systemName: "xmark.circle.fill")
//                             .font(.largeTitle)
//                             .foregroundColor(.white)
//                             .background(Color.black.opacity(0.5))
//                             .clipShape(Circle())
//                     }
//                     .padding()

//                     Spacer()
//                 }

//                 Spacer()
//             }
//         }
//         .onAppear {
//             player.play()
//         }
//         .onDisappear {
//             player.pause()
//         }
//     }
// }

// // MARK: - Preview
// #Preview {
//     struct PreviewWrapper: View {
//         var body: some View {
//             // Note: This preview would need a valid AVAsset to work
//             VStack {
//                 Text("Shared Video Player View")
//                     .font(.headline)

//                 // SharedVideoPlayerView(asset: sampleAsset)
//                 //     .frame(height: 300)

//                 Text("Preview requires valid video asset")
//                     .foregroundColor(.gray)
//             }
//             .padding()
//         }
//     }

//     return PreviewWrapper()
// }

// // MARK: - Convenience Extensions
// public extension SharedVideoPlayerView {
//     /// Create a player view for preview/thumbnail usage
//     static func preview(asset: AVAsset) -> SharedVideoPlayerView {
//         return SharedVideoPlayerView(
//             asset: asset,
//             configuration: .preview
//         )
//     }

//     /// Create a minimal player view with basic controls
//     static func minimal(asset: AVAsset) -> SharedVideoPlayerView {
//         return SharedVideoPlayerView(
//             asset: asset,
//             configuration: .minimal
//         )
//     }

//     /// Create a full-featured player view
//     static func full(asset: AVAsset) -> SharedVideoPlayerView {
//         return SharedVideoPlayerView(
//             asset: asset,
//             configuration: .default
//         )
//     }
// }