## Why

The video loading system is experiencing race conditions and state synchronization issues that prevent users from successfully transitioning from asset selection to the trimming interface. The system gets stuck in loading state despite successful asset acquisition.

## What Changes

- Fix competing state transitions causing "Already transitioning" errors
- Resolve state synchronization between loading completion and UI navigation
- Ensure proper atomic state management during loading → trimming transition
- Fix progress reporting inconsistencies during loading phases
- **BREAKING**: Modifies the state transition coordination mechanism

## Impact

- Affected specs: video-loading
- Affected code: VideoLoadingService, AddMoveUnifiedState, AtomicStateCoordinator
- Critical user flow: photo picker → loading → trimming workflow