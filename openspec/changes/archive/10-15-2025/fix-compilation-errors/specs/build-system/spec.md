## REMOVED Requirements

### Requirement: Clean Build System
**Reason**: Over-engineered files with missing dependencies are preventing compilation.
**Migration**: Remove all problematic files and ensure project builds successfully.

### Requirement: Remove Category Theory Abstractions
**Reason**: VideoStateCategory, FunctorSystem, and other category theory types are missing and causing 129 compilation errors.
**Migration**: Complete removal - these abstractions provided no user value and were over-engineered.

### Requirement: Essentialist Code Maintenance
**Reason**: Keep only essential, functional code that serves user needs.
**Migration**: Preserve only MinimalTrimmerView and related essential components.

## ADDED Requirements

### Requirement: Project Compilation
The system SHALL compile without errors after cleanup.

#### Scenario: Build Verification
- **WHEN** xcodebuild command is executed
- **THEN** project builds successfully with zero compilation errors
- **WHEN** swiftc syntax validation is run on key files
- **THEN** all files pass syntax validation
- **WHEN** app is launched
- **THEN** no runtime crashes occur due to missing types

### Requirement: File Cleanup
The system SHALL remove all over-engineered files causing compilation errors.

#### Scenario: Over-Engineered File Removal
- **WHEN** problematic files are identified
- **THEN** TrimmerState.swift is removed (827 lines of category theory code)
- **THEN** TrimmerInteractionManager.swift is removed (783 lines of missing dependencies)
- **THEN** PrecisionTrimmerTimeline.swift is removed (764 lines of over-engineered timeline)
- **THEN** old TrimmerView.swift is removed (2,637 lines replaced by MinimalTrimmerView)
- **WHEN** build system is updated
- **THEN** no references to deleted files remain

### Requirement: Dependency Resolution
The system SHALL resolve all broken dependencies and missing imports.

#### Scenario: Import Cleanup
- **WHEN** files with missing imports are processed
- **THEN** all imports of deleted types are removed
- **WHEN** project references are updated
- **THEN** no references to over-engineered components remain
- **WHEN** Xcode project is examined
- **THEN** build phases correctly reference existing files only

### Requirement: Essential Functionality Preservation
The system SHALL preserve all essential video trimming functionality through MinimalTrimmerView.

#### Scenario: Functionality Verification
- **WHEN** user accesses video trimming
- **THEN** MinimalTrimmerView loads successfully
- **WHEN** user interacts with timeline
- **THEN** drag handles work correctly
- **WHEN** user selects trim range
- **THEN** validation works as expected
- **WHEN** user applies rotation
- **THEN** rotation preview functions properly
- **WHEN** user proceeds through workflow
- **THEN** navigation flows from SelectClip → Trimmer → Rotation → NameMove correctly