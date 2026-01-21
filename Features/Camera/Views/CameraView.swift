//
//  CameraView.swift
//  BreakingFlashcards
//
//  Created by Claude on 01/20/26.
//

import AVFoundation
import AVKit
import SwiftUI

// MARK: - Camera View
/// Main camera view for recording breaking moves directly from the app.
/// Provides native camera recording with controls for flash, camera switching, and duration display.
struct CameraView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = CameraViewModel()
    @State private var showVideoPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Camera Preview
                    cameraPreviewSection

                    // MARK: - Controls
                    controlsSection
                }
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.cameraState == .recording {
                        // Recording indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("REC")
                                .font(.ibmPlexMono(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.cameraState == .ready || viewModel.cameraState == .idle {
                        Button {
                            viewModel.switchCamera()
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Switch camera")
                    }
                }
            }
            .onAppear {
                viewModel.checkPermissions()
            }
            .onDisappear {
                viewModel.stopCaptureSession()
            }
            .sheet(isPresented: $showVideoPreview) {
                if case .completed(let url) = viewModel.cameraState {
                    VideoPreviewSheet(
                        videoURL: url,
                        onUse: {
                            handleUseRecording(url)
                        },
                        onRetake: {
                            viewModel.resetState()
                            showVideoPreview = false
                        }
                    )
                }
            }
            .onChange(of: viewModel.cameraState) { _, newState in
                if case .completed = newState {
                    showVideoPreview = true
                }
            }
        }
    }

    // MARK: - Camera Preview Section
    @ViewBuilder
    private var cameraPreviewSection: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.hasPermission, let session = viewModel.captureSession {
                    CameraPreviewView(session: session)
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.7)
                } else {
                    permissionDeniedView
                }

                // State overlays
                stateOverlay
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Permission Denied View
    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Camera Access Required")
                .font(.ibmPlexMono(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Please enable camera and microphone access in Settings to record moves.")
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - State Overlay
    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.cameraState {
        case .preparing:
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Preparing camera...")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.white)
                    .padding(.top, 12)
            }

        case .processing:
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Processing video...")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.white)
                    .padding(.top, 12)
            }

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)

                Text(message)
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Try Again") {
                    viewModel.checkPermissions()
                }
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(6)
            }

        case .recording:
            // Duration display at top
            VStack {
                Text(viewModel.formattedDuration)
                    .font(.ibmPlexMono(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(.top, 20)

                Spacer()
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Controls Section
    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 24) {
            Spacer()

            // Recording controls
            HStack(spacing: 60) {
                // Flash toggle
                Button {
                    viewModel.toggleFlash()
                } label: {
                    Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.isFlashOn ? .yellow : .white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(viewModel.isFlashOn ? "Turn off flash" : "Turn on flash")
                .disabled(viewModel.cameraState == .recording)
                .opacity(viewModel.cameraState == .recording ? 0.5 : 1)

                // Record button
                recordButton

                // Placeholder for symmetry
                Color.clear
                    .frame(width: 44, height: 44)
            }

            // Instructions
            if viewModel.cameraState == .ready {
                Text("Tap to start recording your move")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.gray)
            } else if viewModel.cameraState == .recording {
                Text("Tap to stop recording")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .frame(height: 180)
        .background(Color.black)
    }

    // MARK: - Record Button
    @ViewBuilder
    private var recordButton: some View {
        Button {
            if viewModel.cameraState == .recording {
                viewModel.stopRecording()
            } else if viewModel.cameraState == .ready {
                viewModel.startRecording()
            }
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                // Inner shape
                if viewModel.cameraState == .recording {
                    // Stop button (square)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    // Record button (circle)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .accessibilityLabel(viewModel.cameraState == .recording ? "Stop recording" : "Start recording")
        .disabled(viewModel.cameraState != .ready && viewModel.cameraState != .recording)
    }

    // MARK: - Actions
    private func handleUseRecording(_ url: URL) {
        // Navigate to Add Move tab with the recorded video
        // The video URL would be passed to the AddMoveViewModel
        // For now, switch to Add Move tab
        selectedTab = 1
        showVideoPreview = false

        // Post notification for AddMoveView to pick up the recorded video
        NotificationCenter.default.post(
            name: .didRecordVideo,
            object: nil,
            userInfo: ["videoURL": url]
        )
    }
}

// MARK: - Camera Preview UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Video Preview Sheet
struct VideoPreviewSheet: View {
    let videoURL: URL
    let onUse: () -> Void
    let onRetake: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video player
                CameraVideoPreview(url: videoURL)
                    .frame(maxHeight: .infinity)

                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        onRetake()
                        dismiss()
                    } label: {
                        Text("Retake")
                            .font(.ibmPlexMono(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                    }

                    Button {
                        onUse()
                        dismiss()
                    } label: {
                        Text("Use Video")
                            .font(.ibmPlexMono(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black)
            }
            .background(Color.black)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onRetake()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Camera Video Preview
/// Simple wrapper to play a recorded video for preview
struct CameraVideoPreview: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                AVPlayerViewRepresentable(player: player, rotation: .degrees0)
                    .aspectRatio(9/16, contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let didRecordVideo = Notification.Name("didRecordVideo")
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab = 4

        var body: some View {
            CameraView(selectedTab: $selectedTab)
        }
    }

    return PreviewWrapper()
}
