## Context
The current video loading system suffers from architectural over-engineering with multiple coordination layers (VideoLoadingService, VideoLoadingOperationManager, VideoInitializationCoordinator) creating race conditions, state synchronization issues, and reliability problems. Users get stuck in loading states due to concurrent transition blocking and invalid asset URLs (/dev/null).

## Goals / Non-Goals
- **Goals**:
  - Simplify video loading to single coordinated flow
  - Eliminate race conditions and state synchronization issues
  - Fix asset URL generation and file management
  - Improve reliability with proper error recovery
  - Maintain backward compatibility with existing UI components
- **Non-Goals**:
  - Complete rewrite of video processing pipeline
  - Changes to video trimming or playback functionality
  - Modifications to Core Data models

## Decisions
- **Decision**: Consolidate three coordination layers into single VideoLoadingService
  - **Why**: Eliminates race conditions from multiple coordinators trying to manage same state
  - **Alternatives considered**: Keep all layers but add synchronization, Use coordinator pattern with clearer boundaries

- **Decision**: Replace complex progress debouncing with direct atomic state updates
  - **Why**: Simplifies code and eliminates timing-related issues
  - **Alternatives considered**: Enhanced debouncing with better coordination, Event-based progress system

- **Decision**: Implement queue-based state transitions to prevent blocking
  - **Why**: Ensures sequential processing and eliminates concurrent transition conflicts
  - **Alternatives considered**: Lock-based synchronization, Actor-based state management

## Risks / Trade-offs
- **Risk**: Consolidating coordination logic may increase complexity in VideoLoadingService
  - **Mitigation**: Keep VideoLoadingService focused and well-structured with clear separation of concerns
- **Risk**: Removing progress debouncing may affect UI performance
  - **Mitigation**: Implement throttling at UI layer instead of loading service layer
- **Trade-off**: Simplicity vs. granular control - we're choosing simplicity for reliability

## Migration Plan
1. **Phase 1**: Implement new simplified VideoLoadingService alongside existing system
2. **Phase 2**: Add feature flag to switch between old and new systems
3. **Phase 3**: Test new system thoroughly and migrate users
4. **Phase 4**: Remove deprecated coordination components

## Open Questions
- Should we implement iOS 18 specific optimizations for AVAsset loading?
- What timeout values are appropriate for different network conditions?
- How should we handle very large video files (>100MB)?
- Do we need different loading strategies for different video formats?