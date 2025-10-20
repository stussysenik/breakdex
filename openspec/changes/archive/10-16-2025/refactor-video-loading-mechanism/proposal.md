## Why
The current video loading mechanism has critical reliability issues causing users to get stuck in loading states due to complex coordination layers, redundant loading attempts, state transition conflicts, and invalid asset URLs (file:///dev/null). The system suffers from race conditions between multiple coordination components and lacks proper error recovery.

## What Changes
- Simplify video loading architecture by eliminating redundant coordination layers
- Fix AVAsset URL generation to provide proper file paths instead of /dev/null
- Implement single-source-of-truth video loading flow with atomic state transitions
- Add robust timeout and retry mechanisms with exponential backoff
- Fix concurrent state transition blocking issues
- Add comprehensive error recovery and fallback mechanisms
- Improve progress reporting reliability with debouncing and correlation tracking

## Impact
- Affected specs: video-loading (new capability)
- Affected code: VideoLoadingService.swift, VideoLoadingOperationManager.swift, VideoInitializationCoordinator.swift, AddMoveUnifiedState.swift
- **BREAKING**: Simplifies coordination architecture, reduces complexity from 3 coordinators to 1 unified flow