// TimelineNodeView.swift — Individual numbered circle node for combo timelines
//
// PURPOSE:
// This component renders a single step in a combo sequence as a numbered circle.
// It's the building block of the combo timeline — both in ComboDetailView (read-only)
// and ComboTimelineView (editable). Each node displays:
//   - A sequence number (1, 2, 3...) centered in a circle
//   - A colored border indicating the move's learning state
//   - An active/inactive visual state (larger + accent-colored when selected)
//   - An optional delete button (red "X") that appears when the node is active
//
// VISUAL STATES:
// 1. INACTIVE: 50x50pt circle, thin border colored by learning state, gray fill,
//    regular-weight number in white.
// 2. ACTIVE: 60x60pt circle, thick accent border, white fill, bold number in black.
//    If showDelete is true, a red "X" button appears at the top-right corner.
//
// The transition between states is animated with a spring curve, giving a physical
// "pop" effect when the user taps a node to select it.
//
// ARCHITECTURE CONNECTIONS:
// - Move (Models.swift): Optional Move reference used to determine border color.
//   The move's learningState string is resolved to a LearningState enum, which
//   provides the .color property (magenta for NEW, purple for LEARNING, green for MASTERY).
// - LearningState (LearningState.swift): Enum that resolves raw strings to typed states
//   with associated colors. Used here via LearningState.resolve(from:).
// - Color.accent (DesignSystem.swift): The active state border color (#2362a2 blue).
// - Font.ibmPlexMono() (DesignSystem.swift): Monospace font for the sequence number.
//
// CONSUMERS:
// - ComboDetailView: Uses TimelineNodeView in read-only mode (showDelete: false).
// - ComboTimelineView: Uses TimelineNodeView in edit mode (showDelete: true).
// - Both set isActive based on the currently selected index and handle onTapGesture.
//
// SWIFTUI PATTERNS USED:
// - ZStack(alignment:): Layers the circle and delete button, with the delete button
//   positioned at .topTrailing (top-right corner).
// - .overlay(): Renders the sequence number text on top of the circle shape.
// - .transition(.scale.combined(with: .opacity)): Combined enter/exit animation
//   for the delete button — it scales up and fades in simultaneously.
// - .animation(.spring()): Declarative animation tied to the isActive value.
//   Every change to isActive triggers a spring-animated transition of all
//   affected properties (size, border, colors, font weight).

import SwiftUI

struct TimelineNodeView: View {

    // MARK: - Properties

    // sequenceNumber is the 1-based position of this move in the combo.
    // Displayed as text inside the circle (e.g., "1", "2", "3").
    let sequenceNumber: Int

    // isActive indicates whether this node is currently selected.
    // When true, the node enlarges, changes border color to accent,
    // fills with white, shows bold text, and optionally shows the delete button.
    let isActive: Bool

    // onDelete is a closure called when the user taps the delete button.
    // The parent view handles the actual deletion logic (removing from the
    // moves array and adjusting the active index).
    let onDelete: () -> Void

    // Optional Move reference — used to determine the border color.
    // When present, the border color reflects the move's learning state.
    // When nil (e.g., placeholder nodes), the border defaults to gray.
    let move: Move?

    // showDelete controls whether the red "X" delete button appears when active.
    // Set to true in editable contexts (ComboTimelineView) and false in
    // read-only contexts (ComboDetailView).
    let showDelete: Bool

    // MARK: - Initializer

    // Explicit init with default parameter values.
    // move defaults to nil (for cases where no move is associated yet).
    // showDelete defaults to true (editable is the common case).
    //
    // The @escaping annotation on onDelete is required because the closure
    // is stored as a property (it "escapes" the initializer scope). Swift
    // requires this annotation to make the programmer aware that the closure
    // may be called after the function returns.
    init(sequenceNumber: Int, isActive: Bool, onDelete: @escaping () -> Void, move: Move? = nil, showDelete: Bool = true) {
        self.sequenceNumber = sequenceNumber
        self.isActive = isActive
        self.onDelete = onDelete
        self.move = move
        self.showDelete = showDelete
    }

    // MARK: - Computed Properties

