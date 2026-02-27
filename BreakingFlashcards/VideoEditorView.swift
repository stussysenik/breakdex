// VideoEditorView.swift — Full-featured video editor for breakdancing clips
//
// This view is the heart of the Breakdex video editing workflow. When a user picks
// or records a video of a breakdancing move, this editor lets them fine-tune it
// before saving. It supports:
//   - Trimming (adjustable start/end points via TrimmerTimelineView handles)
//   - Speed control (0.25x to 2.0x via TrimmerControlsView speed pills)
//   - Rotation (90-degree increments via TrimmerControlsView rotate button)
//   - Aspect ratio cropping (original, 1:1, 4:5, 16:9 via CropOverlayView)
//   - Reverse playback (toggle via TrimmerControlsView reverse button)
//   - Export to .mp4 with progress feedback (via VideoCompositionPipeline)
//
// ARCHITECTURE ROLE:
//   This is a modal screen presented by AddMoveView after video selection.
//   It receives a raw AVAsset and a completion handler. On export, it calls
//   VideoCompositionPipeline.export() to produce a trimmed/transformed .mp4,
//   then passes the output URL back to the caller via onComplete(url).
//   Passing nil to onComplete signals the user tapped "Back" (cancelled).
//
// LAYOUT STRATEGY:
//   The view adapts to both portrait and landscape orientations using
//   LayoutMetrics (LayoutMetrics.swift). In portrait, everything stacks
//   vertically. In landscape, the video sits on the left (60%) and controls
//   on the right (40%). LayoutMetrics computes responsive values based on
//   the device class (SE, standard, Pro Max, iPad, etc.).
//
// STATE MANAGEMENT:
//   All editing parameters live in a single VideoEditParameters struct
//   (defined in VideoCompositionPipeline.swift): startTime, endTime,
//   playbackRate, isReversed, rotation, aspectRatio, cropOffset.
//   The trim positions are tracked as 0...1 fractions for the UI, then
//   converted to CMTime values before export.
//
// CHILD VIEWS:
//   - CustomVideoPlayerView: Renders the AVPlayer video preview
//   - TrimmerTimelineView: Thumbnail strip with draggable start/end handles
//   - TrimmerPlayheadView: Draggable playhead indicator overlaid on timeline
//   - TrimmerControlsView: Speed pills + transform buttons (reverse, rotate, aspect)
//   - CropOverlayView: Draggable crop region shown over the video when aspect != original
//
// CONNECTED FILES:
//   - VideoCompositionPipeline.swift: Static export() method does the actual rendering
//   - AdaptiveThumbnailGenerator.swift: Generates timeline thumbnail images from the asset
//   - LayoutMetrics.swift: Responsive layout calculations based on screen geometry
//   - HapticEngine.swift: Tactile feedback for playback toggle, export complete, errors
//   - Motion.swift: AppMotion animation presets used for aspect ratio changes, rotation
//   - DesignSystem.swift: Color tokens (backgroundPrimary, accent, textPrimary, etc.),
//     Font.ibmPlexMono, Spacing tokens (xs, sm, md, lg), Radius tokens (md)

import SwiftUI
import AVFoundation

// MARK: - VideoEditorView

/// The main video editor view. Receives an AVAsset to edit and a completion
/// closure that is called with either the exported URL (success) or nil (cancelled).
struct VideoEditorView: View {

    // -----------------------------------------------------------------------
    // MARK: - Injected Dependencies
    // -----------------------------------------------------------------------

    /// The raw video asset loaded from the user's photo library or camera.
    /// This is the source material for all editing operations. It is immutable —
    /// the original file is never modified. Export creates a new .mp4 file.
    let asset: AVAsset

    /// Completion handler called when the editor is dismissed.
    /// - Receives a URL to the exported .mp4 on success.
    /// - Receives nil if the user taps "Back" to cancel without saving.
    let onComplete: (URL?) -> Void

    // -----------------------------------------------------------------------
    // MARK: - State Properties
    // -----------------------------------------------------------------------

    /// The AVPlayer instance used for video preview playback.
    /// Initialized in init() with an AVPlayerItem wrapping the source asset.
    /// The player is controlled by tap-to-play/pause and responds to speed/reverse changes.
    @State private var player: AVPlayer

