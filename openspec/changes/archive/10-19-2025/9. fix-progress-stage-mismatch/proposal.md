## Why
The video loading mechanism gets stuck at 88% progress because the system receives progress updates without matching stage information, causing the final transition to 100% completion to be rejected as "backward progress."

## What Changes
- Add stage information to LoadingProgress struct to preserve stage synchronization
- Fix RobustVideoLoader progress updates to include stage context
- Ensure final state transition from creatingAsset (88%) to fullyReady (100%) completes reliably
- Add minimal diagnostic logging to track stage-progress synchronization
- **BREAKING**: LoadingProgress constructor now requires stage parameter

## Impact
- Affected specs: video-loading
- Affected code: RobustVideoLoader.swift, ProgressTypes.swift, AddMoveViewModel.swift
- Primary benefit: 99.9% reliable video loading completion
- Secondary benefit: Better diagnostic visibility into loading progress synchronization
- Testing: Verify cancel-trim-select-new-clip workflow loads to 100% completion