import SwiftUI

private extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

extension Color {
    // PRIMARY COLORS

    /// Primary background (dynamic)
    static var backgroundPrimary: Color {
        Color.dynamic(
            light: UIColor(red: 248/255, green: 249/255, blue: 251/255, alpha: 1),
            dark: UIColor(red: 11/255, green: 12/255, blue: 14/255, alpha: 1)
        )
    }

    /// Primary text (dynamic)
    static var textPrimary: Color {
        Color.dynamic(
            light: UIColor(red: 16/255, green: 17/255, blue: 20/255, alpha: 1),
            dark: UIColor(red: 245/255, green: 246/255, blue: 248/255, alpha: 1)
        )
    }

    /// IBM Blue 60 - Carbon primary blue (#0f62fe)
    static let carbonBlue60 = Color(red: 15/255, green: 98/255, blue: 254/255)

    /// Gov.cz Primary blue (approx) (#2362a2)
    static let govPrimaryBlue = Color(red: 35/255, green: 98/255, blue: 162/255)

    /// Gov.cz Dark text/neutral (#2b2b2b)
    static let govDarkNeutral = Color(red: 43/255, green: 43/255, blue: 43/255)

    /// Gov.cz Light background (#f5f5f5)
    static let govSurface = Color(red: 245/255, green: 245/255, blue: 245/255)

    /// Primary accent (Czech Gov + Carbon friendly)
    static let accent = govPrimaryBlue

    /// Neutral fill for surfaces (dynamic)
    static var neutralFill: Color {
        Color.dynamic(
            light: UIColor(red: 237/255, green: 240/255, blue: 245/255, alpha: 1),
            dark: UIColor(red: 24/255, green: 27/255, blue: 33/255, alpha: 1)
        )
    }

    // SECONDARY COLORS

    /// Secondary text (dynamic)
    static var textSecondary: Color {
        Color.dynamic(
            light: UIColor(red: 92/255, green: 98/255, blue: 106/255, alpha: 1),
            dark: UIColor(red: 162/255, green: 170/255, blue: 180/255, alpha: 1)
        )
    }

    /// Card backgrounds (dynamic)
    static var cardBackground: Color {
        Color.dynamic(
            light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1),
            dark: UIColor(red: 20/255, green: 24/255, blue: 30/255, alpha: 1)
        )
    }

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

// MARK: - Spacing Tokens

enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius Tokens

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Elevation Tokens

enum Elevation {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let low = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let medium = Shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    static let high = Shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
}

extension View {
    func elevation(_ shadow: Elevation.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
