import AVFoundation
import UIKit

// MARK: - Edit Parameter Types

enum VideoRotation: Int, CaseIterable {
    case none = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270

    var next: VideoRotation {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }

    var radians: CGFloat {
        CGFloat(rawValue) * .pi / 180
    }

    var iconName: String {
        "rotate.right"
    }
}

enum AspectRatio: String, CaseIterable {
    case original
    case square
    case widescreen16x9
    case portrait9x16

    var next: AspectRatio {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }

    var iconName: String {
        switch self {
        case .original:       return "aspectratio"
        case .square:         return "square"
        case .widescreen16x9: return "rectangle"
        case .portrait9x16:   return "rectangle.portrait"
        }
    }

    var label: String {
        switch self {
        case .original:       return "Original"
        case .square:         return "1:1"
        case .widescreen16x9: return "16:9"
        case .portrait9x16:   return "9:16"
        }
    }

    /// Returns target aspect ratio (width/height). nil means use original.
    var ratio: CGFloat? {
        switch self {
        case .original:       return nil
        case .square:         return 1.0
        case .widescreen16x9: return 16.0 / 9.0
        case .portrait9x16:   return 9.0 / 16.0
        }
    }
}

struct VideoEditParameters {
    var startTime: CMTime = .zero
    var endTime: CMTime = .zero
    var playbackRate: Float = 1.0
    var isReversed: Bool = false
    var rotation: VideoRotation = .none
    var aspectRatio: AspectRatio = .original
}

// MARK: - Composition Pipeline

final class VideoCompositionPipeline {

    enum PipelineError: LocalizedError {
        case noVideoTrack
        case exportFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:         return "No video track found in asset"
            case .exportFailed(let msg): return msg
            case .cancelled:            return "Export was cancelled"
            }
        }
    }

    // MARK: - Preview Composition

    /// Build a player item with speed applied for real-time preview.
    /// Rotation and aspect ratio are handled via layer transforms on the view side.
    static func buildPreviewItem(
        from asset: AVAsset,
        with params: VideoEditParameters
    ) -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        item.forwardPlaybackEndTime = params.endTime
        item.reversePlaybackEndTime = params.startTime
        return item
    }

    // MARK: - Export

    static func export(
        asset: AVAsset,
        with params: VideoEditParameters,
        outputURL: URL,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> URL {
        // Load tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw PipelineError.noVideoTrack }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        // Create composition
        let composition = AVMutableComposition()
        let timeRange = CMTimeRange(start: params.startTime, end: params.endTime)

        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw PipelineError.noVideoTrack }

        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        // Add audio track (if present and not reversed)
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let audioTrack = audioTracks.first, !params.isReversed {
            let audioCompTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try audioCompTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            compositionAudioTrack = audioCompTrack
        }

        // Apply speed
        let trimmedDuration = CMTimeSubtract(params.endTime, params.startTime)
        if params.playbackRate != 1.0 {
            let scaledDuration = CMTimeMultiplyByFloat64(trimmedDuration, multiplier: Float64(1.0 / params.playbackRate))
            let fullRange = CMTimeRange(start: .zero, duration: trimmedDuration)
            compositionVideoTrack.scaleTimeRange(fullRange, toDuration: scaledDuration)
            compositionAudioTrack?.scaleTimeRange(fullRange, toDuration: scaledDuration)
        }

        // Video composition for rotation + aspect ratio
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let transformedSize = naturalSize.applying(preferredTransform)
        let videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

        // Compute render size and transform
        let (renderSize, layerTransform) = computeTransform(
            videoSize: videoSize,
            rotation: params.rotation,
            aspectRatio: params.aspectRatio
        )

        videoComposition.renderSize = renderSize

        let instruction = AVMutableVideoCompositionInstruction()
        let outputDuration = composition.duration
        instruction.timeRange = CMTimeRange(start: .zero, duration: outputDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)

        // Combine the track's preferred transform with our rotation/crop
        let combinedTransform = preferredTransform.concatenating(layerTransform)
        layerInstruction.setTransform(combinedTransform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1920x1080
        ) else {
            throw PipelineError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        // Progress monitoring
        let progressTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    progressHandler(exportSession.progress)
                }
            }
        }

        await exportSession.export()
        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .cancelled:
            throw PipelineError.cancelled
        default:
            throw PipelineError.exportFailed(
                exportSession.error?.localizedDescription ?? "Unknown export error"
            )
        }
    }

    // MARK: - Transform Math

    private static func computeTransform(
        videoSize: CGSize,
        rotation: VideoRotation,
        aspectRatio: AspectRatio
    ) -> (CGSize, CGAffineTransform) {
        var size = videoSize
        var transform = CGAffineTransform.identity

        // Apply rotation
        switch rotation {
        case .none:
            break
        case .clockwise90:
            transform = transform
                .translatedBy(x: size.height, y: 0)
                .rotated(by: .pi / 2)
            size = CGSize(width: size.height, height: size.width)
        case .clockwise180:
            transform = transform
                .translatedBy(x: size.width, y: size.height)
                .rotated(by: .pi)
        case .clockwise270:
            transform = transform
                .translatedBy(x: 0, y: size.width)
                .rotated(by: -.pi / 2)
            size = CGSize(width: size.height, height: size.width)
        }

        // Apply aspect ratio crop (after rotation, in rotated coordinate space)
        if let targetRatio = aspectRatio.ratio {
            let currentRatio = size.width / size.height
            if currentRatio > targetRatio {
                // Too wide — crop horizontally
                let newWidth = size.height * targetRatio
                let offsetX = (size.width - newWidth) / 2
                transform = transform.concatenating(CGAffineTransform(translationX: -offsetX, y: 0))
                size = CGSize(width: newWidth, height: size.height)
            } else if currentRatio < targetRatio {
                // Too tall — crop vertically
                let newHeight = size.width / targetRatio
                let offsetY = (size.height - newHeight) / 2
                transform = transform.concatenating(CGAffineTransform(translationX: 0, y: -offsetY))
                size = CGSize(width: size.width, height: newHeight)
            }
        }

        return (size, transform)
    }
}
