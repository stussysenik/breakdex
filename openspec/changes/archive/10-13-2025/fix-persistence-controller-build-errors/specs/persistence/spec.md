## MODIFIED Requirements
### Requirement: Core Data Persistence Layer
The system SHALL provide a clean, unambiguous Core Data persistence layer with proper type safety and no conflicting definitions.

#### Scenario: Successful compilation
- **WHEN** the app is built
- **THEN** there shall be no duplicate class definitions
- **THEN** all Core Data operations shall compile without type errors

#### Scenario: PersistenceController usage
- **WHEN** any component accesses PersistenceController
- **THEN** the reference shall resolve to a single, unambiguous definition
- **THEN** all methods shall be accessible with proper type signatures

#### Scenario: Move entity migration
- **WHEN** the migration system runs
- **THEN** NSFetchRequest shall use proper generic typing
- **THEN** legacy moves shall be updated with correct learningState values

#### Scenario: Core Data logging integration
- **WHEN** Core Data operations are performed
- **THEN** Logger.coreData shall resolve to correct logger instance
- **THEN** all logging calls shall compile without ambiguity

#### Scenario: NSFetchRequest type casting
- **WHEN** using Core Data fetch requests with generic types
- **THEN** Move.fetchRequest() shall be properly cast to NSFetchRequest<Move>
- **THEN** T.fetchRequest() shall be safely cast to NSFetchRequest<T> for generic methods
- **THEN** batch delete requests shall use NSFetchRequest<NSFetchRequestResult> correctly

#### Scenario: Core Data entity property access
- **WHEN** accessing Move entity properties in extensions
- **THEN** photosIdentifier property shall be accessible within Move instance context
- **THEN** all @NSManaged properties shall resolve correctly in extension methods