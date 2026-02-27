// ComboStats.swift — Combo statistics aggregation
//
// Since a Combo doesn't store its own learning state directly, we need to
// compute it from its child moves. This file provides the aggregation logic.
//
// ComboStats accumulates the move count and learning states for a single combo.
// ComboStatsBuilder processes ALL ComboMove entries in one pass to build a
// lookup table keyed by combo ID — this avoids N+1 query problems.
//
// Usage pattern (in views):
//   let statsByID = ComboStatsBuilder.build(from: comboMoves)
//   let stats = statsByID[combo.persistentModelID] ?? ComboStats()
//   // stats.count → number of moves
//   // stats.learningState → composite NEW/LEARNING/MASTERY

import SwiftData

// Accumulator for a single combo's statistics
struct ComboStats {
    var count: Int = 0                    // How many moves are in this combo
    var states: [LearningState] = []      // Learning state of each move

    // Add a ComboMove's data to this accumulator
    mutating func add(_ comboMove: ComboMove) {
        count += 1
        if let rawState = comboMove.move?.learningState {
            states.append(LearningState.resolve(from: rawState))
        }
    }

    // Derived composite learning state using LearningState.resolve(from:)
    // ALL mastery → MASTERY, ANY new → NEW, ANY learning → LEARNING
    var learningState: LearningState {
        LearningState.resolve(from: states)
    }
}

// Builds a dictionary of ComboStats for every combo, in a single pass.
// Input: all ComboMove objects (from a @Query).
// Output: [PersistentIdentifier: ComboStats] — keyed by combo's SwiftData ID.
enum ComboStatsBuilder {
    static func build(from comboMoves: [ComboMove]) -> [PersistentIdentifier: ComboStats] {
        var map: [PersistentIdentifier: ComboStats] = [:]
        for comboMove in comboMoves {
            guard let combo = comboMove.combo else { continue }
            // Get or create the stats entry for this combo
            var stats = map[combo.persistentModelID] ?? ComboStats()
            stats.add(comboMove)
            map[combo.persistentModelID] = stats
        }
        return map
    }
}
