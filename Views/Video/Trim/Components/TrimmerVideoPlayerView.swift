import SwiftUI
import AVKit

struct TrimmerVideoPlayerView: View { // contains the video player with play/pause and mute controls
    let player: AVPlayer
    @State private var isMuted = false
    @State private var isPlaying = false

    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            player.play()
        } else {
            player.pause()
        }
    }

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .onAppear {
                    // do not auto-play here, let the tap gesture control it
                }
                .onDisappear {
                    player.pause()
                }
                .onChange(of: isMuted) { _, newValue in
                    player.isMuted = newValue
                }

            Color.clear // tap-to-play/pause overlay (covers entire video area)
                .contentShape(Rectangle())
                .onTapGesture {
                    togglePlayback()
                }

            VStack { // control overlay
                Spacer()
                HStack {
                    Spacer()
                    if !isPlaying { // play/pause indicator in center when paused
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .onTapGesture {
                                togglePlayback()
                            }
                    }
                    Spacer()
                }
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isMuted.toggle() }) { // mute button
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }
        }
    }
}
