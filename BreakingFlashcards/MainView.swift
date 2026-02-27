// MainView.swift — Root navigation container for the Breakdex app
//
// This is the top-level view that the app entry point (BreakingFlashcardsApp.swift) renders.
// It uses a TabView to provide five primary navigation destinations:
//
//   1. Add Move    — Record and save new breakdancing moves with video clips
//   2. Arsenal     — Browse the full library of moves and combos
//   3. Create Combo — Chain moves together into combo sequences
//   4. Review      — Spaced-repetition flashcard review sessions
//   5. Settings    — Theme picker and app version info
//
// ARCHITECTURE ROLE:
// MainView sits between the app entry point and all feature views. It receives
// two pieces of infrastructure from BreakingFlashcardsApp via the environment:
//   - SwiftData ModelContainer (via .modelContainer()) — provides @Query and @Environment(\.modelContext)
//   - AppSettings (via .environment()) — provides theme/appearance preferences
// These propagate automatically to all child views through SwiftUI's environment system.
//
// SWIFTUI PATTERN — TabView:
// TabView renders a tab bar at the bottom of the screen with icons and labels.
// Each child view gets its own tab via the .tabItem { } modifier. SwiftUI manages
// which tab is active and preserves the state of inactive tabs (they stay in memory).
// Unlike UIKit's UITabBarController, there's no delegate — tab selection is automatic.
//
// ACCESSIBILITY:
// Each tab has an .accessibilityIdentifier for UI testing (XCTest / FlowDeck).
// These identifiers let automated tests tap specific tabs by ID rather than by label text,
// which is more resilient to copy changes.

import SwiftUI

/// The root view of the Breakdex app — a five-tab navigation container.
/// Rendered by BreakingFlashcardsApp as the content of the main WindowGroup.
struct MainView: View {

    // MARK: - Body

    /// The view hierarchy. TabView creates a system tab bar at the bottom of the screen.
    /// Each child view is lazily loaded on first tab selection and kept alive in memory
    /// after that (SwiftUI does not destroy inactive tab content by default).
    var body: some View {
        TabView {

            // TAB 1: Record
            // Presents a multi-step flow: select video -> preview -> trim -> name -> save.
            AddMoveView()
                .tabItem {
                    Label("Record", systemImage: "video.badge.plus")
                }
                .accessibilityIdentifier("Tab.Record")

            // TAB 2: Library
            // Hub screen with glass cards routing to MoveListView and ComboListView.
            BreakingArsenalView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .accessibilityIdentifier("Tab.Library")

            // TAB 3: Combos
            // Chain moves together into named combo sequences.
            CreateComboView()
                .tabItem {
                    Label("Combos", systemImage: "link")
                }
                .accessibilityIdentifier("Tab.Combos")

            // TAB 4: Practice
            // Spaced-repetition flashcard review sessions.
            ReviewView()
                .tabItem {
                    Label("Practice", systemImage: "rectangle.on.rectangle.angled.fill")
                }
                .accessibilityIdentifier("Tab.Practice")

            // TAB 5: Settings
            // Theme picker and app version/build info.
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .accessibilityIdentifier("Tab.Settings")
        }
        .tint(.accent)
    }
}

// MARK: - Preview

#Preview("MainView - Light") {
    MainView()
        .modelContainer(.preview)
        .environment(AppSettings())
}

#Preview("MainView - Dark") {
    MainView()
        .modelContainer(.preview)
        .environment(AppSettings())
        .preferredColorScheme(.dark)
}
