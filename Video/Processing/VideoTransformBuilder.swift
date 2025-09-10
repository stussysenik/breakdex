import AVFoundation
import Foundation

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
        print("🎬 VideoTransformBuilder.build() called with quarterTurns: \(quarterTurns), trimRange: \(trimRange?.description ?? "nil")")

        // Step 1: Create mutable composition
        let composition = AVMutableComposition()

        // Step 2: Determine time range to use
        let timeRange: CMTimeRange
        if let trimRange = trimRange {
            timeRange = trimRange
        } else {
            let duration = try await asset.load(.duration)
            timeRange = CMTimeRange(start: .zero, duration: duration)
        }

        // Step 3: Insert time range into composition
        try await composition.insertTimeRange(timeRange, of: asset, at: .zero)

        // Step 4: Get video track from composition
        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "VideoTransformBuilder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Video track not found"])
        }

        // Step 5: Load track properties
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // Step 6: Validate inputs
        guard naturalSize.width > 0 && naturalSize.height > 0 else {
            throw NSError(domain: "VideoTransformBuilder", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid video dimensions: \(naturalSize)"])
        }

        // Step 7: Compute transforms according to spec: T · R(θ) · R_src
        let Rsrc = preferredTransform
        let (Ruser, translation, renderSize) = computeRotationTransforms(quarterTurns: quarterTurns, naturalSize: naturalSize)

        // Step 8: Combine transforms: T · R(θ) · R_src
        let finalTransform = translation.concatenating(Ruser).concatenating(Rsrc)

        // Step 9: Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(finalTransform, at: .zero)

        // Step 10: Create video composition instruction
        let mainInstruction = AVMutableVideoCompositionInstruction()
        let compDuration = try await composition.load(.duration)
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: compDuration)
        mainInstruction.layerInstructions = [layerInstruction]

        // Step 11: Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.instructions = [mainInstruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps

        print("✅ VideoTransformBuilder completed: renderSize=\(renderSize), quarterTurns=\(quarterTurns)")

        return (composition, videoComposition)
    }

    /// Computes the rotation transforms and render size for the given quarter turns
    /// - Parameters:
    ///   - quarterTurns: Number of quarter turns (0, 1, 2, 3)
    ///   - naturalSize: The natural size of the video track
    /// - Returns: Tuple containing R(θ), T, and renderSize
    private static func computeRotationTransforms(quarterTurns: Int, naturalSize: CGSize) -> (rotation: CGAffineTransform, translation: CGAffineTransform, renderSize: CGSize) {
        let normalizedQuarterTurns = ((quarterTurns % 4) + 4) % 4 // Ensure positive modulo

        switch normalizedQuarterTurns {
        case 0: // 0°
            return (.identity, .identity, naturalSize)
        case 1: // 90° clockwise
            let rotation = CGAffineTransform(rotationAngle: .pi / 2)
            let translation = CGAffineTransform(translationX: naturalSize.height, y: 0)
            let renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            return (rotation, translation, renderSize)
        case 2: // 180°
            let rotation = CGAffineTransform(rotationAngle: .pi)
            let translation = CGAffineTransform(translationX: naturalSize.width, y: naturalSize.height)
            let renderSize = naturalSize
            return (rotation, translation, renderSize)
        case 3: // 270° clockwise
            let rotation = CGAffineTransform(rotationAngle: .pi * 3 / 2)
            let translation = CGAffineTransform(translationX: 0, y: naturalSize.width)
            let renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            return (rotation, translation, renderSize)
        default:
            return (.identity, .identity, naturalSize)
        }
    }

    /// Creates an AVPlayerItem configured with the video composition for preview
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional)
    ///   - quarterTurns: Number of quarter turns
    ///   - optimizeForScrubbing: If true, disables seekingWaitsForVideoCompositionRendering for faster scrubbing
    /// - Returns: Configured AVPlayerItem ready for playback
    static func createPlayerItem(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int, optimizeForScrubbing: Bool = false) async throws -> AVPlayerItem {
        let (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)

        let playerItem = AVPlayerItem(asset: composition)
        playerItem.videoComposition = videoComposition

        // Optimize seeking based on use case
        if optimizeForScrubbing && quarterTurns == 0 {
            // For no rotation and scrubbing, allow faster seeking
            playerItem.seekingWaitsForVideoCompositionRendering = false
        } else {
            // For rotation or precise playback, ensure frame accuracy
            playerItem.seekingWaitsForVideoCompositionRendering = true
        }

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
        let (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)

        // Determine export preset
        let presetName: String
        if quarterTurns != 0 {
            // Use highest quality when transforms are applied
            presetName = AVAssetExportPresetHighestQuality
        } else {
            // Use passthrough for simple trims without rotation
            presetName = AVAssetExportPresetPassthrough
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: presetName) else {
            throw NSError(domain: "VideoTransformBuilder", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        // Configure export session
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        // Export
        try await exportSession.export(to: outputURL, as: .mov)

        return outputURL
    }
}
