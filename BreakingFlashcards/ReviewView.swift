//
//  ReviewView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData

struct ReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Combo.name, ascending: true)],
        animation: .default)
    private var combos: FetchedResults<Combo>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)],
        animation: .default)
    private var comboMoves: FetchedResults<ComboMove>

    private var comboStatsByID: [NSManagedObjectID: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    private var comboStates: [LearningState] {
        combos.map { comboStatsByID[$0.objectID]?.learningState ?? .newState }
    }

    private var newMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .newState }.count
    }

    private var learningMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .learning }.count
    }

    private var masteryMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .mastery }.count
    }

    private var newCombosCount: Int {
        comboStates.filter { $0 == .newState }.count
    }

    private var learningCombosCount: Int {
        comboStates.filter { $0 == .learning }.count
    }

    private var masteryCombosCount: Int {
        comboStates.filter { $0 == .mastery }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // MOVES section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("MOVES")
                            .font(.caption)
                            .tracking(2)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, Spacing.lg)

                        VStack(spacing: 0) {
                            reviewRow(label: "New", color: .stateNew, count: newMovesCount,
                                      destination: FlashcardReviewView(learningState: "NEW", reviewType: .moves))
                            rowDivider()
                            reviewRow(label: "Learning", color: .stateLearning, count: learningMovesCount,
                                      destination: FlashcardReviewView(learningState: "LEARNING", reviewType: .moves))
                            rowDivider()
                            reviewRow(label: "Mastery", color: .stateMastery, count: masteryMovesCount,
                                      destination: FlashcardReviewView(learningState: "MASTERY", reviewType: .moves))
                        }
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .elevation(Elevation.low)
                        .padding(.horizontal, Spacing.lg)
                    }

                    // COMBOS section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("COMBOS")
                            .font(.caption)
                            .tracking(2)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, Spacing.lg)

                        VStack(spacing: 0) {
                            reviewRow(label: "New", color: .stateNew, count: newCombosCount,
                                      destination: FlashcardReviewView(learningState: "NEW", reviewType: .combos))
                            rowDivider()
                            reviewRow(label: "Learning", color: .stateLearning, count: learningCombosCount,
                                      destination: FlashcardReviewView(learningState: "LEARNING", reviewType: .combos))
                            rowDivider()
                            reviewRow(label: "Mastery", color: .stateMastery, count: masteryCombosCount,
                                      destination: FlashcardReviewView(learningState: "MASTERY", reviewType: .combos))
                        }
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .elevation(Elevation.low)
                        .padding(.horizontal, Spacing.lg)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("REVIEW")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(newMovesCount + newCombosCount + learningMovesCount + learningCombosCount + masteryMovesCount + masteryCombosCount)
    }

    private func reviewRow<D: View>(label: String, color: Color, count: Int, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Spacing.md) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                Text(label)
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(.ibmPlexMono(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 4)
        }
    }

    private func rowDivider() -> some View {
        Divider().padding(.leading, Spacing.md + 10 + Spacing.md)
    }
}
