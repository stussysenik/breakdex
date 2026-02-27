// ComboTimelineView.swift — Editable horizontal timeline for combo move sequences
//
// PURPOSE:
// This is the interactive, editable version of the combo sequence timeline.
// It renders a horizontal row of numbered circle nodes (TimelineNodeView) connected
// by gray lines, with full support for:
//   - Tapping nodes to select them (sets activeIndex)
//   - Deleting moves from the sequence (via the red "X" on active nodes)
//   - Auto-scrolling to keep the active node centered in view
//
// This component is used during combo CREATION and EDITING (e.g., CreateComboView),
// where the user needs to build and modify the sequence. For read-only display
// (e.g., ComboDetailView), the timeline is rendered inline without this wrapper.
//
// KEY DIFFERENCES FROM ComboDetailView's INLINE TIMELINE:
// 1. EDITABLE: showDeleteButtons enables the red "X" delete button on active nodes.
// 2. @Binding: moves and activeIndex are two-way bindings, so the parent view
//    stays in sync when moves are deleted or the selection changes.
// 3. AUTO-SCROLL: Uses ScrollViewReader to programmatically scroll to the active
//    node when the selection changes, keeping it centered in the viewport.
// 4. SMART DELETE: When a move is deleted, the active index is reset intelligently
//    to prevent out-of-bounds access.
//
// ARCHITECTURE CONNECTIONS:
// - Move (Models.swift): The SwiftData @Model objects in the timeline. Each node
//   corresponds to a Move in the sequence.
// - TimelineNodeView (TimelineNodeView.swift): The individual circle node component.
//   This view wraps it in a scrollable, connected timeline with delete support.
// - .appMotion() (Motion.swift): Accessibility-aware animation on active index changes.
//   Disabled when the user has "Reduce Motion" enabled in iOS settings.
//
// CONSUMERS:
// - CreateComboView: The primary consumer. Passes its @State moves array and
//   activeIndex as bindings, so edits here flow back to the creation form.
//
// SWIFTUI PATTERNS USED:
// - @Binding (x2): Two-way connections to the parent's state.
//   @Binding var moves — the parent's mutable array of moves in sequence order.
//   @Binding var activeIndex — which node is currently selected (nil = none).
// - ScrollViewReader + scrollTo(): Programmatic scrolling to a specific view.
//   ScrollViewReader provides a ScrollViewProxy that can scroll to any view
//   identified by its .id(). Here we use move.id (UUID) as the identity.
// - .onChange(of:): Reacts to changes in activeIndex. When the user taps a new
//   node, onChange fires and scrolls to center the newly active node.
// - ForEach with enumerated(): Iterates with both index and element.
//   The index is used for sequenceNumber and active state comparison.
//   The element's .id is used as the ForEach identity for stable diffing.

import SwiftUI

struct ComboTimelineView: View {

    // MARK: - Bindings

    // @Binding var moves: Two-way connection to the parent's array of Move objects.
    // This is the ordered sequence of moves in the combo. When a move is deleted
    // here (via the delete button), the parent's array is updated immediately.
    //
    // @Binding is used instead of @State because the parent view OWNS this data.
    // This view is a UI control for displaying and editing the parent's state,
    // not a data owner. The parent (e.g., CreateComboView) manages persistence.
    @Binding var moves: [Move]

    // @Binding var activeIndex: Two-way connection to the parent's selected index.
    // Optional Int? — nil means no node is selected.
    // Changes here (via tap or delete) propagate back to the parent, which may
    // use this index to show the active move's video, details, etc.
    @Binding var activeIndex: Int?

    // showDeleteButtons controls whether TimelineNodeView shows the red "X" button
    // on active nodes. Set to true for editable contexts, false for read-only.
    let showDeleteButtons: Bool

    // MARK: - Initializer

