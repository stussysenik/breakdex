# Core Data Model Synchronization

## ADDED Requirements

### 1. Core Data Class Regeneration
#### Scenario:
When the build fails with "Value of type 'Move' has no member 'learningState'" or similar errors, the system must automatically regenerate the Core Data NSManagedObject subclasses to match the current model definition.

### 2. Model-Class Consistency Validation
#### Scenario:
After any Core Data model changes, the system must verify that all generated classes contain the properties defined in the .xcdatamodel file, including `learningState` and `photosIdentifier` attributes.

### 3. Build Verification Post-Sync
#### Scenario:
After Core Data class regeneration, the system must run a full build verification to ensure all references to Core Data properties compile successfully.

## MODIFIED Requirements

### 1. Persistence Bridge Migration Logic
#### Scenario:
The `migrateDataStoreIfNeeded()` method in PersistenceBridge must successfully access `move.learningState` and `move.photosIdentifier` properties without compilation errors.

### 2. Move Entity Property Access
#### Scenario:
Code accessing Move entity properties must successfully compile and run, including the extension methods that check `self.photosIdentifier != nil`.

### 3. Core Data Integration Testing
#### Scenario:
All Core Data operations must function correctly with the synchronized model and class definitions, including save, fetch, and migration operations.