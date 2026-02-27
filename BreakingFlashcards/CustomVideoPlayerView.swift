// CustomVideoPlayerView.swift — Unified video player for Breakdex
//
// This view handles all video playback across the app. It is used in three contexts:
//   1. Move detail screens: shows a move's recorded video clip (pass move: Move)
//   2. Combo review screens: shows the first move's video in a combo (pass combo: Combo)
//   3. Video editor preview: shows the player from VideoEditorView (pass player: AVPlayer)
//
// The view resolves the video source through a priority chain:
//   player > url > move > combo (first move in sequence)
//
// FEATURES:
//   - Auto-play with looping (configurable via autoPlay parameter)
//   - Mute toggle button with iOS 26 Liquid Glass effect
//   - Fullscreen presentation via .fullScreenCover
//   - Audio session management (ambient for inline, playback for fullscreen)
//   - Graceful error states with placeholder UI
//   - Loading spinner while the player initializes
//   - Reactive: re-initializes when any input (move/combo/url/player) changes
//
// VIDEO PATH RESOLUTION:
//   Move.videoReference stores the path as Data (UTF-8 encoded string).
//   The path can be either:
//     - Relative (e.g. "Moves/UUID.mp4"): resolved against Documents directory
//     - Absolute (e.g. "/var/mobile/.../Moves/UUID.mp4"): used directly, with fallback
//       to Documents/Moves/{filename} if the absolute path is stale
//   This dual-path handling supports both the current storage format and legacy data
//   from before the migration to relative paths.
//
// AUDIO SESSION STRATEGY:
//   - Inline playback uses .ambient category: mixes with other audio, respects silent mode.
//     This is the polite default — watching a move clip shouldn't kill the user's music.
//   - Fullscreen uses .playback category: exclusive audio, ignores silent mode.
//     This is what users expect when they go fullscreen — they want to hear the audio.
//   - Session is deactivated with .notifyOthersOnDeactivation before switching categories,
//     which lets other apps (like Music) resume their audio.
//
// CONNECTED FILES:
//   - Models.swift: Move.videoReference (Data), Combo.comboMoves relationship
//   - VideoEditorView.swift: passes its AVPlayer directly for the preview
//   - MoveDetailView.swift: passes a Move for standalone playback
//   - FlashcardsReviewView.swift: passes Move or Combo for review playback
//   - DesignSystem.swift: Color.textPrimary, .neutralFill, .accent, .liquidGlass modifier

import SwiftUI
import SwiftData
import AVKit
import AVFoundation

// MARK: - CustomVideoPlayerView

/// A versatile video player view that can display video from a Move, Combo, URL, or AVPlayer.
/// Handles auto-play, looping, mute, fullscreen, and error states.
struct CustomVideoPlayerView: View {

    // -----------------------------------------------------------------------
    // MARK: - Injected Dependencies (all optional — only one is needed)
    // -----------------------------------------------------------------------

    /// A SwiftData Move model. If provided, the video is loaded from
    /// Move.videoReference (a relative path stored as Data).
    let move: Move?

    /// A SwiftData Combo model. If provided, the video of the FIRST move
    /// in the combo's sequence is displayed (sorted by ComboMove.sequenceIndex).
    let combo: Combo?

    /// A direct URL to a video file. If provided, the video is loaded from
    /// this URL after verifying the file exists on disk.
    let url: URL?

    /// An externally managed AVPlayer instance. Used by VideoEditorView which
    /// needs direct control over playback (rate, seeking, etc.).
    /// When provided, this player is used as-is without creating a new one.
    let player: AVPlayer?

    // -----------------------------------------------------------------------
    // MARK: - State Properties
    // -----------------------------------------------------------------------

    /// The actual AVPlayer used for playback. Set by setupPlayer() based on the
    /// input priority chain: player > url > move > combo.
    /// When this is nil and videoError is also nil, the loading spinner is shown.
    @State private var internalPlayer: AVPlayer? = nil

    /// Tracks whether the video is currently playing (for loop-on-end behavior).
    @State private var isPlaying = false

    /// Human-readable error message when the video can't be loaded.
    /// Triggers the error placeholder UI (video.slash icon + message).
    @State private var videoError: String? = nil

    /// Whether the audio is muted. Toggled by the speaker button overlay.
    /// Synced to internalPlayer.isMuted via an onChange handler.
    @State private var isMuted = false

