// import AVFoundation
// import OSLog
// import SwiftUI

// // MARK: - Shared Video Trimmer
// /// Clean, reusable video trimming component for consistent trimming operations
// @MainActor
// public class SharedVideoTrimmer: ObservableObject {
//     // MARK: - Published Properties
//     @Published public private(set) var isProcessing = false
//     @Published public private(set) var progress: Double = 0.0
//     @Published public private(set) var statusMessage = ""
//     @Published public private(set) var trimmedVideoURL: URL?
//     @Published public private(set) var errorMessage: String?

//     // MARK: - Private Properties
//     private let logger = Logger(subsystem: "com.breakingflashcards", category: "SharedVideoTrimmer")
//     private var videoProcessingPipeline: VideoProcessingPipeline

//     // MARK: - Trimming Configuration
//     public struct TrimConfiguration {
//         let startTime: Double
//         let endTime: Double
//         let rotationQuarterTurns: Int
//         let outputURL: URL?

//         public init(startTime: Double, endTime: Double, rotationQuarterTurns: Int = 0, outputURL: URL? = nil) {
//             self.startTime = startTime
//             self.endTime = endTime
//             self.rotationQuarterTurns = rotationQuarterTurns
//             self.outputURL = outputURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("trimmed-\(UUID().uuidString).mov")
//         }

//         public var trimRange: CMTimeRange {
//             let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
//             let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
//             return CMTimeRange(start: startCMTime, end: endCMTime)
//         }

//         public var duration: Double {
//             return max(0, endTime - startTime)
//         }
//     }

//     // MARK: - Initialization
//     public init(videoProcessingPipeline: VideoProcessingPipeline) {
//         self.videoProcessingPipeline = videoProcessingPipeline
//         logger.info("✂️ SharedVideoTrimmer initialized")
//     }

//     // MARK: - Public Methods

//     /// Trim video with specified configuration
//     /// - Parameter configuration: Trim configuration including time range and rotation
//     /// - Returns: URL of the trimmed video
//     /// - Throws: VideoTrimmerError if trimming fails
//     public func trimVideo(_ configuration: TrimConfiguration) async throws -> URL {
//         logger.info("✂️ Starting video trim: \(configuration.startTime)s - \(configuration.endTime)s, rotation: \(configuration.rotationQuarterTurns * 90)°")

//         await MainActor.run {
//             isProcessing = true
//             progress = 0.0
//             statusMessage = "Preparing trim operation..."
//             errorMessage = nil
//             trimmedVideoURL = nil
//         }

//         // Validate configuration
//         try await validateTrimConfiguration(configuration)

//         do {
//             await updateProgress(0.2, status: "Setting up trim operation...")

//             // Perform the trim using the video processing pipeline
//             let outputURL = try await videoProcessingPipeline.exportVideo(
//                 try await getAssetFromConfiguration(configuration),
//                 to: configuration.outputURL!,
//                 configuration: VideoProcessingConfiguration.trim(
//                     startTime: configuration.startTime,
//                     endTime: configuration.endTime
//                 )
//             )

//             await updateProgress(0.9, status: "Finalizing trimmed video...")

//             // Validate the output
//             guard FileManager.default.fileExists(atPath: outputURL.path) else {
//                 throw VideoTrimmerError.outputFileNotFound
//             }

//             await updateProgress(1.0, status: "Video trimmed successfully")

//             await MainActor.run {
//                 self.trimmedVideoURL = outputURL
//                 logger.info("✅ Video trim completed successfully: \(outputURL.lastPathComponent)")
//             }

//             return outputURL

//         } catch {
//             await MainActor.run {
//                 isProcessing = false
//                 statusMessage = "Trimming failed: \(error.localizedDescription)"
//                 errorMessage = error.localizedDescription
//                 logger.error("❌ Video trim failed: \(error.localizedDescription)")
//             }
//             throw VideoTrimmerError.trimmingFailed(underlying: error)
//         }
//     }

