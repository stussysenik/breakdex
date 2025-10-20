## Context
The current video trimming interface shows performance degradation with excessive seeking operations (100+ seeks during trimming), inconsistent UI spacing, and poor user experience. The app needs a professional trimming component that matches iOS system standards while maintaining performance.

## Goals / Non-Goals
- Goals: Professional trimming interface, smooth performance, iOS 18 compliance
- Non-Goals: Complex video editing features, custom animation effects

## Decisions
- Decision: Use AVPlayerItem.seek(to:toleranceBefore:toleranceAfter:) with high tolerances for performance
- Decision: Implement custom timeline with SwiftUI gesture handling for responsiveness
- Decision: Use 8-point grid system following Apple HIG guidelines
- Alternatives considered: Third-party libraries (too heavy), UIKit implementation (not SwiftUI native)

## Risks / Trade-offs
- Performance risk: Frame extraction could be memory intensive → Mitigation: Implement lazy loading and caching
- Complexity risk: Custom timeline may be complex → Mitigation: Start with minimal viable implementation
- Compatibility risk: iOS 18 specific features → Mitigation: Use backwards-compatible APIs

## Migration Plan
- Phase 1: Create new timeline component alongside existing
- Phase 2: Gradually replace trimming functionality
- Phase 3: Remove deprecated components after validation

## Open Questions
- Optimal frame extraction rate for timeline preview
- Maximum video size supported without performance degradation
- Accessibility requirements for timeline interactions