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

    // Count moves by learning state
    private var newMovesCount: Int {
        moves.filter { $0.learningState == "NEW" }.count
    }

    private var learningMovesCount: Int {
        moves.filter { $0.learningState == "LEARNING" }.count
    }

    private var masteryMovesCount: Int {
        moves.filter { $0.learningState == "MASTERY" }.count
    }

    // Count combos by learning state
    private var newCombosCount: Int {
        combos.filter { getComboLearningState(for: $0) == "NEW" }.count
    }

    private var learningCombosCount: Int {
        combos.filter { getComboLearningState(for: $0) == "LEARNING" }.count
    }

    private var masteryCombosCount: Int {
        combos.filter { getComboLearningState(for: $0) == "MASTERY" }.count
    }

    private func getComboLearningState(for combo: Combo) -> String {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            let moveStates = comboMoves.compactMap { $0.move?.learningState }

            if moveStates.isEmpty {
                return "NEW"
            }

            if moveStates.allSatisfy({ $0 == "MASTERY" }) {
                return "MASTERY"
            } else if moveStates.contains(where: { $0 == "NEW" }) {
                return "NEW"
            } else if moveStates.contains(where: { $0 == "LEARNING" }) {
                return "LEARNING"
            } else {
                return "NEW"
            }
        } catch {
            return "NEW"
        }
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
    }
}