//     /// Trim video with simple parameters
//     /// - Parameters:
//     ///   - asset: The source video asset
//     ///   - startTime: Start time in seconds
//     ///   - endTime: End time in seconds
//     ///   - rotationQuarterTurns: Number of 90-degree rotations (0, 1, 2, 3)
//     /// - Returns: URL of the trimmed video
//     /// - Throws: VideoTrimmerError if trimming fails
//     public func trimVideo(
//         asset: AVAsset,
//         startTime: Double,
//         endTime: Double,
//         rotationQuarterTurns: Int = 0
//     ) async throws -> URL {
//         let configuration = TrimConfiguration(
//             startTime: startTime,
//             endTime: endTime,
//             rotationQuarterTurns: rotationQuarterTurns
//         )

//         return try await trimVideoWithAsset(asset, configuration: configuration)
//     }

//     /// Get video duration from asset
//     /// - Parameter asset: The video asset
//     /// - Returns: Duration in seconds
//     /// - Throws: VideoTrimmerError if duration cannot be retrieved
//     public func getVideoDuration(from asset: AVAsset) async throws -> Double {
//         do {
//             let duration = try await asset.load(.duration)
//             return duration.seconds
//         } catch {
//             logger.error("❌ Failed to get video duration: \(error.localizedDescription)")
//             throw VideoTrimmerError.failedToGetDuration(underlying: error)
//         }
//     }

//     /// Validate trim range for a given asset
//     /// - Parameters:
//     ///   - startTime: Start time in seconds
//     ///   - endTime: End time in seconds
//     ///   - assetDuration: Duration of the video asset
//     /// - Throws: VideoTrimmerError if range is invalid
//     public func validateTrimRange(startTime: Double, endTime: Double, assetDuration: Double) throws {
//         guard startTime < endTime else {
//             throw VideoTrimmerError.invalidTimeRange
//         }

//         guard startTime >= 0 else {
//             throw VideoTrimmerError.invalidStartTime
//         }

//         guard endTime <= assetDuration else {
//             throw VideoTrimmerError.timeRangeExceedsDuration
//         }

//         guard endTime - startTime >= 0.5 else {
//             throw VideoTrimmerError.trimTooShort
//         }
//     }

//     /// Cancel current trimming operation
//     public func cancelTrimming() {
//         logger.info("🚫 Cancelling trim operation")
//         videoProcessingPipeline.cancelCurrentOperation()

//         Task { @MainActor in
//             isProcessing = false
//             statusMessage = "Trimming cancelled"
//             progress = 0.0
//         }
//     }

//     /// Reset trimmer state
//     public func reset() {
//         Task { @MainActor in
//             isProcessing = false
//             progress = 0.0
//             statusMessage = ""
//             trimmedVideoURL = nil
//             errorMessage = nil
//         }
//     }

//     // MARK: - Private Methods

//     private func trimVideoWithAsset(_ asset: AVAsset, configuration: TrimConfiguration) async throws -> URL {
//         // This method would need to be implemented to work with an existing asset
//         // For now, we'll throw an error indicating this needs to be implemented
//         // based on how the VideoProcessingPipeline is designed
//         throw VideoTrimmerError.notImplemented
//     }

//     private func validateTrimConfiguration(_ configuration: TrimConfiguration) async throws {
//         // Validate time range
//         guard configuration.startTime < configuration.endTime else {
//             throw VideoTrimmerError.invalidTimeRange
//         }

//         guard configuration.startTime >= 0 else {
//             throw VideoTrimmerError.invalidStartTime
//         }

//         guard configuration.rotationQuarterTurns >= 0 && configuration.rotationQuarterTurns <= 3 else {
//             throw VideoTrimmerError.invalidRotation
//         }

//         guard configuration.duration >= 0.5 else {
//             throw VideoTrimmerError.trimTooShort
//         }
//     }

//     private func getAssetFromConfiguration(_ configuration: TrimConfiguration) async throws -> AVAsset {
//         // This would need to be implemented based on how assets are provided
//         // For now, this is a placeholder
//         throw VideoTrimmerError.notImplemented
//     }

