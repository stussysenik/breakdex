import SwiftUI
import UIKit

// MARK: - Font Weight Conversion
extension Font.Weight {
    /// Convert SwiftUI Font.Weight to UIFont.Weight
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

// MARK: - Shared Typography
/// Centralized typography system for consistent text styling across features
public struct SharedTypography {

    // MARK: - Font Sizes
    public struct FontSize {
        public static let caption: CGFloat = 12
        public static let footnote: CGFloat = 14
        public static let body: CGFloat = 16
        public static let callout: CGFloat = 17
        public static let subheadline: CGFloat = 18
        public static let headline: CGFloat = 22
        public static let title: CGFloat = 28
        public static let largeTitle: CGFloat = 34
        public static let massive: CGFloat = 48

        // Video-specific font sizes
        public static let videoControls: CGFloat = 16
        public static let videoTime: CGFloat = 14
        public static let videoTitle: CGFloat = 20
        public static let videoSubtitle: CGFloat = 16
    }

    // MARK: - Font Weights
    public struct FontWeight {
        public static let ultraLight = Font.Weight.ultraLight
        public static let thin = Font.Weight.thin
        public static let light = Font.Weight.light
        public static let regular = Font.Weight.regular
        public static let medium = Font.Weight.medium
        public static let semibold = Font.Weight.semibold
        public static let bold = Font.Weight.bold
        public static let heavy = Font.Weight.heavy
        public static let black = Font.Weight.black
    }

    // MARK: - Text Styles
    public struct TextStyle {
        public let font: Font
        public let weight: Font.Weight
        public let size: CGFloat
        public let lineHeight: CGFloat
        public let letterSpacing: CGFloat

        public init(font: Font, weight: Font.Weight, size: CGFloat, lineHeight: CGFloat, letterSpacing: CGFloat = 0) {
            self.font = font
            self.weight = weight
            self.size = size
            self.lineHeight = lineHeight
            self.letterSpacing = letterSpacing
        }

        // Computed font with weight
        public var weightedFont: Font {
            font.weight(weight)
        }
    }

    // MARK: - Pre-defined Text Styles
    public struct Styles {
        // MARK: - Header Styles
        public static let massiveTitle = TextStyle(
            font: .system(size: FontSize.massive, design: .rounded),
            weight: .bold,
            size: FontSize.massive,
            lineHeight: FontSize.massive * 1.1
        )

        public static let largeTitle = TextStyle(
            font: .system(size: FontSize.largeTitle, design: .rounded),
            weight: .bold,
            size: FontSize.largeTitle,
            lineHeight: FontSize.largeTitle * 1.1
        )

        public static let title1 = TextStyle(
            font: .system(size: FontSize.title, design: .rounded),
            weight: .bold,
            size: FontSize.title,
            lineHeight: FontSize.title * 1.1
        )

        public static let title2 = TextStyle(
            font: .system(size: FontSize.title, design: .rounded),
            weight: .semibold,
            size: FontSize.title,
            lineHeight: FontSize.title * 1.1
        )

        public static let headline = TextStyle(
            font: .system(size: FontSize.headline, design: .rounded),
            weight: .semibold,
            size: FontSize.headline,
            lineHeight: FontSize.headline * 1.2
        )

        // MARK: - Body Styles
        public static let body = TextStyle(
            font: .system(size: FontSize.body, design: .rounded),
            weight: .regular,
            size: FontSize.body,
            lineHeight: FontSize.body * 1.4
        )

        public static let bodyEmphasized = TextStyle(
            font: .system(size: FontSize.body, design: .rounded),
            weight: .semibold,
            size: FontSize.body,
            lineHeight: FontSize.body * 1.4
        )

        public static let callout = TextStyle(
            font: .system(size: FontSize.callout, design: .rounded),
            weight: .regular,
            size: FontSize.callout,
            lineHeight: FontSize.callout * 1.3
        )

        public static let subheadline = TextStyle(
            font: .system(size: FontSize.subheadline, design: .rounded),
            weight: .regular,
            size: FontSize.subheadline,
            lineHeight: FontSize.subheadline * 1.3
        )

