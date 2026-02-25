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
                    .id("move-\(currentIndex)")
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
                    .id("combo-\(currentIndex)")
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
        reviewedIndices.insert(currentIndex)

        let totalItems = reviewType == .moves ? moves.count : filteredCombos.count
        if currentIndex < totalItems - 1 {
            currentIndex += 1
        } else {
            if reviewedIndices.count >= totalItems {
                currentIndex = totalItems
            } else {
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
        VStack(spacing: Spacing.md) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.sm) {
                StatePillView(learningState: move.learningState)

                Text(move.name ?? "Unknown Move")
                    .font(.titleSmall)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(move.createdAt ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            // Video
            CustomVideoPlayerView(move: move)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.lg)

            // Quiz-style buttons
            ReviewButtons(
                learningState: learningState,
                move: move,
                reviewType: .moves,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
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
        VStack(spacing: Spacing.md) {
            // Header
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(combo.name ?? "Unknown Combo")
                    .font(.titleSmall)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(comboMoves.count) moves")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            // Video Player
            if let activeMove = activeMove {
                CustomVideoPlayerView(move: activeMove)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, Spacing.lg)
            } else {
                ContentUnavailableView("Select a move to see a preview", systemImage: "video.slash")
                    .frame(height: 200)
                    .padding(.horizontal, Spacing.lg)
            }

            // Timeline
            if !comboMoves.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Text("SEQUENCE")
                        .font(.caption)
                        .tracking(2)
                        .foregroundColor(.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, move in
                                VStack(spacing: Spacing.sm) {
                                    TimelineNodeView(
                                        sequenceNumber: index + 1,
                                        isActive: activeMoveIndex == index,
                                        onDelete: {},
                                        move: move,
                                        showDelete: false
                                    )
                                    .onTapGesture {
                                        activeMoveIndex = index
                                    }

                                    Text(move.name ?? "Move")
                                        .font(.caption)
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
                        .padding(.horizontal, Spacing.lg)
                    }
                    .frame(height: 80)
                }
            }

            Spacer(minLength: Spacing.lg)

            // Quiz-style buttons
            ReviewButtons(
                learningState: learningState,
                combo: combo,
                reviewType: .combos,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
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
        VStack(spacing: Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary)
            Text("No \(type) to review")
                .font(.titleSmall)
                .foregroundColor(.textPrimary)
            Text("Nothing in the \(learningState) category yet")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.top, Spacing.xxl)
        .navigationTitle(learningState)
    }
}

struct CompletedReviewView: View {
    let type: String
    let learningState: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.stateMastery)

            Text("Great work!")
                .font(.titleSmall)
                .foregroundColor(.textPrimary)

            Text("You've completed all \(type) in the \(learningState) category.")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(Spacing.lg)
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

        do {
            try viewContext.save()
            onReviewComplete()
        } catch {
            print("Error updating move: \(error)")
        }
    }

    func handleComboReview(difficulty: String) {
        guard let combo = combo else { return }

        let fetchRequest = NSFetchRequest<ComboMove>(entityName: "ComboMove")
        fetchRequest.predicate = NSPredicate(format: "combo == %@", combo)

        do {
            let comboMoves = try viewContext.fetch(fetchRequest)

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
            onReviewComplete()
        } catch {
            print("Error updating combo moves: \(error)")
        }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            quizCard(
                label: "AGAIN",
                subtitle: "Reset",
                color: .buttonAgain,
                action: { handleReview(difficulty: "AGAIN") }
            )
            quizCard(
                label: "HARD",
                subtitle: "Keep drilling",
                color: .buttonHard,
                action: { handleReview(difficulty: "HARD") }
            )
            quizCard(
                label: "GOOD",
                subtitle: "Got it",
                color: .buttonGood,
                action: { handleReview(difficulty: "GOOD") }
            )
        }
    }

    private func quizCard(label: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.7)
                }
                Spacer()
            }
            .foregroundColor(color)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(color, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(ReviewButtonStyle())
    }
}

#Preview {
    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
