// TrimmerTimelineView.swift — Video trim timeline with thumbnail strip and drag handles
//
// This view renders the horizontal thumbnail strip that users interact with to set
// the trim range (start and end points) of a video in the VideoEditorView. It consists of:
//
//   1. Thumbnail strip: A row of evenly-spaced video frame thumbnails spanning the full duration.
//   2. Dim overlays: Semi-transparent black rectangles dimming the excluded (trimmed-out) regions.
//   3. Selection border: An accent-colored rounded rectangle outlining the selected region.
//   4. Drag handles: Two accent-colored handles (left = start, right = end) that the user
//      drags to adjust the trim range. Handles expand when actively dragged.
//
// ARCHITECTURE ROLE:
//   This view is a child of VideoEditorView, layered in a ZStack with TrimmerPlayheadView.
//   It owns the trim handle interaction (start/end drag) while TrimmerPlayheadView owns
//   the playhead scrub interaction. Both share the same coordinate space ("timeline").
//
// COORDINATE SYSTEM:
//   All positions are expressed as fractions (0.0 to 1.0) of the full video duration.
//   - startFraction: where the trim begins (0.0 = start of video)
//   - endFraction: where the trim ends (1.0 = end of video)
//   The fractions are converted to pixel positions by multiplying by timelineWidth.
//   When the user finishes editing, VideoEditorView converts these fractions to
//   CMTime values (fraction * duration) for the export pipeline.
//
// THUMBNAIL STRATEGY:
//   Short videos (<120s) use a regular HStack — all thumbnails are loaded at once.
//   Long videos (>120s) use a ScrollView + LazyHStack for on-demand loading.
//   AdaptiveThumbnailGenerator manages the actual image generation with a tiered
//   strategy (more thumbnails for longer videos) and caches results in an NSCache.
//   The onAppear handler for each thumbnail cell updates the visible range, which
//   triggers the generator to prioritize loading nearby thumbnails.
//
// HAPTIC FEEDBACK:
//   - scrubTick(): light selection feedback at each thumbnail boundary during drag
//   - handleSnap(): rigid impact when a handle snaps to the 0% or 100% boundary
//   - trimPointSet(): medium impact when the user releases a handle
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Parent view; provides metrics, duration, bindings, onScrub callback
//   - TrimmerPlayheadView.swift: Sibling view layered on top in the same ZStack
//   - AdaptiveThumbnailGenerator.swift: Generates video frame thumbnails (AVAssetImageGenerator)
//   - LayoutMetrics.swift: Provides timelineWidth, timelineHeight, thumbnailWidth, thumbnailCount
//   - HapticEngine.swift: Tactile feedback for scrub ticks, handle snaps, trim point set
//   - Motion.swift: AppMotion.handleRelease animation for handle expand/contract
//   - DesignSystem.swift: Color.accent, Color.neutralFill, Radius.sm

import SwiftUI
import AVFoundation

// MARK: - TrimmerTimelineView

/// The timeline strip with draggable trim handles, displayed in the VideoEditorView.
/// Shows a row of video thumbnails with interactive start/end handles for setting
/// the trim range.
struct TrimmerTimelineView: View {

    // -----------------------------------------------------------------------
    // MARK: - Injected Dependencies
    // -----------------------------------------------------------------------

    /// Responsive layout metrics from the parent. Provides:
    ///   - timelineWidth: available width for the thumbnail strip (screenWidth - 2 * horizontalPadding)
    ///   - timelineHeight: height of the strip (60-80pt depending on device class)
    ///   - thumbnailWidth: ideal width per thumbnail (timelineHeight * golden ratio)
    let metrics: LayoutMetrics

    /// The thumbnail generator that provides video frame images for the strip.
    /// This is an AdaptiveThumbnailGenerator instance created by VideoEditorView
    /// and configured with the video duration and desired thumbnail count.
    /// We call .thumbnail(at:) to get cached images and .updateVisibleRange()
    /// to tell it which thumbnails to prioritize generating.
    let thumbnailGenerator: AdaptiveThumbnailGenerator

    /// Total duration of the video in seconds. Used to:
    ///   - Calculate the minimumGap (prevents trimming to less than 1 second)
    ///   - Convert drag positions to CMTime for the onScrub callback
    let duration: TimeInterval

