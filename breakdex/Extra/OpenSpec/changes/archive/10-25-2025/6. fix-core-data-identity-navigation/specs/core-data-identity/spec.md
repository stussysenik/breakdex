## ADDED Requirements
### Requirement: Core Data Entity Identity Assignment
All Core Data entities SHALL have unique identifiers assigned during creation to ensure SwiftUI ForEach stability and navigation reliability.

#### Scenario: Combo Creation with UUID Assignment
- **WHEN** user creates and saves a new combo through ComboViewModel.saveCombo()
- **THEN** the new Combo entity SHALL have a non-nil UUID assigned to its id property
- **AND** all associated ComboMove entities SHALL also have non-nil UUID identifiers
- **AND** Core Data save operation SHALL complete without identity-related errors
- **AND** subsequent ForEach operations SHALL use stable identifiers for list rendering

#### Scenario: ForEach Identification Stability
- **WHEN** ComboListView renders the combo list using ForEach
- **THEN** no combo entity SHALL have a nil UUID identifier
- **AND** ForEach SHALL NOT generate "ID nil occurs multiple times" warnings
- **AND** list items SHALL maintain stable positions during data updates
- **AND** navigation interactions SHALL work reliably for all combo items

#### Scenario: Backward Compatibility for Existing Data
- **WHEN** the app loads existing combo entities that may have nil UUID identifiers
- **THEN** the system SHALL gracefully handle nil identifiers using objectID as fallback
- **AND** existing combos SHALL remain accessible and navigable
- **AND** new combo creation SHALL always assign UUID identifiers

## MODIFIED Requirements
### Requirement: Core Data Entity Creation Pattern
The ComboViewModel SHALL enforce proper identity assignment during entity creation following Apple's recommended patterns.

#### Scenario: Combo Entity Initialization
- **WHEN** ComboViewModel.saveCombo() creates a new Combo entity
- **THEN** newCombo.id SHALL be assigned a valid UUID immediately after entity creation
- **AND** all ComboMove entities SHALL have their id property assigned UUID values during iteration
- **AND** the assignment SHALL occur before any Core Data relationship is established
- **AND** successful UUID assignment SHALL be logged for debugging purposes

#### Scenario: Entity Identity Validation
- **WHEN** Core Data entities are created or modified
- **THEN** the system SHALL validate that all entities have non-nil identifiers before save operations
- **AND** any entity with nil identifier SHALL trigger automatic UUID assignment
- **AND** validation failures SHALL be logged with specific entity details
- **AND** the save operation SHALL not proceed until identity issues are resolved