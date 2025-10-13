// import AVFoundation
// import OSLog
// import Combine

// // MARK: - VideoProcessor
// /// Clean service for video processing operations using shared components
// @MainActor
// class VideoProcessor: ObservableObject {
//     private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoProcessor")
//     private let sharedTrimmer: SharedVideoTrimmer
//     private let sharedExporter: SharedVideoExporter

//     // MARK: - Published Properties
//     @Published private(set) var isProcessing = false
//     @Published private(set) var progress = 0.0
//     @Published private(set) var statusMessage = ""

//     init(videoProcessingPipeline: VideoProcessingPipeline) {
//         self.sharedTrimmer = SharedVideoTrimmer(videoProcessingPipeline: videoProcessingPipeline)
//         self.sharedExporter = SharedVideoExporter(videoProcessingPipeline: videoProcessingPipeline)

//         // Observe shared component progress
//         setupProgressObservers()
//     }

//     // MARK: - Progress Observation
//     private func setupProgressObservers() {
//         // Observe trimmer progress
//         sharedTrimmer.$isProcessing
//             .sink { [weak self] isProcessing in
//                 Task { @MainActor in
//                     self?.isProcessing = isProcessing
//                 }
//             }
//             .store(in: &cancellables)

//         sharedTrimmer.$progress
//             .sink { [weak self] progress in
//                 Task { @MainActor in
//                     self?.progress = progress
//                 }
//             }
//             .store(in: &cancellables)

//         sharedTrimmer.$statusMessage
//             .sink { [weak self] statusMessage in
//                 Task { @MainActor in
//                     self?.statusMessage = statusMessage
//                 }
//             }
//             .store(in: &cancellables)

//         // Observe exporter progress
//         sharedExporter.$isExporting
//             .sink { [weak self] isExporting in
//                 Task { @MainActor in
//                     self?.isProcessing = isExporting
//                 }
//             }
//             .store(in: &cancellables)

//         sharedExporter.$progress
//             .sink { [weak self] progress in
//                 Task { @MainActor in
//                     self?.progress = progress
//                 }
//             }
//             .store(in: &cancellables)

//         sharedExporter.$statusMessage
//             .sink { [weak self] statusMessage in
//                 Task { @MainActor in
//                     self?.statusMessage = statusMessage
//                 }
//             }
//             .store(in: &cancellables)
//     }

//     @Published private var cancellables = Set<AnyCancellable>()

//     // MARK: - Processing Methods

//     /// Trim video to specified time range using shared trimmer
//     /// - Parameters:
//     ///   - asset: The source video asset
//     ///   - startTime: Start time in seconds
//     ///   - endTime: End time in seconds
//     ///   - rotationQuarterTurns: Number of 90-degree rotations (0, 1, 2, 3)
//     /// - Returns: Trimmed AVAsset
//     /// - Throws: VideoProcessorError if processing fails
//     func trimVideo(
//         asset: AVAsset,
//         startTime: Double,
//         endTime: Double,
//         rotationQuarterTurns: Int = 0
//     ) async throws -> AVAsset {
//         logger.info("✂️ Starting video trim: \(startTime)s - \(endTime)s, rotation: \(rotationQuarterTurns * 90)°")

//         // Validate input using shared trimmer
//         let duration = try await sharedTrimmer.getVideoDuration(from: asset)
//         try sharedTrimmer.validateTrimRange(
//             startTime: startTime,
//             endTime: endTime,
//             assetDuration: duration
//         )

//         do {
//             // Use shared trimmer for the operation
//             let outputURL = try await sharedTrimmer.trimVideo(
//                 asset: asset,
//                 startTime: startTime,
//                 endTime: endTime,
//                 rotationQuarterTurns: rotationQuarterTurns
//             )

//             // Create the trimmed asset
//             let trimmedAsset = AVAsset(url: outputURL)

//             logger.info("✅ Video trim completed successfully using shared trimmer")
//             return trimmedAsset

//         } catch {
//             logger.error("❌ Video trim failed: \(error.localizedDescription)")
//             throw VideoProcessorError.processingFailed(underlying: error)
//         }
//     }

//     /// Apply rotation to video using shared exporter
//     /// - Parameters:
//     ///   - asset: The source video asset
//     ///   - rotationQuarterTurns: Number of 90-degree rotations (0, 1, 2, 3)
//     /// - Returns: Rotated AVAsset
//     /// - Throws: VideoProcessorError if processing fails
//     func rotateVideo(
//         asset: AVAsset,
//         rotationQuarterTurns: Int
//     ) async throws -> AVAsset {
//         logger.info("🔄 Starting video rotation: \(rotationQuarterTurns * 90)°")

//         // Validate rotation
//         guard (0...3).contains(rotationQuarterTurns) else {
//             throw VideoProcessorError.invalidRotation
//         }

//         do {
//             // Use shared exporter for rotation (full video, no trimming)
//             let outputURL = try await sharedExporter.exportVideo(
//                 asset: asset,
//                 startTime: nil,
//                 endTime: nil,
//                 rotationQuarterTurns: rotationQuarterTurns
//             )

//             let rotatedAsset = AVAsset(url: outputURL)

//             logger.info("✅ Video rotation completed successfully using shared exporter")
//             return rotatedAsset

//         } catch {
//             logger.error("❌ Video rotation failed: \(error.localizedDescription)")
//             throw VideoProcessorError.processingFailed(underlying: error)
//         }
//     }

//     /// Get video duration using shared trimmer
//     /// - Parameter asset: The video asset
//     /// - Returns: Duration in seconds
//     func getVideoDuration(from asset: AVAsset) async throws -> Double {
//         do {
//             return try await sharedTrimmer.getVideoDuration(from: asset)
//         } catch {
//             logger.error("❌ Failed to get video duration: \(error.localizedDescription)")
//             throw VideoProcessorError.failedToGetDuration(underlying: error)
//         }
//     }

//     // MARK: - Public Methods for Integration

//     /// Cancel current processing operation
//     func cancelProcessing() {
//         sharedTrimmer.cancelTrimming()
//         sharedExporter.cancelExport()
//         logger.info("🚫 Video processing cancelled")
//     }

//     /// Reset processor state
//     func reset() {
//         sharedTrimmer.reset()
//         sharedExporter.reset()
//         logger.info("🔄 Video processor reset")
//     }
// }

// // MARK: - VideoProcessorError

// enum VideoProcessorError: LocalizedError {
//     case invalidTimeRange
//     case timeRangeExceedsDuration
//     case invalidRotation
//     case processingFailed(underlying: Error)
//     case failedToGetDuration(underlying: Error)

//     var errorDescription: String? {
//         switch self {
//         case .invalidTimeRange:
//             return "Invalid time range - start time must be less than end time"
//         case .timeRangeExceedsDuration:
//             return "Selected time range exceeds video duration"
//         case .invalidRotation:
//             return "Invalid rotation value - must be 0, 1, 2, or 3"
//         case .processingFailed(let error):
//             return "Video processing failed: \(error.localizedDescription)"
//         case .failedToGetDuration(let error):
//             return "Failed to get video duration: \(error.localizedDescription)"
//         }
//     }

//     var recoverySuggestion: String? {
//         switch self {
//         case .invalidTimeRange:
//             return "Please select a valid time range within the video"
//         case .timeRangeExceedsDuration:
//             return "Please select a time range that fits within the video duration"
//         case .invalidRotation:
//             return "Please select a valid rotation option"
//         case .processingFailed:
//             return "Please try again or select a different video"
//         case .failedToGetDuration:
//             return "Please try selecting the video again"
//         }
//     }
// }