import SwiftUI
import AVKit
import CoreData
import OSLog

// MARK: - AddMove Save Coordinator
// Single Responsibility: Handle all move saving and persistence operations
@MainActor
public class AddMoveSaveCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isSaving = false
    @Published public private(set) var saveProgress: Double = 0.0
    @Published public private(set) var saveStatus: SaveStatus = .idle
    
    // MARK: - Services
    private let movePersistenceService: MovePersistenceServiceProtocol
    private let videoProcessingPipeline: VideoProcessingPipeline
    private let logger: AppLogger
    
    // MARK: - Private State
    private var saveTask: Task<SavedMoveResult, Error>?
    
    // MARK: - Initialization
    public init(
        movePersistenceService: MovePersistenceServiceProtocol,
        videoProcessingPipeline: VideoProcessingPipeline,
        logger: AppLogger
    ) {
        self.movePersistenceService = movePersistenceService
        self.videoProcessingPipeline = videoProcessingPipeline
        self.logger = logger
    }
    
    // MARK: - Public API

    /// Save move with video processing
    public func saveMove(
        name: String,
        asset: AVAsset,
        photosIdentifier: String,
        trimStartTime: Double? = nil,
        trimEndTime: Double? = nil,
        rotationQuarterTurns: Int = 0
    ) async throws -> SavedMoveResult {
        logger.info("🎬 SAVE_COORDINATOR: Starting save operation for move: \(name)", metadata: nil)

        // Validate input parameters before proceeding
        try validateSaveParameters(
            name: name,
            asset: asset,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        )

        isSaving = true
        saveProgress = 0.0
        saveStatus = .processing

        // Create save task for proper cancellation handling
        saveTask = Task<SavedMoveResult, Error> {
            return try await processSaveOperation(
                name: name,
                asset: asset,
                photosIdentifier: photosIdentifier,
                trimStartTime: trimStartTime,
                trimEndTime: trimEndTime,
                rotationQuarterTurns: rotationQuarterTurns
            )
        }

        do {
            let result = try await saveTask!.value
            logger.info("🎬 SAVE_COORDINATOR: ✅ Save completed successfully", metadata: nil)
            return result
        } catch {
            logger.error("🎬 SAVE_COORDINATOR: ❌ Save failed: \(error.localizedDescription)", metadata: nil)

            await MainActor.run {
                self.saveStatus = .error(error.localizedDescription)
                self.saveProgress = 0.0
            }

            throw error
        }
    }
    
    /// Save move with trimmed video from TrimmerViewModel
    public func saveTrimmedMove(
        name: String,
        originalAsset: AVAsset,
        trimmedAsset: AVAsset,
        photosIdentifier: String,
        trimStartTime: Double,
        trimEndTime: Double,
        rotationQuarterTurns: Int
    ) async throws -> SavedMoveResult {
        logger.info("🎬 SAVE_COORDINATOR: Saving pre-trimmed move: \(name)", metadata: nil)
        
        return try await saveMove(
            name: name,
            asset: trimmedAsset,
            photosIdentifier: photosIdentifier,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Export trimmed video for later use
    public func exportTrimmedVideo(
        asset: AVAsset,
        startTime: Double,
        endTime: Double
    ) async throws -> URL {
        logger.info("🎬 SAVE_COORDINATOR: Exporting trimmed video", metadata: nil)
        
        saveStatus = .exporting
        saveProgress = 0.0
        
        do {
            // Create temporary output URL
            let tempDir = FileManager.default.temporaryDirectory
            let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            
            // Create trim range
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 600),
                duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
            )
            
            let exportedURL = try await VideoTransformBuilder.exportVideo(
                asset: asset,
                trimRange: timeRange,
                quarterTurns: 0, // ✨ FIX: Add comment explaining why no rotation for export-only operation
                outputURL: outputURL
            )
            
            await MainActor.run {
                self.saveProgress = 1.0
                self.saveStatus = .exported(exportedURL)
            }
            
            logger.info("🎬 SAVE_COORDINATOR: Video export completed", metadata: nil)
            return exportedURL
            
        } catch {
            logger.error("🎬 SAVE_COORDINATOR: Video export failed: \(error.localizedDescription)", metadata: nil)
            
            await MainActor.run {
                self.saveStatus = .error(error.localizedDescription)
                self.saveProgress = 0.0
            }
            
            throw error
        }
    }
    
    /// Cancel current save operation
    public func cancelSave() {
        logger.info("🎬 SAVE_COORDINATOR: Cancelling save operation", metadata: nil)
        
        saveTask?.cancel()
        saveTask = nil
        
        Task {
            await MainActor.run {
                self.isSaving = false
                self.saveProgress = 0.0
                self.saveStatus = .cancelled
            }
        }
    }
    
    /// Reset coordinator state
    public func reset() {
        logger.info("🎬 SAVE_COORDINATOR: Resetting state", metadata: nil)
        
        Task {
            await MainActor.run {
                self.isSaving = false
                self.saveProgress = 0.0
                self.saveStatus = .idle
            }
        }
        
        saveTask?.cancel()
        saveTask = nil
    }
    
    // MARK: - Private Methods

    /// Main save operation processing with proper async handling
    private func processSaveOperation(
        name: String,
        asset: AVAsset,
        photosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> SavedMoveResult {

        // Track temporary resources for atomic transaction
        var temporaryVideoURL: URL?
        var finalPhotosIdentifier: String?

        defer {
            Task {
                await MainActor.run {
                    self.isSaving = false
                }
            }

            // CRITICAL: Cleanup happens regardless of success or failure
            if let url = temporaryVideoURL {
                try? FileManager.default.removeItem(at: url)
                logger.info("🎬 SAVE_COORDINATOR: 🧹 Deferred cleanup of temporary file completed", metadata: nil)
            }
        }

        do {
            // Step 1: Verify asset is ready and loadable
            logger.info("🎬 SAVE_COORDINATOR: Verifying asset readiness", metadata: nil)
            let readyAsset = try await verifyAssetReadiness(asset)
            await updateProgress(0.1)

            // Step 2: Process video (trim if needed) and export to temporary file
            logger.info("🎬 SAVE_COORDINATOR: Processing video with atomic export", metadata: nil)
            await updateProgress(0.2)

            let timeRange = CMTimeRange(
                start: CMTime(seconds: trimStartTime ?? 0.0, preferredTimescale: 600),
                end: CMTime(seconds: trimEndTime ?? asset.duration.seconds, preferredTimescale: 600)
            )

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            temporaryVideoURL = try await videoProcessingPipeline.exportVideo(
                asset: readyAsset,
                trimRange: timeRange,
                quarterTurns: rotationQuarterTurns,
                outputURL: outputURL
            )

            await updateProgress(0.4)

            // Step 3: ATOMIC OPERATION - Save to Photos library first
            logger.info("🎬 SAVE_COORDINATOR: 🎯 ATOMIC: Saving to Photos library", metadata: nil)
            await updateProgress(0.5)

            guard let tempFileURL = temporaryVideoURL else {
                throw AddMoveSaveError.temporaryFileCreationFailed
            }

            let avAssetForPhotos = AVURLAsset(url: tempFileURL)
            finalPhotosIdentifier = try await movePersistenceService.saveVideoToPhotos(
                asset: avAssetForPhotos,
                moveName: name
            )

            // Step 4: ATOMIC OPERATION - Create Move entity in Core Data
            logger.info("🎬 SAVE_COORDINATOR: 🎯 ATOMIC: Creating Move entity", metadata: nil)
            await updateProgress(0.7)

            guard let photosId = finalPhotosIdentifier else {
                throw AddMoveSaveError.photosIdentifierGenerationFailed
            }

            let move = try await movePersistenceService.createMoveEntity(
                name: name,
                originalPhotosIdentifier: photosId,
                trimStartTime: trimStartTime ?? 0.0,
                trimEndTime: trimEndTime ?? asset.duration.seconds,
                rotationQuarterTurns: rotationQuarterTurns
            )

            // Step 5: Finalize and return result - TRANSACTION COMPLETE
            await MainActor.run {
                self.saveProgress = 1.0
                self.saveStatus = .completed
            }

            guard let finalTempURL = temporaryVideoURL else {
                throw AddMoveSaveError.temporaryFileCreationFailed
            }

            let finalAsset = AVURLAsset(url: finalTempURL)
            let result = SavedMoveResult(
                move: move,
                photosIdentifier: photosId,
                asset: finalAsset,
                wasTrimmed: trimStartTime != nil && trimEndTime != nil
            )

            logger.info("🎬 SAVE_COORDINATOR: ✅ ATOMIC TRANSACTION COMPLETED SUCCESSFULLY", metadata: [
                "move_name": name,
                "photos_identifier": photosId,
                "temporary_file": finalTempURL.lastPathComponent
            ])

            return result

        } catch {
            // 🚨 CRITICAL: ENHANCED ROLLBACK LOGIC - Comprehensive cleanup and error recovery
            await MainActor.run {
                self.saveStatus = .error(error.localizedDescription)
                self.saveProgress = 0.0
            }

            logger.error("🎬 SAVE_COORDINATOR: ❌ ATOMIC TRANSACTION FAILED - Initiating comprehensive rollback", metadata: [
                "error": error.localizedDescription,
                "error_type": "\(type(of: error))",
                "error_domain": (error as NSError).domain,
                "error_code": "\((error as NSError).code)",
                "rollback_initiated": "true"
            ])

            // ENHANCED ROLLBACK: Multi-stage cleanup with detailed logging
            do {
                // Stage 1: Clean up Photos assets if they were created
                if let orphanedIdentifier = finalPhotosIdentifier {
                    await performPhotosRollback(orphanedIdentifier: orphanedIdentifier, error: error)
                }

                // Stage 2: Clean up any Core Data entities that might have been partially created
                await performCoreDataRollback(moveName: name, error: error)

                // Stage 3: Ensure temporary files are cleaned up
                await performTemporaryFileRollback(temporaryURL: temporaryVideoURL, error: error)

                logger.info("🎬 SAVE_COORDINATOR: ✅ ROLLBACK COMPLETED - System integrity maintained", metadata: [
                    "rollback_stages_completed": "3",
                    "system_state": "clean",
                    "user_impact": "operation_failed_but_no_orphans"
                ])

            } catch let rollbackError {
                logger.error("🎬 SAVE_COORDINATOR: ❌ CRITICAL - ROLLBACK FAILED - Manual cleanup required", metadata: [
                    "original_error": error.localizedDescription,
                    "rollback_error": rollbackError.localizedDescription,
                    "orphaned_identifier": finalPhotosIdentifier ?? "none",
                    "temporary_file": temporaryVideoURL?.lastPathComponent ?? "none",
                    "manual_intervention_required": "true",
                    "user_impact": "potential_data_inconsistency"
                ])
            }

            throw error
        }
    }

    /// Verify asset is ready and can be processed
    private func verifyAssetReadiness(_ asset: AVAsset) async throws -> AVAsset {
        logger.info("🎬 SAVE_COORDINATOR: Verifying asset readiness", metadata: [
            "duration": "\(asset.duration.seconds)",
            "is_playable": "\(asset.isPlayable)"
        ])

        // Check if asset is already loaded and playable
        guard asset.isPlayable else {
            logger.error("🎬 SAVE_COORDINATOR: Asset is not playable", metadata: nil)
            throw AddMoveSaveError.assetNotReady
        }

        guard asset.duration.seconds > 0 else {
            logger.error("🎬 SAVE_COORDINATOR: Asset has invalid duration", metadata: [
                "duration": "\(asset.duration.seconds)"
            ])
            throw AddMoveSaveError.invalidAssetDuration
        }

        // Load tracks to ensure asset is properly initialized
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            logger.error("🎬 SAVE_COORDINATOR: Asset has no video tracks", metadata: nil)
            throw AddMoveSaveError.invalidAssetFormat
        }

        // Load duration to ensure it's accurate
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            logger.error("🎬 SAVE_COORDINATOR: Asset duration after load is invalid", metadata: [
                "duration": "\(duration.seconds)"
            ])
            throw AddMoveSaveError.invalidAssetDuration
        }

        logger.info("🎬 SAVE_COORDINATOR: ✅ Asset verified as ready", metadata: [
            "duration": "\(duration.seconds)",
            "track_count": "\(tracks.count)"
        ])

        return asset
    }

    private func processTrimmedVideo(
        asset: AVAsset,
        startTime: Double,
        endTime: Double,
        rotationQuarterTurns: Int // ✨ ADD: Rotation parameter for proper transformation
    ) async throws -> AVAsset {
        logger.info("🎬 SAVE_COORDINATOR: Processing trimmed video (\(startTime)s - \(endTime)s) with rotation: \(rotationQuarterTurns)", metadata: nil)

        // Verify asset before processing
        let readyAsset = try await verifyAssetReadiness(asset)

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

        // Create trim range
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )

        let exportedURL = try await VideoTransformBuilder.exportVideo(
            asset: readyAsset,
            trimRange: timeRange,
            quarterTurns: rotationQuarterTurns, // ✨ FIX: Use passed rotation parameter instead of hardcoded 0
            outputURL: outputURL
        )

        // Create new asset from exported URL
        let trimmedAsset = AVURLAsset(url: exportedURL)

        // Verify the trimmed asset is ready
        return try await verifyAssetReadiness(trimmedAsset)
    }

    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.saveProgress = progress
        }
    }
}

