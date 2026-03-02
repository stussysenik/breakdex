import SwiftUI
import SwiftData

struct ReviewView: View {

    @Query(sort: \Move.createdAt, order: .reverse)
    private var moves: [Move]

    @Query(sort: \Combo.name)
    private var combos: [Combo]

    @Query(sort: \ComboMove.sequenceIndex)
    private var comboMoves: [ComboMove]

    @Query(sort: \Review.reviewedAt, order: .reverse)
    private var reviews: [Review]

    private struct ReviewCategory: Identifiable {
        let id = UUID()
        let label: String
        let state: String
        let count: Int
        let reviewType: ReviewType
    }

    private var comboStatsByID: [PersistentIdentifier: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    private var comboStates: [LearningState] {
        combos.map { comboStatsByID[$0.persistentModelID]?.learningState ?? .newState }
    }

    private var moveCategories: [ReviewCategory] {
        LearningState.allCases.map { state in
            ReviewCategory(
                label: state.displayText,
                state: state.rawValue,
                count: moves.filter { LearningState.resolve(from: $0.learningState) == state }.count,
                reviewType: .moves
            )
        }
    }

    private var comboCategories: [ReviewCategory] {
        LearningState.allCases.map { state in
            ReviewCategory(
                label: state.displayText,
                state: state.rawValue,
                count: comboStates.filter { $0 == state }.count,
                reviewType: .combos
            )
        }
    }

    private var totalReviewCount: Int {
        reviews.count
    }

    private var moveReviewCount: Int {
        reviews.filter { review in
            let type = (review.reviewType ?? "").uppercased()
            return type == "MOVE" || (type.isEmpty && review.move != nil)
        }.count
    }

    private var comboReviewCount: Int {
        reviews.filter { ($0.reviewType ?? "").uppercased() == "COMBO" }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    reviewTotalsCard
                    reviewGroupCard(title: "MOVES", categories: moveCategories)
                    reviewGroupCard(title: "COMBOS", categories: comboCategories)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("REVIEW")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(totalReviewCount + moves.count + combos.count)
    }

    private var reviewTotalsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("REVIEW HISTORY")
                .font(.ibmPlexMono(size: 13, weight: .bold))
                .foregroundColor(.textPrimary)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("\(totalReviewCount)")
                    .font(.ibmPlexMono(size: 34, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("total")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.textSecondary)
            }

            Divider()

            HStack(spacing: Spacing.lg) {
                reviewMetric(label: "Move Reviews", value: moveReviewCount)
                reviewMetric(label: "Combo Reviews", value: comboReviewCount)
            }
        }
        .padding(Spacing.lg)
        .glassCard(radius: Radius.md)
    }

    private func reviewMetric(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(value)")
                .font(.ibmPlexMono(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
            Text(label.uppercased())
                .font(.ibmPlexMono(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewGroupCard(title: String, categories: [ReviewCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.ibmPlexMono(size: 14, weight: .bold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    NavigationLink(destination: FlashcardReviewView(learningState: category.state, reviewType: category.reviewType)) {
                        HStack(spacing: Spacing.md) {
                            Text(category.label)
                                .font(.ibmPlexMono(size: 18, weight: .medium))
                                .foregroundColor(.textPrimary)

                            Spacer(minLength: Spacing.md)

                            Text("\(category.count)")
                                .font(.ibmPlexMono(size: 18, weight: .bold))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.vertical, Spacing.md)
                    }
                    .buttonStyle(.plain)

                    if index < categories.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .glassCard(radius: Radius.md)
    }
}

#Preview("Review Hub - Light") {
    ReviewView()
        .modelContainer(.preview)
}

#Preview("Review Hub - Dark") {
    ReviewView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
