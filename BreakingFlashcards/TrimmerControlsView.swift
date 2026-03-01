// TrimmerControlsView.swift — Speed, rotation, and aspect ratio controls for the video editor
//
// This view provides the secondary editing controls that sit below the video timeline
// in VideoEditorView. It lets the user adjust three categories of video parameters:
//
// LAYOUT (top to bottom):
//   ┌─────────────────────────────────────────────────────┐
//   │  Speed Row:  [.25x] [.5x] [1x] [1.5x] [2x]       │  ← capsule pill buttons
//   │                                                     │
//   │  Transform Row:  [Reverse]  [Rotate]  [Aspect]     │  ← icon + label buttons
//   └─────────────────────────────────────────────────────┘
//
// SPEED ROW:
//   Five playback speed options as pill-shaped buttons.
//   The active speed is highlighted with a filled accent-colored capsule;
//   inactive speeds use a neutral fill. Tapping a speed updates
//   params.playbackRate and triggers haptic feedback via HapticEngine.
//
//   Available speeds: 0.25x, 0.5x, 1.0x (default), 1.5x, 2.0x
//
// TRANSFORM ROW:
//   Three transform buttons, each cycling through their options:
//
//   1. REVERSE — toggles params.isReversed (true/false).
//      When active, the video plays backwards during export.
//      Icon: "arrow.uturn.backward"
//
//   2. ROTATE — cycles through VideoRotation: none → 90° → 180° → 270° → none.
//      The raw value (Int) is displayed as the label (e.g. "90°").
//      The icon comes from VideoRotation.iconName ("rotate.right").
//      Icon changes based on current rotation state.
//
//   3. ASPECT RATIO — cycles through AspectRatio: original → 1:1 → 16:9 → 9:16 → original.
//      When changed, also resets cropOffset to center (0.5, 0.5) so the
//      CropOverlayView starts in a neutral position.
//      The label comes from AspectRatio.label (e.g. "1:1", "16:9").
//      The icon comes from AspectRatio.iconName (e.g. "square", "rectangle").
//
// DATA FLOW:
//   All controls modify a single VideoEditParameters struct via a @Binding.
//   VideoEditParameters (defined in VideoCompositionPipeline.swift) contains:
//   - startTime / endTime: CMTime (set by the timeline, not by these controls)
//   - playbackRate: Float (set by speed row)
//   - isReversed: Bool (set by reverse button)
//   - rotation: VideoRotation (set by rotate button)
//   - aspectRatio: AspectRatio (set by aspect ratio button)
//   - cropOffset: CGPoint (reset by aspect ratio button, adjusted by CropOverlayView)
//
//   The VideoEditorView reads these parameters to configure video playback preview
//   and passes them to VideoCompositionPipeline for export.
//
// HAPTIC FEEDBACK:
//   Every control triggers tactile feedback via HapticEngine (singleton):
//   - speedChange(): rigid impact — satisfying click for speed pill selection
//   - rotationSnap(): heavy impact — emphasizes the 90-degree rotation snap
//
// ANIMATION:
//   - Speed pills use AppMotion.pillSelect (0.15s ease-in-out) for instant feedback
//   - Transform buttons use standard SwiftUI animation for active state changes
//
// DESIGN SYSTEM USAGE:
//   - Spacing.md (16pt): vertical gap between speed row and transform row
//   - Spacing.sm (8pt): horizontal gap between speed pills, padding inside pills/buttons
//   - Spacing.xs (4pt): vertical padding within transform buttons, gap between icon and label
//   - Radius.sm (6pt): corner radius on transform button backgrounds
//   - Font.ibmPlexMono: all text (speed labels, transform labels)
//   - Color.accent: active speed pill fill, active transform button tint
//   - Color.neutralFill: inactive speed pill and transform button backgrounds
//   - Color.textPrimary: inactive speed pill text
//   - Color.textSecondary: inactive transform button icon/text

import SwiftUI   // SwiftUI framework — provides View, @Binding, @ViewBuilder, etc.

// MARK: - TrimmerControlsView

/// The speed and transform controls panel for the video editor.
/// Displayed below the trim timeline in VideoEditorView.
/// All edits are written to a shared VideoEditParameters binding.
struct TrimmerControlsView: View {

    // -------------------------------------------------------------------------
    // MARK: Properties
    // -------------------------------------------------------------------------

    /// Two-way binding to the VideoEditParameters struct owned by VideoEditorView.
    /// Changes made here (speed, rotation, aspect ratio, reverse, crop offset)
    /// are immediately reflected in the video preview and used during export.
    @Binding var params: VideoEditParameters

    /// The available playback speeds displayed as pill buttons.
    /// 1.0 is the default (normal speed). Values < 1 are slow-motion;
    /// values > 1 are fast-forward. These are applied during AVAssetExportSession
    /// by scaling the video's time range.
    private let speeds: [Float] = [0.25, 0.5, 1.0, 1.5, 2.0]

