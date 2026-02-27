// TrimmerPlayheadView.swift — Draggable playhead indicator for the video trimmer
//
// This view draws a vertical white line with a small circular grab handle that
// indicates the current playback position within the video timeline. It serves
// two purposes:
//
//   1. PASSIVE: During playback, the playhead moves automatically (driven by
//      VideoEditorView's periodic time observer updating currentFraction).
//   2. ACTIVE: The user can drag the playhead to scrub through the video,
//      which seeks the AVPlayer to the dragged position.
//
// The playhead is always clamped to the selected trim region (between startFraction
// and endFraction), so it never moves outside the trimmed portion of the video.
//
// VISUAL DESIGN:
//   - Vertical line: white, 2pt wide at rest, 3pt wide when dragging.
//   - Grab circle: white, 10pt diameter at rest, 14pt when dragging.
//   - Both use Elevation shadows for subtle depth (low for circle, medium for line).
//   - The circle sits ABOVE the timeline, offset by half the timeline height + half
//     the circle diameter, creating a "lollipop" shape.
//
// ARCHITECTURE ROLE:
//   This view is layered on top of TrimmerTimelineView in a ZStack within VideoEditorView.
//   Both share the named "timeline" coordinate space so drag positions are relative to
//   the same origin. The playhead only handles scrub/seek interaction — trim handle
//   interaction belongs to TrimmerTimelineView.
//
// HAPTIC FEEDBACK:
//   - handleGrab(): medium impact when the drag begins (user grabs the playhead)
//   - scrubTick(): light selection feedback every 1% of the timeline during drag
//   - trimPointSet(): medium impact when the drag ends (user releases the playhead)
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Parent view; provides metrics, duration, startFraction,
//     endFraction, currentFraction binding, and onScrub callback
//   - TrimmerTimelineView.swift: Sibling view beneath this in the ZStack
//   - HapticEngine.swift: Tactile feedback for grab, scrub, release
//   - Motion.swift: AppMotion.scrubRelease animation for line/circle size changes
//   - DesignSystem.swift: AppShadow.subtle, AppShadow.medium shadow tokens

import SwiftUI
import AVFoundation

// MARK: - TrimmerPlayheadView

/// A draggable playhead indicator that shows the current position within the trim region.
/// Displays as a vertical white line with a circular grab handle above the timeline.
struct TrimmerPlayheadView: View {

    // -----------------------------------------------------------------------
    // MARK: - Injected Dependencies
    // -----------------------------------------------------------------------

    /// Responsive layout metrics from the parent. Provides:
    ///   - timelineWidth: total width of the timeline in points
    ///   - timelineHeight: height of the timeline strip in points
    /// These must match the values used by TrimmerTimelineView so the
    /// playhead aligns correctly with the thumbnail strip.
    let metrics: LayoutMetrics

    /// Total duration of the video in seconds. Used to convert the drag
    /// position (a 0...1 fraction) to a CMTime value for seeking.
    let duration: TimeInterval

    /// Normalized start position of the trim range (0.0 = beginning).
    /// The playhead is clamped to never go below this value.
    let startFraction: CGFloat

    /// Normalized end position of the trim range (1.0 = end of video).
    /// The playhead is clamped to never exceed this value.
    let endFraction: CGFloat

    /// Current playback position as a fraction of total duration (0.0 to 1.0).
    /// Two-way binding:
    ///   - Written by VideoEditorView's periodic time observer (auto-advance during playback).
    ///   - Written by this view's drag gesture (manual scrubbing).
    ///   - Read to compute the playhead's pixel position.
    @Binding var currentFraction: CGFloat

    /// Callback invoked during drag to seek the video preview.
    /// Receives a CMTime computed from the drag position.
    let onScrub: (CMTime) -> Void

    // -----------------------------------------------------------------------
    // MARK: - Gesture State
    // -----------------------------------------------------------------------

    /// Tracks whether the playhead is currently being dragged.
    /// @GestureState auto-resets to false when the gesture ends, which triggers
    /// the contract animation (3pt -> 2pt line, 14pt -> 10pt circle).
    /// Used to:
    ///   - Scale up the line and grab circle during drag (visual feedback)
    ///   - Fire the handleGrab haptic on the first drag change
    @GestureState private var isDragging = false

    /// Tracks the last percentage index (0-100) where a scrub tick was fired.
    /// This gives one haptic tick per 1% of timeline, creating a smooth
    /// "ratchet" feel during scrubbing without overwhelming the Taptic Engine.
    @State private var lastScrubTick: Int = -1

    // -----------------------------------------------------------------------
    // MARK: - Computed Properties
    // -----------------------------------------------------------------------

    /// Timeline width in points (from LayoutMetrics).
    private var timelineWidth: CGFloat { metrics.timelineWidth }

    /// Timeline height in points (from LayoutMetrics).
    private var timelineHeight: CGFloat { metrics.timelineHeight }

