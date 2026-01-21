import SwiftUI
import CoreData
import AVKit
import OSLog

// MARK: - Flashcard Review View
/// Main flashcard review interface with swipe gestures and game-like interactions.
/// Uses SM-2 spaced repetition algorithm for optimal learning.

struct FlashcardReviewView: View {

    // MARK: - Properties

    let learningState: String
    let reviewType: ReviewType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: FlashcardReviewViewModel
    @ObservedObject private var progress = LearningProgress.shared
    @ObservedObject private var accessibility = AccessibilityManager.shared

    // MARK: - Initialization

    init(learningState: String, reviewType: ReviewType) {
        self.learningState = learningState
        self.reviewType = reviewType
        self._viewModel = StateObject(wrappedValue: FlashcardReviewViewModel(
            learningState: learningState,
            reviewType: reviewType,
            viewContext: PersistenceController.shared.container.viewContext
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.isSessionComplete {
                sessionCompleteView
            } else if let currentMove = viewModel.currentMove {
                reviewContent(move: currentMove)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                progressIndicator
            }
        }
        .onAppear {
            viewModel.loadMoves()
        }
    }

    // MARK: - Progress Indicator

    @ViewBuilder
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.currentIndex + 1)/\(viewModel.totalCards)")
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.backgroundSecondary)

                    Capsule()
                        .fill(Color.accent)
                        .frame(width: geo.size.width * viewModel.sessionProgress)
                }
            }
            .frame(width: 60, height: 4)
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading cards...")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.success)

            Text("All caught up!")
                .font(.ibmPlexMono(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("No cards due for review")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.textSecondary)

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Review Content

    @ViewBuilder
    private func reviewContent(move: Move) -> some View {
        VStack(spacing: 0) {
            // Card area
            FlashcardCardView(
                move: move,
                isRevealed: viewModel.isCardRevealed,
                onTap: {
                    withAnimation(accessibility.effectiveAnimation) {
                        viewModel.revealCard()
                    }
                }
            )
            .padding(.horizontal, Spacing.md)
            .gesture(swipeGesture)

            Spacer(minLength: 20)

            // Rating buttons (shown after reveal)
            if viewModel.isCardRevealed {
                RatingButtonsView(
                    currentState: viewModel.currentSpacedRepetitionState,
                    onRate: { rating in
                        viewModel.rateCard(rating)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(accessibility.effectiveAnimation, value: viewModel.isCardRevealed)
            } else {
                // Tap to reveal prompt
                tapToRevealPrompt
            }

            Spacer(minLength: 40)

            // Progress stats at bottom
            dailyProgressView
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Tap to Reveal Prompt

    @ViewBuilder
    private var tapToRevealPrompt: some View {
        VStack(spacing: 12) {
            Text("Tap card to reveal")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.textSecondary)

            HStack(spacing: 20) {
                swipeHint(direction: .left, label: "Again")
                swipeHint(direction: .right, label: "Good")
                swipeHint(direction: .up, label: "Easy")
            }
        }
        .padding()
    }

    @ViewBuilder
    private func swipeHint(direction: SwipeDirection, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: direction.icon)
                .font(.system(size: 12))
            Text(label)
                .font(.ibmPlexMono(size: 12))
        }
        .foregroundColor(.textSecondary)
    }

    // MARK: - Daily Progress View

    @ViewBuilder
    private var dailyProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Today's Progress")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(progress.todayReviews)/\(LearningProgress.dailyGoal)")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.backgroundSecondary)

                    Capsule()
                        .fill(progress.isDailyGoalComplete ? Color.success : Color.accent)
                        .frame(width: geo.size.width * progress.dailyGoalProgress)
                }
            }
            .frame(height: 8)

            // XP and Streak
            HStack {
                Label("\(progress.totalXP) XP", systemImage: "star.fill")
                    .font(.ibmPlexMono(size: 11))
                    .foregroundColor(.accent)

                Spacer()

                if progress.currentStreak > 0 {
                    Label("\(progress.currentStreak) day streak", systemImage: "flame.fill")
                        .font(.ibmPlexMono(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                guard viewModel.isCardRevealed else { return }

                let horizontal = value.translation.width
                let vertical = value.translation.height

                // Determine swipe direction
                if abs(horizontal) > abs(vertical) {
                    // Horizontal swipe
                    if horizontal < -50 {
                        // Left = Again
                        viewModel.rateCard(.again)
                    } else if horizontal > 50 {
                        // Right = Good
                        viewModel.rateCard(.good)
                    }
                } else {
                    // Vertical swipe
                    if vertical < -50 {
                        // Up = Easy
                        viewModel.rateCard(.easy)
                    }
                }
            }
    }

    // MARK: - Session Complete View

    @ViewBuilder
    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            // Celebration icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundColor(.accent)
                .scaleEffect(1.0)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.5)
                        .repeatForever(autoreverses: true),
                    value: true
                )

            Text("Session Complete!")
                .font(.ibmPlexMono(size: 28, weight: .bold))
                .foregroundColor(.textPrimary)

            // Stats
            VStack(spacing: 16) {
                statRow(label: "Cards Reviewed", value: "\(viewModel.sessionStats.cardsReviewed)")
                statRow(label: "Accuracy", value: String(format: "%.0f%%", viewModel.sessionStats.accuracy))
                statRow(label: "Time", value: viewModel.sessionStats.formattedDuration)
                statRow(label: "XP Earned", value: "+\(viewModel.sessionXPEarned)")
            }
            .padding()
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.mediumRadius))

            // Continue button
            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(.ibmPlexMono(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.smallRadius))
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding()
    }

    @ViewBuilder
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .font(.ibmPlexMono(size: 14, weight: .semibold))
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Swipe Direction

private enum SwipeDirection {
    case left, right, up

    var icon: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Flashcard Review") {
    NavigationStack {
        FlashcardReviewView(learningState: "NEW", reviewType: .moves)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
