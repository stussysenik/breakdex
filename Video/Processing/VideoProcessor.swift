import Foundation
import AVFoundation

// MARK: - Video Processor Protocol
protocol VideoProcessor {
    func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int) async throws -> AVAsset
}

// MARK: - Video Processor Implementation
final class VideoProcessorImpl: VideoProcessor {
    private let logger: AppLogger
    
    init(logger: AppLogger) {
        self.logger = logger
    }
    
    func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int) async throws -> AVAsset {
        logger.info("🔄 Processing video with rotation: \(rotationQuarterTurns)", metadata: nil)
        
        // If no rotation needed, return the original asset
        if rotationQuarterTurns == 0 {
            logger.info("✅ No rotation needed, returning original asset", metadata: nil)
            return asset
        }
        
        // Create a new composition with the video track
        guard let videoTrack = (try await asset.loadTracks(withMediaType: .video)).first else {
            let error = VideoProcessingError.assetCreationFailed
            logger.error("❌ No video track found in asset: \(error.localizedDescription)", metadata: nil)
            throw error
        }
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track to composition
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        // Add audio tracks if any
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        for audioTrack in audioTracks {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            try compositionAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: audioTrack,
                at: .zero
            )
        }
        
        // Create video composition with rotation
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Create instruction with rotation
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        // Create layer instruction with rotation
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack!)
        
        // Apply rotation based on quarter turns
        switch rotationQuarterTurns {
        case 1: // 90 degrees
            layerInstruction.setTransform(
                CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: naturalSize.height, y: 0),
                at: .zero
            )
            videoComposition.renderSize = CGSize(
                width: naturalSize.height,
                height: naturalSize.width
            )
        case 2: // 180 degrees
            layerInstruction.setTransform(
                CGAffineTransform(rotationAngle: .pi).translatedBy(x: naturalSize.width, y: naturalSize.height),
                at: .zero
            )
        case 3: // 270 degrees
            layerInstruction.setTransform(
                CGAffineTransform(rotationAngle: 3 * .pi / 2).translatedBy(x: 0, y: naturalSize.width),
                at: .zero
            )
            videoComposition.renderSize = CGSize(
                width: naturalSize.height,
                height: naturalSize.width
            )
        default:
            break
        }
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Create a new AVAsset with the composition
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.assetCreationFailed
        }
        
        // Create a temporary file URL for the exported video
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition
        
        // Export the video
        await exportSession.export()
        
        // Check for errors
        if let error = exportSession.error {
            logger.error("❌ Video export failed: \(error.localizedDescription)", metadata: nil)
            throw VideoProcessingError.videoProcessingFailed(
                operation: "rotation",
                underlyingError: error
            )
        }
        
        logger.info("✅ Video processing completed successfully", metadata: nil)
        
        // Return the exported video as a new AVAsset
        return AVURLAsset(url: tempURL)
    }
}