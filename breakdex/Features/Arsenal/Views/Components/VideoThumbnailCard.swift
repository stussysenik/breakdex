import SwiftUI

// MARK: - Video Thumbnail Card
/// Golden ratio video-centric card for displaying moves in a visually appealing layout.
/// Video takes 61.8% of the card height (major portion), with info below.

struct VideoThumbnailCard: View {

    // MARK: - Properties

    let move: Move
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let videoHeight = GoldenRatio.videoHeight(forWidth: cardWidth)
            let contentHeight = cardWidth / GoldenRatio.phi - videoHeight

            VStack(spacing: 0) {
                // Video Thumbnail - Major portion (61.8%)
                thumbnailSection(height: videoHeight)

                // Info Section - Minor portion (38.2%)
                infoSection(height: max(contentHeight, 60))
            }
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.mediumRadius))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(accessibility.effectiveMicroAnimation, value: isPressed)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        onTap?()
                        HapticFeedback.selectionHaptic()
                    }
            )
        }
        .aspectRatio(GoldenRatio.phi, contentMode: .fit)
    }

    // MARK: - Thumbnail Section

    @ViewBuilder
    private func thumbnailSection(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail Image
            AsyncThumbnailView(move: move)
                .frame(height: height)
                .clipped()

            // Learning State Pill (top right)
            EnhancedStatePillView(learningState: move.learningState ?? "NEW")
                .padding(8)
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private func infoSection(height: CGFloat) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Move Name
                Text(move.name ?? "Untitled Move")
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                // Created date
                if let createdAt = move.createdAt {
                    Text(createdAt, format: .dateTime.month(.abbreviated).day())
                        .font(.ibmPlexMono(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            // Duration indicator (if available)
            if move.trimEndTime > move.trimStartTime {
                let duration = move.trimEndTime - move.trimStartTime
                Text(formatDuration(duration))
                    .font(.ibmPlexMono(size: 11, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.backgroundTertiary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(height: height)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "0:%02d", secs)
        }
    }
}

// MARK: - Enhanced State Pill View
/// Updated pill view using DesignSystem colors with animation support

struct EnhancedStatePillView: View {

    let learningState: String
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        Text(displayText)
            .font(.ibmPlexMono(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
            .animation(MotionSystem.micro, value: learningState)
    }

    private var displayText: String {
        switch learningState.uppercased() {
        case "NEW", "NEW LEARN":
            return "NEW"
        case "LEARNING":
            return "LEARNING"
        case "MASTERY", "MASTERED":
            return "MASTERED"
        default:
            return learningState.uppercased()
        }
    }

    private var backgroundColor: Color {
        let useHighContrast = accessibility.highContrastMode

        switch learningState.uppercased() {
        case "NEW", "NEW LEARN":
            return useHighContrast
                ? Color.stateNewHighContrast.opacity(0.2)
                : Color.stateNew.opacity(0.2)
        case "LEARNING":
            return useHighContrast
                ? Color.stateLearningHighContrast.opacity(0.2)
                : Color.stateLearning.opacity(0.2)
        case "MASTERY", "MASTERED":
            return useHighContrast
                ? Color.stateMasteryHighContrast.opacity(0.2)
                : Color.stateMastery.opacity(0.2)
        default:
            return Color.textSecondary.opacity(0.2)
        }
    }

    private var textColor: Color {
        let useHighContrast = accessibility.highContrastMode

        switch learningState.uppercased() {
        case "NEW", "NEW LEARN":
            return useHighContrast ? Color.stateNewHighContrast : Color.stateNew
        case "LEARNING":
            return useHighContrast ? Color.stateLearningHighContrast : Color.stateLearning
        case "MASTERY", "MASTERED":
            return useHighContrast ? Color.stateMasteryHighContrast : Color.stateMastery
        default:
            return Color.textSecondary
        }
    }
}

// MARK: - Compact Move Card
/// A smaller card variant for grid layouts

struct CompactMoveCard: View {

    let move: Move
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack(alignment: .bottomLeading) {
                AsyncThumbnailView(move: move)
                    .frame(height: 120)
                    .clipped()

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)

                // Move name on thumbnail
                Text(move.name ?? "Untitled")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(8)
            }

            // State indicator bar
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)

                Spacer()

                if let date = move.createdAt {
                    Text(date, format: .dateTime.month(.narrow).day())
                        .font(.ibmPlexMono(size: 10))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.backgroundSecondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(accessibility.effectiveMicroAnimation, value: isPressed)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap?()
                    HapticFeedback.selectionHaptic()
                }
        )
    }

    private var stateColor: Color {
        switch move.learningState?.uppercased() {
        case "NEW", "NEW LEARN":
            return .stateNew
        case "LEARNING":
            return .stateLearning
        case "MASTERY", "MASTERED":
            return .stateMastery
        default:
            return .textSecondary
        }
    }
}

// MARK: - List Row Card
/// A horizontal card variant for list views

struct MoveListRowCard: View {

    let move: Move
    var showThumbnail: Bool = true
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail (optional)
            if showThumbnail {
                AsyncThumbnailView(move: move)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
            }

            // Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(move.name ?? "Untitled Move")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    if let date = move.createdAt {
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.ibmPlexMono(size: 11))
                            .foregroundColor(.textSecondary)
                    }

                    if move.trimEndTime > move.trimStartTime {
                        let duration = move.trimEndTime - move.trimStartTime
                        Text(formatDuration(duration))
                            .font(.ibmPlexMono(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            // State pill
            EnhancedStatePillView(learningState: move.learningState ?? "NEW")
        }
        .padding(Spacing.md)
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.mediumRadius))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(accessibility.effectiveMicroAnimation, value: isPressed)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap?()
                    HapticFeedback.selectionHaptic()
                }
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Preview

#if DEBUG
struct VideoThumbnailCard_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext

        // Create test move
        let move = Move(context: context)
        move.name = "Windmill Tutorial"
        move.createdAt = Date()
        move.learningState = "LEARNING"
        move.photosIdentifier = "test-id"
        move.trimStartTime = 0
        move.trimEndTime = 45.5

        return ScrollView {
            VStack(spacing: 24) {
                Text("Video Thumbnail Card")
                    .font(.ibmPlexMono(size: 20, weight: .bold))

                // Full card
                VideoThumbnailCard(move: move)
                    .frame(width: 300)

                Text("Compact Card")
                    .font(.ibmPlexMono(size: 20, weight: .bold))

                // Compact
                CompactMoveCard(move: move)
                    .frame(width: 150)

                Text("List Row Card")
                    .font(.ibmPlexMono(size: 20, weight: .bold))

                // List row
                MoveListRowCard(move: move)
                    .padding(.horizontal)

                Text("State Pills")
                    .font(.ibmPlexMono(size: 20, weight: .bold))

                HStack(spacing: 8) {
                    EnhancedStatePillView(learningState: "NEW")
                    EnhancedStatePillView(learningState: "LEARNING")
                    EnhancedStatePillView(learningState: "MASTERY")
                }
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
    }
}
#endif
