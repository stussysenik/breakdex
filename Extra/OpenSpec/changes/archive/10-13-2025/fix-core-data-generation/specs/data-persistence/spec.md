## MODIFIED Requirements
### Requirement: Core Data Entity Property Generation
The Core Data system SHALL generate corresponding Swift properties for all entity attributes defined in the data model using the two-file generation pattern.

#### Scenario: Move entity properties generation
- **WHEN** a Move entity is defined with attributes learningState and photosIdentifier
- **THEN** BOTH Move+CoreDataClass.swift AND Move+CoreDataProperties.swift files SHALL exist
- **AND** the properties SHALL be declared with @NSManaged in the Properties file
- **AND** the properties SHALL be of correct types (String for both attributes)

#### Scenario: Code compilation success
- **WHEN** PersistenceBridge.swift accesses move.learningState or move.photosIdentifier
- **THEN** the project SHALL compile without "Value of type 'Move' has no member" errors
- **AND** the properties SHALL be accessible for both read and write operations

#### Scenario: Missing Core Data properties file recovery
- **WHEN** Core Data properties are missing but entity attributes exist in the model
- **THEN** manually create the missing {Entity}+CoreDataProperties.swift file
- **AND** include all @NSManaged properties matching the entity attributes
- **AND** include proper fetchRequest() method and relationship accessors
- **AND** ensure the file has proper target membership in Xcode