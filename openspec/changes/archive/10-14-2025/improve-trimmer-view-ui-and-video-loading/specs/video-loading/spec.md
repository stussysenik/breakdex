## ADDED Requirements

### Requirement: File Size Display in Loading UI
The system SHALL display video file size information during loading to set user expectations about loading times.

#### Scenario: File size shown during loading
- **WHEN** video loading begins
- **THEN** the system displays the file size (e.g., "26.5 MB") in the loading UI
- **AND** shows estimated loading time based on file size and network conditions

### Requirement: Network-Resilient Loading
The system SHALL provide reliable video loading under both mobile network and WiFi conditions with automatic retry mechanisms.

#### Scenario: Loading under mobile network
- **WHEN** user loads video on mobile network
- **THEN** the system adapts loading strategy for network conditions
- **AND** provides progress updates appropriate for network speed

#### Scenario: Loading failure recovery
- **WHEN** video loading fails due to network issues
- **THEN** the system automatically retries with exponential backoff
- **AND** provides clear feedback about retry attempts

### Requirement: Enhanced Progress Indication
The system SHALL ensure loading progress bar always advances smoothly and never appears stuck.

#### Scenario: Smooth progress indication
- **WHEN** video is loading
- **THEN** the progress bar advances continuously from 0% to 100%
- **AND** never stalls at intermediate percentages
- **AND** provides phase-specific progress updates

## MODIFIED Requirements

### Requirement: Video Loading State Management
The system SHALL provide comprehensive video loading state management with fault-tolerant error handling and detailed progress tracking across all loading phases including iCloud downloads, network monitoring, and file validation.

#### Scenario: Loading completion with video display
- **WHEN** video loading completes successfully
- **THEN** the system transitions from loading state to ready state
- **AND** ensures the video is properly displayed in the preview area
- **AND** updates UI to show video is ready for trimming

#### Scenario: Enhanced loading phase tracking
- **WHEN** video loading progresses through different phases
- **THEN** the system provides detailed status messages for each phase
- **AND** displays file size information to manage user expectations
- **AND** shows estimated time remaining based on current progress