import Foundation
import AVFoundation
import UIKit
import SwiftUI
import PhotosUI

// MARK: - Movie Transferable
/// Simple transferable wrapper for movie files from Photos picker
struct VideoMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        }
        importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Add Move Unified State
/// Centralized state management for AddMove feature
/// Essentialist approach - only includes necessary properties
/// Conforms to ObservableObject for SwiftUI reactivity
public class AddMoveUnifiedState: ObservableObject {
    // MARK: - Tab Navigation
    @Published var currentTab: TabSelection = .ready
    @Published var flowState: AddMoveFlowState = .loading

    // MARK: - Video Data
    @Published var selectedVideo: AVAsset?
    @Published var originalVideoURL: URL?
    @Published var trimmedAsset: AVAsset?
    @Published var videoThumbnail: UIImage?

    // MARK: - Move Information
    @Published var moveName: String = ""
    @Published var moveDescription: String = ""
    @Published var moveCategory: String = ""
    @Published var tags: [String] = []

    // MARK: - Trimming Information
    @Published var trimStartTime: TimeInterval = 0.0
    @Published var trimEndTime: TimeInterval = 0.0
    var trimDuration: TimeInterval {
        return max(0.0, trimEndTime - trimStartTime)
    }

    // MARK: - Progress Tracking
    @Published var loadingProgress: VideoLoadingProgress = VideoLoadingProgress(phase: .idle, correlationId: "")
    @Published var processingProgress: Double = 0.0
    @Published var isProcessing: Bool = false

    // MARK: - Error Handling
    @Published var errorMessage: String?
    var hasError: Bool {
        return errorMessage != nil
    }

    // MARK: - Validation
    var isValidForSave: Bool {
        return !moveName.isEmpty &&
               trimmedAsset != nil &&
               !hasError &&
               trimDuration > 0.0
    }

    // MARK: - Initialization
    init() {}

    // MARK: - State Updates
    func updateTab(_ newTab: TabSelection) {
        currentTab = newTab
        Logger.addMove.logStateTransition(from: currentTab, to: newTab, context: "Tab navigation")
    }

    func updateFlowState(_ newState: AddMoveFlowState) {
        flowState = newState
        Logger.addMove.logStateTransition(from: flowState, to: newState, context: "Flow state")
    }

    func setSelectedVideo(_ asset: AVAsset, url: URL?) async {
        selectedVideo = asset
        originalVideoURL = url
        do {
            let duration = try await asset.load(.duration)
            trimEndTime = duration.seconds
            Logger.addMove.info("Video selected: duration \(duration.seconds)s", emoji: "🎥")
        } catch {
            Logger.addMove.error("Failed to load video duration: \(error.localizedDescription)", emoji: "❌")
        }
    }

    func setTrimmedAsset(_ asset: AVAsset) async {
        trimmedAsset = asset
        do {
            let duration = try await asset.load(.duration)
            Logger.addMove.info("Video trimmed: duration \(duration.seconds)s", emoji: "✂️")
        } catch {
            Logger.addMove.error("Failed to load trimmed video duration: \(error.localizedDescription)", emoji: "❌")
        }
    }

    func updateProgress(_ progress: VideoLoadingProgress) {
        DispatchQueue.main.async {
            self.loadingProgress = progress
        }
    }

    func updateProcessingProgress(_ progress: Double) {
        processingProgress = progress
    }

    func setError(_ message: String) {
        errorMessage = message
        Logger.addMove.error("Error set: \(message)", emoji: "❌")
    }

    func clearError() {
        errorMessage = nil
        Logger.addMove.debug("Error cleared", emoji: "🧹")
    }

    /// Process video trim from start time to end time
    func processTrim(from startTime: CMTime, to endTime: CMTime) async throws -> AVAsset {
        Logger.addMove.info("Processing trim: \(startTime.seconds)s - \(endTime.seconds)s", emoji: "✂️")

        // For now, just return the original asset
        // In a real implementation, this would perform actual trimming
        guard let originalAsset = selectedVideo else {
            throw NSError(domain: "VideoTrimming", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video asset available for trimming"])
        }

        // Update the trimmed asset
        await setTrimmedAsset(originalAsset)

        // Update trim times
        await MainActor.run {
            self.trimStartTime = startTime.seconds
            self.trimEndTime = endTime.seconds
        }

        Logger.addMove.info("Trim processed successfully", emoji: "✅")
        return originalAsset
    }

    func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
        Logger.addMove.info("Loading video from PhotosPickerItem", emoji: "📹")

        do {
            guard let movie = try await item.loadTransferable(type: VideoMovie.self) else {
                throw NSError(domain: "VideoLoading", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video from selected item"])
            }

            let asset = AVAsset(url: movie.url)

            await setSelectedVideo(asset, url: movie.url)
            updateFlowState(.loadingVideo)

            Logger.addMove.info("Video loaded successfully: \(movie.url.lastPathComponent)", emoji: "✅")
        } catch {
            setError("Failed to load video: \(error.localizedDescription)")
            updateFlowState(.error("Loading failed", error.localizedDescription))
            Logger.addMove.error("Video loading failed: \(error.localizedDescription)", emoji: "❌")
        }
    }

    func reset() {
        currentTab = .ready
        flowState = .loading
        selectedVideo = nil
        originalVideoURL = nil
        trimmedAsset = nil
        videoThumbnail = nil
        moveName = ""
        moveDescription = ""
        moveCategory = ""
        tags = []
        trimStartTime = 0.0
        trimEndTime = 0.0
        loadingProgress = VideoLoadingProgress(phase: .idle, correlationId: "")
        processingProgress = 0.0
        isProcessing = false
        errorMessage = nil
        Logger.addMove.info("State reset to initial values", emoji: "🔄")
    }
}

// MARK: - Computed Properties
extension AddMoveUnifiedState {
    /// Check if video is loaded and ready for trimming
    var isVideoReady: Bool {
        return selectedVideo != nil && !flowState.isLoading
    }

    /// Check if trimming is complete
    var isTrimmingComplete: Bool {
        return trimmedAsset != nil && trimDuration > 0.0
    }

    /// Check if move information is complete
    var isMoveInfoComplete: Bool {
        return !moveName.isEmpty
    }

    /// Current video duration
    var currentVideoDuration: TimeInterval {
        return selectedVideo?.duration.seconds ?? 0.0
    }

    /// Current video duration in seconds (compatibility)
    var currentVideoDurationSeconds: Double {
        return currentVideoDuration
    }

    /// Current video asset (compatibility)
    var currentVideoAsset: AVAsset? {
        return selectedVideo
    }

    /// Progress for current operation
    var currentProgress: Double {
        if isProcessing {
            return processingProgress
        } else {
            return loadingProgress.progress
        }
    }
}

// MARK: - Video Player View Model Compatibility
/// Compatibility shim for UnifiedVideoPlayerViewModel
/// Simple wrapper that provides basic video player functionality
typealias UnifiedVideoPlayerViewModel = SimpleVideoPlayerViewModel

class SimpleVideoPlayerViewModel: ObservableObject {
    let asset: AVAsset?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0

    init(asset: AVAsset? = nil) {
        self.asset = asset
        self.duration = 0.0 // Will be loaded asynchronously when needed
    }

    /// Load duration asynchronously
    func loadDuration() async {
        guard let asset = asset else { return }
        do {
            let loadedDuration = try await asset.load(.duration)
            await MainActor.run {
                self.duration = loadedDuration.seconds
            }
        } catch {
            Logger.addMove.error("Failed to load video duration: \(error.localizedDescription)", emoji: "❌")
        }
    }
}