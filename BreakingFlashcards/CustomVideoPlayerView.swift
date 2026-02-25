//
//  CustomVideoPlayerView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreData

struct CustomVideoPlayerView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let move: Move?
    let combo: Combo?
    let url: URL?
    let player: AVPlayer?

    @State private var internalPlayer: AVPlayer? = nil
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var videoError: String? = nil
    @State private var isMuted = false
    @State private var isFullscreen = false

    init(move: Move? = nil, combo: Combo? = nil, url: URL? = nil, player: AVPlayer? = nil) {
        self.move = move
        self.combo = combo
        self.url = url
        self.player = player
    }

    var body: some View {
        ZStack {
            if let player = internalPlayer {
                VideoPlayer(player: player)
                    .onAppear {
                        // Auto-play when view appears
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        // Pause and release audio session when view disappears
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                        isPlaying = false
                    }
                    .onChange(of: isMuted) { _, newValue in
                        player.isMuted = newValue
                    }
                    .overlay(alignment: .topTrailing) {
                        // Controls Overlay
                        HStack(spacing: 12) {
                            // Mute/Unmute Button
                            Button(action: {
                                isMuted.toggle()
                            }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }

                            // Fullscreen Button
                            Button(action: {
                                isFullscreen = true
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(16)
                    }
            } else if let error = videoError {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("Video Unavailable")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.neutralFill)
                .cornerRadius(10)
            } else {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.accent)

                    Text("Loading video...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.neutralFill)
                .cornerRadius(10)
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            if let player = internalPlayer {
                ZStack {
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)

                    // Close button for fullscreen
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isFullscreen = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            configureAmbientAudio()
            setupPlayer()
        }
        .onChange(of: isFullscreen) { _, fullscreen in
            if fullscreen {
                activatePlaybackAudio()
            } else {
                configureAmbientAudio()
            }
        }
        .onChange(of: move) {
            setupPlayer()
        }
        .onChange(of: combo) {
            setupPlayer()
        }
        .onChange(of: url) {
            setupPlayer()
        }
        .onChange(of: player) {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        videoError = nil

        if let player = player {
            self.internalPlayer = player
            return
        }
        
        if let url = url {
            // Direct URL provided
            if FileManager.default.fileExists(atPath: url.path) {
                self.internalPlayer = AVPlayer(url: url)
            } else {
                videoError = "Video file not found"
            }
        } else if let move = move {
            if let videoURL = getVideoURL(for: move) {
                self.internalPlayer = AVPlayer(url: videoURL)
            } else {
                videoError = "No video file found for this move"
            }
        } else if let combo = combo {
            // For combos, we'll play the first move's video
            if let firstMove = getFirstMoveFromCombo(combo) {
                if let videoURL = getVideoURL(for: firstMove) {
                    self.internalPlayer = AVPlayer(url: videoURL)
                } else {
                    videoError = "No video file found for this combo"
                }
            } else {
                videoError = "This combo has no moves"
            }
        } else {
            videoError = "No content to display"
        }
    }

    private func getVideoURL(for move: Move) -> URL? {
        guard let videoData = move.videoReference,
              let storedPath = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if storedPath.hasPrefix("/") {
            // Legacy absolute path — try as-is first
            if FileManager.default.fileExists(atPath: storedPath) {
                return URL(fileURLWithPath: storedPath)
            }
            // Container UUID changed — extract filename, rebuild path
            let filename = (storedPath as NSString).lastPathComponent
            let rebuilt = documentsDir.appendingPathComponent("Moves/\(filename)")
            return FileManager.default.fileExists(atPath: rebuilt.path) ? rebuilt : nil
        }

        // New relative path format
        let resolved = documentsDir.appendingPathComponent(storedPath)
        return FileManager.default.fileExists(atPath: resolved.path) ? resolved : nil
    }

    private func getFirstMoveFromCombo(_ combo: Combo) -> Move? {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)]
        fetchRequest.fetchLimit = 1

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            return comboMoves.first?.move
        } catch {
            return nil
        }
    }

    // MARK: - Audio Session

    /// Ambient: mixes with other audio — user's music keeps playing
    private func configureAmbientAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.ambient)
        try? session.setActive(true)
    }

    /// Playback: takes exclusive audio — pauses user's music
    private func activatePlaybackAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Playback Control API

    /// Seek to exact frame with zero tolerance
    func seekToFrame(at time: CMTime) {
        internalPlayer?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Set playback rate (supports negative for reverse)
    func setRate(_ rate: Float) {
        internalPlayer?.rate = rate
    }
}

#Preview {
    // Preview with mock data
    let context = PersistenceController.preview.container.viewContext
    let move = Move(context: context)
    move.id = UUID()
    move.name = "Sample Move"

    return CustomVideoPlayerView(move: move)
        .frame(height: 300)
        .padding()
        .environment(\.managedObjectContext, context)
}