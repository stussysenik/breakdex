// MoveDetailView.swift — Full detail screen for a single breakdancing move
//
// Displays video player with optional 2D pose skeleton overlay,
// tap-to-edit move name, creation date, and learning state as plain text.
// 4 visual anchors: video player, pose toggle (glass circle), move name, metadata.
// Balance analysis code preserved in BalanceAnalyzer.swift for future use.

import SwiftUI
import SwiftData
import AVFoundation
import Vision

struct MoveDetailView: View {

    // MARK: - Environment & Data

    @Environment(\.modelContext) private var modelContext

    let move: Move

    // MARK: - Name Editing State

    @State private var isEditingName = false
    @State private var editedName = ""

    // MARK: - Video Player State

    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    @State private var videoSize: CGSize = CGSize(width: 1920, height: 1080)

    // MARK: - Pose Analysis State

    @State private var isPoseOverlayEnabled = false
    @State private var currentPose: VNHumanBodyPoseObservation?
    @State private var isAnalyzing = false
    @State private var poseTimer: Timer?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 24) {

                // VIDEO PLAYER + POSE OVERLAY
                ZStack {
                    CustomVideoPlayerView(move: move, player: player)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))

                    // 2D skeleton overlay
                    if isPoseOverlayEnabled, let pose = currentPose {
                        PoseOverlayView(
                            observation: pose,
                            imageSize: videoSize,
                            balanceResult: nil
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .allowsHitTesting(false)
                    }

                    // Gradient overlay for control readability over bright video
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .allowsHitTesting(false)

                    // Pose toggle — glass circle anchor
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: { togglePoseOverlay() }) {
                                Image(systemName: isPoseOverlayEnabled ? "figure.walk.circle.fill" : "figure.walk.circle")
                                    .font(.title2)
                                    .foregroundColor(isPoseOverlayEnabled ? Color.accent : .white)
                                    .padding(8)
                            }
                            .liquidGlass(in: .circle)

                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }

                            Spacer()
                        }
                        .padding(12)
                    }
                }
                .aspectRatio(4/3, contentMode: .fit)

                // METADATA — plain text, no cards, no badges
                VStack(alignment: .leading, spacing: 8) {

                    if isEditingName {
                        TextField("Move Name", text: $editedName, onCommit: {
                            saveName()
                        })
                        .font(.ibmPlexMono(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(Radius.sm)
                    } else {
                        Text(move.name ?? "Untitled Move")
                            .font(.ibmPlexMono(size: 20, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .onTapGesture {
                                editedName = move.name ?? ""
                                isEditingName = true
                            }
                    }

                    Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year())")
                        .font(.ibmPlexMono(size: 13))
                        .foregroundColor(.secondary)

                    let resolved = LearningState.resolve(from: move.learningState)
                    Text(resolved.actionLabel)
                        .font(.ibmPlexMono(size: 13, weight: .medium))
                        .foregroundColor(resolved.color)

                    Spacer()
                }
                .padding(.horizontal, Spacing.screenEdge)
            }
            .padding(.top, 20)
        }
        .navigationTitle(move.name ?? "Move Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupVideoPlayer() }
        .onDisappear { stopPoseAnalysis() }
        .animation(AppAnimation.springSmooth, value: isPoseOverlayEnabled)
    }

    // MARK: - Video Player Setup

    private func setupVideoPlayer() {
        guard let url = move.resolveVideoURL() else {
            print("[MoveDetail] Video resolution failed for '\(move.name ?? "?")'")
            return
        }
        videoURL = url
        player = AVPlayer(url: url)

        Task {
            let asset = AVURLAsset(url: url)
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size, let transform {
                    let transformed = size.applying(transform)
                    await MainActor.run {
                        videoSize = CGSize(
                            width: abs(transformed.width),
                            height: abs(transformed.height)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Pose Overlay Toggle

    private func togglePoseOverlay() {
        isPoseOverlayEnabled.toggle()
        if isPoseOverlayEnabled {
            startPoseAnalysis()
        } else {
            stopPoseAnalysis()
            currentPose = nil
        }
    }

    // MARK: - Pose Analysis (2D only)

    private func startPoseAnalysis() {
        guard poseTimer == nil else { return }
        analyzeCurrentFrame()
        poseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            analyzeCurrentFrame()
        }
    }

    private func stopPoseAnalysis() {
        poseTimer?.invalidate()
        poseTimer = nil
        isAnalyzing = false
    }

    private func analyzeCurrentFrame() {
        guard let url = videoURL, let player else { return }
        let currentTime = player.currentTime()
        guard currentTime.isValid, !currentTime.isIndefinite else { return }

        Task {
            await MainActor.run { isAnalyzing = true }

            do {
                guard let frame = try await PoseAnalyzer.extractFrame(from: url, at: currentTime) else {
                    await MainActor.run { isAnalyzing = false }
                    return
                }

                let pose = try PoseAnalyzer.detect2DPose(from: frame)

                await MainActor.run {
                    currentPose = pose
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run { isAnalyzing = false }
            }
        }
    }

    // MARK: - Name Saving

    private func saveName() {
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isEditingName = false
            return
        }
        move.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try modelContext.save()
            isEditingName = false
        } catch {
            print("Failed to save move name: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("MoveDetail NEW - Light") {
    NavigationStack {
        MoveDetailView(move: ModelContainer.previewMove(state: "NEW"))
    }
    .modelContainer(.preview)
}

#Preview("MoveDetail NEW - Dark") {
    NavigationStack {
        MoveDetailView(move: ModelContainer.previewMove(state: "NEW"))
    }
    .modelContainer(.preview)
    .preferredColorScheme(.dark)
}

#Preview("MoveDetail LEARNING") {
    NavigationStack {
        MoveDetailView(move: ModelContainer.previewMove(state: "LEARNING"))
    }
    .modelContainer(.preview)
}

#Preview("MoveDetail MASTERY") {
    NavigationStack {
        MoveDetailView(move: ModelContainer.previewMove(state: "MASTERY"))
    }
    .modelContainer(.preview)
}
