## Why
Core Data uses a two-file generation system, and the `Move+CoreDataProperties.swift` file was missing, causing compilation errors despite attributes being correctly defined in the visual model editor.

## What Changes
- ✅ **COMPLETED**: Created missing `Move+CoreDataProperties.swift` file with all `@NSManaged` properties
- ✅ **SOLVED**: Fixed `learningState` and `photosIdentifier` property access issues
- ✅ **RESOLVED**: Compilation errors in `PersistenceBridge.swift` are now resolved
- Ensure new file has proper target membership

## Impact
- ✅ **FIXED**: data-persistence spec requirements now satisfied
- ✅ **FIXED**: CoreData/Move+CoreDataProperties.swift created and functional
- ✅ **FIXED**: Features/Shared/Services/PersistenceBridge.swift now compiles successfully
- Build system: Core Data code generation now properly configured