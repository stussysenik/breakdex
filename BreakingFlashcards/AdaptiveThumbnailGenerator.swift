// AdaptiveThumbnailGenerator.swift — On-Demand Video Thumbnail Generation for Breakdex
//
// This file generates thumbnail images from a video asset for the trimmer timeline.
// The timeline displays a strip of video frame thumbnails so the user can visually
// navigate the video when trimming. For a 30-second clip, this might mean 10-20
// evenly-spaced thumbnails rendered from the video frames.
//
// ADAPTIVE LOADING STRATEGY:
//   Not all videos are created equal. A 15-second breakdancing clip should have all
//   thumbnails loaded immediately, but a 10-minute recording shouldn't try to generate
//   80 thumbnails at once (that would spike memory and CPU).
//
//   The generator classifies videos into three TIERS:
//     Short  (< 2 min):  Load ALL thumbnails upfront (small count, fast generation)
//     Medium (2-10 min):  Load in batches around the visible area (prefetch window of 10)
//     Long   (10+ min):   On-demand only (prefetch window of 5, aggressive eviction)
//
//   This tiered approach keeps memory usage bounded regardless of video length.
//
// ARCHITECTURE ROLE:
//   VideoEditorView
//     --> Creates AdaptiveThumbnailGenerator(asset:)
//     --> Calls configure(duration:count:) with values from LayoutMetrics
//     --> Passes generator to TrimmerTimelineView
//   TrimmerTimelineView
//     --> Calls updateVisibleRange() as the user scrolls/drags
//     --> Reads thumbnail(at:) for each visible slot
//     --> Displays UIImage in SwiftUI via Image(uiImage:)
//
// AVFoundation CONCEPTS:
//   - AVAssetImageGenerator: Extracts single frames from a video at specified times.
//     It decodes the video at a given CMTime and returns a CGImage.
//   - requestedTimeToleranceBefore/After: How far from the requested time AVFoundation
//     will look for a keyframe. Smaller tolerance = more accurate but slower (may need
//     to decode from a distant keyframe). 0.1 seconds is a good balance.
//   - maximumSize: Downscales the extracted frame to fit within this CGSize.
//     100x60 is tiny (thumbnails are small), which makes generation very fast.
//
// MEMORY MANAGEMENT:
//   Two-level cache system:
//   1. `thumbnails` dict: Active thumbnails shown in the UI (@Observable triggers updates)
//   2. NSCache: Background cache that survives eviction from `thumbnails` dict
//   When the user scrolls away, thumbnails are evicted from the dict (tier permitting)
//   but stay in NSCache. Scrolling back recovers them from NSCache without re-generating.
//
// CONNECTED FILES:
//   - VideoEditorView.swift: Creates the generator, configures it, owns its lifecycle
//   - TrimmerTimelineView.swift: Reads thumbnails for display, reports visible range
//   - LayoutMetrics.swift: thumbnailCount(for:) determines how many thumbnails to generate

import AVFoundation
import Observation
import UIKit

/// Uses the @Observable macro (Observation framework, iOS 17+) instead of ObservableObject.
/// @Observable provides more granular change tracking — SwiftUI only re-renders views
/// that read the specific property that changed, not the entire object.
/// This matters here because `thumbnails` is a dictionary that changes incrementally
/// (one entry at a time as each thumbnail loads).
@Observable
final class AdaptiveThumbnailGenerator {

    // MARK: - Published State

    /// Sparse dictionary mapping thumbnail index to its UIImage.
    /// "Sparse" means not every index from 0..<totalCount has an entry —
    /// only loaded (and not-evicted) thumbnails appear here.
    ///
    /// @Observable tracks changes to this dictionary. When a new thumbnail
    /// is inserted, only TrimmerTimelineView cells that read that specific
    /// index will re-render — not the entire timeline.
    ///
    /// `private(set)`: Views can read but only this class can mutate.
    private(set) var thumbnails: [Int: UIImage] = [:]

    /// Whether thumbnail generation is currently in progress.
    /// TrimmerTimelineView can show a shimmer/placeholder when this is true.
    private(set) var isGenerating = false

    /// Total number of thumbnails to generate (set by configure()).
    /// Determines the valid index range: 0..<totalCount.
    private(set) var totalCount = 0

    // MARK: - Private Properties

    /// The source video asset. Used to create the image generator.
    /// Retained for the lifetime of this object.
    private let asset: AVAsset

    /// AVAssetImageGenerator extracts individual frames from the video.
    /// Configured once in init() with size limits and time tolerances.
    private let imageGenerator: AVAssetImageGenerator