    /// Total duration of the source video in seconds.
    /// Loaded asynchronously in setup() via asset.load(.duration).
    /// Used to convert fraction-based UI positions (0...1) to absolute CMTime values.
    @State private var duration: TimeInterval = 0

    /// Aggregated editing parameters that get passed to VideoCompositionPipeline.export().
    /// Includes: startTime, endTime, playbackRate, isReversed, rotation, aspectRatio, cropOffset.
    /// TrimmerControlsView binds directly to this via $params for speed/transform changes.
    @State private var params = VideoEditParameters()

    /// Normalized start position of the trim range (0.0 = beginning of video).
    /// Controlled by the left trim handle in TrimmerTimelineView.
    /// Converted to CMTime (startFraction * duration) before export.
    @State private var startFraction: CGFloat = 0

    /// Normalized end position of the trim range (1.0 = end of video).
    /// Controlled by the right trim handle in TrimmerTimelineView.
    /// Converted to CMTime (endFraction * duration) before export.
    @State private var endFraction: CGFloat = 1

    /// Current playback position as a fraction of total duration (0.0 to 1.0).
    /// Updated by the periodic time observer at 20Hz (every 0.05 seconds).
    /// Also updated by TrimmerPlayheadView when the user drags the playhead.
    @State private var playheadFraction: CGFloat = 0

    /// Whether the video is currently playing.
    /// Toggled by tapping the video preview area.
    /// When true, the player's rate is set to the current playbackRate (with sign for reverse).
    @State private var isPlaying = false

    /// Whether an export operation is currently in progress.
    /// When true, the "Save" button is replaced with a progress bar.
    @State private var isExporting = false

    /// Export progress from 0.0 to 1.0, updated by VideoCompositionPipeline's progress callback.
    /// Drives the visual progress bar shown during export.
    @State private var exportProgress: Float = 0

    /// Human-readable error message if the export fails.
    /// Displayed below the Save button in .buttonAgain (red) color.
    @State private var exportError: String?

    /// Reference to the AVPlayer's periodic time observer.
    /// Stored so it can be removed in cleanup() to avoid retain cycles.
    /// The observer fires every 0.05 seconds to update playheadFraction.
    @State private var timeObserver: Any?

    /// Cached LayoutMetrics from the most recent GeometryReader pass.
    /// Used by setup() to determine thumbnail count when the GeometryReader
    /// hasn't yet provided metrics (falls back to iPhone 14 Pro dimensions).
    @State private var currentMetrics: LayoutMetrics?

    /// The natural aspect ratio (width/height) of the source video.
    /// Loaded from the video track's naturalSize + preferredTransform in setup().
    /// Defaults to 16:9 as a fallback. Used by the video preview to maintain
    /// correct proportions and by CropOverlayView to calculate crop geometry.
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    /// Current zoom scale applied to the video preview via pinch-to-zoom gesture.
    /// 1.0 = no zoom (full frame). Values > 1.0 zoom in to fine-tune crop position.
    /// Clamped to 1.0...3.0 to prevent excessive zoom.
    @State private var zoomScale: CGFloat = 1.0

    /// Tracks the in-progress magnification gesture value, combined with the
    /// committed zoomScale for smooth interactive zooming.
    @State private var gestureZoomScale: CGFloat = 1.0

    /// Generates thumbnail images from the source video for the timeline strip.
    /// Uses a tiered strategy: fewer thumbnails for short videos, more for long ones.
    /// Initialized in init() with the source asset; configured in setup() with count.
    @State private var thumbnailGenerator: AdaptiveThumbnailGenerator

    // -----------------------------------------------------------------------
    // MARK: - Initializer
    // -----------------------------------------------------------------------