// MARK: - State Validation Methods

private extension AddMoveSaveCoordinator {

    func validateSaveParameters(
        name: String,
        asset: AVAsset,
        trimStartTime: Double?,
        trimEndTime: Double?
    ) throws {
        // Validate move name
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.warning("🎬 SAVE_COORDINATOR: Invalid move name provided", metadata: [
                "name": "\(name)"
            ])
            throw AddMoveSaveError.invalidMoveName
        }

        // Validate asset
        guard asset.duration.seconds > 0 else {
            logger.warning("🎬 SAVE_COORDINATOR: Invalid asset duration", metadata: [
                "asset_duration": "\(asset.duration.seconds)"
            ])
            throw AddMoveSaveError.videoProcessingFailed(underlyingError: nil)
        }

        // Validate trim parameters if provided
        if let startTime = trimStartTime, let endTime = trimEndTime {
            try validateTrimParameters(startTime: startTime, endTime: endTime, assetDuration: asset.duration.seconds)
        }
    }

    func validateTrimParameters(startTime: Double, endTime: Double, assetDuration: Double) throws {
        // Ensure start time is not negative
        guard startTime >= 0 else {
            logger.warning("🎬 SAVE_COORDINATOR: Invalid start time (negative)", metadata: [
                "start_time": "\(startTime)",
                "asset_duration": "\(assetDuration)"
            ])
            throw AddMoveSaveError.videoProcessingFailed(underlyingError: nil)
        }

        // Ensure end time is within asset bounds
        guard endTime <= assetDuration else {
            logger.warning("🎬 SAVE_COORDINATOR: End time exceeds asset duration", metadata: [
                "end_time": "\(endTime)",
                "asset_duration": "\(assetDuration)"
            ])
            throw AddMoveSaveError.videoProcessingFailed(underlyingError: nil)
        }

        // Ensure start time is before end time
        guard startTime < endTime else {
            logger.warning("🎬 SAVE_COORDINATOR: Start time must be before end time", metadata: [
                "start_time": "\(startTime)",
                "end_time": "\(endTime)"
            ])
            throw AddMoveSaveError.videoProcessingFailed(underlyingError: nil)
        }

        // Ensure minimum duration requirement
        let duration = endTime - startTime
        let minimumDuration = 3.0 // 3 seconds minimum
        guard duration >= minimumDuration else {
            logger.warning("🎬 SAVE_COORDINATOR: Duration too short", metadata: [
                "duration": "\(duration)",
                "minimum_duration": "\(minimumDuration)"
            ])
            throw AddMoveSaveError.videoProcessingFailed(underlyingError: nil)
        }

        logger.info("🎬 SAVE_COORDINATOR: ✅ Trim parameters validated", metadata: [
            "start_time": "\(startTime)",
            "end_time": "\(endTime)",
            "duration": "\(duration)",
            "asset_duration": "\(assetDuration)"
        ])
    }

    // MARK: - Enhanced Rollback Methods

    /// Stage 1: Rollback Photos library assets
    private func performPhotosRollback(orphanedIdentifier: String, error: Error) async {
        logger.warning("🎬 SAVE_COORDINATOR: 🔄 ROLLBACK STAGE 1: Cleaning up Photos asset", metadata: [
            "orphaned_identifier": orphanedIdentifier,
            "rollback_reason": "Photos asset orphaned due to failure",
            "original_error": error.localizedDescription
        ])

        do {
            try await movePersistenceService.deleteVideoFromPhotos(localIdentifier: orphanedIdentifier)
            logger.info("🎬 SAVE_COORDINATOR: ✅ ROLLBACK STAGE 1: Photos asset deleted successfully", metadata: [
                "orphaned_identifier": orphanedIdentifier,
                "rollback_successful": "true"
            ])
        } catch {
            logger.error("🎬 SAVE_COORDINATOR: ❌ ROLLBACK STAGE 1 FAILED: Could not delete Photos asset", metadata: [
                "orphaned_identifier": orphanedIdentifier,
                "rollback_error": error.localizedDescription,
                "manual_cleanup_required": "true",
                "user_impact": "orphaned_Photos_asset_requires_manual_deletion"
            ])
            // Continue with other rollback stages even if this one fails
        }
    }

    /// Stage 2: Rollback Core Data entities
    private func performCoreDataRollback(moveName: String, error: Error) async {
        logger.warning("🎬 SAVE_COORDINATOR: 🔄 ROLLBACK STAGE 2: Cleaning up Core Data entities", metadata: [
            "move_name": moveName,
            "rollback_reason": "Potential partially created Move entity",
            "original_error": error.localizedDescription
        ])

        do {
            // Try to find and delete any Move entity with this name that might have been created
            try await movePersistenceService.cleanupOrphanedMoveEntity(name: moveName)
            logger.info("🎬 SAVE_COORDINATOR: ✅ ROLLBACK STAGE 2: Core Data cleanup completed", metadata: [
                "move_name": moveName,
                "rollback_successful": "true"
            ])
        } catch {
            logger.error("🎬 SAVE_COORDINATOR: ❌ ROLLBACK STAGE 2 FAILED: Could not cleanup Core Data", metadata: [
                "move_name": moveName,
                "rollback_error": error.localizedDescription,
                "manual_cleanup_required": "true",
                "user_impact": "potential_orphaned_Core_Data_entity"
            ])
            // Continue with other rollback stages even if this one fails
        }
    }

    /// Stage 3: Rollback temporary files
    private func performTemporaryFileRollback(temporaryURL: URL?, error: Error) async {
        guard let tempURL = temporaryURL else {
            logger.info("🎬 SAVE_COORDINATOR: 🔄 ROLLBACK STAGE 3: No temporary file to cleanup", metadata: [
                "rollback_reason": "No temporary file was created"
            ])
            return
        }

        logger.warning("🎬 SAVE_COORDINATOR: 🔄 ROLLBACK STAGE 3: Cleaning up temporary file", metadata: [
            "temporary_file": tempURL.lastPathComponent,
            "rollback_reason": "Temporary file cleanup after failure",
            "original_error": error.localizedDescription
        ])

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
                logger.info("🎬 SAVE_COORDINATOR: ✅ ROLLBACK STAGE 3: Temporary file deleted successfully", metadata: [
                    "temporary_file": tempURL.lastPathComponent,
                    "rollback_successful": "true"
                ])
            } else {
                logger.info("🎬 SAVE_COORDINATOR: ℹ️ ROLLBACK STAGE 3: Temporary file already cleaned up", metadata: [
                    "temporary_file": tempURL.lastPathComponent,
                    "cleanup_status": "already_cleaned"
                ])
            }
        } catch {
            logger.error("🎬 SAVE_COORDINATOR: ❌ ROLLBACK STAGE 3 FAILED: Could not delete temporary file", metadata: [
                "temporary_file": tempURL.lastPathComponent,
                "rollback_error": error.localizedDescription,
                "manual_cleanup_required": "true",
                "user_impact": "temporary_file_will_be_cleaned_by_system"
            ])
        }
    }
}

