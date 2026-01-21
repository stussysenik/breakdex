import SwiftUI
import UIKit

// MARK: - Motion System
/// Central animation system providing buttery smooth 60fps animations
/// with accessibility-aware fallbacks for reduced motion preferences.

struct MotionSystem {

    // MARK: - Spring Presets

    /// Primary spring - Used for main interactions (cards, navigation, modals)
    /// Response: 0.4s, Damping: 0.8 (slightly underdamped for subtle bounce)
    static let primary = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Secondary spring - Used for supporting animations (state changes, toggles)
    /// Response: 0.5s, Damping: 0.75 (more bounce for visual interest)
    static let secondary = Animation.spring(response: 0.5, dampingFraction: 0.75)

    /// Micro spring - Used for small feedback (button presses, micro-interactions)
    /// Response: 0.25s, Damping: 0.9 (quick, minimal overshoot)
    static let micro = Animation.spring(response: 0.25, dampingFraction: 0.9)

    /// Gentle spring - Used for accessibility mode (65+ users, slower animations)
    /// Response: 0.6s, Damping: 0.7 (slow and graceful)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.7)

    /// Snappy spring - Used for immediate feedback (haptic-paired actions)
    /// Response: 0.2s, Damping: 0.95 (near-instant, barely any bounce)
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.95)

    /// Bouncy spring - Used for playful interactions (success states, achievements)
    /// Response: 0.5s, Damping: 0.6 (noticeable bounce for delight)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    // MARK: - Interactive Springs

    /// Interactive spring - For gesture-driven animations (drag, scrub)
    /// Uses interactiveSpring for better gesture tracking
    static let interactive = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.86, blendDuration: 0.25)

    /// Fluid spring - For continuous gestures (scrubbing, panning)
    static let fluid = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.9, blendDuration: 0.1)

    // MARK: - Easing Curves (for non-spring animations)

    /// Quick ease out - For fast exits
    static let quickOut = Animation.easeOut(duration: 0.2)

    /// Smooth ease - For general transitions
    static let smooth = Animation.easeInOut(duration: 0.3)

    // MARK: - Accessibility-Aware Animation

    /// Returns an appropriate animation based on accessibility settings
    /// - Parameter base: The default animation to use when reduced motion is disabled
    /// - Returns: Either the base animation or a linear fallback for reduced motion
    static func animation(_ base: Animation) -> Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.15)
        }
        return base
    }

    /// Returns animation with accessibility and preference checks
    /// - Parameters:
    ///   - base: Default animation
    ///   - slowerPreferred: Whether the user prefers slower animations (from settings)
    /// - Returns: Appropriate animation for current accessibility state
    static func animation(_ base: Animation, slowerPreferred: Bool) -> Animation {
        if UIAccessibility.isReduceMotionEnabled {
            return .linear(duration: 0.15)
        }
        if slowerPreferred {
            return gentle
        }
        return base
    }

    // MARK: - Animation Helpers

    /// Conditionally applies animation only when not in reduced motion mode
    static func withMotion(_ animation: Animation, body: () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            body()
        } else {
            withAnimation(animation, body)
        }
    }
}

// MARK: - Golden Ratio System
/// Mathematical golden ratio constants for harmonious layouts

struct GoldenRatio {
    /// Phi (φ) - The golden ratio: 1.618033988749895
    static let phi: CGFloat = 1.618033988749895

    /// Inverse phi (1/φ) - Approximately 0.618
    static let inverse: CGFloat = 0.618033988749895

    /// Phi squared - Approximately 2.618
    static let phiSquared: CGFloat = phi * phi

    // MARK: - Proportional Calculations

    /// Returns the major portion (larger segment) of a total
    /// Example: major(of: 100) = 61.8
    static func major(of total: CGFloat) -> CGFloat {
        total * inverse
    }

    /// Returns the minor portion (smaller segment) of a total
    /// Example: minor(of: 100) = 38.2
    static func minor(of total: CGFloat) -> CGFloat {
        total * (1 - inverse)
    }

    /// Splits a total into major and minor portions
    static func split(_ total: CGFloat) -> (major: CGFloat, minor: CGFloat) {
        (major(of: total), minor(of: total))
    }

    // MARK: - Layout Helpers

    /// Returns ideal card height for a given width using golden ratio
    /// Width / phi = height (landscape orientation)
    static func cardHeight(forWidth width: CGFloat) -> CGFloat {
        width / phi
    }

