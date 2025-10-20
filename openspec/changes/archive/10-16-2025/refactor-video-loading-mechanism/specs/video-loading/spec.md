## ADDED Requirements

### Requirement: Unified Video Loading Service
The system SHALL provide a single, simplified VideoLoadingService that handles all video asset loading operations without requiring multiple coordination layers.

#### Scenario: Successful video loading from PhotosPicker
- **WHEN** user selects a video from PhotosPicker
- **THEN** VideoLoadingService SHALL load the asset without spawning redundant coordination processes
- **AND** SHALL provide valid file URL (not /dev/null) for the loaded asset
- **AND** SHALL complete loading within 30 seconds on standard WiFi connection

#### Scenario: Loading state consistency
- **WHEN** video loading operation is in progress
- **THEN** loading state SHALL be atomically managed without race conditions
- **AND** SHALL prevent concurrent state transitions that cause blocking
- **AND** SHALL provide accurate progress updates throughout the loading process

### Requirement: Atomic State Transition Management
The system SHALL implement queue-based state transitions to prevent concurrent modification conflicts and ensure consistent loading states.

#### Scenario: Sequential state transitions
- **WHEN** multiple state updates are required during video loading
- **THEN** transitions SHALL be processed sequentially in a dedicated queue
- **AND** SHALL block any concurrent transition attempts until current transition completes
- **AND** SHALL log all transition attempts with correlation IDs for debugging

#### Scenario: State transition recovery
- **WHEN** a state transition fails or times out
- **THEN** system SHALL automatically rollback to previous stable state
- **AND** SHALL attempt recovery with exponential backoff
- **AND** SHALL provide user notification of the failure and retry options

### Requirement: Robust Asset URL Generation
The system SHALL generate proper file URLs for loaded video assets instead of placeholder /dev/null URLs.

#### Scenario: Temporary file URL generation
- **WHEN** video is loaded from PhotosPicker or file system
- **THEN** system SHALL create valid temporary file URL pointing to actual video data
- **AND** SHALL ensure the file exists and is accessible before returning URL
- **AND** SHALL clean up temporary files after successful asset creation

#### Scenario: Cloud asset URL handling
- **WHEN** video asset is stored in iCloud
- **THEN** system SHALL download asset to temporary location before generating URL
- **AND** SHALL handle network interruptions during download with retry logic
- **AND** SHALL provide meaningful progress updates during cloud download

### Requirement: Network-Aware Retry Mechanisms
The system SHALL implement intelligent retry logic that adapts to network conditions and asset types.

#### Scenario: Network failure recovery
- **WHEN** network connection is lost during video loading
- **THEN** system SHALL detect network failure within 5 seconds
- **AND** SHALL automatically pause loading operation
- **AND** SHALL resume loading when network connection is restored
- **AND** SHALL implement exponential backoff with maximum 3 retry attempts

#### Scenario: Cloud download optimization
- **WHEN** loading video from iCloud on cellular network
- **THEN** system SHALL warn user about potential data usage
- **AND** SHALL prioritize WiFi-only downloads for large files (>50MB)
- **AND** SHALL implement progressive download with resume capability

### Requirement: Simplified Progress Reporting
The system SHALL provide direct, reliable progress updates without complex debouncing mechanisms.

#### Scenario: Real-time progress updates
- **WHEN** video loading operation is active
- **THEN** system SHALL provide progress updates every 100ms or 5% change
- **AND** SHALL include meaningful status messages for each loading phase
- **AND** SHALL correlate all progress updates with unique operation ID

#### Scenario: Progress timeout detection
- **WHEN** progress hasn't updated for more than 10 seconds
- **THEN** system SHALL detect stalled loading operation
- **AND** SHALL attempt automatic recovery or timeout handling
- **AND** SHALL notify user of loading issues with retry options

### Requirement: Error Categorization and Recovery
The system SHALL categorize loading errors and provide appropriate recovery mechanisms.

#### Scenario: Recoverable error handling
- **WHEN** temporary network error occurs during loading
- **THEN** system SHALL categorize as recoverable error
- **AND** SHALL automatically retry with exponential backoff
- **AND** SHALL maintain user context and loading state during retry

#### Scenario: Non-recoverable error handling
- **WHEN** asset corruption or unsupported format is detected
- **THEN** system SHALL categorize as non-recoverable error
- **AND** SHALL provide clear error message to user
- **AND** SHALL offer alternatives (re-select video, convert format)

### Requirement: Asset Validation and Integrity
The system SHALL validate loaded video assets for integrity and playability.

#### Scenario: Asset format validation
- **WHEN** video asset is loaded
- **THEN** system SHALL validate video format compatibility
- **AND** SHALL check for video track presence and duration
- **AND** SHALL verify asset is playable before marking loading complete

#### Scenario: File integrity verification
- **WHEN** video file is copied to temporary location
- **THEN** system SHALL verify file integrity (checksum if possible)
- **AND** SHALL detect file corruption during transfer
- **AND** SHALL retry download if corruption is detected

### Requirement: Performance Optimization
The system SHALL optimize video loading performance for different device capabilities and network conditions.

#### Scenario: Memory-efficient loading
- **WHEN** loading large video files (>100MB)
- **THEN** system SHALL implement streaming loading to minimize memory usage
- **AND** SHALL monitor memory usage during loading
- **AND** SHALL provide fallback for low-memory devices

#### Scenario: Concurrent loading prevention
- **WHEN** user attempts to load multiple videos simultaneously
- **THEN** system SHALL queue loading requests
- **AND** SHALL provide clear indication of queue position
- **AND** SHALL allow user to cancel pending requests

### Requirement: Comprehensive Logging and Debugging
The system SHALL provide detailed logging for all loading operations with correlation tracking.

#### Scenario: Operation correlation tracking
- **WHEN** video loading operation starts
- **THEN** system SHALL generate unique correlation ID
- **AND** SHALL include correlation ID in all related log entries
- **AND** SHALL provide correlation ID to user for support requests

#### Scenario: Performance monitoring
- **WHEN** video loading completes
- **THEN** system SHALL log detailed performance metrics
- **AND** SHALL track loading time by phase and network condition
- **AND** SHALL identify performance bottlenecks for optimization