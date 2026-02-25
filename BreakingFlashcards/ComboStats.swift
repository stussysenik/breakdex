import CoreData

struct ComboStats {
    var count: Int = 0
    var states: [LearningState] = []

    mutating func add(_ comboMove: ComboMove) {
        count += 1
        if let rawState = comboMove.move?.learningState {
            states.append(LearningState.resolve(from: rawState))
        }
    }

    var learningState: LearningState {
        LearningState.resolve(from: states)
    }
}

enum ComboStatsBuilder {
    static func build<S: Sequence>(from comboMoves: S) -> [NSManagedObjectID: ComboStats] where S.Element == ComboMove {
        var map: [NSManagedObjectID: ComboStats] = [:]
        for comboMove in comboMoves {
            guard let combo = comboMove.combo else { continue }
            var stats = map[combo.objectID] ?? ComboStats()
            stats.add(comboMove)
            map[combo.objectID] = stats
        }
        return map
    }
}
