## ADDED Requirements

### Requirement: BreakDex Album Video Saving
The system SHALL save exported videos to a BreakDex album in the Photos library, creating the album if it doesn't exist or reusing an existing one.

#### Scenario: Save video without existing BreakDex album
- **WHEN** user taps Save button and no BreakDex album exists
- **THEN** create new BreakDex album and save video to it
- **AND** return successful save identifier

#### Scenario: Save video with existing BreakDex album
- **WHEN** user taps Save button and BreakDex album exists
- **THEN** save video to existing BreakDex album
- **AND** return successful save identifier

#### Scenario: Multiple saves prevent duplicate albums
- **WHEN** user saves multiple videos
- **THEN** reuse existing BreakDex album
- **AND** create no duplicate albums

### Requirement: Photos Framework Thread Safety
The system SHALL execute all Photos framework operations on the main thread with proper actor isolation.

#### Scenario: Save operation thread verification
- **WHEN** performing Photos library operations
- **THEN** execute on main thread
- **AND** maintain @MainActor isolation

## MODIFIED Requirements

### Requirement: Video Export and Save Flow
The system SHALL export trimmed videos and save them to the BreakDex album with proper error handling and user feedback.

#### Scenario: Complete save workflow
- **WHEN** user provides move name and taps Save
- **THEN** export video to temporary file
- **AND** save to BreakDex album (not general Photos)
- **AND** create Core Data move entry
- **AND** show success/error feedback
- **AND** navigate to appropriate screen

#### Scenario: Photos API context compliance
- **WHEN** accessing Photos framework APIs
- **THEN** perform all operations within performChanges block
- **AND** access placeholder properties only inside context
- **AND** handle completion outside context without Photos API calls

#### Scenario: Diagnostic logging for save operations
- **WHEN** performing save operations
- **THEN** log Photos operation entry/exit
- **AND** log context boundary transitions
- **AND** log thread verification
- **AND** log success/failure outcomes