import SwiftUI
import AVKit
import Combine
import Photos
import Foundation

// MARK: - Video Validation Utilities
struct VideoValidation {
    static func validateVideoDimensions(_ size: CGSize) -> Bool {
        guard size.width.isFinite && size.height.isFinite else {
            print("❌ Video validation failed: Non-finite dimensions \(size)")
            return false
        }

        guard size.width > 0 && size.height > 0 else {
            print("❌ Video validation failed: Zero or negative dimensions \(size)")
            return false
        }

        guard size.width <= 8192 && size.height <= 8192 else {
            print("❌ Video validation failed: Dimensions too large \(size)")
            return false
        }

        return true
    }

    static func validateTransformMatrix(_ transform: CGAffineTransform, context: String = "") -> Bool {
        guard transform.isValid() else {
            print("❌ Transform validation failed\(context.isEmpty ? "" : " in \(context)"): Invalid matrix \(transform.debugDescription)")
            return false
        }

        // Check for extreme scaling that might indicate issues
        let scaleX = sqrt(transform.a * transform.a + transform.c * transform.c)
        let scaleY = sqrt(transform.b * transform.b + transform.d * transform.d)

        guard scaleX.isFinite && scaleY.isFinite && scaleX > 0.01 && scaleY > 0.01 else {
            print("❌ Transform validation failed\(context.isEmpty ? "" : " in \(context)"): Invalid scaling factors scaleX=\(scaleX), scaleY=\(scaleY)")
            return false
        }

        return true
    }

    static func sanitizeCMTime(_ time: CMTime, defaultValue: CMTime = .zero) -> CMTime {
        guard time.isValid && time.seconds.isFinite else {
            print("⚠️ Sanitizing invalid CMTime: \(time) -> \(defaultValue)")
            return defaultValue
        }
        return time
    }
}

// MARK: - Error Handling
enum TrimmerError: LocalizedError {
    case videoLoadFailed(underlyingError: Error?)
    case invalidVideoDuration

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed(let error):
            return "Failed to load video. " + (error?.localizedDescription ?? "Unknown error")
        case .invalidVideoDuration:
            return "Invalid video duration."
        }
    }
}

// MARK: - Haptic Feedback Manager
final class HapticManager {
    static let shared = HapticManager()
    private init() {
        // Pre-warm haptic engines to minimize latency
        selectionFeedback.prepare()
    }

    private let selectionFeedback = UISelectionFeedbackGenerator()

    enum HapticEvent {
        case dragStart
        case dragEnd
        case frameDetent
    }

    func trigger(_ event: HapticEvent) {
        switch event {
        case .dragStart:
            MotionCatalog.Accessibility.buttonTap()
        case .dragEnd:
            MotionCatalog.Accessibility.successHaptic()
        case .frameDetent:
            selectionFeedback.selectionChanged()
        }
    }
}

// MARK: - TrimmerViewModel
@MainActor
final class TrimmerViewModel: ObservableObject {
    // MARK: - Core Properties
    let player: AVPlayer
    let asset: AVAsset
    let photosIdentifier: String?

