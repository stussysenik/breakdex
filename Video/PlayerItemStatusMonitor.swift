
import Foundation
import Combine
import AVFoundation
import OSLog

import Foundation
import Combine
import AVFoundation
import OSLog

@MainActor
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
    
    /// Waits until the player item is ready and has buffered a sufficient duration for smooth interaction.
    /// Reports progress of the buffering process via a callback.
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
                        guard !hasResumed else { return }
                        hasResumed = true
                        observers.forEach { $0.invalidate() }
                        observers.removeAll()
                        if let result = result {
                            continuation.resume(with: result)
                        } else {
                            continuation.resume()
                        }
                    }

                    let checkReadiness = {
                        guard self.playerItem.status == .readyToPlay else {
                            if self.playerItem.status == .failed {
                                cleanupAndResume(.failure(MonitorError.playerItemFailed(self.playerItem.error)))
                            }
                            return
                        }
                        
                        guard let firstRange = self.playerItem.loadedTimeRanges.first?.timeRangeValue else {
                        Task { @MainActor in
                            await onProgress(0) // No buffer yet
                        }
                            return
                        }
                        
                        let bufferedDuration = CMTimeGetSeconds(firstRange.duration)
                        let progress = min(1.0, bufferedDuration / requiredBufferDuration)
                        Task { @MainActor in
                            await onProgress(progress)
                        }

                        if bufferedDuration >= requiredBufferDuration || self.playerItem.isPlaybackBufferFull || self.playerItem.isPlaybackLikelyToKeepUp {
                            cleanupAndResume(nil)
                        }
                    }
                    
                    observers.append(self.playerItem.observe(
                        \.status, options: [.new, .initial]) { _, _ in
                        Task { @MainActor in checkReadiness() }
                    })

                    observers.append(self.playerItem.observe(
                        \.loadedTimeRanges, options: [.new, .initial]) { _, _ in
                        Task { @MainActor in checkReadiness() }
                    })
                }
            }

            // Await the first task to finish and cancel the other.
            try await group.next()
            group.cancelAll()
        }
    }
    
}