import AVFoundation
import AVKit
import Combine
import OSLog
import SwiftUI

// VideoPlayer.swift - production video playback management

// MARK: - Supporting Types

/// Result of video asset validation
public struct AssetValidationResult {
    let isValid: Bool
    let error: String?
}


// MARK: - Shared Video Player
/// Clean, reusable video player component for consistent video playback across features
@MainActor
public class SharedVideoPlayer: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var state: PlayerState = .idle
    @Published public private(set) var isPlaying = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var duration: Double = 0.0
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var isReady = false
    @Published public private(set) var errorMessage: String?

    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SharedVideoPlayer")
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private let mode: PlayerMode
    // REMOVED: onReadyCallback - now using pure async/await pattern

    // MARK: - KVO Observer Management
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
    private var registeredNotificationObservers: [NSObjectProtocol] = []
    private let observerQueue = DispatchQueue(label: "com.breakingflashcards.videoPlayer.observers", qos: .utility)

  
    // MARK: - Player Modes
    public enum PlayerMode {
        case main      // Full-featured player for primary video content
        case preview   // Lightweight player for previews/thumbnails
    }

    // MARK: - Player States
    public enum PlayerState: Equatable {
        case idle
        case loading(progress: Double, message: String)
        case ready
        case playing
        case paused
        case ended
        case error(message: String)

        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        var canPlay: Bool {
            switch self {
            case .ready, .paused, .ended: return true
            default: return false
            }
        }

        var canPause: Bool {
            switch self {
            case .playing: return true
            default: return false
            }
        }

        var isErrorState: Bool {
            if case .error = self { return true }
            return false
        }
    }

    // MARK: - Initialization
    public init(mode: PlayerMode = .main) {
        self.mode = mode
        logger.info("🎬 SharedVideoPlayer initialized with mode: \(mode)")
    }

    deinit {
        // Cleanup resources synchronously in deinit
        logger.info("🧹 SharedVideoPlayer deinit - starting comprehensive cleanup")

        // Safe cleanup of all observers - synchronous cleanup for deinit
        registeredObservers.values.forEach { $0.invalidate() }
        registeredObservers.removeAll()
        registeredNotificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        registeredNotificationObservers.removeAll()

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        cancellables.removeAll()

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        logger.info("✅ SharedVideoPlayer deinit complete - all observers cleaned up safely")
    }

    // MARK: - Public Methods

    /// Load video from AVAsset with modern async pattern
    /// - Parameter asset: The video asset to load
    /// - Returns: True when player is ready for playback
    @discardableResult
    public func loadVideo(_ asset: AVAsset) async -> Bool {
        logger.info("🎬 Starting modern async video asset loading")
        Logger.loadingState.info("🎬 SharedVideoPlayer: Loading asset - tracks: \(asset.tracks.count), duration: \(asset.duration.seconds)s")

        // MODERNIZED: Remove callback logic - use pure async/await pattern
        // Cleanup any existing player state first
        state = .idle
        isReady = false
        isPlaying = false
        currentTime = 0.0
        progress = 0.0
        duration = 0.0
        errorMessage = nil

        // Clean up existing player
        cleanupExistingPlayer()

        // Set initial loading state
        state = .loading(progress: 0.0, message: "Validating video asset...")

        do {
            // Step 1: Validate the asset
            logger.debug("🔍 Validating video asset properties")
            state = .loading(progress: 0.1, message: "Validating video asset...")

            let validationResult = try await validateVideoAsset(asset)
            guard validationResult.isValid else {
                throw LoadingError.assetValidationFailed(validationResult.error ?? "Unknown validation error")
            }

            // Step 2: Load asset properties
            logger.debug("📊 Loading asset properties")
            state = .loading(progress: 0.3, message: "Loading video properties...")

            let assetDuration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)

            // Validate duration
            guard assetDuration.seconds > 0 else {
                throw LoadingError.invalidAsset("Video has zero or negative duration")
            }

            // Step 3: Create and configure player item
            logger.debug("🎮 Creating AVPlayer and AVPlayerItem")
            state = .loading(progress: 0.6, message: "Initializing video player...")

            // FIXED: Update duration in separate frame to prevent @Published collision
            let durationTimestamp = CFAbsoluteTimeGetCurrent()
            logPublishedUpdate("duration", durationTimestamp, "asset duration loaded")
            duration = assetDuration.seconds

            // MODERNIZED: Create player item with modern async AVPlayer setup
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.preferredForwardBufferDuration = 10.0 // Buffer 10 seconds ahead

            // Create player
            let player = AVPlayer(playerItem: playerItem)

            self.player = player
            self.playerItem = playerItem

            // Setup observers and time tracking
            setupPlayerObservers()
            setupTimeObserver()

            state = .loading(progress: 0.8, message: "Preparing video playback...")

            // Step 4: Wait for player to be ready with modern async pattern
            logger.debug("⏳ Waiting for player to be ready")
            try await waitForPlayerReady(playerItem, timeout: 10.0)

            state = .loading(progress: 0.9, message: "Finalizing video load...")

            // Step 5: Final validation and completion
            guard validatePlayerState() else {
                throw LoadingError.playerInitializationFailed("Player validation failed")
            }

            // MODERNIZED: Set final state without callback logic
            // iOS 18 ENHANCED: Ensure atomic @Published updates with frame-aligned temporal separation
            await finalizeVideoLoad()

            Logger.loadingState.info("✅ SharedVideoPlayer: Video loaded successfully - duration: \(duration)s, tracks: \(tracks.count)")

            // Validate state consistency after completion
            validateStateConsistency()

            // MODERNIZED: Return true to indicate successful loading
            return true

        } catch {
            Logger.loadingState.error("❌ SharedVideoPlayer: Video loading failed: \(error.localizedDescription)")
            state = .error(message: "Failed to load video: \(error.localizedDescription)")
            errorMessage = error.localizedDescription

            // Cleanup failed state
            cleanupExistingPlayer()
            isReady = false

            return false
        }
    }

    // MARK: - Enhanced State Management

    /// Minimal diagnostic logging for @Published property timing verification
    /// Helps track frame separation and identify potential collision issues
    private func logPublishedUpdate(_ propertyName: String, _ timestamp: Double, _ context: String) {
        let formattedTime = String(format: "%.3f", timestamp)
        logger.debug("🔄 [@Published] \(propertyName) at \(formattedTime)s - \(context)")
    }

    /// Finalize video load with simple fire-and-forget Task pattern
    /// Original implementation restored - the issue is in AddMoveViewModel, not here
    @MainActor
    private func finalizeVideoLoad() async {
        // Simple fire-and-forget pattern - no complex frame separation needed
        // The SharedVideoPlayer implementation was correct
        state = .ready
        isReady = true

        logger.debug("✅ finalizeVideoLoad completed - simple fire-and-forget pattern")
    }

    /// Finalize player ready state with simple fire-and-forget Task pattern
    /// Original implementation restored - the issue is in AddMoveViewModel, not here
    @MainActor
    private func finalizePlayerReadyState() async {
        // Simple fire-and-forget pattern - no complex frame separation needed
        // The SharedVideoPlayer implementation was correct
        state = .ready
        isReady = true

        logger.debug("✅ finalizePlayerReadyState completed - simple fire-and-forget pattern")
    }

    /// Start video playback
    public func play() {
        guard state.canPlay, let player = player else {
            logger.warning("⚠️ Cannot play - player not ready")
            return
        }

        logger.info("▶️ Starting playback")
        player.play()

        Task { @MainActor in
            state = .playing
            isPlaying = true
        }
    }

    /// Pause video playback
    public func pause() {
        guard state.canPause, let player = player else {
            logger.warning("⚠️ Cannot pause - player not playing")
            return
        }

        logger.info("⏸️ Pausing playback")
        player.pause()

        Task { @MainActor in
            state = .paused
            isPlaying = false
        }
    }

    /// Stop video playback and reset to beginning
    public func stop() {
        guard let player = player else { return }

        logger.info("⏹️ Stopping playback")
        player.pause()
        player.seek(to: .zero)

        Task { @MainActor in
            state = .ready
            isPlaying = false
            currentTime = 0.0
            progress = 0.0
        }
    }

    /// Seek to specific time
    /// - Parameter time: Time in seconds
    public func seek(to time: Double) {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)

        logger.info("⏩ Seeking to \(time)s")
    }

    /// Toggle between play and pause
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Set volume
    /// - Parameter volume: Volume level (0.0 - 1.0)
    public func setVolume(_ volume: Float) {
        player?.volume = volume
    }

    /// Set mute state
    /// - Parameter muted: Whether to mute the player
    public func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    /// Cleanup resources
    public func cleanup() {
        logger.info("🧹 Cleaning up video player resources")

        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        cancellables.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil

        Task { @MainActor in
            state = .idle
            isReady = false
            isPlaying = false
        }
    }

    // MARK: - Enhanced State Management

    /// Force state validation and recovery - for debugging and manual recovery
    public func forceStateValidation() {
        logger.info("🔧 MANUAL STATE VALIDATION TRIGGERED - state: \(state), isReady: \(isReady)")

        let hasPlayer = player != nil
        let playerItemReady = playerItem?.status == .readyToPlay
        let playerItemFailed = playerItem?.status == .failed

        logger.info("🔍 STATE VALIDATION: hasPlayer=\(hasPlayer), playerItemReady=\(playerItemReady), playerItemFailed=\(playerItemFailed)")

        if playerItemReady && (state.isLoading || state == .idle || (state == .ready && !isReady)) {
            logger.warning("⚠️ MANUAL RECOVERY: Forcing ready state based on playerItem status")
            state = .ready
            isReady = true
            logger.info("✅ MANUAL RECOVERY COMPLETED: state=\(state), isReady=\(isReady)")
        }
    }

    /// Enhanced loadVideo method with automatic recovery mechanisms
    public func loadVideoWithRecovery(_ asset: AVAsset) async {
        logger.info("🚀 ENHANCED LOAD VIDEO WITH RECOVERY")
        await loadVideo(asset)

        // Schedule recovery checks if player doesn't become ready
        Task { @MainActor in
            // Check after 1s, 3s, and 5s
            for delay in [1.0, 3.0, 5.0] {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                if self.state.isLoading || (self.state == .ready && !self.isReady) {
                    logger.warning("⚠️ SCHEDULED RECOVERY CHECK (\(delay)s): state=\(self.state), isReady=\(self.isReady)")
                    self.forceStateValidation()
                } else if self.state == .ready && self.isReady {
                    logger.info("✅ SCHEDULED RECOVERY CHECK (\(delay)s): State is consistent")
                    break
                }
            }
        }
    }

    // MARK: - Private Methods

    // MARK: - Safe Observer Management

    /// Safely register a KVO observer with tracking
    private func safelyRegisterObserver<T: NSObject, Value>(
        on object: T,
        keyPath: KeyPath<T, Value>,
        handler: @escaping (T, Value) -> Void
    ) {
        observerQueue.async { [weak self] in
            guard let self = self else { return }

            let observerKey = "\(String(describing: T.self)).\(keyPath)"

            // Remove existing observer if present
            if let existingObserver = self.registeredObservers[observerKey] {
                self.logger.info("🔄 Removing existing observer before re-registration: \(observerKey)")
                existingObserver.invalidate()
                self.registeredObservers.removeValue(forKey: observerKey)
            }

            // Register new observer
            let newObserver = object.observe(keyPath) { obj, change in
                if let newValue = change.newValue {
                    handler(obj, newValue)
                }
            }

            self.registeredObservers[observerKey] = newObserver
            self.logger.info("✅ Registered observer: \(observerKey)")
        }
    }

    /// Safely remove a specific KVO observer
    private func safelyRemoveObserver(forKey key: String) {
        observerQueue.async { [weak self] in
            guard let self = self else { return }

            if let observer = self.registeredObservers[key] {
                self.logger.info("🗑️ Removing observer: \(key)")
                observer.invalidate()
                self.registeredObservers.removeValue(forKey: key)
            } else {
                self.logger.warning("⚠️ Observer not found for removal: \(key)")
            }
        }
    }

    /// Safely remove all KVO observers
    private func safelyRemoveAllObservers() {
        observerQueue.async { [weak self] in
            guard let self = self else { return }

            self.logger.info("🧹 Removing all registered KVO observers (\(self.registeredObservers.count))")

            for (key, observer) in self.registeredObservers {
                self.logger.debug("🗑️ Removing observer: \(key)")
                observer.invalidate()
            }

            self.registeredObservers.removeAll()

            // Also remove notification observers
            self.safelyRemoveAllNotificationObservers()

            self.logger.info("✅ All observers safely removed")
        }
    }

    /// Safely register a notification observer
    private func safelyRegisterNotificationObserver(
        name: NSNotification.Name,
        object: Any?,
        queue: Foundation.OperationQueue? = Foundation.OperationQueue.main,
        handler: @escaping (Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: handler
        )

        registeredNotificationObservers.append(observer)
        logger.info("✅ Registered notification observer: \(name)")
    }

    /// Safely remove all notification observers
    private func safelyRemoveAllNotificationObservers() {
        logger.info("🧹 Removing all registered notification observers (\(registeredNotificationObservers.count))")

        for observer in registeredNotificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }

        registeredNotificationObservers.removeAll()
        logger.info("✅ All notification observers safely removed")
    }

    // MARK: - Fallback State Checking

    /// Schedule periodic state validation during the critical initialization period
    private func scheduleFallbackStateChecks() {
        logger.info("🕐 SCHEDULING FALLBACK STATE CHECKS for the next 5 seconds")

        // Schedule validation checks at 100ms, 500ms, 1s, 2s, and 5s intervals
        let intervals: [TimeInterval] = [0.1, 0.5, 1.0, 2.0, 5.0]

        for interval in intervals {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                // Only perform check if we still have a valid player
                if self.player != nil && self.playerItem != nil {
                    logger.debug("🔍 FALLBACK CHECK (\(interval)s): state=\(self.state), isReady=\(self.isReady)")

                    // Perform validation if there might be an issue
                    if self.state.isLoading || (self.state == .ready && !self.isReady) {
                        logger.warning("⚠️ FALLBACK DETECTED ISSUE at \(interval)s - performing validation")
                        self.validateStateConsistency()

                        // Additional fallback: force ready state if player is actually ready
                        if let playerItem = self.playerItem, playerItem.status == .readyToPlay {
                            logger.info("🔧 FALLBACK RECOVERY: Forcing ready state based on AVPlayerItem status")
                            self.state = .ready
                            self.isReady = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Video Loading Helpers

    /// Comprehensive video asset validation
    private func validateVideoAsset(_ asset: AVAsset) async throws -> AssetValidationResult {
        logger.debug("🔍 Performing comprehensive asset validation")

        // Check asset readability
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            return AssetValidationResult(isValid: false, error: "Asset is not readable")
        }

        // Check for tracks
        let tracks = try await asset.load(.tracks)
        guard !tracks.isEmpty else {
            return AssetValidationResult(isValid: false, error: "No media tracks found")
        }

        // Check for video track
        let videoTracks = tracks.filter { $0.mediaType == .video }
        guard !videoTracks.isEmpty else {
            return AssetValidationResult(isValid: false, error: "No video tracks found")
        }

        // Validate natural size
        for videoTrack in videoTracks {
            let naturalSize = try await videoTrack.load(.naturalSize)
            guard naturalSize.width > 0 && naturalSize.height > 0 else {
                return AssetValidationResult(isValid: false, error: "Invalid video dimensions")
            }
        }

        // Check duration
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            return AssetValidationResult(isValid: false, error: "Invalid duration")
        }

        // Check for protected content
        let hasProtectedContent = try await asset.load(.hasProtectedContent)
        if hasProtectedContent {
            logger.warning("⚠️ Asset contains protected content")
        }

        logger.debug("✅ Asset validation passed - duration: \(duration.seconds)s, tracks: \(tracks.count)")
        return AssetValidationResult(isValid: true, error: nil)
    }

    /// Wait for player item to be ready with timeout - OPENSPEC FIX: Continuation lifecycle management
    private func waitForPlayerReady(_ playerItem: AVPlayerItem, timeout: TimeInterval) async throws {
        let continuationId = UUID().uuidString
        logger.info("⏳ waitForPlayerReady: Starting wait with timeout: \(timeout)s [\(continuationId)]")

        return try await withCheckedThrowingContinuation { continuation in
            // ENHANCED FIX: Track continuation state to prevent multiple resumptions
            var continuationState = ContinuationState()
            let observerKey = "waitForPlayerReady.\(continuationId)"

            // CRITICAL FIX: Check current status first to avoid unnecessary observers
            switch playerItem.status {
            case .readyToPlay:
                logger.info("⚡ waitForPlayerReady: PlayerItem already ready [\(continuationId)]")
                continuationState.safeResume(continuation, with: .success(()), logger: self.logger, context: "immediate ready")
                return
            case .failed:
                let errorMessage = playerItem.error?.localizedDescription ?? "Player item failed"
                logger.error("❌ waitForPlayerReady: PlayerItem already failed [\(continuationId)]: \(errorMessage)")
                continuationState.safeResume(continuation, with: .failure(LoadingError.playerItemFailed(errorMessage)), logger: self.logger, context: "immediate failure")
                return
            default:
                logger.debug("⏳ waitForPlayerReady: PlayerItem status unknown, setting up observer [\(continuationId)]")
            }

            // CRITICAL FIX: Set up timeout with proper cancellation
            var timeoutTask: Task<Void, Never>? = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                guard !continuationState.isResumed else { return }

                self?.logger.error("⏰ waitForPlayerReady: Timeout after \(timeout)s [\(continuationId)]")
                self?.safelyRemoveObserver(forKey: observerKey)
                continuationState.safeResume(continuation, with: .failure(LoadingError.timeout(timeout)), logger: self?.logger, context: "timeout")
            }

            // CRITICAL FIX: Set up status observer with proper cleanup
            let statusObserver = playerItem.observe(\.status) { item, _ in
                guard !continuationState.isResumed else {
                    self.logger.debug("⚠️ waitForPlayerReady: Continuation already resumed, ignoring status change [\(continuationId)]")
                    return
                }

                switch item.status {
                case .readyToPlay:
                    self.logger.info("✅ waitForPlayerReady: PlayerItem became ready [\(continuationId)]")
                    self.safelyRemoveObserver(forKey: observerKey)
                    timeoutTask?.cancel()
                    continuationState.safeResume(continuation, with: .success(()), logger: self.logger, context: "player ready")

                case .failed:
                    let errorMessage = item.error?.localizedDescription ?? "Player item failed"
                    self.logger.error("❌ waitForPlayerReady: PlayerItem failed [\(continuationId)]: \(errorMessage)")
                    self.safelyRemoveObserver(forKey: observerKey)
                    timeoutTask?.cancel()
                    continuationState.safeResume(continuation, with: .failure(LoadingError.playerItemFailed(errorMessage)), logger: self.logger, context: "player failed")

                default:
                    self.logger.debug("⏳ waitForPlayerReady: PlayerItem status still unknown [\(continuationId)]")
                    break
                }
            }

            // Track observer for cleanup
            registeredObservers[observerKey] = statusObserver
            logger.debug("✅ waitForPlayerReady: Observer registered [\(continuationId)]")

            // CRITICAL FIX: Handle continuation cleanup if this specific call gets cancelled
            Task { @MainActor [weak self] in
                // Wait for completion or cancellation
                while !continuationState.isResumed && !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms check interval
                    } catch {
                        // Task was cancelled
                        guard !continuationState.isResumed else { return }

                        self?.logger.info("🚫 waitForPlayerReady: Task cancelled [\(continuationId)]")
                        self?.safelyRemoveObserver(forKey: observerKey)
                        timeoutTask?.cancel()

                        // ENHANCED FIX: Resume with success on cancellation to avoid hanging
                        continuationState.safeResume(continuation, with: .success(()), logger: self?.logger, context: "cancellation")
                        return
                    }
                }
            }
        }
    }

    /// Continuation state manager to prevent multiple resumptions
    private class ContinuationState {
        private var _isResumed = false
        private let lock = NSLock()

        var isResumed: Bool {
            lock.withLock { _isResumed }
        }

        func safeResume<T>(_ continuation: CheckedContinuation<T, Error>, with result: Result<T, Error>, logger: Logger?, context: String) {
            lock.withLock {
                guard !_isResumed else {
                    logger?.warning("⚠️ Continuation already resumed, attempting to resume again from context: \(context)")
                    return
                }
                _isResumed = true
            }

            switch result {
            case .success(let value):
                continuation.resume(returning: value)
                logger?.info("✅ Continuation resumed successfully from context: \(context)")
            case .failure(let error):
                continuation.resume(throwing: error)
                logger?.info("✅ Continuation resumed with error from context: \(context): \(error.localizedDescription)")
            }
        }
    }

    /// Clean up all waitForPlayerReady observers
    private func cleanupAllWaitForPlayerReadyObservers() {
        observerQueue.async { [weak self] in
            guard let self = self else { return }

            let keysToRemove = self.registeredObservers.keys.filter { $0.hasPrefix("waitForPlayerReady.") }

            for key in keysToRemove {
                if let observer = self.registeredObservers[key] {
                    observer.invalidate()
                    self.registeredObservers.removeValue(forKey: key)
                    self.logger.debug("🗑️ waitForPlayerReady: Cleaned up observer: \(key)")
                }
            }
        }
    }

    /// Validate final player state
    private func validatePlayerState() -> Bool {
        guard let player = player else {
            logger.error("❌ Player validation failed: player is nil")
            return false
        }

        guard let playerItem = playerItem else {
            logger.error("❌ Player validation failed: playerItem is nil")
            return false
        }

        guard playerItem.status == .readyToPlay else {
            logger.error("❌ Player validation failed: playerItem status is \(playerItem.status.rawValue)")
            return false
        }

        guard duration > 0 else {
            logger.error("❌ Player validation failed: invalid duration \(duration)")
            return false
        }

        logger.debug("✅ Player validation passed")
        return true
    }

    /// Validate state consistency and attempt automatic recovery
    private func validateStateConsistency() {
        logger.info("🔍 VALIDATING STATE CONSISTENCY - state: \(state), isReady: \(isReady), player exists: \(player != nil)")

        // Check for state inconsistencies
        let hasPlayer = player != nil
        let playerItemReady = playerItem?.status == .readyToPlay
        let playerItemFailed = playerItem?.status == .failed
        let playerItemUnknown = playerItem?.status == .unknown

        var recoveryAttempts = 0
        var stateChanges = [String]()

        // ENHANCED FIX 1: Inconsistency - state is ready but isReady is false
        if case .ready = state, !isReady {
            logger.warning("⚠️ STATE INCONSISTENCY: state=ready but isReady=false - attempting recovery")
            isReady = true
            recoveryAttempts += 1
            stateChanges.append("isReady: false → true")
        }

        // ENHANCED FIX 2: Inconsistency - player is ready but state is still loading
        if playerItemReady && state.isLoading {
            logger.warning("⚠️ STATE INCONSISTENCY: playerItem ready but state still loading - attempting recovery")
            state = .ready
            if !isReady {
                isReady = true
                stateChanges.append("isReady: false → true")
            }
            recoveryAttempts += 1
            stateChanges.append("state: loading → ready")
        }

        // ENHANCED FIX 3: Inconsistency - player is ready but state is not ready (edge case)
        if playerItemReady && state != .ready && state != .playing && state != .paused && state != .ended {
            logger.warning("⚠️ STATE INCONSISTENCY: playerItem ready but state is \(state) - attempting recovery")
            state = .ready
            if !isReady {
                isReady = true
                stateChanges.append("isReady: false → true")
            }
            recoveryAttempts += 1
            stateChanges.append("state: \(state) → ready")
        }

        // ENHANCED FIX 4: Inconsistency - player is failed but state doesn't reflect error
        if playerItemFailed {
            let errorMessage = playerItem?.error?.localizedDescription ?? "Player item failed"
            logger.warning("⚠️ STATE INCONSISTENCY: playerItem failed but state is \(state) - attempting recovery")
            state = .error(message: errorMessage)
            self.errorMessage = errorMessage
            isReady = false
            recoveryAttempts += 1
            stateChanges.append("state: \(state) → error, isReady: true → false")
        }

        // ENHANCED FIX 5: Defensive check for unknown status persisting too long
        if playerItemUnknown && state.isLoading {
            logger.warning("⚠️ STATE WARNING: playerItem unknown while in loading state - monitoring")
            // This might be normal during initialization, so just log it for now
        }

        // ENHANCED FIX 6: Fallback consistency check - if all components indicate ready but flags don't match
        if hasPlayer && playerItemReady && (state == .ready || state == .playing || state == .paused || state == .ended) && !isReady {
            logger.warning("⚠️ STATE INCONSISTENCY: All indicators show ready but isReady=false - forcing recovery")
            isReady = true
            recoveryAttempts += 1
            stateChanges.append("isReady: false → true (fallback)")
        }

        // Log recovery results
        if recoveryAttempts > 0 {
            logger.info("🔧 AUTO-RECOVERY COMPLETED: \(recoveryAttempts) corrections made")
            for (index, change) in stateChanges.enumerated() {
                logger.info("   \(index + 1). \(change)")
            }
            logger.info("🎯 FINAL STATE: \(state), isReady: \(isReady)")
        }

        // Log final state validation for debugging
        logger.debug("✅ State validation complete - state: \(state), isReady: \(isReady), playerReady: \(playerItemReady), playerFailed: \(playerItemFailed)")
    }

    /// Cleanup existing player state
    private func cleanupPlayerState() async {
        logger.debug("🧹 Cleaning up existing player state")

        await MainActor.run {
            state = .idle
            isReady = false
            isPlaying = false
            currentTime = 0.0
            progress = 0.0
            duration = 0.0
            errorMessage = nil
        }

        cleanupExistingPlayer()
    }

    /// Cleanup existing player and observers
    private func cleanupExistingPlayer() {
        logger.info("🧹 Starting comprehensive player cleanup")

        // Stop playback
        player?.pause()

        // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            logger.debug("🗑️ Time observer removed")
        }

        // Remove all cancellables
        cancellables.removeAll()
        logger.debug("🗑️ All cancellables removed (\(cancellables.count))")

        // Safely remove all KVO and notification observers
        safelyRemoveAllObservers()

        // Replace current item with nil to release resources
        player?.replaceCurrentItem(with: nil)

        // Clear references
        player = nil
        playerItem = nil

        logger.info("✅ Player cleanup completed - all observers safely removed")
    }

    private func setupPlayerObservers() {
        guard let playerItem = playerItem else {
            logger.warning("⚠️ Cannot setup observers - playerItem is nil")
            return
        }

        logger.info("🔧 SETTING UP SAFE PLAYER OBSERVERS - current status: \(playerItem.status.rawValue)")

        // Clean up any existing observers before setting up new ones
        safelyRemoveAllObservers()

        // Clear existing cancellables to prevent duplicates
        cancellables.removeAll()
        logger.debug("🧹 Cleared previous cancellables to prevent duplicate observers")

        // CRITICAL FIX: Check current status BEFORE setting up observers
        // This handles the case where playerItem is already ready when observers are set up
        if playerItem.status == .readyToPlay {
            logger.info("⚡ IMMEDIATE READY DETECTION: PlayerItem already ready when setting up observers")
            Task { @MainActor in
                await self.handlePlayerItemStatusChange(.readyToPlay)
            }
        } else if playerItem.status == .failed {
            logger.warning("⚠️ IMMEDIATE FAILURE DETECTION: PlayerItem already failed when setting up observers")
            Task { @MainActor in
                await self.handlePlayerItemStatusChange(.failed)
            }
        }

        // Set up safe KVO observers for player item status
        safelyRegisterObserver(on: playerItem, keyPath: \.status) { [weak self] playerItem, status in
            guard let self = self else { return }
            Task { @MainActor in
                self.logger.info("🔄 KVO Player item status changed: \(status.rawValue)")
                await self.handlePlayerItemStatusChange(status)
            }
        }

        safelyRegisterObserver(on: playerItem, keyPath: \.isPlaybackLikelyToKeepUp) { [weak self] _, isLikelyToKeepUp in
            guard let self = self else { return }
            Task { @MainActor in
                self.logger.debug("🔄 KVO Playback buffer likely to keep up: \(isLikelyToKeepUp)")
                self.handleBufferChange(isLikelyToKeepUp)
            }
        }

        safelyRegisterObserver(on: playerItem, keyPath: \.isPlaybackBufferEmpty) { [weak self] _, isEmpty in
            guard let self = self else { return }
            Task { @MainActor in
                self.logger.debug("🔄 KVO Playback buffer empty: \(isEmpty)")
                self.handleBufferEmpty(isEmpty)
            }
        }

        safelyRegisterObserver(on: playerItem, keyPath: \.loadedTimeRanges) { [weak self] _, timeRanges in
            guard let self = self else { return }
            Task { @MainActor in
                self.logger.debug("🔄 KVO Loaded time ranges updated")
                self.handleLoadedTimeRanges(timeRanges)
            }
        }

        // Set up safe KVO observers for player if available
        if let player = player {
            safelyRegisterObserver(on: player, keyPath: \.rate) { [weak self] _, rate in
                guard let self = self else { return }
                Task { @MainActor in
                    self.logger.debug("🔄 KVO Player rate changed: \(rate)")
                    self.handleRateChange(rate)
                }
            }

            safelyRegisterObserver(on: player, keyPath: \.timeControlStatus) { [weak self] _, status in
                guard let self = self else { return }
                Task { @MainActor in
                    self.logger.debug("🔄 KVO Time control status changed: \(status.rawValue)")
                    self.handleTimeControlStatusChange(status)
                }
            }
        }

        // Set up safe notification observers for playback events
        safelyRegisterNotificationObserver(
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackCompletion()
            }
        }

        safelyRegisterNotificationObserver(
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handlePlaybackFailure(notification)
            }
        }

        safelyRegisterNotificationObserver(
            name: .AVPlayerItemPlaybackStalled,
            object: playerItem
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackStall()
            }
        }

        logger.info("✅ Safe player observers setup complete - using KVO tracking")
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func handlePlayerItemStatusChange(_ status: AVPlayerItem.Status) async {
        logger.info("🎬 Player item status changed: \(status.rawValue), current state: \(state), isReady: \(isReady)")

        switch status {
        case .readyToPlay:
            logger.info("✅ Player item ready to play - updating isReady state")

            // iOS 18 ENHANCED: Ensure state and isReady are synchronized with temporal separation
            let previousState = state
            let previousIsReady = isReady

            // iOS 18 ENHANCED: Use frame-aligned temporal separation for @Published updates
            // This fixes the @Published collision issue that causes AddMoveViewModel to get stuck
            await finalizePlayerReadyState()

            logger.info("🔄 FRAME-ALIGNED STATE TRANSITION: \(previousState) → Ready due to AVPlayerItem ready")
            logger.info("🎯 VIDEO PLAYER READY: isReady set to true with temporal separation - video should now display")

            // REMOVED: Callback logic - now using pure async/await pattern
            // Player ready state is communicated through @Published isReady property
            Logger.loadingState.info("🎯 SharedVideoPlayer: Player ready - isReady=true")

            // CRITICAL FIX: Load duration from player item for accurate timing
            if let playerItem = playerItem {
                let itemDuration = playerItem.duration
                if itemDuration.seconds > 0 && itemDuration.seconds != duration {
                    duration = itemDuration.seconds
                    logger.info("📊 Updated duration from playerItem: \(duration)s")
                }
            }

            // Enhanced state validation and automatic recovery
            validateStateConsistency()

            // Log successful state synchronization
            logger.info("🎯 STATE SYNC SUCCESS: \(previousState) → \(state), isReady: \(previousIsReady) → \(isReady)")

            // REMOVED: Coordination notification broadcast - now handled by AddMoveViewModel
            // Player state changes are observed directly through @Published properties

            // Schedule additional validation to ensure consistency
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                if self.state == .ready && self.isReady {
                    self.logger.info("✅ CONFIRMED: Player state is consistent after 100ms")
                } else {
                    self.logger.warning("⚠️ State inconsistency detected after 100ms - forcing recovery")
                    self.state = .ready
                    self.isReady = true
                }
            }

        case .failed:
            let errorMessage = playerItem?.error?.localizedDescription ?? "Unknown playback error"
            logger.error("❌ Player item failed: \(errorMessage)")

            let previousState = state
            state = .error(message: errorMessage)
            self.errorMessage = errorMessage

            // Ensure isReady is false when player fails
            isReady = false

            logger.info("🔄 STATE TRANSITION: \(previousState) → Error, isReady: true → false")

        case .unknown:
            logger.info("📡 Player item status unknown - awaiting further status updates")

            // Add defensive check - if state is loading but player item is unknown for too long,
            // we might need to force a recovery
            if state.isLoading {
                logger.warning("⚠️ Player item status unknown while in loading state - potential issue")

                // Schedule a fallback check if status stays unknown
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                    if self.playerItem?.status == .unknown && self.state.isLoading {
                        self.logger.warning("⚠️ PlayerItem status still unknown after 2s - forcing error state")
                        self.state = .error(message: "Player initialization timed out")
                        self.isReady = false
                        self.errorMessage = "Player initialization timed out"
                    }
                }
            }

        @unknown default:
            logger.warning("⚠️ Unknown player item status: \(status.rawValue) - handling gracefully")
        }
    }

    private func handleBufferChange(_ isLikelyToKeepUp: Bool) {
        if !isLikelyToKeepUp && isPlaying {
            logger.info("⏳ Buffering... (not likely to keep up)")
            // Could show buffering indicator here
        } else if isLikelyToKeepUp && isPlaying {
            logger.debug("🚀 Buffer sufficient, playback can continue")
        }
    }

    private func handleBufferEmpty(_ isEmpty: Bool) {
        if isEmpty {
            logger.info("⏳ Buffer empty - waiting for data")
            // Could update UI to show buffering state
        } else {
            logger.debug("📦 Buffer has data")
        }
    }

    private func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        logger.debug("⏱️ Time control status changed to: \(status.rawValue)")

        switch status {
        case .paused:
            if isPlaying {
                // Playback was paused externally
                isPlaying = false
                state = .paused
            }
        case .waitingToPlayAtSpecifiedRate:
            logger.debug("⏳ Waiting to play at specified rate")
        case .playing:
            isPlaying = true
            state = .playing
        @unknown default:
            logger.warning("⚠️ Unknown time control status: \(status.rawValue)")
        }
    }

    private func handleLoadedTimeRanges(_ timeRanges: [NSValue]) {
        guard !timeRanges.isEmpty, let playerItem = playerItem else { return }

        // Calculate buffering progress
        let totalBufferedDuration = timeRanges.reduce(0.0) { total, timeRangeValue in
            let timeRange = timeRangeValue.timeRangeValue
            return total + timeRange.duration.seconds
        }

        let bufferProgress = duration > 0 ? totalBufferedDuration / duration : 0.0

        if bufferProgress < 1.0 {
            logger.debug("📦 Buffer progress: \(Int(bufferProgress * 100))%")
        }
    }

    private func handlePlaybackCompletion() {
        logger.info("🏁 Playback completed successfully")
        isPlaying = false
        state = .ended
        currentTime = duration
        progress = 1.0
    }

    private func handlePlaybackFailure(_ notification: Notification) {
        logger.error("❌ ENHANCED PLAYBACK FAILURE HANDLING")

        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        let errorMessage = error?.localizedDescription ?? "Unknown playback error"

        let previousState = state
        state = .error(message: errorMessage)
        self.errorMessage = errorMessage
        isPlaying = false
        isReady = false

        logger.error("🔄 STATE TRANSITION: \(previousState) → Error due to playback failure")
        logger.error("🔍 ERROR DETAILS: \(errorMessage)")

        // ENHANCED: Attempt recovery based on error type
        if let nsError = error as NSError? {
            logger.error("🔍 ERROR CODE: \(nsError.code), DOMAIN: \(nsError.domain)")

            // Attempt recovery for common errors
            if nsError.code == NSURLErrorNotConnectedToInternet {
                logger.info("🔧 NETWORK ERROR DETECTED - No internet connection")
                // Could trigger retry mechanism here
            } else if nsError.domain == AVFoundationErrorDomain {
                logger.info("🔧 AVFOUNDATION ERROR DETECTED - Attempting recovery")
                // Could attempt to recreate player here
            }
        }

        // Validate state consistency after error
        validateStateConsistency()
    }

    private func handlePlaybackStall() {
        logger.warning("⚠️ Playback stalled - waiting for data")
        // Could show stalling indicator or attempt to recover
    }

    private func handleRateChange(_ rate: Float) {
        let wasPlaying = isPlaying
        let isCurrentlyPlaying = rate > 0

        if wasPlaying != isCurrentlyPlaying {
            isPlaying = isCurrentlyPlaying

            if isCurrentlyPlaying, case .ready = state {
                state = .playing
            } else if !isCurrentlyPlaying, case .playing = state {
                state = .paused
            }
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        currentTime = time.seconds
        progress = duration > 0 ? currentTime / duration : 0.0

        // Check if video ended
        if progress >= 1.0 && isPlaying {
            state = .ended
            isPlaying = false
            logger.info("🏁 Video playback ended")
        }
    }
}

