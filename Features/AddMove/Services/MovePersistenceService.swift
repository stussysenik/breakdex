import CoreData
import AVFoundation
import OSLog

// MARK: - Move Persistence Errors
enum MovePersistenceError: LocalizedError {
    case photosAccessDenied
    case videoExportFailed(String)
    case photosLibrarySaveFailed(String)
    case temporaryFileCreationFailed
    case invalidTrimRange
    case assetLoadingFailed(String)
    case exportCancelled
    case insufficientStorage

    var errorDescription: String? {
        switch self {
        case .photosAccessDenied:
            return "Photos library access is required to save videos. Please grant permission in Settings."
        case .videoExportFailed(let reason):
            return "Failed to export video: \(reason)"
        case .photosLibrarySaveFailed(let reason):
            return "Failed to save to Photos library: \(reason)"
        case .temporaryFileCreationFailed:
            return "Failed to create temporary file for video export."
        case .invalidTrimRange:
            return "Invalid trim range specified for video export."
        case .assetLoadingFailed(let reason):
            return "Failed to load video asset: \(reason)"
        case .exportCancelled:
            return "Video export was cancelled."
        case .insufficientStorage:
            return "Insufficient storage space to export video."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .photosAccessDenied:
            return "Go to Settings > Privacy & Security > Photos and enable access for this app."
        case .videoExportFailed:
            return "Try trimming a shorter segment or check if the original video is playable."
        case .photosLibrarySaveFailed:
            return "Try again or ensure you have enough storage space available."
        case .temporaryFileCreationFailed:
            return "Free up storage space and try again."
        case .invalidTrimRange:
            return "Select a valid trim range within the video duration."
        case .assetLoadingFailed:
            return "Select a different video or try loading it again."
        case .exportCancelled:
            return "Start the export process again if needed."
        case .insufficientStorage:
            return "Free up storage space on your device and try again."
        }
    }
}

