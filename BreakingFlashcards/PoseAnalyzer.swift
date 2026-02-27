// PoseAnalyzer.swift — On-Device Pose Estimation for Breakdex
//
// Wraps Apple's Vision framework to detect 2D and 3D human body poses from
// video frames. This is the foundation for balance analysis and pose overlay.
//
// APPLE VISION POSE DETECTION:
//   - VNDetectHumanBodyPoseRequest (iOS 14+): Returns 19 2D joint positions
//     in normalized image coordinates [0,1]. Runs on Neural Engine automatically.
//   - VNDetectHumanBodyPose3DRequest (iOS 17+): Returns 17 3D joint positions
//     in meters relative to the hip (root joint). Enables real biomechanical
//     computation like center-of-mass and balance analysis.
//
// WHY AN ENUM (NOT A CLASS):
//   Stateless utility — no stored properties, no lifecycle. Same pattern as
//   AIMoveSuggester. Using a caseless enum prevents accidental instantiation.
//
// PERFORMANCE:
//   - 2D pose: ~30fps on Neural Engine (< 33ms per frame)
//   - 3D pose: ~25fps on Neural Engine (< 40ms per frame)
//   - Frame extraction: ~5-15ms via AVAssetImageGenerator
//   For overlay use, we throttle to ~10fps to avoid overwhelming the GPU.
//
// KNOWN LIMITATION:
//   Vision's pose model is trained on upright COCO-style poses. Inverted
//   breakdancing poses (freezes, headstands) will have degraded accuracy.
//   This is acceptable for Phase 1 — we validate feasibility first.
//
// CONNECTED FILES:
//   - BalanceAnalyzer.swift: Consumes 3D pose observations for balance scoring
//   - PoseOverlayView.swift: Consumes 2D pose observations for skeleton drawing
//   - MoveDetailView.swift: Triggers pose analysis and displays results

import Vision
import AVFoundation

enum PoseAnalyzer {

    // MARK: - 2D Pose Detection (iOS 14+)

    /// Detect 2D body pose from a CGImage (extracted video frame or photo).
    ///
    /// Returns the highest-confidence person detected. If multiple people are
    /// in the frame, only the first result is returned (breakdancing is typically
    /// one dancer at a time).
    ///
    /// The returned VNHumanBodyPoseObservation contains 19 recognized points
    /// in normalized image coordinates where (0,0) is bottom-left and (1,1) is
    /// top-right. Use recognizedPoint(.jointName) to access individual joints.
    ///
    /// - Parameter image: A CGImage from a video frame or photo.
    /// - Returns: The detected pose observation, or nil if no person was found.
    static func detect2DPose(from image: CGImage) throws -> VNHumanBodyPoseObservation? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first
    }

    /// Detect 2D body pose from a CVPixelBuffer (live video frame).
    ///
    /// CVPixelBuffer is the native format from AVCaptureSession and
    /// AVAssetImageGenerator's copyCGImage. Using it directly avoids an
    /// extra CGImage conversion step, saving ~2-5ms per frame.
    ///
    /// - Parameter pixelBuffer: A pixel buffer from the camera or video decoder.
    /// - Returns: The detected pose observation, or nil if no person was found.
    static func detect2DPose(from pixelBuffer: CVPixelBuffer) throws -> VNHumanBodyPoseObservation? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])
        return request.results?.first
    }

    // MARK: - 3D Pose Detection (iOS 17+)

    /// Detect 3D body pose from a CGImage.
    ///
    /// Returns joint positions in meters relative to the hip (root) joint.
    /// The coordinate system is:
    ///   - X: positive = right of the person
    ///   - Y: positive = up
    ///   - Z: positive = toward the camera
    ///
    /// 3D pose enables biomechanical analysis (center of mass, balance, tilt)
    /// that isn't possible with 2D normalized coordinates alone.
    ///
    /// - Parameter image: A CGImage from a video frame.
    /// - Returns: The detected 3D pose observation, or nil if no person was found.
    @available(iOS 17.0, *)
    static func detect3DPose(from image: CGImage) throws -> VNHumanBodyPose3DObservation? {
        let request = VNDetectHumanBodyPose3DRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first
    }

    // MARK: - Frame Extraction

    /// Extract a CGImage from an AVAsset at a specific time.
    ///
    /// Uses AVAssetImageGenerator with zero tolerance for precise frame extraction
    /// (important for pose analysis — we want exactly the frame at the playhead).
    /// appliesPreferredTrackTransform ensures the image is oriented correctly
    /// regardless of how the video was recorded (portrait, landscape, mirrored).
    ///
    /// - Parameters:
    ///   - asset: The video asset to extract from.
    ///   - time: The timestamp to extract the frame at.
    /// - Returns: The extracted frame as a CGImage, or nil on failure.
    static func extractFrame(from asset: AVAsset, at time: CMTime) async throws -> CGImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(at: time)
        return image
    }

    /// Extract a CGImage from a file URL at a specific time.
    ///
    /// Convenience wrapper that creates an AVURLAsset from the URL.
    /// Used by MoveDetailView which has the video URL but not the AVAsset.
    ///
    /// - Parameters:
    ///   - url: File URL to the video.
    ///   - time: The timestamp to extract the frame at.
    /// - Returns: The extracted frame as a CGImage, or nil on failure.
    static func extractFrame(from url: URL, at time: CMTime) async throws -> CGImage? {
        let asset = AVURLAsset(url: url)
        return try await extractFrame(from: asset, at: time)
    }
}
