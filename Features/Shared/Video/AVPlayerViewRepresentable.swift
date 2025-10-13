import SwiftUI
import AVKit

// AVPlayerViewRepresentable.swift - bridge between UIKit's AVPlayerViewController and SwiftUI

// MARK: - AV Player View Representable
/// Bridge between UIKit's AVPlayerViewController and SwiftUI
/// SwiftUI can't directly use UIKit components like AVPlayerViewController, so this wrapper
/// converts the native iOS video player (UIKit-based) into something SwiftUI can display.
/// This is a common pattern for using existing UIKit components in SwiftUI apps.
struct AVPlayerViewRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}