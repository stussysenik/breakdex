// LayoutMetrics.swift — Responsive Layout Calculator for Breakdex
//
// This file provides device-aware layout calculations for the video editor.
// Instead of hardcoding sizes that look good on one device, LayoutMetrics
// classifies the device into a DeviceClass (SE, standard, proMax, iPad, etc.)
// and returns appropriate dimensions for each class.
//
// DESIGN PHILOSOPHY:
//   The layout system is built around the Golden Ratio (phi = 1.618).
//   - Video player height = screen width / phi (in portrait)
//   - Thumbnail width = timeline height * phi
//   These proportions create visual harmony without complex constraint logic.
//
// ARCHITECTURE ROLE:
//   GeometryReader (SwiftUI)
//     --> LayoutMetrics(geometry:)
//     --> videoPlayerHeight, timelineHeight, thumbnailWidth, etc.
//     --> Consumed by VideoEditorView, TrimmerTimelineView, TrimmerPlayheadView
//
// This is a VALUE TYPE (struct), not a class. A new LayoutMetrics is created
// each time the GeometryReader's size changes (e.g., device rotation). It's
// lightweight — just two stored CGFloats plus computed properties.
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Creates LayoutMetrics from GeometryReader, passes to child views
//   - TrimmerTimelineView.swift: Uses timelineHeight, thumbnailWidth, timelineWidth
//   - TrimmerPlayheadView.swift: Uses timelineHeight for playhead sizing
//   - AdaptiveThumbnailGenerator.swift: Uses thumbnailCount(for:) to determine thumbnail count

import SwiftUI

struct LayoutMetrics {

    // MARK: - Stored Properties

    /// The current width of the available screen/container area in points.
    /// Set from GeometryProxy.size.width. Used to classify the device and
    /// compute all width-dependent layout values.
    let screenWidth: CGFloat

    /// The current height of the available screen/container area in points.
    /// Set from GeometryProxy.size.height. Used for landscape detection
    /// and video player height calculations.
    let screenHeight: CGFloat

    // MARK: - Constants

    /// The Golden Ratio (phi), approximately 1.618.
    /// Used to derive aesthetically proportioned relationships:
    ///   - Video player height: screenWidth / phi (creates a ~61.8% width-to-height ratio)
    ///   - Thumbnail width: timelineHeight * phi (thumbnails are ~1.618x wider than tall)
    /// The golden ratio appears naturally in art and architecture as a pleasing proportion.
    private static let phi: CGFloat = 1.618

    // MARK: - Device Classification

    /// Classifies the device based on screen width into one of six categories.
    /// Width breakpoints are based on Apple's current device lineup:
    ///
    /// DEVICE          | LOGICAL WIDTH | CLASS
    /// iPhone SE       | 375pt         | .se
    /// iPhone 16       | 393pt         | .standard
    /// iPhone 16 Pro   | 402pt         | .standard
    /// iPhone 16 Plus  | 430pt         | .proMax
    /// iPhone 16 Pro Max| 440pt        | .proMax
    /// iPad mini       | 744pt         | .iPadMini
    /// iPad Air/Pro 11"| 820pt         | .iPad
    /// iPad Pro 13"    | 1024pt        | .iPadPro
    ///
    /// The breakpoints use `<` comparisons so each range is exclusive:
    ///   .se:        width < 383 (catches SE at 375)
    ///   .standard:  383 <= width < 410 (catches 393, 402)
    ///   .proMax:    410 <= width < 600 (catches 430, 440)
    ///   .iPadMini:  600 <= width < 780 (catches 744)
    ///   .iPad:      780 <= width < 920 (catches 820)
    ///   .iPadPro:   width >= 920 (catches 1024+)

    private enum DeviceClass {
        case se          // iPhone SE (375pt) — smallest supported screen
        case standard    // iPhone 16 / 16 Pro (390-402pt) — most common
        case proMax      // iPhone 16 Plus / Pro Max (430-440pt) — large phones
        case iPadMini    // iPad mini (744pt) — compact tablet
        case iPad        // iPad Air / iPad Pro 11" (820pt) — standard tablet
        case iPadPro     // iPad Pro 13" (1024pt+) — largest tablet

