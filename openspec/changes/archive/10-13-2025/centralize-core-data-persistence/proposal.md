## Why
The breakdex project currently has multiple fragmented Core Data persistence implementations causing build errors, maintenance complexity, and architectural confusion. Having multiple persistence controllers (PersistenceController, CoreDataPersistenceController, etc.) violates the Single Responsibility Principle and creates conflicting type definitions that prevent compilation.

## Current Problems Identified
1. **Duplicate Controllers**: Both `PersistenceController` in PersistenceBridge.swift and `CoreDataPersistenceController` in Persistence.swift
2. **Type Conflicts**: NSFetchRequest type coercion errors due to inconsistent Core Data entity definitions
3. **Fragmented Services**: MovePersistenceService and PhotosPersistenceService are commented out but still referenced
4. **Build Failures**: Multiple properties like `learningState` and `photosIdentifier` not being recognized across implementations
5. **Maintenance Burden**: Multiple code paths for the same Core Data operations

## What Changes
- **Consolidate**: Create a single, authoritative Core Data persistence system
- **Unify**: Merge functionality from PersistenceController and CoreDataPersistenceController into one implementation
- **Clean**: Remove commented-out services and duplicate code
- **Standardize**: Establish consistent NSFetchRequest patterns across the codebase
- **Simplify**: Create a clean API for all Core Data operations used by features

## Impact
- **Affected specs**: persistence (Core Data layer), move-management, combo-management, review-system
- **Affected code**:
  - Features/Shared/Services/PersistenceBridge.swift
  - CoreData/Persistence.swift
  - Features/Shared/Services/MovePersistenceService.swift (remove)
  - Features/Shared/Services/PhotosPersistenceService.swift (remove)
  - All files using Core Data operations
- **BREAKING**: Centralizes persistence but maintains existing public APIs to minimize impact