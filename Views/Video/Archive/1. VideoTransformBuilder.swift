import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoTransformBuilder")

/// Shared video composition builder that handles rotation and trimming transforms
/// Implements T · R(θ) · R_src where R_src is preferredTransform, R(θ) is quarter-turn rotation, and T is translation
@MainActor
final class VideoTransformBuilder {

    /// Builds AVMutableComposition and AVMutableVideoComposition with rotation and trimming applied
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional, if nil uses full duration)
    ///   - quarterTurns: Number of quarter turns (0, 1, 2, 3 for 0°, 90°, 180°, 270°)
    /// - Returns: Tuple containing the composition and video composition
    static func build(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition) {
        let buildTrimRangeDesc: String
        if let buildTrimRange = trimRange {
            buildTrimRangeDesc = "start: \(buildTrimRange.start.seconds), duration: \(buildTrimRange.duration.seconds)"
        } else {
            buildTrimRangeDesc = "nil"
        }

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: build() called")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Asset type: \(type(of: asset))")
        let assetDuration: CMTime = try await asset.load(.duration)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Asset duration: \(assetDuration.seconds) seconds")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Quarter turns: \(quarterTurns)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Trim range: \(buildTrimRangeDesc)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        // Log performance metrics
        logPerformanceMetrics("build_start")

        // Step 1: Create mutable composition
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 1 - Creating mutable composition")
        let composition = AVMutableComposition()

        // Step 2: Determine time range to use
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 2 - Determining time range")
        let timeRange: CMTimeRange
        if let trimRange = trimRange {
            timeRange = trimRange
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Using provided trim range")
        } else {
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: No trim range provided, loading asset duration")
            let duration = try await asset.load(.duration)
            timeRange = CMTimeRange(start: .zero, duration: duration)
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Asset duration: \(duration.seconds) seconds")
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Final time range: start=\(timeRange.start.seconds), duration=\(timeRange.duration.seconds)")

        // Step 3: Insert time range into composition
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 3 - Inserting time range into composition")
        try await composition.insertTimeRange(timeRange, of: asset, at: .zero)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Time range inserted successfully")

        // Step 4: Get video track from composition
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 4 - Loading video tracks from composition")
        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Found \(videoTracks.count) video tracks")

        guard let videoTrack = videoTracks.first else {
            logger.error("🎬 VIDEO_TRANSFORM_BUILDER: No video track found in composition")
            throw NSError(domain: "VideoTransformBuilder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Video track not found"])
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Video track acquired successfully")

        // Step 5: Load track properties
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 5 - Loading track properties")
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let naturalSizeString: String = "width: \(naturalSize.width), height: \(naturalSize.height)"
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Natural size: \(naturalSizeString)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Preferred transform: \(String(describing: preferredTransform))")

        // Step 6: Validate inputs
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 6 - Validating inputs")
        guard naturalSize.width > 0 && naturalSize.height > 0 else {
            let invalidSizeString: String = "width: \(naturalSize.width), height: \(naturalSize.height)"
            logger.error("🎬 VIDEO_TRANSFORM_BUILDER: Invalid video dimensions: \(invalidSizeString)")
            throw NSError(domain: "VideoTransformBuilder", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid video dimensions: \(naturalSize)"])
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Video dimensions validated successfully")

        // Step 7: Compute transforms according to spec: T · R(θ) · R_src
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 7 - Computing rotation transforms")
        let Rsrc = preferredTransform
        let (Ruser, translation, renderSize) = computeRotationTransforms(quarterTurns: quarterTurns, naturalSize: naturalSize)

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Transform components:")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Rsrc (preferredTransform): \(String(describing: Rsrc))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Ruser (rotation): \(String(describing: Ruser))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   translation: \(String(describing: translation))")
        let renderSizeString: String = "width: \(renderSize.width), height: \(renderSize.height)"
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   renderSize: \(renderSizeString)")

        // Step 8: Apply source transform + user rotation + translation for correct positioning
        // For 90° rotation: after rotation, content needs to be translated to be visible
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 8 - Applying transforms for positioning")
        let rotationTransform = Rsrc.concatenating(Ruser)

        var translationX: CGFloat = 0
        var translationY: CGFloat = 0

        switch quarterTurns {
        case 1: // 90° clockwise - translate right by original height
            translationX = naturalSize.height
            translationY = 0
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: 90° rotation - translating by height")
        case 2: // 180° - translate by width and height
            translationX = naturalSize.width
            translationY = naturalSize.height
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: 180° rotation - translating by width and height")
        case 3: // 270° clockwise - translate down by original width
            translationX = 0
            translationY = naturalSize.width
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: 270° rotation - translating by width")
        default: // 0° - no translation needed
            translationX = 0
            translationY = 0
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: 0° rotation - no translation needed")
        }

        let positionTransform = CGAffineTransform(translationX: translationX, y: translationY)
        let finalTransform = rotationTransform.concatenating(positionTransform)

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Rotation transform: \(String(describing: rotationTransform))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Position translation: (\(translationX), \(translationY))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Final transform: \(String(describing: finalTransform))")

        // Step 9: Create layer instruction
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 9 - Creating layer instruction")
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Layer instruction created with final transform")

        // Step 10: Create video composition instruction
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 10 - Creating video composition instruction")
        let mainInstruction = AVMutableVideoCompositionInstruction()
        let compDuration = try await composition.load(.duration)
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: compDuration)
        mainInstruction.layerInstructions = [layerInstruction]
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Composition duration: \(compDuration.seconds) seconds")

        // Step 11: Create video composition
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Step 11 - Creating video composition")
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: ✅ Build completed successfully")
        let renderSizeDesc: String = "width: \(renderSize.width), height: \(renderSize.height)"
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Render size: \(renderSizeDesc)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Quarter turns: \(quarterTurns)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Frame duration: \(videoComposition.frameDuration.seconds) seconds")

        // Log performance metrics at completion
        logPerformanceMetrics("build_complete")

        return (composition, videoComposition)
    }

    /// Computes the rotation transforms and render size for the given quarter turns
    /// - Parameters:
    ///   - quarterTurns: Number of quarter turns (0, 1, 2, 3)
    ///   - naturalSize: The natural size of the video track
    /// - Returns: Tuple containing R(θ), T, and renderSize
    private static func computeRotationTransforms(quarterTurns: Int, naturalSize: CGSize) -> (rotation: CGAffineTransform, translation: CGAffineTransform, renderSize: CGSize) {
        let normalizedQuarterTurns = ((quarterTurns % 4) + 4) % 4 // Ensure positive modulo
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: computeRotationTransforms called")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Input quarterTurns: \(quarterTurns), normalized: \(normalizedQuarterTurns)")
        let naturalSizeDesc: String = "width: \(naturalSize.width), height: \(naturalSize.height)"
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Natural size: \(naturalSizeDesc)")

        switch normalizedQuarterTurns {
        case 0: // 0°
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Case 0: 0° rotation - identity transforms")
            return (.identity, .identity, naturalSize)
        case 1: // 90° clockwise
            let rotation = CGAffineTransform(rotationAngle: .pi / 2)
            let translation = CGAffineTransform(translationX: naturalSize.height, y: 0)
            let renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Case 1: 90° clockwise")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Rotation: \(String(describing: rotation))")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Translation: \(String(describing: translation))")
            let renderSizeDesc: String = "width: \(renderSize.width), height: \(renderSize.height)"
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Render size: \(renderSizeDesc)")
            return (rotation, translation, renderSize)
        case 2: // 180°
            let rotation = CGAffineTransform(rotationAngle: .pi)
            let translation = CGAffineTransform(translationX: naturalSize.width, y: naturalSize.height)
            let renderSize = naturalSize
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Case 2: 180° rotation")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Rotation: \(String(describing: rotation))")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Translation: \(String(describing: translation))")
            let renderSizeDesc2: String = "width: \(renderSize.width), height: \(renderSize.height)"
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Render size: \(renderSizeDesc2)")
            return (rotation, translation, renderSize)
        case 3: // 270° clockwise
            let rotation = CGAffineTransform(rotationAngle: .pi * 3 / 2)
            let translation = CGAffineTransform(translationX: 0, y: naturalSize.width)
            let renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Case 3: 270° clockwise")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Rotation: \(String(describing: rotation))")
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Translation: \(String(describing: translation))")
            let renderSizeDesc3: String = "width: \(renderSize.width), height: \(renderSize.height)"
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER:   Render size: \(renderSizeDesc3)")
            return (rotation, translation, renderSize)
        default:
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Default case: identity transforms")
            return (.identity, .identity, naturalSize)
        }
    }

    /// Creates an AVPlayerItem configured with the video composition for preview
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional)
    ///   - quarterTurns: Number of quarter turns
    /// - Returns: Configured AVPlayerItem ready for playback
    static func createPlayerItem(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int) async throws -> AVPlayerItem {
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: createPlayerItem called")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Asset type: \(type(of: asset))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Quarter turns: \(quarterTurns)")

        let trimRangeDesc: String
        if let trimRange = trimRange {
            trimRangeDesc = "start: \(trimRange.start.seconds), duration: \(trimRange.duration.seconds)"
        } else {
            trimRangeDesc = "nil"
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Trim range: \(trimRangeDesc)")

        let (composition, videoComposition): (AVMutableComposition, AVMutableVideoComposition)

        if quarterTurns == 0 {
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: No rotation needed, using simple composition")
            (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)
        } else {
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Rotation needed, using transformed composition")
            (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)
        }

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Creating AVPlayerItem")
        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition
        playerItem.seekingWaitsForVideoCompositionRendering = true

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: AVPlayerItem created successfully")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Video composition assigned: \(videoComposition != nil)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Seeking waits for rendering: \(playerItem.seekingWaitsForVideoCompositionRendering)")

        return playerItem
    }

    /// Exports video with rotation and trimming applied
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional)
    ///   - quarterTurns: Number of quarter turns
    ///   - outputURL: Where to save the exported video
    /// - Returns: URL of the exported video
    static func exportVideo(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int, outputURL: URL) async throws -> URL {
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: exportVideo called")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Output URL: \(outputURL.absoluteString)")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Asset: \(type(of: asset))")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Quarter turns: \(quarterTurns)")

        let exportTrimRangeDesc: String
        if let exportTrimRange = trimRange {
            exportTrimRangeDesc = "start: \(exportTrimRange.start.seconds), duration: \(exportTrimRange.duration.seconds)"
        } else {
            exportTrimRangeDesc = "nil"
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Trim range: \(exportTrimRangeDesc)")

        let (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Composition and video composition built successfully")

        // Determine export preset
        let presetName: String
        if quarterTurns != 0 {
            // Use highest quality when transforms are applied
            presetName = AVAssetExportPresetHighestQuality
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Using HighestQuality preset (rotation applied)")
        } else {
            // Use passthrough for simple trims without rotation
            presetName = AVAssetExportPresetPassthrough
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Using Passthrough preset (no rotation)")
        }

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Creating AVAssetExportSession")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
            logger.error("🎬 VIDEO_TRANSFORM_BUILDER: Failed to create export session")
            throw NSError(domain: "VideoTransformBuilder", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Export session created successfully")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Preset: \(presetName)")

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Export session configured")
        if let fileType = exportSession.outputFileType {
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Output file type: \(fileType.rawValue)")
        } else {
            logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Output file type: nil")
        }
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Video composition assigned: \(exportSession.videoComposition != nil)")

        // Export
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Starting video export")
        try await exportSession.export(to: outputURL, as: .mov)

        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: ✅ Video export completed successfully")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: Output file exists: \(FileManager.default.fileExists(atPath: outputURL.path))")

        return outputURL
    }

    private static func logPerformanceMetrics(_ context: String) {
        // Memory usage
        let physicalMemory: Double = Double(ProcessInfo.processInfo.physicalMemory)
        let memoryGB: Double = physicalMemory / (1024 * 1024 * 1024)
        let memoryString: String = String(format: "%.1f", memoryGB)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: [\(context)] System memory: \(memoryString)GB")

        // System performance
        let processInfo: ProcessInfo = ProcessInfo.processInfo
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: [\(context)] Active processors: \(processInfo.activeProcessorCount)")

        let uptimeString: String = String(format: "%.1f", processInfo.systemUptime)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: [\(context)] System uptime: \(uptimeString)s")
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: [\(context)] Thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        // Log current time for timing analysis
        let currentDate: Date = Date()
        let currentTime: TimeInterval = currentDate.timeIntervalSince1970
        let timestampString: String = String(format: "%.3f", currentTime)
        logger.info("🎬 VIDEO_TRANSFORM_BUILDER: [\(context)] Timestamp: \(timestampString)")
    }
}
