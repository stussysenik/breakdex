## ADDED Requirements

### Requirement: Visual Test Infrastructure

The system SHALL provide a visual testing infrastructure using native XCTest capabilities for TDD-driven UI development.

#### Scenario: Screenshot capture utility
- **GIVEN** a UI test is running
- **WHEN** the test calls the screenshot capture helper
- **THEN** a screenshot SHALL be captured of the current screen
- **AND** the screenshot SHALL be attached to the test results with a descriptive name
- **AND** the attachment SHALL be configured to persist after test completion

#### Scenario: Element screenshot capture
- **GIVEN** a specific UI element needs to be captured
- **WHEN** the test calls the element screenshot helper with an element reference
- **THEN** a screenshot of only that element SHALL be captured
- **AND** the screenshot SHALL be attached with the element identifier in the name

### Requirement: Design System Component Tests

The system SHALL provide isolated tests for each design system component to verify correct rendering.

#### Scenario: EmptyStateView component test
- **GIVEN** the DesignSystemComponentTests test class
- **WHEN** the EmptyStateView test is executed
- **THEN** the test SHALL verify the icon is displayed
- **AND** the test SHALL verify the title text matches expected content
- **AND** the test SHALL verify the description text is present
- **AND** a screenshot SHALL be captured for visual reference

#### Scenario: SectionHeaderView component test
- **GIVEN** the DesignSystemComponentTests test class
- **WHEN** the SectionHeaderView test is executed
- **THEN** the test SHALL verify the title is displayed
- **AND** the test SHALL verify the count badge shows correct value
- **AND** the test SHALL verify accessibility labels are set

#### Scenario: CardContainer component test
- **GIVEN** a view wrapped with CardContainer modifier
- **WHEN** the component test is executed
- **THEN** the test SHALL capture a screenshot showing the card styling
- **AND** the test SHALL verify the view has expected accessibility traits

#### Scenario: ProgressRingView component test
- **GIVEN** the DesignSystemComponentTests test class
- **WHEN** the ProgressRingView test is executed with various progress values
- **THEN** screenshots SHALL be captured at 0%, 50%, and 100% progress
- **AND** the test SHALL verify accessibility value matches the progress percentage

### Requirement: Empty State Screen Tests

The system SHALL provide tests verifying empty state rendering across all major screens.

#### Scenario: Arsenal empty moves test
- **GIVEN** no moves exist in the data store
- **WHEN** the Arsenal view is displayed
- **THEN** the test SHALL verify the empty state icon exists
- **AND** the test SHALL verify "No Moves Yet" text is displayed
- **AND** the test SHALL verify the CTA button is tappable
- **AND** a screenshot SHALL be captured of the empty state

#### Scenario: Arsenal empty combos test
- **GIVEN** no combos exist in the data store
- **WHEN** the Arsenal Combos section is displayed
- **THEN** the test SHALL verify the empty state is rendered
- **AND** the test SHALL verify "No Combos Yet" text is displayed

#### Scenario: Add Move initial state test
- **GIVEN** no video is selected
- **WHEN** the Add Move tab is displayed
- **THEN** the test SHALL verify the guidance empty state is shown
- **AND** the test SHALL verify the "Select a Clip" button exists
- **AND** a screenshot SHALL be captured

#### Scenario: Review empty state test
- **GIVEN** no moves exist for review
- **WHEN** the Review tab is displayed
- **THEN** the test SHALL verify an appropriate empty state is shown
- **AND** the test SHALL verify guidance text is displayed

### Requirement: Dark Mode Visual Parity Tests

The system SHALL provide tests ensuring visual consistency between light and dark modes.

#### Scenario: Light and dark mode screenshot comparison
- **GIVEN** a screen under test
- **WHEN** the dark mode parity test is executed
- **THEN** a screenshot SHALL be captured in light mode
- **AND** the app appearance SHALL be switched to dark mode
- **AND** a screenshot SHALL be captured in dark mode
- **AND** both screenshots SHALL be attached for manual comparison

#### Scenario: Dark mode contrast verification
- **GIVEN** the app is in dark mode
- **WHEN** the contrast verification test runs
- **THEN** text elements SHALL have sufficient contrast against backgrounds
- **AND** interactive elements SHALL be clearly distinguishable

### Requirement: Accessibility Visual Tests

The system SHALL provide tests verifying accessibility-related visual requirements.

#### Scenario: High contrast mode test
- **GIVEN** the accessibility visual tests are running
- **WHEN** high contrast colors are applied
- **THEN** screenshots SHALL be captured showing high contrast appearance
- **AND** the test SHALL verify state colors use high contrast variants

#### Scenario: Dynamic Type scaling test
- **GIVEN** the dynamic type test is running
- **WHEN** the preferred content size is set to accessibility sizes
- **THEN** screenshots SHALL be captured at various type sizes
- **AND** the test SHALL verify text remains readable and untruncated
- **AND** the test SHALL verify layouts adapt appropriately

#### Scenario: Touch target size verification
- **GIVEN** interactive elements exist on screen
- **WHEN** the touch target test runs
- **THEN** the test SHALL verify all buttons have minimum 44x44pt touch targets
- **AND** violations SHALL be reported with element identifiers

### Requirement: Test-First Development Workflow

The system SHALL support a test-first development workflow for UI changes.

#### Scenario: Failing test for new UI element
- **GIVEN** a new UI element is planned
- **WHEN** a test is written asserting the element exists
- **THEN** the test SHALL fail until the element is implemented
- **AND** the test failure message SHALL clearly indicate what is missing

#### Scenario: Visual regression detection
- **GIVEN** reference screenshots exist from previous test runs
- **WHEN** a UI change is made and tests are re-run
- **THEN** new screenshots SHALL be captured
- **AND** screenshots SHALL be available in test results for comparison
- **AND** significant visual changes SHALL be reviewable before merge
