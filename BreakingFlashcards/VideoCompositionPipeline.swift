// VideoCompositionPipeline.swift — Video Export Engine for Breakdex
//
// This file is the core video processing pipeline. It takes a raw AVAsset (loaded from
// the user's recorded breakdancing clip), applies edits (trim, speed, rotation, crop),
// and exports the result as a new .mp4 file that gets saved to Documents/Moves/.
//
// ARCHITECTURE ROLE:
//   VideoEditorView (UI) --> VideoEditParameters (user's choices)
//                        --> VideoCompositionPipeline.export() (this file)
//                        --> Exported .mp4 at outputURL
//                        --> Move.videoReference updated in SwiftData
//
// The pipeline is stateless — it's a collection of static methods. You pass in an
// AVAsset + parameters, and get back a URL to the exported file. No retained state,
// no singleton, no side effects beyond file I/O.
//
// AVFoundation CONCEPTS USED:
//   - AVMutableComposition: A mutable timeline that assembles audio/video tracks
//   - AVMutableVideoComposition: Defines how video frames are transformed (rotation, crop)
//   - AVMutableVideoCompositionInstruction: Time-based instructions for frame rendering
//   - AVMutableVideoCompositionLayerInstruction: Per-track transform/opacity instructions
//   - AVAssetExportSession: Renders the composition to a file on disk
//   - CMTime / CMTimeRange: Core Media's precise time representation (value/timescale)
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Calls `VideoCompositionPipeline.export()` when user taps "Save"
//   - HapticEngine.swift: VideoEditorView fires `exportComplete()` / `error()` after export
//   - MediaManager.swift: Loads the source AVAsset that gets passed into this pipeline
//   - Models.swift: The exported URL becomes the Move's `.videoReference` in SwiftData

import AVFoundation

// MARK: - VideoRotation
// Represents the four cardinal rotation states for a video.
// The raw Int value is the clockwise rotation in degrees, which makes
// it easy to display to users and reason about mathematically.
//
// Used by VideoEditorView's rotation button — each tap cycles to `.next`.

enum VideoRotation: Int, CaseIterable {
    case none = 0             // No rotation (original orientation)
    case clockwise90 = 90    // 90 degrees clockwise (portrait -> landscape)
    case clockwise180 = 180  // 180 degrees (upside down)
    case clockwise270 = 270  // 270 degrees clockwise (same as 90 counter-clockwise)

    /// Cycles to the next rotation state in order.
    /// Uses modular arithmetic on CaseIterable's allCases array so that
    /// .clockwise270.next wraps back to .none (0 -> 90 -> 180 -> 270 -> 0).
    var next: VideoRotation {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!  // Safe: self is always a valid case
        return all[(idx + 1) % all.count]
    }

    /// SF Symbol name for the rotation button in the UI.
    /// Always returns "rotate.right" since every rotation is a clockwise action.
    var iconName: String {
        "rotate.right"
    }
}

// MARK: - AspectRatio
// Represents the target aspect ratio for video export.
// The user cycles through these in the video editor to crop their clip
// to common formats (square for Instagram, 16:9 for YouTube, etc.).
//
// `.original` means no cropping — the video keeps whatever dimensions it has.

enum AspectRatio: String, CaseIterable {
    case original         // Keep the video's native aspect ratio (no crop)
    case square           // 1:1 — Instagram posts, profile videos
    case widescreen16x9   // 16:9 — YouTube, standard widescreen
    case portrait9x16     // 9:16 — TikTok, Instagram Reels, vertical video

    /// Cycles to the next aspect ratio option (like VideoRotation.next).
    /// .portrait9x16.next wraps back to .original.
    var next: AspectRatio {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }

    /// SF Symbol name for the aspect ratio button in the UI.
    /// Each ratio gets a visually representative icon.
    var iconName: String {
        switch self {
        case .original:       return "aspectratio"         // Generic aspect ratio icon
        case .square:         return "square"              // Perfect square
        case .widescreen16x9: return "rectangle"           // Wide rectangle
        case .portrait9x16:   return "rectangle.portrait"  // Tall rectangle
        }
    }