        public static let subheadlineEmphasized = TextStyle(
            font: .system(size: FontSize.subheadline, design: .rounded),
            weight: .semibold,
            size: FontSize.subheadline,
            lineHeight: FontSize.subheadline * 1.3
        )

        // MARK: - Caption Styles
        public static let footnote = TextStyle(
            font: .system(size: FontSize.footnote, design: .rounded),
            weight: .regular,
            size: FontSize.footnote,
            lineHeight: FontSize.footnote * 1.3
        )

        public static let footnoteEmphasized = TextStyle(
            font: .system(size: FontSize.footnote, design: .rounded),
            weight: .semibold,
            size: FontSize.footnote,
            lineHeight: FontSize.footnote * 1.3
        )

        public static let caption1 = TextStyle(
            font: .system(size: FontSize.caption, design: .rounded),
            weight: .regular,
            size: FontSize.caption,
            lineHeight: FontSize.caption * 1.3
        )

        public static let caption2 = TextStyle(
            font: .system(size: FontSize.caption, design: .rounded),
            weight: .semibold,
            size: FontSize.caption,
            lineHeight: FontSize.caption * 1.3,
            letterSpacing: 0.5
        )

        // MARK: - Video-specific Styles
        public static let videoControls = TextStyle(
            font: .system(size: FontSize.videoControls, design: .rounded),
            weight: .medium,
            size: FontSize.videoControls,
            lineHeight: FontSize.videoControls * 1.2
        )

        public static let videoTime = TextStyle(
            font: Font.system(size: FontSize.videoTime, design: .monospaced),
            weight: .medium,
            size: FontSize.videoTime,
            lineHeight: FontSize.videoTime * 1.2
        )

        public static let videoTitle = TextStyle(
            font: .system(size: FontSize.videoTitle, design: .rounded),
            weight: .semibold,
            size: FontSize.videoTitle,
            lineHeight: FontSize.videoTitle * 1.2
        )

        public static let videoSubtitle = TextStyle(
            font: .system(size: FontSize.videoSubtitle, design: .rounded),
            weight: .regular,
            size: FontSize.videoSubtitle,
            lineHeight: FontSize.videoSubtitle * 1.3
        )

        // MARK: - Specialized Styles
        public static let button = TextStyle(
            font: .system(size: FontSize.body, design: .rounded),
            weight: .semibold,
            size: FontSize.body,
            lineHeight: FontSize.body * 1.2,
            letterSpacing: 0.5
        )

        public static let navigationTitle = TextStyle(
            font: .system(size: FontSize.title, design: .rounded),
            weight: .bold,
            size: FontSize.title,
            lineHeight: FontSize.title * 1.1
        )

        public static let tabLabel = TextStyle(
            font: .system(size: FontSize.caption, design: .rounded),
            weight: .medium,
            size: FontSize.caption,
            lineHeight: FontSize.caption * 1.2
        )

        public static let error = TextStyle(
            font: .system(size: FontSize.body, design: .rounded),
            weight: .medium,
            size: FontSize.body,
            lineHeight: FontSize.body * 1.4
        )

        public static let success = TextStyle(
            font: .system(size: FontSize.body, design: .rounded),
            weight: .medium,
            size: FontSize.body,
            lineHeight: FontSize.body * 1.4
        )
    }
}

// MARK: - Font Extensions
public extension Font {
    // Quick access to commonly used fonts
    static let massiveTitle = SharedTypography.Styles.massiveTitle.weightedFont
    static let largeTitle = SharedTypography.Styles.largeTitle.weightedFont
    static let title1 = SharedTypography.Styles.title1.weightedFont
    static let title2 = SharedTypography.Styles.title2.weightedFont
    static let headline = SharedTypography.Styles.headline.weightedFont
    static let body = SharedTypography.Styles.body.weightedFont
    static let bodyEmphasized = SharedTypography.Styles.bodyEmphasized.weightedFont
    static let callout = SharedTypography.Styles.callout.weightedFont
    static let subheadline = SharedTypography.Styles.subheadline.weightedFont
    static let footnote = SharedTypography.Styles.footnote.weightedFont
    static let caption1 = SharedTypography.Styles.caption1.weightedFont
    static let caption2 = SharedTypography.Styles.caption2.weightedFont

