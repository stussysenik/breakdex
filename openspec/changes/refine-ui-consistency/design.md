## Context

Breakdex is a breaking/b-boy move tracking application that helps users catalog moves, create combos, and practice through spaced repetition review. The app already has a solid MVVM architecture and design system foundation (colors, typography, spacing) but the views don't consistently apply these patterns.

**Stakeholders**: B-boy/b-girl users who want an intuitive, visually consistent experience for tracking their progress.

**Constraints**:
- Must work with existing Core Data models and MVVM architecture
- Must maintain WCAG 2.2 AA accessibility compliance
- Tests must run in CI without external snapshot libraries
- Must support iOS 17+ and both light/dark modes

## Goals / Non-Goals

**Goals**:
- Establish reusable UI components that enforce visual consistency
- Create TDD workflow where visual tests are written before UI implementation
- Improve empty state UX across all major screens
- Ensure visual parity between light and dark modes
- Enable fast iteration on UI with confidence through automated visual testing

**Non-Goals**:
- Complete UI redesign or new branding
- Adding new features or screens
- Changing navigation architecture
- Third-party snapshot testing libraries (use native XCTest)

## Decisions

### Decision 1: Native XCTest Snapshot Testing over Third-Party Libraries

**What**: Use XCTest's `XCTAttachment` API to capture and compare screenshots rather than external libraries like SnapshotTesting.

**Why**:
- No additional dependencies to manage
- Works seamlessly with Xcode Cloud and standard CI
- Attachments are viewable directly in Xcode test reports
- Full control over comparison logic

**Implementation**:
```swift
// Capture reference image
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "EmptyArsenalView-Light"
attachment.lifetime = .keepAlways
add(attachment)
```

### Decision 2: Component-Based Design System Extension

**What**: Extend the existing DesignSystem.swift with reusable view components (not just tokens).

**Why**:
- Existing system has colors, fonts, spacing but lacks composed components
- Components enforce consistency better than documentation
- SwiftUI's composability makes this natural

**Components to Add**:
1. `EmptyStateView` - Icon + title + description + optional button
2. `SectionHeaderView` - Title + count badge + optional action
3. `CardContainer` - Consistent card styling modifier
4. `ProgressRingView` - Circular progress for learning stats

### Decision 3: Test-First Visual Development Workflow

**What**: Write UI tests that assert expected visual state BEFORE implementing the UI changes.

**Why**:
- Forces clear definition of expected behavior
- Prevents regression during iteration
- Documents expected visual states
- Catches dark mode and accessibility issues early

**Workflow**:
1. Write test asserting element exists with correct accessibility label
2. Run test (fails - red)
3. Implement UI component
4. Run test (passes - green)
5. Capture screenshot attachment for visual reference
6. Refactor if needed

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Screenshot tests can be flaky across iOS versions | Pin tests to specific simulator/iOS version in CI |
| Reference images bloat repository | Store attachments in test results, not committed files |
| Over-testing slows development | Focus on key screens and states, not every permutation |
| Native snapshot comparison is manual | Implement simple pixel comparison helper or rely on human review |

## Migration Plan

1. **Phase 1 - Foundation**: Add design system components without changing existing views
2. **Phase 2 - Tests**: Write failing UI tests for expected empty states and layouts
3. **Phase 3 - Arsenal**: Update Arsenal view, make tests pass
4. **Phase 4 - Add Move**: Update Add Move view, make tests pass
5. **Phase 5 - Review**: Update Review view, make tests pass
6. **Phase 6 - Polish**: Dark mode parity, accessibility verification

**Rollback**: Each phase is independent; can ship incrementally.

## Open Questions

1. Should we add visual diff tooling for CI (e.g., Percy, Chromatic equivalent for iOS)?
2. What's the acceptable visual difference threshold for pixel comparison?
3. Should empty state illustrations be custom or SF Symbols?
