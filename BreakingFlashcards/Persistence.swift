//
//  Persistence.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import CoreData

struct PersistenceController {
    // This is a singleton, ensuring we only have one database controller for the entire app.
    static let shared = PersistenceController()
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let moveStates = ["NEW", "LEARNING", "MASTERY"]
        let moveNames = ["Windmill", "Swipe", "Halo"]
        var moves: [Move] = []

        for index in 0..<moveNames.count {
            let move = Move(context: context)
            move.id = UUID()
            move.name = moveNames[index]
            move.learningState = moveStates[index]
            move.createdAt = Date().addingTimeInterval(TimeInterval(-index * 3600))
            moves.append(move)
        }

        let combo = Combo(context: context)
        combo.id = UUID()
        combo.name = "Starter Combo"

        for (index, move) in moves.prefix(2).enumerated() {
            let comboMove = ComboMove(context: context)
            comboMove.id = UUID()
            comboMove.sequenceIndex = Int64(index)
            comboMove.combo = combo
            comboMove.move = move
        }

        let review = Review(context: context)
        review.id = UUID()
        review.rating = "GOOD"
        review.reviewedAt = Date()
        review.move = moves.first

        try? context.save()

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BreakingFlashcards")
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // This is where you would add real error handling in a production app.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
