//
//  CustomVideoPlayerView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//  Refactored to use VideoPlayerViewModel for proper lifecycle management
//

import SwiftUI
import AVKit
import CoreData
import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit
@preconcurrency import AVFoundation

// MARK: - CGAffineTransform Validation Extension
extension CGAffineTransform {
    func isValid() -> Bool {
        // Check that all components are finite (not NaN or infinite)
        return a.isFinite && b.isFinite && c.isFinite && d.isFinite && tx.isFinite && ty.isFinite
    }

    var debugDescription: String {
        return String(format: "[%.3f, %.3f, %.3f, %.3f, %.3f, %.3f]", a, b, c, d, tx, ty)
    }
}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: View {
    let move: Move?
    let url: URL?
    let photosIdentifier: String?
    let asset: AVAsset?
    let rotationQuarterTurns: Int
    let onRelinkRequested: (() -> Void)?

    // MARK: - Video Player ViewModel (single source of truth)
    @StateObject private var videoModel = VideoPlayerViewModel()

    @State private var isMuted = false
    @State private var isPlaying = false
    @State private var showFullscreen = false
    @State private var showLoadingIndicator = false
    @State private var loadingTimer: Timer?

    // MARK: - Initializers (preserving all existing APIs)
    init(move: Move?, url: URL? = nil, onRelinkRequested: (() -> Void)? = nil) {
        self.move = move
        self.url = url
        self.photosIdentifier = nil
        self.asset = nil
        self.rotationQuarterTurns = Int(move?.rotationQuarterTurns ?? 0)
        self.onRelinkRequested = onRelinkRequested
    }

    init(url: URL, onRelinkRequested: (() -> Void)? = nil) {
        self.move = nil
        self.url = url
        self.photosIdentifier = nil
        self.asset = nil
        self.rotationQuarterTurns = 0
        self.onRelinkRequested = onRelinkRequested
    }

    init(move: Move? = nil, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, onRelinkRequested: (() -> Void)? = nil) {
        self.move = move
        self.url = nil
        self.photosIdentifier = photosIdentifier
        self.asset = nil
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onRelinkRequested = onRelinkRequested
    }

    init(asset: AVAsset, rotationQuarterTurns: Int = 0, onRelinkRequested: (() -> Void)? = nil) {
        self.move = nil
        self.url = nil
        self.photosIdentifier = nil
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onRelinkRequested = onRelinkRequested
    }

    init(_ player: AVPlayer, asset: AVAsset? = nil, rotationQuarterTurns: Int = 0) {
        self.move = nil
        self.url = nil
        self.photosIdentifier = nil
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onRelinkRequested = nil
        // For external player, we'll need to adapt this
    }

    // MARK: - Helper Properties
    private var shouldSetupPlayer: Bool {
        return move != nil || url != nil || photosIdentifier != nil || asset != nil
    }

    private var shouldShowRelink: Bool {
        guard let move = move, onRelinkRequested != nil else { return false }

        if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
            return true
        }

        if let videoURL = getVideoURL(for: move) {
            return !FileManager.default.fileExists(atPath: videoURL.path)
        }

        return true
    }

    // MARK: - Helper Methods
    private func startLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [self] _ in
            Task { @MainActor in
                self.showLoadingIndicator = true
            }
        }
    }

    private func cancelLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        showLoadingIndicator = false
    }

    private func getVideoURL(for move: Move) -> URL? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            switch videoModel.state {
            case .loading:
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing loading state")
                ZStack {
                    Color.backgroundPrimary
                        .edgesIgnoringSafeArea(.all)

                    if showLoadingIndicator {
                        Text("Loading video...")
                            .font(.ibmPlexMono(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            case .playing(let player):
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing playing state")
                ZStack {
                    VideoPlayer(player: player)
                        .assertNoTransforms()
                        .onAppear {
                            player.play()
                            isPlaying = true
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                        }
                        .onChange(of: isMuted) { _, newValue in
                            player.isMuted = newValue
                        }
                        .onChange(of: isPlaying) { _, newValue in
                            if newValue {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isPlaying.toggle()
                        }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if !isPlaying {
                                Image(systemName: "play.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { showFullscreen = true }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 8)

                            Button(action: { isMuted.toggle() }) {
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
                .fullScreenCover(isPresented: $showFullscreen) {
                    if case .playing(let player) = videoModel.state {
                        FullscreenVideoPlayer(player: player, isPresented: $showFullscreen)
                    }
                }

            case .error(let message):
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing error state: \(message)")
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(message)
                        .font(.headline)
                    if shouldShowRelink {
                        Button("Relink Video", action: { onRelinkRequested?() })
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            print("🎬 CustomVideoPlayerView task triggered")
            print("   📊 shouldSetupPlayer: \(shouldSetupPlayer)")
            print("   📹 move: \(move?.name ?? "nil")")
            print("   🆔 photosIdentifier: \(photosIdentifier ?? "nil")")
            print("   📹 asset: \(asset != nil ? "provided" : "nil")")
            print("   🔗 url: \(url?.absoluteString ?? "nil")")
            print("   🔄 rotationQuarterTurns: \(rotationQuarterTurns)")

            if shouldSetupPlayer {
                print("🎬 Starting player setup...")
                startLoadingTimer()

                // Set up the video source in the model
                if let asset = asset {
                    videoModel.setSource(asset: asset, quarterTurns: rotationQuarterTurns)
                }
                // TODO: Handle other sources (move, url, photosIdentifier)

                cancelLoadingTimer()
                print("🎬 Player setup completed")
            } else {
                print("⚠️ shouldSetupPlayer is false, skipping setup")
            }
        }
        .onDisappear {
            // Clean teardown when view disappears
            videoModel.teardown()
            cancelLoadingTimer()
        }
    }
}

// MARK: - Fullscreen Video Player
struct FullscreenVideoPlayer: View {
    let player: AVPlayer
    @Binding var isPresented: Bool

    @State private var isMuted = false
    @State private var isPlaying = true

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VideoPlayer(player: player)
                .onAppear {
                    player.play()
                    isPlaying = true
                }
                .onDisappear {
                    player.pause()
                    isPlaying = false
                }
                .onChange(of: isMuted) { _, newValue in
                    player.isMuted = newValue
                }
                .onChange(of: isPlaying) { _, newValue in
                    if newValue {
                        player.play()
                    } else {
                        player.pause()
                    }
                }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isPlaying.toggle()
                }

            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()

                    Button(action: { isMuted.toggle() }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                if !isPlaying {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct CustomVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomVideoPlayerView(move: nil, photosIdentifier: nil, onRelinkRequested: nil)
            .frame(height: 300)
            .padding()
    }
}
