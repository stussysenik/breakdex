## ADDED Requirements

### Requirement: Empty State Component

The system SHALL provide a reusable `EmptyStateView` component that displays a consistent empty state across all screens.

#### Scenario: Empty state displays icon, title, and description
- **GIVEN** a view with no content to display
- **WHEN** the EmptyStateView is rendered
- **THEN** the component SHALL display an SF Symbol icon, a title, and a description text
- **AND** the content SHALL be vertically centered in the available space

#### Scenario: Empty state with call-to-action button
- **GIVEN** an EmptyStateView configured with a CTA button
- **WHEN** the component is rendered
- **THEN** a primary-styled button SHALL appear below the description
- **AND** tapping the button SHALL execute the provided action

#### Scenario: Empty state accessibility
- **GIVEN** VoiceOver is enabled
- **WHEN** the user focuses on EmptyStateView
- **THEN** the icon, title, and description SHALL be read as a combined accessible label
- **AND** the CTA button SHALL be independently focusable with its own label

### Requirement: Section Header Component

The system SHALL provide a reusable `SectionHeaderView` component for consistent section labeling with optional count badges.

#### Scenario: Section header displays title and count
- **GIVEN** a section with items to display
- **WHEN** the SectionHeaderView is rendered with a title and count
- **THEN** the title SHALL be displayed in `titleSmall` typography
- **AND** a count badge SHALL appear to the right showing the number of items
- **AND** the count SHALL use `bodySmall` typography with `textSecondary` color

#### Scenario: Section header with trailing action
- **GIVEN** a SectionHeaderView configured with a trailing action
- **WHEN** the component is rendered
- **THEN** an action button or icon SHALL appear on the trailing edge
- **AND** tapping the action SHALL execute the provided closure

#### Scenario: Section header without count
- **GIVEN** a SectionHeaderView configured without a count value
- **WHEN** the component is rendered
- **THEN** only the title SHALL be displayed
- **AND** no count badge SHALL appear

### Requirement: Card Container Styling

The system SHALL provide a `CardContainer` view modifier that applies consistent card styling to any view.

#### Scenario: Card container applies visual styling
- **GIVEN** a view wrapped with the CardContainer modifier
- **WHEN** the view is rendered
- **THEN** the view SHALL have `backgroundSecondary` background color
- **AND** the view SHALL have `mediumRadius` (12pt) corner radius
- **AND** the view SHALL have consistent internal padding of `Spacing.md` (16pt)

#### Scenario: Card container in dark mode
- **GIVEN** the app is in dark mode
- **WHEN** a CardContainer-styled view is rendered
- **THEN** the background color SHALL adapt to the dark mode variant
- **AND** visual contrast SHALL meet WCAG 2.2 AA requirements

### Requirement: Progress Ring Component

The system SHALL provide a `ProgressRingView` component for displaying circular progress indicators.

#### Scenario: Progress ring displays percentage
- **GIVEN** a ProgressRingView with a progress value between 0 and 1
- **WHEN** the component is rendered
- **THEN** a circular ring SHALL display with a filled arc proportional to the progress value
- **AND** the percentage SHALL be displayed in the center of the ring

#### Scenario: Progress ring with custom colors
- **GIVEN** a ProgressRingView configured with track and fill colors
- **WHEN** the component is rendered
- **THEN** the background ring SHALL use the track color
- **AND** the filled portion SHALL use the fill color

#### Scenario: Progress ring accessibility
- **GIVEN** VoiceOver is enabled
- **WHEN** the user focuses on a ProgressRingView
- **THEN** the progress SHALL be announced as a percentage value
- **AND** the component SHALL have an appropriate accessibility trait

### Requirement: Arsenal View Empty States

The system SHALL display engaging empty states in the Arsenal view when no moves or combos exist.

#### Scenario: Empty moves section
- **GIVEN** the user has no moves saved
- **WHEN** the Arsenal Moves section is displayed
- **THEN** an EmptyStateView SHALL appear with a move-related icon
- **AND** the title SHALL be "No Moves Yet"
- **AND** the description SHALL guide the user to add their first move
- **AND** a CTA button SHALL navigate to the Add Move flow

#### Scenario: Empty combos section
- **GIVEN** the user has no combos saved
- **WHEN** the Arsenal Combos section is displayed
- **THEN** an EmptyStateView SHALL appear with a combo-related icon
- **AND** the title SHALL be "No Combos Yet"
- **AND** the description SHALL guide the user to create their first combo

### Requirement: Add Move View Guidance

The system SHALL display guidance content in the Add Move view explaining the workflow.

#### Scenario: Initial add move state
- **GIVEN** the user navigates to the Add Move tab
- **WHEN** no video is selected
- **THEN** an EmptyStateView SHALL display with a video-related icon
- **AND** the description SHALL explain the steps: select video, trim, name, save
- **AND** a prominent "Select a Clip" button SHALL be displayed

#### Scenario: Workflow step indicator
- **GIVEN** the user is in the Add Move flow
- **WHEN** any step of the flow is active
- **THEN** a step indicator SHALL show the current position (e.g., "Step 2 of 4")
- **AND** completed steps SHALL be visually distinguished from pending steps

### Requirement: Review View Progress Display

The system SHALL display visual progress indicators in the Review view.

#### Scenario: Overall learning progress
- **GIVEN** the user has moves in various learning states
- **WHEN** the Review view is displayed
- **THEN** a ProgressRingView SHALL show overall mastery percentage
- **AND** the ring SHALL use the mastery color for the filled portion

#### Scenario: Learning state cards
- **GIVEN** the Review view displays learning state categories
- **WHEN** each category row is rendered
- **THEN** the row SHALL use CardContainer styling
- **AND** a mini progress indicator SHALL show the proportion of that state
