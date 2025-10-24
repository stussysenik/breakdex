## Context

Based on diagnostic logs and Apple Photos framework documentation, the app crashes with `NSInternalInconsistencyException` because MovePersistenceService accesses `placeholderForCreatedAsset.localIdentifier` outside the `PHPhotoLibrary.performChanges` context block. The current implementation also saves videos to the general Photos library instead of a BreakDex-specific album, creating a poor user experience.

### Root Cause Analysis (Line-by-Line Evidence)

**Current Crash Pattern:**
1. Line 1215: `🔬 PHOTOS_CONTEXT: Exiting performChanges block - changes queued` ✅
2. Line 1221: `🔬 PHOTOS_CONTEXT: About to access placeholderForCreatedAsset in completion handler` ❌
3. Line 1222: `<NSXPCConnection> Exception caught during invocation of reply block to message 'PhotoKitAddService_applyChangesRequest'`
4. Line 1224: `Exception: This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:]`

The violation occurs in MovePersistenceService.swift:339 where `placeholder.localIdentifier` is accessed in the completion handler rather than inside the performChanges block.

## Goals / Non-Goals

- Goals:
  - Fix Photos API context violation to prevent crashes
  - Ensure videos save to BreakDex album (create if needed, reuse if exists)
  - Maintain thread safety with @MainActor
  - Preserve existing error handling patterns
- Non-Goals:
  - Redesign the entire save workflow
  - Change video export functionality
  - Modify Core Data structure

## Decisions

- Decision: Use PhotoKitService for all album operations instead of MovePersistenceService direct Photos access
  - Why: PhotoKitService already implements correct atomic operations and duplicate prevention
- Decision: Move placeholder.localIdentifier access inside performChanges block
  - Why: Apple Photos framework requires all Photos API calls within performChanges context
- Decision: Add @MainActor to all PhotoKit operations
  - Why: Apple documentation requires main thread execution for Photos framework
- Decision: Keep existing video export flow intact
  - Why: Export functionality works correctly; only Photos integration needs fixing

## Alternatives considered

- Alternative 1: Fix only the context violation without album integration
  - Rejected: Would save to wrong location (general Photos instead of BreakDex album)
- Alternative 2: Create entirely new save service
  - Rejected: Over-engineering; PhotoKitService already has correct implementation
- Alternative 3: Use two-step save (create asset, then add to album)
  - Rejected: Atomic single-operation prevents race conditions and empty albums

## Risks / Trade-offs

- Risk: Breaking existing MovePersistenceService API contracts
  - Mitigation: Update all callers to use new method signature
- Risk: PhotoKitService thread safety issues
  - Mitigation: Add @MainActor annotations and validate with diagnostics
- Trade-off: Slightly more complex service collaboration
  - Acceptance: Improved reliability and correct behavior worth the complexity

## Migration Plan

1. Fix MovePersistenceService Photos API violation
2. Update MoveSaver to use PhotoKitService instead of MovePersistenceService
3. Add @MainActor annotations to PhotoKitService
4. Add minimal diagnostic logging
5. Test end-to-end save flow
6. Verify no duplicate albums created

Rollback: Revert MovePersistenceService to direct Photos access if issues arise.

## Open Questions

- What specific error messages should users see if album creation fails?
- Should we provide fallback to general Photos library if BreakDex album creation fails?