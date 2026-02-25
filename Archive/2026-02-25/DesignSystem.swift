import SwiftUI

extension Color {
    // PRIMARY COLORS

    /// IBM Black 100 - Primary background (#000000)
    static let backgroundPrimary = Color.black

    /// IBM White - Primary text (#FFFFFF)
    static let textPrimary = Color.white

    /// IBM Blue 60 - Primary accent (#0f62fe)
    static let accent = Color(red: 15/255, green: 98/255, blue: 254/255)

    /// IBM Cool Gray 10 - Adapted for dark mode list backgrounds (#f2f4f8)
    static let neutralFill = Color(red: 242/255, green: 244/255, blue: 248/255)

    // SECONDARY COLORS

    /// IBM Cool Gray 80 - Secondary text (#606060)
    static let textSecondary = Color(red: 96/255, green: 96/255, blue: 96/255)

    /// IBM Cool Gray 20 - Card backgrounds (#e0e0e0)
    static let cardBackground = Color(red: 224/255, green: 224/255, blue: 224/255)

    // STATE COLORS (Updated)

    /// The new magenta color for the 'NEW' state. (#ff7eb6)
    static let stateNew = Color(red: 255/255, green: 126/255, blue: 182/255)

    /// The new purple color for the 'LEARNING' state. (#491d8b)
    static let stateLearning = Color(red: 73/255, green: 29/255, blue: 139/255)

    /// The new green color for the 'MASTERY' state. (#24a148)
    static let stateMastery = Color(red: 36/255, green: 161/255, blue: 72/255)

    // MARK: - Action Button Colors (Updated)

    /// The red color for the 'AGAIN' review button. (#da1e28)
    static let buttonAgain = Color(red: 218/255, green: 30/255, blue: 40/255)

    /// The new yellow color for the 'HARD' review button. (#f1c21b)
    static let buttonHard = Color(red: 241/255, green: 194/255, blue: 27/255)

    /// The green color for the 'GOOD' review button. (#42be65)
    static let buttonGood = Color(red: 66/255, green: 190/255, blue: 101/255)
}

// CUSTOM FONT SYSTEM
extension Font {
    // IBM Plex Mono Font Family
    // Note: Requires IBM Plex Mono font files to be added to the project
    // Add to Info.plist: "Fonts provided by application" array with "IBMPlexMono-Regular.ttf"

    static func ibmPlexMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return Font.custom("IBMPlexMono-Bold", size: size)
        case .medium:
            return Font.custom("IBMPlexMono-Medium", size: size)
        case .semibold:
            return Font.custom("IBMPlexMono-SemiBold", size: size)
        default:
            return Font.custom("IBMPlexMono-Regular", size: size)
        }
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
    static let systemTitle = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let systemBody = Font.system(size: 16, design: .monospaced)
    static let systemCaption = Font.system(size: 12, design: .monospaced)
}
