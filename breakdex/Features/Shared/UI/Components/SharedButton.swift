import SwiftUI
import AVKit

// SharedButton.swift - re-usable button component (creator function)

// MARK: - Shared Button
/// Reusable button component that maintains consistent styling across the app
/// Based on the primary button style from SelectClip.swift for consistency
struct SharedButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ibmPlexMono(size: 18, weight: .thin))
                .foregroundColor(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 11)
                .background(backgroundColor)
                .cornerRadius(12)
        }
        .buttonStyle(PressedButtonStyle())
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.primary // Uses the brand accent color from DesignSystem
        case .secondary:
            return Color.secondary // Uses the purple secondary color from DesignSystem
        }
    }
}

// MARK: - Pressed Button Style
/// Provides the scale effect and animation for button presses
struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Convenience Initializers
extension SharedButton {
    /// Primary button with standard sizing
    static func primary(_ title: String, size: ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
        SharedButton(title: title, style: .primary, action: action)
    }

    /// Secondary button with standard sizing
    static func secondary(_ title: String, size: ButtonSize = .medium, action: @escaping () -> Void) -> SharedButton {
        SharedButton(title: title, style: .secondary, action: action)
    }
}

// MARK: - Button Sizes
extension SharedButton {
    enum ButtonSize {
        case small
        case medium
        case large

        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small:
                return (8, 8)
            case .medium:
                return (11, 11) // Matches SelectClip button
            case .large:
                return (16, 16)
            }
        }
    }
}


#Preview("Shared Buttons") {
    VStack(spacing: 16) {
        SharedButton.primary("Primary Action") {}
        SharedButton.secondary("Secondary Action") {}
    }
    .padding(24)
    .background(Color.backgroundPrimary)
}
