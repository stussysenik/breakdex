## ADDED Requirements
### Requirement: Clickable Timeline Nodes
The timeline SHALL support tapping on individual move nodes to trigger video playback and selection state changes.

#### Scenario: Timeline node selection
- **WHEN** user taps on a timeline node representing a move
- **THEN** the node shall become visually active/selected
- **AND** activeIndex binding shall update to reflect selection
- **AND** corresponding move video shall begin loading

#### Scenario: Visual feedback for selection
- **WHEN** a timeline node is selected
- **THEN** selected node shall have distinct visual appearance (color, size, border)
- **AND** other nodes shall maintain default appearance
- **AND** selection state shall be immediately visible to user

### Requirement: Timeline Video Playback Integration
Timeline node selection SHALL trigger video playback for the corresponding move.

#### Scenario: Video loading on selection
- **WHEN** timeline node is selected
- **THEN** ComboViewModel.loadVideoForActiveMove() shall be called
- **AND** video asset for selected move shall be loaded and displayed
- **AND** loading state shall be shown during video preparation

#### Scenario: Video playback controls
- **WHEN** video is loaded from timeline selection
- **THEN** standard playback controls shall be available
- **AND** user can play, pause, and scrub through move video
- **AND** video shall be properly trimmed according to move's trimStartTime/trimEndTime

### Requirement: Timeline Navigation Integration
Timeline nodes SHALL support navigation to detailed move views using modern navigationDestination patterns.

#### Scenario: Navigate from timeline node
- **WHEN** user taps on selected timeline node (or long-presss any node)
- **THEN** navigationDestination(for: Move.self) shall be triggered
- **AND** detailed move view shall show video playback with full controls
- **AND** navigation shall maintain combo context for back navigation

#### Scenario: Timeline state preservation
- **WHEN** user navigates away from ComboDetailView and returns
- **THEN** timeline selection state shall be preserved
- **AND** active node shall remain selected
- **AND** video playback position shall be maintained if possible