//     private func updateProgress(_ progress: Double, status: String) async {
//         await MainActor.run {
//             self.progress = progress
//             self.statusMessage = status

//             if progress >= 1.0 {
//                 isProcessing = false
//             }
//         }
//     }
// }

// // MARK: - VideoTrimmerError
// public enum VideoTrimmerError: LocalizedError {
//     case invalidTimeRange
//     case invalidStartTime
//     case timeRangeExceedsDuration
//     case trimTooShort
//     case invalidRotation
//     case outputFileNotFound
//     case trimmingFailed(underlying: Error)
//     case failedToGetDuration(underlying: Error)
//     case notImplemented

//     public var errorDescription: String? {
//         switch self {
//         case .invalidTimeRange:
//             return "Invalid time range - start time must be less than end time"
//         case .invalidStartTime:
//             return "Invalid start time - must be 0 or greater"
//         case .timeRangeExceedsDuration:
//             return "Selected time range exceeds video duration"
//         case .trimTooShort:
//             return "Trimmed video is too short - minimum 0.5 seconds"
//         case .invalidRotation:
//             return "Invalid rotation - must be 0, 1, 2, or 3 (90-degree increments)"
//         case .outputFileNotFound:
//             return "Trimmed video file was not created"
//         case .trimmingFailed(let error):
//             return "Video trimming failed: \(error.localizedDescription)"
//         case .failedToGetDuration(let error):
//             return "Failed to get video duration: \(error.localizedDescription)"
//         case .notImplemented:
//             return "This trimming method is not yet implemented"
//         }
//     }

//     public var recoverySuggestion: String? {
//         switch self {
//         case .invalidTimeRange:
//             return "Please select a valid time range where start is before end"
//         case .invalidStartTime:
//             return "Please select a start time of 0 seconds or greater"
//         case .timeRangeExceedsDuration:
//             return "Please select a time range within the video duration"
//         case .trimTooShort:
//             return "Please select a longer trim range (minimum 0.5 seconds)"
//         case .invalidRotation:
//             return "Please select a valid rotation option"
//         case .outputFileNotFound:
//             return "Please try trimming again or check available storage space"
//         case .trimmingFailed:
//             return "Please try again or select a different video"
//         case .failedToGetDuration:
//             return "Please try selecting the video again"
//         case .notImplemented:
//             return "Please use an alternative trimming method"
//         }
//     }
// }

// // MARK: - Convenience Extensions
// public extension SharedVideoTrimmer {
//     /// Create a trim configuration for full video (no trimming)
//     /// - Parameter asset: The video asset
//     /// - Returns: Trim configuration for full video
//     func createFullVideoConfiguration(from asset: AVAsset) async throws -> TrimConfiguration {
//         let duration = try await getVideoDuration(from: asset)
//         return TrimConfiguration(
//             startTime: 0,
//             endTime: duration,
//             rotationQuarterTurns: 0
//         )
//     }

//     /// Create a trim configuration with safe defaults
//     /// - Parameters:
//     ///   - asset: The video asset
//     ///   - startTime: Start time in seconds
//     ///   - endTime: End time in seconds
//     /// - Returns: Validated trim configuration
//     /// - Throws: VideoTrimmerError if parameters are invalid
//     func createSafeTrimConfiguration(
//         from asset: AVAsset,
//         startTime: Double,
//         endTime: Double,
//         rotationQuarterTurns: Int = 0
//     ) async throws -> TrimConfiguration {
//         let assetDuration = try await getVideoDuration(from: asset)

//         // Clamp times to valid range
//         let clampedStartTime = max(0, min(startTime, assetDuration - 0.5))
//         let clampedEndTime = max(clampedStartTime + 0.5, min(endTime, assetDuration))

//         return TrimConfiguration(
//             startTime: clampedStartTime,
//             endTime: clampedEndTime,
//             rotationQuarterTurns: rotationQuarterTurns
//         )
//     }
// }