import Foundation
import AVFoundation
import OSLog
import Combine

// MARK: - Category Theory Analysis
/*
 CATEGORY THEORY ANALYSIS:

 Current System (Enhanced):
 - Objects: AVAsset, VideoTransformBuilder, ProcessingResult
 - Morphisms: processVideo(), createPlayerItem(), exportVideo()
 - Functor: Efficient - maps source asset to transformed asset
 - Isomorphism: Preserved - WYSIWYG maintained through VideoTransformBuilder
 - Natural Transformation: Seamless integration with existing VideoTransformBuilder
*/

// MARK: - Video Processing Progress
public struct VideoProcessingProgress {
    let phase: ProcessingPhase
    let progress: Double
    let message: String
    let correlationId: String
    let frameCount: Int?
    let processingTime: TimeInterval

    public enum ProcessingPhase {
        case initializing
        case buildingComposition
        case applyingTransforms
        case validating
        case completed
        case failed(Error)
    }
}

// MARK: - Video Processing Result
public struct VideoProcessingResult {
    let asset: AVAsset
    let playerItem: AVPlayerItem?
    let videoComposition: AVMutableVideoComposition?
    let appliedRotation: Int
    let processingTime: TimeInterval
    let frameCount: Int
    let correlationId: String
}

// MARK: - Video Processor Protocol (Legacy Compatibility)
public protocol VideoProcessor {
    func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int) async throws -> AVAsset
}

// MARK: - Enhanced Video Processor Protocol
@preconcurrency
public protocol EnhancedVideoProcessorProtocol {
    func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange?) async throws -> VideoProcessingResult
    func createPlayerItem(asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange?) async throws -> AVPlayerItem
    func exportVideo(asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange?, to outputURL: URL) async throws -> URL
    var progressPublisher: AnyPublisher<VideoProcessingProgress, Never> { get }
}

// MARK: - Enhanced Video Processor Implementation
@MainActor
@preconcurrency
public final class EnhancedVideoProcessor: EnhancedVideoProcessorProtocol {

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎬 EnhancedVideoProcessor")
    private let memoryLogger = CentralizedMemoryLogger.shared

    // Progress tracking
    private let progressSubject = PassthroughSubject<VideoProcessingProgress, Never>()
    public var progressPublisher: AnyPublisher<VideoProcessingProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // Performance tracking
    private var operationTimings: [String: TimeInterval] = [:]
    private var currentCorrelationId: String?

    // MARK: - Initialization
    public init() {
        // logger.info("🎬 VIDEO_PROCESSOR: 🚀 Initialized - Enhanced video processor with VideoTransformBuilder integration")
    }

    // MARK: - Public API

