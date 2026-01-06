# Trimmer Interface Specification

## ADDED Requirements

### Requirement: Property Alignment
**The system SHALL** ensure TrimmerView has access to all required properties for video loading state management by fixing missing property references and aligning with UnifiedState properties.
#### Scenario:
```swift
// Before: Property not found
isLoadingVideo = false

// After: Use UnifiedState
unifiedState.flowState.isLoading = false
```

### Requirement: Type Safety Resolution
**The system SHALL** fix generic parameter inference and ambiguous type references by adding explicit type annotations and resolving type conflicts.
#### Scenario:
```swift
// Before: Generic parameter 'C' could not be inferred
ForEach(getProgressPhases(), id: \.name) { phase in

// After: Explicit type annotation
ForEach(getProgressPhases(), id: \.name) { phase: ProgressPhase in
```

### Requirement: Switch Statement Exhaustiveness
**The system SHALL** ensure all switch statements handle all cases by adding missing cases or default branches.
#### Scenario:
```swift
// Before: Switch must be exhaustive
switch progress.phase {
    case .loading: // handle
    case .completed: // handle
    // Missing other cases
}

// After: Complete case handling
switch progress.phase {
    case .loading: // handle
    case .completed: // handle
    case .error: // handle
    case .idle: // handle
    // ... all other cases
}
```

### Requirement: Progress Loading Integration
**The system SHALL** integrate VideoLoadingOperationManager for progress tracking by adding operation manager property and coordination.
#### Scenario:
```swift
// Add missing property
@StateObject private var loadingOperationManager = VideoLoadingOperationManager()

// Use for progress monitoring
if let progress = loadingOperationManager.currentProgress {
    // Display progress information
}
```

## MODIFIED Requirements

### Requirement: Video Loading State Management
**The system SHALL** update state management to use UnifiedState as single source of truth by removing redundant local state properties that duplicate UnifiedState.
#### Scenario:
```swift
// Before: Redundant local state
@State private var isLoadingVideo = false
@State private var loadingProgress: Double = 0.0

// After: Use UnifiedState
// unifiedState.flowState.isLoading
// unifiedState.loadingProgress.progress
```

### Requirement: Error Handling Integration
**The system SHALL** align error handling with UnifiedState error management by using UnifiedState error properties instead of local error state.
#### Scenario:
```swift
// Before: Local error handling
@State private var lastError: Error?

// After: Use UnifiedState
// unifiedState.errorMessage
// unifiedState.hasError
```

## REMOVED Requirements

### Requirement: Duplicate ProgressPhase Definition
- **Description**: Remove duplicate ProgressPhase struct definition
- **Implementation**: Use existing ProgressPhase from VideoLoadingState
#### Scenario:
```swift
// Remove this duplicate definition
private struct ProgressPhase {
    let name: String
    let isActive: Bool
}
// Use existing type from VideoLoadingState instead
```

### Requirement: Loading Message Property
- **Description**: Remove redundant loadingMessage property
- **Implementation**: Use UnifiedState progress messages instead
#### Scenario:
```swift
// Remove redundant property
@State private var loadingMessage: String = ""

// Use UnifiedState progress
unifiedState.loadingProgress.detailedMessage
```