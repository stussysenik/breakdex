//
//  Persistence.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Add sample data for previews here if needed
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BreakingFlashcards")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable lightweight migration for BreakDex schema updates
        let description = container.persistentStoreDescriptions.first!
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle migration errors gracefully
                if error.domain == NSCocoaErrorDomain,
                   error.code == NSPersistentStoreIncompatibleVersionHashError ||
                    error.code == NSMigrationMissingSourceModelError {
                    
                    print("⚠️ Core Data migration required. Error: \(error.localizedDescription)")
                    
                    // In a production app, you might want to:
                    // 1. Show user a migration progress indicator
                    // 2. Handle migration failures more gracefully
                    // 3. Provide fallback options
                    
                    fatalError("Core Data migration failed: \(error), \(error.userInfo)")
                } else {
                    fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
                }
            } else {
                print("✅ Core Data store loaded successfully")
                if description.shouldMigrateStoreAutomatically {
                    print("✅ Lightweight migration enabled and ready")
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
