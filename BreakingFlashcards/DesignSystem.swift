// DesignSystem.swift — Centralized design tokens for the Breakdex app
//
// This is the single source of truth for all visual constants:
// colors, typography, spacing, corner radii, shadows, and animations.
//
// The design system follows these conventions:
// - Colors: dynamic (light/dark aware) using UIColor trait collection
// - Typography: IBM Plex Mono throughout (custom monospace font)
// - Spacing: 4pt grid system (xxs=2, xs=4, sm=8, md=16, lg=24, xl=32...)
// - Shadows: semantic levels (low, medium, strong, glow)
// - Animations: bridged from AppMotion (Motion.swift) for backwards compat
//
// Views reference these tokens instead of hardcoding values, so changing a
// color or spacing here updates the entire app consistently.

import SwiftUI

// MARK: - Dynamic Color Helper
// Creates a Color that automatically switches between light/dark variants
// based on the current UIUserInterfaceStyle (dark mode toggle).

private extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

// MARK: - Color Tokens
// Every color the app uses. Named semantically (backgroundPrimary, textPrimary)
// rather than literally (lightGray, almostBlack) so the intent is clear.

extension Color {
    // PRIMARY COLORS

    /// Main background — near-white in light mode, near-black in dark mode
    static var backgroundPrimary: Color {
        Color.dynamic(
            light: UIColor(red: 248/255, green: 249/255, blue: 251/255, alpha: 1),  // #f8f9fb
            dark: UIColor(red: 11/255, green: 12/255, blue: 14/255, alpha: 1)       // #0b0c0e
        )
    }

    /// Primary text — dark in light mode, light in dark mode
    static var textPrimary: Color {
        Color.dynamic(
            light: UIColor(red: 16/255, green: 17/255, blue: 20/255, alpha: 1),     // #101114
            dark: UIColor(red: 245/255, green: 246/255, blue: 248/255, alpha: 1)     // #f5f6f8
        )
    }

    /// Brand accent color — Gov.cz blue (#2362a2)
    /// Used for buttons, links, active states, and highlights
    static let accent = Color(red: 35/255, green: 98/255, blue: 162/255)

    /// Neutral surface fill — for cards, inputs, and secondary backgrounds
    static var neutralFill: Color {
        Color.dynamic(
            light: UIColor(red: 237/255, green: 240/255, blue: 245/255, alpha: 1),  // #edf0f5
            dark: UIColor(red: 24/255, green: 27/255, blue: 33/255, alpha: 1)       // #181b21
        )
    }

    // SECONDARY COLORS

    /// Secondary/muted text — for timestamps, captions, helper text
    static var textSecondary: Color {
        Color.dynamic(
            light: UIColor(red: 92/255, green: 98/255, blue: 106/255, alpha: 1),    // #5c626a
            dark: UIColor(red: 162/255, green: 170/255, blue: 180/255, alpha: 1)     // #a2aab4
        )
    }

