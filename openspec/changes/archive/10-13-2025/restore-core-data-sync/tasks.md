# Tasks - Restore Core Data Model Synchronization

## Immediate Priority (Build Unblockers)

### 1. Clean DerivedData and Regenerate Core Data Classes
- [x] Clean Xcode DerivedData directory: `rm -rf ~/Library/Developer/Xcode/DerivedData/breakdex-*/`
- [x] Open breakdex.xcdatamodeld in Xcode
- [x] Use Editor → Create NSManagedObjectSubclass to regenerate Move classes
- [x] Verify generated classes include `learningState` and `photosIdentifier` properties
- [x] Test compilation of PersistenceBridge.swift

### 2. Restore MoveSaver Service
- [x] Uncomment entire MoveSaver.swift file (216 lines)
- [x] Verify all imports and dependencies are available
- [x] Check for missing MovePersistenceService dependency
- [x] Test compilation of MoveSaver.swift
- [x] Verify AddMove workflow can reference MoveSaver

### 3. Restore SharedVideoPlayerView
- [x] Uncomment entire VideoPlayerView.swift file (400+ lines)
- [x] Verify SharedVideoPlayer dependency exists or create placeholder
- [x] Test compilation of SharedVideoPlayerView
- [x] Verify MoveDetailView.swift can compile with restored video player

## High Priority (Functionality Restoration)

### 4. Implement Logger Utility
- [x] Create Logger utility class with required categories:
  - `Logger.addMove`
  - `Logger.coreData`
  - `Logger.video`
  - `Logger.breakingflashcards` (from existing usage)
- [x] Implement OSLog-based wrapper for consistency with existing code
- [x] Test Logger references across all files compile successfully
- [x] Verify logging functionality works in runtime

### 5. Verify Core Data Integration
- [x] Test PersistenceBridge migration method compiles and runs
- [x] Verify Move entity property access works in all contexts
- [x] Test Core Data save/fetch operations with new properties
- [ ] Run migration on existing development data to verify data integrity

### 6. Build Verification and Testing
- [x] Run full project build: `xcodebuild -project breakdex.xcodeproj -scheme breakdex build`
- [x] Fix any remaining compilation errors
- [ ] Test basic app launch and navigation
- [ ] Verify video loading functionality works
- [ ] Test move creation workflow end-to-end

## Medium Priority (Code Quality)

### 7. Resolve Additional Dependencies
- [ ] Check and fix any missing imports across all modified files
- [ ] Verify all shared UI components are available and compile
- [ ] Test Photo Picker integration functionality
- [ ] Verify color extensions and DesignSystem compile correctly

### 8. Comprehensive Testing
- [ ] Run unit tests for Core Data operations
- [ ] Run UI tests for critical user flows
- [ ] Test video playback in Arsenal, Review, and AddMove features
- [ ] Verify error handling and logging in all components

### 9. Documentation and Cleanup
- [ ] Update any documentation that references old build issues
- [ ] Add comments explaining Core Data synchronization process
- [ ] Document Logger usage patterns for future development
- [ ] Create build verification checklist for future changes

## Validation Criteria

### Build Success
- [ ] All Swift files compile without errors
- [ ] No "Value of type 'Move' has no member" errors
- [ ] Core Data model and classes are synchronized
- [ ] Full project builds successfully on simulator

### Functional Verification
- [ ] App launches and navigates between tabs
- [ ] Move creation workflow functions completely
- [ ] Video playback works in all relevant features
- [ ] Core Data operations (save, fetch, migrate) work correctly

### Code Quality
- [ ] No commented-out critical code remains
- [ ] Logger utility works across all components
- [ ] Error handling is comprehensive and functional
- [ ] Architecture follows Clean Architecture principles

## Dependencies and Risks

### Dependencies
- Xcode for Core Data class regeneration
- Existing Core Data model must be stable
- Development environment must be properly configured

### Risks
- Core Data regeneration may cause development data loss
- Uncommented services may have unresolved dependencies
- Logger implementation may affect existing functionality

### Mitigation
- Backup development data before Core Data changes
- Test each restored component individually
- Use OSLog as stable foundation for Logger implementation