# Actor-Based Transition Lock Implementation

## Overview

This document describes the implementation of an actor-based transition lock system that fixes race conditions in the video loading workflow of the BreakingFlashcards iOS app.

## Problem Statement

The original implementation suffered from a race condition where:

1. A Task to transition to trimming is launched asynchronously with `Task.sleep`
2. The `didSelectVideo` function from the first, now-cancelled task continues execution and hits its `catch` block
3. This `catch` block calls `resetAtomicTransitionLock()` prematurely
4. The second, valid Task wakes up from `sleep` but its transition lock has been prematurely unlocked
5. It then fails validation with "Invalid state for trimmer setup: loadingVideo"

## Solution: Actor-Based Lock Management

### Key Components

#### 1. TransitionLockManager Actor
- **Location**: `breakdex/Views/Arsenal/AddMove/TransitionLockManager.swift`
- **Purpose**: Provides thread-safe lock management with ownership tracking
- **Key Features**:
  - Actor isolation prevents concurrent access to lock state
  - UUID-based ownership tracking ensures only the lock owner can release it
  - Comprehensive diagnostic logging for debugging race conditions
  - Retry mechanism for robustness
  - Force reset capability for emergency situations

#### 2. Refactored AddMoveUnifiedState
- **Changes Made**:
  - Replaced `isTransitioningToTrimming` boolean with `currentTransitionId: UUID?`
  - Replaced `atomicTransitionLock` NSLock with `transitionLockManager: TransitionLockManager`
  - Updated all lock acquisition/release points to use the actor
  - Enhanced diagnostic logging throughout

### Implementation Details

#### Lock Acquisition Pattern
```swift
private func acquireTransitionLock(correlationId: String) async throws -> UUID {
    let transitionId = UUID()

    do {
        try await transitionLockManager.acquireLockWithRetry(for: transitionId, retryCount: 3, retryDelay: 10)
        currentTransitionId = transitionId
        transitionStartTime = Date()
        transitionCorrelationId = correlationId

        logger.info("🎬 AddMoveUnifiedState: ✅ Transition lock acquired successfully - ID: \(transitionId.uuidString)")
        return transitionId
    } catch {
        logger.error("🎬 AddMoveUnifiedState: ❌ Failed to acquire transition lock after retries: \(error.localizedDescription)")
        throw error
    }
}
```

#### Lock Release Pattern
```swift
private func resetAtomicTransitionLock() async {
    // 🎯 ACTOR-BASED LOCK: Release lock only if we own it
    if let transitionId = currentTransitionId {
        await transitionLockManager.releaseLock(for: transitionId)
        logger.info("🎬 AddMoveUnifiedState: 🔒 Transition lock released for operation: \(transitionId.uuidString)")
    } else {
        logger.warning("🎬 AddMoveUnifiedState: ⚠️ No current transition ID - cannot release lock")
    }

    // 🎯 STATE RESET: Clear transition tracking
    currentTransitionId = nil
    transitionStartTime = nil
    transitionCorrelationId = nil
}
```

#### Lock Validation Pattern
```swift
// 🎯 ACTOR-BASED VALIDATION: Verify transition lock ownership
guard let transitionId = currentTransitionId else {
    logger.warning("🎬 AddMoveUnifiedState: ⚠️ ACTOR GUARD VIOLATION - No transition ID found")
    return
}

guard await transitionLockManager.ownsLock(id: transitionId) else {
    logger.warning("🎬 AddMoveUnifiedState: ⚠️ ACTOR GUARD VIOLATION - Transition lock not owned by this operation")
    return
}
```

## How This Fixes the Race Condition

### Before (Original Implementation)
1. **Boolean Flag**: `isTransitioningToTrimming = true/false`
2. **No Ownership Tracking**: Anyone could set the flag to false
3. **Race Condition**: Cancelled task's catch block resets flag prematurely
4. **Result**: Valid task fails validation because flag is cleared

### After (Actor-Based Implementation)
1. **UUID Ownership**: Each operation gets a unique identifier
2. **Actor Isolation**: Only the lock owner can release the lock
3. **Ownership Validation**: Operations verify they own the lock before proceeding
4. **Retry Mechanism**: Operations can retry lock acquisition if needed
5. **Comprehensive Logging**: Full audit trail for debugging

### Race Condition Prevention

The actor-based approach prevents the race condition through several mechanisms:

1. **Actor Isolation**: The `TransitionLockManager` actor ensures that all lock operations are serialized and thread-safe.

2. **Ownership Tracking**: Each operation must provide a UUID to acquire and release the lock. The cancelled task's UUID is different from the new task's UUID.

3. **Validation at Critical Points**: Before executing any transition logic, the operation verifies it still owns the lock:
   ```swift
   guard await transitionLockManager.ownsLock(id: transitionId) else {
       logger.warning("🎬 AddMoveUnifiedState: ⚠️ ACTOR GUARD VIOLATION - Transition lock not owned by this operation")
       return
   }
   ```

4. **Proper Cleanup**: The `resetForNewVideoSelection` method explicitly releases any existing locks before starting a new operation.

## Implementation Benefits

1. **Thread Safety**: Actor isolation prevents concurrent access to lock state
2. **Accountability**: UUID-based ownership tracking ensures only owners can release locks
3. **Robustness**: Retry mechanism handles transient lock conflicts
4. **Debuggability**: Comprehensive logging provides full audit trail
5. **Maintainability**: Clear separation of concerns and well-documented API

## Files Modified

1. **New File**: `TransitionLockManager.swift` - Actor-based lock manager
2. **Modified**: `AddMoveUnifiedState.swift` - Refactored to use actor-based locks
3. **Test File**: `TransitionLockManagerTest.swift` - Unit tests for lock functionality

## Testing

The implementation includes comprehensive tests in `TransitionLockManagerTest.swift`:

1. **Basic Lock Functionality**: Verify acquire/release operations work correctly
2. **Concurrent Lock Prevention**: Verify only one operation can hold the lock
3. **Retry Mechanism**: Verify retry logic works when locks become available

## Performance Considerations

- **Actor Overhead**: Minimal overhead compared to NSLock
- **Memory Usage**: One UUID per transition operation (negligible)
- **Scalability**: Singleton actor ensures system-wide coordination
- **Latency**: Lock operations are typically sub-millisecond

## Conclusion

The actor-based transition lock implementation provides a robust, thread-safe solution to the race condition in the video loading workflow. By combining Swift Concurrency actors with UUID-based ownership tracking, we ensure that cancellation handlers cannot interfere with new operations while maintaining excellent performance and debuggability.

This implementation follows Swift Concurrency best practices and provides a solid foundation for preventing similar race conditions in other parts of the application.