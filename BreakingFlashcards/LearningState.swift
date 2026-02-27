// LearningState.swift — Spaced repetition state machine
//
// Every Move has a learning state that progresses through three stages:
//   NEW → LEARNING → MASTERY
//
// The progression is driven by review ratings:
//   - "GOOD" promotes: NEW → LEARNING, LEARNING → MASTERY
//   - "HARD" sets to LEARNING (no change if already LEARNING)
//   - "AGAIN" demotes back to NEW
//
// This enum is the type-safe wrapper around the raw strings stored in SwiftData.
// The raw strings ("NEW", "LEARNING", "MASTERY") are what get persisted in the DB.

import SwiftUI

enum LearningState: String, CaseIterable {
    case newState = "NEW"       // Just added, never reviewed
    case learning = "LEARNING"  // In progress, needs more practice
    case mastery = "MASTERY"    // Fully learned / muscle memory

    // MARK: - Resolve from raw string
    // Safely converts a raw string (from SwiftData) to a LearningState.
    // Returns .newState as fallback if the string is nil or unrecognized.
    static func resolve(from rawValue: String?) -> LearningState {
        guard let rawValue, let state = LearningState(rawValue: rawValue) else {
            return .newState
        }
        return state
    }

    // MARK: - Resolve composite state for a combo
    // A combo's learning state is derived from its constituent moves:
    //   - ALL mastery → combo is MASTERY
    //   - ANY new → combo is NEW (weakest link)
    //   - ANY learning → combo is LEARNING
    //   - Empty → defaults to NEW
    static func resolve(from states: [LearningState]) -> LearningState {
        guard !states.isEmpty else { return .newState }
        if states.allSatisfy({ $0 == .mastery }) { return .mastery }
        if states.contains(.newState) { return .newState }
        if states.contains(.learning) { return .learning }
        return .newState
    }

    // MARK: - Visual representation
    // Each state has a distinct color from the design system (DesignSystem.swift).
    var color: Color {
        switch self {
        case .newState: return .stateNew      // Magenta (#ff7eb6)
        case .learning: return .stateLearning  // Purple (#491d8b)
        case .mastery: return .stateMastery    // Green (#24a148)
        }
    }

    // Display text is just the raw value (e.g. "NEW", "LEARNING", "MASTERY")
    var displayText: String { rawValue }

    // Human-readable action labels for list rows and summaries
    var actionLabel: String {
        switch self {
        case .newState: return "to learn"
        case .learning: return "practicing"
        case .mastery:  return "mastered"
        }
    }
}