    /// Card/surface background — white in light, dark slate in dark
    static var cardBackground: Color {
        Color.dynamic(
            light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1),   // #ffffff
            dark: UIColor(red: 20/255, green: 24/255, blue: 30/255, alpha: 1)        // #14181e
        )
    }

    /// Elevated surface — slightly lifted from background (cards, modals)
    static var surfaceElevated: Color {
        Color.dynamic(
            light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1),   // #ffffff
            dark: UIColor(red: 28/255, green: 31/255, blue: 38/255, alpha: 1)        // #1c1f26
        )
    }

    /// Subtle divider/separator line color (adaptive)
    static var separator: Color {
        Color.dynamic(
            light: UIColor(red: 220/255, green: 224/255, blue: 230/255, alpha: 1),   // #dce0e6
            dark: UIColor(red: 38/255, green: 42/255, blue: 50/255, alpha: 1)        // #262a32
        )
    }

    // STATE COLORS — one for each LearningState
    // These read from UserDefaults (set by AppSettings in SettingsView) so users
    // can customize them. Falls back to design defaults if no custom color is set.

    /// Pink for NEW moves — configurable in Settings (default: #ff7eb6)
    static var stateNew: Color {
        if let hex = UserDefaults.standard.string(forKey: "stateNewHex"),
           let color = Color(hex: hex) { return color }
        return Color(red: 255/255, green: 126/255, blue: 182/255)
    }

    /// IBM Cyan Blue for LEARNING moves — configurable in Settings (default: #33b1ff)
    static var stateLearning: Color {
        if let hex = UserDefaults.standard.string(forKey: "stateLearningHex"),
           let color = Color(hex: hex) { return color }
        return Color(red: 51/255, green: 177/255, blue: 255/255)
    }

    /// Purple for MASTERY moves — configurable in Settings (default: #8a3ffc)
    static var stateMastery: Color {
        if let hex = UserDefaults.standard.string(forKey: "stateMasteryHex"),
           let color = Color(hex: hex) { return color }
        return Color(red: 138/255, green: 63/255, blue: 252/255)
    }

    // ACTION BUTTON COLORS — for the spaced repetition review buttons

    /// Red for "AGAIN" — needs more practice, demotes learning state
    static let buttonAgain = Color(red: 218/255, green: 30/255, blue: 40/255)       // #da1e28

    /// Yellow for "HARD" — struggled but getting there
    static let buttonHard = Color(red: 241/255, green: 194/255, blue: 27/255)       // #f1c21b

    /// Green for "GOOD" — nailed it, promotes learning state
    static let buttonGood = Color(red: 66/255, green: 190/255, blue: 101/255)       // #42be65
}

// MARK: - Custom Font System
// The app uses IBM Plex Mono exclusively — a monospace font that gives
// the UI a technical/hacker aesthetic fitting for a b-boy training tool.
// Font weights are mapped to the specific font file names in the bundle.

extension Font {
    /// Core font factory — maps SwiftUI Font.Weight to IBMPlexMono font files.
    /// `relativeTo:` enables Dynamic Type scaling so text grows with the user's
    /// Accessibility > Larger Text setting. All existing callers get DT for free
    /// via the default `relativeTo: .body`.
    static func ibmPlexMono(size: CGFloat, weight: Font.Weight = .regular,
                             relativeTo style: Font.TextStyle = .body) -> Font {
        switch weight {
        case .bold:
            return .custom("IBMPlexMono-Bold", size: size, relativeTo: style)
        case .medium:
            return .custom("IBMPlexMono-Medium", size: size, relativeTo: style)
        case .semibold:
            return .custom("IBMPlexMono-SemiBold", size: size, relativeTo: style)
        default:
            return .custom("IBMPlexMono-Regular", size: size, relativeTo: style)
        }
    }

    // Typography Scale — semantic font presets with Dynamic Type bindings
    static let titleLarge  = ibmPlexMono(size: 32, weight: .bold, relativeTo: .largeTitle)
    static let titleMedium = ibmPlexMono(size: 24, weight: .semibold, relativeTo: .title)
    static let titleSmall  = ibmPlexMono(size: 20, weight: .medium, relativeTo: .title3)

    static let bodyLarge  = ibmPlexMono(size: 18, relativeTo: .body)
    static let bodyMedium = ibmPlexMono(size: 16, relativeTo: .body)
    static let bodySmall  = ibmPlexMono(size: 14, relativeTo: .subheadline)

    static let caption = ibmPlexMono(size: 12, relativeTo: .caption)

}

// MARK: - Spacing Tokens (4pt grid)
// All spacing values are multiples of 4 for visual consistency.
// Use these instead of hardcoded numbers: Spacing.md instead of 16.

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let huge: CGFloat = 80
    static let massive: CGFloat = 96

    /// Consistent horizontal screen margin (matches Apple HIG safe inset)
    static let screenEdge: CGFloat = 20
}

// MARK: - Radius Tokens
// Corner radius presets for consistent roundedness across the app.

enum Radius {
    static let sm: CGFloat = 10   // Soft rounding (pills, small buttons)
    static let md: CGFloat = 16   // Standard cards, inputs
    static let lg: CGFloat = 22   // Large cards, video players — organic feel
    static let xl: CGFloat = 30   // Extra round (modals, hero elements)
}

