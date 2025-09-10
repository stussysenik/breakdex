import SwiftUI
import AVKit

struct CustomVideoPlayerView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    private let asset: AVAsset
    private let rotationQuarterTurns: Int

    @State private var isMuted = false
    @State private var showFullscreen = false

    init(asset: AVAsset, rotationQuarterTurns: Int) {
        self._viewModel = StateObject(wrappedValue: VideoPlayerViewModel())
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

            case .playing(let player):
                VideoPlayer(player: player)
                    .onTapGesture { player.togglePlayback() }
                    .overlay(alignment: .topTrailing) {
                        HStack {
                            Button { showFullscreen = true } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            Button { isMuted.toggle() } label: {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            }
                        }
                        .padding()
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding()
                    }
                    .onChange(of: isMuted) { _, muted in
                        player.isMuted = muted
                    }
                    .fullScreenCover(isPresented: $showFullscreen) {
                        FullscreenVideoPlayer(player: player, isPresented: $showFullscreen)
                    }

            case .error(let message):
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            viewModel.setSource(asset: asset, quarterTurns: rotationQuarterTurns)
        }
        .onDisappear {
            viewModel.teardown()
        }
    }
}

fileprivate extension AVPlayer {
    func togglePlayback() {
        if rate == 0 {
            play()
        } else {
            pause()
        }
    }
}

// MARK: - Fullscreen Player
private struct FullscreenVideoPlayer: View {
    let player: AVPlayer
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)

            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .opacity(0.8)
            }
            .padding()
        }
    }
}
