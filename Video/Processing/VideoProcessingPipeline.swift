import Foundation
import AVFoundation
import Photos
import PhotosUI

// MARK: - Video Asset
public struct VideoAsset {
    let avAsset: AVAsset
    let identifier: String
    let filename: String
    let duration: TimeInterval
    let fileSize: Int64
    
    init(avAsset: AVAsset, identifier: String, filename: String) async throws {
        self.avAsset = avAsset
        self.identifier = identifier
        self.filename = filename
        self.duration = (try await avAsset.load(.duration)).seconds
        
        // Calculate file size
        if let urlAsset = avAsset as? AVURLAsset {
            do {
                let resources = try urlAsset.url.resourceValues(forKeys: [.fileSizeKey])
                self.fileSize = Int64(resources.fileSize ?? 0)
            } catch {
                self.fileSize = 0
            }
        } else {
            self.fileSize = 0
        }
    }
}

// MARK: - Video Processing Pipeline Protocol
public protocol VideoProcessingPipeline {
    func loadVideo(from identifier: String) async throws -> VideoAsset
    func processVideo(_ asset: VideoAsset, rotationQuarterTurns: Int) async throws -> VideoAsset
    func saveVideo(_ asset: VideoAsset) async throws -> URL
    func cancelCurrentOperation()
}

// MARK: - Video Processing Pipeline Implementation
final class VideoProcessingPipelineImpl: VideoProcessingPipeline {
    private let videoLoader: VideoLoader
    private let videoProcessor: VideoProcessor
    private let videoSaver: VideoSaver
    private let memoryManager: MemoryManager
    private let stateManager: VideoStateManager
    private let logger: AppLogger
    private let memoryLogger = CentralizedMemoryLogger.shared
    
    private var currentTask: Task<Void, Never>?
    private var correlationId: String?
    
    init(
        videoLoader: VideoLoader,
        videoProcessor: VideoProcessor,
        videoSaver: VideoSaver,
        memoryManager: MemoryManager,
        stateManager: VideoStateManager,
        logger: AppLogger
    ) {
        self.videoLoader = videoLoader
        self.videoProcessor = videoProcessor
        self.videoSaver = videoSaver
        self.memoryManager = memoryManager
        self.stateManager = stateManager
        self.logger = logger
        
        // Generate correlation ID for this pipeline instance
        correlationId = memoryLogger.generateCorrelationId(for: "VideoProcessingPipeline")
    }
    
