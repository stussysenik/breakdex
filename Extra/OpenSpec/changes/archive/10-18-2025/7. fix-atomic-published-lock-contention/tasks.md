## 1. Implementation
- [x] 1.1 Modify `SharedVideoPlayer.swift:finalizeVideoLoad()`:
    - [x] Remove the "fire-and-forget" `Task { ... }` wrapper around the `isReady = true` update.
    - [x] Insert `await Task.yield()` *between* the `self.state = .ready` line and the `self.isReady = true` line.
    - [x] Ensure the entire function is `async` and properly `await`s these steps.
- [x] 1.2 Modify `SharedVideoPlayer.swift:finalizePlayerReadyState()`:
    - [x] Apply the exact same `await Task.yield()` pattern for consistency.
- [x] 1.3 Add minimal diagnostic logging:
    - [x] Add a `debug` log before and after `await Task.yield()` to measure the frame separation duration.
    - [x] Add a `debug` log at the very end of `finalizeVideoLoad` to confirm it completed *after* `isReady = true` was set.

## 2. Validation
- [x] 2.1 Build and run the app: `xcodebuild -project breakdex.xcodeproj -scheme breakdex build`.
- [ ] 2.2 Test the "Add Move" video loading flow.
- [ ] 2.3 **Confirm UI consistently reaches 100% and does not hang at 94%.**
- [ ] 2.4 **Inspect diagnostic logs** and confirm the following sequence:
    1.  `SharedVideoPlayer` logs `state = .ready`.
    2.  `SharedVideoPlayer` logs `isReady = true`.
    3.  `SharedVideoPlayer` logs `finalizeVideoLoad completed`.
    4.  *Only then* does `AddMoveViewModel` log `95% - Preparing for playback`.
- [ ] 2.5 Confirm no "multiple updates per frame" warnings appear in the logs.