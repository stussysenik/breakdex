import SwiftUI
import AVKit
import CoreData
import OSLog

// MARK: - MovePersistenceService Protocol
public protocol MovePersistenceServiceProtocol {
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> String // ✅ FIXED: Returns localIdentifier
    func createMoveEntity(
        name: String,
        originalPhotosIdentifier: String, // ✅ FIXED: This is the single source of truth
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
    private let videoSaver: VideoSaver
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MovePersistenceService")

    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext, videoSaver: VideoSaver) {
        self.viewContext = viewContext
        self.videoSaver = videoSaver
        logger.info("💾 MOVE_PERSISTENCE: Initialized")
    }
    
    // MARK: - Public API
    
    /// Save video to Photos library
    /// 🎯 FIXED: Now returns the Photos library localIdentifier
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> String {
        logger.info("💾 MOVE_PERSISTENCE: Saving video to Photos library")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(moveName)")

        // ✅ USE: VideoSaver to save to Photos library and get the localIdentifier
        let localIdentifier = try await videoSaver.saveToPhotosLibrary(asset)

        logger.info("💾 MOVE_PERSISTENCE: ✅ Video saved to Photos library with identifier: \(localIdentifier), move name: \(moveName)")

        return localIdentifier
    }
    
    /// Create Move entity in Core Data
    /// 🎯 FIXED: Removed videoURL parameter, uses photosIdentifier as single source of truth
    func createMoveEntity(
        name: String,
        originalPhotosIdentifier: String, // This is the single source of truth for the video
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
        
        // 🎯 FIXED: Removed binary video storage from Core Data - architectural violation
        // 🗑️ REMOVED: Storing entire video files as binary Data in Core Data causes performance issues
        // if let videoData = try? Data(contentsOf: videoURL) {
        //     logger.info("💾 MOVE_PERSISTENCE: 📊 Video data size: \(videoData.count) bytes")
        //     move.videoReference = videoData
        //     logger.info("💾 MOVE_PERSISTENCE: ✅ Video data stored successfully")
        // } else {
        //     // Fallback: store URL path as string in tags or log error
        //     logger.warning("💾 MOVE_PERSISTENCE: ⚠️ Could not convert video URL to data, storing path in tags")
        //     move.tags = videoURL.path
        // }

        // ✅ CORRECT: Only store the Photos identifier - video is saved in Photos library
        // The photosIdentifier field already contains the reference to the video in Photos
        logger.info("💾 MOVE_PERSISTENCE: ✅ Using Photos-only storage architecture")
        logger.info("💾 MOVE_PERSISTENCE: Photos identifier: \(originalPhotosIdentifier)")
        logger.info("💾 MOVE_PERSISTENCE: Binary storage removed, using photos library reference approach")
        
        do {
            try context.save()
            logger.info("💾 MOVE_PERSISTENCE: ✅ Move entity saved to Core Data")
            logger.info("💾 MOVE_PERSISTENCE: 📊 Move ID: \(move.id ?? UUID())")
            return move
        } catch {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Failed to save Move entity: \(error.localizedDescription)")
            logger.error("💾 MOVE_PERSISTENCE: ❌ Error type: \(type(of: error))")
            throw NSError(domain: "MovePersistenceService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to save move to Core Data", NSUnderlyingErrorKey: error])
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
        logger.info("💾 MOVE_PERSISTENCE: Asset available: \(true)")

        // Use the provided asset
        logger.info("💾 MOVE_PERSISTENCE: Using asset for save: \(asset)")

        // Step 1: Save to Photos library and get the new localIdentifier
        logger.info("💾 MOVE_PERSISTENCE: Step 1: Saving video to Photos library")
        let finalPhotosIdentifier = try await saveVideoToPhotos(asset: asset, moveName: name)
        logger.info("💾 MOVE_PERSISTENCE: ✅ Video saved to Photos with identifier: \(finalPhotosIdentifier)")

        // Step 2: Create Move entity in Core Data using the NEW identifier
        logger.info("💾 MOVE_PERSISTENCE: Step 2: Creating Move entity with new Photos identifier")
        let move = try await createMoveEntity(
            name: name,
            originalPhotosIdentifier: finalPhotosIdentifier, // ✅ USE: The new identifier from Photos library
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