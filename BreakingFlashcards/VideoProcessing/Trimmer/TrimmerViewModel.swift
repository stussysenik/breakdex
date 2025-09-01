import SwiftUI
import AVKit
import Observation
import BreakingFlashcards

enum TrimmerError: LocalizedError {
    case videoLoadFailed(underlyingError: Error?)
    case invalidVideoDuration

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed(let error):
            return "Failed to load video duration. " + (error?.localizedDescription ?? "")
        case .invalidVideoDuration:
            return "Invalid video duration."
        }
    }
}

@Observable
final class TrimmerViewModel {
    let player: AVPlayer
    let asset: AVAsset
    private var timeObserverToken: Any?

    var startTime: Double = 0
    var endTime: Double = 0
    var videoDuration: Double = 0
    var isDraggingStartHandle: Bool = false
    var isDraggingEndHandle: Bool = false
    var isExporting: Bool = false
    var exportProgress: Double = 0
    var thumbnails: [UIImage] = []
    var isGeneratingThumbnails: Bool = false
    var isEditing: Bool = false
    var currentPreviewImage: UIImage? = nil

    init(asset: AVAsset) {
        self.asset = asset
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        // Create a time observer to monitor playback and loop within trim bounds
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600) // Check every 0.1 seconds

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            let currentSeconds = time.seconds

            // If we're playing and have reached the end time, loop back to start time
            if self.player.timeControlStatus == .playing &&
               currentSeconds >= self.endTime &&
               self.endTime > self.startTime {

                let startTime = CMTime(seconds: self.startTime, preferredTimescale: 600)
                self.player.seek(to: startTime)
            }
        }
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    func setupAsync() async throws { // Added throws
        do {
            let duration = try await asset.load(.duration)
            try await MainActor.run {
                let durationSeconds = duration.seconds
                // Ensure duration is valid
                guard durationSeconds > 0 && !durationSeconds.isNaN else {
                    // Throw error instead of fallback
                    throw TrimmerError.invalidVideoDuration
                }
                self.videoDuration = durationSeconds
                self.endTime = durationSeconds
                // generateThumbnails() // Removed as per previous instruction
            }
        } catch {
            // Re-throw error
            throw TrimmerError.videoLoadFailed(underlyingError: error)
        }
    }

    func generateThumbnails() {
        isGeneratingThumbnails = true
        Task.detached(priority: .background) {
            let thumbs = await self.generateThumbnailsFromAsset()
            try? await MainActor.run {
                self.thumbnails = thumbs
                self.isGeneratingThumbnails = false
            }
        }
    }

    // MARK: - BreakDex: Photos-based thumbnail generation
    private func generateThumbnailsFromAsset() async -> [UIImage] {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 100, height: 60)
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        // Note: MAD service errors are handled by proper error checking and validation

        let count = 20

        // Guard against invalid video duration
        guard videoDuration > 0 && !videoDuration.isNaN else {
            return [UIImage(systemName: "video") ?? UIImage()]
        }

        let interval = videoDuration / Double(count)
        var times = [NSValue]()
        for i in 0..<count {
            let timeValue = interval * Double(i)
            // Ensure timeValue is valid
            guard !timeValue.isNaN && timeValue >= 0 && timeValue <= videoDuration else {
                continue
            }
            let time = CMTime(seconds: timeValue, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }

        guard !times.isEmpty else {
            return [UIImage(systemName: "video") ?? UIImage()]
        }

        var thumbnails: [UIImage] = []
        for time in times {
            do {
                let cgImage = try await imageGenerator.image(at: time.timeValue).image
                // Ensure the image is valid before creating UIImage
                guard cgImage.width > 0 && cgImage.height > 0 else {
                    thumbnails.append(UIImage(systemName: "video") ?? UIImage())
                    continue
                }
                thumbnails.append(UIImage(cgImage: cgImage))
            } catch {
                // Provide more specific error handling
                thumbnails.append(UIImage(systemName: "video") ?? UIImage())
            }
        }
        return thumbnails
    }

    func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero)
    }

    // MARK: - BreakDex: Metadata-Only Trimming
    // No longer exports video files - only stores trim ranges as metadata

    /// Get the current trim ranges for BreakDex storage
    /// - Returns: Tuple containing start and end times in seconds
    func getTrimRanges() -> (startTime: Double, endTime: Double) {
        return (startTime, endTime)
    }

    /// Apply trim ranges from a saved move (for editing existing trims)
    /// - Parameters:
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    func applyTrimRanges(startTime: Double, endTime: Double) {
        self.startTime = startTime
        self.endTime = endTime
    }

    /// Reset trim ranges to full video duration
    func resetTrimRanges() {
        startTime = 0
        endTime = videoDuration
    }

    /// Validate that trim ranges are within video bounds
    /// - Returns: True if ranges are valid
    func validateTrimRanges() -> Bool {
        return startTime >= 0 &&
               endTime <= videoDuration &&
               startTime < endTime
    }

    // Legacy export function - kept for compatibility but not used in BreakDex
    func export() async throws -> URL {
        throw NSError(domain: "BreakDex", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video export is no longer supported. Use getTrimRanges() for metadata-only trimming."])
    }

    func generateLoupePreview(at time: Double) async -> UIImage? {
        // Guard against invalid time values
        guard time >= 0 && time <= videoDuration && !time.isNaN && videoDuration > 0 else {
            return nil
        }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 150, height: 150)
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        // Note: MAD service errors are handled by proper error checking and validation

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        do {
            let cgImage = try await imageGenerator.image(at: cmTime).image
            // Ensure the image is valid before creating UIImage
            guard cgImage.width > 0 && cgImage.height > 0 else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        } catch {
            // Don't log errors for loupe previews as they're frequent and expected
            return nil
        }
    }

    func generatePreviewImage(at time: Double) {
        Task.detached(priority: .userInitiated) {
            let image = await self.generateLoupePreview(at: time)
            try? await MainActor.run {
                self.currentPreviewImage = image
            }
        }
    }

    func triggerHapticFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Thumbnail generation now handled inline using AVAssetImageGenerator
// Photos framework provides native thumbnail APIs for PHAsset-based content