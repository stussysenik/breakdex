import SwiftUI

// MARK: - Shared Colors
/// Centralized color system for consistent styling across features
public struct SharedColors {

    // MARK: - Brand Colors
    public struct Brand {
        public static let primary = Color.blue
        public static let secondary = Color.purple
        public static let accent = Color.orange

        // Video-specific brand colors
        public static let videoPrimary = Color.blue
        public static let videoAccent = Color.red
    }

    // MARK: - Semantic Colors
    public struct Semantic {
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue

        // Video-specific semantic colors
        public static let processing = Color.blue
        public static let complete = Color.green
        public static let failed = Color.red
    }

    // MARK: - Neutral Colors
    public struct Neutral {
        public static let white = Color.white
        public static let black = Color.black
        public static let gray50 = Color(UIColor.systemGray6)  // Very light gray
        public static let gray100 = Color(UIColor.systemGray5) // Light gray
        public static let gray200 = Color(UIColor.systemGray4) // Medium light gray
        public static let gray300 = Color(UIColor.systemGray3) // Medium gray
        public static let gray400 = Color(UIColor.systemGray2) // Medium dark gray
        public static let gray500 = Color(UIColor.systemGray)  // Dark gray
        public static let gray600 = Color(UIColor.darkGray)    // Very dark gray

        // Opacity variants
        public static let whiteOpacity10 = Color.white.opacity(0.1)
        public static let whiteOpacity20 = Color.white.opacity(0.2)
        public static let whiteOpacity50 = Color.white.opacity(0.5)
        public static let whiteOpacity80 = Color.white.opacity(0.8)

        public static let blackOpacity10 = Color.black.opacity(0.1)
        public static let blackOpacity20 = Color.black.opacity(0.2)
        public static let blackOpacity50 = Color.black.opacity(0.5)
        public static let blackOpacity80 = Color.black.opacity(0.8)
    }

    // MARK: - Background Colors
    public struct Background {
        public static let primary = Neutral.white
        public static let secondary = Neutral.gray50
        public static let tertiary = Neutral.gray100
        public static let overlay = Neutral.blackOpacity50

        // Video-specific backgrounds
        public static let videoPlayer = Neutral.black
        public static let videoOverlay = Neutral.blackOpacity20
        public static let videoControls = Neutral.blackOpacity80
    }

    // MARK: - Text Colors
    public struct Text {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
        public static let tertiary = Neutral.gray500
        public static let inverse = Neutral.white

        // Video-specific text colors
        public static let videoControls = Neutral.white
        public static let videoOverlay = Neutral.white
        public static let videoTime = Neutral.whiteOpacity80
    }

    // MARK: - Border Colors
    public struct Border {
        public static let primary = Brand.primary
        public static let secondary = Neutral.gray300
        public static let tertiary = Neutral.gray200
        public static let focus = Brand.primary
        public static let disabled = Neutral.gray300
    }

    // MARK: - Interactive States
    public struct State {
        public static let normal = Brand.primary
        public static let highlighted = Brand.primary.opacity(0.8)
        public static let disabled = Neutral.gray400
        public static let focused = Brand.primary
        public static let selected = Brand.primary
    }

    // MARK: - Video-Specific Colors
    public struct Video {
        // Player controls
        public static let controlsBackground = Neutral.blackOpacity80
        public static let controlsForeground = Neutral.white
        public static let controlsAccent = Brand.videoAccent

        // Progress indicators
        public static let progressBackground = Neutral.whiteOpacity20
        public static let progressForeground = Brand.videoPrimary
        public static let progressBuffered = Neutral.whiteOpacity50

        // Loading states
        public static let loadingForeground = Brand.videoPrimary
        public static let loadingBackground = Neutral.blackOpacity50

        // Error states
        public static let errorForeground = Semantic.error
        public static let errorBackground = Neutral.blackOpacity80

        // Success states
        public static let successForeground = Semantic.success
        public static let successBackground = Neutral.blackOpacity80
    }

    // MARK: - System Colors (iOS Adaptation)
    public struct System {
        public static let label = Color.primary
        public static let secondaryLabel = Color.secondary
        public static let tertiaryLabel = Color(UIColor.tertiaryLabel)
        public static let quaternaryLabel = Color(UIColor.quaternaryLabel)

        public static let systemBackground = Color(UIColor.systemBackground)
        public static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
        public static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)

        public static let systemFill = Color(UIColor.systemFill)
        public static let secondarySystemFill = Color(UIColor.secondarySystemFill)
        public static let tertiarySystemFill = Color(UIColor.tertiarySystemFill)

        public static let separator = Color(UIColor.separator)
        public static let opaqueSeparator = Color(UIColor.opaqueSeparator)
    }
}

// MARK: - Color Extensions
public extension Color {
    // Quick access to commonly used colors
    static let brandPrimary = SharedColors.Brand.primary
    static let brandSecondary = SharedColors.Brand.secondary
    static let brandAccent = SharedColors.Brand.accent