// MARK: - Move Persistence Service
/// Essentialist implementation for move persistence operations
/// Provides core functionality for move saving and management
@MainActor
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

    /// Save video to Photos library with real export functionality
    /// - Parameters:
    ///   - asset: The video asset to export
    ///   - moveName: Name for the saved video
    ///   - trimStartTime: Optional trim start time in seconds
    ///   - trimEndTime: Optional trim end time in seconds
    /// - Returns: Real Photos library identifier that can be used to load the video
    /// - Throws: MovePersistenceError if any step fails
    func saveVideoToPhotos(
        asset: AVAsset,
        moveName: String,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil
    ) async throws -> String {
        logger.info("🎬 Starting real video export to Photos library for move: '\(moveName)'")
        logger.info("🔬 PHOTOS_CONTEXT: Permission checking delegated to PhotoKitService")

        // Get video duration for validation
        let assetDuration: TimeInterval
        do {
            let duration = try await asset.load(.duration)
            assetDuration = duration.seconds
        } catch {
            logger.error("❌ Failed to load video asset duration: \(error.localizedDescription)")
            throw MovePersistenceError.assetLoadingFailed(error.localizedDescription)
        }

        guard assetDuration > 0 else {
            logger.error("❌ Invalid video duration: \(assetDuration)s")
            throw MovePersistenceError.invalidTrimRange
        }

        // Validate trim range if provided
        if let startTime = trimStartTime, let endTime = trimEndTime {
            guard startTime >= 0, endTime <= assetDuration, startTime < endTime else {
                logger.error("❌ Invalid trim range: \(startTime)s - \(endTime)s (video duration: \(assetDuration)s)")
                throw MovePersistenceError.invalidTrimRange
            }
            logger.info("✂️ Will export trimmed video: \(startTime)s - \(endTime)s (duration: \(endTime - startTime)s)")
        } else {
            logger.info("📹 Will export full video: 0s - \(assetDuration)s")
        }

        // Create temporary file for export
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("breakdex_export_\(UUID().uuidString).mov")

        logger.info("📁 Created temporary file for export: \(tempURL.lastPathComponent)")

        do {
            // Export the video asset (with optional trimming)
            let exportStartTime = CFAbsoluteTimeGetCurrent()
            logger.info("🎥 Starting video export to temporary file...")

            try await exportVideoToTempFile(
                asset: asset,
                outputURL: tempURL,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime
            )

            let exportDuration = CFAbsoluteTimeGetCurrent() - exportStartTime
            logger.info("✅ Video export completed in \(String(format: "%.2f", exportDuration))s")

            // Save exported video to Photos library
            let photosIdentifier = try await saveTempFileToPhotosLibrary(tempURL: tempURL, moveName: moveName)

            logger.info("✅ Successfully saved video to Photos library with identifier: \(photosIdentifier)")
            return photosIdentifier

        } catch {
            // Clean up temporary file on error
            cleanupTempFile(at: tempURL)
            throw error
        }
    }

    // MARK: - Private Video Export Methods

    /// Export video asset to temporary file
    /// - Parameters:
    ///   - asset: Video asset to export
    ///   - outputURL: Temporary file URL for export
    ///   - trimStartTime: Optional trim start time in seconds
    ///   - trimEndTime: Optional trim end time in seconds
    /// - Throws: MovePersistenceError if export fails
    private func exportVideoToTempFile(
        asset: AVAsset,
        outputURL: URL,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil
    ) async throws {
        logger.info("🎥 Setting up AVAssetExportSession...")

        // Check if asset is exportable
        guard asset.isExportable else {
            logger.error("❌ Video asset is not exportable")
            throw MovePersistenceError.videoExportFailed("Video asset cannot be exported")
        }

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            logger.error("❌ Failed to create AVAssetExportSession with high quality preset")
            throw MovePersistenceError.videoExportFailed("Could not create export session")
        }

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov
        exportSession.shouldOptimizeForNetworkUse = true

        // Set time range for trimmed export if provided
        if let startTime = trimStartTime, let endTime = trimEndTime {
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 600),
                end: CMTime(seconds: endTime, preferredTimescale: 600)
            )
            exportSession.timeRange = timeRange
            logger.info("✂️ Export time range set: \(startTime)s - \(endTime)s")
        } else {
            logger.info("📹 Exporting full video (no time range set)")
        }

        // Validate export session configuration
        guard exportSession.supportedFileTypes.contains(AVFileType.mov) else {
            logger.error("❌ MOV file type not supported by export session")
            throw MovePersistenceError.videoExportFailed("MOV format not supported")
        }

        let exportProgressStartTime = CFAbsoluteTimeGetCurrent()
        logger.info("🎬 Starting AVAssetExportSession export...")

        // Perform export
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                let exportDuration = CFAbsoluteTimeGetCurrent() - exportProgressStartTime

                switch exportSession.status {
                case .completed:
                    self.logger.info("✅ Export completed successfully in \(String(format: "%.2f", exportDuration))s")
                    continuation.resume()

                case .failed:
                    let error = exportSession.error ?? NSError(
                        domain: "MovePersistenceService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]
                    )
                    self.logger.error("❌ Export failed: \(error.localizedDescription)")
                    continuation.resume(throwing: MovePersistenceError.videoExportFailed(error.localizedDescription))

                case .cancelled:
                    self.logger.warning("⚠️ Export was cancelled")
                    continuation.resume(throwing: MovePersistenceError.exportCancelled)

                default:
                    let error = exportSession.error ?? NSError(
                        domain: "MovePersistenceService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Export completed with unexpected status: \(exportSession.status.rawValue)"]
                    )
                    self.logger.error("❌ Export completed with unexpected status: \(exportSession.status.rawValue)")
                    continuation.resume(throwing: MovePersistenceError.videoExportFailed(error.localizedDescription))
                }
            }
        }

        // Verify output file exists and has content
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: outputURL.path) else {
            throw MovePersistenceError.videoExportFailed("Exported file was not created")
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: outputURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0

            if fileSize == 0 {
                throw MovePersistenceError.videoExportFailed("Exported file is empty")
            }

            logger.info("📊 Exported file size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
        } catch {
            logger.warning("⚠️ Could not verify exported file size: \(error.localizedDescription)")
        }
    }

    /// Save exported temporary file to BreakDex album using PhotoKitService
    /// - Parameters:
    ///   - tempURL: URL of the temporary exported video file
    ///   - moveName: Name for the saved video
    /// - Returns: Photos library identifier for the saved video
    /// - Throws: MovePersistenceError if save fails
    private func saveTempFileToPhotosLibrary(tempURL: URL, moveName: String) async throws -> String {
        logger.info("💾 Saving exported video to BreakDex album...")
        logger.info("🔬 PHOTOS_CONTEXT: Entering saveTempFileToPhotosLibrary - Main thread: \(Thread.isMainThread)")
        logger.info("🔬 PHOTOS_CONTEXT: tempURL exists: \(FileManager.default.fileExists(atPath: tempURL.path))")

        do {
            let identifier = try await PhotoKitService.shared.saveVideoToBreakDexAlbum(tempURL)
            logger.info("✅ Successfully saved video to BreakDex album with identifier: \(identifier)")
            logger.info("🔬 PHOTOS_CONTEXT: PhotoKitService atomic save completed")
            return identifier
        } catch let photoKitError as PhotoKitError {
            logger.error("❌ PhotoKitService failed to save video: \(photoKitError.localizedDescription)")
            throw MovePersistenceError.photosLibrarySaveFailed(photoKitError.localizedDescription)
        } catch {
            logger.error("❌ Unknown error saving video to BreakDex album: \(error.localizedDescription)")
            throw MovePersistenceError.photosLibrarySaveFailed(error.localizedDescription)
        }
    }

    /// Clean up temporary file
    /// - Parameter url: URL of the temporary file to clean up
    private func cleanupTempFile(at url: URL) {
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                logger.info("🧹 Cleaned up temporary file: \(url.lastPathComponent)")
            } else {
                logger.debug("ℹ️ Temporary file already cleaned up: \(url.lastPathComponent)")
            }
        } catch {
            logger.warning("⚠️ Failed to clean up temporary file \(url.lastPathComponent): \(error.localizedDescription)")
        }
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
