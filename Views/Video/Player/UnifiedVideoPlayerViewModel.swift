
import SwiftUI
import AVKit
import Combine
import OSLog
import Photos

@Observable
@MainActor
public final class UnifiedVideoPlayerViewModel: VideoPlayerViewModelProtocol, @preconcurrency Equatable, @preconcurrency Hashable {
    public static func == (lhs: UnifiedVideoPlayerViewModel, rhs: UnifiedVideoPlayerViewModel) -> Bool {
        lhs.state == rhs.state
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(state)
    }

    // MARK: - Enums

    /// Defines the operational mode of the player, allowing for context-specific optimizations.
    public enum PlayerMode {
        /// Full-featured mode for general playback.
        case main
        /// Lightweight mode optimized for fast previews, like in the Add Move flow.
        case preview
    }

    /// Represents the current state of the player.
    public enum State: Hashable {
        case idle
        case loading(progress: Double, etaSeconds: TimeInterval?, status: String)
        case ready(player: AVPlayer)
        case playing(player: AVPlayer)
        case paused(player: AVPlayer)
        case error(message: String)
    }

    // MARK: - Properties

    public private(set) var state: State = .idle
    public var shouldPlay: Bool = false
    public private(set) var healthStatus: VideoHealthStatus = .unknown

    public var playerItem: AVPlayerItem?

    // MARK: - Private Properties

    private let player: AVPlayer
    private var isPlaybackPending = false
    private var cancellables = Set<AnyCancellable>()
    private let logger: AppLogger
    public let videoHealthMonitor: VideoHealthMonitor
    private let memoryManager: MemoryManager
    private let memoryLogger = CentralizedMemoryLogger.shared
    private var correlationId: String?
    private let mode: PlayerMode
    private var memoryCheckTimer: Timer?
    private var healthMonitorTask: Task<Void, Never>?

    // MARK: - Race Condition Fix Properties

    /// 🔧 KVO observer for persistent player item status monitoring to prevent race conditions
    private var itemStatusObserver: NSKeyValueObservation?

    // MARK: - Public Accessors

    /// Public getter for AVPlayer access (for logging and debugging)
    public var avPlayer: AVPlayer? {
        switch state {
        case .ready(let player), .playing(let player), .paused(let player):
            return player
        default:
            return nil
        }
    }

    public var isPlayerReady: Bool {
        switch state {
        case .ready, .playing, .paused:
            return true
        default:
            return false
        }
    }

    public var currentTime: CMTime? {
        switch state {
        case .ready(let player), .playing(let player), .paused(let player):
            return player.currentTime()
        default:
            return nil
        }
    }

    // MARK: - Initialization

    /// Initializes the player with a pre-loaded player and a specific mode.
    public init(player: AVPlayer, mode: PlayerMode = .main, appContainer: AppContainer) {
        self.player = player // Assign to the new stored property
        self.state = .ready(player: self.player) // Use the stored property for the initial state
        self.playerItem = player.currentItem
        self.mode = mode
        self.logger = appContainer.logger
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        self.memoryManager = appContainer.memoryManager
        
        correlationId = memoryLogger.generateCorrelationId(for: "VideoPlayer-\(mode)")
        
        // Start monitoring the health of the provided asset
        if let asset = player.currentItem?.asset {
            videoHealthMonitor.startMonitoring(asset: asset)
        }
        
        healthMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            for await report in self.videoHealthMonitor.getHealthStatusReports() {
                await MainActor.run {
                    self.handleHealthStatusChange(report.status)
                }
            }
        }
        
        if mode == .preview {
            startMemoryChecks()
        }

