---

### **Proposal: `changes/fix-player-await-contract/proposal.md`**

```markdown
## Why

The video loading UI is stuck at 94% due to a race condition between `SharedVideoPlayer` (Service) and `AddMoveViewModel` (ViewModel).

Our previous fix to prevent "multiple updates per frame" warnings inside `SharedVideoPlayer` was correct but incomplete. It used a "fire-and-forget" `Task` to set `isReady = true`, which caused the `loadVideo` function to return to the `AddMoveViewModel` *before* the player was *fully* ready.

`AddMoveViewModel` would then immediately fire its 95%->100% UI updates, which collided with the "floating" `isReady = true` update from the service. SwiftUI throttles this storm of updates, and the UI never renders the final 100% state.

## What Changes

-   **MODIFIED**: `SharedVideoPlayer.swift:finalizeVideoLoad()` will be updated to `await Task.yield()` between the `state = .ready` and `isReady = true` updates.
-   **MODIFIED**: `SharedVideoPlayer.swift:finalizePlayerReadyState()` will be updated with the same `await Task.yield()` pattern for consistency.
-   **Why**: This ensures the `loadVideo` function does not return to its caller (`AddMoveViewModel`) until *all* its `@Published` properties are set and its state is stable, thus honoring its `async` contract and eliminating the race condition.
-   **ADDED**: Minimal diagnostic logging to confirm the frame separation timing and prove that `isReady = true` is set *before* the `AddMoveViewModel` resumes its work.

## Impact

-   **Affected specs**: `video-player-state` (modifies the requirement for deferred updates).
-   **Affected code**: `breakdex/Features/Shared/Video/VideoPlayer.swift` (specifically the `finalizeVideoLoad` and `finalizePlayerReadyState` methods).
-   **Affected code**: `breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift` (**No changes needed.** This is the correct architectural outcome).
-   **Breaking changes**: None. The public API contract is unchanged; this change simply makes the `async` function behave as the caller already expects.
-   **User impact**: **Fixes the 94% hang.** Video loading will now reliably complete to 100%.