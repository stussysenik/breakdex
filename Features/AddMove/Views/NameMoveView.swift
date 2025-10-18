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
    @StateObject private var moveSaver: MoveSaver

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "NameMoveView"
    )

    init(viewModel: AddMoveViewModel) {
        self.viewModel = viewModel
        let movePersistenceService = MovePersistenceService(
            persistentContainer: PersistenceController.shared.container
        )
        self._moveSaver = StateObject(wrappedValue: MoveSaver(
            persistentContainer: PersistenceController.shared.container,
            movePersistenceService: movePersistenceService
        ))
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
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            setupInitialState()
        }
        .onChange(of: moveName) { _, newValue in
            viewModel.moveName = newValue
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Name Your Move")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

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
                AVPlayerViewRepresentable(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
                    .onAppear {
                        calculateEstimatedFileSize()
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
                    .foregroundColor(.white)

                Spacer()

                Text("NEW")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)

                Spacer()

                Text("Breaking • Foundation")
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
                .foregroundColor(.white)
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
                .foregroundColor(.white)
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
                .foregroundColor(.white)
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
               !isSaving
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
        logger.info("💾 Saving move: '\(finalName)'")

        Task {
            isSaving = true
            defer {
                Task { @MainActor in
                    isSaving = false
                }
            }

            do {
                guard let asset = viewModel.selectedVideo else {
                    throw NSError(domain: "NameMoveView", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No video asset available"
                    ])
                }

                // Save the move using MoveSaver service
                let savedMove = try await moveSaver.saveSimpleMove(name: finalName, asset: asset)
                logger.info("✅ Move saved successfully: \(savedMove.name ?? "unnamed")")

                await MainActor.run {
                    // Clear error state and indicate success
                    viewModel.clearError()
                    // Note: In MVVM pattern, navigation would be handled by parent view observing view model state
                    logger.info("✅ Move saved - parent view will handle navigation")
                }

            } catch {
                logger.error("❌ Save failed: \(error.localizedDescription)")
                await MainActor.run {
                    viewModel.setError("Failed to save move: \(error.localizedDescription)")
                }
            }
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

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
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