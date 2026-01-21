import SwiftUI
import AVKit

// MARK: - Flashcard Card View
/// Individual flashcard that shows video thumbnail (front) and video player (back).
/// Supports 3D flip animation and swipe gestures.

struct FlashcardCardView: View {

    // MARK: - Properties

    let move: Move
    let isRevealed: Bool
    var onTap: (() -> Void)?

    @State private var dragOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @ObservedObject private var accessibility = AccessibilityManager.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // Front of card (thumbnail)
            frontCard
                .opacity(isRevealed ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isRevealed ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Back of card (video)
            backCard
                .opacity(isRevealed ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isRevealed ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .offset(dragOffset)
        .rotationEffect(.degrees(rotation))
        .animation(accessibility.effectiveAnimation, value: isRevealed)
        .animation(MotionSystem.interactive, value: dragOffset)
        .gesture(tapGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isRevealed ? "Swipe to rate" : "Tap to reveal")
    }

    // MARK: - Front Card

    @ViewBuilder
    private var frontCard: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack {
                AsyncThumbnailView(move: move)
                    .blur(radius: 8)

                // Question overlay
                VStack(spacing: 16) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white)

                    Text("What move is this?")
                        .font(.ibmPlexMono(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 280)
            .clipped()

            // Info section (hidden on front)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap to reveal")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.textSecondary)

                EnhancedStatePillView(learningState: move.learningState ?? "NEW")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.largeRadius))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    // MARK: - Back Card

    @ViewBuilder
    private var backCard: some View {
        VStack(spacing: 0) {
            // Video preview
            ZStack {
                if let identifier = move.photosIdentifier {
                    MiniVideoPlayer(
                        photosIdentifier: identifier,
                        trimStart: move.trimStartTime,
                        trimEnd: move.trimEndTime
                    )
                } else {
                    AsyncThumbnailView(move: move)
                }
            }
            .frame(height: 280)
            .clipped()

            // Revealed info
            VStack(alignment: .leading, spacing: 8) {
                Text(move.name ?? "Untitled Move")
                    .font(.ibmPlexMono(size: 20, weight: .bold))
                    .foregroundColor(.textPrimary)

                HStack {
                    EnhancedStatePillView(learningState: move.learningState ?? "NEW")

                    Spacer()

                    if let date = move.createdAt {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }

                // Tags if available
                if let tags = move.tags, !tags.isEmpty {
                    Text(tags)
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.largeRadius))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    // MARK: - Gestures

    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded { _ in
                if !isRevealed {
                    HapticFeedback.selectionHaptic()
                    onTap?()
                }
            }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if isRevealed {
            return "Move: \(move.name ?? "Untitled"). State: \(move.learningState ?? "New")"
        } else {
            return "Hidden flashcard. Tap to reveal."
        }
    }
}

// MARK: - Mini Video Player
/// Compact video player for flashcard back side

struct MiniVideoPlayer: View {

    let photosIdentifier: String
    let trimStart: Double
    let trimEnd: Double

    @StateObject private var player = SharedVideoPlayer(mode: .preview)
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if player.isReady {
                VideoPlayerView(player: player, showControls: true)
            } else {
                // Placeholder while loading
                Color.backgroundTertiary
                    .overlay(
                        ProgressView()
                            .tint(.textSecondary)
                    )
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player.cleanup()
        }
    }

    private func loadVideo() {
        Task {
            guard let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier) else {
                return
            }

            await player.loadVideo(asset)

            // Seek to trim start
            if trimStart > 0 {
                await player.seek(to: trimStart)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FlashcardCardView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let move = Move(context: context)
        move.name = "Windmill Tutorial"
        move.createdAt = Date()
        move.learningState = "LEARNING"
        move.photosIdentifier = "test-id"
        move.tags = "Power Move, Foundation"

        return VStack(spacing: 40) {
            Text("Front (Hidden)")
                .font(.ibmPlexMono(size: 14, weight: .medium))

            FlashcardCardView(move: move, isRevealed: false)
                .frame(height: 400)

            Text("Back (Revealed)")
                .font(.ibmPlexMono(size: 14, weight: .medium))

            FlashcardCardView(move: move, isRevealed: true)
                .frame(height: 400)
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
#endif
