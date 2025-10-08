import SwiftUI
import AVKit
import CoreData
import Photos
import OSLog

// MARK: - MovePersistenceService Protocol
public protocol MovePersistenceServiceProtocol {
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> String // ✅ FIXED: Returns localIdentifier
    func deleteVideoFromPhotos(localIdentifier: String) async throws // ✅ ADDED: For rollback operations
    func doesMoveExist(withName name: String) async throws -> Bool // MARK: - FIXED: Added missing method for duplicate validation
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
    func cleanupOrphanedMoveEntity(name: String) async throws // MARK: - ADDED: For rollback operations
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
    /// MARK: - FIXED: Now returns the Photos library localIdentifier
    func saveVideoToPhotos(asset: AVAsset, moveName: String) async throws -> String {
        logger.info("💾 MOVE_PERSISTENCE: Saving video to Photos library")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(moveName)")

        // ✅ USE: VideoSaver to save to Photos library and get the localIdentifier
        let localIdentifier = try await videoSaver.saveToPhotosLibrary(asset)

        logger.info("💾 MOVE_PERSISTENCE: ✅ Video saved to Photos library with identifier: \(localIdentifier), move name: \(moveName)")

        return localIdentifier
    }
    
    /// Create Move entity in Core Data
    /// MARK: - FIXED: Removed videoURL parameter, uses photosIdentifier as single source of truth
    func createMoveEntity(
        name: String,
        originalPhotosIdentifier: String, // This is the single source of truth for the video
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> Move {
        let operationStartTime = Date()
        logger.info("💾 MOVE_PERSISTENCE: 🚀 Creating Move entity in Core Data [context:\(Thread.isMainThread ? "main" : "background")]")
        logger.info("💾 MOVE_PERSISTENCE: Move name: \(name)")
        logger.info("💾 MOVE_PERSISTENCE: Original photos ID: \(originalPhotosIdentifier)")
        logger.info("💾 MOVE_PERSISTENCE: Trim start: \(trimStartTime ?? 0), end: \(trimEndTime ?? 0)")
        logger.info("💾 MOVE_PERSISTENCE: Rotation: \(rotationQuarterTurns)°")

        // Categorical analysis: Log thread safety and concurrency context
        let threadContext = Thread.isMainThread ? "main_actor" : "background_thread"
        let memoryInfo = ProcessInfo.processInfo
        logger.info("💾 MOVE_PERSISTENCE: 🧮 Thread context: \(threadContext), Memory: \(memoryInfo.physicalMemory / (1024*1024*1024))GB")

        // ✨ VALIDATION: Check for duplicate move names before creating entity
        logger.info("💾 MOVE_PERSISTENCE: 🔍 Validating move name uniqueness")
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name) // Case-insensitive comparison

        let existingMoves = try context.fetch(fetchRequest)
        if !existingMoves.isEmpty {
            logger.error("💾 MOVE_PERSISTENCE: ❌ A move named '\(name)' already exists (\(existingMoves.count) duplicates found)")
            logger.error("💾 MOVE_PERSISTENCE: ❌ Duplicate move IDs: \(existingMoves.map { $0.id ?? UUID() })")
            throw AddMoveError.duplicateMoveName
        }

        logger.info("💾 MOVE_PERSISTENCE: ✅ Move name uniqueness validated - no duplicates found")

        // Create Move entity using the existing Core Data context
        
        let move = Move(context: context)
        move.id = UUID()
        move.name = name
        move.photosIdentifier = originalPhotosIdentifier
        move.trimStartTime = trimStartTime ?? 0
        move.trimEndTime = trimEndTime ?? 0
        move.rotationQuarterTurns = Int16(rotationQuarterTurns)
        move.createdAt = Date()
        move.learningState = "NEW" // ✅ FIX: Set default learning state to ensure moves appear in review
        logger.info("💾 MOVE_PERSISTENCE: ✅ Set default learning state: NEW")
        
        // MARK: - FIXED: Removed binary video storage from Core Data - architectural violation
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
            let saveStartTime = Date()
            try context.save()
            let saveDuration = Date().timeIntervalSince(saveStartTime)

            logger.info("💾 MOVE_PERSISTENCE: ✅ Move entity saved to Core Data [duration:\(String(format: "%.2f", saveDuration))s]")
            logger.info("💾 MOVE_PERSISTENCE: 📊 Move ID: \(move.id ?? UUID())")
            logger.info("💾 MOVE_PERSISTENCE: 📊 Total operation duration: \(String(format: "%.2f", Date().timeIntervalSince(operationStartTime)))s")

            // Categorical analysis: Log success metrics
            logger.info("💾 MOVE_PERSISTENCE: 🧮 Save operation metrics - duration: \(Int(Date().timeIntervalSince(operationStartTime) * 1000))ms, context: \(threadContext), name: \(name)")

            return move
        } catch {
            let errorDuration = Date().timeIntervalSince(operationStartTime)
            logger.error("💾 MOVE_PERSISTENCE: ❌ Failed to save Move entity: \(error.localizedDescription)")
            logger.error("💾 MOVE_PERSISTENCE: ❌ Error type: \(type(of: error))")
            logger.error("💾 MOVE_PERSISTENCE: ❌ Failed after \(String(format: "%.2f", errorDuration))s")

            // Categorical analysis: Log failure metrics
            logger.error("💾 MOVE_PERSISTENCE: 🧮 Save failure metrics - duration: \(Int(errorDuration * 1000))ms, context: \(threadContext), error: \((error as NSError).domain):\((error as NSError).code), name: \(name)")

            throw NSError(domain: "MovePersistenceService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Failed to save move to Core Data",
                NSUnderlyingErrorKey: error,
                "OperationDuration": errorDuration,
                "ThreadContext": threadContext
            ])
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