        /// Initializes the device class from the screen width.
        /// Uses a switch with half-open ranges for clean classification.
        init(width: CGFloat) {
            switch width {
            case ..<383:     self = .se
            case ..<410:     self = .standard
            case ..<600:     self = .proMax
            case ..<780:     self = .iPadMini
            case ..<920:     self = .iPad
            default:         self = .iPadPro
            }
        }

        /// Whether this device class is a tablet (iPad).
        /// Used to enable tablet-specific layouts (e.g., side-by-side panels).
        var isTablet: Bool {
            switch self {
            case .iPadMini, .iPad, .iPadPro: return true
            default: return false
            }
        }
    }

    /// Computed device class from the current screen width.
    /// Recalculated every time it's accessed (cheap — just a switch).
    private var device: DeviceClass { DeviceClass(width: screenWidth) }

    // MARK: - Computed Layout Values

    /// Whether the device is currently in landscape orientation.
    /// Determined by comparing width > height (simple and reliable).
    /// Used to switch between portrait (stacked) and landscape (side-by-side) layouts.
    var isLandscape: Bool { screenWidth > screenHeight }

    /// Whether the device is a tablet (any iPad).
    /// Exposes DeviceClass.isTablet publicly so views can check without
    /// knowing about the private DeviceClass enum.
    var isTablet: Bool { device.isTablet }

    /// Height of the video player/preview area in points.
    ///
    /// In portrait: Uses the golden ratio — screenWidth / phi (~61.8% of width).
    ///   This creates a video player that occupies roughly the top third of the screen,
    ///   leaving room for the timeline and controls below.
    ///   Example: 393pt width -> 393 / 1.618 = 242.9pt height
    ///
    /// In landscape: Uses 65% of screen height.
    ///   In landscape the video takes most of its half of the split layout,
    ///   with minimal controls visible.
    var videoPlayerHeight: CGFloat {
        if isLandscape {
            return screenHeight * 0.65
        }
        return screenWidth / Self.phi
    }

    /// Height of the thumbnail timeline strip in points.
    ///
    /// Scales up with device size so thumbnails remain visually balanced:
    ///   SE:       60pt (compact to save vertical space)
    ///   Standard: 68pt (default)
    ///   ProMax:   68pt (same as standard — the extra width gets more thumbnails, not taller ones)
    ///   iPadMini: 72pt (slightly larger for finger targets)
    ///   iPad:     80pt (comfortable touch targets on larger screens)
    ///   iPadPro:  80pt (same as iPad)
    var timelineHeight: CGFloat {
        switch device {
        case .se:                       return 60
        case .standard, .proMax:        return 68
        case .iPadMini:                 return 72
        case .iPad, .iPadPro:           return 80
        }
    }

    /// Width of individual thumbnail images in the timeline strip.
    ///
    /// Derived from the golden ratio: timelineHeight * phi.
    /// This makes each thumbnail slightly wider than it is tall (~1.618:1),
    /// which matches the typical aspect ratio of landscape video frames.
    ///
    /// Examples:
    ///   SE:       60 * 1.618 = 97.1pt
    ///   Standard: 68 * 1.618 = 110.0pt
    ///   iPad:     80 * 1.618 = 129.4pt
    var thumbnailWidth: CGFloat {
        timelineHeight * Self.phi
    }

    /// Horizontal padding on each side of the timeline strip.
    ///
    /// Increases with device size to maintain visual margins:
    ///   SE:       16pt (tight margins to maximize timeline width)
    ///   Standard: 20pt (Apple's standard horizontal margin)
    ///   ProMax:   20pt (same as standard)
    ///   iPadMini: 28pt (slightly more breathing room)
    ///   iPad:     34pt (generous margins)
    ///   iPadPro:  40pt (most generous — lots of screen to fill)
    var horizontalPadding: CGFloat {
        switch device {
        case .se:                       return 16
        case .standard, .proMax:        return 20
        case .iPadMini:                 return 28
        case .iPad:                     return 34
        case .iPadPro:                  return 40
        }
    }