// MARK: - Shadow Tokens
// Single unified shadow system. AppShadow provides semantic levels from
// subtle card lift to accent-colored glow effects.

enum AppShadow {
    struct Value { let color: Color; let radius: CGFloat; let x: CGFloat; let y: CGFloat }

    static let subtle = Value(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let medium = Value(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    static let strong = Value(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    static let glow   = Value(color: .accent.opacity(0.3), radius: 12, x: 0, y: 0) // Accent-colored glow
}

// View modifier for AppShadow: .appShadow(AppShadow.subtle)
extension View {
    func appShadow(_ s: AppShadow.Value) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - AppAnimation (bridges to AppMotion)
// Legacy animation names that map to the canonical presets in Motion.swift.
// Some views still reference these — they're aliases, not duplicates.

enum AppAnimation {
    static let springSmooth = AppMotion.springSoft          // Cards, modals
    static let springBouncy = AppMotion.springQuick          // Progress, counters
    static let buttonPress = AppMotion.easeStandard          // Taps, toggles
    static let springInteractive = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    static let springGentle = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
}

// MARK: - FadeIn Modifier
// Animates a view's opacity from 0 to 1 with a spring curve on appear.
// Supports staggered delays for list-like entrance animations.
// Usage: .fadeIn() or .fadeIn(delay: 0.2)

struct FadeInModifier: ViewModifier {
    @State private var opacity: Double = 0  // Starts invisible
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                // Spring animation fades in when the view first appears
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(delay)) {
                    opacity = 1
                }
            }
    }
}

extension View {
    func fadeIn(delay: Double = 0) -> some View {
        modifier(FadeInModifier(delay: delay))
    }
}

// MARK: - Liquid Glass (iOS 26+)
// Apple's new translucent "glass" material effect introduced in iOS 26.
// .interactive() makes the glass respond to touch/hover states.
// Falls back to plain view on older iOS versions.
// Usage: .liquidGlass(in: RoundedRectangle(cornerRadius: Radius.lg)) or .liquidGlass(in: .circle)

extension View {
    @ViewBuilder
    func liquidGlass(in shape: some InsettableShape) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self  // No-op on iOS < 26
        }
    }
}

// MARK: - Glass Card Modifier
// Clips a view to a rounded rectangle and applies Liquid Glass in one call.
// Eliminates the repeated .clipShape + .liquidGlass pattern across the codebase.

extension View {
    func glassCard(radius: CGFloat = Radius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        return self.clipShape(shape).liquidGlass(in: shape)
    }
}

// MARK: - Press Animation
// Shared press feedback used by all action button styles.
// Single tuning point: change the scale/brightness/spring here, all buttons update.

extension View {
    func pressAnimation(_ isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .brightness(isPressed ? -0.1 : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0), value: isPressed)
    }
}

// MARK: - PrimaryActionButtonStyle
// Accent-colored, full-width, 50pt height, Liquid Glass rounded rectangle.

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ibmPlexMono(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accent)
            .glassCard()
            .pressAnimation(configuration.isPressed)
    }
}

extension View {
    func primaryAction() -> some View {
        self.buttonStyle(PrimaryActionButtonStyle())
    }
}

// MARK: - SecondaryActionButtonStyle
// Ghost variant — accent text on neutralFill background.

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ibmPlexMono(size: 16, weight: .bold))
            .foregroundColor(.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.neutralFill)
            .glassCard()
            .pressAnimation(configuration.isPressed)
    }
}

extension View {
    func secondaryAction() -> some View {
        self.buttonStyle(SecondaryActionButtonStyle())
    }
}

// MARK: - Color Hex Conversion
// Bidirectional conversion between Color and hex strings (e.g. "#ff7eb6").
// Used by AppSettings to persist custom colors and by DesignSystem state colors.

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }

    func toHex() -> String {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Category Color Palette
// Shared preset colors for category creation (used by AddMoveView and SettingsView).

enum CategoryPalette {
    static let hexColors = [
        "#2362a2", "#8a3ffc", "#ff7eb6", "#33b1ff",
        "#24a148", "#da1e28", "#f1c21b", "#ff832b"
    ]
}
