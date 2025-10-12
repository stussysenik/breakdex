import AVFoundation
import Foundation
import Combine

// MARK: - Video Processing Pipeline Protocol
/// Essentialist protocol for video processing operations
/// Enhanced interface to support video trimming and export operations
public protocol VideoProcessingPipeline {
    /// Process a video asset and return the processed result
    func process(asset: AVAsset) async throws -> AVAsset

    /// Export video to URL with optional configuration
    mutating func exportVideo(_ asset: AVAsset, to outputURL: URL, configuration: VideoProcessingConfiguration?) async throws -> URL

    /// Cancel current processing operation
    mutating func cancelCurrentOperation()

    /// Check if processing is currently active
    var isProcessing: Bool { get }
}

// MARK: - Video Processing Result
/// Result of video processing operation - simple and focused
public struct VideoProcessingResult {
    public let processedAsset: AVAsset
    public let duration: TimeInterval
    public let success: Bool
    public let error: Error?

    // Additional properties for compatibility
    public let processingTime: TimeInterval
    public let frameCount: Int
    public var asset: AVAsset { processedAsset } // Alias for compatibility

    public init(
        processedAsset: AVAsset,
        duration: TimeInterval,
        success: Bool,
        error: Error? = nil,
        processingTime: TimeInterval = 0.0,
        frameCount: Int = 0
    ) {
        self.processedAsset = processedAsset
        self.duration = duration
        self.success = success
        self.error = error
        self.processingTime = processingTime
        self.frameCount = frameCount
    }

    /// Successful result
    public static func success(asset: AVAsset, processingTime: TimeInterval = 0.0, frameCount: Int = 0) -> VideoProcessingResult {
        return VideoProcessingResult(
            processedAsset: asset,
            duration: asset.duration.seconds,
            success: true,
            processingTime: processingTime,
            frameCount: frameCount
        )
    }

    /// Failed result
    public static func failure(_ error: Error, processingTime: TimeInterval = 0.0) -> VideoProcessingResult {
        return VideoProcessingResult(
            processedAsset: AVAsset(),
            duration: 0.0,
            success: false,
            error: error,
            processingTime: processingTime
        )
    }
}

// MARK: - Enhanced Video Processor Protocol
/// Extended protocol for enhanced video processing capabilities
public protocol EnhancedVideoProcessorProtocol: VideoProcessingPipeline {
    /// Process with progress reporting
    mutating func process(asset: AVAsset, progressHandler: @escaping (Double) async -> Void) async throws -> AVAsset

    /// Process with custom parameters
    func process(asset: AVAsset, startTime: TimeInterval, endTime: TimeInterval) async throws -> AVAsset

    /// Process video (compatibility method)
    mutating func processVideo(_ asset: AVAsset, configuration: VideoProcessingConfiguration?) async throws -> VideoProcessingResult

    /// Check if processor can handle the given asset
    func canProcess(asset: AVAsset) -> Bool

    /// Progress publisher for observing progress updates
    var progressPublisher: AsyncPublisher<AnyPublisher<Double, Never>> { get }
}

// MARK: - Video Processing Operation Types
/// Types of video processing operations supported
public enum VideoProcessingOperation {
    case trim
    case compress
    case resize
    case filter
    case export

    public var displayName: String {
        switch self {
        case .trim: return "Trim"
        case .compress: return "Compress"
        case .resize: return "Resize"
        case .filter: return "Filter"
        case .export: return "Export"
        }
    }
}

// MARK: - Video Processing Configuration
/// Simple configuration for video processing
public struct VideoProcessingConfiguration {
    public let operation: VideoProcessingOperation
    public let startTime: TimeInterval?
    public let endTime: TimeInterval?
    public let outputSize: CGSize?
    public let compressionQuality: Float

    public init(
        operation: VideoProcessingOperation,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        outputSize: CGSize? = nil,
        compressionQuality: Float = 0.8
    ) {
        self.operation = operation
        self.startTime = startTime
        self.endTime = endTime
        self.outputSize = outputSize
        self.compressionQuality = compressionQuality
    }

    /// Trimming configuration
    public static func trim(startTime: TimeInterval, endTime: TimeInterval) -> VideoProcessingConfiguration {
        return VideoProcessingConfiguration(
            operation: .trim,
            startTime: startTime,
            endTime: endTime
        )
    }

    /// Compression configuration
    public static func compress(quality: Float = 0.8) -> VideoProcessingConfiguration {
        return VideoProcessingConfiguration(
            operation: .compress,
            compressionQuality: quality
        )
    }
}

// MARK: - Video Asset Extensions
extension AVAsset {
    /// Duration in seconds (convenience)
    var durationInSeconds: TimeInterval {
        return CMTimeGetSeconds(self.duration)
    }

    /// Check if asset is video
    var isVideo: Bool {
        return tracks(withMediaType: .video).count > 0
    }

    /// Check if asset is audio
    var isAudio: Bool {
        return tracks(withMediaType: .audio).count > 0
    }

    /// Natural size of the video
    var naturalSize: CGSize {
        guard let videoTrack = tracks(withMediaType: .video).first else {
            return .zero
        }
        return videoTrack.naturalSize
    }
}

