## 1. Design System Components

- [x] 1.1 Create `EmptyStateView` component with icon, title, description, and optional CTA button
- [x] 1.2 Create `SectionHeaderView` component with title, count badge, and optional trailing action
- [x] 1.3 Create `CardContainer` view modifier for consistent card styling
- [x] 1.4 Create `ProgressRingView` component for circular progress display
- [x] 1.5 Add new components to DesignSystem.swift exports
- [x] 1.6 Document component usage in code comments

## 2. Visual Testing Infrastructure

- [x] 2.1 Create `VisualTestHelpers.swift` with screenshot capture and attachment utilities
- [x] 2.2 Create `DesignSystemComponentTests.swift` for isolated component testing
- [x] 2.3 Create `EmptyStateTests.swift` for empty state rendering across all screens
- [x] 2.4 Create `DarkModeParityTests.swift` for light/dark mode visual comparison
- [x] 2.5 Create `AccessibilityVisualTests.swift` for high contrast and dynamic type
- [x] 2.6 Update test target configuration for visual test organization

## 3. Arsenal View Refinement

- [x] 3.1 Write failing tests for Arsenal empty state with EmptyStateView
- [x] 3.2 Write failing tests for Moves section header with count badge
- [x] 3.3 Write failing tests for Combos section header with count badge
- [x] 3.4 Implement Arsenal empty state using EmptyStateView component
- [x] 3.5 Implement section headers using SectionHeaderView component
- [x] 3.6 Verify all Arsenal visual tests pass

## 4. Add Move View Refinement

- [x] 4.1 Write failing tests for Add Move guidance empty state
- [x] 4.2 Write failing tests for workflow step indicators
- [x] 4.3 Implement Add Move empty state with workflow description
- [x] 4.4 Add step indicator showing current position in add flow
- [x] 4.5 Verify all Add Move visual tests pass

## 5. Review View Refinement

- [x] 5.1 Write failing tests for Review progress visualization
- [x] 5.2 Write failing tests for learning state cards with progress rings
- [x] 5.3 Implement ProgressRingView in Review header showing overall progress
- [x] 5.4 Update learning state rows to use CardContainer styling
- [x] 5.5 Add visual progress indicators to each learning state
- [x] 5.6 Verify all Review visual tests pass

## 6. Polish and Verification

- [x] 6.1 Run full visual test suite and capture reference screenshots
- [x] 6.2 Verify dark mode parity across all updated screens
- [x] 6.3 Verify WCAG 2.2 AA compliance with accessibility tests
- [x] 6.4 Test on multiple device sizes (iPhone SE, iPhone 16 Pro, iPad)
- [x] 6.5 Update existing UI tests if element identifiers changed
- [x] 6.6 Document visual testing workflow in README or CONTRIBUTING
