
import Foundation
import Combine
import AVFoundation
import OSLog

public class PlayerItemStatusMonitor {
    
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "PlayerItemStatusMonitor")
    
    public enum MonitorError: Error, LocalizedError {
        case timeoutExceeded
        case playerItemFailed(Error?)
        
        public var errorDescription: String? {
            switch self {
            case .timeoutExceeded:
                return "Player item readiness monitoring timed out."
            case .playerItemFailed(let error):
                return "Player item failed: \(error?.localizedDescription ?? "Unknown error")"
            }
        }
    }
    
    private let playerItem: AVPlayerItem
    
    public init(playerItem: AVPlayerItem) {
        self.playerItem = playerItem
    }
    
    // Helper to get human-readable status description
    private func statusDescription(_ status: AVPlayerItem.Status) -> String {
        switch status {
        case .unknown: return "unknown"
        case .readyToPlay: return "readyToPlay"
        case .failed: return "failed"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }

    // MARK: - ENHANCED: Calculate total buffered duration across all loaded ranges
    private func calculateTotalBufferedDuration() -> TimeInterval {
        var totalDuration: TimeInterval = 0

        for rangeIndex in 0..<playerItem.loadedTimeRanges.count {
            let timeRange = playerItem.loadedTimeRanges[rangeIndex].timeRangeValue
            let rangeDuration = CMTimeGetSeconds(timeRange.duration)
            totalDuration += rangeDuration

            // Log individual ranges for debugging (first 3 ranges only to avoid spam)
            if rangeIndex < 3 {
                logger.info("🎬 MONITOR: 📊 Range \(rangeIndex + 1): \(String(format: "%.2f", rangeDuration))s")
            }
        }

        if self.playerItem.loadedTimeRanges.count > 3 {
            self.logger.info("🎬 MONITOR: 📊 ... and \(self.playerItem.loadedTimeRanges.count - 3) more ranges")
        }

        return totalDuration
    }
    
    /// Waits until the player item is ready and has buffered a sufficient duration for smooth interaction.
    /// Reports progress of the buffering process via a callback.
    @MainActor
    public func awaitReadyAndBuffered(
        timeout: TimeInterval = 15.0,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let requiredBufferDuration: TimeInterval = 0.5 // Reduced from 2.0s to 0.5s for faster readiness
        let retryBackoffBase: TimeInterval = 0.1 // Base for exponential backoff
        let maxRetryAttempts: Int = 5

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Timeout Task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MonitorError.timeoutExceeded
            }
            
            // Readiness Monitoring Task
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var observers = [NSKeyValueObservation]()
                    var hasResumed = false

                    let cleanupAndResume: (Result<Void, Error>?) -> Void = { result in
                        guard !hasResumed else { 
                            self.logger.info("🎬 MONITOR: ⚠️ Continuation already resumed, ignoring duplicate call")
                            return 
                        }
                        hasResumed = true
                        observers.forEach { $0.invalidate() }
                        observers.removeAll()
                        
                        switch result {
                        case .success:
                            self.logger.info("🎬 MONITOR: ✅ Continuation resumed successfully")
                            continuation.resume()
                        case .failure(let error):
                            self.logger.error("🎬 MONITOR: 🚨 Continuation resumed with error: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        case .none:
                            self.logger.info("🎬 MONITOR: ✅ Continuation resumed without error")
                            continuation.resume()
                        }
                    }
                    
                    // Log initial state
                    self.logger.info("🎬 MONITOR: 🚀 Starting monitoring - Initial status: \(self.statusDescription(self.playerItem.status))")

                    let checkReadiness = {
                        // Use switch statement for exhaustive state handling
                        switch self.playerItem.status {
                        case .failed:
                            self.logger.error("🎬 MONITOR: 🚨 Player item failed with error: \(String(describing: self.playerItem.error?.localizedDescription))")
                            cleanupAndResume(.failure(MonitorError.playerItemFailed(self.playerItem.error)))
                            
                        case .unknown:
                            // Simply wait for status update - do nothing, continuation remains pending
                            self.logger.info("🎬 MONITOR: ⏳ Status is unknown, waiting for update...")
                            return
                            
                        case .readyToPlay:
                            self.logger.info("🎬 MONITOR: ✅ Status is ready, checking buffer...")
                            
                            // MARK: - ENHANCED: Multi-range buffer calculation for better 90% handling
                            let totalBufferedDuration = self.calculateTotalBufferedDuration()
                            let progress = min(1.0, totalBufferedDuration / requiredBufferDuration)

                            Task { @MainActor in
                                await onProgress(progress)
                                self.logger.info("🎬 MONITOR: 📈 Enhanced buffer progress: \(Int(progress * 100))% (\(String(format: "%.2f", totalBufferedDuration))s buffered across \(self.playerItem.loadedTimeRanges.count) ranges)")

                                // MARK: - CRITICAL: Explicit 90%+ milestone logging
                                if progress >= 0.9 && progress < 1.0 {
                                    self.logger.info("🎬 MONITOR: 🎯 90% milestone reached - final buffering phase")
                                }
                            }

                            // MARK: - ENHANCED: More comprehensive buffer readiness check
                            let isBufferReady = totalBufferedDuration >= requiredBufferDuration ||
                                                 self.playerItem.isPlaybackBufferFull ||
                                                 self.playerItem.isPlaybackLikelyToKeepUp ||
                                                 (progress >= 0.95 && self.playerItem.loadedTimeRanges.count > 1) // Accept 95%+ with multiple ranges

                            if isBufferReady {
                                self.logger.info("🎬 MONITOR: 🎉 Enhanced buffer requirements met - resuming continuation!")
                                cleanupAndResume(nil)
                            }
                            
                        @unknown default:
                            self.logger.warning("🎬 MONITOR: ⚠️ Unknown player item status: \(self.statusDescription(self.playerItem.status))")
                            // Wait for known status
                            return
                        }
                    }
                    
                    // Initial check to handle case where player is already ready
                    checkReadiness()
                    
                    // Observe status changes with detailed logging
                    observers.append(self.playerItem.observe(
                        \.status, options: [.new, .initial]) { _, change in
                        Task { @MainActor in
                            let oldStatus = change.oldValue.map { self.statusDescription($0) } ?? "unknown"
                            let newStatus = self.statusDescription(self.playerItem.status)
                            self.logger.info("🎬 MONITOR: 📊 Status changed from \(oldStatus) to \(newStatus)")
                            checkReadiness()
                        }
                    })

                    // Observe loaded time ranges with detailed logging
                    observers.append(self.playerItem.observe(
                        \.loadedTimeRanges, options: [.new, .initial]) { _, _ in
                        Task { @MainActor in
                            let rangeCount = self.playerItem.loadedTimeRanges.count
                            if let firstRange = self.playerItem.loadedTimeRanges.first?.timeRangeValue {
                                let duration = CMTimeGetSeconds(firstRange.duration)
                                self.logger.info("🎬 MONITOR: 📊 Loaded ranges updated: \(rangeCount) ranges, first duration: \(String(format: "%.2f", duration))s")
                            } else {
                                self.logger.info("🎬 MONITOR: 📊 Loaded ranges updated: \(rangeCount) ranges, no durations available")
                            }
                            checkReadiness()
                        }
                    })
                    
                    // Observe additional playback properties for comprehensive monitoring
                    observers.append(self.playerItem.observe(
                        \.isPlaybackBufferFull, options: [.new]) { _, _ in
                        Task { @MainActor in
                            self.logger.info("🎬 MONITOR: 📊 Playback buffer full: \(self.playerItem.isPlaybackBufferFull)")
                            checkReadiness()
                        }
                    })
                    
                    observers.append(self.playerItem.observe(
                        \.isPlaybackLikelyToKeepUp, options: [.new]) { _, _ in
                        Task { @MainActor in
                            self.logger.info("🎬 MONITOR: 📊 Likely to keep up: \(self.playerItem.isPlaybackLikelyToKeepUp)")
                            checkReadiness()
                        }
                    })
                    
                    self.logger.info("🎬 MONITOR: ✅ All observers set up successfully")
                }
            }

            // Await the first task to finish and cancel the other.
            try await group.next()
            group.cancelAll()
        }
    }
    
    /// Convenience method that waits for readiness without progress reporting
    @MainActor
    public func awaitReadyAndBuffered(timeout: TimeInterval = 15.0) async throws {
        try await awaitReadyAndBuffered(timeout: timeout) { _ in }
    }
    
}