    /// Width of the playhead vertical line.
    /// Expands from 2pt to 3pt when dragging for visual feedback.
    private var lineWidth: CGFloat { isDragging ? 3 : 2 }

    /// Diameter of the grab circle above the line.
    /// Expands from 10pt to 14pt when dragging for visual feedback.
    private var grabSize: CGFloat { isDragging ? 14 : 10 }

    /// The pixel x-position of the playhead within the timeline.
    /// Clamped between startFraction and endFraction so the playhead
    /// never moves outside the selected trim region.
    private var playheadX: CGFloat {
        // Clamp currentFraction to the trim range.
        let clamped = max(startFraction, min(endFraction, currentFraction))
        // Convert fraction to pixel position.
        return clamped * timelineWidth
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// Renders the playhead as two elements in a ZStack:
    ///   1. A vertical white rectangle (the line) centered at playheadX.
    ///   2. A white circle (the grab handle) positioned above the line.
    ///
    /// The entire view has a contentShape(Rectangle()) to expand the hit area
    /// for easier grabbing. A drag gesture handles scrubbing interaction.
    var body: some View {
        ZStack(alignment: .leading) {
            // -- Playhead vertical line --
            // A thin white rectangle spanning the full timeline height.
            // Offset horizontally to center on the playhead position.
            Rectangle()
                .fill(Color.white)
                .frame(width: lineWidth, height: timelineHeight)
                // AppShadow.medium: 8pt blur, 4pt y-offset, 12% opacity.
                // Adds subtle depth so the white line is visible against light thumbnails.
                .appShadow(AppShadow.medium)
                // Center the line on the playhead position.
                // Without the -lineWidth/2 offset, the line's leading edge would be at playheadX.
                .offset(x: playheadX - lineWidth / 2)

            // -- Grab handle circle --
            // A small white circle positioned directly above the line.
            // This is the primary touch target for drag interaction.
            Circle()
                .fill(Color.white)
                .frame(width: grabSize, height: grabSize)
                // AppShadow.subtle: 4pt blur, 2pt y-offset, 8% opacity.
                // Subtler than the line's shadow since the circle is smaller.
                .appShadow(AppShadow.subtle)
                // Position: horizontally centered on playheadX, vertically above the timeline.
                // The y-offset formula places the circle's center above the top edge of the timeline:
                //   -(timelineHeight/2) moves up to the top edge (from the ZStack center)
                //   -(grabSize/2) moves up by half the circle diameter
                //   +2 adds a tiny overlap so the circle visually connects to the line
                .offset(x: playheadX - grabSize / 2, y: -(timelineHeight / 2) - grabSize / 2 + 2)
        }
        // Explicit frame matches the timeline dimensions.
        .frame(width: timelineWidth, height: timelineHeight)
        // Expand the hit area to the full timeline rectangle for easier grabbing.
        // Without this, only the thin line and small circle would be tappable.
        .contentShape(Rectangle())
        // Animate size changes (line width, grab circle diameter) when drag starts/ends.
        // scrubRelease: spring with response 0.15, damping 0.9 — very snappy settle.
        .animation(AppMotion.scrubRelease, value: isDragging)
        // -- Drag gesture for scrubbing --
        .gesture(
            DragGesture(coordinateSpace: .named("timeline"))
                // Keep isDragging in sync with the gesture lifecycle.
                // Auto-resets to false when the gesture ends.
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    // Fire handleGrab haptic on the FIRST change event.
                    // isDragging is still false on the first .onChanged because
                    // .updating runs in the same frame. This is a known SwiftUI quirk:
                    // @GestureState updates lag by one frame relative to .onChanged.
                    if !isDragging {
                        // Medium impact haptic — signals the user has grabbed the playhead.
                        HapticEngine.shared.handleGrab()
                    }

                    // Convert the drag x-position to a fraction, clamped to the trim range.
                    // This ensures the playhead can't be dragged outside the selected region.
                    let fraction = max(startFraction, min(endFraction, value.location.x / timelineWidth))
                    currentFraction = fraction

                    // Scrub tick: fire a light selection haptic every 1% of the timeline.
                    // Int(fraction * 100) gives 100 evenly-spaced tick positions.
                    // This creates a smooth "ratchet" feel — not too frequent, not too sparse.
                    let tickIndex = Int(fraction * 100)
                    if tickIndex != lastScrubTick {
                        lastScrubTick = tickIndex
                        HapticEngine.shared.scrubTick()
                    }

                    // Seek the video preview to the dragged position.
                    // preferredTimescale: 600 gives sub-frame precision for standard video rates.
                    let time = CMTime(seconds: Double(fraction) * duration, preferredTimescale: 600)
                    onScrub(time)
                }
                .onEnded { _ in
                    // Medium impact haptic to confirm the scrub position is finalized.
                    HapticEngine.shared.trimPointSet()
                }
        )
    }
}
