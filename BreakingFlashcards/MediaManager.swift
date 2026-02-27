// MediaManager.swift — Async Video Loading Service for Breakdex
//
// This file provides a centralized, cached, observable video loading service.
// When the user selects a move (from MoveListView or MoveDetailView), the app
// needs to load the associated video file from disk and prepare it for playback.
// MediaManager handles the full loading lifecycle with progress reporting.
//
// ARCHITECTURE ROLE:
//   MoveDetailView / VideoEditorView
//     --> MediaManager.shared.loadVideo(from: url)
//     --> Observes MediaManager.status (@Published)
//     --> On .loaded: passes AVAsset to AVPlayer / VideoCompositionPipeline
//
// WHY A SINGLETON:
//   Only one video loads at a time in the app. The singleton ensures:
//   1. Cache is shared across views (navigating back and forth reuses loaded assets)
//   2. Cancelling a previous load is automatic (opening a new move cancels the old one)
//   3. No duplicate loading if two views reference the same move
//
// VIDEO FILE PATHS:
//   Move.videoReference stores a relative path as UTF-8 Data (e.g., "Moves/UUID.mp4").
//   The full path is: Documents/Moves/UUID.mp4.
//   The caller resolves this to an absolute URL before calling loadVideo(from:).
//
// CONNECTED FILES:
//   - Models.swift: Move.videoReference -> resolved to URL -> passed here
//   - VideoEditorView.swift: Consumes the loaded AVAsset for editing
//   - CustomVideoPlayerView.swift: Consumes the loaded AVAsset for playback
//   - AdaptiveThumbnailGenerator.swift: Initialized with the loaded AVAsset

import AVFoundation
import Combine

// ObservableObject + @Published allows SwiftUI views to react to status changes.
// When `status` changes, any view observing this object re-renders automatically.
class MediaManager: ObservableObject {

    /// Shared singleton instance. All views use this same instance so the
    /// asset cache is shared and only one load operation runs at a time.
    static let shared = MediaManager()

    /// In-memory cache of recently loaded AVAssets, keyed by URL string.
    /// NSCache automatically evicts entries under memory pressure (unlike Dictionary).
    /// This avoids re-loading the same video when navigating back to a previously viewed move.
    private var assetCache = NSCache<NSString, AVAsset>()

    /// Reference to the currently running load task.
    /// Stored so we can cancel it if a new load is requested (e.g., user taps a different move).
    private var loadTask: Task<Void, Never>?

    // MARK: - MediaStatus
    // Represents the state machine for video loading.
    // The UI switches on this enum to show appropriate content:
    //   .idle    -> placeholder / empty state
    //   .loading -> progress bar with status text
    //   .loaded  -> video player with the loaded asset
    //   .failed  -> error message with retry option

    enum MediaStatus {
        /// No video is being loaded (initial state, or after reset).
        case idle

        /// Video is currently loading. Includes granular progress info:
        /// - progress: 0.0...1.0 for progress bar
        /// - status: Human-readable stage description (e.g., "Loading video tracks...")
        /// - eta: Optional estimated time remaining string (currently unused, reserved)
        case loading(progress: Double, status: String, eta: String?)

        /// Video loaded successfully. Contains:
        /// - asset: The fully loaded AVAsset, ready for AVPlayer or export
        /// - url: The file URL (useful for passing to VideoCompositionPipeline's outputURL)
        case loaded(asset: AVAsset, url: URL)

        /// Loading failed. The error contains a user-facing description.
        case failed(error: Error)
    }

    /// The current loading status. @Published so SwiftUI views automatically
    /// update when this changes. All mutations happen on MainActor (via `await MainActor.run`).
    @Published var status: MediaStatus = .idle