    // Video-specific fonts
    static let videoControls = SharedTypography.Styles.videoControls.weightedFont
    static let videoTime = SharedTypography.Styles.videoTime.weightedFont
    static let videoTitle = SharedTypography.Styles.videoTitle.weightedFont
    static let videoSubtitle = SharedTypography.Styles.videoSubtitle.weightedFont

    // Specialized fonts
    static let button = SharedTypography.Styles.button.weightedFont
    static let navigationTitle = SharedTypography.Styles.navigationTitle.weightedFont
    static let tabLabel = SharedTypography.Styles.tabLabel.weightedFont
}

// MARK: - Text Style Extensions
public extension Text {
    /// Apply shared typography style
    func sharedFont(_ style: SharedTypography.TextStyle) -> some View {
        self
            .font(style.weightedFont)
            .lineSpacing(style.lineHeight - style.size)
            .tracking(style.letterSpacing)
    }

    // Convenience methods for common styles
    func massiveTitle() -> some View {
        sharedFont(SharedTypography.Styles.massiveTitle)
    }

    func largeTitle() -> some View {
        sharedFont(SharedTypography.Styles.largeTitle)
    }

    func title1() -> some View {
        sharedFont(SharedTypography.Styles.title1)
    }

    func title2() -> some View {
        sharedFont(SharedTypography.Styles.title2)
    }

    func headline() -> some View {
        sharedFont(SharedTypography.Styles.headline)
    }

    func body() -> some View {
        sharedFont(SharedTypography.Styles.body)
    }

    func bodyEmphasized() -> some View {
        sharedFont(SharedTypography.Styles.bodyEmphasized)
    }

    func callout() -> some View {
        sharedFont(SharedTypography.Styles.callout)
    }

    func subheadline() -> some View {
        sharedFont(SharedTypography.Styles.subheadline)
    }

    func subheadlineEmphasized() -> some View {
        sharedFont(SharedTypography.Styles.subheadlineEmphasized)
    }

    func footnote() -> some View {
        sharedFont(SharedTypography.Styles.footnote)
    }

    func footnoteEmphasized() -> some View {
        sharedFont(SharedTypography.Styles.footnoteEmphasized)
    }

    func caption1() -> some View {
        sharedFont(SharedTypography.Styles.caption1)
    }

    func caption2() -> some View {
        sharedFont(SharedTypography.Styles.caption2)
    }

    // Video-specific styles
    func videoControls() -> some View {
        sharedFont(SharedTypography.Styles.videoControls)
    }

    func videoTime() -> some View {
        sharedFont(SharedTypography.Styles.videoTime)
    }

    func videoTitle() -> some View {
        sharedFont(SharedTypography.Styles.videoTitle)
    }

    func videoSubtitle() -> some View {
        sharedFont(SharedTypography.Styles.videoSubtitle)
    }

    // Specialized styles
    func buttonStyle() -> some View {
        sharedFont(SharedTypography.Styles.button)
    }

    func navigationTitle() -> some View {
        sharedFont(SharedTypography.Styles.navigationTitle)
    }

    func tabLabel() -> some View {
        sharedFont(SharedTypography.Styles.tabLabel)
    }

    func errorStyle() -> some View {
        sharedFont(SharedTypography.Styles.error)
    }

    func successStyle() -> some View {
        sharedFont(SharedTypography.Styles.success)
    }
}

// MARK: - Attributed String Support
public extension NSAttributedString {
    /// Create attributed string with shared typography
    static func shared(
        _ string: String,
        style: SharedTypography.TextStyle,
        color: Color = .primary
    ) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: style.size, weight: style.weight.uiFontWeight),
            .foregroundColor: UIColor(color),
            .kern: style.letterSpacing
        ]

        return NSAttributedString(string: string, attributes: attributes)
    }
}

// MARK: - Heading Level Enum
public enum TypographyHeadingLevel {
    case h1, h2, h3, h4
}

