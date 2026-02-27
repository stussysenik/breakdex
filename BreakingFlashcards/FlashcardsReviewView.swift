// FlashcardsReviewView.swift — Spaced repetition review screen for Breakdex
//
// This file implements the core practice loop of the app: showing breakdancing
// moves or combos one at a time and letting the user rate their performance.
// The rating ("AGAIN", "HARD", "GOOD") drives the spaced repetition state machine:
//
//   AGAIN: demotes to NEW (start over — the move needs more work)
//   HARD:  sets to LEARNING (struggled but making progress)
//   GOOD:  promotes one level: NEW -> LEARNING, LEARNING -> MASTERY
//
// The user enters this screen from the MainView by selecting a learning state
// category (NEW, LEARNING, or MASTERY) and a review type (moves or combos).
// Cards are presented sequentially with slide-in/slide-out transitions.
//
// ARCHITECTURE:
//   FlashcardReviewView (coordinator) - routes between MoveReviewView, ComboReviewView,
//                                        EmptyReviewView, CompletedReviewView
//   MoveReviewView (single move card) - video player + review buttons
//   ComboReviewView (combo card)      - video player + combo sequence timeline + review buttons
//   ReviewButtons (shared)            - AGAIN/HARD/GOOD buttons with state mutation logic
//   EmptyReviewView                   - "no items" placeholder
//   CompletedReviewView               - "all done" celebration screen
//
// DATA FLOW:
//   SwiftData @Query fetches moves/combos filtered by learning state.
//   ReviewButtons directly mutate the Move.learningState property via SwiftData,
//   then call modelContext.save() to persist. The onReviewComplete callback advances
//   to the next card.
//
// COMBO LEARNING STATE:
//   Combos don't store their own learning state. Instead, it's derived from their
//   constituent moves using ComboStatsBuilder (ComboStats.swift):
//     - ALL moves are MASTERY -> combo is MASTERY
//     - ANY move is NEW -> combo is NEW
//     - ANY move is LEARNING -> combo is LEARNING
//   When reviewing a combo, ALL its moves' states are updated (not just one).
//
// CONNECTED FILES:
//   - Models.swift: Move, Combo, ComboMove SwiftData models
//   - LearningState.swift: LearningState enum with resolve() methods
//   - ComboStats.swift: ComboStatsBuilder computes combo learning state from child moves
//   - CustomVideoPlayerView.swift: Video playback for move/combo preview
//   - StatePillView.swift: Colored pill showing a move's current learning state
//   - TimelineNodeView.swift: Numbered circle node in the combo sequence timeline
//   - DesignSystem.swift: Color.textPrimary, .buttonAgain/Hard/Good, Font.ibmPlexMono,
//     .liquidGlass modifier, Spacing tokens
//   - Motion.swift: AppMotion.easeStandard (via .appMotion modifier) for card transitions

import SwiftUI
import SwiftData

// MARK: - ReviewButtonStyle

/// Custom button style for the review action buttons (AGAIN, HARD, GOOD).
/// Applies glass card shape + shared press animation.
struct ReviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassCard()
            .pressAnimation(configuration.isPressed)
    }
}

// MARK: - ReviewType Enum

/// Distinguishes whether the review session covers individual moves or combos.
/// Passed to FlashcardReviewView to control which @Query results are displayed
/// and which review logic (move vs. combo) is applied.
enum ReviewType {
    case moves   // Review individual Move objects
    case combos  // Review Combo objects (multiple moves in sequence)
}

// MARK: - FlashcardReviewView (Main Coordinator)

/// The top-level review screen. Fetches moves or combos from SwiftData,
/// filters by learning state, and presents them one at a time with
/// slide-in/slide-out transitions. Tracks progress via reviewedIndices
/// and shows a completion screen when all items have been reviewed.
struct FlashcardReviewView: View {

    // -----------------------------------------------------------------------
    // MARK: - Injected Configuration
    // -----------------------------------------------------------------------

    /// The raw string learning state to filter by (e.g. "NEW", "LEARNING", "MASTERY").
    /// Passed from the MainView when the user taps a learning state category.
    /// Used to construct the @Query predicate and as the navigation title.
    let learningState: String