    /// Available width for the timeline strip after subtracting padding from both sides.
    ///
    /// Example on iPhone 16 (393pt wide, 20pt padding):
    ///   393 - (20 * 2) = 353pt available for thumbnails
    var timelineWidth: CGFloat {
        screenWidth - (horizontalPadding * 2)
    }

    /// Calculates the optimal number of thumbnails to display for a given video duration.
    ///
    /// Balances two constraints:
    /// 1. maxByWidth: How many thumbnails fit physically (based on screen width and thumbnail width)
    /// 2. maxByDuration: How many thumbnails make sense temporally (one every N seconds)
    ///
    /// The result is the MINIMUM of these two — we never show more thumbnails than
    /// fit on screen, and we never show so many that they're less than 3 seconds apart.
    ///
    /// DURATION TIERS:
    ///   Short (< 2 min):   8-40 thumbnails, one every ~3 seconds
    ///   Medium (2-10 min):  20-60 thumbnails, one every ~10 seconds
    ///   Long (10+ min):    30-80 thumbnails, one every ~20 seconds
    ///
    /// - Parameter duration: Video duration in seconds
    /// - Returns: The number of thumbnails to generate and display
    ///
    /// Called from: VideoEditorView to configure AdaptiveThumbnailGenerator
    func thumbnailCount(for duration: TimeInterval) -> Int {
        guard duration > 0 else { return 0 }

        // Physical constraint: how many thumbnail slots fit in the available width.
        // Uses 0.3x overlap factor — thumbnails can overlap by 70% (they're tightly packed).
        let maxByWidth = Int(timelineWidth / (thumbnailWidth * 0.3))

        // Temporal constraint: how many thumbnails make sense for the video length.
        let maxByDuration: Int
        if duration <= 120 {
            // Short videos (< 2 min): 1 thumbnail every 3 seconds, clamped to 8...40
            maxByDuration = min(40, max(8, Int(duration / 3)))
        } else if duration <= 600 {
            // Medium videos (2-10 min): 1 thumbnail every 10 seconds, clamped to 20...60
            maxByDuration = min(60, max(20, Int(duration / 10)))
        } else {
            // Long videos (10+ min): 1 thumbnail every 20 seconds, clamped to 30...80
            maxByDuration = min(80, max(30, Int(duration / 20)))
        }

        // Take the smaller of the two constraints.
        return min(maxByWidth, maxByDuration)
    }

    // MARK: - Landscape Split Proportions

    /// In landscape mode, the video player takes 60% of the width.
    /// The remaining 40% is used for the timeline and controls.
    /// These are used by VideoEditorView's landscapeLayout().
    var landscapeVideoFraction: CGFloat { 0.6 }
    var landscapeControlsFraction: CGFloat { 0.4 }

    // MARK: - Initializers

    /// Creates LayoutMetrics from a SwiftUI GeometryProxy.
    /// This is the primary initializer — used inside GeometryReader blocks.
    ///
    /// Usage in VideoEditorView:
    ///   GeometryReader { geometry in
    ///       let metrics = LayoutMetrics(geometry: geometry)
    ///       // ... use metrics.videoPlayerHeight, etc.
    ///   }
    init(geometry: GeometryProxy) {
        self.screenWidth = geometry.size.width
        self.screenHeight = geometry.size.height
    }

    /// Creates LayoutMetrics from explicit width/height values.
    /// Used for:
    /// - Fallback values when GeometryReader isn't available yet
    /// - Unit testing with known dimensions
    /// - Landscape sub-layouts where the "screen" is a fraction of actual screen
    ///
    /// Example fallback in VideoEditorView:
    ///   let metrics = currentMetrics ?? LayoutMetrics(width: 390, height: 844)
    init(width: CGFloat, height: CGFloat) {
        self.screenWidth = width
        self.screenHeight = height
    }
}
