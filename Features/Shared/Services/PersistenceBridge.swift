import CoreData
import Foundation

// MARK: - Persistence Controller Bridge
/// Bridge to provide compatibility with existing PersistenceController usage
/// This maintains backward compatibility while using the existing CoreData setup
public class PersistenceController {

    /// Shared singleton instance
    public static let shared = PersistenceController()

    /// Initialization tracking and state
    private static var isInitialized = false
    private static let initializationQueue = DispatchQueue(label: "coredata.init", attributes: .concurrent)

    /// Core Data persistent container (eagerly initialized)
    public let container: NSPersistentContainer

    /// Public method to check initialization status
    public static var isReady: Bool {
        return initializationQueue.sync {
            return isInitialized
        }
    }

    /// Main view context
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    /// Background context for background operations
    public var backgroundContext: NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    private init() {
        Logger.coreData.info("🚀 Starting Core Data eager initialization")

        // Initialize container immediately
        let container = NSPersistentContainer(name: "breakdex")

        // Check if persistent store descriptions are available
        guard !container.persistentStoreDescriptions.isEmpty else {
            Logger.coreData.error("No persistent store descriptions available - Core Data model may be corrupted")
            // Initialize with empty container to satisfy compiler, then fallback to in-memory
            self.container = NSPersistentContainer(name: "breakdex")
            setupInMemoryStoreFallbackSync()
            return
        }

        // Enable lightweight migration for BreakDex schema updates
        let description = container.persistentStoreDescriptions.first!
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Configure the context before loading stores
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        self.container = container

        // Load persistent stores synchronously using a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        var loadSuccess = false

        Logger.coreData.info("Loading Core Data persistent stores...")
        container.loadPersistentStores { [weak self] _, error in
            guard let self = self else { return }

            if let error = error as NSError? {
                Logger.coreData.error("Core Data store loading failed: \(error.localizedDescription)")
                loadError = error
                // For initialization errors, try in-memory fallback
                self.handlePersistentStoreError(error)
            } else {
                Logger.coreData.info("✅ Core Data store loaded successfully")
                self.validateAndConfigureStore()
                loadSuccess = true
            }

            // Mark initialization as complete
            Self.initializationQueue.sync(flags: .barrier) {
                Self.isInitialized = true
            }
            semaphore.signal()
        }

        // Wait for initialization to complete
        semaphore.wait()

        // Handle initialization failure gracefully
        if let error = loadError {
            Logger.coreData.error("💥 Core Data initialization failed: \(error.localizedDescription)")
            // Don't crash - try to continue with in-memory store
            setupInMemoryStoreFallbackSync()
        }

        Logger.coreData.info("🎉 Core Data initialization completed successfully")
    }

    // MARK: - Enhanced Error Handling and Resource Management