    // borderColor determines the circle's border color based on state:
    //   1. If active: accent blue (the app's primary interactive color)
    //   2. If inactive with a move: the move's learning state color
    //      (magenta for NEW, purple for LEARNING, green for MASTERY)
    //   3. If inactive without a move: neutral gray
    //
    // This creates a visual language where you can scan the timeline and
    // immediately see which moves are mastered (green) vs. new (magenta).
    private var borderColor: Color {
        if isActive {
            return .accent
        } else if let move = move {
            // LearningState.resolve(from:) safely converts the optional raw string
            // to a typed LearningState enum, then .color returns the associated Color.
            return LearningState.resolve(from: move.learningState).color
        } else {
            return .gray
        }
    }

    // MARK: - Body

    var body: some View {
        // ZStack layers views from back to front:
        //   1. The circle (background)
        //   2. The delete button (foreground, top-right corner)
        // alignment: .topTrailing positions child views at the top-right by default,
        // which is where we want the delete button to appear.
        ZStack(alignment: .topTrailing) {

            // CIRCLE NODE — the main visual element.
            Circle()
                // .strokeBorder draws the border INSIDE the circle's bounds
                // (unlike .stroke which straddles the edge). This prevents
                // the border from extending outside the frame.
                // lineWidth is thicker (4pt) when active for visual emphasis.
                .strokeBorder(borderColor, lineWidth: isActive ? 4 : 2)
                // .background fills the interior of the circle.
                // Active: white (makes the number stand out in black).
                // Inactive: semi-transparent gray (darker, receded look).
                .background(Circle().fill(isActive ? Color.white : Color.gray.opacity(0.3)))
                // Size changes based on active state — 60pt when active, 50pt when inactive.
                // This size change, combined with the spring animation below, creates
                // a satisfying "pop" effect when selecting a node.
                .frame(width: isActive ? 60 : 50, height: isActive ? 60 : 50)
                // .overlay places the sequence number text on top of the circle.
                // It's centered by default within the circle's bounds.
                .overlay(
                    Text("\(sequenceNumber)")
                        // Font size and weight change with active state:
                        // Active: 18pt bold (prominent)
                        // Inactive: 16pt regular (subtle)
                        .font(.ibmPlexMono(size: isActive ? 18 : 16, weight: isActive ? .bold : .regular))
                        // Text color contrast:
                        // Active: black on white background
                        // Inactive: white on gray background
                        .foregroundColor(isActive ? .black : .white)
                )

            // DELETE BUTTON — red "X" circle, only shown when active AND showDelete is true.
            // The `if` condition means this view is conditionally inserted/removed from
            // the view hierarchy, which triggers the .transition animation.
            if isActive && showDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        // White circle background behind the X icon to ensure visibility
                        // regardless of what's behind the node.
                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                }
                // Offset positions the button outside the circle's top-right corner.
                // Positive x moves right, negative y moves up.
                .offset(x: 6, y: -6)
                // .transition defines how this view enters/exits the hierarchy.
                // .scale starts at 0 and grows to full size (pop-in effect).
                // .combined(with: .opacity) simultaneously fades from transparent to opaque.
                // Together, this creates a "pop and fade in" appearance animation.
                .transition(.scale.combined(with: .opacity))
            }
        }
        // Fixed 70x70pt container size prevents layout shifts when the inner circle
        // changes size (50 vs 60pt). Without this, sibling views would shift position
        // every time a node becomes active/inactive, causing jarring layout movement.
        .frame(width: 70, height: 70)
        // Spring animation triggered by changes to isActive.
        // All animatable properties (size, border width, colors, font) transition
        // smoothly when isActive changes.
        // response: 0.4 = moderate speed
        // dampingFraction: 0.6 = noticeable bounce (physical, playful feel)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isActive)
    }
}

// MARK: - Preview

// Shows a single inactive node without a move reference.
// To preview active state, change isActive to true.
// To preview with learning state colors, pass a Move object.
#Preview("TimelineNode - Light") {
    HStack(spacing: 12) {
        TimelineNodeView(sequenceNumber: 1, isActive: false, onDelete: {}, move: nil, showDelete: false)
        TimelineNodeView(sequenceNumber: 2, isActive: true, onDelete: {}, move: nil, showDelete: false)
        TimelineNodeView(sequenceNumber: 3, isActive: false, onDelete: {}, showDelete: true)
    }
    .padding()
}

#Preview("TimelineNode - Dark") {
    HStack(spacing: 12) {
        TimelineNodeView(sequenceNumber: 1, isActive: false, onDelete: {}, move: nil, showDelete: false)
        TimelineNodeView(sequenceNumber: 2, isActive: true, onDelete: {}, move: nil, showDelete: false)
        TimelineNodeView(sequenceNumber: 3, isActive: false, onDelete: {}, showDelete: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