    /// Second-level cache (NSCache) for thumbnails evicted from the `thumbnails` dict.
    /// NSCache is preferred over Dictionary for caching because:
    /// 1. Automatic eviction under memory pressure (system manages this)
    /// 2. Thread-safe (no locks needed for concurrent access)
    /// 3. Cost-based limits (we cap at 30MB total)
    ///
    /// Keys: NSNumber(index), Values: UIImage
    private let cache = NSCache<NSNumber, UIImage>()

    /// Operation queue for background thumbnail generation.
    /// Limits concurrency to 3 parallel operations to avoid overwhelming
    /// the CPU (each operation decodes a video frame, which is CPU-intensive).
    private let operationQueue = OperationQueue()

    /// The video's total duration in seconds. Set by configure().
    /// Used to calculate the time position for each thumbnail index.
    private var duration: TimeInterval = 0

    /// Indices currently being generated (in-flight).
    /// Prevents duplicate generation requests for the same thumbnail.
    /// An index is added when generation starts, removed when it completes.
    private var pendingIndices = Set<Int>()

    /// The desired pixel size for each thumbnail.
    /// Passed to imageGenerator.maximumSize to control output resolution.
    /// Small size (100x60) = fast generation + low memory usage.
    private var thumbnailSize: CGSize

    // MARK: - Tiering System

    /// Classifies the video by duration to determine the loading strategy.
    ///
    /// SHORT (< 2 min): Breakdancing clips are typically 10-60 seconds.
    ///   Generate ALL thumbnails upfront for instant scrubbing. Total count
    ///   is small enough (8-40) that this is fast and memory-safe.
    ///
    /// MEDIUM (2-10 min): Longer practice recordings or session videos.
    ///   Generate in batches around the visible area with a prefetch window
    ///   of 10 thumbnails ahead/behind. Evict far-away thumbnails.
    ///
    /// LONG (10+ min): Full practice sessions or class recordings.
    ///   Aggressive on-demand loading with a prefetch window of 5.
    ///   Aggressive eviction. Memory stays bounded.
    private enum Tier {
        case short      // < 2 min: generate all upfront
        case medium     // 2-10 min: batches of 20 around visible area
        case long       // 10+ min: on-demand only, aggressive eviction
    }

    /// The current tier, computed from the video duration.
    private var tier: Tier {
        if duration <= 120 { return .short }
        if duration <= 600 { return .medium }
        return .long
    }

    /// How many thumbnails ahead/behind the visible area to prefetch.
    /// Larger window = smoother scrubbing (thumbnails ready before they scroll into view).
    /// Smaller window = less memory usage.
    ///
    /// For short videos, the window is the entire video (totalCount) since we
    /// load everything upfront anyway.
    private var prefetchWindow: Int {
        switch tier {
        case .short:  return totalCount  // Load everything (it's all "prefetch")
        case .medium: return 10          // 10 thumbnails ahead and behind
        case .long:   return 5           // 5 thumbnails ahead and behind (conservative)
        }
    }

    // MARK: - Initialization

    /// Creates a new thumbnail generator for the given video asset.
    ///
    /// - Parameters:
    ///   - asset: The AVAsset to generate thumbnails from (from MediaManager.loaded)
    ///   - thumbnailSize: Maximum pixel dimensions for each thumbnail (default: 100x60)
    ///
    /// CONFIGURATION OF AVAssetImageGenerator:
    ///   - appliesPreferredTrackTransform: Automatically applies the video track's
    ///     orientation transform, so thumbnails are right-side-up regardless of how
    ///     the phone was held when recording.
    ///   - maximumSize: Caps the output resolution. The generator scales down to fit
    ///     within this box while maintaining aspect ratio. 100x60 is enough for
    ///     the small timeline thumbnails.
    ///   - requestedTimeToleranceBefore/After: 0.1 seconds tolerance means the generator
    ///     can return a frame up to 100ms before/after the requested time. This is
    ///     MUCH faster than exact seeking because it can use the nearest keyframe
    ///     instead of decoding from a distant keyframe to hit an exact time.
    ///
    /// CACHE CONFIGURATION:
    ///   - countLimit: 80 thumbnails max in NSCache (covers most videos entirely)
    ///   - totalCostLimit: 30MB (UIImages in NSCache have cost based on pixel data size)
    ///
    /// OPERATION QUEUE CONFIGURATION:
    ///   - maxConcurrentOperationCount: 3 (balance between speed and CPU load)
    ///   - qualityOfService: .userInitiated (high priority since the user is waiting)

    init(asset: AVAsset, thumbnailSize: CGSize = CGSize(width: 100, height: 60)) {
        self.asset = asset
        self.thumbnailSize = thumbnailSize
        self.imageGenerator = AVAssetImageGenerator(asset: asset)

        // Auto-rotate thumbnails to match the video's display orientation.
        imageGenerator.appliesPreferredTrackTransform = true

        // Cap output size to save memory (thumbnails are tiny in the UI).
        imageGenerator.maximumSize = thumbnailSize

        // Allow 100ms tolerance for faster frame extraction.
        // Without tolerance, exact seeking can be 10x slower.
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)