    /// Human-readable label displayed in the editor's aspect ratio pill/button.
    var label: String {
        switch self {
        case .original:       return "Original"
        case .square:         return "1:1"
        case .widescreen16x9: return "16:9"
        case .portrait9x16:   return "9:16"
        }
    }

    /// The numeric ratio (width / height) used for crop calculations.
    /// Returns nil for `.original`, meaning "don't crop, use native dimensions."
    ///
    /// Examples:
    ///   .square         -> 1.0    (width == height)
    ///   .widescreen16x9 -> 1.778  (width is ~1.78x height)
    ///   .portrait9x16   -> 0.5625 (height is ~1.78x width)
    var ratio: CGFloat? {
        switch self {
        case .original:       return nil
        case .square:         return 1.0
        case .widescreen16x9: return 16.0 / 9.0
        case .portrait9x16:   return 9.0 / 16.0
        }
    }
}

// MARK: - VideoEditParameters
// A value type (struct) that bundles all the edit decisions the user made
// in the VideoEditorView. This gets passed into the export pipeline.
//
// Default values represent "no edits" — the video passes through unchanged.
// VideoEditorView mutates these as the user interacts with controls.

struct VideoEditParameters {
    /// The in-point of the trim selection (where the exported clip starts).
    /// Set by dragging the left trim handle in TrimmerTimelineView.
    var startTime: CMTime = .zero

    /// The out-point of the trim selection (where the exported clip ends).
    /// Set by dragging the right trim handle in TrimmerTimelineView.
    var endTime: CMTime = .zero

    /// Playback speed multiplier.
    /// 1.0 = normal speed, 0.5 = half speed (slow-mo), 2.0 = double speed.
    /// Applied by scaling the composition's time range during export.
    var playbackRate: Float = 1.0

    /// Whether the video should play in reverse.
    /// When true, the audio track is stripped (reversed audio sounds bad).
    /// NOTE: Reverse playback is handled at the AVPlayer level during preview,
    /// but the actual frame reversal during export is not yet implemented.
    var isReversed: Bool = false

    /// The rotation to apply to the video (0, 90, 180, or 270 degrees clockwise).
    /// Applied via CGAffineTransform in the video composition layer instruction.
    var rotation: VideoRotation = .none

    /// The target aspect ratio for the exported video.
    /// When not `.original`, the video is cropped (not letterboxed) to fit.
    var aspectRatio: AspectRatio = .original

    /// Normalized crop position within the frame, ranging from 0.0 to 1.0.
    /// (0.5, 0.5) = center crop (default).
    /// (0.0, 0.5) = crop from left edge.
    /// (1.0, 0.5) = crop from right edge.
    /// This lets the user pan the crop window when a non-original aspect ratio is selected.
    /// Controlled by CropOverlayView's drag gesture.
    var cropOffset: CGPoint = CGPoint(x: 0.5, y: 0.5)
}

// MARK: - VideoCompositionPipeline
// The main export engine. This class has no stored state — it's essentially
// a namespace for the static `export()` function and its helper `computeTransform()`.
//
// Marked `final` because there's no reason to subclass a stateless utility.

final class VideoCompositionPipeline {

    // MARK: - PipelineError
    // Domain-specific errors that can occur during video export.
    // Conforms to LocalizedError so SwiftUI can display `.localizedDescription`
    // directly in alert dialogs without extra mapping.

    enum PipelineError: LocalizedError {
        /// The source asset has no video track (audio-only file, corrupt file, etc.)
        case noVideoTrack
        /// The AVAssetExportSession failed for a specific reason (message included)
        case exportFailed(String)
        /// The user cancelled the export (or the Task was cancelled)
        case cancelled

        /// Human-readable error message shown in the UI's error alert.
        var errorDescription: String? {
            switch self {
            case .noVideoTrack:         return "No video track found in asset"
            case .exportFailed(let msg): return msg
            case .cancelled:            return "Export was cancelled"
            }
        }
    }

    // MARK: - Export

