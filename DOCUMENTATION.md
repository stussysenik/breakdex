 I'd suggest a careful, incremental refactoring approach that preserves your UI while fixing the architecture:

  Phase 1: Audit & Stabilize

  1. Map the current functionality - Document exactly what each review component does
  2. Fix immediate build issues - Resolve import problems for StatePillView and color extensions
  3. Preserve working UI - Keep your carefully designed views functional

  Phase 2: Architectural Consolidation

  Don't delete, consolidate:

  1. Create a unified ReviewCoordinator that can route to different review modes:
  enum ReviewMode {
      case flashcard(moves: [Move])
      case detailed(move: Move)
      case combo(combo: Combo)
  }
  2. Extract shared UI components to reusable library:
    - Keep StatePillView but make it truly standalone
    - Create shared styling components for your design system
  3. Use composition over deletion:
  struct UnifiedReviewView: View {
      let mode: ReviewMode
      var body: some View {
          switch mode {
          case .flashcard(let moves):
              FlashcardsReviewView(moves: moves) // Your existing UI
          case .detailed(let move):
              ReviewView(move: move) // Your existing UI
          }
      }
  }

  Phase 3: Gradual Migration

  - Route through the new coordinator while keeping old views
  - Test each UI component remains identical
  - Only delete duplicates when you're confident the unified version works perfectly

  This way you maintain your precious UI design while fixing the underlying architecture chaos. Your UI stays intact, we just organize the plumbing better.

1. Arsenal page
- shows moves, combos
- each page then shows a column list of individual moves, combos
