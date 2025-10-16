import SwiftUI
import AVFoundation
import OSLog
import PhotosUI

// MARK: - Minimal Trimmer View
/// Simple, functional video trimming interface that replaces the complex TrimmerView
/// Focuses on core functionality: select range, preview, rotate, name
/// Clean visual hierarchy with intuitive drag handles
///
/// Key Features:
/// - Frame-accurate trimming with universal frame rate support
/// - Simple drag handles for start/end selection
/// - Real-time preview with timecode display
/// - Minimum 3-second validation
/// - Clean, minimal interface
@MainActor
struct MinimalTrimmerView: View {
    // MARK: - Dependencies
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @StateObject private var videoPlayer = SharedVideoPlayer(mode: .main)

    // MARK: - State
    @State private var startTime: TimeInterval = 0.0
    @State private var endTime: TimeInterval = 0.0
    @State private var isPlaying: Bool = false
    @State private var rotation: VideoRotation = .degrees0
    @State private var isDraggingLeftHandle: Bool = false
    @State private var isDraggingRightHandle: Bool = false
    @State private var videoDuration: TimeInterval = 0.0
    @State private var frameRate: Double = 30.0
    @State private var errorMessage: String?
    @State private var showingRotationSheet: Bool = false

    // MARK: - Performance Optimization State
    @State private var seekTask: Task<Void, Never>?
    @State private var lastSeekTime: TimeInterval = 0
    @State private var seekDebounceMs: TimeInterval = 100 // 100ms debounce for seeking

    // MARK: - Constants
    private let minimumTrimDuration: TimeInterval = 3.0

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MinimalTrimmerView")

    // MARK: - Computed Properties
    private var trimDuration: TimeInterval {
        max(0.0, endTime - startTime)
    }

    private var isValidTrimRange: Bool {
        trimDuration >= minimumTrimDuration &&
        startTime >= 0 &&
        endTime <= videoDuration &&
        startTime < endTime
    }

    // MARK: - Body (Test2 spacing)
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // Video Preview Section - Test2 spacing
                videoPreviewSection

                // Timeline Section - Test2 spacing
                timelineSection(geometry: geometry)

                // Controls Section - Test2 spacing
                controlsSection

                Spacer()

