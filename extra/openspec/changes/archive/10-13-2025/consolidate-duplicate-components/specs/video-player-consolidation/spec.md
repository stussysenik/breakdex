# Video Player Component Consolidation

## MODIFIED Requirements

### Requirement: Centralize Video Player Representation
The system MUST establish a single, clean implementation for bridging UIKit's AVPlayerViewController to SwiftUI.

#### Scenario: Video playback across different features
**GIVEN** multiple features need video playback capabilities
**WHEN** implementing video viewing in Arsenal, Combo, or Review features
**THEN** all features should use the same AVPlayerViewRepresentable.swift implementation
**AND** video playback behavior should be consistent across the application

#### Scenario: SwiftUI integration with native video player
**GIVEN** the need to display video content in SwiftUI views
**WHEN** creating video interfaces
**THEN** the AVPlayerViewRepresentable should provide clean UIKit/SwiftUI bridging
**AND** maintain full access to native iOS video player features
**AND** follow proper SwiftUI integration patterns

### Requirement: Remove Duplicate Video Player Implementations
The system MUST eliminate inline or duplicate AVPlayerViewRepresentable implementations scattered across the codebase.

#### Scenario: Code deduplication and maintenance
**GIVEN** multiple files containing similar AVPlayerViewRepresentable implementations
**WHEN** performing architectural cleanup
**THEN** all duplicate implementations should be removed
**AND** all references should point to the centralized AVPlayerViewRepresentable.swift
**AND** no inline video player representations should remain

#### Scenario: Consistent video player behavior
**GIVEN** potentially different video player implementations across features
**WHEN** users interact with video content
**THEN** video playback should behave consistently regardless of the feature
**AND** all video controls should have the same appearance and functionality

### Requirement: Maintain Video Playback Functionality
The system MUST ensure the consolidated video player implementation supports all required video playback features.

#### Scenario: Video viewing in Arsenal feature
**GIVEN** the centralized AVPlayerViewRepresentable implementation
**WHEN** users view moves in their Arsenal
**THEN** videos should play smoothly with proper controls
**AND** video playback should integrate seamlessly with the Arsenal UI

#### Scenario: Video preview in trimming workflow
**GIVEN** users are trimming videos in the Add Move workflow
**WHEN** previewing trimmed segments
**THEN** the video player should provide accurate playback of selected segments
**AND** support seeking and playback controls needed for trimming

#### Scenario: Video playback during review sessions
**GIVEN** users are reviewing moves and combos
**WHEN** playing video flashcards
**THEN** video playback should be responsive and support review-specific features
**AND** integrate properly with the review session flow

## REMOVED Requirements

### Requirement: Support Multiple Video Player Implementation Patterns
This requirement is being removed as multiple implementation patterns create inconsistency and maintenance overhead.

#### Scenario: Flexible video player implementation choices
**REMOVED** - Supporting multiple ways to implement video playback created confusion about which pattern to use for new features.

### Requirement: Maintain Inline Video Player Implementations
This requirement is being removed as inline implementations violate the DRY principle and create maintenance issues.

#### Scenario: Localized video player implementations
**REMOVED** - Inline AVPlayerViewRepresentable implementations in individual view files created code duplication and inconsistent behavior.