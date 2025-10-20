# Unified Core Data Persistence Specification

## ADDED Requirements

### Requirement: Single Persistence Controller
#### Scenario:
When the application starts up, it must initialize exactly one Core Data persistence controller that handles all database operations for Moves, Combos, and Reviews. The controller should provide both view context and background context access with proper MainActor isolation.

**Acceptance Criteria:**
- Exactly one PersistenceController instance exists in the application
- Both CoreDataPersistenceController and duplicate PersistenceController definitions are removed
- All features use the same PersistenceController.shared instance
- The controller supports both synchronous and asynchronous operations

### Requirement: Consistent NSFetchRequest Patterns
#### Scenario:
When any part of the application needs to fetch Core Data entities (Move, Combo, Review), it must use consistent type-safe NSFetchRequest patterns that avoid coercion issues.

**Acceptance Criteria:**
- All fetch requests use `NSFetchRequest<Entity>(entityName: "EntityName")` pattern
- No `fetchRequest() as NSFetchRequest<Entity>` coercion patterns exist
- Generic fetch methods work consistently across all entity types
- Type safety is maintained at compile time

### Requirement: Unified Move Operations
#### Scenario:
When creating, updating, or deleting Move entities, all operations must go through the centralized PersistenceController with consistent error handling and logging.

**Acceptance Criteria:**
- Move creation uses PersistenceController instead of fragmented services
- All Move properties (learningState, photosIdentifier, etc.) are accessible
- Move operations work across all features (Arsenal, Add Move, Review)
- Proper error handling and logging for all Move operations

### Requirement: Centralized Combo Management
#### Scenario:
When working with Combo entities and their relationships to Moves, all operations must use the unified persistence system with proper relationship handling.

**Acceptance Criteria:**
- Combo creation and management through PersistenceController
- Combo-Move relationships work correctly
- Combo operations are consistent across Combo and Arsenal features
- Proper fetch and delete operations for combos

### Requirement: Review System Integration
#### Scenario:
When the review system needs to access or modify Review entities and their relationships to Moves, it must use the centralized persistence system.

**Acceptance Criteria:**
- Review entities accessible through unified persistence
- Review-Move relationships work correctly
- Review operations support the review workflow
- Consistent fetch patterns for review data

## MODIFIED Requirements

### Requirement: Core Data Stack Configuration
#### Scenario:
The Core Data stack must be configured once with proper support for lightweight migration, background contexts, and error handling that serves all features.

**Acceptance Criteria:**
- Single NSPersistentContainer configuration
- Lightweight migration enabled for schema updates
- Background context support for all features
- Proper error handling and logging
- Thread-safe context management

### Requirement: Entity Property Access
#### Scenario:
All Core Data entity properties (learningState, photosIdentifier, name, etc.) must be consistently accessible across the entire application without type conflicts.

**Acceptance Criteria:**
- All Move entity properties accessible from all features
- All Combo entity properties accessible consistently
- All Review entity properties accessible consistently
- No compilation errors related to missing properties
- Type-safe property access throughout the app

## REMOVED Requirements

### Requirement: Fragmented Persistence Services
#### Scenario:
Remove the fragmented and commented-out persistence services that create confusion and duplicate functionality.

**Acceptance Criteria:**
- MovePersistenceService.swift completely removed
- PhotosPersistenceService.swift completely removed
- All references to these services updated to use PersistenceController
- No commented-out code blocks remaining in persistence files
- Clean, single source of truth for all persistence operations