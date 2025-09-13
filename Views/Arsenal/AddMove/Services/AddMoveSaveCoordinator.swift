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
        
        guard !name.isEmpty else {
            throw AddMoveError.invalidMoveName
        }
        
        isSaving = true
        saveProgress = 0.0
        saveStatus = .processing
        
        defer {
            Task {
                await MainActor.run {
                    self.isSaving = false
                    self.saveProgress = 1.0
                }
            }
        }
        
        do {
            // Step 1: Process video (trim if needed)
            let processedAsset: AVAsset
            if let startTime = trimStartTime, let endTime = trimEndTime {
                logger.info("🎬 SAVE_COORDINATOR: Processing trimmed video", metadata: nil)
                saveProgress = 0.2
                
                processedAsset = try await processTrimmedVideo(
                    asset: asset,
                    startTime: startTime,
                    endTime: endTime
                )
            } else {
                logger.info("🎬 SAVE_COORDINATOR: Using original video (no trim)", metadata: nil)
                processedAsset = asset
                saveProgress = 0.3
            }
            
            // Step 2: Save video to Photos library
            logger.info("🎬 SAVE_COORDINATOR: Saving video to Photos", metadata: nil)
            saveProgress = 0.5
            
            let savedVideoURL = try await movePersistenceService.saveVideoToPhotos(
                asset: processedAsset,
                moveName: name
            )
            
            // Step 3: Create Move entity in Core Data
            logger.info("🎬 SAVE_COORDINATOR: Creating Move entity", metadata: nil)
            saveProgress = 0.7
            
            let move = try await movePersistenceService.createMoveEntity(
                name: name,
                videoURL: savedVideoURL,
                originalPhotosIdentifier: photosIdentifier,
                trimStartTime: trimStartTime ?? 0.0,
                trimEndTime: trimEndTime ?? processedAsset.duration.seconds,
                rotationQuarterTurns: rotationQuarterTurns
            )
            
            // Step 4: Finalize and return result
            saveProgress = 1.0
            saveStatus = .completed
            
            let result = SavedMoveResult(
                move: move,
                videoURL: savedVideoURL,
                asset: processedAsset,
                wasTrimmed: trimStartTime != nil && trimEndTime != nil
            )
            
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
    
    private func processTrimmedVideo(
        asset: AVAsset,
        startTime: Double,
        endTime: Double
    ) async throws -> AVAsset {
        logger.info("🎬 SAVE_COORDINATOR: Processing trimmed video (\(startTime)s - \(endTime)s)", metadata: nil)
        
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
        
        return AVURLAsset(url: exportedURL)
    }
    
    private func updateProgress(_ progress: Double) {
        Task {
            await MainActor.run {
                self.saveProgress = progress
            }
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
        }
    }
}