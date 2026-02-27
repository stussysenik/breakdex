// ComboDetailView.swift — Full detail screen for a breakdancing combo
//
// PURPOSE:
// This is the detail view shown when the user taps a combo in ComboListView.
// It displays:
//   1. The combo name and move count as a header
//   2. A video player showing the ACTIVE move's clip (switches as user taps nodes)
//   3. A horizontal "combo sequence" timeline of numbered circle nodes
//
// The timeline is the key interactive element — each node represents a move in the
// combo sequence. Tapping a node sets it as "active," which:
//   - Highlights the node (larger, accent-colored border)
//   - Switches the video player to that move's clip
//   - Shows the move name label below the node
//
// ARCHITECTURE CONNECTIONS:
// - Combo (Models.swift): SwiftData @Model with name and comboMoves relationship.
//   comboMoves is a [ComboMove]? — optional because SwiftData relationships are lazy.
// - ComboMove (Models.swift): Join table linking Combo <-> Move with sequenceIndex.
//   sequenceIndex (Int64) determines the order: 0 = first move, 1 = second, etc.
// - Move (Models.swift): The actual move at each sequence position. ComboMove.move
//   is the reference to the Move object, which has the video and learning state.
// - CustomVideoPlayerView: Handles video playback. Here it receives activeMove?.move,
//   which changes as the user taps different timeline nodes.
// - TimelineNodeView: Renders individual numbered circle nodes in the sequence.
//   Shows the sequence number, learning-state-colored border, and optional delete button.
// - DesignSystem.swift: Color.backgroundPrimary, .textPrimary, Font.ibmPlexMono().
//
// SWIFTUI PATTERNS USED:
// - @Environment(\.modelContext): Available for potential future editing operations.
// - let combo: Combo — passed from ComboListView's NavigationLink.
// - @State activeMoveIndex: Tracks which move in the sequence is currently selected.
// - Computed property sortedComboMoves: Sorts the combo's moves by sequenceIndex.
// - Computed property activeMove: Derives the current ComboMove from the active index.
// - ScrollView(.horizontal): Horizontal scrolling for the timeline when it overflows.
// - ForEach with enumerated(): Iterates with both index and element for positioning.

import SwiftUI
import SwiftData

struct ComboDetailView: View {

    // MARK: - Environment & Data

    // ModelContext available for future editing operations (e.g., reordering moves,
    // renaming the combo). Currently unused but present for architectural consistency.
    @Environment(\.modelContext) private var modelContext

    // The combo to display. Passed as a constant from ComboListView's NavigationLink.
    // Since Combo is a reference type (@Model class), it's observed automatically —
    // if the combo's data changes (e.g., moves added/removed), this view re-renders.
    let combo: Combo

    // MARK: - Local State

    // activeMoveIndex tracks which move in the sequence the user has selected.
    // Initialized to 0 (first move) so the video player shows something immediately.
    // Optional Int? because the combo might have zero moves (nil = no selection).
    @State private var activeMoveIndex: Int? = 0

    // MARK: - Computed Properties