    /// Creates a VideoEditorView for the given asset.
    ///
    /// - Parameters:
    ///   - asset: The source AVAsset to edit. Must contain at least one video track.
    ///   - onComplete: Called with the exported URL on save, or nil on cancel.
    ///
    /// Both the AVPlayer and AdaptiveThumbnailGenerator are initialized here because
    /// @State properties must be set before the view body is first evaluated.
    /// We use `State(initialValue:)` to wrap them since they can't be assigned directly.
    init(asset: AVAsset, onComplete: @escaping (URL?) -> Void) {
        self.asset = asset
        self.onComplete = onComplete
        // Create an AVPlayer with an AVPlayerItem wrapping the source asset.
        // AVPlayerItem bridges AVAsset (the media container) to AVPlayer (the playback engine).
        self._player = State(initialValue: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
        // Create the thumbnail generator, which wraps AVAssetImageGenerator internally.
        // Actual thumbnail generation starts in setup() after duration is known.
        self._thumbnailGenerator = State(initialValue: AdaptiveThumbnailGenerator(asset: asset))
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// The root view uses a GeometryReader to obtain screen dimensions, then
    /// delegates to either portraitLayout or landscapeLayout based on aspect ratio.
    /// The GeometryReader provides a GeometryProxy that LayoutMetrics wraps to
    /// compute device-specific values (video height, padding, timeline dimensions).
    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics(geometry: geometry)

            Group {
                if metrics.isLandscape {
                    landscapeLayout(metrics: metrics)
                } else {
                    portraitLayout(metrics: metrics)
                }
            }
            // Cache metrics once here instead of duplicating in both layouts.
            .onAppear { currentMetrics = metrics }
            .onChange(of: metrics.screenWidth) { _, _ in currentMetrics = metrics }
        }
        // backgroundPrimary: near-white (#f8f9fb) in light mode, near-black (#0b0c0e) in dark mode.
        // This covers the entire editor background behind the video and controls.
        .background(Color.backgroundPrimary)
        // setup() runs once when the view appears: loads duration, video size,
        // configures thumbnail generation, and starts the periodic time observer.
        .onAppear(perform: setup)
        // cleanup() runs when the view disappears: removes the time observer,
        // cancels thumbnail generation, pauses and releases the player.
        .onDisappear(perform: cleanup)
    }

    // -----------------------------------------------------------------------
    // MARK: - Portrait Layout
    // -----------------------------------------------------------------------

