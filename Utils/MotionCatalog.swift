import SwiftUI

// MARK: - Minimal Motion Catalog
// =============================================================================
// Basic haptic feedback system - no animations to prevent bugs
// Focuses only on essential haptic feedback
//
// DESIGN PRINCIPLES:
// - No animations to avoid performance issues
// - Simple haptic feedback only
// - Minimal complexity
// =============================================================================

enum MotionCatalog {

    // MARK: - Navigation (Basic animations for compatibility)
    enum Navigation {
        static let push = Animation.easeInOut(duration: 0.22)
        static let tabSwitch = Animation.easeInOut(duration: 0.2)
    }

    // MARK: - Basic Haptic Feedback Only

    enum Haptic {
        static func light() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            #if targetEnvironment(simulator)
            print("🔊 Light haptic")
            #endif
        }

        static func medium() {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            #if targetEnvironment(simulator)
            print("🔊 Medium haptic")
            #endif
        }

        static func selection() {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()

            #if targetEnvironment(simulator)
            print("🎯 Selection haptic")
            #endif
        }

        static func success() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            #if targetEnvironment(simulator)
            print("✅ Success haptic")
            #endif
        }
    }

    // MARK: - Simplified API (No animations)

    enum Accessibility {
        static func accessibleAnimation(_ animation: Animation) -> Animation {
            return UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0) : animation
        }
        
        static func buttonTap() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            Haptic.light()
        }

        static func selectionHaptic() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            Haptic.selection()
        }

        static func actionHaptic() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            Haptic.medium()
        }

        static func tabNavigationHaptic() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            Haptic.medium()
        }

        static func successHaptic() {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            Haptic.success()
        }
    }
}