    /// Whether the fullscreen cover is currently presented.
    /// Toggled by the expand button overlay. Triggers audio session switch.
    @State private var isFullscreen = false

    /// Reference to the NotificationCenter observer for AVPlayerItemDidPlayToEndTime.
    /// Stored so it can be removed in onDisappear to prevent retain cycles.
    /// The observer resets playback to the beginning when the video ends (looping).
    @State private var loopObserver: NSObjectProtocol? = nil

    /// Whether the player is currently buffering (not enough data to play smoothly).
    /// Observed via KVO on AVPlayerItem.isPlaybackLikelyToKeepUp.
    @State private var isBuffering = false

    /// KVO observer for buffering state, stored for cleanup.
    @State private var bufferingObserver: NSKeyValueObservation? = nil

    // -----------------------------------------------------------------------
    // MARK: - Configuration
    // -----------------------------------------------------------------------

    /// When true (default), playback starts automatically when the view appears.
    /// Set to false for the VideoEditorView preview, where the user controls playback
    /// via tap-to-play and the editor manages the player's rate directly.
    var autoPlay: Bool = true

    // -----------------------------------------------------------------------
    // MARK: - Initializer
    // -----------------------------------------------------------------------

    /// Creates a CustomVideoPlayerView with optional video sources.
    /// At least one of move, combo, url, or player should be non-nil.
    /// Resolution priority: player > url > move > combo.
    ///
    /// - Parameters:
    ///   - move: A SwiftData Move model with a videoReference path (optional).
    ///   - combo: A SwiftData Combo model; uses the first move's video (optional).
    ///   - url: A direct file URL to a video (optional).
    ///   - player: An externally managed AVPlayer (optional).
    ///   - autoPlay: Whether to start playback automatically (default: true).
    init(move: Move? = nil, combo: Combo? = nil, url: URL? = nil, player: AVPlayer? = nil, autoPlay: Bool = true) {
        self.move = move
        self.combo = combo
        self.url = url
        self.player = player
        self.autoPlay = autoPlay
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// The body uses a ZStack with three conditional branches:
    ///   1. internalPlayer != nil: Show the video player with overlay controls
    ///   2. videoError != nil: Show the error placeholder
    ///   3. Neither: Show the loading spinner
    var body: some View {
        ZStack {
            if let player = internalPlayer {
                // -------------------------------------------------------
                // BRANCH 1: Video player is ready — show playback with controls
                // -------------------------------------------------------
                VideoPlayer(player: player)
                    .onAppear {
                        // Auto-play if enabled (default for standalone use).
                        // The VideoEditorView sets autoPlay: false and manages playback itself.
                        if autoPlay {
                            player.play()
                            isPlaying = true
                        }
                        // Register a notification observer to loop the video.
                        // AVPlayerItemDidPlayToEndTime fires when the current item finishes.
                        // We seek back to .zero and resume playing to create an infinite loop.
                        loopObserver = NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: player.currentItem,
                            queue: .main
                        ) { _ in
                            // Reset to the beginning of the video.
                            player.seek(to: .zero)
                            // Only resume if we were playing (not if the editor paused us).
                            if isPlaying { player.play() }
                        }
                    }
                    .onDisappear {
                        // Remove the loop observer to prevent retain cycles.
                        if let obs = loopObserver {
                            NotificationCenter.default.removeObserver(obs)
                            loopObserver = nil
                        }
                        // Cancel buffering KVO observer.
                        bufferingObserver?.invalidate()
                        bufferingObserver = nil
                        // Release the player when the view disappears.
                        player.pause()
                        player.replaceCurrentItem(with: nil)
                        isPlaying = false
                    }
                    // Sync the mute state to the player whenever the toggle changes.
                    .onChange(of: isMuted) { _, newValue in
                        player.isMuted = newValue
                    }
                    // Overlay: buffering indicator when player stalls mid-playback.
                    .overlay {
                        if isBuffering {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                                .padding(Spacing.md)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        }
                    }
                    // Overlay: mute + fullscreen buttons in the top-right corner.
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 12) {
                            // -- Mute toggle button --
                            Button(action: {
                                isMuted.toggle()
                            }) {
                                // SF Symbol toggles between speaker.slash.fill (muted)
                                // and speaker.wave.2.fill (unmuted).
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            // .liquidGlass(in: .circle) applies the iOS 26 glass effect.
                            // This calls .glassEffect(.regular.interactive(), in: .circle)
                            // on iOS 26+, making the button translucent with a frosted glass look.
                            // On older iOS versions, this is a no-op (the button appears solid).
                            .liquidGlass(in: .circle)

                            // -- Fullscreen expand button --
                            Button(action: {
                                isFullscreen = true
                            }) {
                                // Arrow icon indicating expand to fullscreen.
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            .liquidGlass(in: .circle)
                        }
                        .padding(16)
                    }
            } else if let error = videoError {
                // -------------------------------------------------------
                // BRANCH 2: Video failed to load — show error placeholder
                // -------------------------------------------------------
                VStack(spacing: 12) {
                    // SF Symbol video.slash icon — universally understood "no video" indicator.
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    // Title text using the primary text color for readability.
                    Text("Video Unavailable")
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    // The specific error message (e.g. "Video file not found").
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                // Fill the entire available space and give it a neutral background.
                // neutralFill: light gray in light mode (#edf0f5), dark slate in dark mode (#181b21).
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.neutralFill)
                .cornerRadius(Radius.lg)
            } else {
                // -------------------------------------------------------
                // BRANCH 3: Still loading — show pulsing placeholder
                // -------------------------------------------------------
                LoadingVideoPlaceholder()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.neutralFill)
                    .cornerRadius(Radius.lg)
            }
        }
        // ---------------------------------------------------------------
        // Fullscreen cover: presented as a modal over the entire screen.
        // Uses .fullScreenCover for a true edge-to-edge experience.
        // ---------------------------------------------------------------
        .fullScreenCover(isPresented: $isFullscreen) {
            if let player = internalPlayer {
                ZStack {
                    // The video player fills the entire screen.
                    VideoPlayer(player: player)
                        .edgesIgnoringSafeArea(.all)

                    // Dismiss button in the top-right corner.
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isFullscreen = false
                            }) {
                                // xmark.circle.fill: a filled X button, white on glass.
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            // Liquid Glass effect on the dismiss button for visual consistency.
                            .liquidGlass(in: .circle)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        // ---------------------------------------------------------------
        // Lifecycle: configure audio session and set up the player on appear.
        // ---------------------------------------------------------------
        .onAppear {
            // Set the audio session to .ambient for inline playback.
            // This mixes with other audio sources and respects the silent switch.
            configureAmbientAudio()
            // Resolve the video source and create the AVPlayer.
            setupPlayer()
        }
        // Switch audio category when entering/leaving fullscreen.
        .onChange(of: isFullscreen) { _, fullscreen in
            if fullscreen {
                // .playback category: exclusive audio, ignores silent switch.
                activatePlaybackAudio()
            } else {
                // Back to .ambient: polite mixing with other apps.
                configureAmbientAudio()
            }
        }
        // Re-initialize the player when any input changes.
        // These onChange handlers support the use case where the same
        // CustomVideoPlayerView instance is reused with different content
        // (e.g. tapping through moves in the combo sequence).
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

    // -----------------------------------------------------------------------
    // MARK: - Player Setup
    // -----------------------------------------------------------------------

    /// Resolves the video source and creates/assigns an AVPlayer.
    /// Priority chain: player > url > move > combo.
    ///
    /// Tears down any existing player before creating a new one to prevent
    /// multiple players running simultaneously (which would waste memory and
    /// potentially cause audio conflicts).
    private func setupPlayer() {
        // Tear down the existing player (if any).
        internalPlayer?.pause()
        // Release the current item's decoded buffers.
        internalPlayer?.replaceCurrentItem(with: nil)
        internalPlayer = nil
        videoError = nil

        // PRIORITY 1: External AVPlayer (from VideoEditorView).
        // Use it directly — the caller manages its lifecycle and playback state.
        if let player = player {
            self.internalPlayer = player
            return
        }

        // PRIORITY 2: Direct URL.
        // Verify the file exists before creating the player.
        if let url = url {
            if FileManager.default.fileExists(atPath: url.path) {
                self.internalPlayer = AVPlayer(url: url)
            } else {
                videoError = "Video file not found"
            }
        }
        // PRIORITY 3: Move model.
        // Resolve the video path from Move.videoReference via centralized resolver.
        else if let move = move {
            if let videoURL = move.resolveVideoURL() {
                self.internalPlayer = AVPlayer(url: videoURL)
            } else {
                videoError = "Video not found for '\(move.name ?? "Untitled")'"
            }
        }
        // PRIORITY 4: Combo model.
        // Find the first move (by sequenceIndex) and use its video.
        else if let combo = combo {
            if let firstMove = getFirstMoveFromCombo(combo) {
                if let videoURL = firstMove.resolveVideoURL() {
                    self.internalPlayer = AVPlayer(url: videoURL)
                } else {
                    videoError = "Video not found for combo move '\(firstMove.name ?? "Untitled")'"
                }
            } else {
                videoError = "This combo has no moves"
            }
        }
        // PRIORITY 5: Nothing provided — show error.
        else {
            videoError = "No content to display"
        }

        // Observe buffering state on the newly created player's current item.
        observeBuffering()
    }

    /// Sets up KVO on the player's currentItem to track buffering state.
    private func observeBuffering() {
        bufferingObserver?.invalidate()
        bufferingObserver = nil
        isBuffering = false

        guard let item = internalPlayer?.currentItem else { return }
        bufferingObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { _, change in
            DispatchQueue.main.async {
                self.isBuffering = !(change.newValue ?? true)
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Combo Move Resolution
    // -----------------------------------------------------------------------

    /// Extracts the first move from a combo's sequence.
    /// Combos contain an array of ComboMove join objects, each linking to a Move
    /// with a sequenceIndex (0-based position). This sorts by index and returns
    /// the Move at position 0.
    ///
    /// - Parameter combo: The Combo model to extract the first move from.
    /// - Returns: The first Move in the sequence, or nil if the combo has no moves.
    private func getFirstMoveFromCombo(_ combo: Combo) -> Move? {
        // combo.comboMoves is Optional<[ComboMove]> — use empty array as fallback.
        // Sort by sequenceIndex to ensure we get the actual first move.
        // .first?.move extracts the Move from the first ComboMove in the sorted array.
        (combo.comboMoves ?? [])
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
            .first?.move
    }

    // -----------------------------------------------------------------------
    // MARK: - Audio Session Configuration
    // -----------------------------------------------------------------------

    /// Configures the audio session for ambient (inline) playback.
    ///
    /// .ambient category: audio mixes with other apps (e.g. Music), respects the
    /// hardware silent switch, and does not interrupt other audio sessions.
    /// This is the polite default for inline video playback — the user can watch
    /// a move clip without their background music stopping.
    ///
    /// The session is first deactivated with .notifyOthersOnDeactivation, which
    /// signals to other apps that they can resume their audio output.
    private func configureAmbientAudio() {
        let session = AVAudioSession.sharedInstance()
        // Deactivate first to let other apps know they can resume.
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        // Set to ambient: mixes with others, silent switch respected.
        try? session.setCategory(.ambient)
        // Re-activate with the new category.
        try? session.setActive(true)
    }

    /// Activates the audio session for fullscreen playback.
    ///
    /// .playback category: audio takes exclusive control, ignores the hardware
    /// silent switch, and interrupts other audio sessions (e.g. Music pauses).
    /// This is what users expect when they explicitly go fullscreen.
    private func activatePlaybackAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Loading Video Placeholder

/// A visible loading placeholder with a pulsing video icon and spinner.
/// Used by CustomVideoPlayerView while the AVPlayer is being initialized.
private struct LoadingVideoPlaceholder: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary.opacity(0.4))
                .scaleEffect(pulse ? 1.08 : 0.95)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

            ProgressView()
                .tint(.accent)
                .scaleEffect(1.1)

            Text("Loading video...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Preview

/// Xcode Preview showing the player with the seeded "Windmill" move.
/// The move has no actual video file, so the error placeholder will be shown.
#Preview("VideoPlayer - Light") {
    CustomVideoPlayerView(move: ModelContainer.previewMove(state: "NEW"))
        .frame(height: 300)
        .padding()
        .modelContainer(.preview)
}

#Preview("VideoPlayer - Dark") {
    CustomVideoPlayerView(move: ModelContainer.previewMove(state: "NEW"))
        .frame(height: 300)
        .padding()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