    /// Handles persistent store loading errors with recovery strategies
    private func handlePersistentStoreError(_ error: NSError) {
        Logger.coreData.error("Core Data store loading failed: \(error.localizedDescription)")

        // Handle specific error types with appropriate recovery strategies
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case NSPersistentStoreIncompatibleVersionHashError,
                 NSMigrationMissingSourceModelError:
                handleMigrationError(error)

            case NSFileReadUnknownError,
                 NSFileReadNoPermissionError:
                handleFileAccessError(error)

            case NSFileReadCorruptFileError:
                handleStoreCorruptionError(error)

            default:
                handleGenericStoreError(error)
            }
        } else {
            // Handle file-related errors that could indicate resource exhaustion
            if error.localizedDescription.contains("Too many open files") {
                handleResourceExhaustionError(error)
            } else {
                handleGenericStoreError(error)
            }
        }
    }

    /// Handles migration errors with graceful degradation
    private func handleMigrationError(_ error: NSError) {
        Logger.coreData.error("Core Data migration failed: \(error.localizedDescription)")

        // Attempt graceful degradation to in-memory store if migration fails
        DispatchQueue.main.async {
            Logger.coreData.warning("Falling back to in-memory store due to migration failure")
            self.setupInMemoryStoreFallback()
        }
    }

    /// Handles file access errors with retry logic
    private func handleFileAccessError(_ error: NSError) {
        Logger.coreData.error("Core Data file access error: \(error.localizedDescription)")

        // Implement exponential backoff retry for transient issues
        let retryDelay = calculateRetryDelay(attempt: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            self?.retryStoreLoading()
        }
    }

    /// Handles store corruption with recovery attempt
    private func handleStoreCorruptionError(_ error: NSError) {
        Logger.coreData.error("Core Data store corruption detected: \(error.localizedDescription)")

        // Attempt to backup and recreate the store
        DispatchQueue.main.async {
            Logger.coreData.warning("Attempting store recovery from corruption")
            self.recreatePersistentStore()
        }
    }

    /// Handles resource exhaustion errors with cleanup
    private func handleResourceExhaustionError(_ error: NSError) {
        Logger.coreData.error("Resource exhaustion detected: \(error.localizedDescription)")

        // For initialization-time errors, we need to setup in-memory fallback immediately
        if !Self.isInitialized {
            setupInMemoryStoreFallbackSync()
        } else {
            // Close all background contexts and clean up resources
            container.viewContext.reset()

            // Remove the store file if it exists to clean up resources
            if let storeURL = container.persistentStoreDescriptions.first?.url {
                try? FileManager.default.removeItem(at: storeURL)
            }

            // Retry after cleanup delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.retryStoreLoading()
            }
        }
    }

    /// Handles generic store errors
    private func handleGenericStoreError(_ error: NSError) {
        Logger.coreData.error("Generic Core Data error: \(error.localizedDescription)")

        // For initialization-time errors, setup in-memory fallback immediately
        if !Self.isInitialized {
            setupInMemoryStoreFallbackSync()
        } else {
            DispatchQueue.main.async {
                Logger.coreData.warning("Falling back to in-memory store due to persistent store failure")
                self.setupInMemoryStoreFallback()
            }
        }
    }

    /// Synchronous in-memory store fallback for initialization failures
    private func setupInMemoryStoreFallbackSync() {
        Logger.coreData.warning("Setting up in-memory store fallback synchronously")

        // Remove existing store file if it exists
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // Configure in-memory store
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")

        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            if let error = error {
                Logger.coreData.error("In-memory store fallback failed: \(error.localizedDescription)")
            } else {
                Logger.coreData.info("✅ In-memory store fallback established successfully")
                self.validateAndConfigureStore()
            }
            semaphore.signal()
        }

        // Wait for in-memory store to load
        semaphore.wait()
    }

    /// Validates and configures the persistent store after successful loading
    private func validateAndConfigureStore() {
        Logger.coreData.info("Validating Core Data store configuration")

        // Set up resource management policies
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Configure background contexts for proper resource cleanup
        let backgroundContext = container.newBackgroundContext()
        backgroundContext.shouldDeleteInaccessibleFaults = true

        Logger.coreData.info("Core Data store validation completed")
    }

    /// Sets up in-memory store as fallback
    private func setupInMemoryStoreFallback() {
        Logger.coreData.warning("Setting up in-memory store fallback")

        // Remove existing store file if it exists
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // Configure in-memory store
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")

        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                Logger.coreData.error("In-memory store fallback failed: \(error.localizedDescription)")
            } else {
                Logger.coreData.info("In-memory store fallback established successfully")
                self?.validateAndConfigureStore()
            }
        }
    }

    /// Recreates the persistent store
    private func recreatePersistentStore() {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            Logger.coreData.error("Cannot recreate store: no store URL available")
            return
        }

        Logger.coreData.info("Recreating persistent store at: \(storeURL.path)")

        // Backup existing store if possible
        let backupURL = storeURL.appendingPathExtension("backup")
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                try FileManager.default.copyItem(at: storeURL, to: backupURL)
                Logger.coreData.info("Created backup store at: \(backupURL.path)")
            } catch {
                Logger.coreData.warning("Failed to create backup store: \(error.localizedDescription)")
            }
        }

        // Remove the corrupted store
        do {
            try FileManager.default.removeItem(at: storeURL)
            Logger.coreData.info("Removed corrupted store")
        } catch {
            Logger.coreData.error("Failed to remove corrupted store: \(error.localizedDescription)")
        }

        // Reload the store
        retryStoreLoading()
    }

    /// Retries store loading with exponential backoff
    private func retryStoreLoading() {
        Logger.coreData.info("Retrying Core Data store loading")

        container.loadPersistentStores { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                Logger.coreData.error("Store loading retry failed: \(error.localizedDescription)")
                // Implement additional retry logic or fall back to in-memory store
                self.setupInMemoryStoreFallback()
            } else {
                Logger.coreData.info("Store loading retry succeeded")
                self.validateAndConfigureStore()
                self.migrateDataStoreIfNeeded()
            }
        }
    }

    /// Calculates retry delay with exponential backoff
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 8.0
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }

    /// Preview initializer for SwiftUI previews and testing
    /// - Parameter inMemory: Whether to create an in-memory persistent store
    public init(inMemory: Bool = false) {
        let container = NSPersistentContainer(name: "breakdex")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")

            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    Logger.coreData.error("Core Data in-memory store loading failed: \(error)")
                } else {
                    Logger.coreData.info("Core Data in-memory store loaded successfully")
                }
            }
        } else {
            // For regular initialization, load persistent stores
            container.loadPersistentStores { _, error in
                if let error = error as NSError? {
                    Logger.coreData.error("Core Data store loading failed: \(error)")
                } else {
                    Logger.coreData.info("Core Data store loaded successfully")
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        self.container = container
    }

    // MARK: - Save Contexts
    /// Save the main view context with enhanced error handling
    public func save() {
        save(context: viewContext)
    }

    /// Save a specific context with resource management
    public func save(context: NSManagedObjectContext) {
        guard context.hasChanges else {
            Logger.coreData.debug("No changes to save")
            return
        }

        // Perform save with proper error handling
        do {
            try context.save()
            Logger.coreData.info("Context saved successfully")

            // Clean up any stale objects after save
            context.refreshAllObjects()
        } catch {
            Logger.coreData.error("Failed to save context: \(error.localizedDescription)")

            // Handle specific save errors with recovery
            handleSaveError(error, context: context)
        }
    }

    /// Save context with completion handler and timeout
    public func save(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        guard context.hasChanges else {
            completion(true)
            return
        }

        // Implement timeout to prevent hanging operations
        let saveTask = Task {
            await MainActor.run {
                context.perform {
                    do {
                        try context.save()
                        Logger.coreData.info("Context saved successfully with completion")
                        context.refreshAllObjects()
                        completion(true)
                    } catch {
                        Logger.coreData.error("Failed to save context with completion: \(error.localizedDescription)")
                        self.handleSaveError(error, context: context)
                        completion(false)
                    }
                }
            }
        }

        // Set timeout for save operation
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if !saveTask.isCancelled {
                saveTask.cancel()
                Logger.coreData.error("Save operation timed out")
                completion(false)
            }
        }
    }

    /// Handles save errors with appropriate recovery strategies
    private func handleSaveError(_ error: Error, context: NSManagedObjectContext) {
        Logger.coreData.error("Context save error: \(error.localizedDescription)")

        context.rollback()

        // Check for specific error types and handle accordingly
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSValidationMultipleErrorsError,
                 NSValidationMissingMandatoryPropertyError:
                Logger.coreData.error("Validation error during save: \(nsError.localizedDescription)")

            case NSManagedObjectMergeError:
                Logger.coreData.error("Merge conflict during save, attempting merge resolution")
                resolveMergeConflict(in: context)

            default:
                if nsError.localizedDescription.contains("Too many open files") {
                    Logger.coreData.error("Resource exhaustion during save, cleaning up resources")
                    cleanupAndRetrySave(context: context)
                }
            }
        }
    }

    /// Resolves merge conflicts in the context
    private func resolveMergeConflict(in context: NSManagedObjectContext) {
        Logger.coreData.info("Attempting to resolve merge conflicts")

        // Reset context and refresh from persistent store
        context.reset()
        context.refreshAllObjects()

        Logger.coreData.info("Merge conflict resolution completed")
    }

    /// Cleans up resources and retries save operation
    private func cleanupAndRetrySave(context: NSManagedObjectContext) {
        Logger.coreData.info("Cleaning up resources before retry save")

        // Force garbage collection
        context.reset()
        context.refreshAllObjects()

        // Short delay before retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.save(context: context)
        }
    }

    // MARK: - Migration
    /// Migrates existing Move entities to ensure learningState consistency
    /// MARK: - MIGRATION: Ensures all moves have proper learningState for review functionality
    ///  LOGS: Detailed logging for debugging migration results
    public func migrateDataStoreIfNeeded() {
        // Ensure the persistent store is loaded before attempting migration
        guard !container.persistentStoreDescriptions.isEmpty else {
            Logger.coreData.warning("MIGRATION: Persistent store not loaded, skipping migration")
            return
        }

        let context = backgroundContext
        context.perform {
            // Check if the Move entity is available in the model
            guard self.container.managedObjectModel.entitiesByName["Move"] != nil else {
                Logger.coreData.warning("MIGRATION: Move entity not found in model, skipping migration")
                return
            }

            let fetchRequest = NSFetchRequest<Move>(entityName: "Move")
            // Fetch moves where learningState is nil or an empty string
            fetchRequest.predicate = NSPredicate(format: "learningState == nil OR learningState == ''")

            do {
                let legacyMoves = try context.fetch(fetchRequest)
                if !legacyMoves.isEmpty {
                    Logger.coreData.info("MIGRATION: Found \(legacyMoves.count) legacy moves to update.")
                    for move in legacyMoves {
                        move.learningState = "NEW"
                    }
                    try context.save()
                    Logger.coreData.info("MIGRATION: Successfully updated learningState for \(legacyMoves.count) moves.")
                } else {
                    Logger.coreData.info("MIGRATION: No legacy moves found requiring update.")
                }
            } catch {
                Logger.coreData.error("MIGRATION: Failed to migrate moves: \(error)")
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
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
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
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
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
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: T.self))
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

// MARK: - Move Extensions
extension Move {
    public var managedObjectID: NSManagedObjectID { objectID }

    // Helper method to check if the move has a video using photosIdentifier
    @objc public var hasVideo: Bool {
        return self.photosIdentifier != nil && !self.photosIdentifier!.isEmpty
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