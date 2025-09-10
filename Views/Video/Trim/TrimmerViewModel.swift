import SwiftUI
import AVKit
import Combine

// MARK: - HandleType Enum
enum HandleType {
    case start, end
}

// MARK: - TrimmerViewModel
@MainActor
final class TrimmerViewModel: ObservableObject {
    // MARK: - Core Properties
    let player: AVPlayer
    let asset: AVAsset
    let photosIdentifier: String?

    var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30)
    let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)

    // MARK: - Published State
    @Published var startTime: CMTime = .zero
    @Published var endTime: CMTime = .zero
    @Published var videoDuration: CMTime = .zero
    @Published var isExporting: Bool = false
    @Published var rotationQuarterTurns: Int = 0
    @Published var showMinimumDurationWarning = false
    @Published var isDraggingStartHandle: Bool = false
    @Published var isDraggingEndHandle: Bool = false

    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?
    private var isSeekInProgress = false
    private var chaseTime: CMTime = .zero

    // MARK: - Initialization & Deinitialization
    init(asset: AVAsset, photosIdentifier: String? = nil) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
    }

    deinit {
        // Schedule cleanup on main thread to avoid actor isolation issues
        Task { @MainActor in
            stopCoalescing()
        }
    }

    // MARK: - Public Setup
    func setupAsync() async throws {
        videoDuration = try await asset.load(.duration)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30
        oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        endTime = videoDuration
    }

    // MARK: - Coalescing Timer Control
    func startCoalescing() {
        player.pause()
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopCoalescing() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let time = pendingPreviewTime else { return }
        pendingPreviewTime = nil
        seekTo(time)
    }

    // MARK: - Time Proposal and Committing
    func proposeTime(_ proposedTime: CMTime, for handle: HandleType) {
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
    
    func commitTime(_ time: CMTime, for handle: HandleType) {
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

    private func validate(_ proposedTime: CMTime, for handle: HandleType) -> CMTime {
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

    // MARK: - Chasing Seek Implementation
    private func seekTo(_ newTime: CMTime) {
        if newTime != chaseTime {
            chaseTime = newTime
            if !isSeekInProgress {
                trySeekToChaseTime()
            }
        }
    }

    private func trySeekToChaseTime() {
        guard player.currentItem?.status == .readyToPlay else { return }
        actuallySeekToTime()
    }

    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        player.seek(to: seekTimeInProgress, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if seekTimeInProgress == self.chaseTime {
                    self.isSeekInProgress = false
                } else {
                    self.trySeekToChaseTime()
                }
            }
        }
    }

    // MARK: - Validation Methods
    func validateTrimRanges() -> Bool {
        return startTime >= .zero && endTime <= videoDuration && startTime < endTime
    }

    // MARK: - Export Methods (needed by TrimmerView)
    func exportVideo() async -> URL {
        guard validateTrimRanges() else {
            print("Invalid trim ranges - cannot export")
            return URL(fileURLWithPath: "") // Return empty URL to indicate failure
        }

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

        // Create trim range
        let timeRange = CMTimeRange(start: startTime, duration: endTime - startTime)

        do {
            // Check if asset is file-based (required for videoComposition)
            if asset is AVURLAsset {
                // Use VideoTransformBuilder for consistent rotation and trimming
                print("🎬 TrimmerViewModel.exportVideo() using VideoTransformBuilder with rotationQuarterTurns: \(rotationQuarterTurns)")
                let exportedURL = try await VideoTransformBuilder.exportVideo(
                    asset: asset,
                    trimRange: timeRange,
                    quarterTurns: rotationQuarterTurns,
                    outputURL: outputURL
                )
                print("✅ Export completed successfully: \(exportedURL)")
                return exportedURL
            } else {
                // For non-file-based assets (like Photos), fall back to basic export
                print("🎬 TrimmerViewModel.exportVideo() using basic export for non-file-based asset")
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
                    print("Failed to create export session")
                    return URL(fileURLWithPath: "")
                }

                exportSession.timeRange = timeRange
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mov

                return await withCheckedContinuation { continuation in
                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            print("✅ Basic export completed successfully")
                            continuation.resume(returning: outputURL)
                        case .failed:
                            print("❌ Basic export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                            continuation.resume(returning: URL(fileURLWithPath: ""))
                        case .cancelled:
                            print("❌ Basic export cancelled")
                            continuation.resume(returning: URL(fileURLWithPath: ""))
                        default:
                            print("❌ Basic export failed with unknown status")
                            continuation.resume(returning: URL(fileURLWithPath: ""))
                        }
                    }
                }
            }
        } catch {
            print("❌ Export failed: \(error.localizedDescription)")
            return URL(fileURLWithPath: "") // Return empty URL to indicate failure
        }
    }

    // MARK: - Preview Updates
    func updatePreview() {
        // Update the live preview by seeking to current start time
        requestSeek(to: startTime)
    }

    func requestSeek(to time: CMTime) {
        seekTo(time)
    }

    // MARK: - Haptic Feedback
    func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        HapticManager.shared.trigger(event)
    }
}


// MARK: - Haptic Feedback Manager (Helper)
final class HapticManager {
    static let shared = HapticManager()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    enum HapticEvent {
        case dragStart
        case dragEnd
        case frameDetent
    }

    private init() {
        selectionFeedback.prepare()
    }

    func trigger(_ event: HapticEvent) {
        switch event {
        case .dragStart, .dragEnd:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .frameDetent:
            selectionFeedback.selectionChanged()
        }
    }
}
