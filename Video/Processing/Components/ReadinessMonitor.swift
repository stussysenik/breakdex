import Foundation
import AVFoundation

@MainActor
public class ReadinessMonitor {
    
    public enum ReadinessMonitorError: Error, LocalizedError {
        case readinessTimeout
        case playerItemUnavailable
        case playerUnavailable
        
        public var errorDescription: String? {
            switch self {
            case .readinessTimeout:
                return "Player readiness timeout after 5 seconds"
            case .playerItemUnavailable:
                return "No player item available"
            case .playerUnavailable:
                return "No player available"
            }
        }
    }
    
    private var readinessObserver: NSKeyValueObservation?
    private var timeoutTask: Task<Void, Never>?
    
    public func waitForPlayerReady(_ player: AVPlayer) async throws {
        guard let playerItem = player.currentItem else {
            throw ReadinessMonitorError.playerItemUnavailable
        }
        
        try await waitForItemReady(playerItem)
    }
    
    public func waitForItemReady(_ item: AVPlayerItem) async throws {
        // If already ready, return immediately
        if item.status == .readyToPlay {
            return
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false // Atomic flag to prevent double resumption
            var kvoFireCount = 0
            
            // Set up KVO observer for playerItem status
            self.readinessObserver = item.observe(\.status, options: [.new]) { [weak self] playerItem, change in
                kvoFireCount += 1
                
                guard let self = self else {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: ReadinessMonitorError.playerUnavailable)
                    }
                    return
                }
                
                // Prevent double resumption
                guard !hasResumed else {
                    return
                }
                
                if playerItem.status == .readyToPlay {
                    // Mark as resumed and cancel timeout
                    hasResumed = true
                    Task { @MainActor [weak self] in
                        self?.timeoutTask?.cancel()
                        self?.timeoutTask = nil
                        self?.readinessObserver?.invalidate()
                        self?.readinessObserver = nil
                        continuation.resume()
                    }
                    
                } else if playerItem.status == .failed {
                    // Mark as resumed and cancel timeout
                    hasResumed = true
                    Task { @MainActor [weak self] in
                        self?.timeoutTask?.cancel()
                        self?.timeoutTask = nil
                        self?.readinessObserver?.invalidate()
                        self?.readinessObserver = nil
                        continuation.resume(throwing: playerItem.error ?? ReadinessMonitorError.readinessTimeout)
                    }
                }
            }
            
            // Set up timeout task with single resumption protection
            self.timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    
                    // Prevent double resumption
                    guard !hasResumed else {
                        return
                    }
                    
                    // Mark as resumed
                    hasResumed = true
                    
                    // Clean up observer on timeout
                    Task { @MainActor [weak self] in
                        self?.readinessObserver?.invalidate()
                        self?.readinessObserver = nil
                        continuation.resume(throwing: ReadinessMonitorError.readinessTimeout)
                    }
                    
                } catch {
                    // Task was cancelled, KVO must have won
                }
            }
        }
    }
    
    public func cancelMonitoring() {
        readinessObserver?.invalidate()
        readinessObserver = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
    
    deinit {
        // Clean up synchronously to avoid retain cycle
        readinessObserver?.invalidate()
        readinessObserver = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}