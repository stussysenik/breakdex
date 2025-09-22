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
    private var saveTask: Task<Void, Never>?
    
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
        saveTask = Task {
            await processSaveOperation(
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
                quarterTurns: 0, // No rotation for save operation
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

        defer {
            Task {
                await MainActor.run {
                    self.isSaving = false
                    self.saveProgress = 1.0
                }
            }
        }

        do {
            // Step 1: Verify asset is ready and loadable
            logger.info("🎬 SAVE_COORDINATOR: Verifying asset readiness", metadata: nil)
            let readyAsset = try await verifyAssetReadiness(asset)
            await updateProgress(0.1)

            // Step 2: Process video (trim if needed)
            let processedAsset: AVAsset
            if let startTime = trimStartTime, let endTime = trimEndTime {
                logger.info("🎬 SAVE_COORDINATOR: Processing trimmed video", metadata: nil)
                await updateProgress(0.2)

                processedAsset = try await processTrimmedVideo(
                    asset: readyAsset,
                    startTime: startTime,
                    endTime: endTime
                )
            } else {
                logger.info("🎬 SAVE_COORDINATOR: Using original video (no trim)", metadata: nil)
                processedAsset = readyAsset
                await updateProgress(0.3)
            }

            // Step 3: Verify processed asset is ready for saving
            let finalAsset = try await verifyAssetReadiness(processedAsset)
            await updateProgress(0.4)

            // Step 4: Save video to Photos library
            logger.info("🎬 SAVE_COORDINATOR: Saving video to Photos", metadata: nil)
            await updateProgress(0.5)

            let savedVideoURL = try await movePersistenceService.saveVideoToPhotos(
                asset: finalAsset,
                moveName: name
            )

            // Step 5: Create Move entity in Core Data
            logger.info("🎬 SAVE_COORDINATOR: Creating Move entity", metadata: nil)
            await updateProgress(0.7)

            let move = try await movePersistenceService.createMoveEntity(
                name: name,
                videoURL: savedVideoURL,
                originalPhotosIdentifier: photosIdentifier,
                trimStartTime: trimStartTime ?? 0.0,
                trimEndTime: trimEndTime ?? finalAsset.duration.seconds,
                rotationQuarterTurns: rotationQuarterTurns
            )

            // Step 6: Finalize and return result
            await MainActor.run {
                self.saveProgress = 1.0
                self.saveStatus = .completed
            }

            let result = SavedMoveResult(
                move: move,
                videoURL: savedVideoURL,
                asset: finalAsset,
                wasTrimmed: trimStartTime != nil && trimEndTime != nil
            )

            return result

        } catch {
            logger.error("🎬 SAVE_COORDINATOR: Save operation failed: \(error.localizedDescription)", metadata: nil)
            await MainActor.run {
                self.saveStatus = .error(error.localizedDescription)
                self.saveProgress = 0.0
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
        endTime: Double
    ) async throws -> AVAsset {
        logger.info("🎬 SAVE_COORDINATOR: Processing trimmed video (\(startTime)s - \(endTime)s)", metadata: nil)

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
            quarterTurns: 0, // No rotation for save operation
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
    public let videoURL: URL
    public let asset: AVAsset
    public let wasTrimmed: Bool
    
    public init(
        move: Move,
        videoURL: URL,
        asset: AVAsset,
        wasTrimmed: Bool
    ) {
        self.move = move
        self.videoURL = videoURL
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
        }
    }
}