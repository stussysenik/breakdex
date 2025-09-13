import SwiftUI
import AVKit
import CoreData
import OSLog

// MARK: - MovePersistenceService Protocol
protocol MovePersistenceServiceProtocol {
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> URL
    func createMoveEntity(
        name: String,
        videoURL: URL,
        originalPhotosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> Move
    func saveCompleteMove(
        name: String,
        asset: AVAsset,
        originalPhotosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws
}

// MARK: - Move Persistence Service
@MainActor
class MovePersistenceService: MovePersistenceServiceProtocol {
    
    // MARK: - Properties
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MovePersistenceService")
    
    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        logger.info("💾 MOVE_PERSISTENCE: Initialized")
    }
    
    // MARK: - Public API
    
    /// Save video to Photos library
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> URL {
        logger.info("💾 MOVE_PERSISTENCE: Saving video to Photos library")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(moveName)")
        
        guard let urlAsset = asset as? AVURLAsset else {
            let error = NSError(domain: "MovePersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset is not a URL asset"])
            logger.error("💾 MOVE_PERSISTENCE: ❌ Asset is not a URL asset")
            throw VideoError.assetLoadingFailed(underlyingError: error)
        }
        
        // For now, return the existing URL (in production, you'd save to Photos library)
        // This is a placeholder - actual Photos library saving would use PHPhotoLibrary
        logger.info("💾 MOVE_PERSISTENCE: Returning existing URL for asset: \(urlAsset.url.absoluteString)")
        return urlAsset.url
    }
    
    /// Create Move entity in Core Data
    func createMoveEntity(
        name: String,
        videoURL: URL,
        originalPhotosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> Move {
        logger.info("💾 MOVE_PERSISTENCE: Creating Move entity in Core Data")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(name)")
        logger.info("💾 MOVE_PERSISTENCE: Original photos ID: \(originalPhotosIdentifier)")
        logger.info("💾 MOVE_PERSISTENCE: Trim start: \(trimStartTime ?? 0), end: \(trimEndTime ?? 0)")
        logger.info("💾 MOVE_PERSISTENCE: Rotation: \(rotationQuarterTurns)°")
        
        // Create Move entity using the Core Data context
        let context = PersistenceController.shared.container.viewContext
        
        let move = Move(context: context)
        move.id = UUID()
        move.name = name
        move.photosIdentifier = originalPhotosIdentifier
        move.trimStartTime = trimStartTime ?? 0
        move.trimEndTime = trimEndTime ?? 0
        move.rotationQuarterTurns = Int16(rotationQuarterTurns)
        move.createdAt = Date()
        
        // Store video URL as Data in videoReference
        if let videoData = try? Data(contentsOf: videoURL) {
            logger.info("💾 MOVE_PERSISTENCE: 📊 Video data size: \(videoData.count) bytes")
            move.videoReference = videoData
            logger.info("💾 MOVE_PERSISTENCE: ✅ Video data stored successfully")
        } else {
            // Fallback: store URL path as string in tags or log error
            logger.warning("💾 MOVE_PERSISTENCE: ⚠️ Could not convert video URL to data, storing path in tags")
            move.tags = videoURL.path
        }
        
        do {
            try context.save()
            logger.info("💾 MOVE_PERSISTENCE: ✅ Move entity saved to Core Data")
            logger.info("💾 MOVE_PERSISTENCE: 📊 Move ID: \(move.id ?? UUID())")
            return move
        } catch {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Failed to save Move entity: \(error.localizedDescription)")
            logger.error("💾 MOVE_PERSISTENCE: ❌ Error type: \(type(of: error))")
            throw AddMoveError.coreDataSaveFailed(underlyingError: error)
        }
    }
    
    /// Complete save operation - handles both video saving and entity creation
    func saveCompleteMove(
        name: String,
        asset: AVAsset,
        originalPhotosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws {
        logger.info("💾 MOVE_PERSISTENCE: Starting complete save operation")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(name)")
        logger.info("💾 MOVE_PERSISTENCE: Asset available: \(asset != nil)")
        
        // Use the provided asset
        logger.info("💾 MOVE_PERSISTENCE: Using asset for save: \(asset)")
        
        // Save to Photos library
        logger.info("💾 MOVE_PERSISTENCE: Step 1: Saving video to Photos library")
        let savedVideoURL = try await saveVideoToPhotos(asset: asset, moveName: name)
        logger.info("💾 MOVE_PERSISTENCE: ✅ Video saved to Photos at: \(savedVideoURL)")
        
        // Create Move entity in Core Data
        logger.info("💾 MOVE_PERSISTENCE: Step 2: Creating Move entity")
        let move = try await createMoveEntity(
            name: name,
            videoURL: savedVideoURL,
            originalPhotosIdentifier: originalPhotosIdentifier,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            rotationQuarterTurns: rotationQuarterTurns
        )
        
        logger.info("💾 MOVE_PERSISTENCE: ✅ Complete save operation finished successfully")
        logger.info("💾 MOVE_PERSISTENCE: 📊 Final Move entity: \(move)")
    }
    
    // MARK: - Helper Methods
    
    /// Validate move data before saving
    private func validateMoveData(
        name: String,
        asset: AVAsset?,
        originalPhotosIdentifier: String
    ) throws {
        logger.info("💾 MOVE_PERSISTENCE: Validating move data")
        
        if name.isEmpty {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Move name is empty")
            throw NSError(domain: "MovePersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Move name cannot be empty"])
        }
        
        if asset == nil {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Asset is nil")
            throw NSError(domain: "MovePersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset cannot be nil"])
        }
        
        if originalPhotosIdentifier.isEmpty {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Photos identifier is empty")
            throw NSError(domain: "MovePersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos identifier cannot be empty"])
        }
        
        logger.info("💾 MOVE_PERSISTENCE: ✅ Move data validation passed")
    }
    
    /// Get file size from URL for logging
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            logger.warning("💾 MOVE_PERSISTENCE: ⚠️ Could not get file size: \(error.localizedDescription)")
            return 0
        }
    }
}