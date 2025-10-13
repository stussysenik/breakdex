// import SwiftUI

// // MARK: - Shared Button
// /// Clean, reusable button component for consistent button styling across features
// public struct SharedButton: View {
//     // MARK: - Properties
//     private let title: String
//     private let action: () -> Void
//     private let configuration: ButtonConfiguration
//     private let isLoading: Bool

//     // MARK: - Button Configuration
//     public struct ButtonConfiguration {
//         let style: ButtonStyle
//         let size: ButtonSize
//         let state: ButtonState
//         let icon: String?
//         let iconPosition: IconPosition

//         public enum ButtonStyle {
//             case primary      // Main action button
//             case secondary    // Secondary action
//             case tertiary     // Tertiary/outline button
//             case danger       // Destructive action
//             case success      // Success action
//             case ghost        // Minimal button
//         }

//         public enum ButtonSize {
//             case small        // Compact button
//             case medium       // Standard button
//             case large        // Prominent button
//             case custom(height: CGFloat, padding: EdgeInsets)
//         }

//         public enum ButtonState {
//             case normal       // Default state
//             case disabled     // Disabled state
//             case loading      // Loading state
//             case selected     // Selected/active state
//         }

//         public enum IconPosition {
//             case leading
//             case trailing
//         }

//         public init(
//             style: ButtonStyle = .primary,
//             size: ButtonSize = .medium,
//             state: ButtonState = .normal,
//             icon: String? = nil,
//             iconPosition: IconPosition = .leading
//         ) {
//             self.style = style
//             self.size = size
//             self.state = state
//             self.icon = icon
//             self.iconPosition = iconPosition
//         }

//         // Preset configurations
//         public static let primaryLarge = ButtonConfiguration(style: .primary, size: .large)
//         public static let primaryMedium = ButtonConfiguration(style: .primary, size: .medium)
//         public static let primarySmall = ButtonConfiguration(style: .primary, size: .small)

//         public static let secondaryLarge = ButtonConfiguration(style: .secondary, size: .large)
//         public static let secondaryMedium = ButtonConfiguration(style: .secondary, size: .medium)
//         public static let secondarySmall = ButtonConfiguration(style: .secondary, size: .small)

//         public static let dangerMedium = ButtonConfiguration(style: .danger, size: .medium)
//         public static let ghostSmall = ButtonConfiguration(style: .ghost, size: .small)
//     }

//     // MARK: - Initialization
//     public init(
//         _ title: String,
//         configuration: ButtonConfiguration = .primaryMedium,
//         isLoading: Bool = false,
//         action: @escaping () -> Void
//     ) {
//         self.title = title
//         self.action = action
//         self.configuration = configuration
//         self.isLoading = isLoading
//     }

//     // Convenience initializers
//     public init(_ title: String, style: ButtonConfiguration.ButtonStyle, action: @escaping () -> Void) {
//         self.title = title
//         self.action = action
//         self.configuration = ButtonConfiguration(style: style, size: .medium)
//         self.isLoading = false
//     }

//     public init(_ title: String, size: ButtonConfiguration.ButtonSize, action: @escaping () -> Void) {
//         self.title = title
//         self.action = action
//         self.configuration = ButtonConfiguration(style: .primary, size: size)
//         self.isLoading = false
//     }

//     // MARK: - Body
//     public var body: some View {
//         Button(action: {
//             guard configuration.state != .disabled && !isLoading else { return }
//             action()
//         }) {
//             buttonContent
//         }
//         .buttonStyle(SharedButtonStyle(configuration: configuration))
//         .disabled(configuration.state == .disabled || isLoading)
//     }

//     // MARK: - Button Content

//     @ViewBuilder
//     private var buttonContent: some View {
//         HStack(spacing: iconSpacing) {
//             if isLoading {
//                 loadingIndicator
//             } else {
//                 // Leading icon
//                 if let icon = configuration.icon, configuration.iconPosition == .leading {
//                     Image(systemName: icon)
//                         .font(iconFont)
//                 }

//                 // Title
//                 Text(title)
//                     .font(titleFont)
//                     .lineLimit(1)

//                 // Trailing icon
//                 if let icon = configuration.icon, configuration.iconPosition == .trailing {
//                     Image(systemName: icon)
//                         .font(iconFont)
//                 }
//             }
//         }
//         .padding(buttonPadding)
//         .frame(minHeight: minHeight)
//         .contentShape(Rectangle())
//     }

//     // MARK: - Loading Indicator

//     private var loadingIndicator: some View {
//         ProgressView()
//             .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
//             .scaleEffect(0.8)
//     }

//     // MARK: - Style Properties

//     private var foregroundColor: Color {
//         switch configuration.style {
//         case .primary, .danger, .success:
//             return .white
//         case .secondary, .tertiary, .ghost:
//             return configuration.state == .selected ? .white : .primary
//         }
//     }

//     private var backgroundColor: Color {
//         switch configuration.style {
//         case .primary:
//             return configuration.state == .disabled ? .gray : .blue
//         case .secondary:
//             return configuration.state == .disabled ? .gray.opacity(0.3) : .gray.opacity(0.2)
//         case .tertiary:
//             return .clear
//         case .danger:
//             return configuration.state == .disabled ? .gray : .red
//         case .success:
//             return configuration.state == .disabled ? .gray : .green
//         case .ghost:
//             return .clear
//         }
//     }

//     private var borderColor: Color {
//         switch configuration.style {
//         case .primary, .secondary, .danger, .success:
//             return .clear
//         case .tertiary, .ghost:
//             return configuration.state == .selected ? .blue : .gray.opacity(0.5)
//         }
//     }

