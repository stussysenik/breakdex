import SwiftUI

enum AppMotion {
    /// Micro-interactions: button presses, toggles (snappy)
    static let easeStandard = Animation.easeInOut(duration: 0.18)
    /// State transitions: view swaps, loading → preview (fluid)
    static let easeState = Animation.easeInOut(duration: 0.3)
    /// Soft spring: cards, modals, interactive elements
    static let springSoft = Animation.spring(response: 0.3, dampingFraction: 0.82, blendDuration: 0)
    /// Quick spring: progress rings, counters
    static let springQuick = Animation.spring(response: 0.2, dampingFraction: 0.75, blendDuration: 0)

    // MARK: - Video Editor Curves

    /// Scrub release: snappy return
    static let scrubRelease = Animation.spring(response: 0.15, dampingFraction: 0.9, blendDuration: 0)
    /// Handle release: smooth settle
    static let handleRelease = Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)
    /// Rotation snap: slight overshoot for physicality
    static let rotationSnap = Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0)
    /// Speed pill selection
    static let pillSelect = Animation.easeInOut(duration: 0.15)
    /// Export progress bar
    static let exportProgress = Animation.linear(duration: 0.2)
}

struct AppMotionModifier<Value: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(AppMotion.easeStandard, value: value)
        }
    }
}

extension View {
    func appMotion<Value: Hashable>(_ value: Value) -> some View {
        modifier(AppMotionModifier(value: value))
    }
}
