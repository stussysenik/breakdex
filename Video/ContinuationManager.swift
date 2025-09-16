import Foundation

/// Manages task continuation lifecycle with atomic operations to prevent misuse
@MainActor
public class ContinuationManager<T> {
    
    public enum ContinuationManagerError: Error, LocalizedError {
        case continuationAlreadyResumed
        case continuationCancelled
        case timeoutExceeded
        
        public var errorDescription: String? {
            switch self {
            case .continuationAlreadyResumed:
                return "Continuation has already been resumed"
            case .continuationCancelled:
                return "Continuation was cancelled"
            case .timeoutExceeded:
                return "Operation timed out"
            }
        }
    }
    
    private enum ContinuationState {
        case pending
        case resumed
        case cancelled
        case errored(Error)
    }
    
    private var state: ContinuationState = .pending
    private let stateQueue = DispatchQueue(label: "continuation.state.queue", attributes: .concurrent)
    
    /// Safely resume a continuation with atomic state management
    /// - Parameters:
    ///   - continuation: The continuation to resume
    ///   - result: The result to resume with
    /// - Returns: True if resumption was successful, false if already resumed
    @discardableResult
    public func safelyResume(
        _ continuation: CheckedContinuation<T, Error>,
        with result: Result<T, Error>
    ) -> Bool {
        return stateQueue.withFlags(.barrier) {
            guard case .pending = state else {
                return false
            }
            
            switch result {
            case .success(let value):
                state = .resumed
                continuation.resume(returning: value)
            case .failure(let error):
                state = .errored(error)
                continuation.resume(throwing: error)
            }
            
            return true
        }
    }
    
    /// Cancel the continuation if it hasn't been resumed yet
    /// - Returns: True if cancellation was successful, false if already resumed
    @discardableResult
    public func cancel() -> Bool {
        return stateQueue.withFlags(.barrier) {
            guard case .pending = state else {
                return false
            }
            
            state = .cancelled
            return true
        }
    }
    
    /// Check if the continuation is still pending
    public var isPending: Bool {
        return stateQueue.withFlags(.barrier) {
            guard case .pending = state else {
                return false
            }
            return true
        }
    }
    
    /// Get the current state for debugging
    public var currentState: String {
        return stateQueue.withFlags(.barrier) {
            switch state {
            case .pending:
                return "pending"
            case .resumed:
                return "resumed"
            case .cancelled:
                return "cancelled"
            case .errored(let error):
                return "errored(\(error.localizedDescription))"
            }
        }
    }
}

// MARK: - DispatchQueue Extension
private extension DispatchQueue {
    func withFlags<T>(_ flags: DispatchWorkItemFlags, execute work: () throws -> T) rethrows -> T {
        try flags.contains(.barrier) 
            ? sync(flags: flags, execute: work)
            : sync(execute: work)
    }
}