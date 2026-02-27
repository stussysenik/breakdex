// CreateComboView.swift — Combo creation screen
//
// This view lets users build a combo by chaining individual moves together.
// A "combo" in breakdancing is a sequence of moves performed back-to-back
// (e.g. Toprock -> Windmill -> Baby Freeze -> Swipe).
//
// SCREEN LAYOUT (top to bottom):
//   1. "+ Add Move to Combo" button — opens the MovePickerSheet
//   2. Video preview — shows the currently selected move's video, or a placeholder
//   3. "Your Combo" section:
//      a. Section title
//      b. ComboTimelineView — horizontal scrollable timeline of selected moves
//      c. "Save Combo" button — opens a naming alert, then persists to SwiftData
//
// DATA MODEL:
//   The combo is saved as a Combo model (SwiftData) with associated ComboMove join records.
//   Each ComboMove links a Move to the Combo with a sequenceIndex (0-based position).
//
//   Combo ──< ComboMove >── Move
//           (join table with sequenceIndex)
//
//   This many-to-many relationship means the same Move can appear in multiple Combos,
//   and a Combo can contain the same Move more than once at different positions.
//
// STATE MANAGEMENT:
//   - comboMoves: [Move] — the ordered list of moves the user has selected for the combo.
//     This is a @State array (not a @Query) because it's a transient working list that
//     only gets persisted when the user taps "Save Combo".
//   - activeNodeIndex: Int? — which move in the timeline is currently selected/highlighted.
//     When set, the video preview shows that move's clip. When nil, a placeholder is shown.
//   - Three sets of alert state (naming, success, error) drive the modal dialogs.
//
// USER FLOW:
//   1. User taps "+ Add Move to Combo" → MovePickerSheet opens
//   2. User selects one or more moves → they appear in the ComboTimelineView
//   3. User taps a move in the timeline → its video plays in the preview area
//   4. User taps "Save Combo" → naming alert appears
//   5. User enters a name (or accepts the auto-generated timestamp name) → combo is saved
//   6. Success alert confirms the save → combo list resets for building another
//
// DESIGN SYSTEM USAGE:
//   - Font.ibmPlexMono: all text (button labels, titles) — technical monospace aesthetic
//   - Color.textPrimary: section title text (dynamic light/dark)
//   - Color.accent: "Save Combo" button tint (#2362a2)
//   - Spacing.md: not directly used here (hardcoded 16pt in some places)
//   - .appMotion(): accessibility-aware animation on combo changes

import SwiftUI   // SwiftUI framework — provides View, @State, @Query, @Environment, etc.
import SwiftData // SwiftData — provides @Model, @Query, ModelContext for persistence

// MARK: - CreateComboView

/// The combo builder screen. Presented as a tab in MainView.
/// Users assemble an ordered sequence of moves and save it as a named Combo.
struct CreateComboView: View {

    // -------------------------------------------------------------------------
    // MARK: Environment
    // -------------------------------------------------------------------------

    /// SwiftData model context — injected by the .modelContainer() modifier
    /// higher up in the view hierarchy (typically from BreakingFlashcardsApp).
    /// Used in saveCombo() to insert Combo and ComboMove models into the database.
    @Environment(\.modelContext) private var modelContext

    // -------------------------------------------------------------------------
    // MARK: Data Query
    // -------------------------------------------------------------------------

    /// Live query of all Move objects from SwiftData, sorted by creation date.
    /// @Query automatically observes the database and re-renders the view when
    /// moves are added, deleted, or modified. This feeds the MovePickerSheet
    /// with the full list of available moves the user can choose from.
    @Query(sort: \Move.createdAt)
    private var allMoves: [Move]

    // -------------------------------------------------------------------------
    // MARK: State Properties
    // -------------------------------------------------------------------------

    /// The ordered list of moves selected for the current combo being built.
    /// This is a transient working array — it only becomes a persisted Combo
    /// when the user taps "Save Combo". Users can add, remove, and reorder
    /// moves through the MovePickerSheet and ComboTimelineView.
    @State private var comboMoves: [Move] = []

    /// The index of the currently active/selected move in the comboMoves array.
    /// When set to a valid index, the video preview area shows that move's clip.
    /// When nil (no selection), a ContentUnavailableView placeholder is shown instead.
    /// This is two-way bound to ComboTimelineView so tapping a node selects it.
    @State private var activeNodeIndex: Int? = nil

    /// Controls whether the MovePickerSheet (modal move selector) is presented.
    /// Set to true when user taps "+ Add Move to Combo".
    @State private var isMovePickerPresented = false

    /// Controls whether the combo naming alert dialog is presented.
    /// Set to true when user taps "Save Combo".
    @State private var isNamingAlertPresented = false

