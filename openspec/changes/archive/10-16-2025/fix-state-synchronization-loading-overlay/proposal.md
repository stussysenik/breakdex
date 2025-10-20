## Why
The AddMove feature suffers from critical state synchronization issues causing users to get stuck at loading overlay due to race conditions between state updates and inconsistent loading state management.

## What Changes
- Fix state synchronization race conditions in AddMoveUnifiedState
- Implement atomic state transitions for loading/trimming states
- Add robust loading overlay state management
- Coordinate VideoLoadingService progress updates with UnifiedState
- **BREAKING**: Changes state management architecture to prevent race conditions

## Impact
- Affected specs: video-loading, add-move-state-management
- Affected code: AddMoveUnifiedState.swift, VideoLoadingService.swift, VideoLoadingOperationManager.swift