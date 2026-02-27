// HapticEngine.swift — Semantic Haptic Feedback for Breakdex
//
// This file wraps UIKit's haptic feedback generators behind a semantic API.
// Instead of calling UIImpactFeedbackGenerator directly, views call named methods
// like `scrubTick()` or `exportComplete()` that describe WHAT happened, not HOW
// the feedback should feel. This decouples haptic design from view code.
//
// ARCHITECTURE ROLE:
//   Any SwiftUI view --> HapticEngine.shared.someAction()
//
// WHY A SINGLETON:
//   UIFeedbackGenerator instances are cheap but benefit from being pre-warmed
//   (`.prepare()` spins up the Taptic Engine hardware). A singleton lets us
//   prepare all generators once when the editor appears, rather than creating
//   new instances per view lifecycle.
//
// UIKit HAPTIC FEEDBACK SYSTEM:
//   iOS provides three categories of haptic feedback:
//   1. UIImpactFeedbackGenerator — Simulates physical impacts at varying intensities:
//      - .light: Subtle tap (button press, toggle)
//      - .medium: Moderate thud (grabbing a handle, starting a drag)
//      - .heavy: Strong thump (rotation snap, major action)
//      - .rigid: Sharp, precise click (snapping to a boundary)
//      - .soft: Gentle, dampened tap (not used in this app)
//   2. UISelectionFeedbackGenerator — Very light tick for selection changes
//      (scrolling through options, scrubbing a timeline)
//   3. UINotificationFeedbackGenerator — Distinct patterns for outcomes:
//      - .success: Ascending double-tap (export complete)
//      - .error: Harsh triple-tap (operation failed)
//      - .warning: Gentle double-tap (not used in this app)
//
// PREPARE/FIRE PATTERN:
//   Each method fires the feedback and then immediately calls .prepare() again.
//   This is the recommended pattern from Apple — .prepare() wakes up the Taptic
//   Engine so the NEXT call to .impactOccurred() has zero latency. Without it,
//   the first haptic after idle has ~50ms delay while the hardware spins up.
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Calls prepare() on appear, exportComplete()/error() on save
//   - TrimmerTimelineView.swift: scrubTick(), handleGrab(), handleSnap(), trimPointSet()
//   - TrimmerControlsView.swift: speedChange(), rotationSnap()
//   - CustomVideoPlayerView.swift: playbackToggle() on play/pause

import UIKit

/// Centralized haptic feedback manager with semantic methods.
/// `final` because this is a singleton utility — no subclassing needed.
final class HapticEngine {

    /// Shared singleton instance used throughout the app.
    static let shared = HapticEngine()

    // MARK: - Feedback Generators
    // Each generator corresponds to a UIKit haptic style.
    // They are stored as properties (not created on-demand) so that
    // prepare() can pre-warm them all at once.

    /// Light impact — subtle tap for minor confirmations.
    /// Used by: trimPointSet(), playbackToggle()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)

    /// Medium impact — moderate thud for interactive grabs.
    /// Used by: handleGrab()
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    /// Heavy impact — strong thump for significant spatial changes.
    /// Used by: rotationSnap()
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

    /// Rigid impact — sharp, precise click for boundary snaps.
    /// Used by: handleSnap(), speedChange()
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)

    /// Selection feedback — very light tick for continuous selection changes.
    /// Used by: scrubTick() (fires repeatedly as the user drags across the timeline)
    private let selection = UISelectionFeedbackGenerator()

    /// Notification feedback — distinct success/error/warning patterns.
    /// Used by: exportComplete() (.success), error() (.error)
    private let notification = UINotificationFeedbackGenerator()

    /// Private init enforces the singleton pattern.
    /// No setup needed — generators are initialized as stored properties above.
    private init() {}

    // MARK: - Prepare

    /// Pre-warms ALL haptic generators by putting the Taptic Engine in a ready state.
    ///
    /// Call this when the video editor appears (VideoEditorView.onAppear).
    /// The Taptic Engine powers down after a few seconds of inactivity, so individual
    /// methods also call .prepare() after firing to keep it warm for the next event.
    ///
    /// Without prepare(), the first haptic after idle has noticeable latency (~50ms)
    /// as the hardware spins up. With prepare(), feedback is instantaneous.
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Semantic Feedback Methods
    // Each method maps a user action to a haptic style.
    // The method name describes the action, not the haptic type.
    // This makes call sites self-documenting:
    //   HapticEngine.shared.scrubTick()    -- clear intent
    //   selection.selectionChanged()        -- unclear without context

    /// Fires a subtle selection tick while the user scrubs across the timeline.
    ///
    /// Called repeatedly during drag gestures on TrimmerTimelineView's playhead
    /// and trim handles. The selection generator is designed for rapid-fire use —
    /// it produces a light "ticking" sensation similar to scrolling a picker wheel.
    ///
    /// Called from: TrimmerTimelineView (during drag gesture value changes)
    func scrubTick() {
        selection.selectionChanged()
        selection.prepare()  // Re-arm for the next tick (drag is still in progress)
    }

    /// Fires a medium impact when the user grabs a trim handle or playhead.
    ///
    /// Provides tactile confirmation that the drag has started. The medium
    /// intensity matches the "weight" of grabbing an interactive control.
    ///
    /// Called from: TrimmerTimelineView (drag gesture onChanged, first event)
    func handleGrab() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Fires a rigid impact when a handle snaps to a boundary (start/end of video).
    ///
    /// The rigid style produces a sharp, precise "click" that feels like hitting
    /// a physical stop. Used when the trim handle reaches 0:00 or the video's end.
    ///
    /// Called from: TrimmerTimelineView (when handle position clamps to min/max)
    func handleSnap() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// Fires a light impact when a trim point is confirmed (handle released).
    ///
    /// Lighter than handleGrab() to signal "action complete" without
    /// being jarring. The trim range is now set.
    ///
    /// Called from: TrimmerTimelineView (drag gesture onEnded)
    func trimPointSet() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Fires a light impact when play/pause is toggled.
    ///
    /// Subtle feedback that confirms the tap registered. Light intensity
    /// because play/pause is a frequent, non-destructive action.
    ///
    /// Called from: VideoEditorView (play/pause button tap)
    func playbackToggle() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Fires a rigid impact when the playback speed changes.
    ///
    /// The rigid style gives a "detent" feel, like clicking through a
    /// physical dial. Speed changes in Breakdex cycle through fixed values
    /// (0.25x, 0.5x, 1x, 2x), so the detent metaphor fits.
    ///
    /// Called from: TrimmerControlsView (speed pill tap, aspect ratio change)
    func speedChange() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    /// Fires a heavy impact when the video is rotated 90 degrees.
    ///
    /// Heavy intensity because rotation is a significant spatial transformation.
    /// The strong thump makes the rotation feel "physical" — like turning
    /// a heavy object. Only fires once per tap (not continuous).
    ///
    /// Called from: TrimmerControlsView (rotation button tap)
    func rotationSnap() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Fires a success notification when video export completes.
    ///
    /// The success pattern is a distinctive ascending double-tap that
    /// iOS users associate with completion (same as Apple Pay success).
    /// Only fires once at the end of a potentially long export.
    ///
    /// Called from: VideoEditorView (after VideoCompositionPipeline.export() succeeds)
    func exportComplete() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Fires an error notification when an operation fails.
    ///
    /// The error pattern is a harsh triple-tap that signals something went wrong.
    /// Used for export failures, file not found, and other error states.
    ///
    /// Called from: VideoEditorView (when export throws an error)
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
