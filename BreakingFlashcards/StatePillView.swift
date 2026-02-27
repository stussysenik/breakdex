// StatePillView.swift — Colored badge showing a move's learning state
//
// A small capsule-shaped pill that displays the current learning state of a move
// (NEW, LEARNING, or MASTERY) with a color-coded dot and label. Used throughout
// the app wherever a move's progress needs to be shown at a glance:
//
//   - MoveListView: appears next to each move name in the arsenal list
//   - MoveDetailView: shown in the move detail header
//   - MoveReviewView: displayed during flashcard review sessions
//
// VISUAL DESIGN:
//   NEW      -> Magenta dot + magenta text on magenta/20% background (#ff7eb6)
//   LEARNING -> Purple dot + purple text on purple/20% background  (#491d8b)
//   MASTERY  -> Green dot + green text on green/20% background     (#24a148)
//
// The pill consists of:
//   [colored dot] [STATE TEXT]
// wrapped in a capsule with a translucent background tinted to the state color.
//
// ARCHITECTURE ROLE:
// StatePillView is a pure presentation component — it takes a raw learning state
// string (from SwiftData's Move.learningState) and resolves it to a typed
// LearningState enum for color and display text. It has no side effects and
// doesn't modify any data.
//
// ANIMATION:
// The pill has spring animations on both the dot and the overall capsule that
// trigger when the resolved state changes. This creates a subtle "pop" effect
// when a move's state transitions (e.g., after a review promotes it from NEW to LEARNING).
// The dot animation has a 0.1s delay to create a staggered effect — the capsule
// scales first, then the dot pops.

import SwiftUI

/// A compact capsule badge that displays a move's learning state with color coding.
/// Input: raw learningState string from SwiftData. Output: colored pill UI.
struct StatePillView: View {

    // MARK: - Properties

    /// The raw learning state string from the SwiftData Move model.
    /// This is optional because Move.learningState is Optional<String> in the model.
    /// Values: "NEW", "LEARNING", "MASTERY", or nil.
    /// Nil and unrecognized values are resolved to .newState by LearningState.resolve().
    let learningState: String?

    // MARK: - Computed Properties

    /// Converts the raw string into a type-safe LearningState enum.
    /// LearningState.resolve(from:) handles nil and invalid values gracefully,
    /// defaulting to .newState. This computed property is used throughout the body
    /// to derive color and display text, ensuring consistent resolution in one place.
    private var resolvedState: LearningState {
        LearningState.resolve(from: learningState)
    }

    // MARK: - Body

    var body: some View {
        // HStack arranges the colored dot and text label side by side with 5pt spacing.
        HStack(spacing: 5) {

            // Colored indicator dot — a small filled circle in the state's color.
            // 9x9 points is small enough to be a subtle indicator without dominating the text.
            Circle()
                .fill(resolvedState.color)  // Color from LearningState.color (DesignSystem tokens)
                .frame(width: 9, height: 9)
                .scaleEffect(1.0)
                // Spring animation on the dot when the state changes.
                // The 0.1s delay creates a staggered effect — the capsule animates first,
                // then the dot "pops" slightly after. response=0.5 is relatively slow,
                // dampingFraction=0.7 gives a noticeable bounce.
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0).delay(0.1),
                    value: resolvedState
                )

            // State label text — shows the raw display text (e.g. "NEW", "LEARNING", "MASTERY").
            // Uses IBM Plex Mono 12pt bold for a compact, readable label.
            Text(resolvedState.displayText)
                .font(.ibmPlexMono(size: 12, weight: .bold))
        }
        // Pill padding — horizontal 10pt and vertical 5pt creates the capsule shape
        // when combined with .clipShape(Capsule()) below.
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // Translucent background — the state color at 20% opacity creates a subtle
        // tinted background that reinforces the color coding without being overwhelming.
        .background(resolvedState.color.opacity(0.2))
        // Text and dot color — the foreground color is set on the HStack and cascades
        // to the Text child. The Circle uses .fill() which overrides foregroundColor,
        // so only the Text is affected by this modifier.
        .foregroundColor(resolvedState.color)
        // Capsule clip shape — rounds the ends of the pill into semicircles.
        // Capsule() is equivalent to RoundedRectangle with cornerRadius = height/2,
        // but it automatically adapts to the content size.
        .clipShape(Capsule())
        // Overall scale animation — the entire pill scales when the state changes.
        // scaleEffect(1.0) is the resting state; the animation curve activates on
        // value change. response=0.6 is slower than the dot animation, dampingFraction=0.8
        // is more dampened (less bouncy), creating a gentle, smooth scale transition.
        .scaleEffect(1.0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0),
            value: resolvedState
        )
    }
}

// MARK: - Preview

/// Shows all three learning state pills side by side for visual comparison.
/// Useful for verifying color contrast, sizing, and spacing across all states.
#Preview("StatePill - Light") {
    HStack {
        StatePillView(learningState: "NEW")
        StatePillView(learningState: "LEARNING")
        StatePillView(learningState: "MASTERY")
    }
    .padding()
}

#Preview("StatePill - Dark") {
    HStack {
        StatePillView(learningState: "NEW")
        StatePillView(learningState: "LEARNING")
        StatePillView(learningState: "MASTERY")
    }
    .padding()
    .preferredColorScheme(.dark)
}
