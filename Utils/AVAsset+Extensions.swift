import AVFoundation

extension AVAsset {
    
    /// Asynchronously calculates the rotation of the first video track in quarter turns.
    /// - Returns: An integer representing the number of 90-degree clockwise rotations (0, 1, 2, or 3).
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