    /// The primary entry point for video export. Orchestrates the full pipeline:
    /// 1. Extract video/audio tracks from the source asset
    /// 2. Build an AVMutableComposition with the trimmed time range
    /// 3. Apply speed changes by scaling the composition's time range
    /// 4. Compute rotation + crop transforms
    /// 5. Configure an AVAssetExportSession and write to disk
    ///
    /// - Parameters:
    ///   - asset: The source AVAsset (loaded by MediaManager from Documents/Moves/)
    ///   - params: All edit parameters (trim points, speed, rotation, crop)
    ///   - outputURL: Where to write the exported .mp4 file
    ///   - progressHandler: Called ~10x/sec on MainActor with export progress (0.0...1.0)
    ///
    /// - Returns: The outputURL on success (same URL passed in, for chaining convenience)
    /// - Throws: PipelineError if tracks are missing, export fails, or task is cancelled
    ///
    /// Called from VideoEditorView's save action:
    ///   `let url = try await VideoCompositionPipeline.export(asset:with:outputURL:progressHandler:)`

    static func export(
        asset: AVAsset,
        with params: VideoEditParameters,
        outputURL: URL,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> URL {

        // ── Step 1: Load tracks from the source asset ──
        // AVAsset.loadTracks() is the modern async API (iOS 16+). It replaces the
        // older .tracks(withMediaType:) which was synchronous and could block.
        // Video tracks contain the actual frame data; audio tracks contain sound.

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw PipelineError.noVideoTrack }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        // ── Step 2: Build the AVMutableComposition ──
        // A composition is like a multitrack timeline editor. We create empty tracks
        // in it and then insert time ranges from the source asset's tracks.
        // This is how we implement trimming — we only insert the selected range.

        let composition = AVMutableComposition()

        // CMTimeRange from the user's trim selection. Everything outside this range
        // is discarded (not included in the composition).
        let timeRange = CMTimeRange(start: params.startTime, end: params.endTime)

        // ── Step 2a: Add the video track to the composition ──
        // `addMutableTrack()` creates an empty track slot in the composition.
        // `kCMPersistentTrackID_Invalid` tells AVFoundation to auto-assign a track ID.
        // `insertTimeRange()` copies the selected portion of the source track into it.

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw PipelineError.noVideoTrack }

        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        // ── Step 2b: Add the audio track (conditionally) ──
        // Audio is included only if:
        //   1. The source has an audio track
        //   2. The video is NOT reversed (reversed audio is unusable noise)
        // The audio track is trimmed to the same time range as video.

        var compositionAudioTrack: AVMutableCompositionTrack?
        if let audioTrack = audioTracks.first, !params.isReversed {
            let audioCompTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try audioCompTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            compositionAudioTrack = audioCompTrack
        }

        // ── Step 3: Apply speed change ──
        // Speed is implemented by scaling the composition's time range.
        // `scaleTimeRange(_:toDuration:)` remaps time — a 10s clip at 2x speed
        // becomes 5s, and at 0.5x speed becomes 20s.
        //
        // The math: scaledDuration = trimmedDuration * (1.0 / playbackRate)
        //   - playbackRate 2.0  -> scaledDuration = half   (faster)
        //   - playbackRate 0.5  -> scaledDuration = double (slower)
        //
        // Both video and audio tracks must be scaled identically to stay in sync.

        let trimmedDuration = CMTimeSubtract(params.endTime, params.startTime)
        if params.playbackRate != 1.0 {
            let scaledDuration = CMTimeMultiplyByFloat64(
                trimmedDuration,
                multiplier: Float64(1.0 / params.playbackRate)
            )
            let fullRange = CMTimeRange(start: .zero, duration: trimmedDuration)
            compositionVideoTrack.scaleTimeRange(fullRange, toDuration: scaledDuration)
            compositionAudioTrack?.scaleTimeRange(fullRange, toDuration: scaledDuration)
        }