    /// Vertical stack layout used when the device is in portrait orientation.
    /// Top to bottom: Back button, video preview, time display, timeline with
    /// playhead, trim controls, spacer, save button.
    ///
    /// Spacing.md (16pt) separates each major section, matching the 4pt grid system.
    @ViewBuilder
    private func portraitLayout(metrics: LayoutMetrics) -> some View {
        VStack(spacing: Spacing.md) {
            // -- Navigation: back button aligned to the leading edge --
            backButton
                // horizontalPadding is device-responsive: 16pt on SE, 20pt on standard/ProMax,
                // up to 40pt on iPad Pro. Keeps content away from screen edges.
                .padding(.horizontal, metrics.horizontalPadding)

            // Top spacer — aligns with the 8-column grid. Uses the column gutter width
            // (screenWidth / 8) as the minimum height to maintain consistent vertical rhythm.
            Spacer()
                .frame(height: metrics.screenWidth / 8 * 0.5)

            // -- Video preview: shows the asset with crop overlay if needed --
            // videoPlayerHeight uses the golden ratio: screenWidth / 1.618 in portrait.
            videoPreview(metrics: metrics)
                .frame(height: metrics.videoPlayerHeight)

            // -- Time display: shows start time, current playhead time, end time --
            timeDisplay

            // -- Timeline: thumbnail strip with trim handles + playhead overlay --
            // ZStack layers the TrimmerPlayheadView on top of TrimmerTimelineView
            // so the playhead line draws over the thumbnail strip.
            ZStack {
                // TrimmerTimelineView: renders the thumbnail strip with draggable
                // start/end handles. Binds to startFraction/endFraction so handle
                // drags update the trim range. onScrub callback seeks the player.
                TrimmerTimelineView(
                    metrics: metrics,
                    thumbnailGenerator: thumbnailGenerator,
                    duration: duration,
                    startFraction: $startFraction,
                    endFraction: $endFraction,
                    onScrub: seekTo
                )

                // TrimmerPlayheadView: renders a vertical white line with a grab
                // circle that the user can drag to scrub through the video.
                // Binds to playheadFraction for two-way updates (auto-advance + drag).
                TrimmerPlayheadView(
                    metrics: metrics,
                    duration: duration,
                    startFraction: startFraction,
                    endFraction: endFraction,
                    currentFraction: $playheadFraction,
                    onScrub: seekTo
                )
            }
            .padding(.horizontal, metrics.horizontalPadding)

            // -- Trim controls: speed pills + transform buttons (reverse, rotate, aspect) --
            // TrimmerControlsView binds to $params so button taps directly update
            // playbackRate, isReversed, rotation, and aspectRatio.
            TrimmerControlsView(params: $params)

            // Push the save button to the bottom of the screen.
            Spacer()

            // -- Action button: "Save" or export progress bar --
            actionButton(metrics: metrics)
                .padding(.horizontal, metrics.horizontalPadding)

            // Bottom spacer — mirrors the top spacer for balanced vertical padding.
            Spacer()
                .frame(height: metrics.screenWidth / 8 * 0.5)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Landscape Layout
    // -----------------------------------------------------------------------

    /// Horizontal split layout used when the device is in landscape orientation.
    /// Left side (60%): back button + video preview.
    /// Right side (40%): time display, timeline, controls, save button.
    ///
    /// The split proportions come from LayoutMetrics.landscapeVideoFraction (0.6)
    /// and LayoutMetrics.landscapeControlsFraction (0.4).
    @ViewBuilder
    private func landscapeLayout(metrics: LayoutMetrics) -> some View {
        HStack(spacing: 0) {
            // -- Left panel: video preview with back button above it --
            VStack {
                backButton
                    .padding(.horizontal, Spacing.md)
                videoPreview(metrics: metrics)
            }
            // 60% of screen width for the video in landscape.
            .frame(width: metrics.screenWidth * metrics.landscapeVideoFraction)

            // -- Right panel: controls stack --
            VStack(spacing: Spacing.md) {
                timeDisplay

                // In landscape, the timeline needs narrower metrics because it only
                // occupies the right 40% panel. We create a new LayoutMetrics with
                // the panel width minus horizontal padding to get correct timelineWidth.
                ZStack {
                    TrimmerTimelineView(
                        metrics: LayoutMetrics(
                            width: metrics.screenWidth * metrics.landscapeControlsFraction - metrics.horizontalPadding * 2,
                            height: metrics.screenHeight
                        ),
                        thumbnailGenerator: thumbnailGenerator,
                        duration: duration,
                        startFraction: $startFraction,
                        endFraction: $endFraction,
                        onScrub: seekTo
                    )

                    TrimmerPlayheadView(
                        metrics: LayoutMetrics(
                            width: metrics.screenWidth * metrics.landscapeControlsFraction - metrics.horizontalPadding * 2,
                            height: metrics.screenHeight
                        ),
                        duration: duration,
                        startFraction: startFraction,
                        endFraction: endFraction,
                        currentFraction: $playheadFraction,
                        onScrub: seekTo
                    )
                }
                .padding(.horizontal, Spacing.md)

                TrimmerControlsView(params: $params)

                Spacer()

                actionButton(metrics: metrics)
                    .padding(.horizontal, Spacing.md)
                    // Spacing.sm (8pt) bottom padding in landscape — less than portrait
                    // because landscape has tighter vertical space.
                    .padding(.bottom, Spacing.sm)
            }
            // 40% of screen width for controls in landscape.
            .frame(width: metrics.screenWidth * metrics.landscapeControlsFraction)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Back Button
    // -----------------------------------------------------------------------

    /// Navigation button to cancel editing and return to the previous screen.
    /// Calls onComplete(nil) to signal cancellation — no video is exported.
    /// Styled with the app's accent color and IBM Plex Mono font.
    private var backButton: some View {
        HStack {
            Button {
                // Pass nil to indicate the user cancelled without saving.
                onComplete(nil)
            } label: {
                HStack(spacing: Spacing.xs) {
                    // SF Symbol chevron for the back arrow.
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    // "Back" label in IBM Plex Mono — the app's monospace font.
                    Text("Back")
                        .font(.ibmPlexMono(size: 18, weight: .medium))
                }
                // .accent is the brand blue (#2362a2) used for all interactive elements.
                .foregroundColor(.accent)
            }
            // Spacer pushes the button to the leading edge.
            Spacer()
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Video Preview
    // -----------------------------------------------------------------------

    /// Renders the video player with optional crop overlay, rotation, and aspect ratio.
    /// The preview reflects all current editing parameters in real-time:
    ///   - Aspect ratio: when not .original, shows the full frame with a CropOverlayView
    ///     that dims the excluded region and lets the user drag the crop position.
    ///   - Rotation: applies a rotationEffect in 90-degree increments.
    ///   - Speed/Reverse: onChange handlers update the player's rate in real-time.
    ///   - Tap to play/pause: onTapGesture toggles playback.
    ///
    /// Uses CustomVideoPlayerView with autoPlay: false because playback is controlled
    /// by the editor (tap-to-play) rather than auto-starting.
    @ViewBuilder
    private func videoPreview(metrics: LayoutMetrics) -> some View {
        Group {
            if params.aspectRatio != .original, let targetRatio = params.aspectRatio.ratio {
                // CROP MODE: aspect ratio is not original (e.g. 1:1, 4:5, 16:9).
                // Show the full video frame with the crop overlay on top.
                // The crop overlay dims the excluded region and provides a drag handle.
                CustomVideoPlayerView(player: player, autoPlay: false)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    // Lock to the video's natural aspect ratio so the frame isn't distorted.
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .overlay {
                        // CropOverlayView draws a bright rectangle for the crop region
                        // and dims everything outside it. The user can drag to reposition.
                        // cropOffset is a normalized CGPoint (0...1) where 0.5 = centered.
                        CropOverlayView(
                            sourceAspectRatio: videoAspectRatio,
                            targetAspectRatio: targetRatio,
                            cropOffset: $params.cropOffset
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
            } else {
                // ORIGINAL MODE: no crop overlay. The video displays at its natural
                // aspect ratio (or the selected ratio if it happens to match original).
                CustomVideoPlayerView(player: player, autoPlay: false)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    // params.aspectRatio.ratio is nil for .original, so this uses
                    // the view's intrinsic size (no forced aspect ratio).
                    .aspectRatio(params.aspectRatio.ratio, contentMode: .fit)
            }
        }
        // Animate aspect ratio changes with springQuick (response: 0.2, damping: 0.75).
        // This gives a snappy feel when switching between 1:1, 4:5, 16:9, etc.
        .animation(AppMotion.springQuick, value: params.aspectRatio)
        .padding(.horizontal, metrics.horizontalPadding)
        // Apply rotation as a visual transform. The raw value is degrees (0, 90, 180, 270).
        // This is a display-only rotation — the actual video rotation is applied during export.
        .rotationEffect(.degrees(Double(params.rotation.rawValue)))
        // Animate rotation with rotationSnap (response: 0.35, damping: 0.6).
        // Low damping creates a satisfying overshoot/bounce effect on each 90-degree snap.
        .animation(AppMotion.rotationSnap, value: params.rotation)
        // Pinch-to-zoom: lets the user zoom into the video to fine-tune crop framing.
        // The scale is clamped between 1.0 (original) and 3.0 (3x zoom).
        .scaleEffect(zoomScale * gestureZoomScale)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    gestureZoomScale = value
                }
                .onEnded { value in
                    zoomScale = min(max(zoomScale * value, 1.0), 3.0)
                    gestureZoomScale = 1.0
                }
        )
        // Double-tap to reset zoom back to 1x (must be before single-tap for priority).
        .onTapGesture(count: 2) {
            withAnimation(AppMotion.springQuick) {
                zoomScale = 1.0
            }
        }
        // Tap anywhere on the video to toggle play/pause.
        .onTapGesture {
            togglePlayback()
        }
        // When playback rate changes (user tapped a speed pill), start playing
        // at the new speed for live preview. This gives instant feedback when
        // the user taps a speed pill — no need to tap play first.
        .onChange(of: params.playbackRate) { _, newRate in
            let rate = params.isReversed ? -newRate : newRate
            player.rate = rate
            if !isPlaying { isPlaying = true }
        }
        // When reverse toggle changes, flip the player's rate sign.
        .onChange(of: params.isReversed) { _, reversed in
            if isPlaying {
                player.rate = reversed ? -params.playbackRate : params.playbackRate
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Time Display
    // -----------------------------------------------------------------------

    /// Shows three timecodes with a centered play/pause button:
    ///   Left: trim start time (textSecondary — muted)
    ///   Center: play/pause button + current playhead time (textPrimary — bold)
    ///   Right: trim end time (textSecondary — muted)
    ///
    /// The play/pause button provides clear visual affordance for toggling playback.
    /// Previously, playback could only be toggled by tapping the video preview (no
    /// visual indicator). This button makes the control discoverable.
    ///
    /// Times are formatted as MM:SS.CC (minutes, seconds, centiseconds) by formatTimecode().
    /// The display updates at 20Hz as the playhead fraction changes.
    private var timeDisplay: some View {
        HStack {
            // Start time: where the trim begins, shown in muted secondary color.
            Text(formatTimecode(seconds: Double(startFraction) * duration))
                .font(.ibmPlexMono(size: 18))
                .foregroundColor(.textSecondary)

            Spacer()

            // Center: play/pause button + current playhead time
            HStack(spacing: Spacing.sm) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(formatTimecode(seconds: Double(playheadFraction) * duration))
                    .font(.ibmPlexMono(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // End time: where the trim ends, shown in muted secondary color.
            Text(formatTimecode(seconds: Double(endFraction) * duration))
                .font(.ibmPlexMono(size: 18))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // -----------------------------------------------------------------------
    // MARK: - Action Button (Save / Export Progress)
    // -----------------------------------------------------------------------

    /// Conditionally shows either:
    ///   - A progress bar with percentage during export (isExporting == true)
    ///   - A "Save" button that triggers the export pipeline (isExporting == false)
    ///   - An error message below the Save button if the last export failed
    @ViewBuilder
    private func actionButton(metrics: LayoutMetrics) -> some View {
        if isExporting {
            // -- Export in progress: show a linear progress bar with percentage text --
            VStack(spacing: Spacing.sm) {
                // SwiftUI ProgressView with a linear style, tinted with the accent color.
                ProgressView(value: Double(exportProgress))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accent))
                    .frame(height: 6)
                    // Capsule clip gives the progress bar rounded ends.
                    .clipShape(Capsule())
                    // exportProgress animates with AppMotion.exportProgress (linear, 0.2s).
                    // Linear animation matches the actual export progress without easing distortion.
                    .animation(AppMotion.exportProgress, value: exportProgress)

                // Percentage text: "Exporting 42%"
                Text("Exporting \(Int(exportProgress * 100))%")
                    .font(.ibmPlexMono(size: 15))
                    .foregroundColor(.textSecondary)
            }
            // Match the same 50pt height as the Save button for layout consistency.
            .frame(height: 50)
        } else {
            // -- Save button: triggers the export pipeline --
            Button {
                exportVideo()
            } label: {
                Text("Save")
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    // Uppercase "SAVE" for visual emphasis.
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    // Full-width button.
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    // Accent blue (#2362a2) background.
                    .background(Color.accent)
                    // Radius.md (12pt) rounded corners.
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            // Accessibility identifier for UI testing — allows XCTest to find this button.
            .accessibilityIdentifier("ExportButton")

            // Error message displayed below the button if the previous export failed.
            if let error = exportError {
                Text(error)
                    .font(.ibmPlexMono(size: 15))
                    // .buttonAgain is the red color (#da1e28) used for error/negative states.
                    .foregroundColor(.buttonAgain)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Setup
    // -----------------------------------------------------------------------

    /// Called once when the view appears. Performs four initialization tasks:
    ///
    /// 1. Prepares the HapticEngine singleton (warms up the Taptic Engine hardware).
    /// 2. Loads the video duration and natural aspect ratio asynchronously.
    /// 3. Configures the thumbnail generator with the correct count for the device.
    /// 4. Installs a periodic time observer on the player to track playhead position.
    private func setup() {
        // Warm up the Taptic Engine so the first haptic has zero latency.
        // HapticEngine.shared.prepare() calls .prepare() on all three feedback generators:
        // UIImpactFeedbackGenerator, UISelectionFeedbackGenerator, UINotificationFeedbackGenerator.
        HapticEngine.shared.prepare()

        // Start with the player paused — the user controls playback via tap-to-play.
        player.pause()

        // Safety: remove any existing time observer to prevent double-registration.
        // This handles edge cases like the view reappearing after a background cycle.
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // --- Async work: load video metadata ---
        Task {
            // Load the video's total duration from the AVAsset.
            // CMTime is Core Media's timestamp type (value/timescale fraction).
            // .seconds converts it to a Double for easier math.
            let cmDuration = try? await asset.load(.duration)
            let dur = cmDuration?.seconds ?? 0
            await MainActor.run {
                duration = dur
                // Set the initial trim range to the full video.
                params.endTime = cmDuration ?? .zero
                params.startTime = .zero
            }

            // Load the video track's natural size to compute the aspect ratio.
            // Videos can be rotated by their preferredTransform (e.g. portrait videos
            // shot on iPhone have a 90-degree transform). We apply the transform
            // to the natural size to get the display dimensions.
            if let videoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                let naturalSize = try? await videoTrack.load(.naturalSize)
                let preferredTransform = try? await videoTrack.load(.preferredTransform)
                if let size = naturalSize {
                    // Apply the transform to account for rotation metadata.
                    // A portrait video might have naturalSize 1920x1080 but a 90-degree transform,
                    // which makes the effective display size 1080x1920.
                    let transformed = preferredTransform.map { size.applying($0) } ?? size
                    let ratio = abs(transformed.width) / abs(transformed.height)
                    await MainActor.run {
                        // Only update if the ratio is sane (finite and positive).
                        if ratio.isFinite && ratio > 0 {
                            videoAspectRatio = ratio
                        }
                    }
                }
            }

            // Configure the thumbnail generator with the appropriate count.
            // thumbnailCount(for:) uses a tiered strategy:
            //   - Short (<120s): min 8, max 40, roughly 1 per 3 seconds
            //   - Medium (120-600s): min 20, max 60, roughly 1 per 10 seconds
            //   - Long (>600s): min 30, max 80, roughly 1 per 20 seconds
            // Also capped by available width (maxByWidth) so thumbnails don't get too thin.
            let metrics = currentMetrics ?? LayoutMetrics(width: 390, height: 844)
            let count = metrics.thumbnailCount(for: dur)
            await MainActor.run {
                // configure() sets up the thumbnail generator's internal state and
                // starts generating images for the visible range.
                thumbnailGenerator.configure(duration: dur, count: count)
            }
        }

        // --- Periodic time observer for playhead tracking ---
        // Fires every 0.05 seconds (20Hz) on the main queue.
        // preferredTimescale: 600 is the standard for video (supports 24/30/60fps evenly).
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            // Don't update if duration hasn't been loaded yet.
            guard duration > 0 else { return }
            // Convert the absolute time to a 0...1 fraction.
            let fraction = CGFloat(time.seconds / duration)
            playheadFraction = fraction

            // Loop: when playback reaches the end trim point, jump back to the start.
            // This creates a seamless preview loop within the selected trim range.
            if fraction >= endFraction {
                let startTime = CMTime(seconds: Double(startFraction) * duration, preferredTimescale: 600)
                // toleranceBefore/After: .zero ensures frame-accurate seeking (no approximation).
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Cleanup
    // -----------------------------------------------------------------------

    /// Called when the view disappears. Releases all resources:
    /// 1. Removes the periodic time observer to break the retain cycle.
    /// 2. Cancels any in-flight thumbnail generation.
    /// 3. Pauses the player and removes its current item.
    private func cleanup() {
        // Remove the periodic time observer. AVPlayer retains the observer,
        // and the observer closure captures `self`, so this breaks the cycle.
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        // Cancel all pending thumbnail generation tasks.
        thumbnailGenerator.cancelAll()
        // Fully stop and release the player.
        player.pause()
        // replaceCurrentItem(with: nil) releases the AVPlayerItem, which releases the
        // decoded video buffers. Important for memory — decoded video frames are large.
        player.replaceCurrentItem(with: nil)
    }

    // -----------------------------------------------------------------------
    // MARK: - Playback Control
    // -----------------------------------------------------------------------

    /// Toggles between play and pause. Handles both forward and reverse playback.
    /// Fires a playbackToggle haptic (UIImpactFeedbackGenerator.light) on every toggle.
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            // Set the player's rate, using a negative value for reverse playback.
            // AVPlayer supports negative rates for reverse playback when the asset allows it.
            player.rate = params.isReversed ? -params.playbackRate : params.playbackRate
        }
        isPlaying.toggle()
        // Fire a light haptic tap to confirm the play/pause action.
        HapticEngine.shared.playbackToggle()
    }

    // -----------------------------------------------------------------------
    // MARK: - Seeking
    // -----------------------------------------------------------------------

    /// Seeks the player to an exact time. Called by TrimmerTimelineView (when handles
    /// are dragged) and TrimmerPlayheadView (when the playhead is dragged).
    ///
    /// - Parameter time: The target CMTime to seek to.
    ///
    /// Uses zero tolerance for frame-accurate seeking. Also updates playheadFraction
    /// so the playhead UI stays in sync without waiting for the time observer.
    private func seekTo(time: CMTime) {
        // toleranceBefore/toleranceAfter: .zero forces exact-frame seeking.
        // Without this, AVPlayer may seek to the nearest keyframe (faster but imprecise).
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        if duration > 0 {
            playheadFraction = CGFloat(time.seconds / duration)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Export
    // -----------------------------------------------------------------------

    /// Initiates the video export pipeline. This method:
    /// 1. Sets the isExporting flag to show the progress UI.
    /// 2. Converts the UI fraction-based trim positions to CMTime values.
    /// 3. Creates a unique output URL in the Documents directory.
    /// 4. Calls VideoCompositionPipeline.export() asynchronously.
    /// 5. On success: fires exportComplete haptic and passes the URL to onComplete.
    /// 6. On failure: fires error haptic and displays the error message.
    private func exportVideo() {
        // Switch to export mode — replaces the Save button with a progress bar.
        isExporting = true
        exportProgress = 0
        exportError = nil

        // Convert the 0...1 fractions to absolute CMTime values for the pipeline.
        // preferredTimescale: 600 gives sub-frame precision for standard video frame rates.
        params.startTime = CMTime(seconds: Double(startFraction) * duration, preferredTimescale: 600)
        params.endTime = CMTime(seconds: Double(endFraction) * duration, preferredTimescale: 600)

        // Create a unique output path: Documents/{UUID}.mp4
        // UUID ensures no filename collisions, even if the user exports multiple times.
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        Task {
            do {
                // VideoCompositionPipeline.export() is a static async method that:
                //   1. Creates an AVMutableComposition with time-scaled (speed) tracks
                //   2. Builds an AVMutableVideoComposition with rotation/crop transforms
                //   3. Uses AVAssetExportSession to render the final .mp4
                // The progress closure fires periodically with a 0.0...1.0 Float.
                let url = try await VideoCompositionPipeline.export(
                    asset: asset,
                    with: params,
                    outputURL: outputURL
                ) { progress in
                    exportProgress = progress
                }
                await MainActor.run {
                    isExporting = false
                    // Fire a success haptic (UINotificationFeedbackGenerator .success pattern).
                    HapticEngine.shared.exportComplete()
                    // Return the exported URL to the caller (AddMoveView), which will
                    // save it as the Move's videoReference in SwiftData.
                    onComplete(url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    // Show the error message below the Save button.
                    exportError = error.localizedDescription
                    // Fire an error haptic (UINotificationFeedbackGenerator .error pattern).
                    HapticEngine.shared.error()
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Timecode Formatting
    // -----------------------------------------------------------------------

    /// Converts a time in seconds to a formatted timecode string: "MM:SS.CC"
    /// (minutes, seconds, centiseconds — hundredths of a second).
    ///
    /// - Parameter seconds: The time value to format.
    /// - Returns: A zero-padded string like "01:23.45" or "00:00.00" for invalid input.
    ///
    /// Centisecond precision is more useful than milliseconds for video editing at
    /// standard frame rates (24/30/60fps). It also keeps the display compact.
    private func formatTimecode(seconds: Double) -> String {
        // Guard against NaN, infinity, and negative values.
        guard seconds.isFinite, seconds >= 0 else { return "00:00.00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        // truncatingRemainder extracts the fractional part, * 100 gives centiseconds.
        let centis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }
}

// MARK: - Preview

#Preview("VideoEditor - Light") {
    VideoEditorView(
        asset: AVAsset(url: URL(string: "file:///dev/null")!),
        onComplete: { _ in }
    )
}

#Preview("VideoEditor - Dark") {
    VideoEditorView(
        asset: AVAsset(url: URL(string: "file:///dev/null")!),
        onComplete: { _ in }
    )
    .preferredColorScheme(.dark)
}