    // Explicit init that accepts Binding wrappers and a plain Bool.
    // The underscore syntax (_moves, _activeIndex) accesses the Binding wrapper
    // directly, rather than the wrapped value. This is required when storing
    // Bindings as properties in a custom init.
    //
    // showDeleteButtons defaults to true since this component is primarily
    // used in editable contexts (the read-only case uses inline timeline code).
    init(moves: Binding<[Move]>, activeIndex: Binding<Int?>, showDeleteButtons: Bool = true) {
        self._moves = moves
        self._activeIndex = activeIndex
        self.showDeleteButtons = showDeleteButtons
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Empty state ghost node
                    if moves.isEmpty {
                        VStack(spacing: Spacing.xs) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.textSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.textSecondary.opacity(0.5))
                            }
                            Text("Add a move")
                                .font(.ibmPlexMono(size: 11))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(width: 70)
                    }

                    // ForEach with enumerated() provides both the index (for
                    // sequenceNumber and active state) and the element (for data).
                    // Identity is the move's UUID (.id), which is stable across
                    // re-renders — important for correct animation and diffing.
                    ForEach(Array(moves.enumerated()), id: \.element.id) { index, move in
                        // Each node + its trailing connector line are grouped in an HStack.
                        HStack(spacing: 0) {
                            // TimelineNodeView renders the numbered circle.
                            TimelineNodeView(
                                sequenceNumber: index + 1,       // 1-based display number
                                isActive: activeIndex == index,   // Highlight if selected
                                onDelete: {
                                    // DELETE LOGIC: Remove the move at this index.
                                    moves.remove(at: index)

                                    // SMART INDEX RESET after deletion:
                                    // If the array is now empty, clear the selection.
                                    // If the deleted index was at or before the active index,
                                    // reset to 0 (first item) to prevent out-of-bounds.
                                    //
                                    // WHY index <= (activeIndex ?? 0)?
                                    // If we deleted a move BEFORE the active one, all
                                    // subsequent indices shift down by 1. Rather than
                                    // trying to track the shift, we reset to 0.
                                    // If we deleted the active move itself, we also reset to 0.
                                    if moves.isEmpty {
                                        activeIndex = nil
                                    } else if index <= (activeIndex ?? 0) {
                                        activeIndex = 0
                                    }
                                },
                                move: move,                       // For learning state border color
                                showDelete: showDeleteButtons     // Show/hide the "X" button
                            )
                            // Tapping the node selects it (sets activeIndex).
                            .onTapGesture { activeIndex = index }

                            // CONNECTOR LINE between nodes — thin gray rectangle.
                            // Only drawn between nodes (not after the last one).
                            if index < moves.count - 1 {
                                Rectangle().frame(width: 30, height: 2).foregroundColor(.textSecondary.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(.horizontal)  // Inset from screen edges
            }
            // .onChange(of:) reacts to changes in activeIndex.
            // When the user taps a new node, this fires and scrolls the
            // timeline to center the newly active node in the viewport.
            //
            // The (oldIndex, newIndex) closure signature is the iOS 17+ API.
            // It provides both the previous and new values for comparison.
            .onChange(of: activeIndex) { oldIndex, newIndex in
                if let newIndex, moves.indices.contains(newIndex) {
                    // withAnimation wraps the scroll in a smooth animation.
                    // proxy.scrollTo() scrolls to the view with the matching id.
                    // anchor: .center positions the target view in the center
                    // of the visible scroll area, not at the leading edge.
                    withAnimation { proxy.scrollTo(moves[newIndex].id, anchor: .center) }
                }
            }
        }
        // .appMotion() applies accessibility-aware animation to changes in activeIndex.
        // When activeIndex is nil, we pass -1 as a sentinel value (since nil isn't
        // Hashable in a way that works with the modifier's generic constraint).
        // This animates the layout transition when the active node changes,
        // but disables animation if the user has "Reduce Motion" enabled.
        .appMotion(activeIndex ?? -1)
    }
}

// MARK: - Preview

// Preview with empty state — no nodes rendered, just the scroll container.
// To preview with nodes, pass a non-empty .constant([Move(name: "Test")]) array.
#Preview("ComboTimeline Empty - Light") {
    ComboTimelineView(moves: .constant([]), activeIndex: .constant(nil), showDeleteButtons: true)
        .frame(height: 100)
}

#Preview("ComboTimeline Empty - Dark") {
    ComboTimelineView(moves: .constant([]), activeIndex: .constant(nil), showDeleteButtons: true)
        .frame(height: 100)
        .preferredColorScheme(.dark)
}
