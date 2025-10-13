import CoreData
import AVFoundation
import Photos

// MARK: - Move Persistence Service
/// Essentialist implementation for move persistence operations
/// Provides core functionality for move saving and management
class MovePersistenceService {
    private let persistentContainer: NSPersistentContainer
    private let logger = Logger.addMove

    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    // MARK: - Core Methods

    /// Check if move with given name already exists
    func doesMoveExist(withName name: String) async throws -> Bool {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1

        let moves = try context.fetch(fetchRequest)
        return !moves.isEmpty
    }

    /// Save video to Photos library
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> String {
        // Essentialist implementation - generate a placeholder identifier
        // In a full implementation, this would save to the Photos library
        let identifier = UUID().uuidString
        logger.info("Generated placeholder photos identifier: \(identifier)")
        return identifier
    }

    /// Create Move entity in Core Data
    func createMoveEntity(
        name: String,
        originalPhotosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> Move {
        let context = persistentContainer.viewContext

        let move = Move(context: context)
        move.id = UUID()
        move.name = name
        move.photosIdentifier = originalPhotosIdentifier
        move.trimStartTime = trimStartTime ?? 0.0
        move.trimEndTime = trimEndTime ?? 0.0
        move.rotationQuarterTurns = Int16(rotationQuarterTurns)
        move.learningState = "NEW"
        move.createdAt = Date()

        try context.save()
        logger.info("Created move entity: \(name)")
        return move
    }
}