    /// Returns ideal video thumbnail height maintaining golden ratio
    /// For video-centric layouts where video is the major portion
    static func videoHeight(forWidth width: CGFloat) -> CGFloat {
        width * inverse
    }

    /// Returns content area height after video in golden ratio card
    static func contentHeight(forCardHeight height: CGFloat) -> CGFloat {
        height * (1 - inverse)
    }

    /// Returns aspect ratio for golden rectangle (width:height)
    static let aspectRatio: CGFloat = phi

    /// Returns inverse aspect ratio (height:width) for portrait orientation
    static let inverseAspectRatio: CGFloat = inverse
}

// MARK: - Motion View Modifiers

extension View {
    /// Applies scale effect with spring animation on press
    /// - Parameters:
    ///   - isPressed: Whether the view is currently pressed
    ///   - scale: The scale to apply when pressed (default: 0.98)
    func pressScale(isPressed: Bool, scale: CGFloat = 0.98) -> some View {
        self
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(MotionSystem.micro, value: isPressed)
    }

    /// Applies accessibility-aware animation
    func withAccessibleAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        self.animation(MotionSystem.animation(animation), value: value)
    }

    /// Applies spring animation with opacity transition
    func springFadeIn(isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .animation(MotionSystem.primary, value: isVisible)
    }

    /// Applies gentle animation for accessibility mode
    func gentleTransition<V: Equatable>(value: V) -> some View {
        self.animation(MotionSystem.gentle, value: value)
    }
}

// MARK: - Motion Transitions

extension AnyTransition {
    /// Spring scale + fade transition for cards
    static var springScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    /// Slide from bottom with spring
    static var springSlideUp: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Gentle fade for accessibility
    static var gentleFade: AnyTransition {
        .opacity
    }
}

// MARK: - Preview

#if DEBUG
struct MotionSystem_Previews: PreviewProvider {
    static var previews: some View {
        MotionSystemDemoView()
    }
}

struct MotionSystemDemoView: View {
    @State private var isAnimated = false
    @State private var isPrimaryPressed = false
    @State private var isSecondaryPressed = false
    @State private var isMicroPressed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Motion System Demo")
                    .font(.ibmPlexMono(size: 24, weight: .bold))

                // Golden Ratio Demo
                VStack(alignment: .leading, spacing: 8) {
                    Text("Golden Ratio Layout")
                        .font(.ibmPlexMono(size: 14, weight: .medium))

                    GeometryReader { geo in
                        let (major, minor) = GoldenRatio.split(geo.size.width - 16)
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accent)
                                .frame(width: major)
                                .overlay(Text("Major\n61.8%").font(.caption).foregroundColor(.white))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accent.opacity(0.5))
                                .frame(width: minor)
                                .overlay(Text("Minor\n38.2%").font(.caption))
                        }
                    }
                    .frame(height: 80)
                }
                .padding(.horizontal)

                // Spring Presets Demo
                VStack(alignment: .leading, spacing: 16) {
                    Text("Spring Presets")
                        .font(.ibmPlexMono(size: 14, weight: .medium))

                    springDemoButton("Primary", animation: MotionSystem.primary, isPressed: $isPrimaryPressed)
                    springDemoButton("Secondary", animation: MotionSystem.secondary, isPressed: $isSecondaryPressed)
                    springDemoButton("Micro", animation: MotionSystem.micro, isPressed: $isMicroPressed)
                }
                .padding(.horizontal)

                // Toggle Animation Demo
                VStack(spacing: 16) {
                    Text("Animation Toggle")
                        .font(.ibmPlexMono(size: 14, weight: .medium))

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accent)
                        .frame(width: 100, height: 100)
                        .offset(x: isAnimated ? 100 : -100)
                        .animation(MotionSystem.primary, value: isAnimated)

                    Button("Toggle") {
                        isAnimated.toggle()
                    }
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                }

                // Accessibility Note
                Text("Enable Reduce Motion in Settings to see fallback animations")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }

    @ViewBuilder
    func springDemoButton(_ name: String, animation: Animation, isPressed: Binding<Bool>) -> some View {
        Button {
            // Action
        } label: {
            Text(name)
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accent)
                .cornerRadius(8)
        }
        .scaleEffect(isPressed.wrappedValue ? 0.95 : 1.0)
        .animation(animation, value: isPressed.wrappedValue)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed.wrappedValue = true }
                .onEnded { _ in isPressed.wrappedValue = false }
        )
    }
}
#endif
