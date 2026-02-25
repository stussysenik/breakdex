//
//  FlashcardsReviewView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import CoreData

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Motion-library inspired button style for review buttons
struct ReviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
    }
}

enum ReviewType {
    case moves
    case combos
}

struct FlashcardReviewView: View {
    let learningState: String
    let reviewType: ReviewType

    // Fetch moves matching the specified learning state.
    @FetchRequest private var moves: FetchedResults<Move>
    @FetchRequest private var combos: FetchedResults<Combo>
    @FetchRequest private var comboMoves: FetchedResults<ComboMove>

    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentIndex = 0
    @State private var reviewedIndices: Set<Int> = []

    init(learningState: String, reviewType: ReviewType = .moves) {
        self.learningState = learningState
        self.reviewType = reviewType
        
        self._moves = FetchRequest<Move>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: true)],
            predicate: NSPredicate(format: "learningState == %@", learningState)
        )
        
        self._combos = FetchRequest<Combo>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Combo.name, ascending: true)],
            predicate: NSPredicate(value: true)
        )

        self._comboMoves = FetchRequest<ComboMove>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)],
            predicate: NSPredicate(value: true)
        )
    }

    private var resolvedLearningState: LearningState {
        LearningState.resolve(from: learningState)
    }

    private var comboStatsByID: [NSManagedObjectID: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    private func getComboLearningState(for combo: Combo) -> LearningState {
        comboStatsByID[combo.objectID]?.learningState ?? .newState
    }

    private var filteredCombos: [Combo] {
        combos.filter { getComboLearningState(for: $0) == resolvedLearningState }
    }

    var body: some View {
        Group {
            if reviewType == .moves {
                if moves.indices.contains(currentIndex) {
                    let move = moves[currentIndex]
                    MoveReviewView(
                        move: move,
                        learningState: learningState,
                        onReviewComplete: { moveToNext() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("move-\(currentIndex)") // Force SwiftUI to recreate view for animation
                }
                else if moves.isEmpty {
                    EmptyReviewView(type: "moves", learningState: learningState)
                } else {
                    CompletedReviewView(type: "moves", learningState: learningState)
                }
            } else {
                if filteredCombos.indices.contains(currentIndex) {
                    let combo = filteredCombos[currentIndex]
                    ComboReviewView(
                        combo: combo,
                        learningState: learningState,
                        onReviewComplete: { moveToNext() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("combo-\(currentIndex)") // Force SwiftUI to recreate view for animation
                }
                else if filteredCombos.isEmpty {
                    EmptyReviewView(type: "combos", learningState: learningState)
                } else {
                    CompletedReviewView(type: "combos", learningState: learningState)
                }
            }
        }
        .appMotion(currentIndex)
    }
    
    private func moveToNext() {
        // Mark current item as reviewed
        reviewedIndices.insert(currentIndex)
        
        let totalItems = reviewType == .moves ? moves.count : filteredCombos.count
        if currentIndex < totalItems - 1 {
            currentIndex += 1
        } else {
            // Only show completion if all items have been reviewed at least once
            // This ensures users see the deck completion message only after reviewing all cards
            if reviewedIndices.count >= totalItems {
                currentIndex = totalItems // Show CompletedReviewView
            } else {
                // Continue cycling through unreviewed items
                currentIndex = 0
            }
        }
    }
}

struct MoveReviewView: View {
    let move: Move
    let learningState: String
    let onReviewComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Display the move's name and date with state
            VStack(spacing: 8) {
                HStack {
                    Text(move.name ?? "Unknown Move")
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    StatePillView(learningState: move.learningState)
                        .fixedSize()
                }
                .padding(.horizontal, 20)
                
                Text(move.createdAt ?? Date(), style: .date)
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Video player with proper audio lifecycle management
            CustomVideoPlayerView(move: move)
                .frame(height: 350)
                .cornerRadius(16)
                .padding(.horizontal, 20)

            Spacer(minLength: 40)

            // Review action buttons
            ReviewButtons(
                learningState: learningState, 
                move: move, 
                reviewType: .moves,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Extra space to avoid bottom navigation
        }
        .navigationTitle(learningState)
    }
}

struct ComboReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let combo: Combo
    let learningState: String
    let onReviewComplete: () -> Void
    
    @State private var activeMoveIndex: Int? = 0
    @State private var comboMoves: [Move] = []

    var body: some View {
        VStack(spacing: 16) {
            // Display the combo's name
            VStack(spacing: 8) {
                Text(combo.name ?? "Unknown Combo")
                    .font(.ibmPlexMono(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("\(comboMoves.count) moves")
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Video Player Section
            if let activeMove = activeMove {
                CustomVideoPlayerView(move: activeMove)
                    .frame(height: 320)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
            } else {
                ContentUnavailableView("Select a move to see a preview", systemImage: "video.slash")
                    .frame(height: 320)
                    .padding(.horizontal, 20)
            }

            // Timeline Section
            if !comboMoves.isEmpty {
                VStack(spacing: 12) {
                    Text("Combo Sequence")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, move in
                                VStack(spacing: 6) {
                                    TimelineNodeView(
                                        sequenceNumber: index + 1,
                                        isActive: activeMoveIndex == index,
                                        onDelete: {}, // No delete functionality in review
                                        move: move,
                                        showDelete: false
                                    )
                                    .onTapGesture {
                                        activeMoveIndex = index
                                    }

                                    Text(move.name ?? "Move")
                                        .font(.ibmPlexMono(size: 12))
                                        .foregroundColor(.textPrimary)
                                        .frame(width: 60)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }

                                if index < comboMoves.count - 1 {
                                    Rectangle()
                                        .frame(width: 20, height: 2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 80)
                }
            }

            Spacer(minLength: 40)

            // Review action buttons for combo
            ReviewButtons(
                learningState: learningState, 
                combo: combo, 
                reviewType: .combos,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Extra space to avoid bottom navigation
        }
        .navigationTitle(learningState)
        .onAppear {
            loadComboMoves()
        }
    }

    private var activeMove: Move? {
        guard let activeMoveIndex, comboMoves.indices.contains(activeMoveIndex) else {
            return nil
        }
        return comboMoves[activeMoveIndex]
    }

    private func loadComboMoves() {
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ComboMove.sequenceIndex, ascending: true)]

        do {
            let comboMoveEntities = try viewContext.fetch(fetchRequest)
            self.comboMoves = comboMoveEntities.compactMap { $0.move }
        } catch {
            print("Error loading combo moves: \(error)")
            self.comboMoves = []
        }
    }
}

struct EmptyReviewView: View {
    let type: String
    let learningState: String

    var body: some View {
        VStack {
            Text("No \(type) to review in this category.")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle(learningState)
    }
}

struct CompletedReviewView: View {
    let type: String
    let learningState: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Great work!")
                .font(.ibmPlexMono(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            
            Text("You've completed all \(type) in the \(learningState) category.")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
        .navigationTitle(learningState)
    }
}

struct ReviewButtons: View {
    @Environment(\.managedObjectContext) private var viewContext

    let learningState: String
    let move: Move?
    let combo: Combo?
    let reviewType: ReviewType
    let onReviewComplete: () -> Void

    init(learningState: String, move: Move? = nil, combo: Combo? = nil, reviewType: ReviewType, onReviewComplete: @escaping () -> Void) {
        self.learningState = learningState
        self.move = move
        self.combo = combo
        self.reviewType = reviewType
        self.onReviewComplete = onReviewComplete
    }

    func handleReview(difficulty: String) {
        if reviewType == .moves {
            handleMoveReview(difficulty: difficulty)
        } else {
            handleComboReview(difficulty: difficulty)
        }
    }

    func handleMoveReview(difficulty: String) {
        guard let move = move else { return }

        // Update the learning state based on difficulty
        switch difficulty {
        case "AGAIN":
            move.learningState = "NEW"
        case "HARD":
            move.learningState = "LEARNING"
        case "GOOD":
            if move.learningState == "LEARNING" {
                move.learningState = "MASTERY"
            } else if move.learningState == "NEW" {
                move.learningState = "LEARNING"
            }
        default:
            break
        }

        // Save the changes
        do {
            try viewContext.save()
            onReviewComplete() // Move to next item
        } catch {
            print("Error updating move: \(error)")
        }
    }

    func handleComboReview(difficulty: String) {
        guard let combo = combo else { return }

        // Get all moves in the combo
        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)
            
            // Update all moves in the combo based on difficulty
            for comboMove in comboMoves {
                guard let move = comboMove.move else { continue }
                
                switch difficulty {
                case "AGAIN":
                    move.learningState = "NEW"
                case "HARD":
                    move.learningState = "LEARNING"
                case "GOOD":
                    if move.learningState == "LEARNING" {
                        move.learningState = "MASTERY"
                    } else if move.learningState == "NEW" {
                        move.learningState = "LEARNING"
                    }
                default:
                    break
                }
            }

            try viewContext.save()
            onReviewComplete() // Move to next item
        } catch {
            print("Error updating combo moves: \(error)")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                handleReview(difficulty: "AGAIN")
            }) {
                Text("AGAIN")
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color.buttonAgain)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(ReviewButtonStyle())

            Button(action: {
                handleReview(difficulty: "HARD")
            }) {
                Text("HARD")
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color.buttonHard)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(ReviewButtonStyle())

            Button(action: {
                handleReview(difficulty: "GOOD")
            }) {
                Text("GOOD")
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color.buttonGood)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .buttonStyle(ReviewButtonStyle())
        }
    }
}

#Preview {
    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
