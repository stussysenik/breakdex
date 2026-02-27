// MovePickerSheet.swift — Modal sheet for selecting a move to add to a combo
//
// PURPOSE:
// This view is presented as a modal sheet (via .sheet()) when the user wants to
// add an existing move to a combo sequence during combo creation/editing. It shows
// a searchable list of ALL available moves in the arsenal. Tapping a move appends
// it to the parent view's selectedMoves array and dismisses the sheet.
//
// This is a "pick one and close" interaction pattern — not a multi-select.
// Each tap selects a single move, appends it, and dismisses. To add multiple
// moves, the user opens the sheet multiple times.
//
// ARCHITECTURE CONNECTIONS:
// - Move (Models.swift): The SwiftData @Model objects displayed in the list.
//   Moves are passed in as `allMoves` from the parent view (not fetched here).
// - AvailableMoveRowView (AvailableMoveRowView.swift): Renders each row with
//   a colored capsule indicator (learning state) and the move name. This is a
//   reusable row component shared between this picker and other move lists.
// - CreateComboView: The primary consumer — presents this sheet and passes its
//   @Query'd moves as `allMoves` and a @State array as `selectedMoves`.
//
// DESIGN DECISIONS:
// - allMoves is a `let` (passed in) rather than a @Query because the parent
//   view already has the queried moves. Passing them avoids a redundant fetch.
// - selectedMoves is a @Binding because the parent owns this array and needs
//   to see the appended move after the sheet dismisses.
//
// SWIFTUI PATTERNS USED:
// - @Environment(\.dismiss): Action to programmatically dismiss this modal sheet.
//   Called both when a move is selected AND when "Cancel" is tapped.
// - @Binding: Two-way connection to the parent's selectedMoves array.
//   When we append a move here, the parent's array updates immediately.
// - @State: Local search text for filtering the move list.
// - NavigationView: Provides the navigation bar with title and toolbar.
//   Note: This uses NavigationView (not NavigationStack) because it's a modal
//   sheet that doesn't need push/pop navigation — just a title bar and toolbar.
// - .searchable(): Adds an integrated search bar, bound to searchText.
// - .sheet() presentation context: This view is designed to be presented via
//   .sheet(isPresented:) from a parent view. The @Environment(\.dismiss) action
//   handles closing it.

import SwiftUI

struct MovePickerSheet: View {

    // MARK: - Environment

    // dismiss is an EnvironmentAction that programmatically closes this modal sheet.
    // It's the Swift equivalent of UIKit's dismiss(animated:completion:).
    // In SwiftUI, when a view is presented via .sheet(), calling dismiss()
    // animates the sheet downward and removes it from the view hierarchy.
    @Environment(\.dismiss) var dismiss

    // MARK: - Input Properties

    // allMoves is the complete list of moves available for selection.
    // Passed in from the parent view (e.g., CreateComboView) which already
    // has this data via its own @Query. This avoids a redundant SwiftData fetch.
    // It's a `let` (immutable) because this view only reads moves, never modifies them.
    let allMoves: [Move]

    // selectedMoves is a two-way binding to the parent's array of chosen moves.
    // @Binding means this view doesn't own the data — it reads and writes to
    // the parent's @State variable. When we call selectedMoves.append(move),
    // the parent's array is updated immediately, and any views in the parent
    // that depend on that array will re-render.
    @Binding var selectedMoves: [Move]

    // MARK: - Local State

    // Search text for filtering the available moves list.
    // This is @State (owned by this view) because the search is local to this sheet
    // and doesn't need to persist after the sheet is dismissed.
    @State private var searchText = ""

    // MARK: - Computed Properties

    // Filters allMoves based on the user's search input.
    // Same pattern used in MoveListView and ComboListView:
    //   - Empty search -> return all moves
    //   - Non-empty search -> case-insensitive name filter
    // The ?? false handles optional .name — nil names don't match any search.
    var searchResults: [Move] {
        if searchText.isEmpty {
            return allMoves
        } else {
            return allMoves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    // MARK: - Body

    var body: some View {
        // NavigationStack (iOS 16+) provides the navigation bar for title and toolbar.
        NavigationStack {
            // List of available moves, filtered by search text.
            // Each Move conforms to Identifiable (via its `id` property),
            // so List can uniquely identify and diff rows.
            List(searchResults) { move in
                // Each row is a Button (not a NavigationLink) because tapping
                // should select the move and dismiss, not push a new view.
                Button(action: {
                    // Append the tapped move to the parent's selected moves array.
                    // Since selectedMoves is a @Binding, this immediately updates
                    // the parent view's state.
                    selectedMoves.append(move)
                    // Dismiss the sheet — the parent now has the new move in its array.
                    dismiss()
                }) {
                    // AvailableMoveRowView renders the row content:
                    //   - A thin colored capsule on the left (learning state color)
                    //   - The move name as headline text
                    // This is a separate component for reusability across the app.
                    AvailableMoveRowView(move: move)
                }
            }
            .listStyle(.plain)  // Flat list without grouped/inset styling
            .navigationTitle("Add Move to Combo")  // Sheet title
            // .searchable() adds the integrated search bar at the top.
            // Binds to searchText which drives searchResults filtering.
            .searchable(text: $searchText, prompt: "Search Moves...")
            // TOOLBAR: Cancel button in the top-left (cancellationAction placement).
            // This gives the user a way to close the sheet without selecting anything.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Dismiss without appending — selectedMoves unchanged.
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("MovePicker - Light") {
    MovePickerSheet(allMoves: [], selectedMoves: .constant([]))
        .modelContainer(.preview)
}

#Preview("MovePicker - Dark") {
    MovePickerSheet(allMoves: [], selectedMoves: .constant([]))
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