    // sortedComboMoves extracts the combo's moves and sorts them by sequenceIndex.
    //
    // WHY NOT USE combo.comboMoves DIRECTLY?
    // combo.comboMoves is an unordered [ComboMove]? (SwiftData relationships don't
    // guarantee order). Since combo sequences have a specific order (1st move, 2nd
    // move, etc.), we must sort by sequenceIndex every time we access them.
    //
    // The ?? [] handles the optional — if comboMoves is nil (no moves added yet),
    // we return an empty array so downstream code doesn't need nil checks.
    var sortedComboMoves: [ComboMove] {
        (combo.comboMoves ?? []).sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    // MARK: - Body

    var body: some View {
        // ScrollView wraps the entire content to handle overflow when the
        // combo has many moves and the content extends beyond the screen.
        ScrollView {
            VStack(spacing: 20) {

                // HEADER SECTION — combo name and move count.
                VStack(alignment: .leading, spacing: 8) {
                    // Combo name — uses system .title font with bold weight.
                    // This deviates from ibmPlexMono used elsewhere, giving
                    // the detail view header a slightly more prominent feel.
                    Text(combo.name ?? "Untitled Combo")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    // Move count subtitle — only shown if the combo has moves.
                    // This prevents showing "0 moves" for empty combos.
                    if !sortedComboMoves.isEmpty {
                        Text("\(sortedComboMoves.count) moves")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                // Align header to the left and add horizontal padding.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // VIDEO PLAYER — shows the currently active move's video.
                // activeMove is a computed property (see below) that resolves
                // the activeMoveIndex to a ComboMove object. We pass
                // activeMove?.move (the underlying Move) to the player.
                // When the user taps a different timeline node, activeMoveIndex
                // changes, which changes activeMove, which changes the video.
                CustomVideoPlayerView(move: activeMove?.move)
                    .frame(height: 300)      // Consistent height with MoveDetailView
                    .cornerRadius(Radius.md)  // Consistent 12pt radius from design system
                    .padding(.horizontal)

                // TIMELINE SECTION — horizontal sequence of numbered nodes.
                // Only shown if the combo has at least one move.
                if !sortedComboMoves.isEmpty {
                    // Section header
                    Text("Combo Sequence")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Horizontal scrolling timeline.
                    // showsIndicators: false hides the horizontal scroll bar
                    // for a cleaner visual appearance.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            // ForEach with enumerated() gives us both the index (for
                            // sequencing) and the element (for data). We use the
                            // comboMove's id as the ForEach identity, not the index,
                            // which is important for correct animation and diffing.
                            ForEach(Array(sortedComboMoves.enumerated()), id: \.element.id) { index, comboMove in
                                // Only render the node if the comboMove has a valid move reference.
                                // This guards against orphaned ComboMove entries where the
                                // linked Move has been deleted.
                                if let move = comboMove.move {
                                    // Each node is a vertical stack: circle on top, name below.
                                    VStack(spacing: 8) {
                                        // TimelineNodeView renders a numbered circle with:
                                        //   - sequenceNumber: 1-based display number
                                        //   - isActive: highlights with accent border when selected
                                        //   - onDelete: empty closure (deletion disabled in detail view)
                                        //   - move: used to determine border color from learning state
                                        //   - showDelete: false hides the delete button (read-only view)
                                        TimelineNodeView(
                                            sequenceNumber: index + 1,
                                            isActive: activeMoveIndex == index,
                                            onDelete: {},
                                            move: move,
                                            showDelete: false  // Detail view is read-only, no deletion
                                        )
                                        // Tapping a node selects it, updating the video player.
                                        .onTapGesture {
                                            activeMoveIndex = index
                                        }

                                        // Move name label below the circle node.
                                        // Fixed width (70pt) and single-line truncation
                                        // keeps the timeline compact and evenly spaced.
                                        Text(move.name ?? "Move")
                                            .font(.ibmPlexMono(size: 12))
                                            .foregroundColor(.textPrimary)
                                            .frame(width: 70)
                                            .lineLimit(1)
                                            .truncationMode(.tail)  // "Wind..." for "Windmill"
                                    }
                                }

                                // CONNECTOR LINE — thin gray rectangle between nodes.
                                // Only drawn between nodes (not after the last one).
                                // This creates the visual "chain" connecting moves in sequence.
                                if index < sortedComboMoves.count - 1 {
                                    Rectangle()
                                        .frame(width: 30, height: 2)
                                        .foregroundColor(.textSecondary.opacity(0.3))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)  // Top and bottom padding inside the ScrollView
        }
        // Background color applied to the ScrollView, extending behind safe areas.
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Combo Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Active Move Resolution

    // activeMove resolves the current activeMoveIndex to a ComboMove object.
    // Returns nil if:
    //   - activeMoveIndex is nil (no selection)
    //   - activeMoveIndex is out of bounds (moves were deleted while viewing)
    //
    // This computed property is used by the video player to determine which
    // move's clip to play. When the user taps a timeline node, activeMoveIndex
    // changes, this property recomputes, and the video player updates.
    private var activeMove: ComboMove? {
        guard let activeMoveIndex, sortedComboMoves.indices.contains(activeMoveIndex) else {
            return nil
        }
        return sortedComboMoves[activeMoveIndex]
    }
}

// MARK: - Preview

// Preview uses the seeded "Starter Combo" (Windmill + Swipe) from
// ModelContainer.preview. Wrapped in NavigationStack for navigation context.
#Preview("ComboDetail - Light") {
    NavigationStack {
        ComboDetailView(combo: ModelContainer.previewCombo)
    }
    .modelContainer(.preview)
}

#Preview("ComboDetail - Dark") {
    NavigationStack {
        ComboDetailView(combo: ModelContainer.previewCombo)
    }
    .modelContainer(.preview)
    .preferredColorScheme(.dark)
}
