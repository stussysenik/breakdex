# Change: Refine UI Consistency with TDD-Driven Visual Testing

## Why

The Breakdex app has functional screens but inconsistent visual presentation across views. Empty states are sparse with no user guidance, navigation patterns vary between screens, and the learning-focused purpose isn't reinforced through visual hierarchy. A TDD approach using XCTest snapshot and UI testing will ensure visual consistency is maintained as the UI evolves.

**Current Issues Observed:**
- Arsenal screen shows plain "MOVES" / "COMBOS" text without visual hierarchy or engaging empty states
- Add Move screen displays only a button with no context about the workflow
- Review screen lists learning states without visual engagement or progress indication
- Navigation breadcrumbs appear inconsistently
- Card and container styling varies across screens
- Empty states lack illustrations, guidance, or calls-to-action

## What Changes

### UI Design System Improvements
- **ADDED**: Standardized empty state component with icon, title, description, and optional CTA
- **ADDED**: Card container component with consistent shadow, border radius, and padding
- **ADDED**: Section header component with title, optional subtitle, and count badge
- **ADDED**: Progress ring component for visual learning progress
- **MODIFIED**: Arsenal view to use section headers and engaging empty states
- **MODIFIED**: Add Move view to show workflow steps and guidance
- **MODIFIED**: Review view to display visual progress indicators

### TDD Testing Infrastructure
- **ADDED**: Snapshot testing capability using XCTest attachments for visual regression
- **ADDED**: Visual consistency test suite covering all major screens
- **ADDED**: Empty state rendering tests for each view
- **ADDED**: Component isolation tests for design system components
- **ADDED**: Dark mode visual parity tests
- **ADDED**: Accessibility visual tests (high contrast, dynamic type)

## Impact

- **Affected specs**: ui-design-system (new), ui-testing (new)
- **Affected code**:
  - `Features/Shared/UI/Components/` - New shared components
  - `Features/Arsenal/Views/` - Arsenal view updates
  - `Features/AddMove/Views/` - Add Move view updates
  - `Features/Review/Views/` - Review view updates
  - `breakdexUITests-01-20-26/` - New visual test files
- **User impact**: More polished, consistent UI with better empty state guidance
- **Developer impact**: TDD workflow ensures visual consistency through automated testing