    /// Normalized start position of the trim range (0.0 = beginning of video).
    /// Two-way binding — updated by the left handle drag gesture.
    /// VideoEditorView reads this to set the export start time.
    @Binding var startFraction: CGFloat  // 0...1

    /// Normalized end position of the trim range (1.0 = end of video).
    /// Two-way binding — updated by the right handle drag gesture.
    /// VideoEditorView reads this to set the export end time.
    @Binding var endFraction: CGFloat    // 0...1

    /// Callback invoked during handle drag to seek the video preview.
    /// Receives a CMTime computed from the drag position so the user
    /// can see which frame they're trimming to.
    let onScrub: (CMTime) -> Void

    // -----------------------------------------------------------------------
    // MARK: - Gesture State
    // -----------------------------------------------------------------------

    /// Tracks whether the START handle is being dragged, and its current x position.
    /// @GestureState automatically resets to nil when the gesture ends, which triggers
    /// the handle contract animation (handleExpandedWidth -> handleWidth).
    @GestureState private var startDragOffset: CGFloat? = nil

    /// Tracks whether the END handle is being dragged, and its current x position.
    /// Same reset behavior as startDragOffset.
    @GestureState private var endDragOffset: CGFloat? = nil

    /// Tracks the last thumbnail index where a scrub tick haptic was fired.
    /// Prevents firing multiple ticks for the same thumbnail boundary.
    /// Reset to -1 means no tick has been fired yet for this drag gesture.
    @State private var lastTickIndex: Int = -1

    // -----------------------------------------------------------------------
    // MARK: - Layout Constants and Computed Properties
    // -----------------------------------------------------------------------

    /// Width of the trim handle at rest (not being dragged).
    private let handleWidth: CGFloat = 14

    /// Width of the trim handle while being actively dragged.
    /// The 4pt expansion (14 -> 18) provides visual feedback that the handle is "grabbed".
    private let handleExpandedWidth: CGFloat = 18

    /// Available width for the entire timeline strip in points.
    /// Comes from LayoutMetrics: screenWidth - (2 * horizontalPadding).
    private var timelineWidth: CGFloat { metrics.timelineWidth }

    /// Height of the timeline strip in points. Device-responsive:
    /// SE: 60pt, standard/ProMax: 68pt, iPadMini: 72pt, iPad/iPadPro: 80pt.
    private var timelineHeight: CGFloat { metrics.timelineHeight }

    /// Total number of thumbnails to display. Determined by AdaptiveThumbnailGenerator
    /// based on video duration and available width.
    private var thumbnailCount: Int { thumbnailGenerator.totalCount }

    /// Pixel x-position of the start handle (left edge of the selected region).
    /// Computed by multiplying the 0...1 fraction by the total timeline width.
    private var startX: CGFloat { startFraction * timelineWidth }

    /// Pixel x-position of the end handle (right edge of the selected region).
    private var endX: CGFloat { endFraction * timelineWidth }

    /// Minimum pixel distance between the start and end handles.
    /// Prevents the user from trimming to a degenerate zero-length clip.
    /// The gap is the larger of:
    ///   - 10pt (absolute minimum for touch targets)
    ///   - 1 second of video expressed in pixels (timelineWidth / duration)
    /// For a 30-second video on a 350pt-wide timeline, that's ~11.7pt per second.
    private var minimumGap: CGFloat {
        guard duration > 0 else { return 10 }
        return max(10, timelineWidth * CGFloat(1.0 / duration))
    }

    // -----------------------------------------------------------------------
    // MARK: - Body
    // -----------------------------------------------------------------------

