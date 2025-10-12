import SwiftUI

// DesignSystem.swift - central styling guide

/// Colors
extension Color {

    // MARK: - Brand Colors

    /// IBM Blue 60 - (#0f62fe)
    public static let accent = Color(
        red: 15 / 255,
        green: 98 / 255,
        blue: 254 / 255
    )  // note: use for tab highlights, buttons, and primary interactive elements

    public static let primary = Color.accent // Primary color
    public static let secondary = Color.purple // Secondary brand color

    // MARK: - Semantic Colors
    static let success = Color.green  // Success state color - green
    static let warning = Color.orange  // Warning state color - orange
    static let error = Color.red  // Error state color - red
    static let info = Color.blue  // Information state color - blue

    // MARK: - Background Colors
    static let backgroundPrimary = Color(.systemBackground)  // Primary background - adapts to light/dark mode
    static let backgroundSecondary = Color(.secondarySystemBackground)  // Secondary background for cards and content areas
    static let backgroundTertiary = Color(.tertiarySystemBackground)  // Tertiary background for nested content
    static let videoBackground = Color.black  // Video player background - always black

    // MARK: - Text Colors
    static let textPrimary = Color(.label)  // Primary text color - adapts to light/dark mode
    static let textSecondary = Color(.secondaryLabel)  // Secondary text color - adapts to light/dark mode
    static let textTertiary = Color(.tertiaryLabel)  // Tertiary text color
    static let textOnDark = Color.white  // White text for dark backgrounds

    /// STATE COLORS - LEARNING SYSTEM
    static let stateNew = Color(
        red: 255 / 255,
        green: 126 / 255,
        blue: 182 / 255
    )  // NEW state - magenta (#ff7eb6)
    static let stateLearning = Color(
        red: 73 / 255,
        green: 29 / 255,
        blue: 139 / 255
    )  // LEARNING state - purple (#491d8b)
    static let stateMastery = Color(
        red: 36 / 255,
        green: 161 / 255,
        blue: 72 / 255
    )  // MASTERY state - green (#24a148)

    // BUTTONS IN REVIEW PAGE
    static let buttonAgain = Color(
        red: 218 / 255,
        green: 30 / 255,
        blue: 40 / 255
    )  // AGAIN button - red (#da1e28)
    static let buttonHard = Color(
        red: 241 / 255,
        green: 194 / 255,
        blue: 27 / 255
    )  // HARD button - yellow (#f1c21b)
    static let buttonGood = Color(
        red: 66 / 255,
        green: 190 / 255,
        blue: 101 / 255
    )  // GOOD button - green (#42be65)

    // MARK: - Neutral Colors
    static let neutralWhite = Color.white  // White

    static let neutralBlack = Color.black  // Black with opacity levels
    static let neutralBlack10 = Color.black.opacity(0.1)
    static let neutralBlack20 = Color.black.opacity(0.2)
    static let neutralBlack50 = Color.black.opacity(0.5)
    static let neutralBlack80 = Color.black.opacity(0.8)

    static let neutralGray50 = Color(.systemGray6)  // System grays
    static let neutralGray100 = Color(.systemGray5)
    static let neutralGray200 = Color(.systemGray4)
    static let neutralGray300 = Color(.systemGray3)

    // MARK: - Video Colors
    static let videoControlsBackground = Color.black.opacity(0.8)  // Video controls background
    static let videoControlsForeground = Color.white  // Video controls foreground
    static let videoAccent = Color.red  // Video accent color

    // MARK: - Border Colors
    static let borderPrimary = Color.accent  // Primary border
    static let borderSecondary = Color(.systemGray4)  // Secondary border
    static let borderDisabled = Color(.systemGray3)  // Disabled border

    // MARK: - Loading Overlay Colors
    static let loadingBackground = Color(
        red: 15 / 255,
        green: 98 / 255,
        blue: 254 / 255
    )  // High contrast loading background
    static let loadingForeground = Color.white  // Loading text and icons
}

/// FONTS
extension Font {
    // IBM Plex Mono Font Family
    static func ibmPlexMono(size: CGFloat, weight: Font.Weight = .regular)
        -> Font
    {
        switch weight {
        case .bold:
            return Font.custom("IBMPlexMono-Bold", size: size) // must be in Info.plist
        case .medium:
            return Font.custom("IBMPlexMono-Medium", size: size)
        case .semibold:
            return Font.custom("IBMPlexMono-SemiBold", size: size)
        default:
            return Font.custom("IBMPlexMono-Regular", size: size)
        }
    }

    static func appFont(_ weight: Font.Weight, size: CGFloat) -> Font {  // App font method for consistent typography
        return ibmPlexMono(size: size, weight: weight)
    }

    // Typography Scale
    static let titleLarge = ibmPlexMono(size: 32, weight: .bold)
    static let titleMedium = ibmPlexMono(size: 24, weight: .semibold)
    static let titleSmall = ibmPlexMono(size: 20, weight: .medium)
    static let bodyLarge = ibmPlexMono(size: 18)
    static let bodyMedium = ibmPlexMono(size: 16)
    static let bodySmall = ibmPlexMono(size: 14)
    static let caption = ibmPlexMono(size: 12)

    // Fallback system fonts for when custom fonts aren't available
    static let systemTitle = Font.system(
        size: 20,
        weight: .semibold,
        design: .monospaced
    )
    static let systemBody = Font.system(size: 16, design: .monospaced)
    static let systemCaption = Font.system(size: 12, design: .monospaced)
}

// MARK: - Transform Assertions
// extension View {
//     /// Runtime assertion to ensure video surfaces don't have transforms
//     /// This prevents black frames caused by SwiftUI transforms on video players
//     func assertNoTransforms() -> some View {
//         #if DEBUG
//         return self.background(
//             GeometryReader { geometry in
//                 Color.clear
//                     .onAppear {
//                         // Check if this view has any transforms applied
//                         let frame = geometry.frame(in: .global)
//                         let localFrame = geometry.frame(in: .local)

//                         // If frames don't match, transforms are likely applied
//                         if abs(frame.width - localFrame.width) > 0.1 ||
//                            abs(frame.height - localFrame.height) > 0.1 {
//                             assertionFailure("""
//                             🚨 Video surface transform detected!
//                             Video players must not have SwiftUI transforms (.rotationEffect, .transformEffect, etc.)
//                             Use VideoTransformBuilder for rotation instead.
//                             Frame: \(frame), Local: \(localFrame)
//                             """)
//                         }
//                     }
//             }
//         )
//         #else
//         return self
//         #endif
//     }
// }