import SwiftUI

// MARK: - Button Style System
// Centralized button styling system for consistent UI across the app
// Inspired by the "Save Combo" button styling with borderedProminent + accent

struct AppButtonStyle: ButtonStyle {
    enum ButtonType {
        case primary    // Main actions (Save, Add Another Move, Try Again, etc.)
        case secondary  // Supporting actions (Cancel, Back, Done, etc.)
        case accent     // Special emphasis (Save Combo, etc.)

        var backgroundColor: Color {
            switch self {
            case .primary:
                return .blue  // Apple's standard blue
            case .secondary:
                return Color.gray.opacity(0.5)  // Keep existing gray
            case .accent:
                return .blue  // Apple's standard blue for emphasis
            }
        }

        var foregroundColor: Color {
            return .white
        }
    }

    let type: ButtonType
    let size: ButtonSize

    enum ButtonSize {
        case small
        case medium
        case large

        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium:
                return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .large:
                return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            }
        }

        var font: Font {
            switch self {
            case .small:
                return .bodySmall
            case .medium:
                return .bodyMedium
            case .large:
                return .bodyLarge
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(type.backgroundColor)
            )
            .foregroundColor(type.foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions
extension ButtonStyle where Self == AppButtonStyle {
    static func appPrimary(size: AppButtonStyle.ButtonSize = .medium) -> AppButtonStyle {
        AppButtonStyle(type: .primary, size: size)
    }

    static func appSecondary(size: AppButtonStyle.ButtonSize = .medium) -> AppButtonStyle {
        AppButtonStyle(type: .secondary, size: size)
    }

    static func appAccent(size: AppButtonStyle.ButtonSize = .large) -> AppButtonStyle {
        AppButtonStyle(type: .accent, size: size)
    }
}

extension ButtonStyle where Self == PhotosPickerButtonStyle {
    static func photosPicker(type: AppButtonStyle.ButtonType) -> PhotosPickerButtonStyle {
        PhotosPickerButtonStyle(type: type)
    }
}

// MARK: - Legacy Compatibility
// For backward compatibility with existing VideoTrimmerButtonStyle
struct LegacyButtonStyle: ButtonStyle {
    let level: VideoTrimmerButtonStyle.Level

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(level == .primary ? Color.accent : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

extension ButtonStyle where Self == LegacyButtonStyle {
    static func legacyPrimary() -> LegacyButtonStyle {
        LegacyButtonStyle(level: .primary)
    }

    static func legacySecondary() -> LegacyButtonStyle {
        LegacyButtonStyle(level: .secondary)
    }
}

// MARK: - Photos Picker Button Style
struct PhotosPickerButtonStyle: ButtonStyle {
    let type: AppButtonStyle.ButtonType

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodyMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
