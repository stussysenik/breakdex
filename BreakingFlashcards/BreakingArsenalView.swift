// BreakingArsenalView.swift — Library hub for browsing moves and combos
//
// Hub with two Liquid Glass card links routing to MoveListView and ComboListView.
// Each card: SF Symbol icon (left) + text (center) + chevron (right).
// Practice summary below shows counts of what's waiting to learn/practice.
// 5 visual anchors: nav title, MOVES glass, COMBOS glass, divider, practice summary.

import SwiftUI
import SwiftData

struct BreakingArsenalView: View {

    @Query(sort: \Move.createdAt, order: .reverse) private var moves: [Move]
    @Query private var combos: [Combo]

    // MARK: - Practice Summary Counts

    private var newCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .newState }.count
    }

    private var learningCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .learning }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {

                // MOVES — glass card with icon + chevron
                NavigationLink {
                    MoveListView()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "figure.dance")
                            .font(.title2)
                            .foregroundColor(.accent)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("MOVES")
                                .font(.ibmPlexMono(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text("\(moves.count) recorded")
                                .font(.ibmPlexMono(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .glassCard(radius: Radius.md)
                }

                // COMBOS — glass card with icon + chevron
                NavigationLink {
                    ComboListView()
                } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundColor(.accent)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("COMBOS")
                                .font(.ibmPlexMono(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text("\(combos.count) built")
                                .font(.ibmPlexMono(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.md)
                    .glassCard(radius: Radius.md)
                }

                Divider()
                    .padding(.vertical, Spacing.xs)

                // PRACTICE SUMMARY — what's waiting
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("TO PRACTICE")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("\(newCount) to learn · \(learningCount) practicing")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.vertical, Spacing.lg)
            .navigationTitle("LIBRARY")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview("Arsenal - Light") {
    BreakingArsenalView()
        .modelContainer(.preview)
}

#Preview("Arsenal - Dark") {
    BreakingArsenalView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