    // -------------------------------------------------------------------------
    // MARK: Body
    // -------------------------------------------------------------------------

    /// Vertical stack containing the speed row on top and the transform row below.
    /// Horizontal padding is applied to the entire container for consistent margins.
    var body: some View {
        VStack(spacing: Spacing.md) {   // 16pt vertical gap between the two rows
            // Row 1: Playback speed pills (.25x, .5x, 1x, 1.5x, 2x)
            speedRow

            // Row 2: Transform controls (Reverse, Rotate, Aspect Ratio)
            transformRow
        }
        .padding(.horizontal, Spacing.md)   // 16pt left/right margins
    }

    // =========================================================================
    // MARK: - Speed Row
    // =========================================================================

    /// A horizontal row of capsule-shaped speed buttons.
    ///
    /// Each button displays a speed label (e.g. ".5x", "1x", "2x") inside a capsule.
    /// The currently selected speed is highlighted with:
    ///   - Accent-colored background fill (Color.accent, #2362a2)
    ///   - White text color
    ///   - Bold font weight
    ///
    /// Inactive speeds use:
    ///   - Neutral fill background (Color.neutralFill, light gray / dark slate)
    ///   - Primary text color (Color.textPrimary)
    ///   - Regular font weight
    private var speedRow: some View {
        HStack(spacing: Spacing.sm) {   // 8pt horizontal gap between pills
            // Iterate over the speeds array. Each Float value acts as its own ID
            // since all values are unique (ForEach requires Hashable, and Float is Hashable).
            ForEach(speeds, id: \.self) { speed in
                Button {
                    // Update the playback rate in the shared parameters
                    params.playbackRate = speed
                    // Trigger haptic feedback — rigid impact for a satisfying click.
                    // HapticEngine.shared is a singleton that pre-warms UIImpactFeedbackGenerators.
                    HapticEngine.shared.speedChange()
                } label: {
                    Text(speedLabel(speed))
                        // Font weight changes based on selection: bold for active, regular for inactive.
                        // This provides visual weight to reinforce the accent background.
                        .font(.ibmPlexMono(size: 15, weight: speed == params.playbackRate ? .bold : .regular))
                        // Text color: white on accent background (active), primary text color (inactive)
                        .foregroundColor(speed == params.playbackRate ? .white : .textPrimary)
                        // Horizontal padding inside the capsule (8pt each side)
                        .padding(.horizontal, Spacing.sm)
                        // Vertical padding: xs (4pt) + 2pt = 6pt — slightly taller than minimum
                        .padding(.vertical, Spacing.xs + 2)
                        // Background capsule shape — filled with accent (active) or neutral (inactive)
                        .background(
                            Capsule()
                                .fill(speed == params.playbackRate ? Color.accent : Color.neutralFill)
                        )
                }
                // Animate the pill transition when playbackRate changes.
                // AppMotion.pillSelect is a fast 0.15s ease-in-out — instant but smooth.
                .animation(AppMotion.pillSelect, value: params.playbackRate)
            }
        }
    }

    // =========================================================================
    // MARK: - Transform Row
    // =========================================================================

    /// A horizontal row of three transform buttons: Reverse, Rotate, and Aspect Ratio.
    /// Each button cycles through its options and provides haptic feedback.
    private var transformRow: some View {
        HStack(spacing: Spacing.md) {   // 16pt horizontal gap between transform buttons

            // -----------------------------------------------------------------
            // Transform 1: Reverse
            // -----------------------------------------------------------------
            // Toggles video playback direction. When isReversed is true,
            // VideoCompositionPipeline reverses the video frames during export.
            // Icon: "arrow.uturn.backward" (U-turn arrow)
            transformButton(
                icon: "arrow.uturn.backward",
                label: "Reverse",
                isActive: params.isReversed   // Highlighted when reverse is enabled
            ) {
                params.isReversed.toggle()         // Toggle the boolean
                HapticEngine.shared.speedChange()  // Rigid impact feedback
            }

            // -----------------------------------------------------------------
            // Transform 2: Rotate
            // -----------------------------------------------------------------
            // Cycles through VideoRotation: .none → .clockwise90 → .clockwise180 → .clockwise270 → .none
            // The rotation raw value (Int: 0, 90, 180, 270) is displayed as the label.
            // "\u{00B0}" is the degree symbol (°).
            // VideoRotation.iconName returns "rotate.right" for all states.
            // VideoRotation.next computes the next value in the cycle using allCases.
            transformButton(
                icon: params.rotation.iconName,                      // "rotate.right"
                label: "\(params.rotation.rawValue)\u{00B0}",       // e.g. "90°", "180°", "0°"
                isActive: params.rotation != .none                   // Highlighted when rotated (not 0°)
            ) {
                params.rotation = params.rotation.next               // Cycle to next rotation
                HapticEngine.shared.rotationSnap()                   // Heavy impact — emphasizes the snap
            }

            // -----------------------------------------------------------------
            // Transform 3: Aspect Ratio
            // -----------------------------------------------------------------
            // Cycles through AspectRatio: .original → .square → .widescreen16x9 → .portrait9x16 → .original
            // When the aspect ratio changes, cropOffset is reset to center (0.5, 0.5)
            // so the CropOverlayView starts in a neutral position for the new ratio.
            // AspectRatio.iconName returns SF Symbols: "aspectratio", "square", "rectangle", "rectangle.portrait"
            // AspectRatio.label returns display strings: "Original", "1:1", "16:9", "9:16"
            transformButton(
                icon: params.aspectRatio.iconName,                   // e.g. "square", "rectangle"
                label: params.aspectRatio.label,                     // e.g. "1:1", "16:9"
                isActive: params.aspectRatio != .original            // Highlighted when not original
            ) {
                params.aspectRatio = params.aspectRatio.next         // Cycle to next ratio
                // Reset crop position to center when switching aspect ratios.
                // Without this, the crop window would jump to a potentially
                // off-screen position based on the previous ratio's offset.
                params.cropOffset = CGPoint(x: 0.5, y: 0.5)
                HapticEngine.shared.speedChange()                    // Rigid impact feedback
            }
        }
    }

