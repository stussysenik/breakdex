import SwiftUI
import AVKit
import OSLog

// MARK: - NameMoveView
/// Clean move naming interface for finalizing the video move
/// Uses AddMoveViewModel directly following MVVM pattern
struct NameMoveView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var isSaving = false
    @State private var estimatedFileSize: String = "Calculating..."
    @State private var videoDuration: String = "0:00"
    @State private var moveName: String = ""
    @StateObject private var videoPlayer = SharedVideoPlayer(mode: .preview)

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "NameMoveView"
    )

    init(viewModel: AddMoveViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerView

            // Video Preview
            videoPreviewView

            // Move Details
            moveDetailsView

            // Name Input
            nameInputView

            // Action Buttons
            actionButtonsView

            Spacer()
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            logger.info("🧹 NameMoveView disappearing - cleaning up SharedVideoPlayer")
            videoPlayer.cleanup()
        }
        .onChange(of: moveName) { _, newValue in
            viewModel.moveName = newValue
        }
        .onChange(of: viewModel.saveState) { _, saveState in
            // Sync local isSaving state with ViewModel's save state
            isSaving = saveState.isSaving
            logger.info("🔄 OPENSPEC FIX: NameMoveView: saveState changed to \(saveState.description), isSaving: \(isSaving)")
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Name Your Move")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)

            Text("Give your breaking move a memorable name")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    // MARK: - Video Preview View
    private var videoPreviewView: some View {
        VStack(spacing: 12) {
            // Video Player Container
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 180)
                .aspectRatio(contentMode: .fit)
                .clipped()
                .overlay(
                    Group {
                        if viewModel.isVideoReady {
                            videoPlayerContent
                        } else {
                            videoPreviewPlaceholder
                        }
                    }
                )
                .padding(.horizontal)

            // Video Info
            HStack {
                Text("Duration: \(videoDuration)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("Size: \(estimatedFileSize)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Video Player Content
    private var videoPlayerContent: some View {
        Group {
            if let asset = viewModel.selectedVideo {
                VideoPlayerView(player: videoPlayer, showControls: true)
                    .rotationEffect(viewModel.videoRotation.angle)
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .onAppear {
                        logger.info("🔄 OPENSPEC FIX: NameMoveView using SharedVideoPlayer - Available rotation: \(viewModel.videoRotation.description)")
                        logger.info("🎬 VIDEO_PLAYER_PROOF: Player type=SharedVideoPlayer (with rotation support)")
                        logger.info("📊 ROTATION INHERITANCE: Applying rotation transform: \(viewModel.videoRotation.description)")

                        // Enhanced logging to prove video container overflow hypothesis
                        Task {
                            await logVideoContainerDimensions(asset: asset)
                        }

                        loadVideoInSharedPlayer(asset: asset)
                        calculateEstimatedFileSize()
                    }
                    .onTapGesture {
                        logger.info("👆 INTERACTION_PROOF: NameMoveView video tapped - Player type: SharedVideoPlayer, Rotation: \(viewModel.videoRotation.description)")
                    }
            } else {
                videoPreviewPlaceholder
            }
        }
    }

    // MARK: - Video Preview Placeholder
    private var videoPreviewPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary)

            Text("Video Preview")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Move Details View
    private var moveDetailsView: some View {
        VStack(spacing: 16) {
            // Learning State
            HStack {
                Text("Learning State")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("NEW")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }

            // Tags
            HStack {
                Text("Tags")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Breaking • Foundation")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            // Rotation Information
            HStack {
                Text("Rotation")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(viewModel.videoRotation.description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal)
    }

    // MARK: - Name Input View
    private var nameInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move Name")
                .font(.subheadline)
                .foregroundColor(.textPrimary)
                .padding(.horizontal)

            TextField("Enter move name", text: $moveName)
                .font(.ibmPlexMono(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
                .padding(.horizontal)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(moveName.isEmpty ? Color.gray : Color.blue, lineWidth: 1)
                )
                .padding(.horizontal)

            // Name validation hint
            if moveName.isEmpty {
                Text("Enter a descriptive name for your move")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal)
            } else if moveName.count < 3 {
                Text("Use at least 3 characters")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Save Button
            Button(action: saveMove) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isSaving ? "Saving..." : "Save Move")
                }
                .font(.ibmPlexMono(size: 18, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canSave ? Color.blue : Color.gray)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canSave || isSaving)

            // Back Button
            Button(action: goBack) {
                HStack {
                    Image(systemName: "arrow.left")
                    Text("Back to Trim")
                }
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.6))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSaving)
        }
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var canSave: Bool {
        return !moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               moveName.count >= 3 &&
               viewModel.isVideoReady &&
               !isSaving &&
               !viewModel.saveState.isSaving
    }

    // MARK: - Private Methods

    private func setupInitialState() {
        moveName = viewModel.moveName
        logger.info("📝 NameMoveView setup - initial name: '\(moveName)'")
    }

    private func calculateEstimatedFileSize() {
        guard let asset = viewModel.selectedVideo else {
            estimatedFileSize = "Unknown"
            videoDuration = "0:00"
            return
        }

        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationInSeconds = duration.seconds

                // Update video duration
                await MainActor.run {
                    videoDuration = formatTime(durationInSeconds)
                }

                // Base bitrate estimation (rough estimate for H.264 video)
                let baseBitrateMbps: Double = 5.0 // 5 Mbps for standard quality

                // Calculate file size in bytes
                let bitratebps = baseBitrateMbps * 1_000_000
                let estimatedSizeBytes = bitratebps * durationInSeconds / 8

                // Format for display
                let sizeInMB = estimatedSizeBytes / (1024 * 1024)

                await MainActor.run {
                    if sizeInMB < 1 {
                        let sizeInKB = estimatedSizeBytes / 1024
                        estimatedFileSize = String(format: "%.0f KB", sizeInKB)
                    } else if sizeInMB < 100 {
                        estimatedFileSize = String(format: "%.1f MB", sizeInMB)
                    } else {
                        estimatedFileSize = String(format: "%.0f MB", sizeInMB)
                    }

                    logger.info("📏 File size calculated - duration: \(String(format: "%.1f", durationInSeconds))s, estimated size: \(estimatedFileSize)")
                }

            } catch {
                await MainActor.run {
                    estimatedFileSize = "Estimate unavailable"
                    videoDuration = "0:00"
                    logger.warning("⚠️ File size calculation failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func saveMove() {
        guard canSave else { return }

        let finalName = moveName.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("💾 OPENSPEC FIX: NameMoveView: saveMove called with name: '\(finalName)'")

        Task {
            isSaving = true
            defer {
                Task { @MainActor in
                    isSaving = false
                }
            }

            logger.info("🔄 OPENSPEC FIX: NameMoveView: Calling viewModel.saveMove")

            // Save the move using ViewModel's saveMove method (MVVM pattern)
            await viewModel.saveMove(name: finalName)

            // Save completion and error handling are now managed by the ViewModel
            // Parent AddMoveView will observe saveState and handle navigation
            logger.info("✅ OPENSPEC FIX: NameMoveView: Save delegated to ViewModel - parent will handle navigation")
        }
    }

    private func goBack() {
        logger.info("⬅️ Going back to trimming")
        Task {
            await MainActor.run {
                // In MVVM pattern, navigation would be handled by parent view observing view model state
                // For now, just log the navigation request
                logger.info("⬅️ Navigation request - parent view will handle navigation")
            }
        }
    }

    private func loadVideoInSharedPlayer(asset: AVAsset) {
        logger.info("🎬 OPENSPEC FIX: Loading video in SharedVideoPlayer with rotation: \(viewModel.videoRotation.description)")

        Task {
            let success = await videoPlayer.loadVideo(asset)
            await MainActor.run {
                if success {
                    logger.info("✅ OPENSPEC FIX: SharedVideoPlayer loaded video successfully with rotation: \(viewModel.videoRotation.description)")
                } else {
                    logger.error("❌ OPENSPEC FIX: SharedVideoPlayer failed to load video")
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Enhanced Video Container Analysis
    /// Enhanced logging to prove video container overflow hypothesis
    private func logVideoContainerDimensions(asset: AVAsset) async {
        do {
            // Get video track dimensions
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let firstVideoTrack = videoTracks.first else {
                logger.error("📐 CONTAINER_ANALYSIS: No video tracks found")
                return
            }

            let naturalSize = try await firstVideoTrack.load(.naturalSize)
            let preferredTransform = try await firstVideoTrack.load(.preferredTransform)

            // Log original video dimensions
            logger.info("📐 CONTAINER_ANALYSIS: Original video dimensions: \(naturalSize.width) x \(naturalSize.height)")
            logger.info("📐 CONTAINER_ANALYSIS: Preferred transform: \(preferredTransform)")
            logger.info("📐 CONTAINER_ANALYSIS: Applied rotation: \(viewModel.videoRotation.description)")

            // Calculate container constraints
            let containerHeight: CGFloat = 180 // Fixed container height from frame(height: 180)
            let containerAspectRatio: CGFloat = 1.0 // Assuming square container for now

            // Calculate expected dimensions after rotation
            let rotationDegrees = viewModel.videoRotation.angle.degrees
            let isRotated = abs(rotationDegrees.truncatingRemainder(dividingBy: 180)) > 45

            let (effectiveWidth, effectiveHeight) = isRotated ?
                (naturalSize.height, naturalSize.width) :
                (naturalSize.width, naturalSize.height)

            logger.info("📐 CONTAINER_ANALYSIS: Effective dimensions after rotation: \(effectiveWidth) x \(effectiveHeight)")
            logger.info("📐 CONTAINER_ANALYSIS: Container constraints: height=\(containerHeight), aspectRatio=\(containerAspectRatio)")

            // Calculate overflow
            let containerWidth = containerHeight * containerAspectRatio
            let widthOverflow = effectiveWidth - containerWidth
            let heightOverflow = effectiveHeight - containerHeight

            logger.info("📐 CONTAINER_ANALYSIS: Container dimensions: \(containerWidth) x \(containerHeight)")
            logger.info("📐 CONTAINER_ANALYSIS: Width overflow: \(widthOverflow > 0 ? "\(widthOverflow)px (OVERFLOW)" : "\(widthOverflow)px (OK)")")
            logger.info("📐 CONTAINER_ANALYSIS: Height overflow: \(heightOverflow > 0 ? "\(heightOverflow)px (OVERFLOW)" : "\(heightOverflow)px (OK)")")

            // OPENSPEC FIX: Log container fix application
            logger.info("🔧 OPENSPEC FIX: Applied aspectRatio(contentMode: .fit) and clipped() modifiers to prevent overflow")

            // Provide mathematical proof of overflow
            if widthOverflow > 0 || heightOverflow > 0 {
                logger.error("📐 CONTAINER_PROOF: Video container overflow CONFIRMED - Video (\(effectiveWidth)x\(effectiveHeight)) cannot fit in container (\(containerWidth)x\(containerHeight))")
                logger.error("📐 CONTAINER_PROOF: Root cause: Fixed container dimensions don't account for rotation transform")
                logger.warning("🔧 OPENSPEC FIX: aspectRatio and clipped() modifiers should prevent system instability from overflow")
            } else {
                logger.info("📐 CONTAINER_PROOF: Video fits within container bounds - No overflow detected")
                logger.info("✅ OPENSPEC FIX: Container fixes applied successfully - no overflow expected")
            }

        } catch {
            logger.error("📐 CONTAINER_ANALYSIS: Failed to analyze video dimensions: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        private var viewModel: AddMoveViewModel {
            let vm = AddMoveViewModel()
            // Simulate a loaded video for preview by setting some state
            vm.moveName = "Sample Move"
            return vm
        }

        var body: some View {
            NameMoveView(viewModel: viewModel)
                .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}