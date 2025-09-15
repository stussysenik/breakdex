//
//  PlayerItemStatusMonitor.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 9/15/25.
//

import Foundation
import Combine
import AVFoundation
import OSLog

/// Monitors AVPlayerItem status changes with atomic operations to prevent race conditions
/// Used for Phase 2 progress tracking (70-90%) in the video loading pipeline
@MainActor
public class PlayerItemStatusMonitor {
    
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "PlayerItemStatusMonitor")
    
    /// Simple logging for debugging
    private func log(_ message: String) {
        print("🎬 \(message)")
    }
    
    public enum MonitorError: Error, LocalizedError {
        case playerItemNotReady
        case timeoutExceeded
        case playerItemFailed(Error?)
        case observationCancelled
        case invalidPlayerItem
        
        public var errorDescription: String? {
            switch self {
            case .playerItemNotReady:
                return "Player item is not ready"
            case .timeoutExceeded:
                return "Player item readiness monitoring timed out"
            case .playerItemFailed(let error):
                return "Player item failed: \(error?.localizedDescription ?? "Unknown error")"
            case .observationCancelled:
                return "Player item observation was cancelled"
            case .invalidPlayerItem:
                return "Invalid player item provided"
            }
        }
    }
    
    // MARK: - Observer tokens
    private var kvoObservers: [NSKeyValueObservation] = []
    private var timeoutTask: Task<Void, Never>?
    private var currentPlayerItem: AVPlayerItem?
    private var continuation: CheckedContinuation<Void, Error>?
    private var isMonitoring = false
    
    private let playerItem: AVPlayerItem
    
    /// Initialize monitor with a player item
    /// - Parameter playerItem: The AVPlayerItem to monitor
    public init(playerItem: AVPlayerItem) {
        self.playerItem = playerItem
        log("🎬 PLAYER_ITEM_MONITOR: Initialized for playerItem: \(playerItem)")
    }
    
    /// Wait for player item to reach ready state with atomic continuation management
    /// - Parameter timeout: Maximum time to wait in seconds
    public func waitForReadyToPlay(timeout: TimeInterval = 30.0) async throws {
        log("🎬 PLAYER_ITEM_MONITOR: waitForReadyToPlay called with timeout: \(timeout)s")
        
        // Validate player item
        guard playerItem.status != .failed else {
            throw MonitorError.playerItemFailed(playerItem.error)
        }
        
        // If player item is already ready, return immediately
        if isPlayerItemReady() {
            log("✅ PLAYER_ITEM_MONITOR: Player item already ready, returning immediately")
            return
        }
        
        log("⏳ PLAYER_ITEM_MONITOR: Player item not ready, setting up monitoring")
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            // Set up state monitoring
            start(timeout: timeout)
        }
    }
    
    /// Start monitoring the player item state
    /// - Parameter timeout: Maximum time to wait in seconds
    private func start(timeout: TimeInterval) {
        log("🔀 PLAYER_ITEM_MONITOR: start() called for playerItem: \(playerItem)")
        
        // Only stop if we're already monitoring
        if isMonitoring {
            stop()
        }
        
        // Store the current player item for cleanup
        currentPlayerItem = playerItem
        isMonitoring = true
        
        // Monitor player item status using KVO
        let itemStatusKVO = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handlePlayerItemStatusChange()
            }
        }
        kvoObservers.append(itemStatusKVO)
        
        // Monitor loaded time ranges for buffering progress
        let loadedTimeRangesKVO = playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handleLoadedTimeRangesChange()
            }
        }
        kvoObservers.append(loadedTimeRangesKVO)
        
        // Monitor playback buffer full status
        let playbackBufferFullKVO = playerItem.observe(\.isPlaybackBufferFull, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handlePlaybackBufferFullChange()
            }
        }
        kvoObservers.append(playbackBufferFullKVO)
        
        // Monitor playback likely to keep up
        let playbackLikelyToKeepUpKVO = playerItem.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handlePlaybackLikelyToKeepUpChange()
            }
        }
        kvoObservers.append(playbackLikelyToKeepUpKVO)
        
        // Set up timeout task
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                
                // Only timeout if still monitoring
                if self?.isMonitoring == true {
                    self?.continuation?.resume(throwing: MonitorError.timeoutExceeded)
                    self?.stop()
                }
            } catch {
                // Task was cancelled, monitoring must have completed
            }
        }
        
        // Check initial state one more time
        if isPlayerItemReady() {
            continuation?.resume()
            stop()
        }
    }
    
    /// Stop all monitoring and clean up resources
    public func stop() {
        log("⚡ PLAYER_ITEM_MONITOR: Cleaning up monitoring resources...")
        
        // Cancel and remove all KVO observers
        kvoObservers.removeAll()
        
        // Cancel timeout task
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Clear continuation - ensure it's resumed or thrown before clearing
        if let continuation = continuation {
            log("⚠️ PLAYER_ITEM_MONITOR: Clearing unfinished continuation")
            // Don't just nil it out - ensure it's properly completed
            continuation.resume(throwing: MonitorError.observationCancelled)
        }
        continuation = nil
        
        // Clear current player item reference
        currentPlayerItem = nil
        
        isMonitoring = false
        
        log("✅ PLAYER_ITEM_MONITOR: Monitoring completed")
    }
    
    /// Cancel all ongoing monitoring (legacy method for backward compatibility)
    public func cancelMonitoring() {
        stop()
    }
    
    // MARK: - Private Methods
    
    private func isPlayerItemReady() -> Bool {
        return playerItem.status == .readyToPlay
    }
    
    private func handlePlayerItemStatusChange() {
        log("🔄 PLAYER_ITEM_MONITOR: Status update → \(getStatusDescription(playerItem.status))")
        
        guard isMonitoring else { 
            log("✅ PLAYER_ITEM_MONITOR: Status change ignored - monitoring already completed")
            return 
        }
        
        switch playerItem.status {
        case .readyToPlay:
            log("✅ PLAYER_ITEM_MONITOR: PlayerItem ready, checking if can resume")
            checkAndResumeIfReady()
        case .failed:
            log("❌ PLAYER_ITEM_MONITOR: PlayerItem failed with error: \(playerItem.error?.localizedDescription ?? "Unknown")")
            continuation?.resume(throwing: MonitorError.playerItemFailed(playerItem.error))
            cancelMonitoring()
        case .unknown:
            log("📊 PLAYER_ITEM_MONITOR: PlayerItem status unknown - still loading, waiting...")
            break
        @unknown default:
            log("⚠️ PLAYER_ITEM_MONITOR: Unknown playerItem status: \(String(describing: playerItem.status))")
            break
        }
    }
    
    private func handleLoadedTimeRangesChange() {
        let loadedRanges = playerItem.loadedTimeRanges
        if let firstRange = loadedRanges.first {
            let range = firstRange.timeRangeValue
            let duration = range.duration
            log("📊 PLAYER_ITEM_MONITOR: Loaded time range: \(duration.seconds)s")
        }
    }
    
    private func handlePlaybackBufferFullChange() {
        if playerItem.isPlaybackBufferFull {
            log("📊 PLAYER_ITEM_MONITOR: Playback buffer full")
            checkAndResumeIfReady()
        }
    }
    
    private func handlePlaybackLikelyToKeepUpChange() {
        if playerItem.isPlaybackLikelyToKeepUp {
            log("📊 PLAYER_ITEM_MONITOR: Playback likely to keep up")
            checkAndResumeIfReady()
        }
    }
    
    private func checkAndResumeIfReady() {
        guard isMonitoring else {
            log("⚠️ PLAYER_ITEM_MONITOR: Already completed, ignoring check")
            return
        }
        
        if isPlayerItemReady() {
            log("🎉 PLAYER_ITEM_MONITOR: PlayerItem ready, resuming continuation")
            // Resume continuation FIRST, then clean up
            continuation?.resume()
            log("🎉 PLAYER_ITEM_MONITOR: Continuation resumed successfully")
            stop()
        } else {
            log("⏳ PLAYER_ITEM_MONITOR: PlayerItem not ready yet - status: \(String(describing: playerItem.status)), bufferFull: \(playerItem.isPlaybackBufferFull), likelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
        }
    }
    
    /// Helper function to get descriptive status messages
    private func getStatusDescription(_ status: AVPlayerItem.Status) -> String {
        switch status {
        case .unknown:
            return "🔄 Loading video data..."
        case .readyToPlay:
            return "✅ Ready for playback!"
        case .failed:
            return "❌ Playback failed"
        @unknown default:
            return "⚠️ Unknown status"
        }
    }
    
    deinit {
        // Clean up synchronously to avoid retain cycles
        kvoObservers.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation = nil
        currentPlayerItem = nil
        isMonitoring = false
    }
}