//
//  SaveProgressViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/27/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import OSLog
import CoreData
import Photos
import CoreMedia

// MARK: - Category Theory Analysis
/*
 CATEGORY THEORY ANALYSIS:

 Current System (Fragmented):
 - Objects: Multiple independent services, states, operations
 - Morphisms: Disparate operations without unifying framework
 - Functor: Fragmented - no cohesive mapping from input to output
 - Natural Transformation: Missing - no unified state transitions

 Ideal System (Unified):
 - Objects: Unified state, cohesive services, atomic operations
 - Morphisms: End-to-end save flow with unified state management
 - Functor: Efficient - maps user intent to completed save operation
 - Natural Transformation: Seamless integration of all services
 - Isomorphism: Preserved - consistent state throughout the pipeline
*/

// MARK: - Save Flow State
public enum SaveFlowState {
    case idle
    case initializing
    case loadingVideo(progress: Double)
    case processingVideo(progress: Double)
    case savingToLibrary(progress: Double)
    case savingToDatabase(progress: Double)
    case completed
    case failed(Error)

    public var isProcessing: Bool {
        switch self {
        case .loadingVideo, .processingVideo, .savingToLibrary, .savingToDatabase:
            return true
        default:
            return false
        }
    }

    public var progress: Double {
        switch self {
        case .idle, .initializing, .completed, .failed:
            return 0.0
        case .loadingVideo(let progress):
            return progress * 0.25 // 25% of total process
        case .processingVideo(let progress):
            return 0.25 + (progress * 0.35) // 35% of total process
        case .savingToLibrary(let progress):
            return 0.6 + (progress * 0.25) // 25% of total process
        case .savingToDatabase(let progress):
            return 0.85 + (progress * 0.15) // 15% of total process
        }
    }

