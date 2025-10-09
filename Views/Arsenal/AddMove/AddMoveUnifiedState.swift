import AVFoundation
import AVKit
import Combine
import CoreData
import OSLog
import PhotosUI
import SwiftUI

// AddMoveUnifiedState.swift

// MARK: - AddMoveUnifiedState
public class AddMoveUnifiedState: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var flowState: AddMoveFlowState = .ready
    @Published public private(set) var playerState: PlayerState = .idle
    @Published public private(set) var correlationId: String? = nil

    // MARK: - Service Dependencies
    public let unifiedPlayerManager: UnifiedPlayerManager
    public let modernVideoLoadingService: ModernVideoLoadingService
    public let videoProcessingPipeline: VideoProcessingPipeline
    public let timecodeCalculationService: TimecodeCalculationService
    public let persistentContainer: NSPersistentContainer
    public let movePersistenceService: MovePersistenceService
    public let appContainer: AppContainer

    // MARK: - Initialization
    public init(
        unifiedPlayerManager: UnifiedPlayerManager,
        modernVideoLoadingService: ModernVideoLoadingService,
        videoProcessingPipeline: VideoProcessingPipeline,
        timecodeCalculationService: TimecodeCalculationService,
        persistentContainer: NSPersistentContainer,
        movePersistenceService: MovePersistenceService,
        appContainer: AppContainer
    ) {
        self.unifiedPlayerManager = unifiedPlayerManager
        self.modernVideoLoadingService = modernVideoLoadingService
        self.videoProcessingPipeline = videoProcessingPipeline
        self.timecodeCalculationService = timecodeCalculationService
        self.persistentContainer = persistentContainer
        self.movePersistenceService = movePersistenceService
        self.appContainer = appContainer
    }

    // MARK: - Core Workflow Methods

    /// Load video from Photos picker - MAIN ENTRY POINT
    public func loadVideo(from item: PhotosPickerItem) async {
        logger.info("📹 Starting video loading from Photos picker")

        await MainActor.run {
            correlationId = UUID().uuidString
            flowState = .loadingVideo
        }

        do {
            // Get the video asset from Photos picker
            let asset = try await loadVideoAsset(from: item)

            await MainActor.run {
                self.currentVideoAsset = asset
                self.flowState = .trimming
                self.playerState = .ready
            }

            logger.info("✅ Video loaded successfully")

        } catch {
            await MainActor.run {
                self.flowState = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }

            logger.error("❌ Video loading failed: \(error.localizedDescription)")
        }
    }

    /// Reset the workflow to ready state
    public func resetWorkflow() {
        logger.info("🔄 Resetting AddMove workflow")

        flowState = .ready
        playerState = .idle
        correlationId = nil
        currentVideoAsset = nil

        cancellables.removeAll()
    }

    // MARK: - Private Properties

    @Published public private(set) var currentVideoAsset: AVAsset? = nil
    private var cancellables = Set<AnyCancellable>()

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveUnifiedState")

    // MARK: - Video Loading Helper

    private func loadVideoAsset(from item: PhotosPickerItem) async throws -> AVAsset {
        logger.info("🔄 Loading video asset from PhotosPickerItem")

        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw NSError(domain: "AddMoveUnifiedState", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video data"])
        }

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        try data.write(to: tempURL)

        // Create AVAsset
        let asset = AVAsset(url: tempURL)

        // Validate asset
        guard asset.isReadable else {
            throw NSError(domain: "AddMoveUnifiedState", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video asset is not readable"])
        }

        logger.info("✅ Video asset loaded and validated")
        return asset
    }

    // MARK: - Trimming Methods (Basic Implementation)

    /// Process video trim - basic implementation
    public func processTrim(from startTime: CMTime, to endTime: CMTime) async throws -> AVAsset {
        guard let asset = currentVideoAsset else {
            throw NSError(domain: "AddMoveUnifiedState", code: -3, userInfo: [NSLocalizedDescriptionKey: "No video asset loaded"])
        }

        logger.info("✂️ Processing video trim: \(startTime.seconds) -> \(endTime.seconds)")

        await MainActor.run {
            flowState = .loadingTrimmedAsset(progress: SimpleProgress(value: 0.5, message: "Trimming video..."))
        }

        // Use the existing video processing pipeline
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed-\(UUID().uuidString).mov")

        let trimmedURL = try await videoProcessingPipeline.exportVideo(
            asset: asset,
            trimRange: CMTimeRange(start: startTime, end: endTime),
            quarterTurns: 0, // No rotation by default
            outputURL: tempURL
        )

        let trimmedAsset = AVAsset(url: trimmedURL)

        await MainActor.run {
            self.currentVideoAsset = trimmedAsset
            self.flowState = .naming
        }

        logger.info("✅ Video trim completed successfully")
        return trimmedAsset
    }

    // MARK: - Save Methods (Basic Implementation)

    /// Save move with basic metadata
    public func saveMove(name: String, videoAsset: AVAsset) async throws -> Move {
        logger.info("💾 Saving move: \(name)")

        await MainActor.run {
            flowState = .saving
        }

        // This is a basic implementation - you'll need to integrate with your existing Move entity
        // For now, throw an error to indicate it needs implementation
        throw NSError(domain: "AddMoveUnifiedState", code: -4, userInfo: [
            NSLocalizedDescriptionKey: "Save functionality needs to be implemented with your Core Data Move entity"
        ])
    }

    // MARK: - Cleanup
    deinit {
        logger.info("🧹 AddMoveUnifiedState deallocating")
        cancellables.removeAll()
    }
}