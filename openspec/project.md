# Project Context

## Purpose

Breakdex is an iOS application for breaking/b-boy dancers to catalog their moves, create combos, and practice through spaced repetition review. The app helps users track their move library ("arsenal"), organize moves into combos, and systematically improve recall through an SM-2 based learning system.

## Tech Stack

- **Platform**: iOS 17+ (SwiftUI)
- **Architecture**: MVVM with feature-based module organization
- **Persistence**: Core Data with SQLite backend
- **Testing**: XCTest UI tests with accessibility verification
- **Video**: AVFoundation for video playback and trimming
- **Design**: IBM Plex Mono typography, IBM Carbon-inspired color palette

## Project Conventions

### Code Style

- SwiftUI views use `@StateObject` for owned ViewModels, `@ObservedObject` for injected
- ViewModels are `@MainActor` annotated for thread safety
- Feature modules organized under `Features/[FeatureName]/Views/` and `Features/[FeatureName]/ViewModels/`
- Shared components live in `Features/Shared/UI/Components/`
- Design tokens defined in `Features/Shared/UI/Styles/DesignSystem.swift`

### Architecture Patterns

- **MVVM**: Views observe ViewModels which manage state and business logic
- **Dependency Injection**: Core Data context injected via environment
- **Tab Navigation**: 5-tab TabView as primary navigation
- **Feature Isolation**: Each feature is independently testable

### Testing Strategy

- **UI Tests**: XCTest-based UI tests covering user flows
- **Accessibility Tests**: WCAG 2.2 AA compliance verification
- **Performance Tests**: Launch and scroll performance metrics
- **Test-First**: Write failing tests before implementing features when possible

### Git Workflow

- Feature branches from main
- PR-based review process
- OpenSpec proposals for non-trivial changes

## Domain Context

### Key Concepts

- **Move**: A single breaking move/tutorial with associated video clip
- **Combo**: A sequence of moves performed together
- **Arsenal**: The user's collection of moves and combos
- **Learning States**: NEW (just added), LEARNING (in progress), MASTERY (well-known)
- **Spaced Repetition**: SM-2 algorithm for optimal review scheduling

### User Journey

1. User records or imports video clips of moves
2. User trims clips and names moves to build their arsenal
3. User creates combos by sequencing moves
4. User reviews moves through flashcard-style practice
5. System schedules reviews based on recall performance

## Important Constraints

- Must maintain WCAG 2.2 AA accessibility compliance
- Must support both light and dark modes with visual parity
- Video content may be stored in iCloud, requiring timeout handling
- Target users include older adults (65+) with accessibility needs

## External Dependencies

- Photos framework for video import
- AVFoundation for video processing
- Core Data for local persistence
- No external networking or API dependencies currently
