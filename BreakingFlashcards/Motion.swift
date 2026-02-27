// Motion.swift — Animation presets and accessibility-aware motion system
//
// All animation curves used throughout the app are defined here as static constants.
// This provides a single source of truth for motion design — no magic numbers
// scattered across view files.
//
// Two categories of animations:
// 1. General UI: button presses, state transitions, modals
// 2. Video Editor: scrub release, handle physics, rotation snaps
//
// The AppMotionModifier respects the system "Reduce Motion" accessibility setting.
// When reduce motion is enabled, animations are silently disabled.

import SwiftUI

enum AppMotion {
    // MARK: - General UI Curves

    /// Micro-interactions: button presses, toggles — fast and snappy
    static let easeStandard = Animation.easeInOut(duration: 0.18)

    /// State transitions: loading → preview, view swaps — smooth and fluid
    static let easeState = Animation.easeInOut(duration: 0.3)

    /// Soft spring: cards, modals, interactive elements
    /// response=0.3 (speed), dampingFraction=0.82 (minimal bounce)
    static let springSoft = Animation.spring(response: 0.3, dampingFraction: 0.82, blendDuration: 0)

    /// Quick spring: progress rings, counters
    /// Lower damping = slightly more bounce than springSoft
    static let springQuick = Animation.spring(response: 0.2, dampingFraction: 0.75, blendDuration: 0)

    // MARK: - Video Editor Curves

    /// Scrub release: when user lifts finger from playhead — snappy return
    static let scrubRelease = Animation.spring(response: 0.15, dampingFraction: 0.9, blendDuration: 0)

    /// Handle release: when trim handle settles after drag — smooth
    static let handleRelease = Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)

    /// Rotation snap: 90° increments — low damping gives a satisfying overshoot
    static let rotationSnap = Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0)

    /// Speed pill selection: instant, no bounce
    static let pillSelect = Animation.easeInOut(duration: 0.15)

    /// Export progress bar: linear for accurate visual progress
    static let exportProgress = Animation.linear(duration: 0.2)
}

// MARK: - Accessibility-Aware Motion Modifier
// Wraps any hashable value change in an animation, but only if the user
// hasn't enabled "Reduce Motion" in iOS Accessibility settings.
// Usage: .appMotion(someValue) — applies easeStandard animation to changes.

struct AppMotionModifier<Value: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        if reduceMotion {
            content  // No animation — respect the user's accessibility preference
        } else {
            content.animation(AppMotion.easeStandard, value: value)
        }
    }
}

// Convenience extension: .appMotion(value) instead of .modifier(AppMotionModifier(value: value))
extension View {
    func appMotion<Value: Hashable>(_ value: Value) -> some View {
        modifier(AppMotionModifier(value: value))
    }
}
