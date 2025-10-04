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
    func exportVideo(asset: AVAsset, trimRange: CMTimeRange, quarterTurns: Int, outputURL: URL) async throws -> URL
    func cancelCurrentOperation()
}

// MARK: - Video Processing Pipeline Implementation
@preconcurrency
final class VideoProcessingPipelineImpl: VideoProcessingPipeline {
    private let loadingService: breakdex.VideoLoadingService
    private let videoProcessor: VideoProcessor
    private let videoSaver: VideoSaver
    private let memoryManager: MemoryManager
    private let stateManager: VideoStateManager
    private let logger: AppLogger
    private let memoryLogger = CentralizedMemoryLogger.shared
    
    private var currentTask: Task<Void, Never>?
    private var correlationId: String?
    
    init(
        loadingService: breakdex.VideoLoadingService,
        videoProcessor: VideoProcessor,
        videoSaver: VideoSaver,
        memoryManager: MemoryManager,
        stateManager: VideoStateManager,
        logger: AppLogger
    ) {
        self.loadingService = loadingService
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
            let result: VideoAsset
            
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
                
                // Load the video using the loading service
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                guard let phAsset = fetchResult.firstObject else {
                    throw NSError(domain: "VideoProcessingPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
                }
                
                // Use the loading service to load the video asset
                let progressStream = loadingService.loadPHAssetWithProgress(phAsset)
                
                // Wait for completion and get the final asset
                var finalAsset: AVAsset?
                for try await event in progressStream {
                    switch event {
                    case .progress(let fraction, _):
                        // Continue processing
                        continue
                    case .success(let asset):
                        finalAsset = asset
                        break
                    }
                }
                
                // Ensure we have an asset
                guard let asset = finalAsset else {
                    throw NSError(domain: "VideoProcessingPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"])
                }
                
                result = try await VideoAsset(
                    avAsset: asset,
                    identifier: identifier,
                    filename: "video-\(Date().timeIntervalSince1970).mov"
                )
                
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
            
            // The video asset is already created and stored in result
            let videoAsset = result
            
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
    
    func exportVideo(asset: AVAsset, trimRange: CMTimeRange, quarterTurns: Int, outputURL: URL) async throws -> URL {
        // 🎯 ENHANCED: Comprehensive export logging with asset validation and rotation tracking
        logger.info("🎬 PIPELINE: 🚀 Starting video export operation", metadata: [
            "trim_start_seconds": "\(trimRange.start.seconds)",
            "trim_duration_seconds": "\(trimRange.duration.seconds)",
            "rotation_quarter_turns": "\(quarterTurns)",
            "rotation_degrees": "\(quarterTurns * 90)",
            "output_filename": outputURL.lastPathComponent,
            "asset_duration_seconds": "\(asset.duration.seconds)",
            "asset_tracks": "\(asset.tracks.count)",
            "export_applies_rotation": "true",
            "rotation_fix_applied": "quarterTurns_will_be_zero_in_metadata"
        ])

        // 🎯 ENHANCED: Asset validation before export
        do {
            let assetDuration = try await asset.load(.duration)
            guard assetDuration.seconds > 0 else {
                logger.error("🎬 PIPELINE: ❌ Invalid asset duration for export", metadata: [
                    "duration_seconds": "\(assetDuration.seconds)",
                    "asset_tracks": "\(asset.tracks.count)"
                ])
                throw NSError(domain: "VideoProcessingPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid asset duration"])
            }
            logger.info("🎬 PIPELINE: ✅ Asset validation passed for export", metadata: [
                "validated_duration_seconds": "\(assetDuration.seconds)"
            ])
        } catch {
            logger.error("🎬 PIPELINE: ❌ Asset validation failed for export: \(error)", metadata: [
                "trim_range": "\(trimRange.start.seconds)-\(trimRange.end.seconds)s",
                "user_impact": "export_operation_will_fail"
            ])
            throw error
        }

        // Cancel any existing operation
        cancelCurrentOperation()

        return try await withTaskCancellationHandler {
            // 🎯 ENHANCED: Detailed export progress tracking
            logger.info("🎬 PIPELINE: 🔄 Beginning VideoTransformBuilder export", metadata: [
                "export_method": "VideoTransformBuilder.exportVideo",
                "expected_output_path": outputURL.path,
                "rotation_applied": "\(quarterTurns != 0)"
            ])

            let startTime = CFAbsoluteTimeGetCurrent()

            // Use VideoTransformBuilder for export
            let exportedURL = try await VideoTransformBuilder.exportVideo(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: quarterTurns,
                outputURL: outputURL
            )

            let exportDuration = CFAbsoluteTimeGetCurrent() - startTime

            // 🎯 ENHANCED: Post-export validation and detailed logging
            guard FileManager.default.fileExists(atPath: exportedURL.path) else {
                logger.error("🎬 PIPELINE: ❌ Export completed but output file missing", metadata: [
                    "expected_path": exportedURL.path,
                    "export_duration_ms": "\(exportDuration * 1000)",
                    "user_impact": "export_failed_silently"
                ])
                throw NSError(domain: "VideoProcessingPipeline", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed - output file missing"])
            }

            do {
                let resources = try exportedURL.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resources.fileSize ?? 0
                logger.info("🎬 PIPELINE: ✅ Video export completed successfully", metadata: [
                    "output_url": exportedURL.lastPathComponent,
                    "file_size_bytes": "\(fileSize)",
                    "file_size_mb": "\(String(format: "%.2f", Double(fileSize) / (1024 * 1024)))",
                    "export_duration_ms": "\(String(format: "%.1f", exportDuration * 1000))",
                    "export_throughput_mb_s": "\(String(format: "%.2f", (Double(fileSize) / (1024 * 1024)) / exportDuration))",
                    "rotation_applied": "\(quarterTurns != 0)",
                    "trim_applied": "\(trimRange.duration.seconds < asset.duration.seconds)"
                ])
            } catch {
                logger.warning("🎬 PIPELINE: ⚠️ Export succeeded but file size unavailable", metadata: [
                    "output_url": exportedURL.lastPathComponent,
                    "export_duration_ms": "\(String(format: "%.1f", exportDuration * 1000))",
                    "file_access_error": error.localizedDescription
                ])
            }

            return exportedURL
        } onCancel: {
            logger.info("🎬 PIPELINE: 🚫 Export operation cancelled", metadata: [
                "output_path": outputURL.lastPathComponent,
                "cancellation_reason": "user_initiated_or_system_triggered"
            ])
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
        memoryManager.clearCache(excluding: nil)
        
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