        // ── Step 4: Build the video composition (rotation + crop) ──
        // AVMutableVideoComposition controls how frames are rendered to the output.
        // It doesn't change the timeline — it changes how each frame looks.
        //
        // frameDuration = 1/30 means 30fps output. This is set explicitly rather
        // than relying on the source frame rate for consistency across devices.

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)  // 30 fps output

        // ── Step 4a: Determine the video's effective size ──
        // naturalSize is the raw pixel dimensions of the video track.
        // preferredTransform is a CGAffineTransform that the camera sets to indicate
        // how the video should be displayed (e.g., a phone held vertically records
        // in landscape but sets a 90-degree rotation transform).
        //
        // We apply the transform to naturalSize to get the "as displayed" dimensions.
        // The abs() calls handle negative values from rotation transforms.

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let transformedSize = naturalSize.applying(preferredTransform)
        let videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

        // ── Step 4b: Compute the output render size and layer transform ──
        // computeTransform() handles all the geometry math for rotation and cropping.
        // It returns:
        //   - renderSize: The pixel dimensions of the exported video
        //   - layerTransform: A CGAffineTransform to apply to each frame

        let (renderSize, layerTransform) = computeTransform(
            videoSize: videoSize,
            rotation: params.rotation,
            aspectRatio: params.aspectRatio,
            cropOffset: params.cropOffset
        )

        videoComposition.renderSize = renderSize

        // ── Step 4c: Create composition instructions ──
        // Instructions tell the video composition WHAT to do and WHEN.
        // - AVMutableVideoCompositionInstruction: Covers a time range
        // - AVMutableVideoCompositionLayerInstruction: Per-track transform/opacity
        //
        // We have one instruction covering the entire output duration,
        // and one layer instruction for our single video track.
        //
        // The combined transform chains the camera's preferred transform
        // (which corrects for device orientation at recording time) with
        // our user-applied rotation and crop.

        let instruction = AVMutableVideoCompositionInstruction()
        let outputDuration = composition.duration  // Duration after speed scaling
        instruction.timeRange = CMTimeRange(start: .zero, duration: outputDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(
            assetTrack: compositionVideoTrack
        )

        // Chain transforms: first the camera's orientation fix, then our edits.
        // .concatenating() means "apply layerTransform AFTER preferredTransform".
        let combinedTransform = preferredTransform.concatenating(layerTransform)
        layerInstruction.setTransform(combinedTransform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // ── Step 5: Create and configure the export session ──
        // AVAssetExportSession takes a composition and writes it to a file.
        //
        // AVAssetExportPreset1920x1080: Targets 1080p output. The actual output
        // dimensions are determined by videoComposition.renderSize, but this preset
        // sets the quality/bitrate appropriate for 1080p content.
        //
        // outputFileType .mp4: Universal format playable on all devices.

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1920x1080
        ) else {
            throw PipelineError.exportFailed("Could not create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        // ── Step 5a: Progress monitoring ──
        // AVAssetExportSession doesn't have a delegate or callback for progress.
        // Instead, we poll `exportSession.progress` (a Float from 0.0 to 1.0)
        // on a detached task every 100ms and forward it to the UI via progressHandler.
        //
        // The detached task runs independently and is cancelled when export completes.
        // MainActor.run ensures the UI update happens on the main thread.

        let progressTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms polling interval
                await MainActor.run {
                    progressHandler(exportSession.progress)
                }
            }
        }

        // ── Step 5b: Perform the export ──
        // `exportSession.export()` is the modern async API (iOS 18+).
        // It blocks this async context until the export finishes (success, failure, or cancel).

        await exportSession.export()
        progressTask.cancel()  // Stop polling now that export is done

        // ── Step 6: Handle the result ──
        // Check the export session's status and return/throw accordingly.
        // VideoEditorView catches these to show success haptics or error alerts.

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

    /// Computes the output render size and the CGAffineTransform needed to
    /// rotate and/or crop the video to the desired aspect ratio.
    ///
    /// This is pure geometry math — no AVFoundation APIs, no side effects.
    ///
    /// HOW ROTATION WORKS:
    /// CGAffineTransform rotations rotate around the origin (0,0), which is the
    /// top-left corner. After rotation, the content may be off-screen (negative coords).
    /// We fix this with a translation that moves the rotated content back into the
    /// positive quadrant (visible area).
    ///
    /// Example for 90-degree clockwise rotation of a 1920x1080 video:
    ///   1. Rotate 90 degrees: content now extends into negative X space
    ///   2. Translate by (height=1080, 0): shifts content right so it's fully visible
    ///   3. New dimensions become 1080x1920 (width/height swap)
    ///
    /// HOW CROPPING WORKS:
    /// When the video's current aspect ratio doesn't match the target, we crop
    /// by translating the content so only the desired portion is within the render size.
    /// The cropOffset (0.0...1.0) controls where in the frame the crop window sits.
    ///
    /// Example: 1920x1080 video (16:9) cropped to 1:1 (square):
    ///   - Target width = 1080 * 1.0 = 1080 (height * targetRatio)
    ///   - Excess width = 1920 - 1080 = 840px to remove
    ///   - cropOffset.x = 0.5 -> offsetX = 840 * 0.5 = 420px (center crop)
    ///   - Translate by (-420, 0) to center the crop window
    ///   - Render size becomes 1080x1080
    ///
    /// - Parameters:
    ///   - videoSize: The video's display dimensions (after preferredTransform)
    ///   - rotation: The user's chosen rotation
    ///   - aspectRatio: The user's chosen aspect ratio
    ///   - cropOffset: Normalized (0...1) crop position; (0.5, 0.5) = center
    ///
    /// - Returns: A tuple of (renderSize, transform) where:
    ///   - renderSize: The final pixel dimensions of the exported video
    ///   - transform: The CGAffineTransform to apply in the layer instruction

    private static func computeTransform(
        videoSize: CGSize,
        rotation: VideoRotation,
        aspectRatio: AspectRatio,
        cropOffset: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> (CGSize, CGAffineTransform) {

        // Start with the video's display size and identity transform (no-op).
        // We'll mutate both as we apply rotation and cropping.
        var size = videoSize
        var transform = CGAffineTransform.identity

        // ── Apply rotation ──
        // Each rotation case applies a translate + rotate combination.
        // The translation compensates for the rotation moving content off-screen.
        // 90 and 270 degree rotations swap width/height.

        switch rotation {
        case .none:
            break  // No rotation — identity transform is correct

        case .clockwise90:
            // Rotate 90 degrees clockwise around origin, then translate right
            // by the original height to bring content back into view.
            transform = transform
                .translatedBy(x: size.height, y: 0)
                .rotated(by: .pi / 2)  // 90 degrees in radians
            size = CGSize(width: size.height, height: size.width)  // Swap dimensions

        case .clockwise180:
            // Rotate 180 degrees around origin, then translate by (width, height)
            // to bring content back into view. Dimensions don't change.
            transform = transform
                .translatedBy(x: size.width, y: size.height)
                .rotated(by: .pi)  // 180 degrees in radians

        case .clockwise270:
            // Rotate 270 degrees clockwise (= 90 degrees counter-clockwise).
            // Translate down by original width to bring content back into view.
            transform = transform
                .translatedBy(x: 0, y: size.width)
                .rotated(by: -.pi / 2)  // -90 degrees in radians
            size = CGSize(width: size.height, height: size.width)  // Swap dimensions
        }

        // ── Apply aspect ratio crop (in rotated coordinate space) ──
        // If a target ratio is specified, we compare it to the current ratio
        // and crop whichever dimension is "too large."
        //
        // Two cases:
        //   - currentRatio > targetRatio: video is too wide -> crop horizontally
        //   - currentRatio < targetRatio: video is too tall -> crop vertically
        //   - currentRatio == targetRatio: no crop needed (exact match)

        if let targetRatio = aspectRatio.ratio {
            let currentRatio = size.width / size.height

            if currentRatio > targetRatio {
                // Video is wider than target — crop left/right edges.
                // Calculate the new width that matches the target ratio,
                // then use cropOffset.x to position the crop window.
                let newWidth = size.height * targetRatio
                let offsetX = (size.width - newWidth) * cropOffset.x
                transform = transform.concatenating(
                    CGAffineTransform(translationX: -offsetX, y: 0)
                )
                size = CGSize(width: newWidth, height: size.height)

            } else if currentRatio < targetRatio {
                // Video is taller than target — crop top/bottom edges.
                // Calculate the new height that matches the target ratio,
                // then use cropOffset.y to position the crop window.
                let newHeight = size.width / targetRatio
                let offsetY = (size.height - newHeight) * cropOffset.y
                transform = transform.concatenating(
                    CGAffineTransform(translationX: 0, y: -offsetY)
                )
                size = CGSize(width: size.width, height: newHeight)
            }
        }

        return (size, transform)
    }
}