    static let success = SharedColors.Semantic.success
    static let warning = SharedColors.Semantic.warning
    static let error = SharedColors.Semantic.error
    static let info = SharedColors.Semantic.info

    static let backgroundPrimary = SharedColors.Background.primary
    static let backgroundSecondary = SharedColors.Background.secondary

    // Video-specific shortcuts
    static let videoBackground = SharedColors.Video.controlsBackground
    static let videoForeground = SharedColors.Video.controlsForeground
    static let videoAccent = SharedColors.Video.controlsAccent

    // Create custom colors with ease
    static func hex(_ hex: String) -> Color {
        return Color(UIColor(hex: hex) ?? .systemGray)
    }

    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        return Color(red: red/255, green: green/255, blue: blue/255)
    }

    static func rgba(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> Color {
        return Color(red: red/255, green: green/255, blue: blue/255, opacity: alpha)
    }
}

// MARK: - UIColor Extension for Hex Support
private extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            } else if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

// MARK: - Color Scheme Support
public extension SharedColors {
    /// Adaptive color that changes based on light/dark mode
    static func adaptive(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Pre-defined adaptive colors
    struct Adaptive {
        public static let background = adaptive(
            light: Neutral.white,
            dark: Neutral.black
        )

        public static let surface = adaptive(
            light: Neutral.gray50,
            dark: Neutral.gray800
        )

        public static let textPrimary = adaptive(
            light: Neutral.black,
            dark: Neutral.white
        )

        public static let textSecondary = adaptive(
            light: Neutral.gray600,
            dark: Neutral.gray400
        )

        public static let border = adaptive(
            light: Neutral.gray300,
            dark: Neutral.gray600
        )
    }
}

// MARK: - View Modifiers
public extension View {
    /// Apply consistent background color
    func sharedBackground(_ style: BackgroundStyle = .primary) -> some View {
        self.background(backgroundColor(for: style))
    }

    /// Apply consistent text color
    func sharedTextColor(_ style: TextStyle = .primary) -> some View {
        self.foregroundColor(textColor(for: style))
    }

    /// Apply consistent border color
    func sharedBorderColor(_ style: BorderStyle = .primary) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor(for: style), lineWidth: 1)
        )
    }

    // MARK: - Helper Enums
    enum BackgroundStyle {
        case primary, secondary, tertiary, overlay, videoPlayer
    }

    enum TextStyle {
        case primary, secondary, tertiary, inverse, videoControls
    }

    enum BorderStyle {
        case primary, secondary, tertiary, focus, disabled
    }

    // MARK: - Helper Methods
    private func backgroundColor(for style: BackgroundStyle) -> Color {
        switch style {
        case .primary: return SharedColors.Background.primary
        case .secondary: return SharedColors.Background.secondary
        case .tertiary: return SharedColors.Background.tertiary
        case .overlay: return SharedColors.Background.overlay
        case .videoPlayer: return SharedColors.Video.controlsBackground
        }
    }

    private func textColor(for style: TextStyle) -> Color {
        switch style {
        case .primary: return SharedColors.Text.primary
        case .secondary: return SharedColors.Text.secondary
        case .tertiary: return SharedColors.Text.tertiary
        case .inverse: return SharedColors.Text.inverse
        case .videoControls: return SharedColors.Video.controlsForeground
        }
    }

    private func borderColor(for style: BorderStyle) -> Color {
        switch style {
        case .primary: return SharedColors.Border.primary
        case .secondary: return SharedColors.Border.secondary
        case .tertiary: return SharedColors.Border.tertiary
        case .focus: return SharedColors.Border.focus
        case .disabled: return SharedColors.Border.disabled
        }
    }
}

// MARK: - Preview
#Preview("Color Palette") {
    ScrollView {
        VStack(spacing: 20) {
            GroupHeader("Brand Colors")
            ColorRow("Primary", SharedColors.Brand.primary)
            ColorRow("Secondary", SharedColors.Brand.secondary)
            ColorRow("Accent", SharedColors.Brand.accent)

            GroupHeader("Semantic Colors")
            ColorRow("Success", SharedColors.Semantic.success)
            ColorRow("Warning", SharedColors.Semantic.warning)
            ColorRow("Error", SharedColors.Semantic.error)
            ColorRow("Info", SharedColors.Semantic.info)

            GroupHeader("Neutral Colors")
            ColorRow("White", SharedColors.Neutral.white)
            ColorRow("Gray 100", SharedColors.Neutral.gray100)
            ColorRow("Gray 300", SharedColors.Neutral.gray300)
            ColorRow("Gray 500", SharedColors.Neutral.gray500)

            GroupHeader("Video Colors")
            ColorRow("Video Controls BG", SharedColors.Video.controlsBackground)
            ColorRow("Video Controls FG", SharedColors.Video.controlsForeground)
            ColorRow("Video Accent", SharedColors.Video.controlsAccent)
        }
        .padding()
    }
}

private struct GroupHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top)
    }
}

private struct ColorRow: View {
    let name: String
    let color: Color

    init(_ name: String, _ color: Color) {
        self.name = name
        self.color = color
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text(name)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}