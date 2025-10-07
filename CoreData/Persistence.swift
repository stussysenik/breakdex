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
        container = NSPersistentContainer(name: "breakdex")
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

// MARK: - Move Extensions
extension Move {
    public var managedObjectID: NSManagedObjectID { objectID }

    // Helper method to check if the move has a video using photosIdentifier
    @objc public var hasVideo: Bool {
        return photosIdentifier != nil && !photosIdentifier!.isEmpty
    }

    // Method to update the last accessed date for the video
    @objc public func updateVideoLastAccessedDate() {
        // This method would update a lastAccessedDate property if it existed
        // For now, it's a placeholder for future functionality
    }
}

// MARK: - Data Migration
extension PersistenceController {
    /// Migrates existing Move entities to ensure learningState consistency
    /// 🎯 MIGRATION: Ensures all moves have proper learningState for review functionality
    /// 📊 LOGS: Detailed logging for debugging migration results
    func migrateDataStoreIfNeeded() {
        backgroundContext.perform {
            let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
            // Fetch moves where learningState is nil or an empty string
            fetchRequest.predicate = NSPredicate(format: "learningState == nil OR learningState == ''")

            do {
                let legacyMoves = try self.backgroundContext.fetch(fetchRequest)
                if !legacyMoves.isEmpty {
                    print("✅ MIGRATION: Found \(legacyMoves.count) legacy moves to update.")
                    for move in legacyMoves {
                        move.learningState = "NEW"
                    }
                    try self.backgroundContext.save()
                    print("✅ MIGRATION: Successfully updated learningState for \(legacyMoves.count) moves.")
                } else {
                    print("✅ MIGRATION: No legacy moves found requiring update.")
                }
            } catch {
                print("❌ MIGRATION: Failed to migrate moves: \(error)")
            }
        }
    }

    /// Background context for Core Data operations
    private var backgroundContext: NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}

// MARK: - Hashable Conformance
extension Move {
    public static func == (lhs: Move, rhs: Move) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