    /// The user-entered combo name, bound to the TextField inside the naming alert.
    /// If left empty, a timestamp-based default name is generated (e.g. "Combo Feb 26, 2026, 3:14 PM").
    @State private var comboName = ""

    /// Controls visibility of the success alert after a successful save.
    @State private var showSuccessMessage = false

    /// Controls visibility of the error alert when a save fails.
    @State private var showErrorMessage = false

    /// The text displayed in the success alert (e.g. "Combo 'Power Set' created successfully!").
    @State private var successMessage = ""

    /// The text displayed in the error alert (e.g. "Failed to save combo. Please try again.").
    @State private var errorMessage = ""

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    /// The main view body. Uses a VStack with zero spacing as the root layout,
    /// with the "+ Add" button at top, video preview in the middle, and the
    /// combo timeline + save button at the bottom.
    var body: some View {
        VStack(spacing: 0) {

            // ------------------------------------------------------------------
            // Top: Add Move Button
            // ------------------------------------------------------------------

            /// Button to open the MovePickerSheet.
            Button("+ Add Move to Combo") {
                isMovePickerPresented = true
            }
            .secondaryAction()
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.vertical, Spacing.md)

            // ------------------------------------------------------------------
            // Middle: Video Preview Area
            // ------------------------------------------------------------------

            // Show either the active move's video or a visual video placeholder.
            // The activeMove computed property resolves the current selection.
            if let activeMove = activeMove {
                // CustomVideoPlayerView initialized with a Move object.
                // It internally resolves the move's videoReference to a playable URL.
                CustomVideoPlayerView(move: activeMove)
                    .aspectRatio(4/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .padding(.horizontal, Spacing.screenEdge)
            } else {
                // Clean video placeholder — neutral fill with centered icon and hint.
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.neutralFill)

                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 36))
                            .foregroundColor(.textSecondary.opacity(0.4))

