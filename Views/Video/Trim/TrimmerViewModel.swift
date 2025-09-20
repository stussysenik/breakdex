import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - HandleType Enum
public enum TrimmerHandleType {
    case start, end
}

// MARK: - TrimmerViewModel
@MainActor
public final class TrimmerViewModel: ObservableObject {
    // MARK: - Core Properties
    let playerViewModel: any VideoPlayerViewModelProtocol
    public let asset: AVAsset
    public let photosIdentifier: String?

    public var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30)
    public let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)

    // MARK: - Initialization State
    private var isSetupComplete = false

    // MARK: - Observable State
    @Published
    public var startTime: CMTime = .zero
    @Published
    public var endTime: CMTime = .zero
    @Published
    public var videoDuration: CMTime = .zero
    @Published
    public var isExporting: Bool = false
    @Published
    public var rotationQuarterTurns: Int = 0 {
        didSet {
            // 🛑 PREVENT running during initialization - avoid race condition
            guard isSetupComplete else { return }
            
            // This is no longer a simple UI rotation change.
            // It now triggers real-time asset transformation for true WYSIWYG.
            Task {
                await applyRotationToPlayerAsset()
            }
        }
    }
    @Published
    public var showMinimumDurationWarning = false
    @Published
    public var isDraggingStartHandle: Bool = false
    @Published
    public var isDraggingEndHandle: Bool = false

    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?

    // MARK: - Initialization & Deinitialization
    public init(asset: AVAsset, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, playerViewModel: any VideoPlayerViewModelProtocol) {
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
        
        // ✅ ARM the rotation logic now that the model is in a valid state.
        isSetupComplete = true
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

    // MARK: - Real-time Asset Transformation
  private func applyRotationToPlayerAsset() async {
      let logger = Logger(subsystem: "com.breakingflashcards", category: "TrimmerViewModel")
      logger.info("🎬 TRIMMER_VM: Applying asset-level rotation: \(self.rotationQuarterTurns * 90)°")
      
      // 🛡️ DEFENSIVE GUARD: Ensure the time range is valid before processing.
      guard (self.endTime - self.startTime).seconds > 0 else {
          logger.warning("🎬 TRIMMER_VM: Skipping asset rotation due to invalid (zero-duration) time range.")
          return
      }
      
      do {
          // Use the VideoTransformBuilder to create a new player item with the current trim
          // and the NEW rotation. This implements true WYSIWYG.
          let transformedItem = try await VideoTransformBuilder.createPlayerItem(
              asset: self.asset,
              trimRange: CMTimeRange(start: self.startTime, end: self.endTime),
              quarterTurns: self.rotationQuarterTurns
          )
          
          // Hot-swap the player's content. This is a powerful feature of AVFoundation.
          guard let unifiedPlayer = self.playerViewModel as? UnifiedVideoPlayerViewModel else {
              logger.error("🎬 TRIMMER_VM: ❌ PlayerViewModel is not UnifiedVideoPlayerViewModel")
              return
          }
          
          try await unifiedPlayer.replacePlayerItemAndWaitForReady(transformedItem)
          
          logger.info("🎬 TRIMMER_VM: ✅ Asset rotation applied successfully.")
      } catch {
          logger.error("🎬 TRIMMER_VM: ❌ Failed to apply asset rotation: \(error.localizedDescription)")
          // Optionally, revert rotationQuarterTurns or show a user-facing error.
          // For now, we'll log the error and continue with the previous state.
      }
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
    
    // MARK: - Computed Properties
    public var isValidTrim: Bool {
        return validateTrimRanges()
    }
    
    public var duration: CMTime {
        return videoDuration
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