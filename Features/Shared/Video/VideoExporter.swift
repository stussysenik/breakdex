import AVFoundation
import OSLog
import SwiftUI

// MARK: - Shared Video Exporter
/// Clean, reusable video export component for consistent export operations
@MainActor
public class SharedVideoExporter: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var isExporting = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var statusMessage = ""
    @Published public private(set) var exportedVideoURL: URL?
    @Published public private(set) var errorMessage: String?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SharedVideoExporter")
    private var videoProcessingPipeline: VideoProcessingPipeline
    private var exportTask: Task<URL, Error>?

    // MARK: - Export Configuration
    public struct ExportConfiguration {
        let asset: AVAsset
        let outputURL: URL
        let trimRange: CMTimeRange?
        let rotationQuarterTurns: Int
        let outputFileType: AVFileType
        let quality: ExportQuality

        public enum ExportQuality {
            case low      // ~500 kbps
            case medium   // ~1 Mbps
            case high     // ~2 Mbps
            case original // Preserve original quality

            var bitrate: Float {
                switch self {
                case .low: return 500_000
                case .medium: return 1_000_000
                case .high: return 2_000_000
                case .original: return 0 // Use source bitrate
                }
            }

            var description: String {
                switch self {
                case .low: return "Low (500 kbps)"
                case .medium: return "Medium (1 Mbps)"
                case .high: return "High (2 Mbps)"
                case .original: return "Original"
                }
            }
        }

        public init(
            asset: AVAsset,
            outputURL: URL? = nil,
            trimRange: CMTimeRange? = nil,
            rotationQuarterTurns: Int = 0,
            outputFileType: AVFileType = .mov,
            quality: ExportQuality = .original
        ) {
            self.asset = asset
            self.outputURL = outputURL ?? Self.generateUniqueOutputURL()
            self.trimRange = trimRange
            self.rotationQuarterTurns = rotationQuarterTurns
            self.outputFileType = outputFileType
            self.quality = quality
        }

        private static func generateUniqueOutputURL() -> URL {
            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "exported-video-\(timestamp).mov"
            return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        }

        var hasTrimming: Bool {
            return trimRange != nil
        }

        var hasRotation: Bool {
            return rotationQuarterTurns > 0
        }
    }

    // MARK: - Initialization
    public init(videoProcessingPipeline: VideoProcessingPipeline) {
        self.videoProcessingPipeline = videoProcessingPipeline
        logger.info("📤 SharedVideoExporter initialized")
    }

    deinit {
        // Safely cancel export in deinit
        Task { @MainActor in
            self.cancelExport()
        }
    }

    // MARK: - Public Methods

    /// Export video with specified configuration
    /// - Parameter configuration: Export configuration
    /// - Returns: URL of the exported video
    /// - Throws: VideoExporterError if export fails
    public func exportVideo(_ configuration: ExportConfiguration) async throws -> URL {
        logger.info("📤 Starting video export with configuration:")
        logger.info("   - Quality: \(configuration.quality.description)")
        logger.info("   - Has trimming: \(configuration.hasTrimming)")
        logger.info("   - Has rotation: \(configuration.hasRotation)")

        await MainActor.run {
            isExporting = true
            progress = 0.0
            statusMessage = "Preparing export..."
            errorMessage = nil
            exportedVideoURL = nil
        }

        // Validate configuration
        try await validateExportConfiguration(configuration)

        // Cancel any existing export
        cancelExport()

        do {
            await updateProgress(0.1, status: "Validating video asset...")

            // Validate asset
            let assetDuration = try await configuration.asset.load(.duration)
            guard assetDuration.seconds > 0 else {
                throw VideoExporterError.invalidAsset
            }

            await updateProgress(0.2, status: "Setting up export...")

            // Determine effective trim range
            let effectiveTrimRange = configuration.trimRange ?? CMTimeRange(start: .zero, end: assetDuration)

            // Perform export
            let exportURL = try await videoProcessingPipeline.exportVideo(
                configuration.asset,
                to: configuration.outputURL,
                configuration: VideoProcessingConfiguration(
                    operation: .trim,
                    startTime: effectiveTrimRange.start.seconds,
                    endTime: effectiveTrimRange.end.seconds
                )
            )

            await updateProgress(0.9, status: "Finalizing export...")

            // Validate output
            guard FileManager.default.fileExists(atPath: exportURL.path) else {
                throw VideoExporterError.exportFailed(reason: "Output file not found")
            }

            // Get file info for logging
            let attributes = try? FileManager.default.attributesOfItem(atPath: exportURL.path)
            let fileSize: Int64 = (attributes?[.size] as? Int64) ?? 0

            await updateProgress(1.0, status: "Export completed successfully")

            await MainActor.run {
                self.exportedVideoURL = exportURL
                logger.info("✅ Video export completed successfully:")
                logger.info("   - File: \(exportURL.lastPathComponent)")
                logger.info("   - Size: \(String(format: "%.2f", Double(fileSize) / (1024 * 1024))) MB")
                logger.info("   - Quality: \(configuration.quality.description)")
            }

            return exportURL

        } catch {
            await MainActor.run {
                isExporting = false
                statusMessage = "Export failed: \(error.localizedDescription)"
                errorMessage = error.localizedDescription
                logger.error("❌ Video export failed: \(error.localizedDescription)")
            }
            throw VideoExporterError.exportFailed(reason: error.localizedDescription)
        }
    }

    /// Export video with simple parameters
    /// - Parameters:
    ///   - asset: The video asset to export
    ///   - startTime: Start time in seconds (optional)
    ///   - endTime: End time in seconds (optional)
    ///   - rotationQuarterTurns: Number of 90-degree rotations (optional)
    ///   - quality: Export quality (optional)
    /// - Returns: URL of the exported video
    /// - Throws: VideoExporterError if export fails
    public func exportVideo(
        asset: AVAsset,
        startTime: Double? = nil,
        endTime: Double? = nil,
        rotationQuarterTurns: Int = 0,
        quality: ExportConfiguration.ExportQuality = .original
    ) async throws -> URL {
        let trimRange: CMTimeRange?

        if let startTime = startTime, let endTime = endTime {
            let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
            let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
            trimRange = CMTimeRange(start: startCMTime, end: endCMTime)
        } else {
            trimRange = nil
        }

        let configuration = ExportConfiguration(
            asset: asset,
            trimRange: trimRange,
            rotationQuarterTurns: rotationQuarterTurns,
            quality: quality
        )

        return try await exportVideo(configuration)
    }

    /// Export full video without trimming or rotation
    /// - Parameters:
    ///   - asset: The video asset to export
    ///   - quality: Export quality (optional)
    /// - Returns: URL of the exported video
    /// - Throws: VideoExporterError if export fails
    public func exportFullVideo(
        asset: AVAsset,
        quality: ExportConfiguration.ExportQuality = .original
    ) async throws -> URL {
        return try await exportVideo(
            asset: asset,
            quality: quality
        )
    }

    /// Get estimated export time for configuration
    /// - Parameter configuration: Export configuration
    /// - Returns: Estimated export time in seconds
    public func getEstimatedExportTime(for configuration: ExportConfiguration) async throws -> Double {
        let assetDuration = try await configuration.asset.load(.duration)
        let effectiveDuration = configuration.trimRange?.duration.seconds ?? assetDuration.seconds

        // Rough estimate: 1 second of video takes 0.2-0.5 seconds to export
        // depending on quality and processing requirements
        let baseTime = effectiveDuration * 0.3

        // Add time for quality processing
        let qualityMultiplier: Double
        switch configuration.quality {
        case .low: qualityMultiplier = 0.5
        case .medium: qualityMultiplier = 1.0
        case .high: qualityMultiplier = 1.5
        case .original: qualityMultiplier = 1.2
        }

        // Add time for trimming and rotation
        let processingTime = configuration.hasTrimming ? 2.0 : 0.0
        let rotationTime = configuration.hasRotation ? 1.0 : 0.0

        return (baseTime * qualityMultiplier) + processingTime + rotationTime
    }

    /// Get estimated file size for configuration
    /// - Parameter configuration: Export configuration
    /// - Returns: Estimated file size in bytes
    public func getEstimatedFileSize(for configuration: ExportConfiguration) async throws -> Int64 {
        let assetDuration = try await configuration.asset.load(.duration)
        let effectiveDuration = configuration.trimRange?.duration.seconds ?? assetDuration.seconds

        // Estimate based on quality and duration
        let bitratePerSecond: Double
        switch configuration.quality {
        case .low: bitratePerSecond = 500_000 / 8 // 500 kbps in bytes
        case .medium: bitratePerSecond = 1_000_000 / 8 // 1 Mbps in bytes
        case .high: bitratePerSecond = 2_000_000 / 8 // 2 Mbps in bytes
        case .original: bitratePerSecond = 3_000_000 / 8 // Rough estimate for original
        }

        return Int64(effectiveDuration * bitratePerSecond)
    }

    /// Cancel current export operation
    public func cancelExport() {
        guard exportTask != nil else { return }

        logger.info("🚫 Cancelling export operation")
        exportTask?.cancel()
        videoProcessingPipeline.cancelCurrentOperation()

        Task { @MainActor in
            isExporting = false
            statusMessage = "Export cancelled"
            progress = 0.0
        }
    }

    /// Reset exporter state
    public func reset() {
        cancelExport()

        Task { @MainActor in
            isExporting = false
            progress = 0.0
            statusMessage = ""
            exportedVideoURL = nil
            errorMessage = nil
        }
    }

    // MARK: - Private Methods

    private func validateExportConfiguration(_ configuration: ExportConfiguration) async throws {
        // Validate asset
        let assetDuration = try await configuration.asset.load(.duration)
        guard assetDuration.seconds > 0 else {
            throw VideoExporterError.invalidAsset
        }

        // Validate trim range
        if let trimRange = configuration.trimRange {
            guard trimRange.start >= .zero else {
                throw VideoExporterError.invalidTrimRange
            }

            guard trimRange.end <= assetDuration else {
                throw VideoExporterError.trimRangeExceedsDuration
            }

            guard trimRange.duration.seconds > 0 else {
                throw VideoExporterError.invalidTrimRange
            }
        }

        // Validate rotation
        guard configuration.rotationQuarterTurns >= 0 && configuration.rotationQuarterTurns <= 3 else {
            throw VideoExporterError.invalidRotation
        }

        // Validate output URL
        let outputDir = configuration.outputURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: outputDir.path) else {
            throw VideoExporterError.invalidOutputURL
        }
    }

    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            self.progress = progress
            self.statusMessage = status

            if progress >= 1.0 {
                isExporting = false
            }
        }
    }
}

