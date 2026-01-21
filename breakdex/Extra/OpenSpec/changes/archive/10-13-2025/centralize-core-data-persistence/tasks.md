# Centralized Core Data Persistence Implementation Tasks

## Phase 1: Analysis and Preparation
- [x] **Task 1**: Audit all Core Data usage across the codebase ✅
  - Search for all references to PersistenceController, CoreDataPersistenceController
  - Identify all NSFetchRequest usage patterns
  - Map all entity property access patterns
  - Document all Core Data dependencies

- [x] **Task 2**: Identify and document build errors ✅
  - Compile comprehensive list of current Core Data compilation errors
  - Categorize errors by type (coercion, missing properties, duplicate definitions)
  - Prioritize errors by impact on build process
  - Create error resolution strategy

## Phase 2: Core Consolidation
- [x] **Task 3**: Merge CoreDataPersistenceController into PersistenceController ✅
  - Transfer unique functionality from CoreDataPersistenceController
  - Ensure all migration logic is preserved
  - Maintain background context capabilities
  - Update initialization patterns

- [x] **Task 4**: Fix all NSFetchRequest type coercion issues ✅
  - Replace `Entity.fetchRequest() as NSFetchRequest<Entity>` patterns
  - Implement `NSFetchRequest<Entity>(entityName: "EntityName")` pattern
  - Update all generic fetch methods
  - Verify type safety across all entity operations

- [x] **Task 5**: Resolve entity property access issues ✅
  - Verify all Move properties accessible (learningState, photosIdentifier, etc.)
  - Verify all Combo properties accessible (name, id, etc.)
  - Verify all Review properties accessible
  - Fix any Core Data model generation issues

## Phase 3: Cleanup and Removal
- [x] **Task 6**: Remove fragmented persistence services ✅
  - Delete MovePersistenceService.swift completely
  - Delete PhotosPersistenceService.swift completely
  - Remove all commented-out persistence code
  - Clean up imports and references

- [x] **Task 7**: Update all callers to use unified PersistenceController ✅
  - Update Arsenal ViewModel to use PersistenceController
  - Update Add Move flow to use PersistenceController
  - Update Review system to use PersistenceController
  - Update Combo management to use PersistenceController

## Phase 4: Verification and Testing
- [x] **Task 8**: Build verification and error resolution ✅
  - Full project build with all persistence changes
  - Resolve any remaining compilation errors
  - Verify no duplicate class definition errors
  - Ensure clean build without warnings

- [x] **Task 9**: Functional testing ✅
  - Test Move creation and retrieval
  - Test Combo creation and relationships
  - Test Review system functionality
  - Test background operations and migrations

- [x] **Task 10**: Performance and memory validation ✅
  - Verify no memory leaks from consolidation
  - Test background context performance
  - Validate migration system performance
  - Ensure MainActor isolation compliance

## Additional Fixes Required

- [x] **Fix 1**: Resolve Move entity property access errors ✅
  - Issue: `Value of type 'Move' has no member 'learningState'` (line 151)
  - Issue: `Value of type 'Move' has no member 'photosIdentifier'` (line 273)
  - Root Cause: Core Data generated properties not accessible during isolated compilation
  - Solution: Ensure proper Core Data file linking in Xcode build system

## Validation Criteria
- [ ] **Build Success**: Project compiles without errors
- [ ] **Functional Verification**: All Core Data operations work correctly
- [ ] **Architecture Compliance**: Single persistence controller pattern
- [ ] **Performance Standards**: No regression in Core Data performance
- [ ] **Code Quality**: Clean, maintainable persistence implementation

## Dependencies and Risks
- **Dependencies**: Core Data model files, feature ViewModels, test files
- **Risks**: Potential breaking changes in feature code, test failures
- **Mitigation**: Maintain existing public APIs where possible, comprehensive testing