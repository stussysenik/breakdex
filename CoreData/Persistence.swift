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

// MARK: - Move Extensions
extension Move {
    public var managedObjectID: NSManagedObjectID { objectID }

    // Computed property to get the video URL from videoReference
    @objc public var videoURL: URL? {
        get {
            guard let videoData = videoReference,
                  let path = String(data: videoData, encoding: .utf8),
                  !path.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        set {
            if let url = newValue {
                videoReference = Data(url.path.utf8)
            } else {
                videoReference = nil
            }
        }
    }

    // Helper method to check if the move has a video
    @objc public var hasVideo: Bool {
        return videoURL != nil
    }

    // Helper method to check if the video file exists
    @objc public var videoFileExists: Bool {
        guard let url = videoURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // Method to update the last accessed date for the video
    @objc public func updateVideoLastAccessedDate() {
        // This method would update a lastAccessedDate property if it existed
        // For now, it's a placeholder for future functionality
    }
}

// MARK: - Hashable Conformance
extension Move {
    public static func == (lhs: Move, rhs: Move) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
