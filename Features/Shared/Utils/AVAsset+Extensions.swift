import AVFoundation
import OSLog

extension AVAsset {

    /// MARK: - Extracts the intrinsic rotation of the video asset in quarter turns from metadata.
    /// This method analyzes the asset's video track transform matrix to determine
    /// the native rotation stored in the video file using modern AVFoundation APIs.
    ///
    /// **Category Theory Analysis**:
    /// - **Objects**: AVAsset, AVAssetTrack, CGAffineTransform
    /// - **Morphisms**: loadTracks(with:), load(.preferredTransform), transform analysis
    /// - **Functor**: Maps asset metadata to rotation representation
    /// - **Natural Transformation**: Converts CGAffineTransform to discrete quarter turns
    ///
    /// - Returns: An integer representing the number of 90-degree clockwise rotations (0, 1, 2, or 3).
    /// - Note: This is the asset's intrinsic rotation, not user-applied rotation.
    func getRotationInQuarterTurns() async -> Int {
        let logger = Logger(subsystem: "BreakingFlashcards", category: "🔄 AVAsset_Rotation")
        let startTime = CFAbsoluteTimeGetCurrent()

        logger.debug("🔄 [CAT] Extracting intrinsic rotation from video asset")
        logger.debug("🔄 [CAT] Domain: AVAsset → AVAssetTrack → CGAffineTransform → Int")

        // MARK: - Morphism 1: AVAsset → [AVAssetTrack] (async track loading)
        // Using modern async/await API with proper error handling
        let videoTracks: [AVAssetTrack]
        do {
            videoTracks = try await self.loadTracks(withMediaType: .video)
            logger.debug("🔄 [CAT] Loaded \(videoTracks.count) video tracks")
        } catch {
            logger.warning("🔄 [CAT] ⚠️ Failed to load video tracks: \(error.localizedDescription)")
            return 0
        }

        guard let videoTrack = videoTracks.first else {
            logger.warning("🔄 [CAT] ⚠️ No video tracks found, identity morphism → 0 rotation")
            return 0
        }

        // MARK: - Morphism 2: AVAssetTrack → CGAffineTransform (transform loading)
        let transform: CGAffineTransform
        do {
            transform = try await videoTrack.load(.preferredTransform)
            logger.debug("🔄 [CAT] Loaded preferred transform: a=\(transform.a), b=\(transform.b), c=\(transform.c), d=\(transform.d)")
        } catch {
            logger.warning("🔄 [CAT] ⚠️ Could not load preferred transform: \(error.localizedDescription)")
            return 0
        }

        // MARK: - Morphism 3: CGAffineTransform → Int (rotation analysis functor)
        // This functor maps continuous transform space to discrete rotation space
        let rotationQuarterTurns = analyzeTransformMatrix(transform, logger: logger)

        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("🔄 [CAT] ✅ Intrinsic asset rotation extracted: \(rotationQuarterTurns) quarter turns in \(String(format: "%.2f", executionTime * 1000))ms")
        logger.debug("🔄 [CAT] Composition: AVAsset → [AVAssetTrack] → CGAffineTransform → Int")

        return rotationQuarterTurns
    }