    /// Layers all timeline elements in a ZStack aligned to the leading edge.
    /// The order (bottom to top) is: thumbnails, dim overlays, selection border, handles.
    /// The entire stack is clipped to a rounded rectangle and given a named
    /// coordinate space ("timeline") so drag gestures can use position-based coordinates.
    var body: some View {
        ZStack(alignment: .leading) {
            // Layer 1 (bottom): The thumbnail strip — video frame images in a row.
            thumbnailStrip

            // Layer 2: Dim overlays — semi-transparent black over the excluded regions.
            // These darken the thumbnails outside the selected trim range.
            dimOverlays

            // Layer 3: Selection border — accent-colored outline around the selected region.
            // This is non-interactive (allowsHitTesting: false) since handles manage the drag.
            selectionBorder

            // Layer 4: Start handle (left) — draggable to set the trim start point.
            handle(isStart: true)

            // Layer 5 (top): End handle (right) — draggable to set the trim end point.
            handle(isStart: false)
        }
        // Explicit frame ensures the ZStack has the correct dimensions.
        .frame(width: timelineWidth, height: timelineHeight)
        // Clip to rounded rectangle — Radius.sm (6pt) for subtle rounding.
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        // Named coordinate space used by DragGesture(coordinateSpace: .named("timeline"))
        // in both the handle gestures and TrimmerPlayheadView's gesture.
        .coordinateSpace(name: "timeline")
    }

    // -----------------------------------------------------------------------
    // MARK: - Thumbnail Strip
    // -----------------------------------------------------------------------

