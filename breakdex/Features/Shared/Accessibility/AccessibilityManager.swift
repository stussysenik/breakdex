import SwiftUI
import Combine

// MARK: - Accessibility Manager
/// Central manager for accessibility settings and preferences
/// Supports WCAG 2.2 AA compliance and 65+ user accommodations

@MainActor
final class AccessibilityManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    // MARK: - User Preferences (Persisted)

    /// Enable larger touch targets (56pt minimum vs 44pt)
    @AppStorage("largeTouchTargets") var largeTouchTargets = false

    /// Enable high contrast mode for better visibility
    @AppStorage("highContrastMode") var highContrastMode = false

    /// Enable slower animations for easier tracking
    @AppStorage("slowerAnimations") var slowerAnimations = false

    /// Enable haptic feedback enhancement
    @AppStorage("enhancedHaptics") var enhancedHaptics = true

    /// Preferred text size multiplier (1.0 = default, 1.5 = 150%)
    @AppStorage("textSizeMultiplier") var textSizeMultiplier: Double = 1.0

    // MARK: - Computed Properties

    /// Returns appropriate touch target size based on accessibility settings
    /// Standard: 44pt, Accessible: 56pt (per research for 65+ users)
    var touchTargetSize: CGFloat {
        largeTouchTargets ? 56 : 44
    }

    /// Returns minimum touch target size for critical controls
    var minimumTouchTarget: CGFloat {
        largeTouchTargets ? 56 : 44
    }

    /// Returns effective animation based on all accessibility settings
    var effectiveAnimation: Animation {
        // System reduce motion takes highest priority
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.15)
        }
        // User preference for slower animations
        if slowerAnimations {
            return MotionSystem.gentle
        }
        return MotionSystem.primary
    }

    /// Returns effective micro animation for button presses
    var effectiveMicroAnimation: Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.1)
        }
        if slowerAnimations {
            return MotionSystem.secondary
        }
        return MotionSystem.micro
    }

    /// Returns scaled font size
    func scaledSize(_ baseSize: CGFloat) -> CGFloat {
        baseSize * CGFloat(textSizeMultiplier)
    }

    // MARK: - System Accessibility State

    /// Returns true if system reduce motion is enabled
    var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Returns true if VoiceOver is running
    var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    /// Returns true if bold text is enabled
    var isBoldTextEnabled: Bool {
        UIAccessibility.isBoldTextEnabled
    }

    /// Returns true if any accessibility feature is active
    var isAccessibilityActive: Bool {
        isReduceMotionEnabled ||
        isVoiceOverRunning ||
        largeTouchTargets ||
        highContrastMode ||
        slowerAnimations
    }

    // MARK: - Initialization

    private init() {
        setupNotifications()
    }

    // MARK: - Notification Observers

    private var cancellables = Set<AnyCancellable>()

    private func setupNotifications() {
        // Listen for accessibility changes
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Haptic Feedback

    /// Triggers light haptic feedback (for frame boundaries, selections)
    func lightHaptic() {
        guard enhancedHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Triggers medium haptic feedback (for button taps, confirmations)
    func mediumHaptic() {
        guard enhancedHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Triggers heavy haptic feedback (for markers, important events)
    func heavyHaptic() {
        guard enhancedHaptics else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Triggers success notification haptic
    func successHaptic() {
        guard enhancedHaptics else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Triggers error notification haptic
    func errorHaptic() {
        guard enhancedHaptics else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Triggers selection haptic
    func selectionHaptic() {
        guard enhancedHaptics else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Convenience Methods

    /// Announces text to VoiceOver if running
    func announce(_ message: String) {
        guard isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Posts screen changed notification for VoiceOver
    func screenChanged() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }

    /// Posts layout changed notification for VoiceOver
    func layoutChanged() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - Accessibility Environment Key

private struct AccessibilityManagerKey: EnvironmentKey {
    static let defaultValue = AccessibilityManager.shared
}

extension EnvironmentValues {
    var accessibilityManager: AccessibilityManager {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies accessibility-appropriate touch target sizing
    func accessibleTouchTarget() -> some View {
        self.modifier(AccessibleTouchTargetModifier())
    }

    /// Applies high contrast styling when enabled
    func accessibleHighContrast() -> some View {
        self.modifier(HighContrastModifier())
    }

    /// Adds accessibility label and hint
    func accessibilityDescribed(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Accessible Touch Target Modifier

struct AccessibleTouchTargetModifier: ViewModifier {
    @ObservedObject private var accessibility = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .frame(minWidth: accessibility.touchTargetSize, minHeight: accessibility.touchTargetSize)
    }
}

// MARK: - High Contrast Modifier

struct HighContrastModifier: ViewModifier {
    @ObservedObject private var accessibility = AccessibilityManager.shared

    func body(content: Content) -> some View {
        if accessibility.highContrastMode {
            content.environment(\.colorScheme, .dark)
        } else {
            content
        }
    }
}

// MARK: - Accessibility Aware Button Style

struct AccessibleButtonStyle: ButtonStyle {
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var backgroundColor: Color = .accent
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: accessibility.touchTargetSize)
            .background(
                accessibility.highContrastMode
                    ? Color.accessibleAccent
                    : backgroundColor
            )
            .foregroundColor(foregroundColor)
            .cornerRadius(AppLayout.smallRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(accessibility.effectiveMicroAnimation, value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct AccessibilityManager_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityDemoView()
    }
}

struct AccessibilityDemoView: View {
    @StateObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section("Touch Targets") {
                    Toggle("Large Touch Targets (56pt)", isOn: $accessibility.largeTouchTargets)
                    Text("Current size: \(Int(accessibility.touchTargetSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Visual") {
                    Toggle("High Contrast Mode", isOn: $accessibility.highContrastMode)
                    Toggle("Slower Animations", isOn: $accessibility.slowerAnimations)
                }

                Section("Haptics") {
                    Toggle("Enhanced Haptics", isOn: $accessibility.enhancedHaptics)

                    Button("Test Light Haptic") {
                        accessibility.lightHaptic()
                    }

                    Button("Test Heavy Haptic") {
                        accessibility.heavyHaptic()
                    }

                    Button("Test Success Haptic") {
                        accessibility.successHaptic()
                    }
                }

                Section("System Status") {
                    LabeledContent("Reduce Motion", value: accessibility.isReduceMotionEnabled ? "On" : "Off")
                    LabeledContent("VoiceOver", value: accessibility.isVoiceOverRunning ? "On" : "Off")
                    LabeledContent("Bold Text", value: accessibility.isBoldTextEnabled ? "On" : "Off")
                }

                Section("Demo Buttons") {
                    Button("Standard Button") {}
                        .buttonStyle(AccessibleButtonStyle())

                    Button("High Contrast") {}
                        .buttonStyle(AccessibleButtonStyle(backgroundColor: .accessibleAccent))
                }
            }
            .navigationTitle("Accessibility")
        }
    }
}
#endif
