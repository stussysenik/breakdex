// AvailableMoveRowView.swift — Row component for move selection lists
//
// A compact list row that displays a move's name with a colored indicator bar
// showing its learning state. Used in contexts where the user picks moves from
// their arsenal — primarily in MovePickerSheet when building combos.
//
// VISUAL DESIGN:
//   [colored capsule bar] [Move Name]
//
// The left-edge capsule is a thin vertical bar (5pt wide, 30pt tall) filled with
// the move's learning state color:
//   - Magenta (#ff7eb6) for NEW
//   - Purple (#491d8b) for LEARNING
//   - Green (#24a148) for MASTERY
//
// This creates a quick visual indicator of each move's progress without taking up
// much space — important in picker/selection contexts where many moves are listed.
//
// ARCHITECTURE ROLE:
// AvailableMoveRowView is a pure presentation component — it receives a Move model
// and renders it. It doesn't modify the move or interact with SwiftData directly.
// The parent view (e.g., MovePickerSheet) handles selection logic and data mutations.
//
// COMPARED TO OTHER ROW VIEWS:
// - MoveListView's inline row: Shows name + date + StatePillView (full badge).
//   Used in the main arsenal list where detail matters.
// - AvailableMoveRowView: Shows name + color bar only. Used in picker/selection
//   contexts where compactness and scan-ability are prioritized over detail.
//
// SWIFTDATA NOTE:
// The `move` parameter is a SwiftData @Model object. SwiftData model classes are
// reference types (classes, not structs), so passing a Move here doesn't copy it.
// Any changes to the move elsewhere (e.g., a review updating its learningState)
// will be reflected here automatically on the next SwiftUI render cycle, because
// @Model objects participate in SwiftData's change tracking.

import SwiftUI
import SwiftData

/// A compact row view showing a move's name with a colored learning-state indicator bar.
/// Used in move picker/selection contexts (e.g., MovePickerSheet for combo creation).
struct AvailableMoveRowView: View {

    // MARK: - Properties

    /// The Move model object to display. This is a SwiftData @Model class instance,
    /// passed in by the parent view. We read .name and .learningState from it.
    /// The `let` binding means this view doesn't own or mutate the move.
    let move: Move

    // MARK: - Body

    var body: some View {
        // HStack arranges the color indicator and move name horizontally.
        // Default spacing (8pt) between children.
        HStack {

            // Learning state color indicator — a thin vertical capsule on the leading edge.
            // Capsule() is a shape that creates rounded ends (semicircles) on a rectangle.
            // At 5x30pt, this creates a slim vertical bar with rounded top and bottom.
            //
            // The fill color is derived from the move's learning state:
            //   move.learningState (String?) -> LearningState enum -> .color (Color)
            // This provides an at-a-glance visual cue about the move's progress.
            Capsule()
                .fill(learningStateColor)
                .frame(width: 5, height: 30)

            // Move name text — displays the move's name, falling back to "Untitled Move"
            // if the name is nil (which shouldn't happen in practice since Move.init()
            // defaults to "", but SwiftData stores it as Optional<String>).
            //
            // .headline is a system dynamic type style (roughly 17pt semibold).
            // Note: this uses the system font rather than .ibmPlexMono — this was an
            // intentional choice for picker contexts where system font readability
            // is preferred, or may be a candidate for future alignment with the design system.
            Text(move.name ?? "Untitled Move")
                .font(.headline)
                .padding(.leading, 8)  // Extra 8pt spacing between capsule and text

            // Spacer pushes all content to the leading edge, leaving empty space on
            // the trailing side. This ensures consistent left-alignment across all rows.
            Spacer()
        }
        // Vertical padding adds breathing room above and below each row.
        // Combined with the list's default row spacing, this creates comfortable tap targets.
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    /// Resolves the move's raw learning state string into a Color from the design system.
    ///
    /// Data flow:
    ///   move.learningState (Optional<String>, e.g. "NEW")
    ///   -> LearningState.resolve(from:) -> LearningState enum case (e.g. .newState)
    ///   -> .color -> Color (e.g. Color.stateNew = magenta #ff7eb6)
    ///
    /// LearningState.resolve(from:) handles nil and unrecognized strings gracefully,
    /// defaulting to .newState (magenta) so the indicator always has a valid color.
    private var learningStateColor: Color {
        LearningState.resolve(from: move.learningState).color
    }
}

// MARK: - Preview

/// Xcode Preview showing move rows across all three learning states.
/// Uses the seeded data from ModelContainer.preview (Windmill=NEW, Swipe=LEARNING, Halo=MASTERY).
#Preview("MoveRow - All States Light") {
    VStack(spacing: 8) {
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "NEW"))
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "LEARNING"))
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "MASTERY"))
    }
    .padding()
    .modelContainer(.preview)
}

#Preview("MoveRow - All States Dark") {
    VStack(spacing: 8) {
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "NEW"))
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "LEARNING"))
        AvailableMoveRowView(move: ModelContainer.previewMove(state: "MASTERY"))
    }
    .padding()
    .modelContainer(.preview)
    .preferredColorScheme(.dark)
}
