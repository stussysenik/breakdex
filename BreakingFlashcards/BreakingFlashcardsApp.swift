// BreakingFlashcardsApp.swift — App entry point
//
// This is the @main struct — iOS launches the app by instantiating this.
// It sets up two critical pieces of infrastructure:
//
// 1. SwiftData ModelContainer — the database that persists all Move, Combo,
//    ComboMove, and Review objects to disk. Injected via .modelContainer()
//    so every view can access @Query and @Environment(\.modelContext).
//
// 2. AppSettings — the theme/appearance manager, injected via .environment()
//    so any view can read the current theme with @Environment(AppSettings.self).
//
// The .preferredColorScheme() modifier applies the user's theme choice
// to the entire app — overriding system dark/light mode when not set to "system".

import SwiftUI
import SwiftData

@main
struct BreakingFlashcardsApp: App {
    // @State ensures AppSettings is created once and survives view re-renders.
    // Because AppSettings is @Observable, SwiftUI tracks property access automatically.
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(settings)                      // Inject theme settings globally
                .preferredColorScheme(settings.colorScheme) // Apply dark/light/system override
        }
        // Create the on-disk SwiftData database for all four model types.
        // SwiftData auto-handles schema creation and lightweight migrations.
        .modelContainer(for: [Move.self, Combo.self, ComboMove.self, Review.self])
    }
}
