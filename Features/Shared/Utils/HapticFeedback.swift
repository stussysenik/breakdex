import UIKit

// MARK: - Haptic Feedback Utility
/// Simple haptic feedback utility to replace MotionCatalog
/// Essentialist approach - provides only necessary haptic types
public struct HapticFeedback {

    // MARK: - Haptic Types
    public enum HapticType {
        case selection    // For selection changes
        case action       // For button presses, actions
        case notification // For notifications/warnings
        case impact       // For impacts/feedback
    }

    // MARK: - Public Interface

    /// Play selection haptic - for UI selection changes
    public static func selectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Play action haptic - for button taps and actions
    public static func actionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Play notification haptic - for success/error/warning
    public static func notificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    /// Play impact haptic - for physical feedback
    public static func impactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Compatibility Interface (MotionCatalog replacement)

    /// Compatibility layer for MotionCatalog.Accessibility.buttonTap()
    public static func buttonTap() {
        actionHaptic()
    }
}

// MARK: - MotionCatalog Compatibility Namespace
/// Provides MotionCatalog-compatible interface for gradual migration
public struct MotionCatalog {
    public struct Accessibility {
        public static func buttonTap() {
            HapticFeedback.actionHaptic()
        }

        public static func selectionHaptic() {
            HapticFeedback.selectionHaptic()
        }

        public static func actionHaptic() {
            HapticFeedback.actionHaptic()
        }
    }
}