// CropOverlayView.swift — Draggable crop region overlay for the video editor
//
// This view draws a crop rectangle on top of a video preview, allowing the user
// to position the crop window by dragging. It's used in the VideoEditorView when
// the user selects a non-original aspect ratio (e.g. 1:1, 16:9, 9:16).
//
// HOW CROPPING WORKS:
//   When the target aspect ratio differs from the source video's aspect ratio,
//   the crop window is smaller than the video in one dimension. The user drags
//   the crop window to choose which part of the video to keep.
//
//   Example: A 16:9 video cropped to 1:1 (square)
//   ┌────────────────────────────────────┐
//   │  dim  │ ┌────────┐ │     dim      │  ← user slides the square left/right
//   │       │ │  CROP  │ │              │
//   │       │ └────────┘ │              │
//   └────────────────────────────────────┘
//
//   Example: A 16:9 video cropped to 9:16 (portrait)
//   ┌────────────────────────────────────┐
//   │          dim (top)                 │
//   │  ┌──────────────────────┐         │  ← user slides the rectangle up/down
//   │  │       CROP           │         │
//   │  └──────────────────────┘         │
//   │          dim (bottom)              │
//   └────────────────────────────────────┘
//
// COORDINATE SYSTEM:
//   cropOffset is a normalized CGPoint where:
//   - x ranges from 0.0 (crop at left edge) to 1.0 (crop at right edge)
//   - y ranges from 0.0 (crop at top edge) to 1.0 (crop at bottom edge)
//   - 0.5 in either axis means the crop is centered
//
//   The actual pixel offset is computed by multiplying the normalized value by
//   the available slide distance (container size minus crop size).
//
// DRAG DIRECTION:
//   Only one axis of dragging is enabled at a time, determined by isHorizontalCrop:
//   - If the source is wider than the target (e.g. 16:9 → 1:1): horizontal drag
//   - If the source is taller than the target (e.g. 1:1 → 9:16): vertical drag
//   A directional arrow indicator shows which way the user can drag.
//
// VISUAL LAYERS (ZStack, bottom to top):
//   1. Dim overlay — semi-transparent black (45% opacity) covering the cropped-out areas.
//      Split into 4 non-overlapping rectangles: top, bottom, left, right.
//   2. Crop border — white rounded rectangle stroke (2pt) outlining the crop window.
//   3. Drag indicator — arrow icon in the center showing the allowed drag direction.
//
// DESIGN SYSTEM:
//   This view intentionally does NOT use design system tokens for colors because
//   it overlays video content — the white/black color scheme is for maximum contrast
//   against any video background. It does use GeometryReader for responsive layout.

import SwiftUI   // SwiftUI framework — provides View, GeometryReader, DragGesture, etc.

// MARK: - CropOverlayView