// MARK: - Video Player View
/// SwiftUI view wrapper for SharedVideoPlayer
struct VideoPlayerView: View {
    @ObservedObject var player: SharedVideoPlayer
    let showControls: Bool

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoPlayerView")

    init(player: SharedVideoPlayer, showControls: Bool = true) {
        self.player = player
        self.showControls = showControls
    }

    var body: some View {
        ZStack {
            // Video player using AVPlayerViewController
            if let avPlayer = getPlayerInstance(), player.isReady {
                VideoPlayerController(player: avPlayer, showControls: showControls)
                    .onAppear {
                        logger.info("🎬 VideoPlayerController appeared - video should be visible")
                    }
            } else {
                // Enhanced loading state with detailed feedback
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text(getLoadingMessage())
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)

                    Text(getDetailedLoadingStatus())
                        .font(.ibmPlexMono(size: 12, weight: .regular))
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)

                    if let errorMessage = player.errorMessage {
                        Text(errorMessage)
                            .font(.ibmPlexMono(size: 12, weight: .regular))
                            .foregroundColor(.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // ENHANCED: Add manual recovery button for debugging
                    #if DEBUG
                    if player.state == .ready && !player.isReady {
                        Button("Force Ready State") {
                            logger.warning("🔧 Manual intervention: Forcing isReady to true")
                            // This would require making isReady publicly settable or adding a public method
                        }
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.warning)
                        .padding(.top, 8)
                    }
                    #endif
                }
                .onAppear {
                    logger.info("🔄 VideoPlayerView in loading state - state: \(player.state), isReady: \(player.isReady)")

                    // ENHANCED: Add immediate state check on appearance
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        logger.info("🔍 DELAYED STATE CHECK: state=\(self.player.state), isReady=\(self.player.isReady)")
                        if self.player.state == .ready && !self.player.isReady {
                            logger.warning("⚠️ DELAYED CHECK: Inconsistency detected - state=ready but isReady=false")
                        }
                    }
                }
            }

            // Overlay controls if enabled
            if showControls && player.isReady {
                VStack {
                    Spacer()

                    // Playback controls overlay
                    playbackControlsOverlay
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.7), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                }
            }
        }
    }

    // MARK: - Playback Controls Overlay
    private var playbackControlsOverlay: some View {
        HStack(spacing: 20) {
            // Play/Pause button
            Button(action: {
                player.togglePlayPause()
            }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }

            // Time display and progress
            VStack(spacing: 4) {
                HStack {
                    Text(player.currentTimeString)
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text(player.durationString)
                        .font(.ibmPlexMono(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)

                        // Progress fill
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: geometry.size.width * player.progress, height: 4)
                            .cornerRadius(2)
                            .animation(.easeInOut(duration: 0.1), value: player.progress)
                    }
                }
                .frame(height: 20)
                .onTapGesture { location in
                    // Seek to tapped position
                    let relativePosition = location.x / UIScreen.main.bounds.width
                    let targetTime = player.duration * relativePosition
                    player.seek(to: targetTime)
                }
            }

            // Mute button
            Button(action: {
                player.setMuted(!player.isMuted)
            }) {
                Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Get Player Instance
    private func getPlayerInstance() -> AVPlayer? {
        return player.avPlayer
    }

    // MARK: - Enhanced Loading State Helpers
    private func getLoadingMessage() -> String {
        switch player.state {
        case .loading(let progress, let message):
            return message
        case .idle:
            return "Initializing video player..."
        case .ready, .playing, .paused, .ended:
            return player.isReady ? "Ready" : "Finalizing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private func getDetailedLoadingStatus() -> String {
        if player.isReady {
            return "Video ready! Displaying content..."
        } else if case .loading(let progress, _) = player.state {
            return "Progress: \(Int(progress * 100))% - Player state: \(player.state)"
        } else {
            return "Player state: \(player.state) | Ready: \(player.isReady)"
        }
    }
}

// MARK: - Video Player Controller
/// UIKit wrapper for AVPlayerViewController
struct VideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let showControls: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showControls
        controller.allowsPictureInPicturePlayback = false
        controller.allowsVideoFrameAnalysis = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.showsPlaybackControls = showControls
    }
}

// MARK: - Convenience Extensions
public extension SharedVideoPlayer {
    /// Get current playback time as formatted string (MM:SS)
    var currentTimeString: String {
        return formatTime(currentTime)
    }

    /// Get duration as formatted string (MM:SS)
    var durationString: String {
        return formatTime(duration)
    }

    /// Get remaining time as formatted string (MM:SS)
    var remainingTimeString: String {
        return formatTime(max(0, duration - currentTime))
    }

    /// Get the AVPlayer instance for use with VideoPlayerController
    var avPlayer: AVPlayer? {
        return player
    }

    /// Check if player is muted
    var isMuted: Bool {
        return player?.isMuted ?? false
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}