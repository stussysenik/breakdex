## 1. Cleanup Duplicate Definitions ✅ COMPLETED
- [x] 1.1 Remove commented-out PersistenceController definition in AddMoveFlowTests.swift
- [x] 1.2 Verify no other duplicate PersistenceController definitions exist
- [x] 1.3 Rename struct PersistenceController to CoreDataPersistenceController in Persistence.swift to resolve ambiguity

## 2. Fix Type Casting Issues ✅ COMPLETED
- [x] 2.1 Fix NSFetchRequest type casting in PersistenceBridge.swift line 112: `Move.fetchRequest()` to `Move.fetchRequest() as NSFetchRequest<Move>`
- [x] 2.2 Fix generic type casting in PersistenceBridge.swift line 173: `T.fetchRequest() as NSFetchRequest<T>`
- [x] 2.3 Fix generic type casting in PersistenceBridge.swift line 191: `T.fetchRequest() as NSFetchRequest<T>`
- [x] 2.4 Fix batch delete request type casting in PersistenceBridge.swift line 211: `T.fetchRequest() as NSFetchRequest<NSFetchRequestResult>`
- [x] 2.5 Fix NSFetchRequest type casting in Persistence.swift line 100: `Move.fetchRequest()` to `Move.fetchRequest() as NSFetchRequest<Move>`

## 3. Resolve Ambiguous References ✅ COMPLETED
- [x] 3.1 Fix ambiguous PersistenceController references by renaming struct to CoreDataPersistenceController
- [x] 3.2 Ensure Logger.coreData resolves correctly throughout the file
- [x] 3.3 Test all method calls compile without ambiguity

## 4. Build Verification ✅ COMPLETED
- [x] 4.1 Run syntax validation: `swiftc -parse Features/Shared/Services/PersistenceBridge.swift` - ✅ PASSED
- [x] 4.2 Run full build: `xcodebuild -project breakdex.xcodeproj -scheme breakdex build`
- [x] 4.3 Fix remaining compilation errors:
  - [x] 4.3.1 **PersistenceBridge.swift:112** - Cannot assign value of type 'NSFetchRequest<any NSFetchRequestResult>' to type 'NSFetchRequest<Move>' ✅ FIXED
  - [x] 4.3.2 **PersistenceBridge.swift:173** - Cannot convert value of type 'NSFetchRequest<any NSFetchRequestResult>' to type 'NSFetchRequest<T>' in coercion ✅ FIXED
  - [x] 4.3.3 **PersistenceBridge.swift:191** - Cannot convert value of type 'NSFetchRequest<any NSFetchRequestResult>' to type 'NSFetchRequest<T>' in coercion ✅ FIXED
  - [x] 4.3.4 **PersistenceBridge.swift:211** - Batch delete request type casting issue ✅ FIXED
  - [x] 4.3.5 **Persistence.swift:100** - NSFetchRequest type casting in migration method ✅ FIXED
  - [x] 4.3.6 **Persistence.swift:71** - Cannot find 'photosIdentifier' in scope (Move extension property access) ✅ FIXED
- [x] 4.4 Test Core Data functionality in isolation

**Note:** The original PersistenceController build errors have been resolved. New errors discovered in ReviewViewModel.swift are outside the scope of this change request and require separate investigation.

## 5. Testing and Validation
- [ ] 5.1 Run unit tests to ensure Core Data operations work correctly
- [ ] 5.2 Verify migration system functions properly
- [ ] 5.3 Test video flashcard creation and retrieval
- [ ] 5.4 Validate logging integration works as expected