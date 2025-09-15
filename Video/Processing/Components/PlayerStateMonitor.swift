import Foundation
import Combine
import AVFoundation
import OSLog

/// Monitors player state changes with atomic operations to prevent race conditions
@MainActor
public class PlayerStateMonitor {
    
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "PlayerStateMonitor")
    
    /// Simple logging for debugging
    private func log(_ message: String) {
        print("🎬 \(message)")
    }
    
    public enum MonitorError: Error, LocalizedError {
        case playerNotReady
        case timeoutExceeded
        case playerFailed(Error?)
        case observationCancelled
        
        public var errorDescription: String? {
            switch self {
            case .playerNotReady:
                return "Player is not ready"
            case .timeoutExceeded:
                return "Player readiness monitoring timed out"
            case .playerFailed(let error):
                return "Player failed: \(error?.localizedDescription ?? "Unknown error")"
            case .observationCancelled:
                return "Player state observation was cancelled"
            }
        }
    }
    
    // MARK: - Observer tokens
    private var cancellables = Set<AnyCancellable>()
    private var kvoObservers: [NSKeyValueObservation] = []
    private var notifObservers: [NSObjectProtocol] = []
    private var timeoutTask: Task<Void, Never>?
    private var currentPlayer: AVPlayer?
    
    private let continuationManager = ContinuationManager<Void>()
    
    /// Public accessor for checking if monitor is still pending
    public var isPending: Bool {
        return continuationManager.isPending
    }
    
    public init() {}
    
    /// Wait for player to reach ready state with atomic continuation management
    /// - Parameters:
    ///   - player: The AVPlayer to monitor
    ///   - timeout: Maximum time to wait in seconds
    public func waitForPlayerReady(
        _ player: AVPlayer,
        timeout: TimeInterval = 30.0
    ) async throws {
        log("PLAYER_STATE_MONITOR: waitForReady called with timeout: \(timeout)s")
        
        // If player is already ready, return immediately
        if isPlayerReady(player) {
            log("✅ PLAYER_STATE_MONITOR: Player already ready, returning immediately")
            return
        }
        
        log("⏳ PLAYER_STATE_MONITOR: Player not ready, setting up monitoring")
        return try await withCheckedThrowingContinuation { continuation in
            // Set up state monitoring
            start(player: player, continuation: continuation, timeout: timeout)
        }
    }
    
    /// Start monitoring the player state
    /// - Parameters:
    ///   - player: The AVPlayer to monitor
    ///   - continuation: The continuation to resume when ready
    ///   - timeout: Maximum time to wait in seconds
    private func start(
        player: AVPlayer,
        continuation: CheckedContinuation<Void, Error>,
        timeout: TimeInterval
    ) {
        log("🔀 PLAYER_STATE_MONITOR: start() called for player: \(player)")
        
        // Stop any existing monitoring
        stop()
        
        // Store the current player for cleanup
        currentPlayer = player
        
        // Monitor player status using KVO
        let playerStatusKVO = player.observe(\.status, options: [.initial, .new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.handlePlayerStatusChange(player.status, player: player, continuation: continuation)
            }
        }
        kvoObservers.append(playerStatusKVO)
        
        // Monitor current item status if available
        if let currentItem = player.currentItem {
            let itemStatusKVO = currentItem.observe(\.status, options: [.initial, .new]) { [weak self] _, change in
                Task { @MainActor [weak self] in
                    self?.handlePlayerItemStatusChange(currentItem.status, player: player, continuation: continuation)
                }
            }
            kvoObservers.append(itemStatusKVO)
        }
        
        // Set up timeout task
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                
                // Only timeout if still pending
                if self?.continuationManager.isPending == true {
                    self?.stop()
                    let _ = self?.continuationManager.safelyResume(continuation, with: .failure(MonitorError.timeoutExceeded))
                }
            } catch {
                // Task was cancelled, monitoring must have completed
            }
        }
        
        // Check initial state one more time
        if isPlayerReady(player) {
            stop()
            let _ = continuationManager.safelyResume(continuation, with: .success(()))
        }
    }
    
    /// Stop all monitoring and clean up resources
    public func stop() {
        log("🛑 PLAYER_STATE_MONITOR: stop() called")
        
        // Cancel and remove all KVO observers
        kvoObservers.removeAll()
        
        // Cancel and remove all Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Cancel timeout task
        timeoutTask?.cancel()
        timeoutTask = nil
        
        // Clear current player reference
        currentPlayer = nil
        
        let wasCancelled = continuationManager.cancel()
        log("🛑 PLAYER_STATE_MONITOR: Monitoring stopped, was pending: \(wasCancelled)")
    }
    
    /// Cancel all ongoing monitoring (legacy method for backward compatibility)
    public func cancelMonitoring() {
        stop()
    }
    
    // MARK: - Private Methods
    
    private func isPlayerReady(_ player: AVPlayer) -> Bool {
        return player.status == .readyToPlay && 
               player.currentItem?.status == .readyToPlay
    }
    
    private func handlePlayerStatusChange(
        _ status: AVPlayer.Status,
        player: AVPlayer,
        continuation: CheckedContinuation<Void, Error>
    ) {
        log("📊 PLAYER_STATE_MONITOR: Player status changed to: \(String(describing: status))")
        
        guard continuationManager.isPending else { 
            log("⚠️ PLAYER_STATE_MONITOR: Ignoring status change - continuation already resumed")
            return 
        }
        
        switch status {
        case .readyToPlay:
            log("✅ PLAYER_STATE_MONITOR: Player ready, checking if can resume")
            checkAndResumeIfReady(player: player, continuation: continuation)
        case .failed:
            log("❌ PLAYER_STATE_MONITOR: Player failed with error: \(player.error?.localizedDescription ?? "Unknown")")
            cancelMonitoring()
            let _ = continuationManager.safelyResume(
                continuation, 
                with: .failure(MonitorError.playerFailed(player.error))
            )
        case .unknown:
            log("📊 PLAYER_STATE_MONITOR: Player status unknown, waiting...")
            break
        @unknown default:
            log("⚠️ PLAYER_STATE_MONITOR: Unknown player status: \(String(describing: status))")
            break
        }
    }
    
    private func handlePlayerItemStatusChange(
        _ status: AVPlayerItem.Status,
        player: AVPlayer,
        continuation: CheckedContinuation<Void, Error>
    ) {
        log("📊 PLAYER_STATE_MONITOR: PlayerItem status changed to: \(String(describing: status))")
        
        guard continuationManager.isPending else { 
            log("⚠️ PLAYER_STATE_MONITOR: Ignoring playerItem status change - continuation already resumed")
            return 
        }
        
        switch status {
        case .readyToPlay:
            log("✅ PLAYER_STATE_MONITOR: PlayerItem ready, checking if can resume")
            checkAndResumeIfReady(player: player, continuation: continuation)
        case .failed:
            log("❌ PLAYER_STATE_MONITOR: PlayerItem failed with error: \(player.currentItem?.error?.localizedDescription ?? "Unknown")")
            cancelMonitoring()
            let _ = continuationManager.safelyResume(
                continuation, 
                with: .failure(MonitorError.playerFailed(player.currentItem?.error))
            )
        case .unknown:
            log("📊 PLAYER_STATE_MONITOR: PlayerItem status unknown, waiting...")
            break
        @unknown default:
            log("⚠️ PLAYER_STATE_MONITOR: Unknown playerItem status: \(String(describing: status))")
            break
        }
    }
    
    private func checkAndResumeIfReady(
        player: AVPlayer,
        continuation: CheckedContinuation<Void, Error>
    ) {
        if isPlayerReady(player) {
            log("🎉 PLAYER_STATE_MONITOR: Player and PlayerItem both ready, resuming continuation")
            cancelMonitoring()
            let didResume = continuationManager.safelyResume(continuation, with: .success(()))
            log("🎉 PLAYER_STATE_MONITOR: Continuation resumed successfully: \(didResume)")
        } else {
            log("⏳ PLAYER_STATE_MONITOR: Player not fully ready yet - player: \(String(describing: player.status)), item: \(String(describing: player.currentItem?.status ?? .unknown))")
        }
    }
    
    deinit {
        // Clean up synchronously to avoid retain cycles
        kvoObservers.removeAll()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        timeoutTask?.cancel()
        timeoutTask = nil
        currentPlayer = nil
        // Note: continuationManager.cancel() cannot be called from deinit due to actor isolation
        // The continuation manager will be cleaned up when it's released
    }
}