    // =========================================================================
    // MARK: - Reusable Transform Button
    // =========================================================================

    /// A reusable button component for the transform row.
    /// Renders as a vertical stack of an SF Symbol icon and a text label,
    /// styled differently based on active/inactive state.
    ///
    /// ACTIVE STATE (isActive = true):
    ///   - Accent text color (#2362a2)
    ///   - Accent background at 12% opacity (subtle tinted fill)
    ///
    /// INACTIVE STATE (isActive = false):
    ///   - Secondary text color (muted gray)
    ///   - Neutral fill background (Color.neutralFill)
    ///
    /// The button has a minimum 44x44pt tap target (Apple HIG requirement)
    /// with additional padding for comfortable touch interaction.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name for the button's icon (e.g. "rotate.right").
    ///   - label: Display text below the icon (e.g. "90°", "1:1").
    ///   - isActive: Whether this transform is currently active/non-default.
    ///   - action: Closure to execute when the button is tapped.
    @ViewBuilder
    private func transformButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {   // 4pt gap between icon and label
                // SF Symbol icon — 23pt system font for visual prominence
                Image(systemName: icon)
                    .font(.system(size: 23))

                // Text label below the icon — IBM Plex Mono, 16pt
                Text(label)
                    .font(.ibmPlexMono(size: 16))
            }
            // Foreground color: accent when active (draws attention), muted when inactive
            .foregroundColor(isActive ? .accent : .textSecondary)
            // Minimum 44x44pt tap target as per Apple Human Interface Guidelines.
            // This ensures the button is easily tappable even if the icon/text is small.
            .frame(minWidth: 44, minHeight: 44)
            // Additional padding for comfortable spacing within the button
            .padding(.horizontal, Spacing.sm)   // 8pt horizontal padding
            .padding(.vertical, Spacing.xs)      // 4pt vertical padding
            // Background fill — rounded rectangle with subtle styling
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)   // 6pt corner radius from design system
                    .fill(isActive ? Color.accent.opacity(0.12) : Color.neutralFill)
                    // Active: 12% accent tint — subtle but noticeable highlight
                    // Inactive: neutral fill — blends into the background
            )
        }
    }

    // =========================================================================
    // MARK: - Speed Label Formatting
    // =========================================================================

    /// Formats a Float speed value into a compact display string.
    ///
    /// Special cases for clean display:
    ///   - 1.0 → "1x" (not "1.0x" — cleaner for the default speed)
    ///   - 0.25 → ".25x" (drops the leading zero for compactness)
    ///   - 0.5 → ".5x" (drops the leading zero for compactness)
    ///   - 1.5 → "1.5x" (standard decimal format)
    ///   - 2.0 → "2x" (removes trailing ".0" for clean display)
    ///
    /// - Parameter speed: The playback speed as a Float (e.g. 0.25, 1.0, 2.0).
    /// - Returns: A compact string representation (e.g. ".25x", "1x", "2x").
    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }     // Default speed — clean display
        if speed == 0.25 { return ".25x" }   // Quarter speed — drop leading zero
        if speed == 0.5 { return ".5x" }     // Half speed — drop leading zero
        // For all other speeds: format to 1 decimal place, then remove ".0" if present
        // Example: 1.5 → "1.5x", 2.0 → "2.0x" → "2x"
        return String(format: "%.1fx", speed).replacingOccurrences(of: ".0x", with: "x")
    }
}

private struct TrimmerControlsPreviewHost: View {
    @State private var params = VideoEditParameters()

    var body: some View {
        TrimmerControlsView(params: $params)
            .padding(.vertical, Spacing.md)
            .background(Color.backgroundPrimary)
    }
}

#Preview("Trimmer Controls") {
    TrimmerControlsPreviewHost()
}
