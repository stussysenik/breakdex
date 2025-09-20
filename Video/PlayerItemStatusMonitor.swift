
import Foundation
import Combine
import AVFoundation
import OSLog

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
    
    /// Waits until the player item is ready and has buffered a sufficient duration for smooth interaction.
    /// Reports progress of the buffering process via a callback.
    @MainActor
    public func awaitReadyAndBuffered(
        timeout: TimeInterval = 15.0,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let requiredBufferDuration: TimeInterval = 2.0 // Require 2 seconds of buffer for "readiness"

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
                            
                            // Check loaded time ranges
                            guard let firstRange = self.playerItem.loadedTimeRanges.first?.timeRangeValue else {
                                Task { @MainActor in
                                    await onProgress(0) // No buffer yet
                                    self.logger.info("🎬 MONITOR: 📈 Buffer progress: 0% (no loaded ranges)")
                                }
                                return
                            }
                            
                            // Calculate buffer progress
                            let bufferedDuration = CMTimeGetSeconds(firstRange.duration)
                            let progress = min(1.0, bufferedDuration / requiredBufferDuration)
                            Task { @MainActor in
                                await onProgress(progress)
                                self.logger.info("🎬 MONITOR: 📈 Buffer progress: \(Int(progress * 100))% (\(String(format: "%.2f", bufferedDuration))s buffered)")
                            }

                            // Check if buffer requirements are met
                            if bufferedDuration >= requiredBufferDuration || 
                               self.playerItem.isPlaybackBufferFull || 
                               self.playerItem.isPlaybackLikelyToKeepUp {
                                self.logger.info("🎬 MONITOR: 🎉 Buffer requirements met - resuming continuation!")
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