    var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30) // Default 30fps, will be updated in setupAsync

    // MARK: - Published State
    @Published var startTime: CMTime = .zero {
        didSet {
            if startTime > endTime - oneFrameDuration && endTime != .zero {
                startTime = endTime - oneFrameDuration
            }
            print("✅ STEP 3: ViewModel startTime updated to: \(startTime.seconds)")
        }
    }
    @Published var endTime: CMTime = .zero {
        didSet {
            if endTime < startTime + oneFrameDuration {
                endTime = startTime + oneFrameDuration
            }
            print("✅ STEP 3: ViewModel endTime updated to: \(endTime.seconds)")
        }
    }
    @Published var videoDuration: CMTime = .zero
    @Published var isExporting: Bool = false
    @Published var rotationQuarterTurns: Int = 0 {
        didSet {
            #if DEBUG
            // Runtime assertion: rotation should never reset to 0 unexpectedly
            if oldValue != 0 && rotationQuarterTurns == 0 {
                assertionFailure("""
                🚨 Rotation state reset detected!
                rotationQuarterTurns changed from \(oldValue) to 0.
                This may indicate StateObject recreation or state loss.
                """)
            }
            #endif
        }
    }

    // MARK: - New Feature-Related Properties
    @Published var zoomScale: CGFloat = 1.0
    @Published var isDraggingHandle: Bool = false
    @Published var isDraggingStartHandle: Bool = false
    @Published var isDraggingEndHandle: Bool = false

    // MARK: - Seek Scheduler State
    private var isSeeking = false
    private var pendingSeekTime: CMTime?

    // MARK: - Concurrency Control
    private var currentPreviewTask: Task<Void, Never>?
    private var currentExportTask: Task<URL, Error>?

    // MARK: - Private Properties
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()
    private let seekScheduler: SeekScheduler

    // MARK: - Video Composition Caching
    private var compositionCache = [String: (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition)]()
    private let compositionQueue = DispatchQueue(label: "com.breakingflashcards.composition", qos: .userInitiated)

    // MARK: - Initialization
    init(asset: AVAsset, photosIdentifier: String? = nil) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.seekScheduler = SeekScheduler(player: self.player, asset: self.asset)
        setupTimeObserver()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }


    // MARK: - Public Setup
    func setupAsync() async throws {
        do {
            guard let duration = try? await asset.load(.duration) else {
                throw TrimmerError.videoLoadFailed(underlyingError: nil)
            }

            // Load video tracks to calculate proper frame rate
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30

            await MainActor.run {
                guard duration.seconds > 0, !duration.seconds.isNaN else {
                    self.videoDuration = .zero
                    self.endTime = .zero
                    return
                }
                self.videoDuration = duration
                self.endTime = duration
                self.oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            }
        } catch {
            throw TrimmerError.videoLoadFailed(underlyingError: error)
        }
    }

    // MARK: - Playback & Seeking
    /// The public entry point for requesting a seek. The View will call this.
    /// It coalesces rapid requests into a single pending seek.
    func requestSeek(to time: CMTime) {
        // If we are already busy seeking, just update the pending time to the latest request.
        if isSeeking {
            pendingSeekTime = time
            return
        }

        // If we are not busy, perform the seek immediately.
        performSeek(to: time)
    }

    /// Performs the actual seek on the player and manages the scheduling chain.
    private func performSeek(to time: CMTime) {
        // 1. Mark the scheduler as busy.
        isSeeking = true

        // 2. Tell the player to seek, using its completion handler.
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
            guard let self = self else { return }

            // 3. IMPORTANT: In the completion handler, mark the scheduler as free.
            self.isSeeking = false

            // 4. Check if a new seek was requested while this one was in flight.
            if let pendingTime = self.pendingSeekTime {
                // If so, clear the pending request and kick off a new seek for the latest time.
                self.pendingSeekTime = nil
                self.performSeek(to: pendingTime)
                }
            }
        }
    }

    // MARK: - Trimming Logic
    func validateTrimRanges() -> Bool {
        return startTime >= .zero && endTime <= videoDuration && startTime < endTime
    }

    // MARK: - Haptic Feedback
    func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        HapticManager.shared.trigger(event)
    }

    /// Updates the player preview with rotation and trim applied using VideoTransformBuilder
    /// This method coordinates concurrent calls to prevent race conditions
    func updatePreview() async {
        // Cancel any existing preview task
        currentPreviewTask?.cancel()
        currentPreviewTask = nil

        // Create new preview task
        let task = Task { @MainActor in
            print("🎬 TrimmerViewModel.updatePreview() called with rotationQuarterTurns: \(rotationQuarterTurns)")
            print("🎬   startTime: \(startTime.seconds), endTime: \(endTime.seconds)")

            do {
                // Check if task was cancelled
                try Task.checkCancellation()

                // Always use VideoTransformBuilder for consistent preview/export parity
                let trimRange = CMTimeRange(start: startTime, duration: endTime - startTime)
                print("🎬   trimRange: start=\(trimRange.start.seconds), duration=\(trimRange.duration.seconds)")

                // Check if task was cancelled before heavy computation
                try Task.checkCancellation()

                let playerItem = try await VideoTransformBuilder.createPlayerItem(
                    asset: self.asset,
                    trimRange: trimRange,
                    quarterTurns: rotationQuarterTurns
                )

                // Check if task was cancelled before UI updates
                try Task.checkCancellation()

                // Enable precise scrubbing for video compositions
                playerItem.seekingWaitsForVideoCompositionRendering = true

                // Replace current item with the new composition-based item
                self.player.replaceCurrentItem(with: playerItem)

                print("✅ TrimmerViewModel preview updated successfully")
            } catch is CancellationError {
                print("🎬 Preview update cancelled")
            } catch {
                print("❌ Failed to update preview: \(error)")
                // Fallback to original asset
                let playerItem = AVPlayerItem(asset: self.asset)
                self.player.replaceCurrentItem(with: playerItem)
            }
        }

        currentPreviewTask = task
        await task.value

        // Clean up completed task
        currentPreviewTask = nil
    }

    private func compositionCacheKey(rotationQuarterTurns: Int, trimRange: CMTimeRange? = nil) -> String {
        let assetId = asset.description
        let trimKey = trimRange.map { "\($0.start.seconds)-\($0.duration.seconds)" } ?? "full"
        return "\(assetId)_\(rotationQuarterTurns)_\(trimKey)"
    }

    private func getCachedComposition(rotationQuarterTurns: Int, trimRange: CMTimeRange? = nil) -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition)? {
        let key = compositionCacheKey(rotationQuarterTurns: rotationQuarterTurns, trimRange: trimRange)
        return compositionCache[key]
    }

    private func cacheComposition(_ result: (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition),
                                rotationQuarterTurns: Int, trimRange: CMTimeRange? = nil) {
        let key = compositionCacheKey(rotationQuarterTurns: rotationQuarterTurns, trimRange: trimRange)
        compositionCache[key] = result

        // Limit cache size to prevent memory issues
        if compositionCache.count > 10 {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = compositionCache.keys.prefix(compositionCache.count - 5)
            keysToRemove.forEach { compositionCache.removeValue(forKey: $0) }
        }
    }

    // MARK: - Private Time Observer
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.01, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                if self.player.timeControlStatus == .playing &&
                    time >= self.endTime &&
                    self.endTime > self.startTime {
                    self.player.seek(to: self.startTime)
                }
            }
        }
    }

    // MARK: - Export with VideoTransformBuilder
    func exportVideo() async throws -> URL {
        // Prevent concurrent exports
        guard currentExportTask == nil else {
            throw TrimmerError.videoLoadFailed(underlyingError: NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export already in progress"]))
        }

        // Create export task
        let task = Task<URL, Error> { @MainActor in
            print("🎬 TrimmerViewModel.exportVideo() called with rotationQuarterTurns: \(rotationQuarterTurns)")

            try Task.checkCancellation()

            // Step 1: Ensure we have a file-backed asset for export
            let exportAsset: AVAsset
            if let urlAsset = asset as? AVURLAsset {
                // Asset is already file-backed, use directly
                exportAsset = urlAsset
            } else if let photosIdentifier = photosIdentifier {
                // Asset is not file-backed, materialize it using PHAssetResourceManager
                exportAsset = try await materializeAssetToFile(photosIdentifier: photosIdentifier)
            } else {
                // No photos identifier available, try to use the asset directly
                exportAsset = asset
            }

            try Task.checkCancellation()

            // Step 2: Build trim range
            let trimRange = CMTimeRange(start: startTime, duration: endTime - startTime)

            // Step 3: Create output URL
            let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

            try Task.checkCancellation()

            // Step 4: Use VideoTransformBuilder for export
            let exportedURL = try await VideoTransformBuilder.exportVideo(
                asset: exportAsset,
                trimRange: trimRange,
                quarterTurns: rotationQuarterTurns,
                outputURL: outputURL
            )

            try Task.checkCancellation()

            // Step 5: Validate exported video
            try await validateExportedVideo(outputURL: exportedURL, rotationQuarterTurns: rotationQuarterTurns)

            try Task.checkCancellation()

            // Step 6: Cleanup temporary files (materialized assets)
            if exportAsset !== asset, let urlAsset = exportAsset as? AVURLAsset {
                do {
                    try FileManager.default.removeItem(at: urlAsset.url)
                    print("✅ Cleaned up temporary materialized asset: \(urlAsset.url.lastPathComponent)")
                } catch {
                    print("⚠️  Failed to cleanup temporary asset \(urlAsset.url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            print("✅ TrimmerViewModel export completed successfully")
            return exportedURL
        }

        currentExportTask = task

        do {
            let result = try await task.value
            currentExportTask = nil
            return result
        } catch {
            currentExportTask = nil
            throw error
        }
    }

    // MARK: - Export with Retry
    private func exportWithRetry(exportSession: AVAssetExportSession, outputURL: URL) async throws -> URL {
        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
        try await exportSession.export(to: outputURL, as: .mov)
                return outputURL
            } catch {
                lastError = error

                // Check if this is a retryable error
                let isRetryable = isRetryableExportError(error)

                if !isRetryable || attempt == maxRetries {
                    // Not retryable or last attempt, throw the error
                    throw error
                }

                // Exponential backoff: 1s, 2s, 4s
                let delay = pow(2.0, Double(attempt - 1))
                print("⚠️  Export attempt \(attempt) failed with retryable error: \(error.localizedDescription). Retrying in \(delay)s...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // This should never be reached, but just in case
        throw lastError ?? NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed after all retries"])
    }

    private func isRetryableExportError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // Common transient export errors that might be retryable
        let retryableCodes = [
            AVError.Code.exportFailed.rawValue,
            AVError.Code.operationInterrupted.rawValue
        ]

        return retryableCodes.contains(nsError.code) ||
               nsError.localizedDescription.contains("interrupted") ||
               nsError.localizedDescription.contains("timeout") ||
               nsError.localizedDescription.contains("network") ||
               nsError.localizedDescription.contains("connection")
    }

    // MARK: - Export Validation
    private func validateExportedVideo(outputURL: URL, rotationQuarterTurns: Int) async throws {
        let exportedAsset = AVURLAsset(url: outputURL)

        // 1. Validate duration
        let exportedDuration = try await exportedAsset.load(.duration)
        let expectedDuration = endTime - startTime
        let durationTolerance = CMTime(seconds: 0.1, preferredTimescale: expectedDuration.timescale)

        guard abs(exportedDuration.seconds - expectedDuration.seconds) <= durationTolerance.seconds else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Export validation failed: Duration mismatch. Expected \(expectedDuration.seconds)s, got \(exportedDuration.seconds)s"
            ])
        }

        // 2. Validate playable status
        let isPlayable = try await exportedAsset.load(.isPlayable)
        guard isPlayable else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Export validation failed: Exported video is not playable"
            ])
        }

        // 3. Validate rotation was baked (for non-zero rotations)
        if rotationQuarterTurns != 0 {
            let outputVideoTrack: AVAssetTrack? = try await {
                let tracks = try await exportedAsset.loadTracks(withMediaType: .video)
                return tracks.first
            }()

            if let outputVideoTrack = outputVideoTrack {
                let outputPreferredTransform = try await outputVideoTrack.load(.preferredTransform)

                // For properly baked rotation, preferredTransform should be identity (or close to it)
                let identity = CGAffineTransform.identity
                let transformTolerance: CGFloat = 0.001

                let isIdentity =
                    abs(outputPreferredTransform.a - identity.a) < transformTolerance &&
                    abs(outputPreferredTransform.b - identity.b) < transformTolerance &&
                    abs(outputPreferredTransform.c - identity.c) < transformTolerance &&
                    abs(outputPreferredTransform.d - identity.d) < transformTolerance &&
                    abs(outputPreferredTransform.tx - identity.tx) < transformTolerance &&
                    abs(outputPreferredTransform.ty - identity.ty) < transformTolerance

                if !isIdentity {
                    print("⚠️  Warning: Output video still has non-identity preferredTransform after rotation bake: \(outputPreferredTransform)")
                    // Don't fail the export for this, as some formats might retain transforms
                    // Just log it for observability
                }
            }
        }

        // 4. Validate dimensions (basic check)
        let outputVideoTrack: AVAssetTrack? = try await {
            let tracks = try await exportedAsset.loadTracks(withMediaType: .video)
            return tracks.first
        }()

        if let outputVideoTrack = outputVideoTrack {
            let outputNaturalSize = try await outputVideoTrack.load(.naturalSize)
            guard outputNaturalSize.width > 0 && outputNaturalSize.height > 0 else {
                throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Export validation failed: Invalid video dimensions \(outputNaturalSize)"
                ])
            }
        }
    }

    // MARK: - Asset Materialization
    private func materializeAssetToFile(photosIdentifier: String) async throws -> AVURLAsset {
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find PHAsset for identifier: \(photosIdentifier)"])
        }

        // Get the video resource
        let resources = PHAssetResource.assetResources(for: phAsset)
        guard let videoResource = resources.first(where: { $0.type == .video }) else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video resource found for asset."])
        }

        // Create temp file URL
        let fileExtension = videoResource.originalFilename.split(separator: ".").last.map(String.init) ?? "mov"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        // Use PHAssetResourceManager to write the data to file
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: tempURL, options: nil) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let urlAsset = AVURLAsset(url: tempURL)
                    continuation.resume(returning: urlAsset)
                }
            }
        }
    }
}
