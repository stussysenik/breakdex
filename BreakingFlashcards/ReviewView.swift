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

    // Count moves by learning state
    private var newMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .newState }.count
    }

    private var learningMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .learning }.count
    }

    private var masteryMovesCount: Int {
        moves.filter { LearningState.resolve(from: $0.learningState) == .mastery }.count
    }

    // Count combos by learning state
    private var newCombosCount: Int {
        comboStates.filter { $0 == .newState }.count
    }

    private var learningCombosCount: Int {
        comboStates.filter { $0 == .learning }.count
    }

    private var masteryCombosCount: Int {
        comboStates.filter { $0 == .mastery }.count
    }

    private func getComboLearningState(for combo: Combo) -> LearningState {
        comboStatsByID[combo.objectID]?.learningState ?? .newState
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("MOVES")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // NEW moves row
                NavigationLink(destination: FlashcardReviewView(learningState: "NEW", reviewType: .moves)) {
                    HStack {
                        Text("NEW")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(newMovesCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                // LEARNING moves row
                NavigationLink(destination: FlashcardReviewView(learningState: "LEARNING", reviewType: .moves)) {
                    HStack {
                        Text("LEARNING")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(learningMovesCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                // MASTERY moves row
                NavigationLink(destination: FlashcardReviewView(learningState: "MASTERY", reviewType: .moves)) {
                    HStack {
                        Text("MASTERY")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(masteryMovesCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                Divider()
                    .padding(.horizontal, 20)

                Text("COMBOS")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // NEW combos row
                NavigationLink(destination: FlashcardReviewView(learningState: "NEW", reviewType: .combos)) {
                    HStack {
                        Text("NEW")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(newCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                // LEARNING combos row
                NavigationLink(destination: FlashcardReviewView(learningState: "LEARNING", reviewType: .combos)) {
                    HStack {
                        Text("LEARNING")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(learningCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                // MASTERY combos row
                NavigationLink(destination: FlashcardReviewView(learningState: "MASTERY", reviewType: .combos)) {
                    HStack {
                        Text("MASTERY")
                            .font(.ibmPlexMono(size: 20))

                        Spacer()

                        Text("(\(masteryCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 24)
            .navigationTitle("REVIEW")
            .navigationBarTitleDisplayMode(.inline)
        }
        .appMotion(newMovesCount + newCombosCount + learningMovesCount + learningCombosCount + masteryMovesCount + masteryCombosCount)
    }
}
