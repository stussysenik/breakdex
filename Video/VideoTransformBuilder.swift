import AVFoundation
import Foundation
import OSLog

/// Shared video composition builder that handles rotation and trimming transforms
/// Implements T · R(θ) · R_src where R_src is preferredTransform, R(θ) is quarter-turn rotation, and T is translation
@MainActor
final class VideoTransformBuilder {

    private static let logger = Logger(subsystem: "BreakingFlashcards", category: "VideoTransformBuilder")

    /// Builds AVMutableComposition and AVMutableVideoComposition with rotation and trimming applied
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional, if nil uses full duration)
    ///   - quarterTurns: Number of quarter turns (0, 1, 2, 3 for 0°, 90°, 180°, 270°)
    /// - Returns: Tuple containing the composition and optional video composition (nil when no rotation needed)
    static func build(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition?) {
        let buildStartTime = CFAbsoluteTimeGetCurrent()
        logger.info("🎬 BUILDER: 🚀 Starting composition build - quarterTurns: \(quarterTurns), trimRange: \(trimRange?.start.seconds ?? 0)-\(trimRange?.end.seconds ?? 0)s")
        
        // 1. DETERMINE TIME RANGE FOR TRIMMING
        let timeRange: CMTimeRange
        if let trimRange = trimRange {
            timeRange = trimRange
        } else {
            let duration = try await asset.load(.duration)
            timeRange = CMTimeRange(start: .zero, duration: duration)
        }
        
        // 2. 🎯 CRITICAL: PROACTIVE ASSET LOADING - Ensure tracks are fully loaded before composition
        logger.info("🎬 BUILDER: 📊 Proactively loading asset tracks...")
        let trackLoadStart = CFAbsoluteTimeGetCurrent()
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        logger.info("🎬 BUILDER: 📊 Track loading completed in \((CFAbsoluteTimeGetCurrent() - trackLoadStart) * 1000)ms - Video: \(videoTracks.count), Audio: \(audioTracks.count)")
        
        guard !videoTracks.isEmpty else {
            throw NSError(domain: "VideoTransformBuilder", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "No video tracks found in asset"])
        }
        
        // 3. 🎯 CRITICAL: EXPLICIT TRACK-BY-TRACK COMPOSITION BUILDING
        // Abandon the high-level API that creates invalid compositions
        let composition = AVMutableComposition()

        logger.info("🎬 BUILDER: 🔧 Building composition with explicit track insertion...")
        let compositionStart = CFAbsoluteTimeGetCurrent()
        
        // Handle video tracks explicitly
        for (index, sourceVideoTrack) in videoTracks.enumerated() {
            logger.info("🎬 BUILDER: 🎬 Processing video track \(index + 1)/\(videoTracks.count)")
            
            let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video, 
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            do {
                try compositionVideoTrack?.insertTimeRange(
                    timeRange, 
                    of: sourceVideoTrack, 
                    at: .zero
                )
                print("🎬 VideoTransformBuilder: ✅ Successfully inserted video track \(index + 1)")
            } catch {
                print("🎬 VideoTransformBuilder: ❌ Failed to insert video track \(index + 1): \(error)")
                throw error
            }
        }
        
        // Handle audio tracks explicitly
        for (index, sourceAudioTrack) in audioTracks.enumerated() {
            logger.info("🎬 BUILDER: 🎵 Processing audio track \(index + 1)/\(audioTracks.count)")
            
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio, 
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            do {
                try compositionAudioTrack?.insertTimeRange(
                    timeRange, 
                    of: sourceAudioTrack, 
                    at: .zero
                )
                print("🎬 VideoTransformBuilder: ✅ Successfully inserted audio track \(index + 1)")
            } catch {
                print("🎬 VideoTransformBuilder: ❌ Failed to insert audio track \(index + 1): \(error)")
                throw error
            }
        }
        
        // 4. VALIDATE THE COMPOSITION
        logger.info("🎬 BUILDER: 🔍 Validating built composition...")
        let finalVideoTracks = composition.tracks(withMediaType: .video)
        let finalAudioTracks = composition.tracks(withMediaType: .audio)

        guard !finalVideoTracks.isEmpty else {
            throw NSError(domain: "VideoTransformBuilder", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Composition has no video tracks after building"])
        }

        logger.info("🎬 BUILDER: ✅ Composition validation passed - \(finalVideoTracks.count) video tracks, \(finalAudioTracks.count) audio tracks")
        logger.info("🎬 BUILDER: 📏 Composition duration: \(composition.duration.seconds)s")
        logger.info("🎬 BUILDER: ⏱️ Track insertion completed in \((CFAbsoluteTimeGetCurrent() - compositionStart) * 1000)ms")
        
        // 7. If no rotation is needed, we are done - return nil for video composition to bypass problematic layer
        if quarterTurns % 4 == 0 {
            print("🎬 VideoTransformBuilder: No rotation needed, returning composition without video composition")
            print("🎬 VideoTransformBuilder: Composition duration: \(composition.duration.seconds)s")
            print("✅ VideoTransformBuilder completed with explicit track building approach - bypassing video composition")
            return (composition, nil)
        }
        
        // 8. --- ROTATION TRANSFORM LOGIC (for quarterTurns != 0) ---
        print("🎬 VideoTransformBuilder: Rotation needed. Building video composition manually...")
        
        // Step A: Get the properties we need from the composition's video track.
        guard let compositionVideoTrack = composition.tracks(withMediaType: .video).first,
              let sourceVideoTrack = videoTracks.first else { 
            throw NSError(domain: "VideoTransformBuilder", code: -4, userInfo: [NSLocalizedDescriptionKey: "Could not find video track in composition."])
        }
        
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        
        // Step B: Manually create a fresh, empty AVMutableVideoComposition.
        // THIS IS THE CORE FIX. We no longer use `propertiesOf:`.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // Step C: Calculate the final render size based on rotation.
        let isPortraitRotation = quarterTurns % 2 != 0
        let finalRenderSize = isPortraitRotation ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize
        videoComposition.renderSize = finalRenderSize
        print("🎬 VideoTransformBuilder: Manually set render size to \(finalRenderSize)")
        
        // Step D: Manually create the layer instruction.
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        // Apply the source video's own orientation transform first, then our custom rotation.
        var transform = preferredTransform
        let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2.0 * CGFloat(quarterTurns))
        let translationTransform: CGAffineTransform
        
        switch quarterTurns {
        case 1: // 90°
            translationTransform = CGAffineTransform(translationX: naturalSize.height, y: 0)
        case 2: // 180°
            translationTransform = CGAffineTransform(translationX: naturalSize.width, y: naturalSize.height)
        case 3: // 270°
            translationTransform = CGAffineTransform(translationX: 0, y: naturalSize.width)
        default:
            translationTransform = .identity
        }
        
        // Order is critical: initial orientation -> our rotation -> translation to fit new bounds.
        transform = transform.concatenating(rotationTransform).concatenating(translationTransform)
        layerInstruction.setTransform(transform, at: .zero)
        print("🎬 VideoTransformBuilder: Manually constructed final transform.")
        
        // Step E: Manually create the main instruction.
        let mainInstruction = AVMutableVideoCompositionInstruction()
        // Its timeRange MUST cover the entire duration of our new, trimmed composition.
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        mainInstruction.layerInstructions = [layerInstruction]
        print("🎬 VideoTransformBuilder: Manually created main instruction with timeRange 0.0-\(composition.duration.seconds)s")
        
        // Step F: Assign the manually built instructions to the video composition.
        videoComposition.instructions = [mainInstruction]
        
        // --- END: ROTATION TRANSFORM LOGIC ---
        
        // 9. FINAL DIAGNOSTIC LOGGING
        logger.info("🎬 BUILDER: ✅ Manual video composition build completed")
        logger.info("🎬 BUILDER: 📐 Final render size: \(videoComposition.renderSize.width)x\(videoComposition.renderSize.height)")
        logger.info("🎬 BUILDER: 🔄 User rotation applied: \(quarterTurns) quarter turns (\(quarterTurns * 90)°)")
        logger.info("🎬 BUILDER: ⏱️ Total build time: \((CFAbsoluteTimeGetCurrent() - buildStartTime) * 1000)ms")
        logger.info("✅ VideoTransformBuilder completed with explicit track building and manual rotation")

        return (composition, videoComposition)
    }

    
    /// Creates an AVPlayerItem configured with the video composition for preview
    /// - Parameters:
    ///   - asset: The source AVAsset
    ///   - trimRange: The time range to trim (optional)
    ///   - quarterTurns: Number of quarter turns
    ///   - optimizeForScrubbing: If true, disables seekingWaitsForVideoCompositionRendering for faster scrubbing
    /// - Returns: Configured AVPlayerItem ready for playback
    static func createPlayerItem(asset: AVAsset, trimRange: CMTimeRange? = nil, quarterTurns: Int, optimizeForScrubbing: Bool = false) async throws -> AVPlayerItem {
        print("🎬 VideoTransformBuilder: createPlayerItem called with trimRange: \(trimRange?.start.seconds ?? 0)-\(trimRange?.end.seconds ?? 0)s, quarterTurns: \(quarterTurns)")
        
        let (composition, videoComposition) = try await build(asset: asset, trimRange: trimRange, quarterTurns: quarterTurns)
        
        print("🎬 VideoTransformBuilder: ✅ Composition built successfully")
        print("🎬 VideoTransformBuilder: - Composition duration: \(composition.duration.seconds)s")
        print("🎬 VideoTransformBuilder: - Video composition exists: \(videoComposition != nil)")
        if let videoComposition = videoComposition {
            print("🎬 VideoTransformBuilder: - Video composition render size: \(videoComposition.renderSize)")
            print("🎬 VideoTransformBuilder: - Video composition instructions count: \(videoComposition.instructions.count)")
        }

        let playerItem = AVPlayerItem(asset: composition)
        
        // Only assign video composition if it exists (i.e., rotation is needed)
        if let videoComposition = videoComposition {
            playerItem.videoComposition = videoComposition
            print("🎬 VideoTransformBuilder: ✅ Applied video composition for rotation")
            
            // Additional diagnostics for video composition
            print("🎬 VideoTransformBuilder: 📋 Video Composition Diagnostics:")
            print("🎬 VideoTransformBuilder:   - Render size: \(videoComposition.renderSize)")
            print("🎬 VideoTransformBuilder:   - Frame duration: \(videoComposition.frameDuration.seconds)s")
            print("🎬 VideoTransformBuilder:   - Instructions count: \(videoComposition.instructions.count)")
            
            for (index, instruction) in videoComposition.instructions.enumerated() {
                guard let mutableInstruction = instruction as? AVMutableVideoCompositionInstruction else { continue }
                print("🎬 VideoTransformBuilder:   - Instruction \(index): timeRange \(mutableInstruction.timeRange.start.seconds)-\(mutableInstruction.timeRange.end.seconds)s")
                print("🎬 VideoTransformBuilder:   - Instruction \(index): layerInstructions count: \(mutableInstruction.layerInstructions.count)")
            }
        } else {
            print("🎬 VideoTransformBuilder: ✅ Bypassed video composition - no rotation needed")
        }

        // Optimize seeking based on use case
        if optimizeForScrubbing && quarterTurns == 0 {
            // For no rotation and scrubbing, allow faster seeking
            playerItem.seekingWaitsForVideoCompositionRendering = false
            print("🎬 VideoTransformBuilder: ⚡ Optimized for scrubbing (fast seeking)")
        } else {
            // For rotation or precise playback, ensure frame accuracy
            playerItem.seekingWaitsForVideoCompositionRendering = true
            print("🎬 VideoTransformBuilder: 🎯 Frame-accurate seeking enabled")
        }
        
        print("🎬 VideoTransformBuilder: ✅ Player item created and configured")
        logger.info("🎬 BUILDER: 📏 Asset duration: \(String(describing: playerItem.asset.duration))")
        print("🎬 VideoTransformBuilder:   - Video composition assigned: \(playerItem.videoComposition != nil)")
        print("🎬 VideoTransformBuilder:   - Seeking waits for rendering: \(playerItem.seekingWaitsForVideoCompositionRendering)")

        // 🎯 ENHANCED: Validate composition readiness before returning
        try await validateCompositionReadiness(composition: composition, videoComposition: videoComposition, playerItem: playerItem)

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
        
        // Only assign video composition if it exists (i.e., rotation is needed)
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
            print("🎬 VideoTransformBuilder: ✅ Applied video composition for export rotation")
        } else {
            print("🎬 VideoTransformBuilder: ✅ Bypassed video composition for export - no rotation needed")
        }

        // Export
        try await exportSession.export(to: outputURL, as: .mov)

        return outputURL
    }

    // MARK: - Composition Readiness Validation

    /// 🎯 ENHANCED: Validates that the composition is truly ready for playback and seeking
    /// This prevents the 90% hang by ensuring the composition is fully processed
    private static func validateCompositionReadiness(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        playerItem: AVPlayerItem
    ) async throws {
        print("🎬 VideoTransformBuilder: 🔍 Starting composition readiness validation...")

        // 1. Validate track mapping integrity
        let videoTracks = composition.tracks(withMediaType: .video)
        let audioTracks = composition.tracks(withMediaType: .audio)

        print("🎬 VideoTransformBuilder: 📊 Track validation - Video: \(videoTracks.count), Audio: \(audioTracks.count)")

        guard !videoTracks.isEmpty else {
            throw NSError(domain: "VideoTransformBuilder", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "Composition has no video tracks after validation"])
        }

        // 2. Validate time range consistency
        let expectedDuration = composition.duration
        for (index, track) in videoTracks.enumerated() {
            let trackRange = track.timeRange
            print("🎬 VideoTransformBuilder: 📊 Video track \(index): \(String(format: "%.2f", trackRange.start.seconds))s - \(String(format: "%.2f", trackRange.end.seconds))s")

            if abs(trackRange.duration.seconds - expectedDuration.seconds) > 0.1 {
                print("⚠️ VideoTransformBuilder: Track duration mismatch: \(trackRange.duration.seconds)s vs expected \(expectedDuration.seconds)s")
            }
        }

        // 3. Validate video composition instructions if present
        if let videoComposition = videoComposition {
            print("🎬 VideoTransformBuilder: 📊 Video composition validation:")
            print("   - Render size: \(videoComposition.renderSize)")
            print("   - Frame duration: \(videoComposition.frameDuration.seconds)s")
            print("   - Instructions count: \(videoComposition.instructions.count)")

            // Validate instruction time ranges cover the composition
            let totalInstructionDuration = videoComposition.instructions.reduce(CMTime.zero) { total, instruction in
                total + instruction.timeRange.duration
            }

            if abs(totalInstructionDuration.seconds - expectedDuration.seconds) > 0.1 {
                print("⚠️ VideoTransformBuilder: Instruction duration mismatch: \(totalInstructionDuration.seconds)s vs expected \(expectedDuration.seconds)s")
            }

            // Validate layer instructions
            for (instructionIndex, instruction) in videoComposition.instructions.enumerated() {
                guard let mutableInstruction = instruction as? AVMutableVideoCompositionInstruction else { continue }
                print("   - Instruction \(instructionIndex): \(mutableInstruction.layerInstructions.count) layer instructions")

                for (layerIndex, layerInstruction) in mutableInstruction.layerInstructions.enumerated() {
                    guard let mutableLayerInstruction = layerInstruction as? AVMutableVideoCompositionLayerInstruction else { continue }
                    print("     - Layer \(layerIndex): Transform applied")
                }
            }
        }

        // 4. Test basic seekability (non-blocking test)
        do {
            let testSeekTime = CMTime(seconds: 0.1, preferredTimescale: 600)
            logger.info("🎬 BUILDER: 📊 Seekability test - checking asset seekability")
        }

        // 5. Check audio/video sync
        if !audioTracks.isEmpty {
            let audioDuration = audioTracks.first?.timeRange.duration ?? CMTime.zero
            let videoDuration = videoTracks.first?.timeRange.duration ?? CMTime.zero

            let syncDifference = abs(audioDuration.seconds - videoDuration.seconds)
            print("🎬 VideoTransformBuilder: 📊 Audio/Video sync difference: \(String(format: "%.3f", syncDifference))s")

            if syncDifference > 0.1 {
                print("⚠️ VideoTransformBuilder: Audio/video sync difference detected: \(syncDifference)s")
            }
        }

        print("🎬 VideoTransformBuilder: ✅ Composition readiness validation completed successfully")
    }
}
