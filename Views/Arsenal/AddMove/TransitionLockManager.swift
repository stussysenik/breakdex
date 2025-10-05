import Foundation
import os.log

/// Actor-based transition lock manager to prevent race conditions in video loading workflow
///
/// This actor ensures that only one loading operation can hold the transition lock at a time,
/// preventing cancellation handlers from interfering with new operations.
///
/// Key features:
/// - Actor isolation prevents concurrent access to lock state
/// - UUID-based ownership tracking ensures only the lock owner can release it
/// - Comprehensive diagnostic logging for debugging race conditions
/// - Proper error handling for lock acquisition failures
actor TransitionLockManager {
    /// Shared singleton instance for the entire application
    static let shared = TransitionLockManager()

    /// Private state tracking the current lock owner
    private var lockOwner: UUID?

    /// Logger for comprehensive diagnostics
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "TransitionLockManager")

    /// Actor initializer - creates the global lock manager
    private init() {
        logger.info("🔒 TransitionLockManager: Initialized - Ready for lock management")
    }

    /// Acquire the transition lock for a specific operation
    ///
    /// - Parameter id: Unique identifier for the operation requesting the lock
    /// - Throws: `TransitionLockError.alreadyAcquired` if the lock is already held by another operation
    func acquireLock(for id: UUID) throws {
        logger.info("🔒 TransitionLockManager: Lock acquisition requested for operation: \(id.uuidString)")

        if let currentOwner = lockOwner {
            if currentOwner == id {
                logger.warning("🔒 TransitionLockManager: Lock already owned by same operation: \(id.uuidString)")
                return
            } else {
                let errorMessage = "Transition lock already acquired by operation: \(currentOwner.uuidString)"
                logger.error("🔒 TransitionLockManager: ❌ Lock acquisition failed - \(errorMessage)")
                throw TransitionLockError.alreadyAcquired(owner: currentOwner, requester: id)
            }
        }

        lockOwner = id
        logger.info("🔒 TransitionLockManager: ✅ Lock acquired successfully by operation: \(id.uuidString)")
    }

    /// Release the transition lock for a specific operation
    ///
    /// - Parameter id: Unique identifier for the operation releasing the lock
    /// - Throws: `TransitionLockError.notOwner` if the operation doesn't own the lock
    func releaseLock(for id: UUID) {
        logger.info("🔒 TransitionLockManager: Lock release requested for operation: \(id.uuidString)")

        guard let currentOwner = lockOwner else {
            logger.warning("🔒 TransitionLockManager: ⚠️ Lock release requested but no lock owner exists")
            return
        }

        if currentOwner != id {
            let errorMessage = "Operation \(id.uuidString) attempted to release lock owned by \(currentOwner.uuidString)"
            logger.error("🔒 TransitionLockManager: ❌ Lock release failed - \(errorMessage)")
            // Don't throw here to prevent crashes, but log the error clearly
            return
        }

        lockOwner = nil
        logger.info("🔒 TransitionLockManager: ✅ Lock released successfully by operation: \(id.uuidString)")
    }

    /// Check if the lock is currently held
    ///
    /// - Returns: `true` if the lock is held, `false` otherwise
    func isLocked() -> Bool {
        let locked = lockOwner != nil
        logger.debug("🔒 TransitionLockManager: Lock status check - Locked: \(locked)")
        return locked
    }

    /// Check if a specific operation owns the lock
    ///
    /// - Parameter id: Unique identifier for the operation to check
    /// - Returns: `true` if the operation owns the lock, `false` otherwise
    func ownsLock(id: UUID) -> Bool {
        let owns = lockOwner == id
        logger.debug("🔒 TransitionLockManager: Ownership check for operation \(id.uuidString): \(owns)")
        return owns
    }

    /// Get the current lock owner (for debugging purposes)
    ///
    /// - Returns: The UUID of the current lock owner, or `nil` if no owner
    func getCurrentOwner() -> UUID? {
        let owner = lockOwner
        logger.debug("🔒 TransitionLockManager: Current owner query: \(owner?.uuidString ?? "none")")
        return owner
    }

    /// Force reset the lock (emergency use only)
    ///
    /// This method should only be used in emergency situations where the lock
    /// needs to be reset regardless of ownership. It logs a warning for audit purposes.
    func forceResetLock() {
        logger.warning("🔒 TransitionLockManager: ⚠️ FORCE RESET - Lock being reset regardless of ownership")
        let previousOwner = lockOwner
        lockOwner = nil
        logger.info("🔒 TransitionLockManager: ✅ Force reset completed - Previous owner: \(previousOwner?.uuidString ?? "none")")
    }
}

/// Errors that can occur during lock management
enum TransitionLockError: LocalizedError {
    case alreadyAcquired(owner: UUID, requester: UUID)
    case notOwner(owner: UUID, requester: UUID)

    var errorDescription: String? {
        switch self {
        case .alreadyAcquired(let owner, let requester):
            return "Transition lock already acquired by operation \(owner.uuidString). Requester: \(requester.uuidString)"
        case .notOwner(let owner, let requester):
            return "Operation \(requester.uuidString) attempted to release lock owned by \(owner.uuidString)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .alreadyAcquired:
            return "Wait for the current operation to complete or cancel it before acquiring the lock"
        case .notOwner:
            return "Only the lock owner can release the lock. Check operation sequencing."
        }
    }
}

// MARK: - Convenience Extensions

extension TransitionLockManager {
    /// Acquire lock with automatic retry mechanism
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the operation
    ///   - retryCount: Number of times to retry acquisition (default: 3)
    ///   - retryDelay: Delay between retries in milliseconds (default: 10)
    /// - Throws: `TransitionLockError` if lock cannot be acquired after retries
    func acquireLockWithRetry(for id: UUID, retryCount: Int = 3, retryDelay: Int = 10) async throws {
        logger.info("🔒 TransitionLockManager: Starting lock acquisition with retry - Operation: \(id.uuidString), Retries: \(retryCount)")

        for attempt in 0...retryCount {
            do {
                try acquireLock(for: id)
                if attempt > 0 {
                    logger.info("🔒 TransitionLockManager: ✅ Lock acquired after \(attempt) retries for operation: \(id.uuidString)")
                }
                return
            } catch let lockError as TransitionLockError {
                if attempt < retryCount {
                    logger.info("🔒 TransitionLockManager: Retry \(attempt + 1)/\(retryCount) - Lock busy, waiting \(retryDelay)ms")
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000))
                } else {
                    logger.error("🔒 TransitionLockManager: ❌ Lock acquisition failed after \(retryCount) retries for operation: \(id.uuidString)")
                    throw lockError
                }
            } catch {
                // Re-throw any other errors immediately
                throw error
            }
        }
    }

    /// Execute a block of code while holding the lock
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the operation
    ///   - operation: The operation to execute while holding the lock
    /// - Throws: Any error from the operation or lock acquisition
    func withLock<T>(for id: UUID, operation: () async throws -> T) async throws -> T {
        try acquireLock(for: id)
        defer {
            releaseLock(for: id)
        }
        return try await operation()
    }
}