// MARK: - VideoExporterError
public enum VideoExporterError: LocalizedError {
    case invalidAsset
    case invalidTrimRange
    case trimRangeExceedsDuration
    case invalidRotation
    case invalidOutputURL
    case exportFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidAsset:
            return "Invalid video asset - asset has no duration or is not playable"
        case .invalidTrimRange:
            return "Invalid trim range - check start and end times"
        case .trimRangeExceedsDuration:
            return "Trim range exceeds video duration"
        case .invalidRotation:
            return "Invalid rotation - must be 0, 1, 2, or 3 (90-degree increments)"
        case .invalidOutputURL:
            return "Invalid output URL - directory does not exist"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidAsset:
            return "Please select a valid video file"
        case .invalidTrimRange:
            return "Please select a valid time range within the video"
        case .trimRangeExceedsDuration:
            return "Please select a trim range that fits within the video duration"
        case .invalidRotation:
            return "Please select a valid rotation option"
        case .invalidOutputURL:
            return "Please check that the output directory exists and is writable"
        case .exportFailed:
            return "Please try again or check available storage space"
        }
    }
}

// MARK: - Convenience Extensions
public extension SharedVideoExporter {
    /// Create export configuration for common use cases
    struct PresetConfigurations {
        /// Configuration for sharing (medium quality, reasonable file size)
        public static func forSharing(asset: AVAsset) -> ExportConfiguration {
            return ExportConfiguration(
                asset: asset,
                quality: .medium
            )
        }

        /// Configuration for backup (original quality)
        public static func forBackup(asset: AVAsset) -> ExportConfiguration {
            return ExportConfiguration(
                asset: asset,
                quality: .original
            )
        }

        /// Configuration for preview (low quality, small file size)
        public static func forPreview(asset: AVAsset) -> ExportConfiguration {
            return ExportConfiguration(
                asset: asset,
                quality: .low
            )
        }

        /// Configuration for social media (high quality)
        public static func forSocialMedia(asset: AVAsset) -> ExportConfiguration {
            return ExportConfiguration(
                asset: asset,
                quality: .high
            )
        }
    }
}