    /// Renders the row of video frame thumbnails.
    ///
    /// Two rendering strategies based on video duration:
    ///   - Short videos (<= 120s): Regular HStack renders all cells eagerly.
    ///     For up to ~40 thumbnails, the overhead of lazy loading isn't worth it.
    ///   - Long videos (> 120s): ScrollView + LazyHStack for on-demand rendering.
    ///     Up to 80 thumbnails are generated lazily as they scroll into view.
    ///
    /// Both strategies use 1pt spacing between cells and neutralFill as the background
    /// (visible through the gaps and while thumbnails are still loading).
    @ViewBuilder
    private var thumbnailStrip: some View {
        if duration > 120 {
            // LONG VIDEO STRATEGY: ScrollView + LazyHStack.
            // showsIndicators: false hides the scroll bar (the handles provide navigation).
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 1) {
                    // Each cell shows one video frame thumbnail at an evenly-spaced time.
                    ForEach(0..<thumbnailCount, id: \.self) { index in
                        thumbnailCell(index: index)
                    }
                }
            }
            .frame(width: timelineWidth, height: timelineHeight)
            // neutralFill: light gray (#edf0f5) in light mode, dark slate (#181b21) in dark mode.
            // Visible as the background while thumbnails load.
            .background(Color.neutralFill)
        } else {
            // SHORT VIDEO STRATEGY: Regular HStack renders all cells immediately.
            HStack(spacing: 1) {
                ForEach(0..<thumbnailCount, id: \.self) { index in
                    thumbnailCell(index: index)
                }
            }
            .frame(width: timelineWidth, height: timelineHeight)
            .background(Color.neutralFill)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Individual Thumbnail Cell
    // -----------------------------------------------------------------------

    /// Renders a single thumbnail cell at the given index.
    ///
    /// Each cell has a fixed width (timelineWidth / thumbnailCount) and the full
    /// timeline height. The cell either shows the generated UIImage (aspect-fill,
    /// clipped to prevent overflow) or a neutralFill placeholder while loading.
    ///
    /// The onAppear modifier updates the AdaptiveThumbnailGenerator's visible range
    /// (current index +/- 2) so it prioritizes generating nearby thumbnails first.
    ///
    /// - Parameter index: The 0-based index of this thumbnail in the strip.
    @ViewBuilder
    private func thumbnailCell(index: Int) -> some View {
        // Each cell gets an equal share of the total timeline width.
        // max(1, thumbnailCount) prevents division by zero.
        let cellWidth = timelineWidth / CGFloat(max(1, thumbnailCount))
        Group {
            if let image = thumbnailGenerator.thumbnail(at: index) {
                // Thumbnail is available in the cache — display it.
                Image(uiImage: image)
                    .resizable()
                    // .fill ensures the thumbnail covers the cell completely.
                    // Combined with .clipped(), this crops excess rather than letterboxing.
                    .aspectRatio(contentMode: .fill)
            } else {
                // Thumbnail hasn't been generated yet — show placeholder.
                Color.neutralFill
            }
        }
        .frame(width: cellWidth, height: timelineHeight)
        // Clip overflow from the aspect-fill. Without this, wider-than-expected
        // thumbnails would bleed into adjacent cells.
        .clipped()
        .onAppear {
            // Tell the generator which indices are currently visible.
            // The generator prioritizes this range for loading, so thumbnails
            // near the user's scroll position load first.
            // The range extends 2 indices before and after for pre-loading.
            let lo = max(0, index - 2)
            let hi = min(thumbnailCount, index + 3)
            thumbnailGenerator.updateVisibleRange(lo..<hi)
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Dim Overlays
    // -----------------------------------------------------------------------

    /// Semi-transparent black rectangles that dim the regions OUTSIDE the selected
    /// trim range. This creates a visual contrast where the selected region shows
    /// bright thumbnails and the excluded regions appear darkened.
    ///
    /// Two rectangles:
    ///   - Left dim: from x=0 to x=startX (the part before the start handle)
    ///   - Right dim: from x=endX to x=timelineWidth (the part after the end handle)
    ///
    /// allowsHitTesting(false) ensures these overlays don't block touch events
    /// on the handles or thumbnails beneath them.
    private var dimOverlays: some View {
        ZStack(alignment: .leading) {
            // Left dim overlay: covers everything before the start handle.
            Rectangle()
                .fill(Color.black.opacity(0.5))
                // Width is the start handle's pixel position (startFraction * timelineWidth).
                // max(0, ...) prevents negative widths when startFraction is 0.
                .frame(width: max(0, startX), height: timelineHeight)

            // Right dim overlay: covers everything after the end handle.
            Rectangle()
                .fill(Color.black.opacity(0.5))
                // Width is the remaining space from the end handle to the right edge.
                .frame(width: max(0, timelineWidth - endX), height: timelineHeight)
                // Offset positions this rectangle at the end handle's pixel position.
                .offset(x: endX)
        }
        // Don't intercept touch events — let them pass through to the handles.
        .allowsHitTesting(false)
    }

    // -----------------------------------------------------------------------
    // MARK: - Selection Border
    // -----------------------------------------------------------------------

    /// An accent-colored rounded rectangle stroke that outlines the selected trim region.
    /// This provides a clear visual boundary between the selected and excluded areas.
    /// It spans from startX to endX with a 2pt stroke width.
    ///
    /// Non-interactive (allowsHitTesting: false) — handles manage all drag interaction.
    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 3)
            // .stroke draws only the outline, not a filled shape.
            // Color.accent is the brand blue (#2362a2).
            .stroke(Color.accent, lineWidth: 2)
            // Width spans from the start handle to the end handle.
            .frame(width: max(0, endX - startX), height: timelineHeight)
            // Position the border at the start handle's x-coordinate.
            .offset(x: startX)
            .allowsHitTesting(false)
    }

    // -----------------------------------------------------------------------
    // MARK: - Trim Handles
    // -----------------------------------------------------------------------

    /// Renders a single trim handle (either start or end).
    ///
    /// Each handle is an accent-colored rounded rectangle with a chevron icon inside.
    /// The handle expands from 14pt to 18pt wide when actively dragged, providing
    /// tactile visual feedback. The expansion animates with AppMotion.handleRelease
    /// (spring: response 0.25, damping 0.85) for a smooth settle-after-drag effect.
    ///
    /// - Parameter isStart: true for the left/start handle, false for the right/end handle.
    @ViewBuilder
    private func handle(isStart: Bool) -> some View {
        // Determine if THIS handle is currently being dragged.
        // @GestureState is non-nil during the drag and auto-resets to nil on release.
        let isDragging = isStart ? (startDragOffset != nil) : (endDragOffset != nil)
        // Expand when dragged: 14pt -> 18pt width.
        let width = isDragging ? handleExpandedWidth : handleWidth
        // Center the handle on its trim position.
        // startX - width/2 for the start handle, endX - width/2 for the end handle.
        let xPos = isStart ? startX - width / 2 : endX - width / 2

        RoundedRectangle(cornerRadius: 3)
            // Accent blue (#2362a2) fill.
            .fill(Color.accent)
            .frame(width: width, height: timelineHeight)
            .overlay {
                // Chevron icon: left-pointing for start, right-pointing for end.
                // Small (10pt) and bold to be visible at the handle's narrow width.
                Image(systemName: isStart ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: xPos)
            // Animate the width change (expand/contract) when drag starts/ends.
            // handleRelease: spring with response 0.25, damping 0.85 — smooth settle.
            .animation(AppMotion.handleRelease, value: isDragging)
            // Attach the appropriate drag gesture.
            .gesture(dragGesture(isStart: isStart))
    }

    // -----------------------------------------------------------------------
    // MARK: - Drag Gestures
    // -----------------------------------------------------------------------

    /// Creates a DragGesture for the specified handle (start or end).
    ///
    /// The gesture uses the named "timeline" coordinate space so that value.location.x
    /// gives the position relative to the timeline's leading edge (not the screen).
    ///
    /// The .updating modifier keeps the @GestureState in sync (non-nil while dragging,
    /// auto-resets to nil on release). This drives the handle expansion animation.
    ///
    /// .onChanged calls handleDragChanged() to update the fraction and fire haptics.
    /// .onEnded fires a trimPointSet() haptic to signal the drag is complete.
    ///
    /// - Parameter isStart: true for the start handle gesture, false for end.
    /// - Returns: A configured DragGesture.
    private func dragGesture(isStart: Bool) -> some Gesture {
        if isStart {
            return DragGesture(coordinateSpace: .named("timeline"))
                .updating($startDragOffset) { value, state, _ in
                    // Store the current x position; this makes startDragOffset non-nil,
                    // which triggers the handle expansion.
                    state = value.location.x
                }
                .onChanged { value in
                    handleDragChanged(x: value.location.x, isStart: true)
                }
                .onEnded { _ in
                    // Medium impact haptic to confirm the trim point is set.
                    HapticEngine.shared.trimPointSet()
                }
        } else {
            return DragGesture(coordinateSpace: .named("timeline"))
                .updating($endDragOffset) { value, state, _ in
                    state = value.location.x
                }
                .onChanged { value in
                    handleDragChanged(x: value.location.x, isStart: false)
                }
                .onEnded { _ in
                    HapticEngine.shared.trimPointSet()
                }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Handle Drag Logic
    // -----------------------------------------------------------------------

    /// Processes a handle drag position update.
    ///
    /// This method:
    /// 1. Converts the pixel x-position to a 0...1 fraction.
    /// 2. Clamps the fraction to maintain the minimumGap between handles.
    /// 3. Fires a handleSnap haptic when the handle reaches the 0% or 100% boundary.
    /// 4. Fires a scrubTick haptic at each thumbnail boundary for tactile feedback.
    /// 5. Calls onScrub to seek the video preview to the current position.
    ///
    /// - Parameters:
    ///   - x: The current drag position in pixels within the "timeline" coordinate space.
    ///   - isStart: true if dragging the start handle, false for the end handle.
    private func handleDragChanged(x: CGFloat, isStart: Bool) {
        // Convert pixel position to 0...1 fraction, clamped to valid range.
        let fraction = max(0, min(1, x / timelineWidth))

        if isStart {
            // START HANDLE: can't go past the end handle minus the minimum gap.
            let maxFraction = endFraction - minimumGap / timelineWidth
            startFraction = min(fraction, maxFraction)

            // Snap feedback: rigid impact when the handle reaches the leftmost boundary.
            // 0.001 threshold accounts for floating-point imprecision.
            if startFraction <= 0.001 {
                HapticEngine.shared.handleSnap()
            }
        } else {
            // END HANDLE: can't go before the start handle plus the minimum gap.
            let minFraction = startFraction + minimumGap / timelineWidth
            endFraction = max(fraction, minFraction)

            // Snap feedback: rigid impact when the handle reaches the rightmost boundary.
            if endFraction >= 0.999 {
                HapticEngine.shared.handleSnap()
            }
        }

        // Scrub tick: fire a light selection haptic at each thumbnail boundary.
        // This creates a "detent" feel as the handle crosses thumbnail edges,
        // similar to scrolling through a date picker wheel.
        let currentIndex = Int(fraction * CGFloat(thumbnailCount))
        if currentIndex != lastTickIndex {
            lastTickIndex = currentIndex
            HapticEngine.shared.scrubTick()
        }

        // Seek the video preview to the current drag position so the user
        // can see which frame they're trimming to.
        // preferredTimescale: 600 gives sub-frame precision.
        let time = CMTime(seconds: Double(fraction) * duration, preferredTimescale: 600)
        onScrub(time)
    }
}
