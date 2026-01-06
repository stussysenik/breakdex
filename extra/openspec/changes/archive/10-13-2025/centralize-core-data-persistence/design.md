# Centralized Core Data Persistence Design

## Architecture Decision

### Problem Statement
The current codebase has multiple Core Data persistence implementations:
1. `PersistenceController` in PersistenceBridge.swift
2. `CoreDataPersistenceController` in Persistence.swift
3. Commented-out `MovePersistenceService` and `PhotosPersistenceService`
4. Inconsistent NSFetchRequest patterns causing type coercion errors

### Solution Overview
Create a single, unified Core Data persistence system that consolidates all functionality while maintaining clean architecture principles.

## Design Decisions

### 1. Single Persistence Controller
**Decision**: Use `PersistenceController` as the single authority for Core Data operations
**Rationale**:
- Already has broader adoption across the codebase
- Better separation of concerns with bridge pattern
- More feature-complete with background operations and migrations

### 2. Layered Architecture
```
Features (ViewModels/Services)
    ↓
PersistenceBridge (Clean API)
    ↓
PersistenceController (Core Logic)
    ↓
Core Data Stack (NSPersistentContainer)
```

### 3. Consistent NSFetchRequest Patterns
**Decision**: Use `NSFetchRequest<Entity>(entityName: "EntityName")` pattern consistently
**Rationale**:
- Avoids type coercion issues with `Entity.fetchRequest() as NSFetchRequest<Entity>`
- More explicit and readable
- Consistent across all entity types

### 4. Protocol-Based Design
**Decision**: Define clear protocols for persistence operations
**Rationale**:
- Enables testing with mock implementations
- Provides clear contracts for different operation types
- Supports future extensibility

## Implementation Strategy

### Phase 1: Consolidation
1. Merge CoreDataPersistenceController functionality into PersistenceController
2. Remove duplicate/commented services
3. Fix all NSFetchRequest type coercion issues

### Phase 2: API Standardization
1. Define unified protocols for common operations
2. Update all callers to use consistent patterns
3. Add comprehensive error handling

### Phase 3: Cleanup
1. Remove unused imports and references
2. Consolidate Core Data extensions
3. Update documentation

## Migration Considerations

### Backward Compatibility
- Maintain existing public APIs where possible
- Use deprecation warnings for removed functionality
- Provide migration path for custom implementations

### Testing Strategy
- Unit tests for consolidated PersistenceController
- Integration tests for all Core Data operations
- Performance tests to ensure no regression

## Trade-offs

### Chosen Approach Benefits
✅ Single source of truth for Core Data operations
✅ Consistent API across all features
✅ Easier maintenance and debugging
✅ Better testability
✅ Cleaner architecture

### Alternatives Considered
❌ Keep multiple controllers (leads to continued conflicts)
❌ Use SwiftData instead of Core Data (breaking change, iOS 17+ requirement)
❌ Create abstraction layer over both (unnecessary complexity)

## Future Extensibility

The centralized design supports:
- Easy addition of new entity types
- Consistent background operations
- Unified migration system
- Standardized error handling
- Potential future migration to SwiftData