                // Bottom Actions Section - Test2 spacing
                actionsSection
            }
            .padding(.vertical, 20)
        }
        .background(Color.backgroundPrimary)
        .sheet(isPresented: $showingRotationSheet) {
            rotationSelectionSheet
        }
        .onAppear {
            setupTrimmer()
        }
        .onChange(of: videoPlayer.isReady) { _, isReady in
            if isReady {
                loadVideoMetadata()
            }
        }
        .onChange(of: startTime) { _, newStartTime in
            validateTrimRange()
        }
        .onChange(of: endTime) { _, newEndTime in
            validateTrimRange()
        }
    }

    // MARK: - Video Preview Section (Test2 styling)
    private var videoPreviewSection: some View {
        VStack(spacing: 20) {
            // Video Player - Test2 design with 12pt corner radius
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)

                VideoPlayerView(player: videoPlayer, showControls: false)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Rotation Overlay
                if rotation != .degrees0 {
                    Text("Rotation: \(rotation.description)")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(Layout.smallRadius)
                        .position(x: Spacing.sm, y: Spacing.sm)
                }

                // Loading/Error States
                if !videoPlayer.isReady {
                    loadingOverlay
                }
            }
            .frame(height: 220)
            .padding(.horizontal, 16)

            // Time Display - Horizontal layout matching Test2.swift design
            HStack(spacing: 40) {
                // Start time group
                VStack(alignment: .center, spacing: 4) {
                    Text("START")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(formatTimecode(startTime))
                        .font(.headline)
                }

                // Duration - centered with matching visual weight
                Text(formatTimecode(trimDuration))
                    .font(.headline)
                    .foregroundColor(trimDuration >= minimumTrimDuration ? .blue : .red)

                // End time group
                VStack(alignment: .center, spacing: 4) {
                    Text("END")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(formatTimecode(endTime))
                        .font(.headline)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Timeline Section
    private func timelineSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: Spacing.xs) { // 4pt spacing for tighter grouping
            // Timeline with drag handles - responsive to screen bounds
            ZStack(alignment: .leading) {
                // Base Track - Timeline Background (Test2 proportions)
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 40)
                    .cornerRadius(8)

                // Selected Range Highlight (Test2 styling)
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: calculateHandlePosition(startTime, totalWidth: geometry.size.width))

                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: calculateTrimWidth(totalWidth: geometry.size.width))
                        .cornerRadius(6)

                    Spacer()
                }
                .frame(height: 40)

                // Playhead Indicator - constrained to trim range
                if videoPlayer.isReady && videoPlayer.currentTime >= startTime && videoPlayer.currentTime <= endTime {
                    playheadIndicator(totalWidth: geometry.size.width)
                }

                // Left Handle
                leftHandle(totalWidth: geometry.size.width)

                // Right Handle
                rightHandle(totalWidth: geometry.size.width)
            }
            .frame(maxWidth: .infinity) // Ensure within bounds

            // Timeline Markers - Test2 spacing
            HStack(spacing: 24) {
                ForEach([0, 1, 2, 3, 4], id: \.self) { index in
                    Text(timeLabel(for: index))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    // MARK: - Controls Section (Test2 styling)
    private var controlsSection: some View {
        HStack(spacing: 16) {
            // Play/Pause Button - Test2 circular design
            Button(action: togglePlayback) {
                Image(systemName: videoPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(!videoPlayer.isReady)

            // Rotation Button - Test2 circular design
            Button(action: showRotationOptions) {
                Image(systemName: "rotate.right")
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            }
            .disabled(!videoPlayer.isReady)

            Spacer()

            // Reset Button
            Text("Reset")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Actions Section (Test2 styling)
    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Action Buttons - Test2 styling
            HStack(spacing: 16) {
                // Cancel Button
                Button("Cancel") {
                    cancelTrimming()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

                // Submit Button - Test2 styling
                Button("Submit") {
                    proceedToNaming()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isValidTrimRange)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Playhead Indicator
    private func playheadIndicator(totalWidth: CGFloat) -> some View {
        let playheadPosition = calculateHandlePosition(videoPlayer.currentTime, totalWidth: totalWidth)

        return VStack(spacing: 0) {
            // Playhead line
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: 40)
                .overlay(
                    // Playhead triangle at top
                    Path { path in
                        path.move(to: CGPoint(x: -4, y: 0))
                        path.addLine(to: CGPoint(x: 4, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: -6))
                        path.closeSubpath()
                    }
                    .fill(Color.red)
                    .offset(y: -3)
                )
        }
        .position(x: playheadPosition, y: 20)
        .allowsHitTesting(false) // Don't interfere with drag gestures
    }

  // MARK: - Handle Components
    private func leftHandle(totalWidth: CGFloat) -> some View {
        let handlePosition = calculateHandlePosition(startTime, totalWidth: totalWidth)

        return Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .position(x: handlePosition, y: 20)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDraggingLeftHandle {
                            // Provide haptic feedback on drag start
                            provideSelectionFeedback()
                        }
                        isDraggingLeftHandle = true
                        handleLeftHandleDrag(value.location.x, totalWidth: totalWidth)
                    }
                    .onEnded { _ in
                        isDraggingLeftHandle = false
                        // Provide haptic feedback on drag end
                        provideNotificationFeedback(.success)
                        snapToNearestSecond(&startTime)
                        validateTrimRange()
                    }
            )
    }

    private func rightHandle(totalWidth: CGFloat) -> some View {
        let handlePosition = calculateHandlePosition(endTime, totalWidth: totalWidth)

        return Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .position(x: handlePosition, y: 20)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDraggingRightHandle {
                            // Provide haptic feedback on drag start
                            provideSelectionFeedback()
                        }
                        isDraggingRightHandle = true
                        handleRightHandleDrag(value.location.x, totalWidth: totalWidth)
                    }
                    .onEnded { _ in
                        isDraggingRightHandle = false
                        // Provide haptic feedback on drag end
                        provideNotificationFeedback(.success)
                        snapToNearestSecond(&endTime)
                        validateTrimRange()
                    }
            )
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))

            Text("Loading Video...")
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Setup Methods
    private func setupTrimmer() {
        logger.info("Setting up minimal trimmer")

        // Load video into player if available
        if let asset = unifiedState.selectedVideo {
            Task {
                await videoPlayer.loadVideo(asset)
            }
        }

        // Initialize trim range asynchronously
        Task {
            do {
                let duration = try await unifiedState.selectedVideo?.load(.duration)
                await MainActor.run {
                    if let duration = duration {
                        videoDuration = duration.seconds
                        endTime = duration.seconds
                        startTime = max(0, duration.seconds - 10) // Default to last 10 seconds

                        // Load existing trim values if available
                        if unifiedState.trimStartTime > 0 && unifiedState.trimEndTime > 0 {
                            startTime = unifiedState.trimStartTime
                            endTime = unifiedState.trimEndTime
                        }
                    }
                }
            } catch {
                logger.error("Failed to load video duration: \(error.localizedDescription)")
            }
        }
    }

    private func loadVideoMetadata() {
        guard let asset = unifiedState.selectedVideo else { return }

        Task {
            do {
                // Load duration
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    videoDuration = duration.seconds
                    if endTime == 0 {
                        endTime = duration.seconds
                        startTime = max(0, duration.seconds - 10)
                    }
                }

                // Load frame rate
                let videoTracks = try await asset.load(.tracks)
                if let videoTrack = videoTracks.first(where: { $0.mediaType == .video }) {
                    let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                    await MainActor.run {
                        frameRate = Double(nominalFrameRate)
                    }
                }

                logger.info("Video metadata loaded - Duration: \(videoDuration)s, Frame Rate: \(frameRate)fps")
            } catch {
                logger.error("Failed to load video metadata: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to load video metadata"
                }
            }
        }
    }

    // MARK: - Optimized Video Seeking
    /// Optimized seeking with debouncing for better performance
    /// Uses iOS 18 best practices for smooth timeline interaction
    private func optimizedSeek(to time: TimeInterval) {
        // Cancel any existing seek operation
        seekTask?.cancel()

        // Debounce seek operations to prevent excessive seeking during drag
        seekTask = Task { @MainActor in
            // Small delay to debounce rapid seeks
            try? await Task.sleep(nanoseconds: UInt64(seekDebounceMs * 1_000_000))

            // Check if task wasn't cancelled during sleep
            guard !Task.isCancelled else { return }

            // Use existing videoPlayer seek method with debouncing for performance
            videoPlayer.seek(to: time)

            logger.debug("Optimized seek to \(String(format: "%.2f", time))s with debouncing")
        }
    }

    // MARK: - Timeline Calculations
    private func calculateHandlePosition(_ time: TimeInterval, totalWidth: CGFloat) -> CGFloat {
        guard videoDuration > 0 else { return 0 }
        let progress = min(max(0, time / videoDuration), 1)
        return progress * totalWidth
    }

    private func calculateTrimWidth(totalWidth: CGFloat) -> CGFloat {
        let startPosition = calculateHandlePosition(startTime, totalWidth: totalWidth)
        let endPosition = calculateHandlePosition(endTime, totalWidth: totalWidth)
        return max(0, endPosition - startPosition)
    }

    private func handleLeftHandleDrag(_ dragX: CGFloat, totalWidth: CGFloat) {
        guard videoDuration > 0 else { return }

        // Constrain to timeline bounds with safe area
        let constrainedX = max(0, min(dragX, totalWidth))
        let newTime = (constrainedX / totalWidth) * videoDuration

        // Ensure minimum duration and boundary constraints
        let maxStartTime = endTime - minimumTrimDuration
        startTime = min(max(0, newTime), maxStartTime)

        // Use optimized seeking during drag for better performance
        optimizedSeek(to: startTime)
    }

    private func handleRightHandleDrag(_ dragX: CGFloat, totalWidth: CGFloat) {
        guard videoDuration > 0 else { return }

        // Constrain to timeline bounds with safe area
        let constrainedX = max(0, min(dragX, totalWidth))
        let newTime = (constrainedX / totalWidth) * videoDuration

        // Ensure minimum duration and boundary constraints
        let minEndTime = startTime + minimumTrimDuration
        endTime = max(min(videoDuration, newTime), minEndTime)

        // Use optimized seeking during drag for better performance
        optimizedSeek(to: endTime)
    }

    // MARK: - Validation
    private func validateTrimRange() {
        if trimDuration < minimumTrimDuration {
            errorMessage = "Minimum duration is \(Int(minimumTrimDuration)) seconds"
        } else if startTime < 0 || endTime > videoDuration || startTime >= endTime {
            errorMessage = "Invalid trim range"
        } else {
            errorMessage = nil
        }

        // Update unified state
        Task { @MainActor in
            unifiedState.trimStartTime = startTime
            unifiedState.trimEndTime = endTime
        }
    }

    // MARK: - Helper Methods
    private func snapToNearestSecond(_ time: inout TimeInterval) {
        // Round to nearest second for simplicity
        time = round(time)
    }

    /// Provides haptic feedback for selection interactions
    private func provideSelectionFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Provides haptic feedback for notification/completion interactions
    private func provideNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }

    private func formatTimecode(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * frameRate)
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }

    // Helper: Generate time labels for timeline ticks (Test2 style)
    private func timeLabel(for index: Int) -> String {
        switch index {
        case 0: return "00:00:00"
        case 1: return "00:08:12"
        case 2: return "00:17:01"
        case 3: return "00:25:14"
        default: return formatTimecode(videoDuration)
        }
    }

    private func togglePlayback() {
        if videoPlayer.isPlaying {
            videoPlayer.pause()
        } else {
            // Seek to start time and play within trim range
            videoPlayer.seek(to: startTime)
            videoPlayer.play()

            // Monitor playback to enforce trim range boundaries
            monitorTrimRangePlayback()
        }
    }

    /// Optimized playback monitoring with efficient checking
    private func monitorTrimRangePlayback() {
        Task { @MainActor in
            // Use a timer for more efficient playback monitoring
            var lastCheckTime = videoPlayer.currentTime

            while videoPlayer.isPlaying && videoPlayer.isReady {
                let currentTime = videoPlayer.currentTime

                // Only seek if we've significantly moved forward to reduce operations
                if currentTime >= endTime || (currentTime - lastCheckTime > 0.5) {
                    if currentTime >= endTime {
                        // Loop back to start time using optimized seek
                        optimizedSeek(to: startTime)
                        if videoPlayer.isPlaying {
                            videoPlayer.play()
                        }
                    }
                    lastCheckTime = currentTime
                }

                // Use a longer sleep interval for better performance
                try? await Task.sleep(nanoseconds: 200_000_000) // Check every 200ms instead of 100ms
            }
        }
    }

    private func showRotationOptions() {
        showingRotationSheet = true
        logger.info("Rotation options requested")
    }

    // MARK: - Rotation Selection Sheet
    private var rotationSelectionSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Rotate Video")
                        .font(.ibmPlexMono(size: 20, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text("Choose the rotation angle for your video")
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Current Rotation Display
                VStack(spacing: 12) {
                    Text("Current Rotation")
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                        .textCase(.uppercase)

                    Text(rotation.description)
                        .font(.ibmPlexMono(size: 32, weight: .bold))
                        .foregroundColor(.accent)

                    // Preview of rotation effect (simple visual indicator)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 120, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.borderPrimary, lineWidth: 1)
                            )

                        // Arrow showing rotation direction
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(.accent)
                            .rotationEffect(.degrees(Double(rotation.rawValue)))
                            .animation(.easeInOut(duration: 0.3), value: rotation)
                    }
                }
                .padding(.vertical, 16)

                // Rotation Options Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(VideoRotation.allCases, id: \.self) { rotationOption in
                        rotationOptionButton(rotationOption)
                    }
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button("Apply Rotation") {
                        applyRotation()
                    }
                    .font(.ibmPlexMono(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.buttonHeight)
                    .background(Color.accent)
                    .cornerRadius(Layout.mediumRadius)

                    Button("Cancel") {
                        showingRotationSheet = false
                    }
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.buttonHeight)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(Layout.mediumRadius)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func rotationOptionButton(_ rotationOption: VideoRotation) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                rotation = rotationOption
            }
        }) {
            VStack(spacing: 8) {
                // Visual rotation indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rotation == rotationOption ? Color.accent.opacity(0.1) : Color.backgroundSecondary)
                        .frame(width: 80, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(rotation == rotationOption ? Color.accent : Color.borderPrimary, lineWidth: rotation == rotationOption ? 2 : 1)
                        )

                    // Arrow showing rotation
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(rotation == rotationOption ? .accent : .textTertiary)
                        .rotationEffect(.degrees(Double(rotationOption.rawValue)))
                }

                // Rotation label
                Text(rotationOption.description)
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(rotation == rotationOption ? .accent : .textPrimary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func applyRotation() {
        logger.info("Applying rotation: \(rotation.description)")

        // Update unified state with new rotation
        Task { @MainActor in
            await unifiedState.updateVideoRotation(rotation)
        }

        // Dismiss sheet
        showingRotationSheet = false

        // Show brief confirmation feedback
        logger.info("Rotation applied successfully")
    }

    private func resetTrimRange() {
        startTime = 0
        endTime = videoDuration
        validateTrimRange()
        logger.info("Trim range reset")
    }

    private func proceedToNaming() {
        guard isValidTrimRange else { return }

        logger.info("🎯 Proceeding to naming with validated trim range: \(startTime)s - \(endTime)s, rotation: \(rotation.description)")

        // Cancel any pending seek operations before navigation
        seekTask?.cancel()

        // Create trim modification with rotation persistence
        let modification = TrimModification(
            startTimeMs: Int64(startTime * 1000),
            endTimeMs: Int64(endTime * 1000),
            rotation: rotation
        )

        Task {
            // Update UnifiedState with trim modification data
            await unifiedState.updateTrimModification(modification)

            // Ensure smooth transition to naming workflow
            await MainActor.run {
                unifiedState.updateTab(.naming)
                unifiedState.updateFlowState(.naming)
            }

            logger.info("✅ Navigation complete: Trimming → Naming workflow")
        }
    }

    // MARK: - Cleanup
    private func cancelTrimming() {
        // Cancel any pending seek operations
        seekTask?.cancel()

        unifiedState.updateTab(.add)
        unifiedState.updateFlowState(.ready)
        logger.info("Trimming cancelled with cleanup")
    }
}

// MARK: - Mock State for Preview
/// Simple mock state that enables real-time canvas updates without async dependencies
/// Inherits from AddMoveUnifiedState to maintain compatibility
class MockTrimmerState: AddMoveUnifiedState {
    override init() {
        // Initialize with mock data
        super.init()
        self.currentTab = .trimming
        self.flowState = .trimming
        self.trimStartTime = 2.0
        self.trimEndTime = 8.0
        self.videoRotation = .degrees0
        self.selectedVideo = nil
    }

    // Override complex async methods with simple mock implementations
    override func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
        // Mock implementation - does nothing for preview
        print("🎬 Mock: loadVideo called - no operation in preview")
    }

    override func processTrim(from startTime: CMTime, to endTime: CMTime) async throws -> AVAsset {
        print("🎬 Mock: processTrim called - returning mock asset")
        return AVAsset()
    }

    override func updateVideoRotation(_ rotation: VideoRotation) async {
        await MainActor.run {
            self.videoRotation = rotation
        }
        print("🎬 Mock: updateVideoRotation called with \(rotation.description)")
    }
}

// MARK: - Preview
#Preview("Minimal Trimmer - Live Preview") {
    MinimalTrimmerView(unifiedState: MockTrimmerState())
        .frame(height: 600)
        .background(Color.gray.opacity(0.1))
}