//     private var titleFont: Font {
//         switch configuration.size {
//         case .small:
//             return .caption.weight(.medium)
//         case .medium:
//             return .body.weight(.medium)
//         case .large:
//             return .headline.weight(.semibold)
//         case .custom:
//             return .body.weight(.medium)
//         }
//     }

//     private var iconFont: Font {
//         switch configuration.size {
//         case .small:
//             return .caption
//         case .medium:
//             return .body
//         case .large:
//             return .headline
//         case .custom:
//             return .body
//         }
//     }

//     private var buttonPadding: EdgeInsets {
//         switch configuration.size {
//         case .small:
//             return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
//         case .medium:
//             return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
//         case .large:
//             return EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
//         case .custom(let _, let padding):
//             return padding
//         }
//     }

//     private var minHeight: CGFloat {
//         switch configuration.size {
//         case .small: return 32
//         case .medium: return 44
//         case .large: return 56
//         case .custom(let height, _): return height
//         }
//     }

//     private var iconSpacing: CGFloat {
//         return configuration.icon != nil ? 8 : 0
//     }
// }

// // MARK: - Button Style
// private struct SharedButtonStyle: ButtonStyle {
//     let configuration: SharedButton.ButtonConfiguration

//     func makeBody(configuration: Configuration) -> some View {
//         configuration.label
//             .background(backgroundColor)
//             .overlay(
//                 RoundedRectangle(cornerRadius: cornerRadius)
//                     .stroke(borderColor, lineWidth: borderWidth)
//             )
//             .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
//             .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//             .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
//     }

//     private var backgroundColor: Color {
//         switch configuration.style {
//         case .primary:
//             return configuration.state == .disabled ? .gray : .blue
//         case .secondary:
//             return configuration.state == .disabled ? .gray.opacity(0.3) : .gray.opacity(0.2)
//         case .tertiary:
//             return .clear
//         case .danger:
//             return configuration.state == .disabled ? .gray : .red
//         case .success:
//             return configuration.state == .disabled ? .gray : .green
//         case .ghost:
//             return .clear
//         }
//     }

//     private var borderColor: Color {
//         switch configuration.style {
//         case .primary, .secondary, .danger, .success:
//             return .clear
//         case .tertiary, .ghost:
//             return configuration.state == .selected ? .blue : .gray.opacity(0.5)
//         }
//     }

//     private var borderWidth: CGFloat {
//         switch configuration.style {
//         case .tertiary, .ghost:
//             return 1
//         default:
//             return 0
//         }
//     }

//     private var cornerRadius: CGFloat {
//         return 8
//     }
// }

// // MARK: - Convenience Initializers
// public extension SharedButton {
//     /// Primary action button
//     static func primary(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .primary, size: size), action: action)
//     }

//     /// Secondary action button
//     static func secondary(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .secondary, size: size), action: action)
//     }

//     /// Destructive action button
//     static func danger(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .danger, size: size), action: action)
//     }

//     /// Success action button
//     static func success(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .success, size: size), action: action)
//     }

//     /// Outline button
//     static func outline(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .tertiary, size: size), action: action)
//     }

//     /// Ghost button
//     static func ghost(_ title: String, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(title, configuration: ButtonConfiguration(style: .ghost, size: size), action: action)
//     }

//     /// Button with icon
//     static func withIcon(_ title: String, icon: String, style: ButtonConfiguration.ButtonStyle = .primary, size: ButtonConfiguration.ButtonSize = .medium, iconPosition: ButtonConfiguration.IconPosition = .leading, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(
//             title,
//             configuration: ButtonConfiguration(
//                 style: style,
//                 size: size,
//                 icon: icon,
//                 iconPosition: iconPosition
//             ),
//             action: action
//         )
//     }
// }

// // MARK: - Loading State Support
// public extension SharedButton {
//     /// Button with loading state
//     static func loading(_ title: String, isLoading: Bool, style: ButtonConfiguration.ButtonStyle = .primary, size: ButtonConfiguration.ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
//         return SharedButton(
//             title,
//             configuration: ButtonConfiguration(style: style, size: size),
//             isLoading: isLoading,
//             action: action
//         )
//     }
// }

// // MARK: - Preview
// #Preview("Button Styles") {
//     VStack(spacing: 20) {
//         SharedButton.primary("Primary Button") { }
//         SharedButton.secondary("Secondary Button") { }
//         SharedButton.outline("Outline Button") { }
//         SharedButton.ghost("Ghost Button") { }
//         SharedButton.danger("Danger Button") { }
//         SharedButton.success("Success Button") { }
//     }
//     .padding()
// }

// #Preview("Button Sizes") {
//     VStack(spacing: 15) {
//         SharedButton.primary("Large Button", size: .large) { }
//         SharedButton.primary("Medium Button", size: .medium) { }
//         SharedButton.primary("Small Button", size: .small) { }
//     }
//     .padding()
// }

// #Preview("Button with Icons") {
//     VStack(spacing: 15) {
//         SharedButton.withIcon("Save Video", icon: "video.fill") { }
//         SharedButton.withIcon("Next", icon: "arrow.right", iconPosition: .trailing) { }
//         SharedButton.withIcon("Add Move", icon: "plus.circle.fill", style: .secondary) { }
//     }
//     .padding()
// }

// #Preview("Loading States") {
//     VStack(spacing: 15) {
//         SharedButton.loading("Processing...", isLoading: true) { }
//         SharedButton.loading("Saving...", isLoading: true, style: .secondary) { }
//         SharedButton("Normal Button") { }
//     }
//     .padding()
// }