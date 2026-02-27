// ReviewView.swift — Spaced repetition review hub
//
// This is the "Review" tab — the gateway to flashcard-style practice sessions.
// It shows a summary of all moves and combos grouped by their learning state
// (NEW, LEARNING, MASTERY) with counts, and lets users tap into a category
// to start a FlashcardReviewView session for that group.
//
// ARCHITECTURE ROLE:
// ReviewView is a read-only dashboard that aggregates data from three SwiftData
// queries (moves, combos, comboMoves) to display category counts. It doesn't
// modify any data — the actual review logic (state transitions, saving reviews)
// lives in FlashcardReviewView and its child ReviewButtons.
//
// DATA FLOW:
//   @Query fetches moves, combos, and comboMoves from SwiftData
//   -> ComboStatsBuilder.build() computes each combo's learning state from its child moves
//   -> moveCategories / comboCategories group items by LearningState with counts
//   -> NavigationLinks route to FlashcardReviewView filtered by state and type
//
// COMBO STATE COMPUTATION:
// Unlike moves (which store their own learningState string), combos derive their
// learning state from their child moves via ComboStats:
//   - ALL moves are MASTERY -> combo is MASTERY
//   - ANY move is NEW -> combo is NEW (weakest link principle)
//   - ANY move is LEARNING -> combo is LEARNING
//   - Empty combo -> defaults to NEW
// This is computed on-the-fly rather than stored, so it always reflects current state.
//
// SWIFTUI PATTERNS:
// - @Query: SwiftData's property wrapper that automatically fetches and observes
//   model objects. When the underlying data changes (e.g., after a review), the
//   query results update and SwiftUI re-renders the view. Sort descriptors are
//   specified inline: \Move.createdAt sorts by creation date, .reverse = newest first.
//
// - @Environment(\.modelContext): Provides access to the SwiftData ModelContext
//   for read/write operations. Not used directly in this view's body, but required
//   to be available in the environment for @Query to function.
//
// - .appMotion(): Accessibility-aware animation modifier from Motion.swift.
//   Animates changes when the total item count changes, but respects the user's
//   "Reduce Motion" accessibility setting by disabling animations when enabled.

import SwiftUI
import SwiftData

/// Review hub view — displays move and combo counts by learning state,
/// with navigation links to start flashcard review sessions.
struct ReviewView: View {

    // MARK: - Environment & Queries

    /// The SwiftData model context from the environment.
    /// Injected by .modelContainer() in BreakingFlashcardsApp.
    /// Required for @Query to function — @Query reads from the model context's store.
    @Environment(\.modelContext) private var modelContext

    /// All moves in the database, sorted by creation date (newest first).
    /// @Query automatically observes the SwiftData store — when a move is added,
    /// deleted, or its learningState changes (e.g., after a review), this array
    /// updates and the view re-renders with new counts.
    /// The sort descriptor \Move.createdAt with .reverse ensures consistent ordering.
    @Query(sort: \Move.createdAt, order: .reverse)
    private var moves: [Move]

    /// All combos in the database, sorted alphabetically by name.
    /// Used to iterate and compute each combo's learning state from its child moves.
    @Query(sort: \Combo.name)
    private var combos: [Combo]

    /// All ComboMove join entries, sorted by sequence index.
    /// These link moves to combos with ordering. We fetch ALL of them and pass
    /// them to ComboStatsBuilder, which groups them by combo in a single pass
    /// to avoid N+1 query problems (fetching comboMoves per combo individually).
    @Query(sort: \ComboMove.sequenceIndex)
    private var comboMoves: [ComboMove]

    // MARK: - Computed Properties

    /// Builds a lookup dictionary mapping each combo's PersistentIdentifier to its ComboStats.
    /// PersistentIdentifier is SwiftData's stable identity type for model objects.
    ///
    /// ComboStatsBuilder.build() iterates all ComboMove objects once, grouping by combo,
    /// and accumulates move counts and learning states. This is more efficient than
    /// querying per-combo because it's a single O(n) pass over all join entries.
    ///
    /// This is a computed property, so it recalculates whenever `comboMoves` changes.
    /// In a production app with thousands of combos, this could be memoized, but for
    /// a typical b-boy arsenal (dozens of combos) the overhead is negligible.
    private var comboStatsByID: [PersistentIdentifier: ComboStats] {
        ComboStatsBuilder.build(from: comboMoves)
    }

    /// Maps each combo to its computed learning state.
    /// For each combo, looks up its stats in the dictionary and extracts the composite
    /// learning state. Falls back to .newState if the combo has no stats (no moves attached).
    ///
    /// This array is parallel to the `combos` array — comboStates[i] corresponds to combos[i].
    /// It's used by comboCategories to count how many combos are in each learning state.
    private var comboStates: [LearningState] {
        combos.map { comboStatsByID[$0.persistentModelID]?.learningState ?? .newState }
    }

    // MARK: - ReviewCategory Model