    /// MARK: - Analyzes CGAffineTransform matrix to determine rotation in quarter turns
    /// This implements a mathematical functor from transform matrices to discrete rotations
    ///
    /// **Functor Properties**:
    /// - **Preserves identity**: Identity transform → 0 rotations
    /// - **Preserves composition**: Transform composition → rotation addition (mod 4)
    ///
    /// - Parameters:
    ///   - transform: The CGAffineTransform to analyze
    ///   - logger: Diagnostic logger for detailed analysis
    /// - Returns: Integer representing quarter turns (0, 1, 2, 3)
    private func analyzeTransformMatrix(_ transform: CGAffineTransform, logger: Logger) -> Int {
        let a = transform.a
        let b = transform.b
        let c = transform.c
        let d = transform.d

        logger.debug("🔄 [CAT] Matrix analysis: [\(a), \(b); \(c), \(d)]")

        // MARK: - Isomorphism check: Verify this is a pure rotation matrix
        // For pure rotation: a² + b² = 1, c² + d² = 1, ac + bd = 0
        let determinant = a * d - b * c
        let isPureRotation = abs(determinant - 1.0) < 0.001 &&
                             abs(a * c + b * d) < 0.001 &&
                             abs(a * a + b * b - 1.0) < 0.001 &&
                             abs(c * c + d * d - 1.0) < 0.001

        logger.debug("🔄 [CAT] Pure rotation check: determinant=\(determinant), isPure=\(isPureRotation)")

        let rotationQuarterTurns: Int
        let rotationDescription: String

        // MARK: - Standard rotation matrices mapped to quarter turns
        if a == 0 && b == 1.0 && c == -1.0 && d == 0 {
            // [ 0,  1; -1,  0] = 90° clockwise rotation
            rotationQuarterTurns = 1
            rotationDescription = "90° clockwise"
        } else if a == 0 && b == -1.0 && c == 1.0 && d == 0 {
            // [ 0, -1;  1,  0] = 270° clockwise (90° counter-clockwise)
            rotationQuarterTurns = 3
            rotationDescription = "270° clockwise (90° counter-clockwise)"
        } else if a == -1.0 && b == 0 && c == 0 && d == -1.0 {
            // [-1,  0;  0, -1] = 180° rotation
            rotationQuarterTurns = 2
            rotationDescription = "180°"
        } else if a == 1.0 && b == 0 && c == 0 && d == 1.0 {
            // [ 1,  0;  0,  1] = Identity (0° rotation)
            rotationQuarterTurns = 0
            rotationDescription = "0° (identity)"
        } else {
            // MARK: - Non-standard transform - apply mathematical projection
            // Extract angle from transform using atan2
            let angle = atan2(transform.b, transform.a) * (180.0 / .pi)
            let normalizedAngle = ((angle.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0))

            // MARK: - Project continuous angle to discrete quarter turns
            let projectedTurns = Int(round(normalizedAngle / 90.0)) % 4
            rotationQuarterTurns = projectedTurns >= 0 ? projectedTurns : projectedTurns + 4

            rotationDescription = "\(String(format: "%.1f", angle))° → projected to \(rotationQuarterTurns * 90)°"
            logger.warning("🔄 [CAT] ⚠️ Non-standard transform detected, mathematical projection applied")
        }

        logger.info("🔄 [CAT] Rotation analysis result: \(rotationDescription) → \(rotationQuarterTurns) quarter turns")
        return rotationQuarterTurns
    }

    /// Asynchronously calculates the rotation of the first video track in quarter turns.
    /// - Returns: An integer representing the number of 90-degree clockwise rotations (0, 1, 2, or 3).
    /// - Note: This method is maintained for backward compatibility.
    func rotation() async -> Int {
        // Load the tracks asynchronously.
        guard let tracks = try? await self.load(.tracks),
              let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
            return 0
        }
        
        // Load the preferred transform of the video track.
        guard let transform = try? await videoTrack.load(.preferredTransform) else {
            return 0
        }
        
        // Determine the rotation from the transform matrix.
        let a = transform.a
        let b = transform.b
        let c = transform.c
        let d = transform.d
        
        if a == 0 && b == 1.0 && c == -1.0 && d == 0 {
            // Rotated 90 degrees clockwise
            return 1
        } else if a == 0 && b == -1.0 && c == 1.0 && d == 0 {
            // Rotated 90 degrees counter-clockwise
            return 3
        } else if a == -1.0 && b == 0 && c == 0 && d == -1.0 {
            // Rotated 180 degrees
            return 2
        } else {
            // No rotation or unsupported rotation
            return 0
        }
    }
}