    /// Whether this session reviews individual moves or combos.
    /// Controls which branch of the body renders and which review logic applies.
    let reviewType: ReviewType

    // -----------------------------------------------------------------------
    // MARK: - SwiftData Queries
    // -----------------------------------------------------------------------

    /// All moves matching the specified learning state, sorted by creation date.
    /// The @Query macro auto-fetches from the SwiftData model context and
    /// updates the view whenever the underlying data changes.
    /// The predicate filter is constructed in init() using the learningState parameter.
    @Query private var moves: [Move]

    /// All combos, sorted by name. Unlike moves, combos don't have a stored learning state —
    /// it's computed from their child moves. So we fetch ALL combos and filter in filteredCombos.
    @Query private var combos: [Combo]

    /// All ComboMove join objects, sorted by sequence index.
    /// Used by ComboStatsBuilder to compute each combo's aggregate learning state.
    @Query private var comboMoves: [ComboMove]

    // -----------------------------------------------------------------------
    // MARK: - Environment and State
    // -----------------------------------------------------------------------

    /// The SwiftData model context for saving state changes after reviews.
    @Environment(\.modelContext) private var modelContext

    /// Index of the currently displayed card in the moves or filteredCombos array.
    /// Incremented by moveToNext() after each review. When it exceeds the array
    /// bounds, the CompletedReviewView is shown.
    @State private var currentIndex = 0

    /// Set of indices that have been reviewed in this session.
    /// Used to determine when all items have been reviewed (show completion screen).
    /// Prevents infinite loops when wrapping around the array.
    @State private var reviewedIndices: Set<Int> = []

    // -----------------------------------------------------------------------
    // MARK: - Initializer
    // -----------------------------------------------------------------------

    /// Creates a review session for the specified learning state and type.
    ///
    /// - Parameters:
    ///   - learningState: The raw string state to filter by ("NEW", "LEARNING", "MASTERY").
    ///   - reviewType: Whether to review moves or combos (default: .moves).
    ///
    /// The init constructs three @Query configurations:
    ///   1. Moves: filtered by learningState using a #Predicate, sorted by createdAt.
    ///   2. Combos: all combos sorted by name (filtering happens in filteredCombos).
    ///   3. ComboMoves: all join entries sorted by sequenceIndex (for ComboStatsBuilder).
    ///
    /// Note: #Predicate requires a local let binding (`let state = learningState`)
    /// because the macro captures by value and can't reference `self.learningState`.
    init(learningState: String, reviewType: ReviewType = .moves) {
        self.learningState = learningState
        self.reviewType = reviewType

        // Capture learningState in a local for the #Predicate closure.
        let state = learningState
        self._moves = Query(
            filter: #Predicate<Move> { move in
                move.learningState == state
            },
            sort: \Move.createdAt
        )