// MARK: - View Modifiers
public extension View {
    /// Apply consistent typography with additional styling
    func sharedTypography(
        _ style: SharedTypography.TextStyle,
        color: Color = .primary,
        multilineTextAlignment: TextAlignment? = nil
    ) -> some View {
        return self
            .font(style.weightedFont)
            .lineSpacing(style.lineHeight - style.size)
            .tracking(style.letterSpacing)
            .foregroundColor(color)
            .multilineTextAlignment(multilineTextAlignment ?? .leading)
    }

    /// Apply heading typography
    func heading(_ level: TypographyHeadingLevel = .h1, color: Color = .primary) -> some View {
        let style: SharedTypography.TextStyle
        switch level {
        case .h1: style = SharedTypography.Styles.title1
        case .h2: style = SharedTypography.Styles.title2
        case .h3: style = SharedTypography.Styles.headline
        case .h4: style = SharedTypography.Styles.subheadline
        }

        return sharedTypography(style, color: color)
    }

    /// Apply body typography
    func bodyText(emphasized: Bool = false, color: Color = .primary) -> some View {
        let style = emphasized ? SharedTypography.Styles.bodyEmphasized : SharedTypography.Styles.body
        return sharedTypography(style, color: color)
    }

    /// Apply caption typography
    func captionText(emphasized: Bool = false, color: Color = .secondary) -> some View {
        let style = emphasized ? SharedTypography.Styles.caption2 : SharedTypography.Styles.caption1
        return sharedTypography(style, color: color)
    }
}

// MARK: - Preview
#Preview("Typography Styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            GroupHeader("Header Styles")
            TextSample("Massive Title", style: SharedTypography.Styles.massiveTitle)
            TextSample("Large Title", style: SharedTypography.Styles.largeTitle)
            TextSample("Title 1", style: SharedTypography.Styles.title1)
            TextSample("Title 2", style: SharedTypography.Styles.title2)
            TextSample("Headline", style: SharedTypography.Styles.headline)

            GroupHeader("Body Styles")
            TextSample("Body text regular weight", style: SharedTypography.Styles.body)
            TextSample("Body text emphasized", style: SharedTypography.Styles.bodyEmphasized)
            TextSample("Callout text", style: SharedTypography.Styles.callout)
            TextSample("Subheadline text", style: SharedTypography.Styles.subheadline)
            TextSample("Subheadline emphasized", style: SharedTypography.Styles.subheadlineEmphasized)

            GroupHeader("Caption Styles")
            TextSample("Footnote text", style: SharedTypography.Styles.footnote)
            TextSample("Footnote emphasized", style: SharedTypography.Styles.footnoteEmphasized)
            TextSample("Caption 1 text", style: SharedTypography.Styles.caption1)
            TextSample("CAPTION 2 TEXT", style: SharedTypography.Styles.caption2)

            GroupHeader("Video Styles")
            TextSample("Video Controls", style: SharedTypography.Styles.videoControls)
            TextSample("00:00 / 01:23", style: SharedTypography.Styles.videoTime)
            TextSample("Video Title", style: SharedTypography.Styles.videoTitle)
            TextSample("Video subtitle text", style: SharedTypography.Styles.videoSubtitle)

            GroupHeader("Specialized Styles")
            TextSample("Button Text", style: SharedTypography.Styles.button)
            TextSample("Navigation Title", style: SharedTypography.Styles.navigationTitle)
            TextSample("Tab Label", style: SharedTypography.Styles.tabLabel)
            TextSample("Error Message", style: SharedTypography.Styles.error)
                .foregroundColor(SharedColors.Semantic.error)
            TextSample("Success Message", style: SharedTypography.Styles.success)
                .foregroundColor(SharedColors.Semantic.success)
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
                .foregroundColor(SharedColors.Brand.primary)
            Spacer()
        }
        .padding(.top)
    }
}

private struct TextSample: View {
    let text: String
    let style: SharedTypography.TextStyle

    init(_ text: String, style: SharedTypography.TextStyle) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .sharedFont(style)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}