<div align="center">

# breakdex

### Breaking flashcards for everyone.

[![Language](https://img.shields.io/github/languages/top/stussysenik/breakdex?style=flat-square)]()
[![Last Commit](https://img.shields.io/github/last-commit/stussysenik/breakdex?style=flat-square)]()
[![Stars](https://img.shields.io/github/stars/stussysenik/breakdex?style=flat-square)]()
[![Repo Size](https://img.shields.io/github/repo-size/stussysenik/breakdex?style=flat-square)]()

</div>

---

## What It Does

A SwiftUI + SwiftData iOS app for b-boys and b-girls to catalog moves, build combos, and review them with spaced repetition flashcards. Record video clips, trim them, and attach them to moves — then drill your arsenal with flashcard review sessions.

## Features

| Feature | Description |
|---------|-------------|
| **Move Library** | Catalog individual breaking moves with video clips |
| **Combo Builder** | Chain moves into combos with a visual timeline |
| **Flashcard Review** | Spaced repetition review of moves and combos |
| **Video Editor** | Trim, crop, and attach video clips to moves |
| **Pose Analysis** | Vision framework pose overlay on video clips |
| **AI Move Suggestions** | Context-aware move suggestions |
| **Design System** | Custom theme engine with haptic feedback |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Data | SwiftData (local persistence) |
| Video | AVFoundation + VideoCompositionPipeline |
| Vision | PoseAnalyzer + BalanceAnalyzer |
| AI | AIMoveSuggester |
| Haptics | Custom HapticEngine |

## Project Structure

```
BreakingFlashcards/
├── BreakingFlashcardsApp.swift   # App entry point + SwiftData container
├── Models.swift                  # Move, Combo, ComboMove, Review
├── MainView.swift                # Tab navigation
├── MoveListView.swift            # Move library browser
├── MoveDetailView.swift          # Individual move with video
├── AddMoveView.swift             # New move creation
├── ComboListView.swift           # Combo browser
├── ComboDetailView.swift         # Combo timeline + stats
├── CreateComboView.swift         # Combo builder
├── FlashcardsReviewView.swift    # Spaced repetition review
├── ReviewView.swift              # Single flashcard view
├── VideoEditorView.swift         # Trim + crop video clips
├── PoseAnalyzer.swift            # Vision framework pose detection
├── BalanceAnalyzer.swift         # Balance scoring from poses
├── AIMoveSuggester.swift         # AI-powered move suggestions
├── DesignSystem.swift            # Theme + typography + colors
└── Theme.swift                   # Theme configuration
```

## Quick Start

```bash
git clone https://github.com/stussysenik/breakdex.git
cd breakdex
open BreakingFlashcards.xcodeproj
```

Build and run on iOS Simulator or device (Xcode 16+, iOS 17+).

## License

All rights reserved.
