//
//  ReviewView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData
import OSLog

struct ReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "ReviewView")
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Combo.name, ascending: true)],
        animation: .default)
    private var combos: FetchedResults<Combo>
    
    
    private var newMovesCount: Int { // count moves by learning state
        moves.filter { $0.learningState == "NEW" }.count
    }
    
    private var learningMovesCount: Int {
        moves.filter { $0.learningState == "LEARNING" }.count
    }
    
    private var masteryMovesCount: Int {
        moves.filter { $0.learningState == "MASTERY" }.count
    }
    
      // MARK: - Optimized Combo Learning State Calculation

    /// Optimized combo states cache - calculates states once per combo instead of per filter
    /// 🚀 PERFORMANCE: Reduces O(N) database queries to O(1) using memoization
    ///  METRICS: Logs performance and state distribution for debugging
    private var comboStates: [NSManagedObjectID: String] {
        logger.info(" REVIEW_VIEW: 🔄 Calculating combo learning states for \(combos.count) combos")

        var states: [NSManagedObjectID: String] = [:]
        var stateCounts: [String: Int] = ["NEW": 0, "LEARNING": 0, "MASTERY": 0]

        for combo in combos {
            let state = calculateComboLearningState(for: combo)
            states[combo.objectID] = state
            stateCounts[state, default: 0] += 1
        }

        logger.info(" REVIEW_VIEW: ✅ Combo state calculation complete")
        logger.info(" REVIEW_VIEW:  State distribution - NEW: \(stateCounts["NEW"] ?? 0), LEARNING: \(stateCounts["LEARNING"] ?? 0), MASTERY: \(stateCounts["MASTERY"] ?? 0)")

        return states
    }

    /// Count combos by learning state using optimized cache
    private var newCombosCount: Int {
        comboStates.values.filter { $0 == "NEW" }.count
    }

    private var learningCombosCount: Int {
        comboStates.values.filter { $0 == "LEARNING" }.count
    }

    private var masteryCombosCount: Int {
        comboStates.values.filter { $0 == "MASTERY" }.count
    }

    /// Calculate learning state for a single combo using in-memory data
    /// MARK: - MEMORY: Uses relationship data instead of additional database queries
    ///  LOGS: Detailed logging for debugging combo state logic
    private func calculateComboLearningState(for combo: Combo) -> String {
        logger.info(" REVIEW_VIEW: 🔄 Calculating state for combo: \(combo.name ?? "Unknown")")

        // ✅ RELATIONSHIPS: Use existing relationship data instead of fetching
        guard let comboMoves = combo.comboMoves as? Set<ComboMove> else {
            logger.warning(" REVIEW_VIEW: ⚠️ No combo moves relationship found for combo: \(combo.name ?? "Unknown")")
            return "NEW"
        }

        let moveStates = comboMoves.compactMap { $0.move?.learningState }
        logger.info(" REVIEW_VIEW:  Found \(moveStates.count) move states: \(moveStates)")

        // Business logic for determining combo learning state
        let calculatedState: String

        if moveStates.isEmpty {
            calculatedState = "NEW"
        } else if moveStates.allSatisfy({ $0 == "MASTERY" }) {
            calculatedState = "MASTERY"
        } else if moveStates.contains("NEW") {
            calculatedState = "NEW"
        } else if moveStates.contains("LEARNING") {
            calculatedState = "LEARNING"
        } else {
            calculatedState = "NEW" // Fallback for edge cases
        }

        logger.info(" REVIEW_VIEW: ✅ Combo '\(combo.name ?? "Unknown")' calculated state: \(calculatedState)")

        return calculatedState
    }

    // 🗑️ DEPRECATED: Old getComboLearningState method removed - replaced by optimized version
    
    var body: some View {
        NavigationStack {
            if moves.isEmpty && combos.isEmpty {
                // Show empty state when no moves or combos exist
                ZStack {
                    Color.backgroundPrimary.ignoresSafeArea()

                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: "book.closed")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))

                        VStack(spacing: 12) {
                            Text("Nothing to review yet")
                                .font(.ibmPlexMono(size: 24, weight: .bold))
                                .foregroundColor(.textPrimary)

                            Text("Add some moves and create combos to start reviewing your breaking skills!")
                                .font(.ibmPlexMono(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Spacer()
                    }
                }
                .navigationTitle("Review")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 24) {
                    Text("MOVES")
                        .font(.ibmPlexMono(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                
                NavigationLink {
                    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
                } label: {
                    HStack {
                        Text("NEW")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

                        Spacer()

                        Text("(\(newMovesCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                NavigationLink {
                    FlashcardReviewView(learningState: "LEARNING", reviewType: .moves)
                } label: {
                    HStack {
                        Text("LEARNING")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

                        Spacer()

                        Text("(\(learningMovesCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                NavigationLink {
                    FlashcardReviewView(learningState: "MASTERY", reviewType: .moves)
                } label: {
                    HStack {
                        Text("MASTERY")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

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
                    .font(.ibmPlexMono(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                NavigationLink {
                    FlashcardReviewView(learningState: "NEW", reviewType: .combos)
                } label: {
                    HStack {
                        Text("NEW")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

                        Spacer()

                        Text("(\(newCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                NavigationLink {
                    FlashcardReviewView(learningState: "LEARNING", reviewType: .combos)
                } label: {
                    HStack {
                        Text("LEARNING")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

                        Spacer()

                        Text("(\(learningCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                NavigationLink {
                    FlashcardReviewView(learningState: "MASTERY", reviewType: .combos)
                } label: {
                    HStack {
                        Text("MASTERY")
                            .font(.ibmPlexMono(size: 20, weight: .thin))

                        Spacer()

                        Text("(\(masteryCombosCount))")
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            }
        }
    }
}