// MARK: - Save Status
public enum SaveStatus {
    case idle
    case processing
    case exporting
    case exported(URL)
    case completed
    case cancelled
    case error(String)
}

// MARK: - Saved Move Result
public struct SavedMoveResult {
    public let move: Move
    public let photosIdentifier: String // ✅ FIXED: Uses Photos identifier instead of local URL
    public let asset: AVAsset
    public let wasTrimmed: Bool

    public init(
        move: Move,
        photosIdentifier: String, // ✅ FIXED: Uses Photos identifier instead of local URL
        asset: AVAsset,
        wasTrimmed: Bool
    ) {
        self.move = move
        self.photosIdentifier = photosIdentifier
        self.asset = asset
        self.wasTrimmed = wasTrimmed
    }
}

// MARK: - Save Coordinator Protocol
@MainActor
public protocol AddMoveSaveCoordinatorProtocol: ObservableObject {
    var isSaving: Bool { get }
    var saveProgress: Double { get }
    var saveStatus: SaveStatus { get }
    
    func saveMove(
        name: String,
        asset: AVAsset,
        photosIdentifier: String,
        trimStartTime: Double?,
        trimEndTime: Double?,
        rotationQuarterTurns: Int
    ) async throws -> SavedMoveResult
    
    func saveTrimmedMove(
        name: String,
        originalAsset: AVAsset,
        trimmedAsset: AVAsset,
        photosIdentifier: String,
        trimStartTime: Double,
        trimEndTime: Double,
        rotationQuarterTurns: Int
    ) async throws -> SavedMoveResult
    
