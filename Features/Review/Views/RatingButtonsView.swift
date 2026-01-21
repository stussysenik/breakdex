import SwiftUI

// MARK: - Rating Buttons View
/// Displays rating buttons for flashcard review with interval previews.
/// Supports swipe gesture hints and accessibility features.

struct RatingButtonsView: View {

    // MARK: - Properties

    let currentState: SpacedRepetitionState
    var onRate: ((RecallRating) -> Void)?

    @ObservedObject private var accessibility = AccessibilityManager.shared
    @State private var intervalPreviews: [RecallRating: String] = [:]

    // MARK: - Body

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Interval previews header
            Text("How well did you remember?")
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.textSecondary)

            // Rating buttons grid
            HStack(spacing: Spacing.sm) {
                ForEach(RecallRating.allCases) { rating in
                    RatingButton(
                        rating: rating,
                        intervalPreview: intervalPreviews[rating] ?? "...",
                        onTap: {
                            HapticFeedback.actionHaptic()
                            onRate?(rating)
                        }
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .onAppear {
            calculateIntervalPreviews()
        }
        .onChange(of: currentState) { _, newState in
            calculateIntervalPreviews()
        }
    }

    // MARK: - Methods

    private func calculateIntervalPreviews() {
        intervalPreviews = SM2Algorithm.previewNextIntervals(for: currentState)
    }
}

// MARK: - Rating Button

struct RatingButton: View {

    let rating: RecallRating
    let intervalPreview: String
    var onTap: (() -> Void)?

    @State private var isPressed = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 6) {
                // Icon
                Image(systemName: rating.sfSymbol)
                    .font(.system(size: 24))
                    .foregroundColor(ratingColor)

                // Label
                Text(rating.label)
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)

                // Interval preview
                Text(intervalPreview)
                    .font(.ibmPlexMono(size: 10))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.smallRadius)
                    .stroke(ratingColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(rating.label): \(rating.description)")
        .accessibilityHint("Next review in \(intervalPreview)")
    }

    private var ratingColor: Color {
        switch rating {
        case .again:
            return accessibility.highContrastMode ? .stateNewHighContrast : .error
        case .hard:
            return accessibility.highContrastMode ? .stateLearningHighContrast : .warning
        case .good:
            return accessibility.highContrastMode ? .stateMasteryHighContrast : .success
        case .easy:
            return accessibility.highContrastMode ? .accessibleAccent : .accent
        }
    }

    private var backgroundColor: Color {
        isPressed ? ratingColor.opacity(0.15) : Color.backgroundSecondary
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(MotionSystem.micro, value: configuration.isPressed)
    }
}

// MARK: - Compact Rating Buttons
/// A more compact horizontal layout for smaller screens

struct CompactRatingButtons: View {

    let currentState: SpacedRepetitionState
    var onRate: ((RecallRating) -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RecallRating.allCases) { rating in
                CompactRatingButton(rating: rating) {
                    HapticFeedback.actionHaptic()
                    onRate?(rating)
                }
            }
        }
    }
}

struct CompactRatingButton: View {

    let rating: RecallRating
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: rating.sfSymbol)
                    .font(.system(size: 14))
                Text(rating.label)
                    .font(.ibmPlexMono(size: 12, weight: .medium))
            }
            .foregroundColor(ratingColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ratingColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var ratingColor: Color {
        switch rating {
        case .again: return .error
        case .hard: return .warning
        case .good: return .success
        case .easy: return .accent
        }
    }
}

// MARK: - Swipe Rating Overlay
/// Visual feedback during swipe gestures

struct SwipeRatingOverlay: View {

    let dragOffset: CGSize
    let threshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Left swipe - Again
            if dragOffset.width < -threshold / 2 {
                ratingIndicator(rating: .again)
                    .offset(x: -60)
                    .opacity(leftOpacity)
            }

            // Right swipe - Good
            if dragOffset.width > threshold / 2 {
                ratingIndicator(rating: .good)
                    .offset(x: 60)
                    .opacity(rightOpacity)
            }

            // Up swipe - Easy
            if dragOffset.height < -threshold / 2 {
                ratingIndicator(rating: .easy)
                    .offset(y: -60)
                    .opacity(upOpacity)
            }
        }
        .animation(MotionSystem.micro, value: dragOffset)
    }

    @ViewBuilder
    private func ratingIndicator(rating: RecallRating) -> some View {
        VStack(spacing: 4) {
            Image(systemName: rating.sfSymbol)
                .font(.system(size: 32, weight: .semibold))
            Text(rating.label)
                .font(.ibmPlexMono(size: 14, weight: .bold))
        }
        .foregroundColor(ratingColor(for: rating))
        .padding()
        .background(ratingColor(for: rating).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.mediumRadius))
    }

    private func ratingColor(for rating: RecallRating) -> Color {
        switch rating {
        case .again: return .error
        case .hard: return .warning
        case .good: return .success
        case .easy: return .accent
        }
    }

    private var leftOpacity: Double {
        min(1.0, abs(dragOffset.width) / threshold)
    }

    private var rightOpacity: Double {
        min(1.0, abs(dragOffset.width) / threshold)
    }

    private var upOpacity: Double {
        min(1.0, abs(dragOffset.height) / threshold)
    }
}

// MARK: - Preview

#if DEBUG
struct RatingButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Standard rating buttons
            RatingButtonsView(
                currentState: SpacedRepetitionState(),
                onRate: { rating in
                    print("Rated: \(rating.label)")
                }
            )

            Divider()

            // Compact version
            CompactRatingButtons(
                currentState: SpacedRepetitionState(),
                onRate: { rating in
                    print("Rated: \(rating.label)")
                }
            )

            Divider()

            // Swipe overlay demo
            SwipeRatingOverlay(dragOffset: CGSize(width: -120, height: 0))
                .frame(height: 100)
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
#endif
