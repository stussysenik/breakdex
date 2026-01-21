//
//  CameraViewModel.swift
//  BreakingFlashcards
//
//  Created by Claude on 01/20/26.
//

import AVFoundation
import Combine
import OSLog
import SwiftUI

// MARK: - Camera State
enum CameraState: Equatable {
    case idle
    case preparing
    case ready
    case recording
    case processing
    case completed(URL)
    case error(String)

    static func == (lhs: CameraState, rhs: CameraState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.ready, .ready),
             (.recording, .recording), (.processing, .processing):
            return true
        case let (.completed(url1), .completed(url2)):
            return url1 == url2
        case let (.error(msg1), .error(msg2)):
            return msg1 == msg2
        default:
            return false
        }
    }
}

// MARK: - Camera ViewModel
@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var cameraState: CameraState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var isFlashOn: Bool = false
    @Published var isFrontCamera: Bool = false
    @Published var hasPermission: Bool = false
    @Published var errorMessage: String?

    // MARK: - AVFoundation Properties
    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentDevice: AVCaptureDevice?
    private var recordingTimer: Timer?
    private var tempFileURL: URL?

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "CameraViewModel")

    // MARK: - Constants
    private let maxRecordingDuration: TimeInterval = 60 // 1 minute max

    // MARK: - Initialization
    override init() {
        super.init()
        checkPermissions()
    }

    deinit {
        // Stop session on deinit - capture session operations are thread-safe
        captureSession?.stopRunning()
        recordingTimer?.invalidate()
    }

    // MARK: - Permission Handling
    func checkPermissions() {
        Task {
            let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
            let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

            switch (videoStatus, audioStatus) {
            case (.authorized, .authorized):
                hasPermission = true
                await setupCaptureSession()
            case (.notDetermined, _), (_, .notDetermined):
                await requestPermissions()
            default:
                hasPermission = false
                cameraState = .error("Camera or microphone access denied. Please enable in Settings.")
            }
        }
    }

    private func requestPermissions() async {
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        let audioGranted = await AVCaptureDevice.requestAccess(for: .audio)

        hasPermission = videoGranted && audioGranted

        if hasPermission {
            await setupCaptureSession()
        } else {
            cameraState = .error("Camera and microphone access required to record moves.")
        }
    }

    // MARK: - Capture Session Setup
    func setupCaptureSession() async {
        cameraState = .preparing
        logger.info("Setting up capture session")

        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Setup video input
        guard let videoDevice = getCamera(position: isFrontCamera ? .front : .back) else {
            cameraState = .error("Could not access camera")
            return
        }

        currentDevice = videoDevice

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            // Setup audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }

            // Setup movie output
            let movieOutput = AVCaptureMovieFileOutput()
            movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                videoOutput = movieOutput
            }

            captureSession = session

            // Start session on background thread
            Task.detached(priority: .userInitiated) { [weak self] in
                session.startRunning()
                await MainActor.run {
                    self?.cameraState = .ready
                    self?.logger.info("Capture session ready")
                }
            }

        } catch {
            logger.error("Failed to setup capture session: \(error.localizedDescription)")
            cameraState = .error("Failed to setup camera: \(error.localizedDescription)")
        }
    }

    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Recording Controls
    func startRecording() {
        guard cameraState == .ready,
              let output = videoOutput,
              !output.isRecording else {
            logger.warning("Cannot start recording - invalid state")
            return
        }

        // Create temp file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "move_recording_\(UUID().uuidString).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        tempFileURL = fileURL

        logger.info("Starting recording to \(fileURL.lastPathComponent)")
        output.startRecording(to: fileURL, recordingDelegate: self)

        cameraState = .recording
        recordingDuration = 0

        // Start timer for duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

        HapticFeedback.actionHaptic()
    }

    func stopRecording() {
        guard let output = videoOutput, output.isRecording else {
            logger.warning("Cannot stop - not recording")
            return
        }

        logger.info("Stopping recording")
        output.stopRecording()

        recordingTimer?.invalidate()
        recordingTimer = nil

        cameraState = .processing
        HapticFeedback.actionHaptic()
    }

    // MARK: - Camera Controls
    func toggleFlash() {
        guard let device = currentDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            device.unlockForConfiguration()
            isFlashOn.toggle()
        } catch {
            logger.error("Failed to toggle flash: \(error.localizedDescription)")
        }
    }

    func switchCamera() {
        isFrontCamera.toggle()

        Task {
            await setupCaptureSession()
        }
    }

    // MARK: - Session Control
    func stopCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func resetState() {
        cameraState = .ready
        recordingDuration = 0
        tempFileURL = nil
    }

    // MARK: - Formatting
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Recording failed: \(error.localizedDescription)")
                cameraState = .error("Recording failed: \(error.localizedDescription)")
                return
            }

            logger.info("Recording completed: \(outputFileURL.lastPathComponent)")
            cameraState = .completed(outputFileURL)
        }
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didStartRecordingTo fileURL: URL,
                                from connections: [AVCaptureConnection]) {
        Task { @MainActor in
            logger.info("Recording started")
        }
    }
}
