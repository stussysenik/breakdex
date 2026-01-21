# Design: Fix Photo Picker to Trimmer Video Loading

## Context
The app is failing at the most critical user flow: selecting a video from Photos and loading it into the TrimmerView. Analysis of crash logs shows "Too many open files" error causing Core Data store corruption, indicating resource leaks in the video loading pipeline. The previous implementation attempt was overly complex with verbose logging that obscured the real issues.

## Goals / Non-Goals
- **Goals**: Stable video loading from Photos picker to TrimmerView, resource leak elimination, minimalistic diagnostic logging, error recovery
- **Non-Goals**: Advanced video processing features, extensive logging framework, major architectural changes

## Decisions

### 1. Resource Management Strategy
**Decision**: Implement explicit resource cleanup patterns with automatic disposal
- Use `defer` blocks for guaranteed cleanup
- Implement `autoreleasepool` for video processing operations
- Add timeout-based resource release for video loading operations
- Track and limit concurrent file handles during video loading

**Alternatives considered**:
- Rely on ARC alone (insufficient for file handles)
- Implement complex resource pooling (over-engineering for current scope)

### 2. Core Data Stability
**Decision**: Add defensive error handling and recovery in PersistenceBridge
- Implement store loading retry logic with exponential backoff
- Add store validation before access attempts
- Provide fallback to in-memory store if persistent store fails
- Implement store migration handling without fatal errors

**Alternatives considered**:
- Continue with fatal error on store failure (blocks user completely)
- Implement complex store backup/restore (unnecessary complexity)

### 3. Minimalistic Logging Approach
**Decision**: Essential logging only for critical state transitions and errors
- Log only: app lifecycle, Core Data store events, video loading state changes, errors
- Use structured logging with emojis for visual scanning
- Remove verbose progress logging during video loading
- Add error correlation IDs for debugging

**Alternatives considered**:
- Comprehensive logging of all operations (creates noise, hides issues)
- No logging (makes debugging impossible)

### 4. Video Loading Simplification
**Decision**: Streamline PhotosPickerItem → Loading UI → TrimmerView flow
- Remove intermediate state variables that complicate the flow
- Use single async task with proper cancellation
- Implement immediate resource cleanup after successful/failed loading
- Simplify state management in AddMoveUnifiedState

**Alternatives considered**:
- Complex state machine with multiple intermediate states (overly complex)
- Parallel loading strategies (unnecessary for single video selection)

## Risks / Trade-offs

### Risk: Core Data store corruption during rapid video loading
**Mitigation**: Implement store validation, automatic cleanup, and graceful degradation to in-memory store

### Risk: Memory leaks from AVAsset references
**Mitigation**: Explicit asset cleanup, weak references where appropriate, memory pressure handling

### Trade-off: Reduced logging visibility vs. cleaner output
**Justification**: Essential logging provides actionable information without noise; verbose logging was hiding real issues

### Trade-off: Simpler state management vs. less granular control
**Justification**: Current complexity was causing bugs; simplified flow reduces failure points

## Migration Plan

1. **Phase 1**: Fix Core Data resource management issues
2. **Phase 2**: Eliminate video loading resource leaks
3. **Phase 3**: Implement minimalistic logging
4. **Phase 4**: Streamline user flow and strengthen error handling
5. **Phase 5**: Performance optimization and validation

**Rollback**: Each phase can be independently reverted; changes are additive and don't break existing functionality.

## Open Questions
- What is the optimal timeout for video loading operations before automatic cancellation?
- Should we implement video file size limits to prevent resource exhaustion?
- How should we handle iCloud video loading scenarios with poor network connectivity?