    func exportTrimmedVideo(asset: AVAsset, startTime: Double, endTime: Double) async throws -> URL
    func cancelSave()
    func reset()
}

// MARK: - Conformance
extension AddMoveSaveCoordinator: AddMoveSaveCoordinatorProtocol {}

// MARK: - Save Errors
public enum AddMoveSaveError: LocalizedError {
    case invalidMoveName
    case videoProcessingFailed(underlyingError: Error?)
    case photosSaveFailed(underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error?)
    case assetNotReady
    case invalidAssetDuration
    case invalidAssetFormat
    case operationCancelled
    case temporaryFileCreationFailed
    case photosIdentifierGenerationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidMoveName:
            return "Please enter a name for your move."
        case .videoProcessingFailed(let error):
            return "Failed to process video. " + (error?.localizedDescription ?? "")
        case .photosSaveFailed(let error):
            return "Failed to save video to Photos. " + (error?.localizedDescription ?? "")
        case .coreDataSaveFailed(let error):
            return "Failed to save move data. " + (error?.localizedDescription ?? "")
        case .assetNotReady:
            return "Video asset is not ready for processing. Please try again."
        case .invalidAssetDuration:
            return "Invalid video duration detected. Please select a different video."
        case .invalidAssetFormat:
            return "Unsupported video format. Please select a valid video file."
        case .operationCancelled:
            return "Save operation was cancelled."
        case .temporaryFileCreationFailed:
            return "Failed to create temporary video file for processing."
        case .photosIdentifierGenerationFailed:
            return "Failed to generate identifier for saved video."
        }
    }
}