        // Combos and ComboMoves are fetched without filtering — combo learning state
        // is computed, not stored. See filteredCombos below.
        self._combos = Query(sort: \Combo.name)
        self._comboMoves = Query(sort: \ComboMove.sequenceIndex)
    }

    // -----------------------------------------------------------------------
    // MARK: - Computed Properties
    // -----------------------------------------------------------------------

    /// Converts the raw string learningState to a type-safe LearningState enum.
    /// Used by filteredCombos to compare against computed combo learning states.
    /// Falls back to .newState if the string is unrecognized.
    private var resolvedLearningState: LearningState {
        LearningState.resolve(from: learningState)
    }

    /// Precomputed dictionary mapping each combo's PersistentIdentifier to its ComboStats.
    /// Built in a single pass by ComboStatsBuilder.build(from:), which iterates all
    /// ComboMove entries and aggregates move counts and learning states per combo.
    /// This avoids N+1 query problems when computing many combos' stats.
    private var comboStatsByID: [PersistentIdentifier: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    /// Looks up a combo's derived learning state from the precomputed stats dictionary.
    /// Falls back to .newState if the combo has no stats entry (e.g. no moves).
    ///
    /// - Parameter combo: The Combo to get the learning state for.
    /// - Returns: The composite LearningState (NEW if any move is NEW, MASTERY if all are, etc.).
    private func getComboLearningState(for combo: Combo) -> LearningState {
        comboStatsByID[combo.persistentModelID]?.learningState ?? .newState
    }

    /// Combos filtered to only those whose computed learning state matches
    /// the requested learningState. Unlike moves (which are filtered by @Query),
    /// combos must be filtered in-memory because their state is derived, not stored.
    private var filteredCombos: [Combo] {
        combos.filter { getComboLearningState(for: $0) == resolvedLearningState }
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// Routes to the appropriate sub-view based on review type and progress:
    ///
    /// For MOVES:
    ///   - If currentIndex is valid: show MoveReviewView for the current move.
    ///   - If the moves array is empty: show EmptyReviewView ("no items").
    ///   - Otherwise (all reviewed): show CompletedReviewView ("great work!").
    ///
    /// For COMBOS:
    ///   - Same three-state logic, but using filteredCombos instead of moves.
    ///
    /// Card transitions use .asymmetric: new cards slide in from the trailing edge
    /// with a fade, outgoing cards slide out to the leading edge with a fade.
    /// This creates a natural left-to-right "deck of cards" progression.
    ///
    /// The .id modifier on each card forces SwiftUI to create a new view instance
    /// when the index changes, which triggers the transition animation.
    var body: some View {
        Group {
            if reviewType == .moves {
                // -- MOVES REVIEW --
                if moves.indices.contains(currentIndex) {
                    // There's a valid move at the current index — show its review card.
                    let move = moves[currentIndex]
                    MoveReviewView(
                        move: move,
                        learningState: learningState,
                        onReviewComplete: { moveToNext() }
                    )
                    // Asymmetric transition: slide in from right, slide out to left.
                    // .combined(with: .opacity) adds a fade for smoothness.
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    // Unique ID forces view re-creation on index change, triggering the transition.
                    .id("move-\(currentIndex)")
                }
                else if moves.isEmpty {
                    // No moves match this learning state — show empty placeholder.
                    EmptyReviewView(type: "moves", learningState: learningState)
                } else {
                    // All moves have been reviewed — show completion celebration.
                    CompletedReviewView(type: "moves", learningState: learningState)
                }
            } else {
                // -- COMBOS REVIEW --
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
        // .appMotion(currentIndex) applies an easeStandard animation (0.18s)
        // when currentIndex changes, but ONLY if the user hasn't enabled
        // "Reduce Motion" in iOS Accessibility settings (AppMotionModifier checks this).
        .appMotion(currentIndex)
    }

    // -----------------------------------------------------------------------
    // MARK: - Navigation Logic
    // -----------------------------------------------------------------------

    /// Advances to the next card after a review is completed.
    ///
    /// Logic:
    ///   1. Add the current index to reviewedIndices.
    ///   2. If there are more items ahead, increment the index.
    ///   3. If we've reached the end:
    ///      - If all items have been reviewed, set index past the end to show CompletedReviewView.
    ///      - Otherwise, wrap to 0 to show any unreviewed items from the beginning.
    ///
    /// Note: After a review, the move's learningState may have changed (e.g. NEW -> LEARNING),
    /// which means the @Query results may have shrunk. SwiftUI will re-evaluate the body
    /// and the .indices check will handle this gracefully.
    private func moveToNext() {
        // Record this index as reviewed.
        reviewedIndices.insert(currentIndex)

        // Get the current count based on review type.
        let totalItems = reviewType == .moves ? moves.count : filteredCombos.count
        if currentIndex < totalItems - 1 {
            // More items ahead — advance to the next one.
            currentIndex += 1
        } else {
            // Reached the end of the list.
            if reviewedIndices.count >= totalItems {
                // All items reviewed — set index past the end to trigger CompletedReviewView.
                currentIndex = totalItems
            } else {
                // Some items at the beginning haven't been reviewed yet — wrap around.
                currentIndex = 0
            }
        }
    }
}

// MARK: - MoveReviewView (Single Move Card)

/// Displays a single move for review: name, learning state pill, creation date,
/// video player, and review buttons (AGAIN/HARD/GOOD).
///
/// This is a stateless presentation view — all state mutation happens in ReviewButtons.
struct MoveReviewView: View {

    /// The Move model to display. Contains name, learningState, createdAt, videoReference.
    let move: Move

    /// The learning state string for the navigation title (e.g. "NEW").
    let learningState: String

    /// Callback fired when the user taps a review button and the state is saved.
    /// Triggers FlashcardReviewView.moveToNext() to advance to the next card.
    let onReviewComplete: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(move.name ?? "Unknown Move")
                .font(.ibmPlexMono(size: 18, weight: .bold))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, Spacing.sm)

            CustomVideoPlayerView(move: move)
                .frame(height: 320)
                .cornerRadius(Radius.lg)
                .padding(.horizontal, Spacing.screenEdge)

            Spacer(minLength: 40)

            ReviewButtons(
                learningState: learningState,
                move: move,
                reviewType: .moves,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 40)
        }
        .navigationTitle(learningState)
    }
}