    func loadVideo(from identifier: String) async throws -> VideoAsset {
        logger.info("🔄 Starting video loading process", metadata: ["identifier": identifier])
        
        // Generate correlation ID for this load operation
        let operationCorrelationId = memoryLogger.generateCorrelationId(for: "LoadVideo-\(identifier.prefix(8))")
        
        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before video loading", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
        
        // Cancel any existing operation
        cancelCurrentOperation()
        
        // Transition to loading state
        try await stateManager.transition(to: .loading)
        
        // Create and start the loading task
        return try await withTaskCancellationHandler {
            let result: VideoLoaderResult
            
            // Check memory before loading
            let availableMemory = memoryManager.getAvailableMemory()
            let memoryThreshold: Int64 = 200 * 1024 * 1024 // 200MB
            
            if availableMemory < memoryThreshold {
                memoryLogger.logMemoryWarning(
                    message: "Low memory before loading: \(availableMemory / (1024 * 1024))MB",
                    correlationId: operationCorrelationId,
                    component: "VideoProcessingPipeline",
                    metadata: ["availableMemory": availableMemory, "threshold": memoryThreshold]
                )
                
                performAggressiveCacheClearing(correlationId: operationCorrelationId)
                
                // Check memory again after clearing
                let availableMemoryAfterClear = memoryManager.getAvailableMemory()
                if availableMemoryAfterClear < memoryThreshold {
                    let error = VideoProcessingError.memoryLimitExceeded(
                        used: memoryManager.getUsedMemory() / (1024 * 1024),
                        available: availableMemoryAfterClear / (1024 * 1024)
                    )
                    
                    memoryLogger.logMemoryError(
                        message: "Memory limit exceeded before loading: \(error.localizedDescription)",
                        correlationId: operationCorrelationId,
                        component: "VideoProcessingPipeline",
                        metadata: ["availableMemoryAfterClear": availableMemoryAfterClear, "threshold": memoryThreshold]
                    )
                    
                    try await stateManager.transition(to: .error)
                    throw error
                }
            }
            
            // Load the video
            do {
                // Log memory just before loading
                memoryLogger.logMemoryState(context: "Just before video loading", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
                
                // Load the video directly from the Photos identifier
                result = try await videoLoader.loadVideo(fromIdentifier: identifier)
                
                // Log memory after loading
                memoryLogger.logMemoryState(context: "After video loading", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            } catch {
                logger.error("❌ Video loading failed: \(error.localizedDescription)", metadata: ["identifier": identifier])
                
                memoryLogger.logMemoryError(
                    message: "Video loading error: \(error.localizedDescription)",
                    correlationId: operationCorrelationId,
                    component: "VideoProcessingPipeline",
                    metadata: ["identifier": identifier, "error": error.localizedDescription]
                )
                
                try await stateManager.transition(to: .error)
                throw VideoProcessingError.videoLoadingFailed(identifier: identifier, underlyingError: error)
            }
            
            // Create VideoAsset
            let videoAsset = try await VideoAsset(
                avAsset: result.asset,
                identifier: result.photosIdentifier,
                filename: result.filename
            )
            
            logger.info("✅ Video loaded successfully", metadata: [
                "identifier": identifier,
                "filename": result.filename,
                "duration": videoAsset.duration,
                "fileSize": videoAsset.fileSize
            ])
            
            // Log memory before state transition
            memoryLogger.logMemoryState(context: "Before transitioning to loaded state", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            
            // Transition to loaded state
            try await stateManager.transition(to: .loaded)
            
            // Log memory after state transition
            memoryLogger.logMemoryState(context: "After transitioning to loaded state", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            
            return videoAsset
        } onCancel: {
            self.currentTask?.cancel()
        }
    }
    
    func processVideo(_ asset: VideoAsset, rotationQuarterTurns: Int) async throws -> VideoAsset {
        logger.info("🔄 Starting video processing", metadata: [
            "identifier": asset.identifier,
            "rotation": rotationQuarterTurns
        ])
        
        // Generate correlation ID for this process operation
        let operationCorrelationId = memoryLogger.generateCorrelationId(for: "ProcessVideo-\(asset.identifier.prefix(8))")
        
        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before video processing", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
        
        // Cancel any existing operation
        cancelCurrentOperation()
        
        // Transition to processing state
        try await stateManager.transition(to: .processing)
        
        // Create and start the processing task
        return try await withTaskCancellationHandler {
            // Check memory before processing
            let availableMemory = memoryManager.getAvailableMemory()
            let memoryThreshold: Int64 = 300 * 1024 * 1024 // 300MB
            
            if availableMemory < memoryThreshold {
                memoryLogger.logMemoryWarning(
                    message: "Low memory before processing: \(availableMemory / (1024 * 1024))MB",
                    correlationId: operationCorrelationId,
                    component: "VideoProcessingPipeline",
                    metadata: ["availableMemory": availableMemory, "threshold": memoryThreshold]
                )
                
                performAggressiveCacheClearing(correlationId: operationCorrelationId)
                
                // Check memory again after clearing
                let availableMemoryAfterClear = memoryManager.getAvailableMemory()
                if availableMemoryAfterClear < memoryThreshold {
                    let error = VideoProcessingError.memoryLimitExceeded(
                        used: memoryManager.getUsedMemory() / (1024 * 1024),
                        available: availableMemoryAfterClear / (1024 * 1024)
                    )
                    
                    memoryLogger.logMemoryError(
                        message: "Memory limit exceeded before processing: \(error.localizedDescription)",
                        correlationId: operationCorrelationId,
                        component: "VideoProcessingPipeline",
                        metadata: ["availableMemoryAfterClear": availableMemoryAfterClear, "threshold": memoryThreshold]
                    )
                    
                    try await stateManager.transition(to: .error)
                    throw error
                }
            }
            
            // Process the video
            let processedAsset: AVAsset
            do {
                // Log memory just before processing
                memoryLogger.logMemoryState(context: "Just before video processing", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
                
                // Clear any intermediate assets before processing
                clearIntermediateAssets(correlationId: operationCorrelationId)
                
                processedAsset = try await videoProcessor.processVideo(
                    asset.avAsset,
                    rotationQuarterTurns: rotationQuarterTurns
                )
                
                // Log memory after processing
                memoryLogger.logMemoryState(context: "After video processing", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            } catch {
                logger.error("❌ Video processing failed: \(error.localizedDescription)", metadata: [
                    "identifier": asset.identifier,
                    "operation": "rotation"
                ])
                
                memoryLogger.logMemoryError(
                    message: "Video processing error: \(error.localizedDescription)",
                    correlationId: operationCorrelationId,
                    component: "VideoProcessingPipeline",
                    metadata: ["identifier": asset.identifier, "operation": "rotation", "error": error.localizedDescription]
                )
                
                try await stateManager.transition(to: .error)
                throw VideoProcessingError.videoProcessingFailed(
                    operation: "rotation",
                    underlyingError: error
                )
            }
            
            // Create processed VideoAsset
            let processedVideoAsset = try await VideoAsset(
                avAsset: processedAsset,
                identifier: "\(asset.identifier)-processed",
                filename: "processed-\(asset.filename)"
            )
            
            logger.info("✅ Video processed successfully", metadata: [
                "identifier": asset.identifier,
                "rotation": rotationQuarterTurns
            ])
            
            // Log memory before state transition
            memoryLogger.logMemoryState(context: "Before transitioning to ready state", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            
            // Transition to ready state
            try await stateManager.transition(to: .ready)
            
            // Log memory after state transition
            memoryLogger.logMemoryState(context: "After transitioning to ready state", correlationId: operationCorrelationId, component: "VideoProcessingPipeline")
            
            return processedVideoAsset
        } onCancel: {
            self.currentTask?.cancel()
        }
    }
    
    func saveVideo(_ asset: VideoAsset) async throws -> URL {
        logger.info("🔄 Starting video saving", metadata: ["identifier": asset.identifier])
        
        // Log initial memory state
        logMemoryState("Before video saving")
        
        // Cancel any existing operation
        cancelCurrentOperation()
        
        // Create and start the saving task
        return try await withTaskCancellationHandler {
            // Check memory before saving
            let availableMemory = memoryManager.getAvailableMemory()
            let memoryThreshold: Int64 = 100 * 1024 * 1024 // 100MB
            
            if availableMemory < memoryThreshold {
                logger.warning("⚠️ Low memory before saving: \(availableMemory / (1024 * 1024))MB", metadata: nil)
                performAggressiveCacheClearing()
                
                // Check memory again after clearing
                let availableMemoryAfterClear = memoryManager.getAvailableMemory()
                if availableMemoryAfterClear < memoryThreshold {
                    let error = VideoProcessingError.memoryLimitExceeded(
                        used: memoryManager.getUsedMemory() / (1024 * 1024),
                        available: availableMemoryAfterClear / (1024 * 1024)
                    )
                    logger.error("❌ Memory limit exceeded before saving: \(error.localizedDescription)", metadata: nil)
                    throw error
                }
            }
            
            // Save the video
            let savedURL: URL
            do {
                // Log memory just before saving
                logMemoryState("Just before video saving")
                
                // Clear any intermediate assets before saving
                clearIntermediateAssets()
                
                savedURL = try await videoSaver.saveVideo(asset.avAsset, filename: asset.filename)
                
                // Log memory after saving
                logMemoryState("After video saving")
            } catch {
                logger.error("❌ Video saving failed: \(error.localizedDescription)", metadata: [
                    "identifier": asset.identifier
                ])
                logMemoryState("After video saving error")
                throw VideoProcessingError.videoProcessingFailed(
                    operation: "saving",
                    underlyingError: error
                )
            }
            
            logger.info("✅ Video saved successfully", metadata: [
                "identifier": asset.identifier,
                "url": savedURL.absoluteString
            ])
            
            // Perform aggressive cache clearing after successful save
            performAggressiveCacheClearing()
            
            // Log memory after cache clearing
            logMemoryState("After cache clearing post-save")
            
            return savedURL
        } onCancel: {
            self.currentTask?.cancel()
        }
    }
    
    func cancelCurrentOperation() {
        logger.info("🔄 Cancelling current operation", metadata: nil)
        logMemoryState("Before cancelling operation")
        
        currentTask?.cancel()
        currentTask = nil
        
        // Clear intermediate assets when cancelling
        clearIntermediateAssets()
        
        // Perform cache clearing when cancelling
        performAggressiveCacheClearing()
        
        logMemoryState("After cancelling operation")
    }
    
    // MARK: - Private Helper Methods
    
    private func logMemoryState(_ context: String) {
        let availableMemory = memoryManager.getAvailableMemory()
        let usedMemory = memoryManager.getUsedMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentageUsed = Double(usedMemory) / Double(totalMemory) * 100
        
        logger.info("🧠 [\(context)] Memory state:", metadata: ["correlationId": correlationId ?? "unknown"])
        logger.info("   - Available: \(availableMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
        logger.info("   - Used: \(usedMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
        logger.info("   - Total: \(totalMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
        logger.info("   - Percentage used: \(String(format: "%.1f", percentageUsed))%", metadata: ["correlationId": correlationId ?? "unknown"])
    }
    
    private func performAggressiveCacheClearing(correlationId: String? = nil) {
        logger.info("🧠 Performing aggressive cache clearing", metadata: ["correlationId": correlationId ?? "unknown"])
        
        // Log memory event
        memoryLogger.logCacheClearing(
            correlationId: correlationId,
            component: "VideoProcessingPipeline",
            details: "Performing aggressive cache clearing"
        )
        
        // Clear memory manager cache
        memoryManager.clearCache()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Request garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Force garbage collection
            DispatchQueue.main.async {
                // This is a hint to the system that we're in a critical memory state
                // The system may take additional actions
            }
        }
        
        logger.info("🧠 Aggressive cache clearing completed", metadata: ["correlationId": correlationId ?? "unknown"])
    }
    
    private func clearIntermediateAssets(correlationId: String? = nil) {
        logger.info("🧠 Clearing intermediate assets", metadata: ["correlationId": correlationId ?? "unknown"])
        
        // Log memory event
        memoryLogger.logMemoryEvent(
            event: "Clearing intermediate assets",
            correlationId: correlationId,
            component: "VideoProcessingPipeline",
            metadata: nil
        )
        
        // Clear any temporary video files
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in contents where file.pathExtension == "mov" || file.pathExtension == "mp4" || file.pathExtension == "tmp" {
                try FileManager.default.removeItem(at: file)
                logger.info("🧠 Deleted intermediate video file: \(file.lastPathComponent)", metadata: ["correlationId": correlationId ?? "unknown"])
            }
        } catch {
            logger.error("🧠 Failed to clear intermediate video files: \(error.localizedDescription)", metadata: ["correlationId": correlationId ?? "unknown"])
        }
        
        logger.info("🧠 Intermediate assets clearing completed", metadata: ["correlationId": correlationId ?? "unknown"])
    }
}