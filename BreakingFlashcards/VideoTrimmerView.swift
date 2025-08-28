//
//  VideoTrimmerView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/27/25.
//

import SwiftUI
import PhotosUI
import Foundation

struct VideoTrimmerView: UIViewControllerRepresentable {
    let videoURL: URL
    let onComplete: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        // Check if we're on simulator - UIVideoEditorController doesn't work on simulator
        #if targetEnvironment(simulator)
        return makeSimulatorFallbackController(context: context)
        #else
        return makeVideoEditorController(context: context)
        #endif
    }
    
    private func makeVideoEditorController(context: Context) -> UIViewController {
        // Validate file exists first
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            print("Video file does not exist at path: \(videoURL.path)")
            DispatchQueue.main.async {
                onComplete(nil)
            }
            return UIViewController()
        }
        
        // Check if video editing is available and video can be edited
        guard UIVideoEditorController.canEditVideo(atPath: videoURL.path) else {
            print("Video cannot be edited at path: \(videoURL.path)")
            DispatchQueue.main.async {
                onComplete(videoURL) // Return original URL if trimming not possible
            }
            return UIViewController()
        }
        
        let editor = UIVideoEditorController()
        editor.videoPath = videoURL.path
        editor.delegate = context.coordinator
        return editor
    }
    
    private func makeSimulatorFallbackController(context: Context) -> UIViewController {
        let alert = UIAlertController(
            title: "Video Trimming", 
            message: "Video trimming is not available in the simulator. Would you like to use the video as-is?", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Use Original", style: .default) { _ in
            self.onComplete(self.videoURL)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.onComplete(nil)
        })
        
        let controller = UIViewController()
        DispatchQueue.main.async {
            controller.present(alert, animated: true)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIVideoEditorControllerDelegate {
        let parent: VideoTrimmerView

        init(_ parent: VideoTrimmerView) {
            self.parent = parent
        }

        func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
            editor.dismiss(animated: true) {
                self.parent.onComplete(URL(fileURLWithPath: editedVideoPath))
            }
        }

        func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
            editor.dismiss(animated: true) {
                self.parent.onComplete(nil) // User cancelled trimming.
            }
        }

        func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
            print("Video editor failed with error: \(error.localizedDescription)")
            editor.dismiss(animated: true) {
                self.parent.onComplete(self.parent.videoURL) // Return original on error
            }
        }
    }
}
