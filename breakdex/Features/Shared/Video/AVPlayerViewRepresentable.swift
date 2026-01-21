import SwiftUI
import AVKit
import OSLog

// AVPlayerViewRepresentable.swift - bridge between UIKit's AVPlayerViewController and SwiftUI

// MARK: - AV Player View Representable
/// Bridge between UIKit's AVPlayerViewController and SwiftUI with rotation support
/// SwiftUI can't directly use UIKit components like AVPlayerViewController, so this wrapper
/// converts the native iOS video player (UIKit-based) into something SwiftUI can display.
/// Enhanced with rotation parameter for video orientation preservation.
struct AVPlayerViewRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let rotation: VideoRotation

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "AVPlayerViewRepresentable"
    )

    init(player: AVPlayer, rotation: VideoRotation = .degrees0) {
        self.player = player
        self.rotation = rotation
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true

        // Apply rotation transform using Apple's recommended approach
        applyRotationTransform(to: controller)

        logger.info("🔄 AVPlayerViewRepresentable created with rotation: \(rotation.description)")
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player

        // Re-apply rotation transform if needed
        applyRotationTransform(to: uiViewController)

        logger.debug("🔄 AVPlayerViewRepresentable updated with rotation: \(rotation.description)")
    }

    // MARK: - Private Methods

    /// Apply rotation transform using Apple's recommended approach
    private func applyRotationTransform(to controller: AVPlayerViewController) {
        guard rotation != .degrees0 else {
            logger.debug("🔄 No rotation needed (0°)")
            return
        }

        logger.info("🔄 Applying rotation transform: \(rotation.description)")

        // Apply rotation to the video layer using CATransform3D
        if let videoLayer = controller.view.layer.sublayers?.first {
            let rotationTransform = CATransform3DMakeRotation(rotation.radians, 0, 0, 1)
            videoLayer.transform = rotationTransform
            logger.info("✅ Rotation transform applied to video layer")
        } else {
            logger.warning("⚠️ Could not find video layer to apply rotation")
        }
    }
}