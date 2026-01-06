## MODIFIED Requirements
### Requirement: Reliable Loading Workflow State Management
The add move workflow SHALL maintain reliable loading state management that handles user interactions like cancel-trim-select-new-clip without progress display issues.

#### Scenario: User cancels trimming during video loading
- **WHEN** user cancels trimming operation
- **THEN** workflow SHALL reset to clean state without affecting subsequent loading operations
- **AND** next video selection SHALL load with accurate progress display

#### Scenario: Multiple video selection attempts
- **WHEN** user selects multiple videos in sequence
- **THEN** each loading attempt SHALL display accurate progress percentages
- **AND** no stage synchronization issues SHALL carry over between sessions