    public var description: String {
        switch self {
        case .idle:
            return "Ready to save"
        case .initializing:
            return "Initializing save process"
        case .loadingVideo(let progress):
            return "Loading video (\(Int(progress * 100))%)"
        case .processingVideo(let progress):
            return "Processing video (\(Int(progress * 100))%)"
        case .savingToLibrary(let progress):
            return "Saving to Photos library (\(Int(progress * 100))%)"
        case .savingToDatabase(let progress):
            return "Saving to database (\(Int(progress * 100))%)"
        case .completed:
            return "Save completed"
        case .failed(let error):
            return "Save failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Save Flow Result
public struct SaveFlowResult {
    let move: Move
    let videoLoadingResult: VideoLoadingResult
    let videoProcessingResult: VideoProcessingResult?
    let photosPersistenceResult: PhotosPersistenceResult?
    let totalDuration: TimeInterval
    let correlationId: String
    let saveMetrics: SaveMetrics
}

// MARK: - Save Metrics
public struct SaveMetrics {
    var videoLoadingTime: TimeInterval
    var videoProcessingTime: TimeInterval?
    var photosPersistenceTime: TimeInterval
    var databaseSaveTime: TimeInterval
    var totalDuration: TimeInterval
    var fileSizeBytes: Int64?
    var frameCount: Int?
    var memoryPeakMB: Double?
}

// MARK: - Save Flow Configuration
public struct SaveFlowConfiguration {
    let videoSource: VideoSource
    let moveName: String
    let rotationQuarterTurns: Int
    let trimRange: CMTimeRange?
    let tags: String?
    let learningState: String?

    public enum VideoSource {
        case photosPickerItem(PhotosPickerItem)
        case url(URL)
        case phAsset(PHAsset)
    }
}

// MARK: - Save Progress ViewModel Protocol
public protocol SaveProgressViewModelProtocol: ObservableObject {
    var saveState: SaveFlowState { get }
    var progress: Double { get }
    var isProcessing: Bool { get }
    var errorMessage: String? { get }
    var correlationId: String? { get }

    func startSaveFlow(configuration: SaveFlowConfiguration) async
    func cancelSaveFlow() async
    func resetState() async
}

// MARK: - Save Progress ViewModel Implementation
@MainActor
@preconcurrency
public final class SaveProgressViewModel: ObservableObject, SaveProgressViewModelProtocol {

    // MARK: - Published Properties
    @Published public private(set) var saveState: SaveFlowState = .idle
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var errorMessage: String? = nil
    @Published public private(set) var correlationId: String? = nil

    // MARK: - Services
    private let videoLoadingService: ModernVideoLoadingServiceProtocol
    private var videoProcessor: EnhancedVideoProcessorProtocol
    private let photosPersistenceService: PhotosPersistenceServiceProtocol
    private let context: NSManagedObjectContext

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "💾 SaveProgressViewModel")
    private let memoryLogger = CentralizedMemoryLogger.shared
    private var saveTask: Task<Void, Never>?
    private var currentCorrelationId: String?

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    public init(
        videoLoadingService: ModernVideoLoadingServiceProtocol,
        videoProcessor: EnhancedVideoProcessorProtocol,
        photosPersistenceService: PhotosPersistenceServiceProtocol,
        context: NSManagedObjectContext
    ) {
        self.videoLoadingService = videoLoadingService
        self.videoProcessor = videoProcessor
        self.photosPersistenceService = photosPersistenceService
        self.context = context

        logger.info("💾 SAVE_PROGRESS: 🚀 Initialized - end-to-end save flow orchestration")
        setupProgressSubscriptions()
    }

    // MARK: - Public API

    /// Start the complete save flow with comprehensive orchestration
    public func startSaveFlow(configuration: SaveFlowConfiguration) async {
        // Cancel any existing save operation
        await cancelSaveFlow()

        // Generate correlation ID for this operation
        currentCorrelationId = memoryLogger.generateCorrelationId(for: "SaveFlow")
        correlationId = currentCorrelationId

        logger.info("💾 SAVE_PROGRESS: 🚀 Starting save flow [\(self.currentCorrelationId ?? "unknown")]")
        logger.info("💾 SAVE_PROGRESS: 📋 Configuration - name: \(configuration.moveName), rotation: \(configuration.rotationQuarterTurns)")

        saveTask = Task {
            do {
                try await performSaveFlow(configuration: configuration)
            } catch {
                await handleSaveError(error)
            }
        }
    }

    /// Cancel the current save flow
    public func cancelSaveFlow() async {
        logger.info("💾 SAVE_PROGRESS: ⏹️ Cancelling save flow [\(self.currentCorrelationId ?? "unknown")]")

        saveTask?.cancel()
        saveTask = nil

        await resetState()
    }

    /// Reset the view model state
    public func resetState() async {
        logger.info("💾 SAVE_PROGRESS: 🔄 Resetting state [\(self.currentCorrelationId ?? "unknown")]")

        await MainActor.run {
            saveState = .idle
            progress = 0.0
            isProcessing = false
            errorMessage = nil
        }

        // Clean up correlation ID
        if let correlationId = currentCorrelationId {
            memoryLogger.clearCorrelationId(for: "SaveFlow")
        }
        currentCorrelationId = nil
    }

    // MARK: - Private Implementation

    /// Perform the complete save flow with orchestration
    private func performSaveFlow(configuration: SaveFlowConfiguration) async throws {
        let startTime = Date()
        var metrics = SaveMetrics(
            videoLoadingTime: 0.0,
            videoProcessingTime: nil,
            photosPersistenceTime: 0.0,
            databaseSaveTime: 0.0,
            totalDuration: 0.0,
            fileSizeBytes: nil,
            frameCount: nil,
            memoryPeakMB: nil
        )

        do {
            // Phase 1: Initialize
            await updateState(.initializing)
            logger.info("💾 SAVE_PROGRESS: 📋 Save flow initialized [\(self.currentCorrelationId!)]")

            // Phase 2: Load Video
            let videoLoadingResult = try await loadVideoPhase(configuration: configuration)
            metrics.videoLoadingTime = Date().timeIntervalSince(startTime)
            metrics.fileSizeBytes = videoLoadingResult.fileSize

            // Phase 3: Process Video (if needed)
            let videoProcessingResult = try await processVideoPhase(
                asset: videoLoadingResult.asset,
                configuration: configuration
            )
            if let processingResult = videoProcessingResult {
                metrics.videoProcessingTime = processingResult.processingTime
                metrics.frameCount = processingResult.frameCount
            }

            // Phase 4: Save to Photos Library
            let photosPersistenceResult = try await saveToLibraryPhase(
                asset: videoProcessingResult?.asset ?? videoLoadingResult.asset,
                filename: videoLoadingResult.filename,
                sourceIdentifier: videoLoadingResult.photosIdentifier
            )
            metrics.photosPersistenceTime = Date().timeIntervalSince(startTime) - metrics.videoLoadingTime - (metrics.videoProcessingTime ?? 0.0)

            // Phase 5: Save to Database
            let move = try await saveToDatabasePhase(
                configuration: configuration,
                videoLoadingResult: videoLoadingResult,
                videoProcessingResult: videoProcessingResult,
                photosPersistenceResult: photosPersistenceResult
            )
            metrics.databaseSaveTime = Date().timeIntervalSince(startTime) - metrics.videoLoadingTime - (metrics.videoProcessingTime ?? 0.0) - metrics.photosPersistenceTime

            // Calculate total duration
            metrics.totalDuration = Date().timeIntervalSince(startTime)
            // TODO: Implement peak memory tracking
            metrics.memoryPeakMB = nil

            // Create final result
            let result = SaveFlowResult(
                move: move,
                videoLoadingResult: videoLoadingResult,
                videoProcessingResult: videoProcessingResult,
                photosPersistenceResult: photosPersistenceResult,
                totalDuration: metrics.totalDuration,
                correlationId: currentCorrelationId!,
                saveMetrics: metrics
            )

            // Complete the save flow
            await completeSaveFlow(result: result)

        } catch {
            logger.error("💾 SAVE_PROGRESS: ❌ Save flow failed [\(self.currentCorrelationId!)]: \(error)")
            throw error
        }
    }

    // MARK: - Save Flow Phases

    /// Phase 2: Load Video
    private func loadVideoPhase(configuration: SaveFlowConfiguration) async throws -> VideoLoadingResult {
        logger.info("💾 SAVE_PROGRESS: 🎬 Starting video loading phase [\(self.currentCorrelationId!)]")

        switch configuration.videoSource {
        case .photosPickerItem(let item):
            return try await videoLoadingService.loadVideo(from: item)
        case .url(let url):
            return try await videoLoadingService.loadVideo(from: url)
        case .phAsset(let phAsset):
            return try await videoLoadingService.loadVideo(from: phAsset)
        }
    }

    /// Phase 3: Process Video
    private func processVideoPhase(asset: AVAsset, configuration: SaveFlowConfiguration) async throws -> VideoProcessingResult? {
        logger.info("💾 SAVE_PROGRESS: 🔄 Starting video processing phase [\(self.currentCorrelationId!)]")

        // Skip processing if no rotation or trimming needed
        guard configuration.rotationQuarterTurns != 0 || configuration.trimRange != nil else {
            logger.info("💾 SAVE_PROGRESS: ⏭️ Skipping video processing - no transforms needed [\(self.currentCorrelationId!)]")
            return nil
        }

        let processingConfig = VideoProcessingConfiguration(
            operation: configuration.rotationQuarterTurns != 0 ? .trim : .compress,
            startTime: configuration.trimRange?.start.seconds,
            endTime: configuration.trimRange?.end.seconds
        )

        return try await videoProcessor.processVideo(asset, configuration: processingConfig)
    }

    /// Phase 4: Save to Photos Library
    private func saveToLibraryPhase(asset: AVAsset, filename: String, sourceIdentifier: String?) async throws -> PhotosPersistenceResult {
        logger.info("💾 SAVE_PROGRESS: 📸 Starting photos library save phase [\(self.currentCorrelationId!)]")

        return try await photosPersistenceService.saveVideoAsset(
            asset,
            filename: filename,
            sourceIdentifier: sourceIdentifier
        )
    }

    /// Phase 5: Save to Database
    private func saveToDatabasePhase(
        configuration: SaveFlowConfiguration,
        videoLoadingResult: VideoLoadingResult,
        videoProcessingResult: VideoProcessingResult?,
        photosPersistenceResult: PhotosPersistenceResult
    ) async throws -> Move {
        logger.info("💾 SAVE_PROGRESS: 💾 Starting database save phase [\(self.currentCorrelationId!)]")

        // Calculate durations async first (outside Core Data context)
        let trimStartTime: Double
        let trimEndTime: Double

        if let trimRange = configuration.trimRange {
            trimStartTime = trimRange.start.seconds
            trimEndTime = trimRange.end.seconds
        } else {
            trimStartTime = 0.0

            if let processingResult = videoProcessingResult {
                // Use the full asset duration
                do {
                    trimEndTime = try await processingResult.asset.load(.duration).seconds
                } catch {
                    trimEndTime = 10.0 // fallback duration
                }
            } else {
                // Use the original asset duration
                do {
                    trimEndTime = try await videoLoadingResult.asset.load(.duration).seconds
                } catch {
                    trimEndTime = 10.0 // fallback duration
                }
            }
        }

        return try await context.perform {
            let move = Move(context: self.context)
            move.id = UUID()
            move.name = configuration.moveName
            move.photosIdentifier = photosPersistenceResult.localAssetIdentifier
            move.videoAssetCloudIdentifier = photosPersistenceResult.cloudAssetIdentifier
            move.rotationQuarterTurns = Int16(configuration.rotationQuarterTurns)
            move.tags = configuration.tags
            move.learningState = configuration.learningState
            move.createdAt = Date()

            // Set the pre-calculated trim times
            move.trimStartTime = trimStartTime
            move.trimEndTime = trimEndTime

            self.logger.info("💾 SAVE_PROGRESS: 💾 Created Move entity [\(self.currentCorrelationId!)]:")
            self.logger.info("💾 SAVE_PROGRESS:   - Name: \(configuration.moveName)")
            self.logger.info("💾 SAVE_PROGRESS:   - Photos ID: \(photosPersistenceResult.localAssetIdentifier)")
            self.logger.info("💾 SAVE_PROGRESS:   - Cloud ID: \(photosPersistenceResult.cloudAssetIdentifier ?? "none")")
            self.logger.info("💾 SAVE_PROGRESS:   - Rotation: \(configuration.rotationQuarterTurns)")
            self.logger.info("💾 SAVE_PROGRESS:   - Trim: \(move.trimStartTime)s - \(move.trimEndTime)s")

            try self.context.save()

            self.logger.info("💾 SAVE_PROGRESS: ✅ Move saved to database [\(self.currentCorrelationId!)]")
            return move
        }
    }

    // MARK: - Completion and Error Handling

    /// Complete the save flow successfully
    private func completeSaveFlow(result: SaveFlowResult) async {
        logger.info("💾 SAVE_PROGRESS: 🏆 Save flow completed successfully [\(result.correlationId)]")
        logger.info("💾 SAVE_PROGRESS:  Final metrics:")
        logger.info("💾 SAVE_PROGRESS:   - Total duration: \(String(format: "%.2f", result.totalDuration))s")
        logger.info("💾 SAVE_PROGRESS:   - Video loading: \(String(format: "%.2f", result.saveMetrics.videoLoadingTime))s")
        logger.info("💾 SAVE_PROGRESS:   - Video processing: \(String(format: "%.2f", result.saveMetrics.videoProcessingTime ?? 0.0))s")
        logger.info("💾 SAVE_PROGRESS:   - Photos persistence: \(String(format: "%.2f", result.saveMetrics.photosPersistenceTime))s")
        logger.info("💾 SAVE_PROGRESS:   - Database save: \(String(format: "%.2f", result.saveMetrics.databaseSaveTime))s")
        logger.info("💾 SAVE_PROGRESS:   - File size: \(result.saveMetrics.fileSizeBytes ?? 0) bytes")
        logger.info("💾 SAVE_PROGRESS:   - Frame count: \(result.saveMetrics.frameCount ?? 0)")
        logger.info("💾 SAVE_PROGRESS:   - Memory peak: \(String(format: "%.2f", result.saveMetrics.memoryPeakMB ?? 0.0))MB")

        await updateState(.completed)

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "SaveFlow")
        currentCorrelationId = nil
    }

    /// Handle save flow errors
    private func handleSaveError(_ error: Error) async {
        logger.error("💾 SAVE_PROGRESS: ❌ Save flow error [\(self.currentCorrelationId ?? "unknown")]: \(error)")

        await MainActor.run {
            errorMessage = error.localizedDescription
            saveState = .failed(error)
            isProcessing = false
        }
    }

    /// Update the save state
    private func updateState(_ state: SaveFlowState) async {
        await MainActor.run {
            saveState = state
            progress = state.progress
            isProcessing = state.isProcessing
            errorMessage = state.isProcessing ? nil : errorMessage
        }

        logger.info("💾 SAVE_PROGRESS:  State updated: \(state.description) [\(self.currentCorrelationId!)]")
    }

    // MARK: - Progress Subscriptions

    /// Setup progress subscriptions from services
    private func setupProgressSubscriptions() {
        // Video loading progress
        videoLoadingService.progressPublisher
            .sink { [weak self] (progress: VideoLoadingProgress) in
                Task {
                    await self?.handleVideoLoadingProgress(progress)
                }
            }
            .store(in: &cancellables)

        // Video processing progress - disabled for now due to AsyncPublisher limitations
        // Video processing is typically fast enough that real-time progress isn't critical
        logger.info("💾 SAVE_PROGRESS: Video processing progress subscription disabled")

        // Photos persistence progress
        photosPersistenceService.progressPublisher
            .sink { [weak self] (progress: PhotosPersistenceProgress) in
                Task {
                    await self?.handlePhotosPersistenceProgress(progress)
                }
            }
            .store(in: &cancellables)
    }

    /// Handle video loading progress
    private func handleVideoLoadingProgress(_ progress: VideoLoadingProgress) async {
        guard progress.correlationId == currentCorrelationId else { return }

        let saveProgress = progress.progress
        await updateState(.loadingVideo(progress: saveProgress))

        logger.info("💾 SAVE_PROGRESS:  Video loading progress [\(progress.correlationId)]: \(Int(saveProgress * 100))% - \(progress.message)")
    }

    /// Handle video processing progress
    private func handleVideoProcessingProgress(_ progress: VideoProcessingProgress) async {
        guard progress.correlationId == currentCorrelationId else { return }

        let saveProgress = progress.progress
        await updateState(.processingVideo(progress: saveProgress))

        logger.info("💾 SAVE_PROGRESS:  Video processing progress [\(progress.correlationId)]: \(Int(saveProgress * 100))% - \(progress.message)")
    }

    /// Handle photos persistence progress
    private func handlePhotosPersistenceProgress(_ progress: PhotosPersistenceProgress) async {
        guard progress.correlationId == currentCorrelationId else { return }

        let saveProgress = progress.progressValue
        await updateState(.savingToLibrary(progress: saveProgress))

        logger.info("💾 SAVE_PROGRESS:  Photos persistence progress [\(progress.correlationId)]: \(Int(saveProgress * 100))% - \(progress.message)")
    }

    // MARK: - Deinitialization
    deinit {
        logger.info("💾 SAVE_PROGRESS: 🧹 Deinit - cleaning up resources")
        cancellables.removeAll()
        saveTask?.cancel()
    }
}