/// Draws a draggable crop rectangle over a video preview.
/// The crop window maintains the target aspect ratio and can be slid along
/// one axis to choose which portion of the video to keep.
struct CropOverlayView: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    /// The aspect ratio (width / height) of the source video being cropped.
    /// For example, a 1920x1080 video has sourceAspectRatio = 16/9 = 1.778.
    /// Used to determine whether the crop slides horizontally or vertically.
    let sourceAspectRatio: CGFloat

    /// The aspect ratio (width / height) of the desired crop output.
    /// For example: 1:1 square = 1.0, 16:9 = 1.778, 9:16 = 0.5625.
    /// Determines the shape and size of the crop window.
    let targetAspectRatio: CGFloat

    /// The normalized crop position, bound to VideoEditParameters.cropOffset.
    /// x: 0.0 = crop at left edge, 0.5 = centered, 1.0 = right edge
    /// y: 0.0 = crop at top edge, 0.5 = centered, 1.0 = bottom edge
    /// Two-way binding so the parent view can read the position for export.
    @Binding var cropOffset: CGPoint

    // -------------------------------------------------------------------------
    // MARK: Gesture State
    // -------------------------------------------------------------------------

    /// Stores the cropOffset value at the moment the drag gesture began.
    /// @GestureState automatically resets to nil when the gesture ends.
    /// Used to compute delta from the starting position (absolute positioning,
    /// not incremental) which prevents drift during fast drags.
    @GestureState private var dragStart: CGPoint? = nil

    // -------------------------------------------------------------------------
    // MARK: Computed Properties
    // -------------------------------------------------------------------------

    /// Determines whether the crop window slides horizontally or vertically.
    ///
    /// When the source video is wider than the target crop (sourceAspectRatio > targetAspectRatio),
    /// the crop window is narrower than the video, so it slides left/right.
    ///
    /// When the source video is taller than the target crop, the crop window is shorter
    /// than the video, so it slides up/down.
    ///
    /// Example: 16:9 video (1.778) → 1:1 crop (1.0) → source is wider → horizontal crop
    /// Example: 1:1 video (1.0) → 9:16 crop (0.5625) → source is wider → horizontal crop
    /// Example: 16:9 video (1.778) → 9:16 crop (0.5625) → source is wider → horizontal crop
    private var isHorizontalCrop: Bool {
        sourceAspectRatio > targetAspectRatio
    }

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    /// The main view body. Uses a GeometryReader to get the container size, then
    /// computes the crop window size and position based on the target aspect ratio
    /// and current cropOffset. Renders three layers: dim overlay, crop border, drag indicator.
    var body: some View {
        GeometryReader { geo in
            // The container size represents the video preview area
            let containerSize = geo.size

            // Compute the crop window dimensions to fit the target aspect ratio
            // within the container while maximizing one dimension
            let cropSize = computeCropSize(in: containerSize)

            // Compute the top-left origin of the crop window based on the normalized offset
            let cropOrigin = computeCropOrigin(containerSize: containerSize, cropSize: cropSize)

            ZStack {
                // Layer 1: Semi-transparent dim overlay covering the area outside the crop window.
                // Split into 4 non-overlapping rectangles to avoid double-darkening at corners.
                dimOverlay(containerSize: containerSize, cropOrigin: cropOrigin, cropSize: cropSize)

                // Layer 2: White border around the crop window.
                // Uses a RoundedRectangle with a thin stroke to outline the keep region.
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)   // Semi-transparent white, 2pt stroke
                    .frame(width: cropSize.width, height: cropSize.height)
                    .position(
                        x: cropOrigin.x + cropSize.width / 2,    // Center of the crop window (x)
                        y: cropOrigin.y + cropSize.height / 2     // Center of the crop window (y)
                    )

                // Layer 3: Directional arrow icon showing which way the user can drag.
                // Shows left-right arrows for horizontal crop, up-down for vertical crop.
                dragIndicator(cropOrigin: cropOrigin, cropSize: cropSize)
            }
            // Make the entire container tappable/draggable, not just the visible elements
            .contentShape(Rectangle())
            // Drag gesture to reposition the crop window
            .gesture(
                DragGesture()
                    // .updating captures the cropOffset at the start of the drag.
                    // This runs on every gesture update but only sets the initial value once.
                    .updating($dragStart) { _, state, _ in
                        if state == nil { state = cropOffset }   // Capture starting position
                    }
                    // .onChanged runs on every drag movement.
                    // Computes the new normalized offset from the drag translation.
                    .onChanged { value in
                        // dragStart is guaranteed to be set by .updating before .onChanged fires
                        guard let start = dragStart else { return }

                        if isHorizontalCrop {
                            // Horizontal crop: translate drag distance to normalized 0...1 range.
                            // maxSlide = total distance the crop window can travel horizontally.
                            let maxSlide = containerSize.width - cropSize.width
                            guard maxSlide > 0 else { return }   // No room to slide (same width)
                            // delta = fraction of total slide distance covered by this drag
                            let delta = value.translation.width / maxSlide
                            // Clamp to 0...1 range to prevent dragging outside bounds
                            cropOffset.x = min(1, max(0, start.x + delta))
                        } else {
                            // Vertical crop: same logic but for the Y axis
                            let maxSlide = containerSize.height - cropSize.height
                            guard maxSlide > 0 else { return }
                            let delta = value.translation.height / maxSlide
                            cropOffset.y = min(1, max(0, start.y + delta))
                        }
                    }
            )
        }
    }

    // =========================================================================
    // MARK: - Layout Math
    // =========================================================================

    /// Computes the pixel dimensions of the crop window within the given container.
    ///
    /// The crop window is sized to fit the target aspect ratio while being as large
    /// as possible within the container. One dimension will match the container exactly,
    /// and the other will be smaller (creating the slideable gap).
    ///
    /// ALGORITHM:
    /// - If the container is wider than the target ratio: the crop fills the full height,
    ///   and the width is computed from height * targetAspectRatio (narrower than container).
    /// - If the container is taller than the target ratio: the crop fills the full width,
    ///   and the height is computed from width / targetAspectRatio (shorter than container).
    ///
    /// - Parameter containerSize: The size of the GeometryReader container (the video preview area).
    /// - Returns: The CGSize of the crop window in points.
    private func computeCropSize(in containerSize: CGSize) -> CGSize {
        let containerRatio = containerSize.width / containerSize.height
        if containerRatio > targetAspectRatio {
            // Container is wider than target — crop fills the full height,
            // width is computed to match the target ratio (leaves horizontal gap for sliding)
            let h = containerSize.height
            let w = h * targetAspectRatio
            return CGSize(width: w, height: h)
        } else {
            // Container is taller than target — crop fills the full width,
            // height is computed to match the target ratio (leaves vertical gap for sliding)
            let w = containerSize.width
            let h = w / targetAspectRatio
            return CGSize(width: w, height: h)
        }
    }

    /// Computes the top-left origin point of the crop window.
    ///
    /// Multiplies the normalized cropOffset (0...1) by the maximum slide distance
    /// in each axis. When cropOffset.x = 0, the crop is at the left edge.
    /// When cropOffset.x = 1, the crop is at the right edge.
    /// When cropOffset.x = 0.5, the crop is centered horizontally.
    ///
    /// - Parameters:
    ///   - containerSize: The container dimensions.
    ///   - cropSize: The crop window dimensions (from computeCropSize).
    /// - Returns: The top-left CGPoint of the crop window in container coordinates.
    private func computeCropOrigin(containerSize: CGSize, cropSize: CGSize) -> CGPoint {
        // Maximum distance the crop can travel in each axis
        let maxX = containerSize.width - cropSize.width     // 0 if crop fills full width
        let maxY = containerSize.height - cropSize.height   // 0 if crop fills full height
        return CGPoint(
            x: maxX * cropOffset.x,   // Horizontal position: 0 = left, maxX = right
            y: maxY * cropOffset.y     // Vertical position: 0 = top, maxY = bottom
        )
    }

    // =========================================================================
    // MARK: - Dim Overlay
    // =========================================================================

    /// Draws four semi-transparent black rectangles around the crop window,
    /// dimming the areas of the video that will be cropped out.
    ///
    /// The four rectangles are arranged to avoid overlapping:
    /// ┌──────────────────────────────────┐
    /// │          TOP (full width)         │
    /// ├──────┬────────────┬──────────────┤
    /// │ LEFT │   (crop)   │    RIGHT     │  ← same height as crop
    /// ├──────┴────────────┴──────────────┤
    /// │         BOTTOM (full width)       │
    /// └──────────────────────────────────┘
    ///
    /// Top and Bottom span the full container width.
    /// Left and Right span only the crop window's height (between Top and Bottom).
    /// This prevents double-darkening at the corners.
    ///
    /// - Parameters:
    ///   - containerSize: The full container dimensions.
    ///   - cropOrigin: The top-left corner of the crop window.
    ///   - cropSize: The width and height of the crop window.
    @ViewBuilder
    private func dimOverlay(containerSize: CGSize, cropOrigin: CGPoint, cropSize: CGSize) -> some View {
        // The dim color: black at 45% opacity. Enough to clearly distinguish the
        // crop region from the discarded area without completely hiding the video.
        let dimColor = Color.black.opacity(0.45)

        // TOP rectangle — spans full container width, from top to crop origin
        dimColor
            .frame(width: containerSize.width, height: max(0, cropOrigin.y))
            .position(x: containerSize.width / 2, y: cropOrigin.y / 2)   // Centered in top strip

        // BOTTOM rectangle — spans full container width, from crop bottom edge to container bottom
        let bottomY = cropOrigin.y + cropSize.height     // Y coordinate of the crop's bottom edge
        let bottomH = containerSize.height - bottomY      // Remaining height below the crop
        dimColor
            .frame(width: containerSize.width, height: max(0, bottomH))
            .position(x: containerSize.width / 2, y: bottomY + bottomH / 2)   // Centered in bottom strip

        // LEFT rectangle — spans crop height only, from left edge to crop origin
        dimColor
            .frame(width: max(0, cropOrigin.x), height: cropSize.height)
            .position(x: cropOrigin.x / 2, y: cropOrigin.y + cropSize.height / 2)

        // RIGHT rectangle — spans crop height only, from crop right edge to container right
        let rightX = cropOrigin.x + cropSize.width       // X coordinate of the crop's right edge
        let rightW = containerSize.width - rightX          // Remaining width to the right
        dimColor
            .frame(width: max(0, rightW), height: cropSize.height)
            .position(x: rightX + rightW / 2, y: cropOrigin.y + cropSize.height / 2)
    }

    // =========================================================================
    // MARK: - Drag Indicator
    // =========================================================================

    /// Shows a directional arrow icon in the center of the crop window,
    /// indicating which direction the user can drag.
    ///
    /// - Horizontal crop → left-right arrow ("arrow.left.and.right")
    /// - Vertical crop → up-down arrow ("arrow.up.and.down")
    ///
    /// The icon uses semibold weight and 70% opacity white for visibility
    /// against video content without being too distracting.
    ///
    /// - Parameters:
    ///   - cropOrigin: The top-left corner of the crop window.
    ///   - cropSize: The dimensions of the crop window.
    @ViewBuilder
    private func dragIndicator(cropOrigin: CGPoint, cropSize: CGSize) -> some View {
        // Compute the center point of the crop window for positioning the icon
        let centerX = cropOrigin.x + cropSize.width / 2
        let centerY = cropOrigin.y + cropSize.height / 2

        if isHorizontalCrop {
            // Horizontal drag — show left-right arrow
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))   // Semi-transparent white for subtle visibility
                .position(x: centerX, y: centerY)        // Centered in the crop window
        } else {
            // Vertical drag — show up-down arrow
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .position(x: centerX, y: centerY)
        }
    }
}

// MARK: - Preview

#Preview("CropOverlay 16:9→1:1 - Light") {
    CropOverlayView(
        sourceAspectRatio: 16.0 / 9.0,
        targetAspectRatio: 1.0,
        cropOffset: .constant(CGPoint(x: 0.5, y: 0.5))
    )
    .frame(width: 320, height: 180)
    .background(Color.gray.opacity(0.3))
    .padding()
}

#Preview("CropOverlay 16:9→1:1 - Dark") {
    CropOverlayView(
        sourceAspectRatio: 16.0 / 9.0,
        targetAspectRatio: 1.0,
        cropOffset: .constant(CGPoint(x: 0.5, y: 0.5))
    )
    .frame(width: 320, height: 180)
    .background(Color.gray.opacity(0.3))
    .padding()
    .preferredColorScheme(.dark)
}
