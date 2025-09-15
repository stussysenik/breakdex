import SwiftUI
import AVKit
import Combine

// MARK: - HandleType Enum
public enum TrimmerHandleType {
    case start, end
}

// MARK: - TrimmerViewModel
@Observable
@MainActor
public final class TrimmerViewModel {
    // MARK: - Core Properties
    let playerViewModel: VideoPlayerViewModelProtocol
    public let asset: AVAsset
    public let photosIdentifier: String?

    public var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30)
    public let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)

    // MARK: - Observable State
    public var startTime: CMTime = .zero
    public var endTime: CMTime = .zero
    public var videoDuration: CMTime = .zero
    public var isExporting: Bool = false
    public var rotationQuarterTurns: Int = 0
    public var showMinimumDurationWarning = false
    public var isDraggingStartHandle: Bool = false
    public var isDraggingEndHandle: Bool = false

    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?

    // MARK: - Initialization & Deinitialization
    public init(asset: AVAsset, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, playerViewModel: VideoPlayerViewModelProtocol) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.playerViewModel = playerViewModel
        self.rotationQuarterTurns = rotationQuarterTurns
        Task {
            do {
                try await setupAsync()
            } catch {
                // Log the error but don't crash the app
                print("Error setting up TrimmerViewModel: \(error)")
            }
        }
    }

    deinit {
        // Schedule cleanup on main thread to avoid actor isolation issues
        Task { [weak self] in
            await MainActor.run {
                guard let self = self else { return }
                self.stopCoalescing()
            }
        }
    }

    // MARK: - Public Setup
    public func setupAsync() async throws {
        videoDuration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30
        oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        endTime = videoDuration
    }

    // MARK: - Coalescing Timer Control
    public func startCoalescing() {
        playerViewModel.pauseForTrimming()
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stopCoalescing() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let time = pendingPreviewTime else { return }
        pendingPreviewTime = nil
        playerViewModel.seek(to: time)
    }

    // MARK: - Time Proposal and Committing
    public func proposeTime(_ proposedTime: CMTime, for handle: TrimmerHandleType) {
        let validatedTime = validate(proposedTime, for: handle)

        switch handle {
        case .start:
            if startTime != validatedTime {
                startTime = validatedTime
            }
        case .end:
            if endTime != validatedTime {
                endTime = validatedTime
            }
        }

        self.pendingPreviewTime = validatedTime

        // Show while duration <= minimum during drag
        let atOrBelowMin = (endTime - startTime) <= minimumDuration
        showMinimumDurationWarning = atOrBelowMin
    }
    
    public func commitTime(_ time: CMTime, for handle: TrimmerHandleType) {
        let validatedTime = validate(time, for: handle)
        switch handle {
        case .start:
            startTime = validatedTime
        case .end:
            endTime = validatedTime
        }
        // Keep warning consistent with the final committed range
        showMinimumDurationWarning = (endTime - startTime) <= minimumDuration
    }

    private func validate(_ proposedTime: CMTime, for handle: TrimmerHandleType) -> CMTime {
        var validatedTime = max(.zero, min(proposedTime, videoDuration))

        switch handle {
        case .start:
            let limit = endTime - minimumDuration
            if validatedTime > limit {
                validatedTime = limit
                showMinimumDurationWarning = true
            }
        case .end:
            let limit = startTime + minimumDuration
            if validatedTime < limit {
                validatedTime = limit
                showMinimumDurationWarning = true
            }
        }

        if oneFrameDuration.seconds > 0 {
            let frameNumber = round(validatedTime.seconds / oneFrameDuration.seconds)
            validatedTime = CMTime(seconds: frameNumber * oneFrameDuration.seconds, preferredTimescale: validatedTime.timescale)
        }
        
        return validatedTime
    }

    // MARK: - Validation Methods
    public func validateTrimRanges() -> Bool {
        return startTime >= .zero && endTime <= videoDuration && startTime < endTime
    }

    // MARK: - Export Methods (needed by TrimmerView)
    public func exportVideo() async throws -> URL {
        guard validateTrimRanges() else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid trim ranges"])
        }

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

        // Create trim range
        let timeRange = CMTimeRange(start: startTime, duration: endTime - startTime)

        let exportedURL = try await VideoTransformBuilder.exportVideo(
            asset: asset,
            trimRange: timeRange,
            quarterTurns: rotationQuarterTurns,
            outputURL: outputURL
        )
        return exportedURL
    }

    // MARK: - Preview Updates
    public func updatePreview() async {
        // Update the live preview by seeking to current start time
        requestSeek(to: startTime)
    }

    public func requestSeek(to time: CMTime) {
        playerViewModel.seek(to: time)
    }

    // MARK: - Haptic Feedback
    public func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        HapticManager.shared.trigger(event)
    }
}


// MARK: - Haptic Feedback Manager (Helper)
public final class HapticManager {
    public static let shared = HapticManager()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    public enum HapticEvent {
        case dragStart
        case dragEnd
        case frameDetent
    }

    private init() {
        selectionFeedback.prepare()
    }

    public func trigger(_ event: HapticEvent) {
        switch event {
        case .dragStart, .dragEnd:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .frameDetent:
            selectionFeedback.selectionChanged()
        }
    }
}