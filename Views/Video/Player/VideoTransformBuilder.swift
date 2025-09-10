import AVFoundation

struct VideoTransformBuilder {
    static func build(asset: AVAsset, quarterTurns: Int) async throws -> (composition: AVComposition, videoComposition: AVVideoComposition) {
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()

        // Ensure there's a video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            // Handle cases with no video tracks if necessary
            return (composition: composition, videoComposition: videoComposition)
        }

        // Get video properties
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        // Create composition track
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            // Handle failure to add track
            return (composition: composition, videoComposition: videoComposition)
        }

        // Add video asset to composition
        let timeRange = try await asset.load(.duration)
        try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: timeRange), of: videoTrack, at: .zero)

        // --- Audio Track --- //
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: timeRange), of: audioTrack, at: .zero)
        }

        // --- Video Composition --- //
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)

        // Calculate the final transform
        let finalTransform = calculateTransform(quarterTurns: quarterTurns, naturalSize: naturalSize, preferredTransform: preferredTransform)
        layerInstruction.setTransform(finalTransform.transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = finalTransform.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // Or use videoTrack.minFrameDuration

        return (composition: composition, videoComposition: videoComposition)
    }

    private static func calculateTransform(quarterTurns: Int, naturalSize: CGSize, preferredTransform: CGAffineTransform) -> (transform: CGAffineTransform, renderSize: CGSize) {
        var transform = preferredTransform
        var renderSize = naturalSize

        // Apply rotation based on quarter turns
        let rotationAngle = CGFloat(quarterTurns) * .pi / 2
        transform = transform.concatenating(CGAffineTransform(rotationAngle: rotationAngle))

        // Adjust translation to keep the video centered after rotation
        switch quarterTurns % 4 {
        case 1: // 90 degrees
            transform = transform.concatenating(CGAffineTransform(translationX: naturalSize.height, y: 0))
            renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        case 2: // 180 degrees
            transform = transform.concatenating(CGAffineTransform(translationX: naturalSize.width, y: naturalSize.height))
        case 3: // 270 degrees
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: naturalSize.width))
            renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        default: // 0 or 360 degrees
            break
        }

        return (transform, renderSize)
    }
    
    static func exportVideo(asset: AVAsset, trimRange: CMTimeRange, quarterTurns: Int, outputURL: URL) async throws -> URL {
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()

        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoTransformBuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? videoCompositionTrack?.insertTimeRange(trimRange, of: videoTrack, at: .zero)

        // Add audio track
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try? audioCompositionTrack?.insertTimeRange(trimRange, of: audioTrack, at: .zero)
        }

        // Create video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: trimRange.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack!)
        let transform = calculateTransform(quarterTurns: quarterTurns, naturalSize: videoTrack.naturalSize, preferredTransform: videoTrack.preferredTransform)
        layerInstruction.setTransform(transform.transform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = transform.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Export
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoTransformBuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = videoComposition

        await exportSession.export()
        
        if let error = exportSession.error {
            throw error
        }
        
        return outputURL
    }
}