    /// Private initializer enforces the singleton pattern.
    /// Configures the NSCache with sensible limits:
    /// - countLimit: Maximum 10 cached assets (typical user won't view more in a session)
    /// - totalCostLimit: 100MB cap (video assets can be large; prevents OOM)
    private init() {
        assetCache.countLimit = 10
        assetCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    // MARK: - Public API

    /// Begins loading a video from the given file URL.
    ///
    /// This is the single entry point for all video loading in the app.
    /// It handles:
    /// 1. Cancelling any in-flight load (prevents stale results from a previous video)
    /// 2. File existence check (fast fail before doing async work)
    /// 3. Cache lookup (instant return if the asset was loaded recently)
    /// 4. Full async loading pipeline with progress updates
    /// 5. 90-second timeout (protects against corrupt files that hang AVFoundation)
    ///
    /// - Parameter url: Absolute file URL to the .mp4 file in Documents/Moves/
    ///
    /// Called from MoveDetailView/VideoEditorView when a move with a video is displayed.

    func loadVideo(from url: URL) {
        // Cancel any in-flight load — opening a new video supersedes the previous one.
        // The cancelled task will hit `catch is CancellationError` and silently exit.
        loadTask?.cancel()

        // Fast-fail: Check file exists before doing any async work.
        // This catches cases where the video was deleted externally or the
        // videoReference data in SwiftData is stale/corrupted.
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.status = .failed(error: NSError(
                domain: "MediaManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Video file not found"]
            ))
            return
        }

        // Use the URL's absolute string as the cache key.
        // NSString is required because NSCache is an Objective-C class.
        let assetKey = url.absoluteString as NSString

        // Set initial loading state so the UI shows a progress indicator immediately.
        self.status = .loading(progress: 0.0, status: "Creating asset...", eta: nil)

        // Create the AVURLAsset. This is lightweight — it doesn't load data yet.
        // AVURLAsset just wraps the URL; actual I/O happens when we call .load() methods.
        let asset = AVURLAsset(url: url)

        // Check the cache first. If we loaded this exact URL recently and NSCache
        // hasn't evicted it, skip the whole pipeline and return immediately.
        if let cachedAsset = self.assetCache.object(forKey: assetKey) {
            self.status = .loaded(asset: cachedAsset, url: url)
            return
        }

        // ── Full loading pipeline with timeout ──
        // We use withThrowingTaskGroup to race the loading pipeline against a 90-second timeout.
        //
        // PATTERN: "Race with timeout"
        // - Task 1 (loadPipeline): Does the actual work, reports progress at each stage
        // - Task 2 (timeout): Sleeps for 90s then throws an error
        // - `group.next()`: Returns when EITHER task completes first
        // - `group.cancelAll()`: Cancels the losing task
        //
        // If loadPipeline finishes first -> timeout is cancelled (normal case)
        // If timeout fires first -> loadPipeline is cancelled, error is shown
        //
        // The 90-second timeout protects against corrupt .mp4 files where
        // AVFoundation's async loading hangs indefinitely.

        loadTask = Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Task 1: The actual loading pipeline
                    group.addTask {
                        try await self.loadPipeline(asset: asset, url: url, cacheKey: assetKey)
                    }

                    // Task 2: Timeout watchdog (90 seconds)
                    group.addTask {
                        try await Task.sleep(nanoseconds: 90_000_000_000)  // 90 seconds
                        throw NSError(
                            domain: "MediaManager",
                            code: -10,
                            userInfo: [NSLocalizedDescriptionKey:
                                "Video took too long to load. The file may be corrupt or too large to process."]
                        )
                    }

