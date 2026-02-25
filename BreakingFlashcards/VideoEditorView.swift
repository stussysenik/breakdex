import SwiftUI
import AVFoundation

struct VideoEditorView: View {
    let asset: AVAsset
    let onComplete: (URL?) -> Void

    @State private var player: AVPlayer
    @State private var duration: TimeInterval = 0
    @State private var params = VideoEditParameters()
    @State private var startFraction: CGFloat = 0
    @State private var endFraction: CGFloat = 1
    @State private var playheadFraction: CGFloat = 0
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var exportProgress: Float = 0
    @State private var exportError: String?
    @State private var timeObserver: Any?
    @State private var currentMetrics: LayoutMetrics?

    @State private var thumbnailGenerator: AdaptiveThumbnailGenerator

    init(asset: AVAsset, onComplete: @escaping (URL?) -> Void) {
        self.asset = asset
        self.onComplete = onComplete
        self._player = State(initialValue: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
        self._thumbnailGenerator = State(initialValue: AdaptiveThumbnailGenerator(asset: asset))
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics(geometry: geometry)

            if metrics.isLandscape {
                landscapeLayout(metrics: metrics)
            } else {
                portraitLayout(metrics: metrics)
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }

    // MARK: - Portrait Layout

    @ViewBuilder
    private func portraitLayout(metrics: LayoutMetrics) -> some View {
        VStack(spacing: Spacing.md) {
            // Back button
            backButton
                .padding(.horizontal, metrics.horizontalPadding)

            // Video preview
            videoPreview(metrics: metrics)
                .frame(height: metrics.videoPlayerHeight)

            // Time display
            timeDisplay

            // Timeline
            ZStack {
                TrimmerTimelineView(
                    metrics: metrics,
                    thumbnailGenerator: thumbnailGenerator,
                    duration: duration,
                    startFraction: $startFraction,
                    endFraction: $endFraction,
                    onScrub: seekTo
                )

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

            // Controls
            TrimmerControlsView(params: $params)

            Spacer()

            // Save button / export progress
            actionButton(metrics: metrics)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.bottom, Spacing.md)
        }
        .onAppear { currentMetrics = metrics }
        .onChange(of: metrics.screenWidth) { _, _ in currentMetrics = metrics }
    }

    // MARK: - Landscape Layout

    @ViewBuilder
    private func landscapeLayout(metrics: LayoutMetrics) -> some View {
        HStack(spacing: 0) {
            // Left: video preview
            VStack {
                backButton
                    .padding(.horizontal, Spacing.md)
                videoPreview(metrics: metrics)
            }
            .frame(width: metrics.screenWidth * metrics.landscapeVideoFraction)

            // Right: controls stack
            VStack(spacing: Spacing.md) {
                timeDisplay

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
                    .padding(.bottom, Spacing.sm)
            }
            .frame(width: metrics.screenWidth * metrics.landscapeControlsFraction)
        }
        .onAppear { currentMetrics = metrics }
        .onChange(of: metrics.screenWidth) { _, _ in currentMetrics = metrics }
    }

    // MARK: - Back Button

    private var backButton: some View {
        HStack {
            Button {
                onComplete(nil)
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                        .font(.ibmPlexMono(size: 18, weight: .medium))
                }
                .foregroundColor(.accent)
            }
            Spacer()
        }
    }

    // MARK: - Video Preview

    @ViewBuilder
    private func videoPreview(metrics: LayoutMetrics) -> some View {
        CustomVideoPlayerView(player: player)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .aspectRatio(params.aspectRatio.ratio, contentMode: .fit)
            .animation(AppMotion.springQuick, value: params.aspectRatio)
            .padding(.horizontal, metrics.horizontalPadding)
            .rotationEffect(.degrees(Double(params.rotation.rawValue)))
            .animation(AppMotion.rotationSnap, value: params.rotation)
            .onTapGesture {
                togglePlayback()
            }
            .onChange(of: params.playbackRate) { _, newRate in
                if isPlaying {
                    player.rate = params.isReversed ? -newRate : newRate
                }
            }
            .onChange(of: params.isReversed) { _, reversed in
                if isPlaying {
                    player.rate = reversed ? -params.playbackRate : params.playbackRate
                }
            }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack {
            Text(formatTimecode(seconds: Double(startFraction) * duration))
                .font(.ibmPlexMono(size: 18))
                .foregroundColor(.textSecondary)

            Spacer()

            Text(formatTimecode(seconds: Double(playheadFraction) * duration))
                .font(.ibmPlexMono(size: 18, weight: .medium))
                .foregroundColor(.textPrimary)

            Spacer()

            Text(formatTimecode(seconds: Double(endFraction) * duration))
                .font(.ibmPlexMono(size: 18))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(metrics: LayoutMetrics) -> some View {
        if isExporting {
            VStack(spacing: Spacing.sm) {
                ProgressView(value: Double(exportProgress))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accent))
                    .frame(height: 6)
                    .clipShape(Capsule())
                    .animation(AppMotion.exportProgress, value: exportProgress)

                Text("Exporting \(Int(exportProgress * 100))%")
                    .font(.ibmPlexMono(size: 15))
                    .foregroundColor(.textSecondary)
            }
            .frame(height: 50)
        } else {
            Button {
                exportVideo()
            } label: {
                Text("Save")
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }

            if let error = exportError {
                Text(error)
                    .font(.ibmPlexMono(size: 15))
                    .foregroundColor(.buttonAgain)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    // MARK: - Actions

    private func setup() {
        HapticEngine.shared.prepare()

        // Pause initially — user controls playback via tap
        player.pause()

        // Remove any existing observer to avoid double-add
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        Task {
            let cmDuration = try? await asset.load(.duration)
            let dur = cmDuration?.seconds ?? 0
            await MainActor.run {
                duration = dur
                params.endTime = cmDuration ?? .zero
                params.startTime = .zero
            }

            let metrics = currentMetrics ?? LayoutMetrics(width: 390, height: 844)
            let count = metrics.thumbnailCount(for: dur)
            await MainActor.run {
                thumbnailGenerator.configure(duration: dur, count: count)
            }
        }

        // Periodic time observer for playhead
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard duration > 0 else { return }
            let fraction = CGFloat(time.seconds / duration)
            playheadFraction = fraction

            // Loop within trim range
            if fraction >= endFraction {
                let startTime = CMTime(seconds: Double(startFraction) * duration, preferredTimescale: 600)
                player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }

    private func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        thumbnailGenerator.cancelAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.rate = params.isReversed ? -params.playbackRate : params.playbackRate
        }
        isPlaying.toggle()
        HapticEngine.shared.playbackToggle()
    }

    private func seekTo(time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func exportVideo() {
        isExporting = true
        exportProgress = 0
        exportError = nil

        // Update params with current trim positions
        params.startTime = CMTime(seconds: Double(startFraction) * duration, preferredTimescale: 600)
        params.endTime = CMTime(seconds: Double(endFraction) * duration, preferredTimescale: 600)

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        Task {
            do {
                let url = try await VideoCompositionPipeline.export(
                    asset: asset,
                    with: params,
                    outputURL: outputURL
                ) { progress in
                    exportProgress = progress
                }
                await MainActor.run {
                    isExporting = false
                    HapticEngine.shared.exportComplete()
                    onComplete(url)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                    HapticEngine.shared.error()
                }
            }
        }
    }

    // MARK: - Formatting

    private func formatTimecode(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00.00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let centis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }
}