// MARK: - ComboReviewView (Combo Card)

/// Displays a combo for review: name, move count, video player (for the active move),
/// horizontal combo sequence timeline, and review buttons.
///
/// The combo sequence timeline shows numbered circles (TimelineNodeView) connected
/// by horizontal lines. Tapping a node selects that move and shows its video.
struct ComboReviewView: View {

    /// SwiftData model context for potential data operations.
    @Environment(\.modelContext) private var modelContext

    /// The Combo model to display. Contains name and comboMoves relationship.
    let combo: Combo

    /// The learning state string for the navigation title.
    let learningState: String

    /// Callback fired when the user taps a review button.
    let onReviewComplete: () -> Void

    /// Index of the currently selected move in the combo sequence.
    /// Defaults to 0 (first move). Tapping a TimelineNodeView changes this.
    /// Optional because the combo might have no moves.
    @State private var activeMoveIndex: Int? = 0

    /// Flattened array of Move objects extracted from the combo's ComboMove relationships.
    /// Sorted by sequenceIndex and populated in onAppear via loadComboMoves().
    /// This avoids repeatedly sorting the relationship array on every body evaluation.
    @State private var comboMovesList: [Move] = []

    var body: some View {
        VStack(spacing: Spacing.md) {
            // -- Header: combo name + move count --
            VStack(spacing: Spacing.sm) {
                Text(combo.name ?? "Unknown Combo")
                    .font(.ibmPlexMono(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(comboMovesList.count) moves")
                    .font(.ibmPlexMono(size: 13))
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, Spacing.sm)

            // -- Video player --
            if let activeMove = activeMove {
                CustomVideoPlayerView(move: activeMove)
                    .frame(height: 320)
                    .cornerRadius(Radius.lg)
                    .padding(.horizontal, Spacing.screenEdge)
            } else {
                ContentUnavailableView("Select a move to see a preview", systemImage: "video.slash")
                    .frame(height: 320)
                    .padding(.horizontal, Spacing.screenEdge)
            }

            // -- Combo sequence (ASCII tree) --
            if !comboMovesList.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(comboMovesList.enumerated()), id: \.element.id) { index, move in
                        HStack(spacing: 0) {
                            Text(index == comboMovesList.count - 1 ? "└─ " : "├─ ")
                                .font(.ibmPlexMono(size: 14))
                                .foregroundColor(.secondary)
                            Text("\(index + 1). \(move.name ?? "?")")
                                .font(.ibmPlexMono(size: 14, weight: activeMoveIndex == index ? .bold : .regular))
                                .foregroundColor(activeMoveIndex == index ? .textPrimary : .secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { activeMoveIndex = index }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
            }

            Spacer(minLength: 40)

            ReviewButtons(
                learningState: learningState,
                combo: combo,
                reviewType: .combos,
                onReviewComplete: onReviewComplete
            )
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 40)
        }
        .navigationTitle(learningState)
        .onAppear {
            loadComboMoves()
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Computed Properties
    // -----------------------------------------------------------------------

    /// Returns the currently selected Move from the combo sequence,
    /// or nil if the index is invalid or the combo has no moves.
    private var activeMove: Move? {
        guard let activeMoveIndex, comboMovesList.indices.contains(activeMoveIndex) else {
            return nil
        }
        return comboMovesList[activeMoveIndex]
    }

    // -----------------------------------------------------------------------
    // MARK: - Data Loading
    // -----------------------------------------------------------------------

    /// Extracts and sorts the Move objects from the combo's ComboMove relationships.
    /// combo.comboMoves is Optional<[ComboMove]> — each ComboMove has a sequenceIndex
    /// (position in the combo) and an optional move reference.
    /// We sort by sequenceIndex and extract the Move objects, discarding any
    /// ComboMove entries where the move relationship is nil (defensive).
    private func loadComboMoves() {
        self.comboMovesList = (combo.comboMoves ?? [])
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
            .compactMap { $0.move }
    }
}

// MARK: - EmptyReviewView

/// Placeholder shown when there are no items to review in the selected category.
/// For example, if the user has no "NEW" moves, this view says "No moves to review."
struct EmptyReviewView: View {

    /// The item type label: "moves" or "combos".
    let type: String

    /// The learning state for the navigation title.
    let learningState: String

    var body: some View {
        VStack {
            Text("No \(type) to review in this category.")
                .font(.ibmPlexMono(size: 16))
                .foregroundColor(.secondary)
            // Push text to the top.
            Spacer()
        }
        .navigationTitle(learningState)
    }
}

// MARK: - CompletedReviewView

/// Celebration screen shown when all items in the category have been reviewed.
/// Shows a green checkmark, congratulations text, and a summary message.
struct CompletedReviewView: View {

    /// The item type label: "moves" or "combos".
    let type: String

    /// The learning state for the navigation title and summary message.
    let learningState: String

    var body: some View {
        VStack(spacing: 24) {
            // Large green checkmark — universally recognized "success" symbol.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            // Congratulations headline in IBM Plex Mono bold.
            Text("Great work!")
                .font(.ibmPlexMono(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)

            // Summary text explaining what was completed.
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

// MARK: - ReviewButtons (Shared Review Action Buttons)

/// The three review action buttons: AGAIN (red), HARD (yellow), GOOD (green).
/// These are the core spaced-repetition controls. Each button mutates the
/// learning state of the reviewed item(s) according to the SRS progression:
///
///   AGAIN: reset to "NEW" (needs more practice)
///   HARD:  set to "LEARNING" (struggled but progressing)
///   GOOD:  promote one level (NEW -> LEARNING, LEARNING -> MASTERY)
///
/// For moves: only the single move's state is updated.
/// For combos: ALL constituent moves' states are updated.
///
/// After mutating, the changes are persisted via modelContext.save() and the
/// onReviewComplete callback advances to the next card.
struct ReviewButtons: View {

    /// SwiftData model context for persisting state changes after a review.
    @Environment(\.modelContext) private var modelContext

    /// The learning state category being reviewed (for display/logging).
    let learningState: String

    /// The individual Move being reviewed (nil for combo reviews).
    let move: Move?

    /// The Combo being reviewed (nil for move reviews).
    let combo: Combo?

    /// Whether this is a moves or combos review session.
    let reviewType: ReviewType

    /// Callback fired after the state is successfully saved.
    let onReviewComplete: () -> Void

    // -----------------------------------------------------------------------
    // MARK: - Initializer
    // -----------------------------------------------------------------------

    /// Creates review buttons for either a move or combo review.
    ///
    /// - Parameters:
    ///   - learningState: The category string (e.g. "NEW").
    ///   - move: The Move to review (for .moves type, nil otherwise).
    ///   - combo: The Combo to review (for .combos type, nil otherwise).
    ///   - reviewType: .moves or .combos.
    ///   - onReviewComplete: Called after successful save.
    init(learningState: String, move: Move? = nil, combo: Combo? = nil, reviewType: ReviewType, onReviewComplete: @escaping () -> Void) {
        self.learningState = learningState
        self.move = move
        self.combo = combo
        self.reviewType = reviewType
        self.onReviewComplete = onReviewComplete
    }

    // -----------------------------------------------------------------------
    // MARK: - Review Logic
    // -----------------------------------------------------------------------

    /// Routes the review to the appropriate handler based on review type.
    ///
    /// - Parameter difficulty: The user's rating: "AGAIN", "HARD", or "GOOD".
    func handleReview(difficulty: String) {
        if reviewType == .moves {
            handleMoveReview(difficulty: difficulty)
        } else {
            handleComboReview(difficulty: difficulty)
        }
    }

    /// Processes a review rating for a single move.
    ///
    /// State transitions:
    ///   - "AGAIN": Always resets to "NEW" (start over).
    ///   - "HARD": Always sets to "LEARNING" (in progress).
    ///   - "GOOD": Promotes one level:
    ///     - "NEW" -> "LEARNING"
    ///     - "LEARNING" -> "MASTERY"
    ///     - "MASTERY" stays "MASTERY" (no change — already at the top)
    ///
    /// After updating the state, saves via modelContext and calls onReviewComplete.
    func handleMoveReview(difficulty: String) {
        guard let move = move else { return }

        switch difficulty {
        case "AGAIN":
            // Demote to NEW — the user needs to relearn this move.
            move.learningState = "NEW"
        case "HARD":
            // Set to LEARNING — the user struggled but is making progress.
            move.learningState = "LEARNING"
        case "GOOD":
            // Promote one level. The conditional logic prevents promoting past MASTERY.
            if move.learningState == "LEARNING" {
                move.learningState = "MASTERY"
            } else if move.learningState == "NEW" {
                move.learningState = "LEARNING"
            }
            // If already "MASTERY", no change.
        default:
            break
        }

        do {
            // Persist the state change to SwiftData's backing store.
            try modelContext.save()
            // Advance to the next card.
            onReviewComplete()
        } catch {
            print("Error updating move: \(error)")
        }
    }

    /// Processes a review rating for a combo by updating ALL constituent moves.
    ///
    /// A combo review affects every move in the combo, not just the combo itself
    /// (since combos don't have their own stored learning state). This means tapping
    /// "GOOD" on a combo promotes all its moves one level.
    ///
    /// The same state transition rules apply as handleMoveReview, but applied
    /// to every move in the combo's sequence.
    func handleComboReview(difficulty: String) {
        guard let combo = combo else { return }

        // Get all ComboMove join objects for this combo.
        let comboMoveEntities = combo.comboMoves ?? []

        // Apply the rating to each move in the combo.
        for comboMove in comboMoveEntities {
            // Skip ComboMove entries with no associated Move (defensive).
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

        do {
            try modelContext.save()
            onReviewComplete()
        } catch {
            print("Error updating combo moves: \(error)")
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// AGAIN (red) / HARD (yellow) / GOOD (green) — data-driven to avoid repetition.
    private static let reviewOptions: [(label: String, color: Color, difficulty: String)] = [
        ("AGAIN", .buttonAgain, "AGAIN"),
        ("HARD",  .buttonHard,  "HARD"),
        ("GOOD",  .buttonGood,  "GOOD"),
    ]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(Self.reviewOptions, id: \.difficulty) { option in
                Button(action: { handleReview(difficulty: option.difficulty) }) {
                    Text(option.label)
                        .font(.ibmPlexMono(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(option.color)
                }
                .buttonStyle(ReviewButtonStyle())
            }
        }
    }
}

// MARK: - Preview

/// Xcode Preview showing the review screen for "NEW" moves.
/// Uses the in-memory preview ModelContainer with sample data (3 moves: Windmill,
/// Swipe, Halo across different learning states; see Models.swift for details).
#Preview("Review NEW - Light") {
    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
        .modelContainer(.preview)
}

#Preview("Review NEW - Dark") {
    FlashcardReviewView(learningState: "NEW", reviewType: .moves)
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}

#Preview("Review LEARNING - Light") {
    FlashcardReviewView(learningState: "LEARNING", reviewType: .moves)
        .modelContainer(.preview)
}

#Preview("Review MASTERY - Light") {
    FlashcardReviewView(learningState: "MASTERY", reviewType: .moves)
        .modelContainer(.preview)
}
