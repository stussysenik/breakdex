# Video Player State Management Specification

## MODIFIED Requirements

### Requirement: Synchronized Async Contract for @Published Updates

Video player state finalization methods SHALL `await` all sequential @Published property updates, including mandatory frame breaks, to ensure the `async` function's contract is not violated.

#### Scenario: Successful Video Loading with Synchronized State Propagation
**Given** a video asset is loaded and the player is ready for finalization
**When** `finalizeVideoLoad()` is called (and awaited by a caller)
**Then** it SHALL:
1.  Acquire atomic lock for state coordination only.
2.  Determine if state updates are needed while under lock.
3.  Release atomic lock before any @Published property updates.
4.  Update `state = .ready` outside the atomic lock context.
5.  **`await` a task suspension** (e.g., `await Task.yield()`) to explicitly cede control to the MainActor scheduler and guarantee a UI frame break.
6.  **Update `isReady = true`** in a separate MainActor execution context *after* the suspension has resumed.
7.  The `finalizeVideoLoad()` function SHALL NOT return control to its caller (e.g., `loadVideo`) until *after* `isReady = true` has been successfully set.
8.  Log timing diagnostics for lock boundaries and the frame separation break.

#### Scenario: KVO-Triggered State Updates
**Given** the player item status changes to `readyToPlay`
**When** `finalizePlayerReadyState()` is called via a KVO observer
**Then** it SHALL:
1.  Follow the same synchronized `await` pattern as `finalizeVideoLoad()`.
2.  `await Task.yield()` between the `state = .ready` update and the `isReady = true` update.
3.  Ensure state consistency by awaiting all `@Published` side effects.

### Requirement: Minimal Diagnostic Logging for Concurrency

Video player SHALL provide minimal, high-signal diagnostic logs to verify concurrency boundaries and state synchronization.

#### Scenario: Frame Separation Verification
**Given** a state finalization method is executed
**When** `await Task.yield()` is called for frame separation
**Then** it SHALL:
1.  Log the `state` update timestamp.
2.  Log the `isReady` update timestamp.
3.  Log the measured duration *between* the two updates to confirm a frame break occurred (e.g., > 0ms).
4.  Log when the `finalizeVideoLoad` function completes, *after* all properties are set.

#### Scenario: State Composition Validation
**Given** `AddMoveViewModel` is awaiting `SharedVideoPlayer.loadVideo()`
**When** `SharedVideoPlayer.loadVideo()` returns
**Then** diagnostic logs SHALL show:
1.  `SharedVideoPlayer` logged "isReady = true" *before* `AddMoveViewModel` logged "95% - Preparing for playback".
2.  This confirms the `await` contract was honored and the race condition is eliminated.