## ADDED Requirements
### Requirement: Modern Observable Pattern
AddMoveViewModel SHALL use @Observable macro for iOS 18 compatibility following Apple's recommended migration from ObservableObject.

#### Scenario: Observable implementation
- **WHEN** AddMoveViewModel manages state
- **THEN** it uses @Observable macro for modern SwiftUI integration
- **AND** provides reactive updates to subscribing views

### Requirement: Direct View-ViewModel Integration
Views SHALL integrate with AddMoveViewModel directly without adapter layers following MVVM pattern.

#### Scenario: MinimalTrimmerView direct integration
- **WHEN** user needs to trim video clip
- **THEN** MinimalTrimmerView uses AddMoveViewModel directly for state and actions
- **AND** no adapter layer exists between view and view model

#### Scenario: NameMoveView direct integration
- **WHEN** user needs to name move
- **THEN** NameMoveView uses AddMoveViewModel directly for state and actions
- **AND** no adapter layer exists between view and view model

### Requirement: AVFoundation Video Trimming
Video trimming functionality SHALL use AVComposition and AVPlayer following iOS 18 best practices.

#### Scenario: Video trimming with AVFoundation
- **WHEN** user trims video clip
- **THEN** MinimalTrimmerView uses AVComposition for trimming operations
- **AND** AVPlayer integration follows iOS 18 performance guidelines
- **AND** trimming state managed through AddMoveViewModel

## REMOVED Requirements
### Requirement: View Adapter Layer
**Reason**: Adapter layers violate MVVM pattern and add unnecessary complexity
**Migration**: Views now integrate with AddMoveViewModel directly

### Requirement: NameMoveViewAdapter
**Reason**: Temporary migration aid no longer needed
**Migration**: NameMoveView uses AddMoveViewModel directly

### Requirement: MinimalTrimmerViewAdapter
**Reason**: Placeholder replaced with actual implementation
**Migration**: MinimalTrimmerView uses AddMoveViewModel directly