## Why
Fix critical build errors preventing compilation of the breakdex iOS app caused by PersistenceController conflicts and type casting issues.

## What Changes
- Remove duplicate PersistenceController definition in test files
- Fix NSFetchRequest type casting issue in migration method
- Resolve ambiguous PersistenceController references
- Ensure proper Core Data integration for video flashcard functionality

## Impact
- Affected specs: persistence (Core Data layer)
- Affected code: Features/Shared/Services/PersistenceBridge.swift, breakdexUITests/AddMoveFlowTests.swift
- **BREAKING**: None - fixes existing broken functionality