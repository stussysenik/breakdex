## Context
The current video loading pipeline works correctly for initial video selection, but fails to preserve state across navigation events. When users navigate away from trimming or background the app, the loaded video asset and player state are lost, requiring complete reinitialization. This is particularly problematic for large video files and iCloud videos that require significant download time.

## Goals / Non-Goals
- **Goals**:
  - Preserve video state across tab navigation and app lifecycle events
  - Implement proper cancel functionality that returns to initial state
  - Support large video files (up to 30 minutes) efficiently
  - Add 30-minute video duration validation with user feedback
  - Maintain existing excellent architecture
  - Add minimal diagnostic logging for debugging
- **Non-Goals**:
  - Major refactoring of existing well-designed components
  - Complex caching mechanisms beyond basic state preservation
  - Background video processing
  - Video transcoding or compression
  - Architectural changes to working features

## Decisions
- **Decision**: Use simple WorkflowState enum for persistence
  - **Rationale**: Minimal complexity, reliable, follows existing patterns
  - **Alternatives considered**: Complex caching, Core Data persistence
- **Decision**: Implement suspend/restore pattern in AddMoveViewModel
  - **Rationale**: Leverages existing ViewModel, follows iOS best practices
  - **Alternatives considered**: Separate manager classes, background services
- **Decision**: Keep existing architecture intact
  - **Rationale**: Current architecture is already excellent and well-tested
  - **Alternatives considered**: Major refactoring, new manager classes
- **Decision**: Add minimal diagnostic logging only
  - **Rationale**: Existing logging is comprehensive; only need workflow state visibility
  - **Alternatives considered**: Comprehensive telemetry, performance metrics

## Risks / Trade-offs
- **Memory usage** → Implement progressive loading for large files, clean up unused assets
- **Complexity** → Keep persistence logic simple and focused on workflow state, not data management
- **Performance** → Use lazy restoration only when needed, avoid premature initialization
- **Implementation risk** → Minimal changes reduce risk of breaking existing functionality

## Migration Plan
1. Add WorkflowState enum to AddMoveViewModel without breaking existing functionality
2. Implement suspend/restore methods alongside existing workflow logic
3. Add lifecycle observers while maintaining current behavior
4. Update cancel functionality after persistence is working
5. Add large video validation as separate enhancement
6. Final testing to ensure existing architecture remains intact

## Open Questions
- How to handle memory pressure with very large video files?
- Should we implement timeout for iCloud video downloads?
- What's the optimal persistence duration for video assets?