import SwiftUI
import CoreData

enum LearningState: String, CaseIterable {
    case newState = "NEW"
    case learning = "LEARNING"
    case mastery = "MASTERY"

    static func resolve(from rawValue: String?) -> LearningState {
        guard let rawValue, let state = LearningState(rawValue: rawValue) else {
            return .newState
        }
        return state
    }

    static func resolve(from states: [LearningState]) -> LearningState {
        guard !states.isEmpty else { return .newState }
        if states.allSatisfy({ $0 == .mastery }) { return .mastery }
        if states.contains(.newState) { return .newState }
        if states.contains(.learning) { return .learning }
        return .newState
    }

    static func resolve(from rawStates: [String]) -> LearningState {
        let states = rawStates.compactMap { LearningState(rawValue: $0) }
        return resolve(from: states)
    }

    static func resolve(from moves: [Move]) -> LearningState {
        let rawStates = moves.compactMap { $0.learningState }
        return resolve(from: rawStates)
    }

    var color: Color {
        switch self {
        case .newState: return .stateNew
        case .learning: return .stateLearning
        case .mastery: return .stateMastery
        }
    }

    var displayText: String { rawValue }
}
