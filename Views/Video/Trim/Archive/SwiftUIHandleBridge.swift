//
//  SwiftUIHandleBridge.swift
//  BreakingFlashcards
//
//  Created by Principal Solutions Architect
//  Bridge that hosts SwiftUI HandleView content with precise UIKit gesture handling
//

import SwiftUI
import UIKit

/// UIViewRepresentable that hosts SwiftUI HandleView content with UIKit pan gestures
/// This provides the precision of UIKit gestures while maintaining SwiftUI's declarative UI
struct SwiftUIHandleBridge<Content: View>: UIViewRepresentable {
    let content: Content
    let onChanged: (UIPanGestureRecognizer) -> Void
    let onEnded: (UIPanGestureRecognizer) -> Void
    let isStartHandle: Bool

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        // Create hosting controller for SwiftUI content
        let hostingController = UIHostingController(rootView: AnyView(content))
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Add hosting controller's view to container
        containerView.addSubview(hostingController.view)

        // Set up constraints to match the handle size
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            hostingController.view.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            hostingController.view.widthAnchor.constraint(equalToConstant: 44),
            hostingController.view.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Add precise pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 1
        panGesture.minimumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false

        // Only allow horizontal panning for trim handles
        panGesture.allowedScrollTypesMask = []

        containerView.addGestureRecognizer(panGesture)

        // Store hosting controller reference for cleanup
        context.coordinator.hostingController = hostingController

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the SwiftUI content if needed
        if let hostingController = context.coordinator.hostingController {
            hostingController.rootView = AnyView(content)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    class Coordinator: NSObject {
        let onChanged: (UIPanGestureRecognizer) -> Void
        let onEnded: (UIPanGestureRecognizer) -> Void
        weak var hostingController: UIHostingController<AnyView>?

        init(onChanged: @escaping (UIPanGestureRecognizer) -> Void,
             onEnded: @escaping (UIPanGestureRecognizer) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .changed:
                onChanged(gesture)
            case .ended, .cancelled:
                onEnded(gesture)
            default:
                break
            }
        }
    }
}
