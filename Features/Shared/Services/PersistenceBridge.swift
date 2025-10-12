import CoreData
import Foundation

// MARK: - Persistence Controller Bridge
/// Bridge to provide compatibility with existing PersistenceController usage
/// This maintains backward compatibility while using the existing CoreData setup
public class PersistenceController {

    /// Shared singleton instance
    public static let shared = PersistenceController()

    /// Core Data persistent container
    public lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "breakdex")

        // Load the persistent stores
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Logger.coreData.error("Core Data store loading failed: \(error)")
                // fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                // Logger.coreData.info("Core Data store loaded successfully")
            }
        }

        // Configure the context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    /// Main view context
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    /// Background context for background operations
    public var backgroundContext: NSManagedObjectContext {
        return container.newBackgroundContext()
    }

    private init() {}

    /// Preview initializer for SwiftUI previews and testing
    /// - Parameter inMemory: Whether to create an in-memory persistent store
    public init(inMemory: Bool = false) {
        if inMemory {
            container = NSPersistentContainer(name: "breakdex")
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")

            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    Logger.coreData.error("Core Data in-memory store loading failed: \(error)")
                } else {
                    Logger.coreData.info("Core Data in-memory store loaded successfully")
                }
            }

            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }

    // MARK: - Save Contexts
    /// Save the main view context
    public func save() {
        save(context: viewContext)
    }

    /// Save a specific context
    public func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
            Logger.coreData.info("Context saved successfully")
        } catch {
            Logger.coreData.error("Failed to save context: \(error)")
            context.rollback()
        }
    }

    /// Save context with completion handler
    public func save(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        guard context.hasChanges else {
            completion(true)
            return
        }

        context.perform {
            do {
                try context.save()
                Logger.coreData.info("Context saved successfully with completion")
                completion(true)
            } catch {
                Logger.coreData.error("Failed to save context: \(error)")
                context.rollback()
                completion(false)
            }
        }
    }

    // MARK: - Migration
    /// Migrates existing Move entities to ensure learningState consistency
    /// MARK: - MIGRATION: Ensures all moves have proper learningState for review functionality
    public func migrateDataStoreIfNeeded() {
        let context = backgroundContext
        context.perform {
            let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
            // Fetch moves where learningState is nil or an empty string
            fetchRequest.predicate = NSPredicate(format: "learningState == nil OR learningState == ''")

            do {
                let legacyMoves = try context.fetch(fetchRequest)
                if !legacyMoves.isEmpty {
                    // Logger.coreData.info("MIGRATION: Found \(legacyMoves.count) legacy moves to update.")
                    for move in legacyMoves {
                        move.learningState = "NEW"
                    }
                    try context.save()
                    // Logger.coreData.info("MIGRATION: Successfully updated learningState for \(legacyMoves.count) moves.")
                } else {
                    // Logger.coreData.info("MIGRATION: No legacy moves found requiring update.")
                }
            } catch {
                // Logger.coreData.error("MIGRATION: Failed to migrate moves: \(error)")
            }
        }
    }

    // MARK: - Background Operations
    /// Perform operation on background context
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = container.newBackgroundContext()
        context.perform {
            block(context)
        }
    }

    /// Perform background task with save
    public func performBackgroundTask<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let context = container.newBackgroundContext()
            context.perform {
                do {
                    let result = try block(context)
                    try context.save()
                    continuation.resume(returning: result)
                } catch {
                    context.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Persistence Controller Extensions
public extension PersistenceController {

    /// Fetch all entities of a given type
    func fetchAll<T: NSManagedObject>(
        _ type: T.Type,
        sortDescriptors: [NSSortDescriptor] = [],
        predicate: NSPredicate? = nil
    ) -> [T] {
        // Use the auto-generated fetch request method from the Core Data entity
        let request = T.fetchRequest() as! NSFetchRequest<T>
        request.sortDescriptors = sortDescriptors
        request.predicate = predicate

        do {
            return try viewContext.fetch(request)
        } catch {
            Logger.coreData.error("Failed to fetch \(type): \(error)")
            return []
        }
    }

    /// Count entities of a given type
    func count<T: NSManagedObject>(
        _ type: T.Type,
        predicate: NSPredicate? = nil
    ) -> Int {
        // Use the auto-generated fetch request method from the Core Data entity
        let request = T.fetchRequest() as! NSFetchRequest<T>
        request.predicate = predicate

        do {
            return try viewContext.count(for: request)
        } catch {
            Logger.coreData.error("Failed to count \(type): \(error)")
            return 0
        }
    }

    /// Delete entity
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        Logger.coreData.info("Deleted object: \(type(of: object))")
    }

    /// Delete all entities of a given type
    func deleteAll<T: NSManagedObject>(_ type: T.Type) {
        // Use the auto-generated fetch request method from the Core Data entity
        let request = T.fetchRequest() as! NSFetchRequest<NSFetchRequestResult>
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            Logger.coreData.info("Deleted all \(type) objects")
        } catch {
            Logger.coreData.error("Failed to delete all \(type): \(error)")
        }
    }
}

// MARK: - Preview Support
extension PersistenceController {
    /// Create preview persistence controller for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Add sample data for previews if needed
        // This can be expanded with test data later

        return controller
    }()
}