                        Text(comboMoves.isEmpty ? "Add moves to preview" : "Tap a move to preview")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                }
                .aspectRatio(4/3, contentMode: .fit)
                .padding(.horizontal, Spacing.screenEdge)
            }

            // ------------------------------------------------------------------
            // Bottom: Combo Timeline + Save Button
            // ------------------------------------------------------------------

            VStack(spacing: Spacing.md) {
                // ComboTimelineView — a horizontally scrollable timeline showing the
                // ordered sequence of moves in the combo. Each move is represented as a
                // node that can be tapped to select it (updating activeNodeIndex) or
                // deleted. The bindings allow two-way communication: adding/removing moves
                // and changing the active selection.
                ComboTimelineView(moves: $comboMoves, activeIndex: $activeNodeIndex)
                    .frame(height: 120)   // Fixed height for the timeline strip

                // "Save Combo" button — triggers the naming alert.
                Button("Save Combo") {
                    isNamingAlertPresented = true
                }
                .primaryAction()
                .disabled(comboMoves.isEmpty)
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, Spacing.lg)

                Spacer(minLength: Spacing.lg)
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        // Apply accessibility-aware animation. When comboMoves.count changes (move added/removed),
        // the layout change is animated with AppMotion.easeStandard — unless the user has
        // "Reduce Motion" enabled in Accessibility settings, in which case no animation is applied.
        .appMotion(comboMoves.count)

        // ------------------------------------------------------------------
        // Sheet: Move Picker
        // ------------------------------------------------------------------

        // MovePickerSheet is a modal view that presents all available moves (from @Query).
        // The user taps moves to add them to the combo. selectedMoves is a two-way binding,
        // so changes in the picker immediately reflect in comboMoves.
        .sheet(isPresented: $isMovePickerPresented) {
            MovePickerSheet(allMoves: allMoves, selectedMoves: $comboMoves)
        }

        // Auto-activate the newly added move when comboMoves grows
        .onChange(of: comboMoves.count) { oldCount, newCount in
            if newCount > oldCount {
                activeNodeIndex = newCount - 1
            }
        }

        // ------------------------------------------------------------------
        // Alert: Name Your Combo
        // ------------------------------------------------------------------

        // A standard system alert with a text field for entering the combo name.
        // Two buttons: Cancel (resets the name) and Save (persists the combo).
        // If the user leaves the name empty, a default timestamp name is generated.
        .alert("Name Your Combo", isPresented: $isNamingAlertPresented) {
            // Text field inside the alert for combo name entry
            TextField("Combo Name", text: $comboName)

            // Cancel button — dismisses the alert and clears the name field
            Button("Cancel", role: .cancel) {
                comboName = ""
            }

            // Save button — calls saveCombo with either the entered name or a generated default.
            // Default name format: "Combo Feb 26, 2026, 3:14 PM" (using .abbreviated date + .shortened time)
            Button("Save") {
                saveCombo(name: comboName.isEmpty ? "Combo \(Date().formatted(date: .abbreviated, time: .shortened))" : comboName)
                comboName = ""   // Reset for next use
            }
        } message: {
            // Instructional text shown below the alert title
            Text("Enter a name for your combo to save it.")
        }

        // ------------------------------------------------------------------
        // Alert: Success Confirmation
        // ------------------------------------------------------------------

        // Shown after a combo is successfully saved to SwiftData.
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("OK") { showSuccessMessage = false }
        } message: {
            Text(successMessage)   // Dynamic message, e.g. "Combo 'Power Set' created successfully!"
        }

        // ------------------------------------------------------------------
        // Alert: Error Notification
        // ------------------------------------------------------------------

        // Shown when the SwiftData save fails (e.g. model validation error, disk full).
        .alert("Error", isPresented: $showErrorMessage) {
            Button("OK") { showErrorMessage = false }
        } message: {
            Text(errorMessage)   // Dynamic message, e.g. "Failed to save combo. Please try again."
        }
    }

    // =========================================================================
    // MARK: - Computed Properties
    // =========================================================================

    /// Resolves the currently active move from the comboMoves array.
    /// Returns nil if:
    ///   - activeNodeIndex is nil (no selection)
    ///   - comboMoves is empty (nothing to select from)
    ///   - activeNodeIndex is out of bounds (stale selection after deletion)
    ///
    /// Used by the video preview area to decide whether to show a video or placeholder.
    private var activeMove: Move? {
        guard let activeNodeIndex, !comboMoves.isEmpty, comboMoves.indices.contains(activeNodeIndex) else {
            return nil
        }
        return comboMoves[activeNodeIndex]
    }

    // =========================================================================
    // MARK: - Persistence
    // =========================================================================

    /// Saves the assembled combo to SwiftData.
    ///
    /// This creates a Combo model and links it to each selected Move via ComboMove
    /// join records. Each ComboMove stores a sequenceIndex indicating the move's
    /// position in the combo (0 = first, 1 = second, etc.).
    ///
    /// PIPELINE:
    /// 1. Create a new Combo model with the given name
    /// 2. For each move in comboMoves (in order), create a ComboMove join record
    ///    with the correct sequenceIndex, linked to both the Combo and the Move
    /// 3. Save the model context to persist everything to disk
    /// 4. On success: show confirmation, reset the working state for next combo
    /// 5. On failure: show error alert with a retry suggestion
    ///
    /// - Parameter name: The user-chosen name for the combo (or auto-generated default).
    private func saveCombo(name: String) {
        // Step 1: Create the parent Combo model and insert it into the context.
        // SwiftData generates a UUID and sets up the relationships automatically.
        let newCombo = Combo(name: name)
        modelContext.insert(newCombo)

        // Step 2: Create a ComboMove join record for each selected move.
        // The sequenceIndex preserves the order the user arranged them in the timeline.
        for (index, move) in comboMoves.enumerated() {
            let comboMove = ComboMove(sequenceIndex: Int64(index))  // 0-based position in the combo
            comboMove.move = move     // Link to the actual Move model
            comboMove.combo = newCombo // Link to the parent Combo
            modelContext.insert(comboMove)
        }

        do {
            // Step 3: Persist all changes (Combo + ComboMoves) to disk in a single transaction
            try modelContext.save()

            // Step 4 (success): Update UI with confirmation
            successMessage = "Combo '\(name)' created successfully!"
            showSuccessMessage = true

            // Reset the working state so the user can build another combo immediately
            comboMoves.removeAll()     // Clear the selected moves list
            activeNodeIndex = nil       // Clear the video preview selection

            // Auto-dismiss the success alert after 3 seconds for convenience
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccessMessage = false
            }
        } catch {
            // Step 5 (failure): Log the error and show an alert
            print("Error saving combo: \(error)")
            errorMessage = "Failed to save combo. Please try again."
            showErrorMessage = true

            // Auto-dismiss the error alert after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showErrorMessage = false
            }
        }
    }
}

// MARK: - Preview

/// Xcode Preview using an in-memory SwiftData container with sample data.
/// The .preview container (defined in Models.swift) seeds a few sample moves
/// so the picker has data to display during development.
#Preview("CreateCombo - Light") {
    CreateComboView()
        .modelContainer(.preview)
}

#Preview("CreateCombo - Dark") {
    CreateComboView()
        .modelContainer(.preview)
        .preferredColorScheme(.dark)
}
