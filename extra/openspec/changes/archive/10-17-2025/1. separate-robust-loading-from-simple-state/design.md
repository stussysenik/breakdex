## Context
The BreakingFlashcards video flashcard app currently uses enterprise-level state management complexity (1800+ lines) for a simple user flow. The robust loading features are essential for handling iCloud videos, large files, and network conditions, but the state coordination layer is over-engineered for the use case.

## Goals / Non-Goals
- Goals: Maintain 100% robust loading functionality while reducing state management complexity by 70%
- Goals: Simple external API that hides internal complexity using iOS 18 best practices
- Goals: Follow SRP with focused, single-responsibility components
- Goals: Proper encapsulation and complete cleanup of unnecessary files
- Non-Goals: Remove any robust loading capabilities (iCloud, large files, network handling)
- Non-Goals: Change user experience or progress feedback
- Non-Goals: Reduce video loading reliability
- Non-Goals: Leave any legacy files or references in the codebase

## Decisions
- Decision: Extract robust loading logic into RobustVideoLoader service that maintains all current capabilities
- Decision: Replace atomic state coordination with simple @State and @StateObject in view models
- Decision: Create facade pattern for loading service - complex internals, simple external interface
- Decision: Keep all error handling, progress tracking, and recovery mechanisms within the robust loader
- Decision: Use iOS 18 Swift 6 async/await with structured concurrency for all async operations
- Decision: Implement proper temporary file management using NSTemporaryDirectory() and automatic cleanup
- Decision: Complete removal and cleanup of all legacy components (AtomicStateCoordinator, StateValidationMiddleware, UnifiedState)
- Alternatives considered:
  - Keep current architecture (rejected: over-engineered for use case)
  - Remove all complexity (rejected: would break iCloud and large file handling)
  - Incremental simplification (rejected: architectural debt requires clear separation)

## Risks / Trade-offs
- Risk: Refactoring may introduce regressions in loading behavior → Mitigation: Comprehensive testing of iCloud scenarios
- Risk: Hidden complexity may make debugging harder → Mitigation: Clear logging and well-documented internal interfaces
- Trade-off: More code in the loader service to maintain simplicity outside → Acceptable: complexity is localized and justified
- Trade-off: Less visibility into loading state transitions → Acceptable: UI only needs basic loading/ready/failed states

## Migration Plan
1. Create new RobustVideoLoader service with all current loading capabilities using iOS 18 best practices
2. Create simple state management interface using SwiftUI @State and Swift 6 async/await
3. Update AddMoveViewModel to use simple state with robust loader behind the scenes
4. Implement proper temporary file management and cleanup procedures
5. Completely remove AtomicStateCoordinator, StateValidationMiddleware, and UnifiedState files
6. Remove all references to deleted components from build phases and imports
7. Test all scenarios: local videos, iCloud videos, large files, network conditions
8. Verify user experience remains identical and no temporary files are left behind

## Open Questions
- Should the robust loader expose progress events or just basic states? (Decision: Expose detailed progress for UI feedback)
- How should error handling be presented to the view layer? (Decision: Simple LoadingError enum with user-friendly messages)
- Do we need to maintain backward compatibility during migration? (Decision: No, this is internal architecture change)