                    // Wait for whichever task finishes first, then cancel the other.
                    try await group.next()
                    group.cancelAll()
                }
            } catch is CancellationError {
                // Task was cancelled (e.g., user navigated to a different move,
                // or the view disappeared). Silently ignore — no error to show.
            } catch {
                // Either the timeout fired or loadPipeline threw a non-cancellation error.
                // Update the UI to show the error state.
                await MainActor.run {
                    self.status = .failed(error: error)
                }
            }
        }
    }

    // MARK: - Loading Pipeline

    /// The sequential loading pipeline that validates and pre-loads an AVAsset.
    ///
    /// AVFoundation's modern API uses lazy loading — properties like `.duration`,
    /// `.isPlayable`, and track metadata are NOT available until you explicitly
    /// `.load()` them. This pipeline loads everything the app needs upfront so
    /// that later code (AVPlayer, export, thumbnail generation) doesn't have to
    /// wait for I/O.
    ///
    /// Each stage:
    /// 1. Checks for cancellation (so a cancelled load exits quickly)
    /// 2. Updates the UI with a progress message (so the user sees what's happening)
    /// 3. Loads one or more properties from the asset
    /// 4. Validates the result (fails fast if the file is unplayable or has no tracks)
    ///
    /// STAGES:
    ///   0.15 — Read file header: Check .isPlayable (validates the container format)
    ///   0.35 — Load duration: Pre-load .duration (needed for trimmer timeline)
    ///   0.55 — Load video tracks: Verify at least one video track exists
    ///   0.70 — Read track metadata: Pre-load .naturalSize and .nominalFrameRate
    ///   0.85 — Load audio tracks: Pre-load audio (optional, may not exist)
    ///   0.95 — Cache the asset: Store in NSCache for quick re-access
    ///   done — Set .loaded status with the asset and URL
    ///
    /// - Parameters:
    ///   - asset: The AVURLAsset to load (created in loadVideo)
    ///   - url: The original file URL (passed through to .loaded status)
    ///   - cacheKey: The NSString key for storing in assetCache

    private func loadPipeline(asset: AVURLAsset, url: URL, cacheKey: NSString) async throws {

        // ── Stage 1: Validate the file is playable ──
        // .isPlayable checks that AVFoundation recognizes the container format
        // (MP4, MOV, etc.) and can decode it. Rejects corrupt files early.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.15, status: "Reading file header...", eta: nil)
        }
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            await MainActor.run {
                self.status = .failed(error: NSError(
                    domain: "MediaManager",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "File is not playable"]
                ))
            }
            return
        }

        // ── Stage 2: Pre-load duration ──
        // Duration is needed by the trimmer timeline (TrimmerTimelineView) to
        // calculate handle positions and by AdaptiveThumbnailGenerator to space
        // thumbnail times evenly across the video.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.35, status: "Loading duration...", eta: nil)
        }
        _ = try await asset.load(.duration)

        // ── Stage 3: Verify video tracks exist ──
        // A file might be audio-only (e.g., .m4a renamed to .mp4).
        // We need at least one video track to display in the player.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.55, status: "Loading video tracks...", eta: nil)
        }
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            await MainActor.run {
                self.status = .failed(error: NSError(
                    domain: "MediaManager",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "No video tracks found"]
                ))
            }
            return
        }

        // ── Stage 4: Pre-load track metadata ──
        // .naturalSize: The raw pixel dimensions of the video (e.g., 1920x1080).
        //   Needed by VideoCompositionPipeline for transform calculations.
        // .nominalFrameRate: The typical frame rate (e.g., 30, 60).
        //   Useful for UI display and thumbnail interval calculations.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.70, status: "Reading track metadata...", eta: nil)
        }
        _ = try await tracks[0].load(.naturalSize)
        _ = try await tracks[0].load(.nominalFrameRate)

        // ── Stage 5: Pre-load audio tracks ──
        // Uses try? because audio is optional — some clips may be silent.
        // If audio exists, it's now cached in the asset for later use during export.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.85, status: "Loading audio tracks...", eta: nil)
        }
        _ = try? await asset.loadTracks(withMediaType: .audio)

        // ── Stage 6: Cache and complete ──
        // Store the fully-loaded asset in NSCache so reopening this move
        // is instant (no disk I/O). Then transition to .loaded state.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.95, status: "Caching asset...", eta: nil)
        }
        self.assetCache.setObject(asset, forKey: cacheKey)

        // Final state transition — the video is ready for playback and editing.
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loaded(asset: asset, url: url)
        }
    }
}