    /// Process video with enhanced frame-accurate processing
    public func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange? = nil) async throws -> VideoProcessingResult {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        // logger.info("🎬 VIDEO_PROCESSOR: 🚀 Processing video - rotation: \(rotationQuarterTurns), trim: \(trimRange?.start.seconds ?? 0)-\(trimRange?.end.seconds ?? 0)s [\(correlationId)]")
        await reportProgress(.initializing, progress: 0.0, message: "Starting video processing", correlationId: correlationId)

        let startTime = Date()

        do {
            await reportProgress(.buildingComposition, progress: 0.2, message: "Building video composition", correlationId: correlationId)

            // MARK: - CRITICAL: Use existing VideoTransformBuilder for composition
            let (composition, videoComposition) = try await VideoTransformBuilder.build(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns
            )

            await reportProgress(.applyingTransforms, progress: 0.6, message: "Applying video transforms", correlationId: correlationId)

            // Validate the composition
            await reportProgress(.validating, progress: 0.8, message: "Validating processed video", correlationId: correlationId)

            let frameCount = try await validateComposition(composition, correlationId: correlationId)
            let processingTime = Date().timeIntervalSince(startTime)

            // Create player item if needed for preview
            let playerItem = try await VideoTransformBuilder.createPlayerItem(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns
            )

            let result = VideoProcessingResult(
                asset: composition,
                playerItem: playerItem,
                videoComposition: videoComposition,
                appliedRotation: rotationQuarterTurns,
                processingTime: processingTime,
                frameCount: frameCount,
                correlationId: correlationId
            )

            await reportProgress(.completed, progress: 1.0, message: "Video processing completed", correlationId: correlationId)

            await logCompletion(result: result, startTime: startTime)
            return result

        } catch {
            await reportProgress(.failed(error), progress: 0.0, message: "Processing failed: \(error.localizedDescription)", correlationId: correlationId)
            logger.error("🎬 VIDEO_PROCESSOR: ❌ Processing failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Create player item using VideoTransformBuilder
    public func createPlayerItem(asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange?) async throws -> AVPlayerItem {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        // logger.info("🎬 VIDEO_PROCESSOR: 🎯 Creating player item - rotation: \(rotationQuarterTurns), trim: \(trimRange?.start.seconds ?? 0)-\(trimRange?.end.seconds ?? 0)s [\(correlationId)]")

        let startTime = Date()

        do {
            // Use VideoTransformBuilder for consistent player item creation
            let playerItem = try await VideoTransformBuilder.createPlayerItem(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns,
                optimizeForScrubbing: true
            )

            let duration = Date().timeIntervalSince(startTime)
            // logger.info("🎬 VIDEO_PROCESSOR: ✅ Player item created [\(correlationId)] - Duration: \(String(format: "%.2f", duration))s")

            return playerItem

        } catch {
            logger.error("🎬 VIDEO_PROCESSOR: ❌ Player item creation failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Export video using VideoTransformBuilder
    public func exportVideo(asset: AVAsset, rotationQuarterTurns: Int, trimRange: CMTimeRange?, to outputURL: URL) async throws -> URL {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        // logger.info("🎬 VIDEO_PROCESSOR: 💾 Exporting video - rotation: \(rotationQuarterTurns), trim: \(trimRange?.start.seconds ?? 0)-\(trimRange?.end.seconds ?? 0)s [\(correlationId)]")

        let startTime = Date()

        do {
            // Use VideoTransformBuilder for consistent export
            let exportedURL = try await VideoTransformBuilder.exportVideo(
                asset: asset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns,
                outputURL: outputURL
            )

            let duration = Date().timeIntervalSince(startTime)
            // logger.info("🎬 VIDEO_PROCESSOR: ✅ Video exported [\(correlationId)] - Duration: \(String(format: "%.2f", duration))s")

            return exportedURL

        } catch {
            logger.error("🎬 VIDEO_PROCESSOR: ❌ Video export failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Validate composition and return frame count
    private func validateComposition(_ composition: AVMutableComposition, correlationId: String) async throws -> Int {
        // logger.info("🎬 VIDEO_PROCESSOR: 🔍 Validating composition [\(correlationId)]")

        let validationStart = Date()

        // Check video tracks
        let videoTracks = composition.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoProcessingError.noValidVideoTrackFound
        }

        // Check composition duration
        let duration = composition.duration
        guard duration.seconds > 0 else {
            throw VideoProcessingError.videoProcessingFailed(
                operation: "validation",
                underlyingError: NSError(domain: "VideoProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid composition duration"])
            )
        }

        // Estimate frame count based on video track properties
        let frameCount = try await estimateFrameCount(from: videoTracks.first!, duration: duration)

        operationTimings["validation"] = Date().timeIntervalSince(validationStart)

        // logger.info("🎬 VIDEO_PROCESSOR: ✅ Composition validated [\(correlationId)] - Duration: \(duration.seconds)s, Frame count: \(frameCount)")

        return frameCount
    }

    /// Estimate frame count from video track
    private func estimateFrameCount(from videoTrack: AVAssetTrack, duration: CMTime) async throws -> Int {
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        return Int(duration.seconds * Double(frameRate))
    }

    /// Generate correlation ID
    private func generateCorrelationId() -> String {
        return memoryLogger.generateCorrelationId(for: "EnhancedVideoProcessor")
    }

    /// Report progress
    private func reportProgress(_ phase: VideoProcessingProgress.ProcessingPhase, progress: Double, message: String, correlationId: String, frameCount: Int? = nil) async {
        let processingTime = operationTimings["total_processing"] ?? 0.0

        let progress = VideoProcessingProgress(
            phase: phase,
            progress: progress,
            message: message,
            correlationId: correlationId,
            frameCount: frameCount,
            processingTime: processingTime
        )

        progressSubject.send(progress)

        let progressPercentage = Int(progress.progress * 100)
        let phaseString = "\(phase)"
        // logger.info("🎬 VIDEO_PROCESSOR:  Progress [\(correlationId)]: \(phaseString) - \(progressPercentage)% - \(message)")
    }

    /// Log completion
    private func logCompletion(result: VideoProcessingResult, startTime: Date) async {
        let duration = Date().timeIntervalSince(startTime)

        // logger.info("🎬 VIDEO_PROCESSOR: 🏆 COMPLETION [\(result.correlationId)]:")
        // logger.info("🎬 VIDEO_PROCESSOR:   - Processing time: \(String(format: "%.2f", duration))s")
        // logger.info("🎬 VIDEO_PROCESSOR:   - Applied rotation: \(result.appliedRotation) quarter turns")
        // logger.info("🎬 VIDEO_PROCESSOR:   - Frame count: \(result.frameCount)")
        // logger.info("🎬 VIDEO_PROCESSOR:   - Has video composition: \(result.videoComposition != nil)")
        do {
            let assetDuration = try await result.asset.load(.duration).seconds
            // logger.info("🎬 VIDEO_PROCESSOR:   - Asset duration: \(assetDuration)s")
        } catch {
            logger.error("🎬 VIDEO_PROCESSOR: ❌ Failed to load asset duration: \(error)")
            // logger.info("🎬 VIDEO_PROCESSOR:   - Asset duration: unavailable")
        }

        // Log memory state
        memoryLogger.logMemoryState(
            context: "After Video Processing",
            correlationId: result.correlationId,
            component: "EnhancedVideoProcessor"
        )

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "EnhancedVideoProcessor")
        currentCorrelationId = nil
    }
}

// MARK: - Legacy Compatibility
// Extends the existing protocol for backward compatibility
extension EnhancedVideoProcessor: VideoProcessor {
    public func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int) async throws -> AVAsset {
        let result = try await processVideo(asset, rotationQuarterTurns: rotationQuarterTurns, trimRange: nil)
        return result.asset
    }
}