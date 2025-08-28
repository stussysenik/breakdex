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

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "BreakingFlashcards")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // This is where you would add real error handling in a production app.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
