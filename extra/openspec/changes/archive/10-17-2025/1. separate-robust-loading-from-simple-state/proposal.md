## Why
The current video loading system has 1800+ lines of complex state management (AtomicStateCoordinator + StateValidationMiddleware + UnifiedState) for what should be a simple user flow: select photo → see progress → get ready to trim. While the robust loading engine is necessary for handling iCloud videos, large files, and network conditions, the state management complexity is excessive and violates SRP.

## What Changes
- Extract robust video loading logic into a focused, self-contained service that handles all iCloud/network/large file scenarios
- Replace complex atomic state coordination with simple SwiftUI state management for UI states
- Create clean separation between robust loading engine (internal complexity) and simple state interface (external simplicity)
- Maintain all current functionality: iCloud downloads, progress tracking, error handling, memory management
- **BREAKING**: Refactor state management architecture from atomic coordination to simple state

## Impact
- Affected specs: video-loading, add-move-flow, state-management
- Affected code: VideoLoadingService (1550 lines), AtomicStateCoordinator (421 lines), StateValidationMiddleware (721 lines), UnifiedState (703 lines)
- Target reduction: ~70% reduction in state management complexity while maintaining 100% of robust loading features
- UI remains unchanged: Users still see progress and get ready-to-trim videos reliably