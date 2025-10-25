## REMOVED Requirements
### Requirement: Custom Hashable Conformance for Core Data Entities
Core Data entities SHALL override hash and isEqual methods for custom equality logic.

**Reason**: Apple explicitly forbids overriding hash and isEqual on NSManagedObject as Core Data relies on internal object management. This causes app crashes during entity creation.

**Migration**: Remove all hash and isEqual overrides from Core Data classes and rely on Core Data's built-in objectID-based identity management.

## MODIFIED Requirements
### Requirement: Core Data Entity Identity Management
Core Data entities SHALL use Apple's built-in identity management through NSManagedObjectID for equality comparisons and collection operations.

#### Scenario: Combo creation without crash
- **WHEN** user creates and saves a new combo
- **THEN** the app shall not crash due to illegal hash override
- **AND** the combo shall be successfully persisted to Core Data

#### Scenario: Object equality comparison
- **WHEN** code needs to compare two Core Data entities
- **THEN** use objectID == objectID for equality checks
- **AND** Core Data's internal identity management shall handle comparisons correctly

#### Scenario: Collection operations with Core Data entities
- **WHEN** using Core Data entities in Sets, Dictionaries, or other collections
- **THEN** collections shall work correctly using objectID-based hashing
- **AND** no custom hash implementation shall be required

## ADDED Requirements
### Requirement: Core Data Relationship Fetching
The system SHALL efficiently fetch related entities using NSPredicate with relationship filters.

#### Scenario: Loading combo moves
- **WHEN** displaying combo details or calculating move count
- **THEN** use NSPredicate(format: "combo == %@", combo) to fetch related ComboMove entities
- **AND** results shall be sorted by sequenceIndex for proper ordering

#### Scenario: Combo learning state calculation
- **WHEN** determining a combo's overall learning state
- **THEN** aggregate learning states from all related moves
- **AND** return MASTERY only if all moves are in MASTERY state