//
//  ReviewView.swift
//  BreakingFlashcards
//
//  Created by Claude on 10/10/25.
//

import SwiftUI
import CoreData
import OSLog

/// Clean review view using shared components and clean architecture
/// Displays learning states and provides navigation to review sessions
struct ReviewView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - State
    @StateObject private var viewModel: ReviewViewModel

    // MARK: - Initialization
    init() {
        _viewModel = StateObject(wrappedValue: ReviewViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.hasContentToReview {
                    emptyStateView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - View Components
    private var loadingView: some View {
        VStack(spacing: 20) {
            SharedLoadingView.withMessage("Loading review data...", style: .circular)

            Text("Preparing your learning materials")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.secondary)
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "book.closed",
            title: "Nothing to Review Yet",
            description: "Add some moves and create combos to start reviewing your breaking skills!"
        )
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // MARK: - Progress Header
                progressHeader
                    .padding(.horizontal, Spacing.md)

                // MARK: - Moves Section
                if viewModel.hasMovesToReview {
                    movesSection
                }

                // MARK: - Combos Section
                if viewModel.hasCombosToReview {
                    combosSection
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: Spacing.md) {
            // Overall mastery progress
            ProgressRingView(
                progress: viewModel.overallMasteryProgress,
                fillColor: .stateMastery,
                lineWidth: 12,
                fontSize: 18,
                size: 100
            )

            Text("Overall Mastery")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)

            // Quick stats row
            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.totalMovesCount)")
                        .font(.titleSmall)
                        .foregroundColor(.textPrimary)
                    Text("Moves")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.totalCombosCount)")
                        .font(.titleSmall)
                        .foregroundColor(.textPrimary)
                    Text("Combos")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.masteryMovesCount + viewModel.masteryCombosCount)")
                        .font(.titleSmall)
                        .foregroundColor(.stateMastery)
                    Text("Mastered")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .cardContainer()
    }

    private var movesSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeaderView(
                title: "MOVES",
                count: viewModel.totalMovesCount
            )
            .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                learningStateCard(
                    title: "NEW",
                    count: viewModel.newMovesCount,
                    total: viewModel.totalMovesCount,
                    color: .stateNew,
                    learningState: "NEW",
                    type: .moves
                )

                learningStateCard(
                    title: "LEARNING",
                    count: viewModel.learningMovesCount,
                    total: viewModel.totalMovesCount,
                    color: .stateLearning,
                    learningState: "LEARNING",
                    type: .moves
                )

                learningStateCard(
                    title: "MASTERY",
                    count: viewModel.masteryMovesCount,
                    total: viewModel.totalMovesCount,
                    color: .stateMastery,
                    learningState: "MASTERY",
                    type: .moves
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private var combosSection: some View {
        VStack(spacing: Spacing.md) {
            SectionHeaderView(
                title: "COMBOS",
                count: viewModel.totalCombosCount
            )
            .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.sm) {
                learningStateCard(
                    title: "NEW",
                    count: viewModel.newCombosCount,
                    total: viewModel.totalCombosCount,
                    color: .stateNew,
                    learningState: "NEW",
                    type: .combos
                )

                learningStateCard(
                    title: "LEARNING",
                    count: viewModel.learningCombosCount,
                    total: viewModel.totalCombosCount,
                    color: .stateLearning,
                    learningState: "LEARNING",
                    type: .combos
                )

                learningStateCard(
                    title: "MASTERY",
                    count: viewModel.masteryCombosCount,
                    total: viewModel.totalCombosCount,
                    color: .stateMastery,
                    learningState: "MASTERY",
                    type: .combos
                )
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func learningStateCard(
        title: String,
        count: Int,
        total: Int,
        color: Color,
        learningState: String,
        type: ReviewType
    ) -> some View {
        let progress = total > 0 ? Double(count) / Double(total) : 0.0

        return NavigationLink {
            FlashcardReviewView(learningState: learningState, reviewType: type)
        } label: {
            HStack(spacing: Spacing.md) {
                // Color indicator and title
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)

                    Text(title)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.neutralGray200)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(width: 80, height: 8)

                // Count
                Text("\(count)")
                    .font(.titleSmall)
                    .foregroundColor(color)
                    .frame(minWidth: 30, alignment: .trailing)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .cardContainer(padding: Spacing.md)
        }
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Review Statistics View
extension ReviewView {
    /// Optional statistics view for debugging or advanced users
    private var statisticsView: some View {
        VStack(spacing: 12) {
            Text("Review Statistics")
                .font(.ibmPlexMono(size: 18, weight: .bold))
                .foregroundColor(.textPrimary)

            let stats = viewModel.reviewStatistics

            VStack(spacing: 8) {
                HStack {
                    Text("Total Moves:")
                        .font(.ibmPlexMono(size: 14))
                    Spacer()
                    Text("\(stats.totalMoves)")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                }

                HStack {
                    Text("Total Combos:")
                        .font(.ibmPlexMono(size: 14))
                    Spacer()
                    Text("\(stats.totalCombos)")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                }

                HStack {
                    Text("Total Items:")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                    Spacer()
                    Text("\(stats.totalItems)")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
#Preview("Review View") {
    ReviewView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}