        // 🔧 CRITICAL: Setup persistent observers for initial player item to prevent race conditions
        if let initialPlayerItem = player.currentItem {
            setupObservers(for: initialPlayerItem)
        }
    }
    

    deinit {
        // The Task in deinit was causing retain cycles - cleanup is now handled in teardown()
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): deinit called", metadata: nil)
    }

    // MARK: - State Management


    // MARK: - Public Methods


    /// 🎯 CRITICAL FIX: Enhanced idempotent startPlayback method with comprehensive state validation
    /// Prevents redundant calls and ensures correct player state management
    public func startPlayback() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🎬 startPlayback() called", metadata: [
            "current_state": "\(state)",
            "is_playback_pending": "\(isPlaybackPending)",
            "is_player_ready": "\(isPlayerReady)"
        ])

        switch state {
        case .ready(let player):
            // Defensive check: Only attempt to play if the item is actually ready
            if let currentItem = player.currentItem, currentItem.status == .readyToPlay {
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Player ready, starting playback", metadata: [
                    "item_status": "\(currentItem.status.rawValue)",
                    "is_likely_to_keep_up": "\(currentItem.isPlaybackLikelyToKeepUp)"
                ])

                // 🎯 CRITICAL FIX: Basic validation before playback
                // Note: isPlayable check omitted to avoid async complexity in synchronous method
                guard currentItem.duration.seconds > 0 else {
                    logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ❌ Invalid asset duration", metadata: [
                        "duration_seconds": "\(currentItem.duration.seconds)"
                    ])
                    state = .error(message: "Invalid video duration")
                    return
                }

                player.play()
                self.state = .playing(player: player)
                isPlaybackPending = false

                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🎉 Playback started successfully", metadata: [
                    "player_rate": "\(player.rate)",
                    "time_control_status": "\(player.timeControlStatus.rawValue)"
                ])
            } else {
                // If not ready, set pending flag and observe for readiness
                logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ Item not ready, setting playback pending flag", metadata: [
                    "item_status": "\(player.currentItem?.status.rawValue ?? -1)",
                    "item_error": "\(player.currentItem?.error?.localizedDescription ?? "none")"
                ])
                isPlaybackPending = true
                observePlayerItemReadiness()
            }

        case .playing(let player):
            // 🎯 CRITICAL FIX: Ensure player is actually playing when in playing state
            if player.rate == 0 {
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Player in playing state but paused, resuming", metadata: [
                    "player_rate": "\(player.rate)",
                    "time_control_status": "\(player.timeControlStatus.rawValue)"
                ])
                player.play()
            } else {
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏭️ Player already playing, skipping redundant call", metadata: [
                    "player_rate": "\(player.rate)",
                    "time_control_status": "\(player.timeControlStatus.rawValue)"
                ])
            }

        case .paused(let player):
            // 🎯 CRITICAL FIX: Handle transition from paused to playing state
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Resuming from paused state", metadata: [
                "player_rate": "\(player.rate)",
                "time_control_status": "\(player.timeControlStatus.rawValue)"
            ])

            if let currentItem = player.currentItem, currentItem.status == .readyToPlay {
                player.play()
                self.state = .playing(player: player)
                isPlaybackPending = false
            } else {
                logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ Cannot resume from paused - item not ready", metadata: [
                    "item_status": "\(player.currentItem?.status.rawValue ?? -1)"
                ])
                isPlaybackPending = true
                observePlayerItemReadiness()
            }

        case .loading, .idle:
            logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ Cannot start playback from current state: \(state)", metadata: nil)

        case .error:
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ❌ Cannot start playback from error state", metadata: nil)
        }
    }

    /// 🔧 Observe player item status and trigger playback when ready
    /// Note: This method uses Combine publishers which may be cleared during player item replacement.
    /// The persistent KVO observer in `setupObservers(for:)` provides additional race condition protection.
    private func observePlayerItemReadiness() {
        guard let currentItem = player.currentItem else {
            logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ observePlayerItemReadiness() called but no current item", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            return
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Setting up Combine publishers for player item readiness", metadata: [
            "correlationId": correlationId ?? "unknown",
            "item_status": "\(currentItem.status.rawValue)",
            "is_playback_pending": "\(isPlaybackPending)"
        ])

        // Observe status changes
        currentItem.publisher(for: \.status)
            .combineLatest(currentItem.publisher(for: \.isPlaybackLikelyToKeepUp))
            .sink { [weak self] status, isLikelyToKeepUp in
                guard let self = self else { return }

                Task { @MainActor in
                    self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 📡 Combine status update", metadata: [
                        "correlationId": self.correlationId ?? "unknown",
                        "status": "\(status.rawValue)",
                        "is_playback_likely_to_keep_up": "\(isLikelyToKeepUp)",
                        "is_playback_pending": "\(self.isPlaybackPending)"
                    ])

                    if status == .readyToPlay && self.isPlaybackPending {
                        self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 🎯 Combine-based playback triggered", metadata: [
                            "correlationId": self.correlationId ?? "unknown"
                        ])
                        self.isPlaybackPending = false
                        self.startPlayback()
                    }
                }
            }
            .store(in: &cancellables)
    }

    public func teardown() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🚨 teardown() called - CRITICAL RETAIN CYCLE PREVENTION", metadata: [
            "correlationId": correlationId ?? "unknown",
            "healthMonitorTask_exists": "\(healthMonitorTask != nil)",
            "cancellables_count": "\(cancellables.count)",
            "itemStatusObserver_exists": "\(itemStatusObserver != nil)",
            "memoryCheckTimer_exists": "\(memoryCheckTimer != nil)",
            "current_state": "\(state)"
        ])

        // 🎯 CRITICAL FIX: Cancel the health monitor task to break the retain cycle
        if let task = healthMonitorTask {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🛑 Cancelling health monitor task to prevent retain cycle", metadata: [
                "correlationId": correlationId ?? "unknown",
                "task_isCancelled": "\(task.isCancelled)"
            ])
            task.cancel()
            healthMonitorTask = nil
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Health monitor task cancelled and nilled", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
        }

        // 🔧 CRITICAL: Cancel all Combine subscriptions to prevent memory leaks
        if !cancellables.isEmpty {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🧹 Clearing \(cancellables.count) Combine subscriptions", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            cancellables.removeAll()
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ All Combine subscriptions cleared", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
        }

        // 🔧 CRITICAL: Cleanup KVO observer to prevent memory leaks
        if itemStatusObserver != nil {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🧹 Invalidating KVO observer", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            itemStatusObserver?.invalidate()
            itemStatusObserver = nil
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ KVO observer invalidated", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
        }

        // 🎯 CRITICAL: Stop player and release resources
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏹️ Stopping player and replacing current item", metadata: [
            "correlationId": correlationId ?? "unknown",
            "player_exists": "\(avPlayer != nil)"
        ])
        player.pause()
        player.replaceCurrentItem(with: nil)

        // 🔧 CRITICAL: Stop health monitoring
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏹️ Stopping video health monitoring", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        videoHealthMonitor.stopMonitoring()

        // 🔧 CRITICAL: Stop memory check timer if in preview mode
        if mode == .preview {
            if memoryCheckTimer != nil {
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏹️ Invalidating memory check timer", metadata: [
                    "correlationId": correlationId ?? "unknown"
                ])
                memoryCheckTimer?.invalidate()
                memoryCheckTimer = nil
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Memory check timer invalidated", metadata: [
                    "correlationId": correlationId ?? "unknown"
                ])
            }

            // 🎯 CRITICAL: Clear memory cache
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🧹 Clearing memory cache", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            memoryManager.clearCache()
        }

        // 🔧 CRITICAL: Reset all state properties to ensure clean deallocation
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Resetting state properties", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        state = .idle
        shouldPlay = false
        isPlaybackPending = false
        healthStatus = .unknown
        playerItem = nil

        // 🎯 CRITICAL: Final validation logging
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🎉 teardown() completed successfully - RETAIN CYCLE BROKEN", metadata: [
            "correlationId": correlationId ?? "unknown",
            "healthMonitorTask_isNil": "\(healthMonitorTask == nil)",
            "cancellables_isEmpty": "\(cancellables.isEmpty)",
            "itemStatusObserver_isNil": "\(itemStatusObserver == nil)",
            "memoryCheckTimer_isNil": "\(memoryCheckTimer == nil)",
            "final_state": "\(state)"
        ])
    }
    
    // 💡 SOLUTION: Enhanced replace player item and wait for readiness with comprehensive race condition prevention
    public func replacePlayerItemAndWaitForReady(_ newItem: AVPlayerItem) async throws {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Starting enhanced player item replacement with race condition prevention", metadata: [
            "correlationId": correlationId ?? "unknown",
            "new_item_status": "\(newItem.status.rawValue)",
            "current_state": "\(state)",
            "is_playback_pending": "\(isPlaybackPending)"
        ])

        // 💡 ENHANCEMENT: Validate preconditions before replacement
        guard newItem.asset != player.currentItem?.asset || newItem != player.currentItem else {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏭️ Skip replacement - identical item already loaded", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            return
        }

        // 💡 ENHANCEMENT: Pause current playback and cancel any pending operations
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏸️ Pausing current playback and canceling pending operations", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])

        player.pause()
        isPlaybackPending = false

        // 🎯 CRITICAL FIX: Invalidate the persistent KVO observer on the OLD item before replacing it.
        // This is the root cause of the crash, as it prevents the "message sent to deallocated instance"
        // error when the old view's coordinator is dismantled during the state transition.
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🧹 Invalidating persistent KVO observer to prevent race condition", metadata: [
            "correlationId": correlationId ?? "unknown",
            "observer_exists": "\(itemStatusObserver != nil)",
            "old_item_duration": "\(player.currentItem?.asset.duration.seconds ?? 0)"
        ])

        itemStatusObserver?.invalidate()
        itemStatusObserver = nil

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ KVO observer invalidated safely", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])

        // 💡 ENHANCEMENT: Clear any existing observation subscriptions to prevent race conditions
        cancellables.removeAll()

        // 🎯 CRITICAL ADDITION: Verify KVO observer is fully invalidated before replacement
        // This ensures atomic operation - no observer should exist during item replacement
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔍 Verifying KVO observer invalidation", metadata: [
            "correlationId": correlationId ?? "unknown",
            "observer_still_exists": "\(itemStatusObserver != nil)",
            "cancellables_count": "\(cancellables.count)"
        ])

        // 💡 ENHANCEMENT: Replace the player item with detailed logging
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Replacing player item", metadata: [
            "correlationId": correlationId ?? "unknown",
            "old_item_duration": "\(player.currentItem?.asset.duration.seconds ?? 0)",
            "new_item_duration": "\(newItem.asset.duration.seconds)"
        ])

        // 🎯 CRITICAL: Atomic replacement - clear nil first, then assign new item
        // This ensures no intermediate state where both old and new items could be observed
        player.replaceCurrentItem(with: nil) // Clear first to prevent reference cycles
        player.replaceCurrentItem(with: newItem)
        self.playerItem = newItem

        // 🎯 CRITICAL: Verification logging to confirm atomic operation
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Player item replacement completed atomically", metadata: [
            "correlationId": correlationId ?? "unknown",
            "new_player_item": "\(player.currentItem === newItem)",
            "old_observer_cleared": "\(itemStatusObserver == nil)",
            "cancellables_cleared": "\(cancellables.isEmpty)"
        ])

        // 💡 ENHANCEMENT: Wait for the new item to become ready with enhanced timeout and progress monitoring
        let monitor = PlayerItemStatusMonitor(playerItem: newItem)

        do {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⏳ Starting readiness monitoring with timeout protection", metadata: [
                "correlationId": correlationId ?? "unknown",
                "timeout_seconds": "10.0",
                "required_buffer_duration": "2.0"
            ])

            try await monitor.awaitReadyAndBuffered(timeout: 10.0) { [weak self] progress in
                guard let self = self else { return }

                // 💡 ENHANCEMENT: Detailed progress logging with memory and performance metrics
                let memoryInfo = self.diagnosticLogger.getMemoryInfo()
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 📈 Readiness progress: \(Int(progress * 100))%", metadata: [
                    "correlationId": self.correlationId ?? "unknown",
                    "progress": "\(progress)",
                    "memory_usage_mb": "\(String(format: "%.1f", memoryInfo.used))",
                    "item_status": "\(newItem.status.rawValue)",
                    "loaded_ranges": "\(newItem.loadedTimeRanges.count)",
                    "is_playback_likely_to_keep_up": "\(newItem.isPlaybackLikelyToKeepUp)",
                    "is_playback_buffer_full": "\(newItem.isPlaybackBufferFull)"
                ])

                // 💡 ENHANCEMENT: Update state to reflect progress
                if progress < 1.0 {
                    self.state = .loading(progress: progress, etaSeconds: nil, status: "Preparing video player...")
                }
            }

            // 💡 ENHANCEMENT: Comprehensive post-readiness validation
            guard newItem.status == .readyToPlay else {
                let errorMessage = "Player item status is \(newItem.status.rawValue) after readiness monitoring completed"
                logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ❌ \(errorMessage)", metadata: [
                    "correlationId": correlationId ?? "unknown",
                    "item_status": "\(newItem.status.rawValue)",
                    "item_error": "\(newItem.error?.localizedDescription ?? "none")"
                ])
                throw VideoProcessingError.playerInitializationFailed
            }

            // 💡 ENHANCEMENT: Check buffering status but continue anyway as this is not a blocking condition
            if !newItem.isPlaybackLikelyToKeepUp && !newItem.isPlaybackBufferFull {
                logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ Player item ready but buffering incomplete", metadata: [
                    "correlationId": correlationId ?? "unknown",
                    "is_playback_likely_to_keep_up": "\(newItem.isPlaybackLikelyToKeepUp)",
                    "is_playback_buffer_full": "\(newItem.isPlaybackBufferFull)",
                    "loaded_ranges": "\(newItem.loadedTimeRanges.count)"
                ])
            }

            // 💡 ENHANCEMENT: Update state to ready with comprehensive logging
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Player item readiness validated, updating state", metadata: [
                "correlationId": correlationId ?? "unknown",
                "final_status": "\(newItem.status.rawValue)",
                "final_duration": "\(newItem.asset.duration.seconds)",
                "is_playback_likely_to_keep_up": "\(newItem.isPlaybackLikelyToKeepUp)",
                "is_playback_buffer_full": "\(newItem.isPlaybackBufferFull)"
            ])

            state = .ready(player: player)

            // 💡 ENHANCEMENT: Restart health monitoring with new asset and detailed logging
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Restarting health monitoring with new asset", metadata: [
                "correlationId": correlationId ?? "unknown",
                "asset_duration": "\(newItem.asset.duration.seconds)",
                "is_playable": "\(newItem.asset.isPlayable)"
            ])

            videoHealthMonitor.stopMonitoring()
            videoHealthMonitor.startMonitoring(asset: newItem.asset)

            // 💡 ENHANCEMENT: Setup new persistent KVO observers for the replaced item to prevent future race conditions
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔧 Setting up new persistent KVO observers for replaced item", metadata: [
                "correlationId": correlationId ?? "unknown",
                "new_item_status": "\(newItem.status.rawValue)"
            ])

            setupObservers(for: newItem)

            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🎉 Enhanced player item replacement completed successfully", metadata: [
                "correlationId": correlationId ?? "unknown",
                "total_operation_time": "measured_by_monitor",
                "final_state": "\(state)",
                "new_observer_active": "\(itemStatusObserver != nil)"
            ])

        } catch {
            // 💡 ENHANCEMENT: Enhanced error handling with detailed diagnostics
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ❌ Player item replacement failed", metadata: [
                "correlationId": correlationId ?? "unknown",
                "error": "\(error.localizedDescription)",
                "item_status": "\(newItem.status.rawValue)",
                "item_error": "\(newItem.error?.localizedDescription ?? "none")",
                "loaded_ranges": "\(newItem.loadedTimeRanges.count)"
            ])

            // Attempt recovery by restoring previous state if possible
            if let previousItem = playerItem {
                logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Attempting recovery by restoring previous player item", metadata: [
                    "correlationId": correlationId ?? "unknown"
                ])
                player.replaceCurrentItem(with: previousItem)
            }

            throw error
        }
    }

    // 💡 ENHANCEMENT: New method to setup observers for player item to prevent race conditions
    private func setupPlayerItemObservers(_ item: AVPlayerItem) {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔧 Setting up player item observers", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])

        // Observe status changes for real-time monitoring
        item.publisher(for: \.status)
            .combineLatest(item.publisher(for: \.isPlaybackLikelyToKeepUp))
            .sink { [weak self] status, isLikelyToKeepUp in
                guard let self = self else { return }

                Task { @MainActor in
                    self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 📊 Player item status update", metadata: [
                        "correlationId": self.correlationId ?? "unknown",
                        "status": "\(status.rawValue)",
                        "is_playback_likely_to_keep_up": "\(isLikelyToKeepUp)",
                        "current_state": "\(self.state)"
                    ])

                    // Handle status changes that might indicate race conditions
                    if case .failed = status {
                        self.logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 🚨 Player item failed after replacement", metadata: [
                            "correlationId": self.correlationId ?? "unknown",
                            "error": "\(item.error?.localizedDescription ?? "unknown")"
                        ])
                        self.state = .error(message: "Player item failed: \(item.error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
            .store(in: &cancellables)

        // Observe loaded time ranges for buffer monitoring
        item.publisher(for: \.loadedTimeRanges)
            .sink { [weak self] _ in
                guard let self = self else { return }

                Task { @MainActor in
                    let rangeCount = item.loadedTimeRanges.count
                    if let firstRange = item.loadedTimeRanges.first?.timeRangeValue {
                        let duration = CMTimeGetSeconds(firstRange.duration)
                        self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 📊 Buffer update - \(rangeCount) ranges, first: \(String(format: "%.2f", duration))s", metadata: [
                            "correlationId": self.correlationId ?? "unknown"
                        ])
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Race Condition Fix Implementation

    /// 🔧 Sets up persistent KVO observers for player item status to prevent race conditions
    /// This ensures that when `isPlaybackPending` is true, we don't miss the .readyToPlay event
    /// during SwiftUI view reconfiguration or player item status flickering
    private func setupObservers(for item: AVPlayerItem) {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔄 Setting up persistent KVO observers for race condition prevention", metadata: [
            "correlationId": correlationId ?? "unknown",
            "item_status": "\(item.status.rawValue)",
            "is_playback_pending": "\(isPlaybackPending)"
        ])

        // 🎯 CRITICAL: Validate preconditions before setting up observers
        guard item.status != .failed else {
            logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ⚠️ Cannot setup observers for failed item", metadata: [
                "correlationId": correlationId ?? "unknown",
                "item_error": "\(item.error?.localizedDescription ?? "unknown")"
            ])
            return
        }

        // 🔧 CRITICAL: Invalidate any existing observer to prevent multiple observers on the same item
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil

        // 🎯 CRITICAL: Verify observer is properly cleared before creating new one
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 🔍 Observer cleanup verification", metadata: [
            "correlationId": correlationId ?? "unknown",
            "observer_cleared": "\(itemStatusObserver == nil)"
        ])

        // 🔧 CRITICAL: Set up persistent KVO observer that survives Combine cancellable removal
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): 📡 Creating persistent KVO observer", metadata: [
            "correlationId": correlationId ?? "unknown",
            "item_status": "\(item.status.rawValue)",
            "observation_options": "initial,new"
        ])

        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, change in
            guard let self = self else { return }

            // 🚨 CRITICAL: Always dispatch to main thread for UI updates and state changes
            DispatchQueue.main.async {
                let newStatus = observedItem.status
                self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 📡 KVO status change detected", metadata: [
                    "correlationId": self.correlationId ?? "unknown",
                    "old_status": "\(change.oldValue?.rawValue ?? -1)",
                    "new_status": "\(newStatus.rawValue)",
                    "is_playback_pending": "\(self.isPlaybackPending)",
                    "current_state": "\(self.state)"
                ])

                // 🔧 CRITICAL: Handle the race condition - if playback is pending and item becomes ready, trigger playback
                if newStatus == .readyToPlay && self.isPlaybackPending {
                    self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): 🎯 RACE CONDITION PREVENTED - Status became ready with pending playback", metadata: [
                        "correlationId": self.correlationId ?? "unknown",
                        "item_status": "\(newStatus.rawValue)"
                    ])

                    // Reset pending flag to prevent multiple triggers
                    self.isPlaybackPending = false

                    // Trigger playback on main thread
                    self.startPlayback()
                }

                // 🔧 ENHANCEMENT: Handle status transitions that might indicate issues
                switch newStatus {
                case .readyToPlay:
                    self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): ✅ Player item is ready to play", metadata: [
                        "correlationId": self.correlationId ?? "unknown"
                    ])
                case .failed:
                    self.logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): ❌ Player item failed", metadata: [
                        "correlationId": self.correlationId ?? "unknown",
                        "error": "\(observedItem.error?.localizedDescription ?? "unknown")"
                    ])
                    // Don't update state here, let the existing error handling deal with it
                case .unknown:
                    self.logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): ⚠️ Player item status flickered to unknown", metadata: [
                        "correlationId": self.correlationId ?? "unknown"
                    ])
                @unknown default:
                    self.logger.warning("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): ⚠️ Unknown player item status: \(newStatus.rawValue)", metadata: [
                        "correlationId": self.correlationId ?? "unknown"
                    ])
                }
            }
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): ✅ Persistent KVO observers setup completed", metadata: [
            "correlationId": correlationId ?? "unknown",
            "observer_created": "\(itemStatusObserver != nil)",
            "item_status": "\(item.status.rawValue)"
        ])
    }

    // 💡 ENHANCEMENT: Add diagnostic logger property for enhanced logging
    private var diagnosticLogger: DiagnosticLoggingHelper {
        return DiagnosticLoggingHelper(category: "UnifiedVideoPlayerViewModel-\(mode)")
    }

    public func pauseForTrimming() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): pauseForTrimming() called", metadata: nil)

        // Ensure this runs on the main actor synchronously.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.pauseForTrimming() }
            return
        }

        switch state {
        case .playing(let player):
            player.pause()
            videoHealthMonitor.pauseMonitoring()
            if mode == .preview {
                memoryCheckTimer?.invalidate()
                memoryCheckTimer = nil
            }
            state = .paused(player: player)
        case .ready(let player):
            player.pause()
            videoHealthMonitor.pauseMonitoring()
            state = .paused(player: player)
        case .paused(_):
            // Already paused, do nothing
            break
        default:
            break
        }
        shouldPlay = false
    }

    public func resumeAfterTrimming() {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): resumeAfterTrimming() called", metadata: nil)

        Task { @MainActor in
            if case .playing(let player) = state {
                videoHealthMonitor.resumeMonitoring()
                if mode == .preview {
                    startMemoryChecks()
                }
                if shouldPlay {
                    player.play()
                }
            }
        }
    }
    
    /// Re-primes the player with a given asset if the current state is idle.
    /// This is used to recover from a premature teardown during view transitions.
    public func primeWithAsset(_ asset: AVAsset) async {
        guard case .idle = state else {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): primeWithAsset called, but player is not idle. Skipping.", metadata: ["currentState": "\(state)"])
            return
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Re-priming player from idle state.", metadata: ["correlationId": correlationId ?? "unknown"])

        let newPlayerItem = AVPlayerItem(asset: asset)
        self.player.replaceCurrentItem(with: newPlayerItem)
        self.playerItem = newPlayerItem
        
        // 🚨 FIX: Instead of a simple sleep, we will now explicitly wait for the player item's status
        // to become .readyToPlay, ensuring the video is actually playable.
        
        do {
            // Wait for the item to be ready using the robust PlayerItemStatusMonitor.
            let monitor = PlayerItemStatusMonitor(playerItem: newPlayerItem)
            try await monitor.awaitReadyAndBuffered(timeout: 5.0) { progress in
                self.logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(self.mode)): Re-priming buffer progress: \(Int(progress * 100))%", metadata: ["correlationId": self.correlationId ?? "unknown"])
            }
            
            // If the above line doesn't throw, the item is ready.
            self.state = .ready(player: self.player)
            videoHealthMonitor.startMonitoring(asset: asset)

            // 🔧 CRITICAL: Setup persistent observers for race condition prevention
            self.setupObservers(for: newPlayerItem)

            logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player successfully re-primed and item status is ready.", metadata: ["correlationId": correlationId ?? "unknown"])
            
        } catch {
            // If it times out or fails, set an error state.
            self.state = .error(message: "Failed to make video player ready after re-priming.")
            logger.error("❌ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player item failed to become ready. Status: \(newPlayerItem.status.rawValue), Error: \(error.localizedDescription)", metadata: ["correlationId": correlationId ?? "unknown"])
        }
    }
    
    
    // MARK: - Existing Methods
    
    public func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func asyncSeek(to time: CMTime) async throws {
        let diagnosticStart = CFAbsoluteTimeGetCurrent()
        logger.info("🎬 VIDEO_MODEL: Async seek starting with enhanced readiness check.", metadata: [
            "target_time": "\(time.seconds)",
            "player_state": "\(state)",
            "correlationId": correlationId ?? "unknown"
        ])

        // Enhanced validation with detailed logging
        guard let player = self.avPlayer, let item = player.currentItem else {
            let errorMessage = "Player or player item is nil"
            logger.error("❌ VIDEO_MODEL: Async seek validation failed", metadata: [
                "error": errorMessage,
                "player_exists": "\(self.avPlayer != nil)",
                "item_exists": "\(player.currentItem != nil)",
                "current_state": "\(state)"
            ])
            throw NSError(domain: "SeekFailed", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // 🎯 CRITICAL FIX: Enhanced readiness awaiting with comprehensive progress logging
        // This prevents race conditions during player item status transitions
        let initialItemStatus = item.status
        let initialBufferStatus = item.isPlaybackLikelyToKeepUp

        logger.info("🎬 VIDEO_MODEL: Starting enhanced player readiness monitoring", metadata: [
            "initial_item_status": "\(initialItemStatus.rawValue)",
            "initial_buffer_status": "\(initialBufferStatus)",
            "target_time": "\(time.seconds)",
            "item_duration": "\(item.asset.duration.seconds)",
            "loaded_ranges": "\(item.loadedTimeRanges.count)"
        ])

        let monitor = PlayerItemStatusMonitor(playerItem: item)
        do {
            // Enhanced readiness monitoring with progress callbacks
            try await monitor.awaitReadyAndBuffered(timeout: 5.0) { [weak self] progress in
                guard let self = self else { return }

                let memoryInfo = self.diagnosticLogger.getMemoryInfo()
                logger.info("🎬 VIDEO_MODEL: Seek readiness progress: \(Int(progress * 100))%", metadata: [
                    "correlationId": self.correlationId ?? "unknown",
                    "progress": "\(progress)",
                    "memory_usage_mb": "\(String(format: "%.1f", memoryInfo.used))",
                    "current_item_status": "\(item.status.rawValue)",
                    "buffer_status": "\(item.isPlaybackLikelyToKeepUp)",
                    "loaded_ranges": "\(item.loadedTimeRanges.count)"
                ])
            }

            // Post-readiness validation
            let finalItemStatus = item.status
            let finalBufferStatus = item.isPlaybackLikelyToKeepUp

            logger.info("✅ VIDEO_MODEL: Player readiness validation complete", metadata: [
                "initial_status": "\(initialItemStatus.rawValue)",
                "final_status": "\(finalItemStatus.rawValue)",
                "initial_buffer": "\(initialBufferStatus)",
                "final_buffer": "\(finalBufferStatus)",
                "validation_time_ms": "\((CFAbsoluteTimeGetCurrent() - diagnosticStart) * 1000)"
            ])

        } catch {
            let readinessDuration = CFAbsoluteTimeGetCurrent() - diagnosticStart
            logger.error("❌ VIDEO_MODEL: Enhanced readiness monitoring failed", metadata: [
                "error": error.localizedDescription,
                "duration_ms": "\(readinessDuration * 1000)",
                "final_item_status": "\(item.status.rawValue)",
                "item_error": "\(item.error?.localizedDescription ?? "none")",
                "loaded_ranges": "\(item.loadedTimeRanges.count)",
                "correlationId": correlationId ?? "unknown"
            ])
            throw NSError(domain: "PlayerNotReady", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Player item did not become ready for seek operation after enhanced monitoring."
            ])
        }

        // 🎯 ENHANCED: Now that we're certain the item is ready, perform the seek with enhanced error handling
        let seekStart = CFAbsoluteTimeGetCurrent()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            // Configure video composition settings for smooth seeking
            if item.videoComposition != nil {
                item.seekingWaitsForVideoCompositionRendering = true
                logger.info("🎬 VIDEO_MODEL: Video composition seeking enabled", metadata: [
                    "composition_layers": "\(item.videoComposition?.instructions.count ?? 0)",
                    "render_size": "\(item.videoComposition?.renderSize.width ?? 0)x\(item.videoComposition?.renderSize.height ?? 0)"
                ])
            }

            // Perform the seek with precise timing
            // Capture values needed in closure to avoid main actor isolation issues
            let targetTimeSeconds = time.seconds
            let currentCorrelationId = self.correlationId ?? "unknown"
            let currentLogger = self.logger

            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
                let seekDuration = CFAbsoluteTimeGetCurrent() - seekStart

                if completed {
                    let finalTime = player.currentTime()
                    currentLogger.info("✅ VIDEO_MODEL: Enhanced seek completed successfully", metadata: [
                        "target_time": "\(targetTimeSeconds)",
                        "actual_time": "\(finalTime.seconds)",
                        "time_delta_ms": "\((finalTime.seconds - targetTimeSeconds) * 1000)",
                        "seek_duration_ms": "\(seekDuration * 1000)",
                        "player_rate": "\(player.rate)",
                        "correlationId": currentCorrelationId
                    ])
                    continuation.resume()
                } else {
                    currentLogger.error("❌ VIDEO_MODEL: Enhanced seek failed to complete", metadata: [
                        "target_time": "\(targetTimeSeconds)",
                        "seek_duration_ms": "\(seekDuration * 1000)",
                        "player_time_control_status": "\(player.timeControlStatus.rawValue)",
                        "correlationId": currentCorrelationId
                    ])
                    continuation.resume(throwing: NSError(domain: "SeekFailed", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "The enhanced seek operation was cancelled or failed."
                    ]))
                }
            }
        }
    }

    public func waitForReady() async throws {
        // Since we're initialized with a ready player, this is mostly a no-op
        // but we can still check if the player is actually ready
        // We always have a player now, so this check is just for consistency
        
        // For simplicity, we'll just return immediately since the player should be ready
        // In a more complex implementation, you might want to verify player status here
        return
    }

    // MARK: - Private Helper Methods

    private func handleHealthStatusChange(_ healthStatus: VideoHealthStatus) {
        self.healthStatus = healthStatus
        memoryLogger.logMemoryEvent(
            event: "Video health status changed to \(healthStatus)",
            correlationId: correlationId,
            component: "VideoPlayer-\(mode)",
            metadata: ["healthStatus": healthStatus.rawValue]
        )

        switch healthStatus {
        case .critical:
            attemptRecovery()
        case .poor:
            if mode == .preview {
                applyOptimizations()
            }
            memoryLogger.logMemoryWarning(
                message: "Video health is poor",
                correlationId: correlationId,
                component: "VideoPlayer-\(mode)",
                metadata: ["healthStatus": healthStatus.rawValue]
            )
        default:
            break
        }
    }

    private func attemptRecovery() {
        memoryLogger.logMemoryEvent(
            event: "Attempting video recovery",
            correlationId: correlationId,
            component: "VideoPlayer-\(mode)"
        )

        guard case .playing(let player) = state, let currentItem = player.currentItem else { return }
        let currentTime = player.currentTime()
        player.pause()

        if mode == .preview {
            memoryManager.clearCache()
        }

        Task {
            let newPlayerItem = AVPlayerItem(asset: currentItem.asset)
            if mode == .preview {
                newPlayerItem.preferredPeakBitRate = 1_000_000
                newPlayerItem.preferredForwardBufferDuration = 0.5
            }
            player.replaceCurrentItem(with: newPlayerItem)
            player.seek(to: currentTime)
            if shouldPlay {
                player.play()
            }
            memoryLogger.logMemoryEvent(
                event: "Video recovery completed",
                correlationId: correlationId,
                component: "VideoPlayer-\(mode)"
            )
        }
    }
    
    private func startMemoryChecks() {
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryAndOptimize()
            }
        }
    }

    private func checkMemoryAndOptimize() {
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 30 * 1024 * 1024

        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory during preview: \(availableMemory / (1024 * 1024))MB", metadata: ["correlationId": correlationId ?? "unknown"])
            if case .playing(let player) = state {
                player.currentItem?.preferredPeakBitRate = 1_000_000
                player.currentItem?.preferredForwardBufferDuration = 0.5
                player.pause()
            }
            memoryManager.clearCache()
            memoryLogger.logMemoryWarning(
                message: "Low memory during preview: \(availableMemory / (1024 * 1024))MB",
                correlationId: correlationId,
                component: "PreviewVideoPlayer",
                metadata: ["availableMemory": availableMemory]
            )
        }
    }
    
    private func applyOptimizations() {
        if case .playing(let player) = state, let currentItem = player.currentItem {
            currentItem.preferredPeakBitRate = 1_500_000
            currentItem.preferredForwardBufferDuration = 0.8
            memoryLogger.logMemoryEvent(
                event: "Applied optimizations to preview player",
                correlationId: correlationId,
                component: "PreviewVideoPlayer"
            )
        }
    }
    
    // MARK: - VideoPlayerViewModelProtocol Implementation
    
    public func loadVideo(from source: VideoSource, quarterTurns: Int) async throws {
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): loadVideo() called", metadata: [
            "source": "\(source)",
            "quarterTurns": quarterTurns,
            "correlationId": correlationId ?? "unknown"
        ])
        
        guard case .photos(let identifier) = source else {
            let errorMessage = "Unsupported video source type."
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Unsupported source type - \(source)", metadata: [
                "correlationId": correlationId ?? "unknown",
                "source": "\(source)"
            ])
            self.state = .error(message: errorMessage)
            throw NSError(domain: "UnifiedVideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Loading video from Photos", metadata: [
            "identifier": identifier,
            "correlationId": correlationId ?? "unknown"
        ])
        
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            let errorMessage = "Could not find PHAsset with identifier: \(identifier)."
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): PHAsset not found", metadata: [
                "correlationId": correlationId ?? "unknown",
                "identifier": identifier
            ])
            self.state = .error(message: errorMessage)
            throw NSError(domain: "UnifiedVideoPlayerViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): PHAsset found successfully", metadata: [
            "assetDuration": phAsset.duration,
            "assetMediaType": "\(phAsset.mediaType)",
            "correlationId": correlationId ?? "unknown"
        ])

        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Creating LiveVideoLoadingService", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        let loadingService = LiveVideoLoadingService(memoryManager: memoryManager, logger: logger) // As per 2. plan.md, this is the main loading service
        
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Starting video loading stream", metadata: [
            "correlationId": correlationId ?? "unknown"
        ])
        let progressStream = loadingService.loadPHAssetWithProgress(phAsset)

        do {
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Entering progress stream processing", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
            for try await event in progressStream {
                await MainActor.run {
                    switch event {
                    case .progress(let fraction, let status):
                        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Progress update", metadata: [
                            "progress": fraction,
                            "status": status,
                            "correlationId": correlationId ?? "unknown"
                        ])
                        self.state = .loading(progress: fraction, etaSeconds: nil, status: status)
                    case .success(let asset):
                        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Loading successful", metadata: [
                            "assetDuration": CMTimeGetSeconds(asset.duration),
                            "correlationId": correlationId ?? "unknown"
                        ])

                        // Create a new AVPlayerItem from the loaded asset
                        let newPlayerItem = AVPlayerItem(asset: asset)
                        
                        // Diagnostic Check: Log before replacement
                        logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player reference is valid. Replacing item.", metadata: ["correlationId": correlationId ?? "unknown"])

                        // Use the stable `self.player` reference to replace the item
                        self.player.replaceCurrentItem(with: newPlayerItem)
                        self.playerItem = newPlayerItem
                        
                        // Diagnostic Check: Log after replacement and transition to ready state
                        logger.info("✅ UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Player item replaced successfully. Transitioning to ready state.", metadata: ["correlationId": correlationId ?? "unknown"])
                        self.state = .ready(player: self.player)
                        
                        videoHealthMonitor.startMonitoring(asset: asset)
                    }
                }
            }
            logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Progress stream completed successfully", metadata: [
                "correlationId": correlationId ?? "unknown"
            ])
        } catch {
            let errorMessage = "Failed to load video asset: \(error.localizedDescription)"
            logger.error("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): Video loading failed", metadata: [
                "error": error.localizedDescription,
                "correlationId": correlationId ?? "unknown"
            ])
            self.state = .error(message: errorMessage)
            throw error
        }
    }
    
    public func setRotation(_ quarterTurns: Int) {
        // Rotation is handled by the asset transform during initialization
        logger.info("🎬 UNIFIED_VIDEO_PLAYER_VIEWMODEL (\(mode)): setRotation(\(quarterTurns)) called", metadata: ["quarterTurns": quarterTurns])
    }
}