    /// A local data model representing one row in the review dashboard.
    /// Each row shows a learning state label, the count of items in that state,
    /// and routes to a FlashcardReviewView filtered by that state and type.
    ///
    /// Identifiable conformance (via `let id = UUID()`) is required by ForEach to
    /// uniquely identify each row. The UUID is generated fresh each time the computed
    /// property creates new categories, which is fine since these are ephemeral display models.
    private struct ReviewCategory: Identifiable {
        let id = UUID()           // Unique identifier for ForEach
        let label: String         // Display text (e.g. "NEW", "LEARNING", "MASTERY")
        let state: String         // Raw state string passed to FlashcardReviewView for filtering
        let count: Int            // Number of items in this learning state
        let reviewType: ReviewType  // .moves or .combos — determines which flashcard mode to use
    }

    /// Creates one ReviewCategory per LearningState for moves.
    /// Iterates LearningState.allCases (NEW, LEARNING, MASTERY) and counts how many
    /// moves match each state by resolving each move's raw learningState string.
    ///
    /// Example result: [
    ///   ReviewCategory(label: "NEW", state: "NEW", count: 5, reviewType: .moves),
    ///   ReviewCategory(label: "LEARNING", state: "LEARNING", count: 3, reviewType: .moves),
    ///   ReviewCategory(label: "MASTERY", state: "MASTERY", count: 2, reviewType: .moves)
    /// ]
    private var moveCategories: [ReviewCategory] {
        LearningState.allCases.map { state in
            ReviewCategory(
                label: state.displayText,
                state: state.rawValue,
                // Filter moves whose resolved learning state matches this category's state.
                // LearningState.resolve(from:) safely converts the raw string to an enum case.
                count: moves.filter { LearningState.resolve(from: $0.learningState) == state }.count,
                reviewType: .moves
            )
        }
    }

    /// Creates one ReviewCategory per LearningState for combos.
    /// Uses the pre-computed comboStates array (derived from child moves) rather than
    /// a stored property on the Combo model itself.
    private var comboCategories: [ReviewCategory] {
        LearningState.allCases.map { state in
            ReviewCategory(
                label: state.displayText,
                state: state.rawValue,
                // Filter the parallel comboStates array to count combos in this state.
                count: comboStates.filter { $0 == state }.count,
                reviewType: .combos
            )
        }
    }

    // MARK: - Body

    var body: some View {
        // NavigationStack provides the navigation context for pushing into
        // FlashcardReviewView when the user taps a category row.
        NavigationStack {
            VStack(spacing: 24) {

                // --- MOVES SECTION ---

                // Section header — left-aligned, bold, using design system color token.
                Text("MOVES")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)  // Dynamic color from DesignSystem.swift
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // One row per learning state (NEW, LEARNING, MASTERY) showing the count.
                // ForEach iterates moveCategories, which conforms to Identifiable.
                ForEach(moveCategories) { category in
                    // NavigationLink wraps the row — tapping it pushes FlashcardReviewView.
                    // The destination is initialized with the category's state string and review type,
                    // which FlashcardReviewView uses to filter its @Query for matching moves.
                    NavigationLink(destination: FlashcardReviewView(learningState: category.state, reviewType: category.reviewType)) {
                        HStack {
                            // Learning state label (e.g. "NEW")
                            Text(category.label)
                                .font(.ibmPlexMono(size: 20))
                            Spacer()
                            // Count in parentheses (e.g. "(5)")
                            // .secondary color provides visual hierarchy — the count is
                            // supplementary information, less important than the label.
                            Text("(\(category.count))")
                                .font(.ibmPlexMono(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }

                // Visual separator between the moves and combos sections.
                // Inset with horizontal padding to align with the content above/below.
                Divider()
                    .padding(.horizontal, 20)

                // --- COMBOS SECTION ---

                // Section header — mirrors the moves header for visual consistency.
                Text("COMBOS")
                    .font(.ibmPlexMono(size: 18, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // One row per learning state for combos — same structure as moves above.
                // The key difference is that combo learning states are computed from child moves
                // (via ComboStatsBuilder) rather than stored directly on the Combo model.
                ForEach(comboCategories) { category in
                    NavigationLink(destination: FlashcardReviewView(learningState: category.state, reviewType: category.reviewType)) {
                        HStack {
                            Text(category.label)
                                .font(.ibmPlexMono(size: 20))
                            Spacer()
                            Text("(\(category.count))")
                                .font(.ibmPlexMono(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 24)  // Top and bottom padding for the entire content area
            .navigationTitle("REVIEW")
            .navigationBarTitleDisplayMode(.inline)  // Small, centered title
        }
        // .appMotion() from Motion.swift — animates view changes when the total count changes.
        // The argument (moves.count + combos.count) is a Hashable value that SwiftUI watches.
        // When it changes (e.g., a move is added/deleted), an easeInOut animation is applied.
        // If the user has "Reduce Motion" enabled in Accessibility settings, the animation
        // is silently disabled via AppMotionModifier's reduceMotion check.
        .appMotion(moves.count + combos.count)
    }
}

// MARK: - Preview

#Preview("Review Hub - Light") {
    ReviewView()
        .modelContainer(.preview)
}

#Preview("Review Hub - Dark") {
    ReviewView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