    /// Delete video from Photos library (for rollback operations)
    func deleteVideoFromPhotos(localIdentifier: String) async throws {
        logger.info("💾 MOVE_PERSISTENCE: Deleting video from Photos library: \(localIdentifier.prefix(20))...")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.warning("💾 MOVE_PERSISTENCE: ⚠️ Asset not found for deletion: \(localIdentifier.prefix(20))...")
            return // Asset doesn't exist, consider deletion successful
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }

        logger.info("💾 MOVE_PERSISTENCE: ✅ Video deleted from Photos library successfully")
    }

    /// Check if a move with the given name already exists (fail-fast validation)
    /// MARK: - NEW: Lightweight validation function for early duplicate detection
    func doesMoveExist(withName name: String) async throws -> Bool {
        logger.info("💾 MOVE_PERSISTENCE: 🔍 Validating move name uniqueness for: '\(name)'")

        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name) // Case-insensitive check
        fetchRequest.fetchLimit = 1 // We only need to know if at least one exists

        let count = try await PersistenceController.shared.container.viewContext.perform {
            try self.viewContext.count(for: fetchRequest)
        }

        let exists = count > 0
        logger.info("💾 MOVE_PERSISTENCE: 🎯 Name validation result: '\(name)' exists: \(exists)")

        // ✨ ENHANCED: Log detailed information when duplicate is found
        if exists {
            logger.warning("💾 MOVE_PERSISTENCE: ⚠️ DUPLICATE DETECTION: Move name '\(name)' already exists in database")
            logger.info("💾 MOVE_PERSISTENCE: 📊 Duplicate detection details: name=\(name), method=doesMoveExist, case_insensitive=true")
        }

        return exists
    }

    /// Clean up orphaned Move entity (for rollback operations)
    func cleanupOrphanedMoveEntity(name: String) async throws {
        logger.info("💾 MOVE_PERSISTENCE: 🔄 Cleaning up potential orphaned Move entity: \(name)")

        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let orphanedMove = results.first {
                logger.info("💾 MOVE_PERSISTENCE: 🗑️ Found orphaned Move entity, deleting: \(orphanedMove.name ?? "unnamed")")
                viewContext.delete(orphanedMove)
                try viewContext.save()
                logger.info("💾 MOVE_PERSISTENCE: ✅ Orphaned Move entity deleted successfully")
            } else {
                logger.info("💾 MOVE_PERSISTENCE: ℹ️ No orphaned Move entity found for cleanup: \(name)")
            }
        } catch {
            logger.error("💾 MOVE_PERSISTENCE: ❌ Failed to cleanup orphaned Move entity: \(error.localizedDescription)")
            throw error
        }
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