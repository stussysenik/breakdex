// Models.swift — SwiftData persistence layer
//
// This file defines the four core data models that SwiftData persists to disk.
// SwiftData replaced CoreData in the SICP overhaul — no .xcdatamodeld needed.
// The @Model macro auto-generates schema, migration, and change-tracking.
//
// DATA RELATIONSHIPS:
//   Move ──< ComboMove >── Combo      (many-to-many via join table)
//   Move ──< Review                   (one-to-many: a move has many reviews)
//
// All properties are optional (SwiftData requirement for @Model classes).
// Default values are provided via init() so callers don't have to worry about nil.

import SwiftData
import Foundation

// MARK: - Move
// A single breakdancing move (e.g. "Windmill", "Headspin", "Six Step").
// This is the fundamental unit of the app — users record video clips of moves
// and track their learning progress through spaced repetition review.
@Model
final class Move {
    var id: UUID?                 // Unique identifier, auto-generated on init
    var name: String?             // Display name (e.g. "Windmill")
    var learningState: String?    // Raw string: "NEW", "LEARNING", or "MASTERY"
                                  // Stored as String (not enum) for SwiftData compatibility
    var createdAt: Date?          // When the move was added to the arsenal
    var videoReference: Data?     // Relative file path stored as UTF-8 Data
                                  // (e.g. "Moves/UUID.mp4" → Documents/Moves/UUID.mp4)
    var category: String?         // Category name (e.g. "MOVE", "COMBO", or custom)
                                  // References CategoryDefinition.name in AppSettings

    // Inverse relationships — SwiftData auto-manages these bidirectional links.
    // When a ComboMove or Review references this Move, it appears here automatically.
    @Relationship(inverse: \ComboMove.move) var combos: [ComboMove]?
    @Relationship(inverse: \Review.move) var reviews: [Review]?

    init(name: String = "", learningState: String = "NEW", category: String = "MOVE", createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.learningState = learningState
        self.category = category
        self.createdAt = createdAt
    }
}

// MARK: - Combo
// A sequence of moves chained together (e.g. "Toprock → Windmill → Freeze").
// Combos don't have their own learning state — it's computed from their child moves.
@Model
final class Combo {
    var id: UUID?
    var name: String?
    var activeMoveVideoReference: Data?  // Optional: video of the full combo in action

    // .cascade deleteRule: when a Combo is deleted, all its ComboMove join entries
    // are also deleted (but the Move objects themselves survive).
    @Relationship(deleteRule: .cascade, inverse: \ComboMove.combo) var comboMoves: [ComboMove]?

    init(name: String = "") {
        self.id = UUID()
        self.name = name
    }
}

// MARK: - ComboMove (Join Table)
// Links a Move to a Combo with a specific position in the sequence.
// This is the "join table" pattern for many-to-many relationships.
// sequenceIndex determines the order: 0 = first move, 1 = second, etc.
@Model
final class ComboMove {
    var id: UUID?
    var sequenceIndex: Int64 = 0  // Position in the combo sequence (0-based)
    var combo: Combo?             // Parent combo this belongs to
    var move: Move?               // The actual move at this position

    init(sequenceIndex: Int64 = 0) {
        self.id = UUID()
        self.sequenceIndex = sequenceIndex
    }
}

// MARK: - Review
// A single review event — records how the user rated a move during practice.
// This feeds the spaced-repetition system: "AGAIN" demotes, "GOOD" promotes.
@Model
final class Review {
    var id: UUID?
    var rating: String?       // "AGAIN", "HARD", or "GOOD"
    var reviewedAt: Date?     // When this review happened
    var move: Move?           // Which move was reviewed

    init(rating: String = "", reviewedAt: Date = Date()) {
        self.id = UUID()
        self.rating = rating
        self.reviewedAt = reviewedAt
    }
}

// MARK: - Video Resolution

extension Move {
    /// Resolves videoReference Data → file URL. Returns nil only if truly unresolvable.
    /// Logs all resolution attempts for diagnostics.
    func resolveVideoURL() -> URL? {
        guard let videoData = videoReference,
              let storedPath = String(data: videoData, encoding: .utf8) else {
            print("[VideoResolver] Move '\(name ?? "?")': videoReference is nil or not valid UTF-8")
            return nil
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        if storedPath.hasPrefix("/") {
            // Absolute path — try direct
            if FileManager.default.fileExists(atPath: storedPath) {
                return URL(fileURLWithPath: storedPath)
            }
            // Fallback: extract filename, look in Documents/Moves/
            let filename = (storedPath as NSString).lastPathComponent
            let rebuilt = documentsDir.appendingPathComponent("Moves/\(filename)")
            if FileManager.default.fileExists(atPath: rebuilt.path) {
                // Self-heal: update stored reference to the working relative path
                self.videoReference = "Moves/\(filename)".data(using: .utf8)
                print("[VideoResolver] Move '\(name ?? "?")': healed stale absolute path → Moves/\(filename)")
                return rebuilt
            }
            print("[VideoResolver] Move '\(name ?? "?")': file NOT FOUND at '\(storedPath)' or fallback")
            return nil
        }

        // Relative path (normal case)
        let resolved = documentsDir.appendingPathComponent(storedPath)
        if FileManager.default.fileExists(atPath: resolved.path) {
            return resolved
        }
        print("[VideoResolver] Move '\(name ?? "?")': file NOT FOUND at '\(resolved.path)'")
        return nil
    }
}

// MARK: - Preview Support
// Creates an in-memory SwiftData container with sample data for Xcode Previews.
// isStoredInMemoryOnly: true means data disappears when the preview closes —
// it never touches the real database.
//
// IMPORTANT: This is a stored property (static let), NOT a computed property.
// A computed property would create a new container on every access, causing
// preview crashes because seeded objects would belong to different containers.

extension ModelContainer {
    @MainActor
    static let preview: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Move.self, Combo.self, ComboMove.self, Review.self,
            configurations: config
        )

        let context = container.mainContext

        // Seed sample moves across all three learning states
        let windmill = Move(name: "Windmill", learningState: "NEW")
        let swipe = Move(name: "Swipe", learningState: "LEARNING")
        let halo = Move(name: "Halo", learningState: "MASTERY")
        context.insert(windmill)
        context.insert(swipe)
        context.insert(halo)

        // Seed a sample combo with two moves in sequence
        let combo = Combo(name: "Starter Combo")
        context.insert(combo)

        let cm1 = ComboMove(sequenceIndex: 0)
        cm1.combo = combo
        cm1.move = windmill
        context.insert(cm1)

        let cm2 = ComboMove(sequenceIndex: 1)
        cm2.combo = combo
        cm2.move = swipe
        context.insert(cm2)

        // Seed a sample review
        let review = Review(rating: "GOOD")
        review.move = windmill
        context.insert(review)

        return container
    }()

    /// Fetch a seeded preview Move by learning state.
    /// Seeded states: "NEW" (Windmill), "LEARNING" (Swipe), "MASTERY" (Halo)
    @MainActor
    static func previewMove(state: String) -> Move {
        let target = state
        let descriptor = FetchDescriptor<Move>(
            predicate: #Predicate<Move> { $0.learningState == target }
        )
        return try! preview.mainContext.fetch(descriptor).first!
    }

    /// Fetch the seeded preview Combo ("Starter Combo" with Windmill + Swipe)
    @MainActor
    static var previewCombo: Combo {
        let descriptor = FetchDescriptor<Combo>()
        return try! preview.mainContext.fetch(descriptor).first!
    }
}