        // NSCache limits — auto-evicts oldest entries when exceeded.
        cache.countLimit = 80
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB

        // Background operation queue — 3 concurrent frame extractions max.
        operationQueue.maxConcurrentOperationCount = 3
        operationQueue.qualityOfService = .userInitiated
    }

    // MARK: - Public API

    /// Configures the generator with the video's duration and desired thumbnail count.
    ///
    /// Must be called once after initialization, before any thumbnails are requested.
    /// For short videos, this immediately kicks off generation of ALL thumbnails.
    /// For longer videos, it just stores the configuration — thumbnails are generated
    /// on-demand as the user scrolls (via updateVisibleRange).
    ///
    /// - Parameters:
    ///   - duration: Total video duration in seconds (from AVAsset.load(.duration))
    ///   - count: Number of thumbnails to generate (from LayoutMetrics.thumbnailCount)
    ///
    /// Called from: VideoEditorView after the asset is loaded and metrics are computed.
    func configure(duration: TimeInterval, count: Int) {
        self.duration = duration
        self.totalCount = count

        // Short videos: generate everything now for instant scrubbing.
        // The user will see thumbnails appear progressively as they load.
        if tier == .short {
            loadThumbnails(for: 0..<count)
        }
    }

    /// Updates which thumbnails should be loaded based on the visible scroll position.
    ///
    /// Called continuously as the user drags trim handles or the playhead in
    /// TrimmerTimelineView. The visible range indicates which thumbnail indices
    /// are currently on-screen.
    ///
    /// This method does three things:
    /// 1. PREFETCH: Loads thumbnails within `prefetchWindow` indices of the visible range
    /// 2. DEDUP: Skips indices that are already loaded or in-flight (pendingIndices)
    /// 3. EVICT: For medium/long videos, removes thumbnails far outside the visible area
    ///    from the `thumbnails` dict (they remain in NSCache for quick recovery)
    ///
    /// - Parameter range: The range of thumbnail indices currently visible on screen
    ///
    /// Called from: TrimmerTimelineView during drag gestures and on initial layout.
    func updateVisibleRange(_ range: Range<Int>) {
        // Expand the visible range by the prefetch window in both directions.
        // Clamp to valid bounds (0..<totalCount) to avoid out-of-range indices.
        let lo = max(0, range.lowerBound - prefetchWindow)
        let hi = min(totalCount, range.upperBound + prefetchWindow)

        // Filter to only indices that aren't already loaded or being generated.
        let needed = (lo..<hi).filter { thumbnails[$0] == nil && !pendingIndices.contains($0) }

        // Load any missing thumbnails in the prefetch window.
        if !needed.isEmpty {
            loadThumbnails(for: needed)
        }

        // EVICTION: For medium/long videos, remove thumbnails that are far from
        // the visible area to free memory. The eviction boundary is 2x the prefetch
        // window — so thumbnails within prefetchWindow*2 of visible are kept.
        //
        // Evicted thumbnails stay in NSCache (second-level cache). If the user
        // scrolls back, they're recovered from NSCache instead of re-generated.
        //
        // Short videos skip eviction entirely (we want all thumbnails loaded).
        if tier != .short {
            let evictBelow = max(0, range.lowerBound - prefetchWindow * 2)
            let evictAbove = min(totalCount, range.upperBound + prefetchWindow * 2)
            for key in thumbnails.keys where key < evictBelow || key >= evictAbove {
                thumbnails.removeValue(forKey: key)
            }
        }
    }

    /// Returns the thumbnail image at the given index, or nil if not yet loaded.
    ///
    /// TWO-LEVEL LOOKUP:
    /// 1. Check `thumbnails` dict (fast, in-memory, triggers @Observable)
    /// 2. Check NSCache (may have been evicted from dict but still in cache)
    ///    If found in cache, promotes it back to the dict (so the view renders it)
    /// 3. Returns nil if not in either (caller shows placeholder)
    ///
    /// - Parameter index: The thumbnail slot index (0..<totalCount)
    /// - Returns: The thumbnail UIImage, or nil if not yet generated
    ///
    /// Called from: TrimmerTimelineView for each visible thumbnail cell.
    func thumbnail(at index: Int) -> UIImage? {
        // Level 1: Check the active thumbnails dictionary.
        if let img = thumbnails[index] { return img }

        // Level 2: Check the NSCache (thumbnail may have been evicted from dict).
        if let cached = cache.object(forKey: NSNumber(value: index)) {
            // Promote back to the active dict so the view can display it.
            thumbnails[index] = cached
            return cached
        }

        // Not loaded yet — caller should show a placeholder.
        return nil
    }

    // MARK: - Private: Thumbnail Generation

    /// Generates thumbnail images for the given indices and stores them.
    ///
    /// This is where the actual AVFoundation frame extraction happens.
    /// The work runs on a background OperationQueue to avoid blocking the main thread.
    ///
    /// FLOW:
    /// 1. Calculate the CMTime for each requested index based on duration and totalCount
    /// 2. Add the operation to the background queue
    /// 3. For each index, call generateCGImagesAsynchronously() to extract the frame
    /// 4. Wrap the CGImage in a UIImage, store in NSCache, and update the dict on main
    /// 5. When all frames in this batch complete, set isGenerating = false
    ///
    /// WHY OperationQueue (not Task/async):
    /// AVAssetImageGenerator.generateCGImagesAsynchronously() is a callback-based API
    /// (not async/await). It's designed to batch-generate multiple frames efficiently.
    /// Using OperationQueue + DispatchGroup is the natural pattern for this API.
    ///
    /// - Parameter indices: A sequence of thumbnail indices to generate

    private func loadThumbnails<S: Sequence>(for indices: S) where S.Element == Int {
        guard duration > 0, totalCount > 0 else { return }
        isGenerating = true

        // Calculate the time interval between consecutive thumbnails.
        // For a 30-second video with 10 thumbnails: interval = 3.0 seconds.
        let interval = duration / Double(totalCount)

        // Build the list of (index, CMTime) pairs to generate.
        // Skip indices that are out of bounds or already being generated.
        var times: [(Int, NSValue)] = []
        for index in indices {
            guard index >= 0, index < totalCount, !pendingIndices.contains(index) else { continue }
            pendingIndices.insert(index)  // Mark as in-flight to prevent duplicates

            // Convert the thumbnail index to a time position in the video.
            // Index 0 = 0 seconds, Index 5 with 3s interval = 15 seconds, etc.
            let seconds = Double(index) * interval
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            times.append((index, NSValue(time: time)))  // NSValue wraps CMTime for ObjC API
        }

        guard !times.isEmpty else {
            isGenerating = false
            return
        }

        // Run frame extraction on a background operation queue.
        // [weak self] prevents a retain cycle — if the generator is deallocated
        // (user navigated away), the operation exits cleanly.
        operationQueue.addOperation { [weak self] in
            guard let self else { return }
            let group = DispatchGroup()
            let generator = self.imageGenerator
            let cache = self.cache

            for (index, timeValue) in times {
                group.enter()  // Track this async generation in the group

                // generateCGImagesAsynchronously is AVFoundation's batch frame extraction API.
                // It takes an array of times (we pass one at a time for per-frame error handling).
                // The callback provides:
                //   - requestedTime: The time we asked for
                //   - cgImage: The extracted frame (nil on failure)
                //   - actualTime: The actual time of the extracted frame (may differ by tolerance)
                //   - result: .succeeded, .failed, or .cancelled
                //   - error: Error details on failure
                generator.generateCGImagesAsynchronously(forTimes: [timeValue]) {
                    [weak self] _, cgImage, _, _, _ in
                    defer { group.leave() }  // Always leave the group, even on failure

                    // If frame extraction failed (corrupt data, cancelled), skip silently.
                    // The thumbnail slot will remain empty (placeholder in the UI).
                    guard let cgImage else { return }

                    // Wrap the raw CGImage in a UIImage for storage and display.
                    let image = UIImage(cgImage: cgImage)

                    // Store in NSCache (thread-safe, no main thread needed).
                    cache.setObject(image, forKey: NSNumber(value: index))

                    // Update the active thumbnails dict on the main thread.
                    // This triggers @Observable, which updates the SwiftUI view.
                    DispatchQueue.main.async { [weak self] in
                        self?.thumbnails[index] = image
                        self?.pendingIndices.remove(index)  // No longer in-flight
                    }
                }
            }

            // Wait for ALL frame extractions in this batch to complete.
            group.wait()

            // Mark generation as complete (on the main thread for UI observation).
            DispatchQueue.main.async { [weak self] in
                self?.isGenerating = false
            }
        }
    }

    // MARK: - Cancellation

    /// Cancels all in-flight thumbnail generation.
    ///
    /// Called when:
    /// - The video editor is dismissed (view disappears)
    /// - A different video is loaded
    /// - The generator is about to be deallocated
    ///
    /// Cancels at three levels:
    /// 1. AVAssetImageGenerator: Cancels pending frame extractions
    /// 2. OperationQueue: Cancels queued operations
    /// 3. Internal bookkeeping: Clears pending set, resets generating flag
    func cancelAll() {
        imageGenerator.cancelAllCGImageGeneration()
        operationQueue.cancelAllOperations()
        pendingIndices.removeAll()
        isGenerating = false
    }
}
