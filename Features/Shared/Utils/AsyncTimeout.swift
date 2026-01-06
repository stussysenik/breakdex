import Foundation

// MARK: - Async Timeout Utility
/// Provides timeout guards for async operations to prevent crashes from hanging operations

enum TimeoutError: Error, LocalizedError {
    case timedOut(seconds: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .timedOut(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        }
    }
}

/// Execute an async operation with a timeout guard
/// - Parameters:
///   - seconds: Maximum time allowed for the operation
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: TimeoutError.timedOut if operation exceeds timeout
func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }
        
        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut(seconds: seconds)
        }
        
        // Return the first completed task's result
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut(seconds: seconds)
        }
        
        // Cancel remaining tasks
        group.cancelAll()
        
        return result
    }
}

/// Execute an async operation with a timeout guard (non-throwing version)
/// - Parameters:
///   - seconds: Maximum time allowed for the operation
///   - defaultValue: Value to return on timeout
///   - operation: The async operation to execute
/// - Returns: The result of the operation or defaultValue on timeout
func withTimeout<T: Sendable>(seconds: TimeInterval, defaultValue: T, operation: @escaping @Sendable () async -> T) async -> T {
    do {
        return try await withTimeout(seconds: seconds) {
            await operation()
        }
    } catch {
        return defaultValue
    }
}
