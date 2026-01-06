# Design: Fix Player `async` Contract

## Context

Our previous fix (Specs 3-6) solved the "multiple updates per frame" warning *inside* `SharedVideoPlayer` by separating `state = .ready` and `isReady = true` into different execution contexts.

However, this introduced a new, critical bug: the `finalizeVideoLoad()` function (and by extension `loadVideo()`) `await`ed the *first* update (`state = .ready`) but used a "fire-and-forget" `Task { ... }` for the *second* update (`isReady = true`).

This means `loadVideo()` returned `true` to `AddMoveViewModel` *prematurely*. `AddMoveViewModel`, believing the player was fully ready, would immediately start its own 95%->99%->100% `@Published` updates, which would then collide with the "floating" `isReady = true` update from the player. This race condition is the root cause of the UI freezing at 94%.

## Goals / Non-Goals

-   **Goal:** Fix the race condition by ensuring `SharedVideoPlayer.loadVideo()` honors its `async` contract.
-   **Goal:** The function *must not return* until all its `@Published` side effects are complete.
-   **Goal:** Maintain the frame separation that prevents the "multiple updates per frame" warning.
-   **Non-Goal:** Change `AddMoveViewModel`. The ViewModel's code is correct; it is the Service's *contract* that is broken.
-   **Non-Goal:** Remove the atomic lock, which is working correctly to prevent dual execution.

## Decision: `await Task.yield()`

We will enforce a **synchronized `async` contract** in `SharedVideoPlayer`. The `finalizeVideoLoad` and `finalizePlayerReadyState` methods will be modified to `await` *both* `@Published` updates sequentially.

To achieve frame separation, we will use `await Task.yield()` between the two updates.

```swift
// Proposed Implementation Pattern

@MainActor
private func finalizeVideoLoad() async {
    // 1. Atomic lock logic remains the same
    guard !isFinalizingState, state != .ready else {
        logger.debug("🎯 Atomic lock prevented: finalizeVideoLoad() blocked")
        return
    }
    isFinalizingState = true
    let shouldUpdateState = (state != .ready)
    let lockStartTime = CFAbsoluteTimeGetCurrent()
    
    defer {
        isFinalizingState = false
        logger.debug("🔓 Lock released: ...")
    }

    // 2. Exit atomic context
    guard shouldUpdateState else { return }

    // 3. First @Published update
    let stateTimestamp = CFAbsoluteTimeGetCurrent()
    logPublishedUpdate("state", stateTimestamp, "loading -> ready")
    self.state = .ready

    // 4. THE FIX: Await a suspension to guarantee a frame break
    // This forces this async function to pause, allowing the UI
    // to process the `state` update.
    await Task.yield()

    // 5. This code now runs *after* the suspension, in a new frame.
    // The `await` forces `finalizeVideoLoad` to wait for this.
    let isReadyTimestamp = CFAbsoluteTimeGetCurrent()
    let frameDelay = isReadyTimestamp - stateTimestamp
    
    logPublishedUpdate("isReady", isReadyTimestamp, "false -> true")
    logger.debug("🎯 Frame separation confirmed: \(String(format: "%.1f", frameDelay * 1000))ms")
    self.isReady = true
    
    // 6. Function returns AFTER isReady is set.
}