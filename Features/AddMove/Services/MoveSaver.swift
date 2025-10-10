import AVFoundation
import CoreData
import OSLog

// MARK: - MoveSaver
/// Clean service for saving moves to Core Data and Photos library
@MainActor
class MoveSaver: ObservableObject {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MoveSaver")
    private let persistentContainer: NSPersistentContainer
    private let movePersistenceService: MovePersistenceService

    // MARK: - Published Properties
    @Published private(set) var isSaving = false
    @Published private(set) var progress = 0.0
    @Published private(set) var statusMessage = ""

    init(
        persistentContainer: NSPersistentContainer,
        movePersistenceService: MovePersistenceService
    ) {
        self.persistentContainer = persistentContainer
        self.movePersistenceService = movePersistenceService
    }

    // MARK: - Saving Methods

    /// Save move with video asset
    /// - Parameters:
    ///   - name: Move name
    ///   - asset: Video asset
    ///   - trimStartTime: Optional trim start time in seconds
    ///   - trimEndTime: Optional trim end time in seconds
    ///   - rotationQuarterTurns: Optional rotation (0, 1, 2, 3)
    /// - Returns: Saved Move entity
    /// - Throws: MoveSaverError if saving fails
    func saveMove(
        name: String,
        asset: AVAsset,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        rotationQuarterTurns: Int = 0
    ) async throws -> Move {
        logger.info("💾 Starting save operation for move: '\(name)'")

        await MainActor.run {
            isSaving = true
            progress = 0.0
            statusMessage = "Preparing to save move..."
        }

        // Validate input
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw MoveSaverError.invalidName
        }

        guard cleanName.count >= 3 else {
            throw MoveSaverError.nameTooShort
        }

        await updateProgress(0.1, status: "Validating move data...")

        // Check for duplicate names
        let duplicateExists = try await movePersistenceService.doesMoveExist(withName: cleanName)
        if duplicateExists {
            throw MoveSaverError.duplicateName
        }

        await updateProgress(0.2, status: "Saving video to Photos...")

        do {
            // Step 1: Save video to Photos library
            let photosIdentifier = try await movePersistenceService.saveVideoToPhotos(
                asset: asset,
                moveName: cleanName
            )

            await updateProgress(0.6, status: "Creating move entry...")

            // Step 2: Create Move entity in Core Data
            let move = try await movePersistenceService.createMoveEntity(
                name: cleanName,
                originalPhotosIdentifier: photosIdentifier,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime,
                rotationQuarterTurns: rotationQuarterTurns
            )

            await updateProgress(0.9, status: "Finalizing save...")

            // Step 3: Verify the move was saved
            let savedMove = try await verifyMoveExists(name: cleanName)

            await updateProgress(1.0, status: "Move saved successfully")

            logger.info("✅ Move saved successfully: '\(cleanName)'")
            return savedMove

        } catch {
            await MainActor.run {
                isSaving = false
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
            logger.error("❌ Move save failed: \(error.localizedDescription)")
            throw MoveSaverError.saveFailed(underlying: error)
        }
    }

    /// Save simple move without trimming
    /// - Parameters:
    ///   - name: Move name
    ///   - asset: Video asset
    /// - Returns: Saved Move entity
    /// - Throws: MoveSaverError if saving fails
    func saveSimpleMove(name: String, asset: AVAsset) async throws -> Move {
        return try await saveMove(
            name: name,
            asset: asset,
            trimStartTime: nil,
            trimEndTime: nil,
            rotationQuarterTurns: 0
        )
    }

    /// Save trimmed move
    /// - Parameters:
    ///   - name: Move name
    ///   - asset: Trimmed video asset
    ///   - startTime: Original trim start time
    ///   - endTime: Original trim end time
    ///   - rotationQuarterTurns: Applied rotation
    /// - Returns: Saved Move entity
    /// - Throws: MoveSaverError if saving fails
    func saveTrimmedMove(
        name: String,
        asset: AVAsset,
        startTime: Double,
        endTime: Double,
        rotationQuarterTurns: Int = 0
    ) async throws -> Move {
        return try await saveMove(
            name: name,
            asset: asset,
            trimStartTime: startTime,
            trimEndTime: endTime,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }

    // MARK: - Private Methods

    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            self.progress = progress
            self.statusMessage = status

            if progress >= 1.0 {
                isSaving = false
            }
        }
    }

    private func verifyMoveExists(name: String) async throws -> Move {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1

        let moves = try context.fetch(fetchRequest)
        guard let move = moves.first else {
            throw MoveSaverError.moveNotFoundAfterSave
        }
        return move
    }
}

// MARK: - MoveSaverError

enum MoveSaverError: LocalizedError {
    case invalidName
    case nameTooShort
    case duplicateName
    case saveFailed(underlying: Error)
    case moveNotFoundAfterSave

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Move name cannot be empty"
        case .nameTooShort:
            return "Move name must be at least 3 characters long"
        case .duplicateName:
            return "A move with this name already exists"
        case .saveFailed(let error):
            return "Failed to save move: \(error.localizedDescription)"
        case .moveNotFoundAfterSave:
            return "Move was not found after saving"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidName:
            return "Please enter a valid move name"
        case .nameTooShort:
            return "Please use at least 3 characters for the move name"
        case .duplicateName:
            return "Please choose a different name for your move"
        case .saveFailed:
            return "Please try again or check your available storage"
        case .moveNotFoundAfterSave:
            return "Please try saving the move again"
        }
    }
}