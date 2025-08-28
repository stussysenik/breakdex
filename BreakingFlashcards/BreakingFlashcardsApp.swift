//
//  BreakingFlashcardsApp.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI

@main
struct BreakingFlashcardsApp: App {
    // This line keeps the Core Data controller alive for the whole app.
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            // Here, we create our MainView and inject the database context
            // into the environment, making it available to all sub-views.
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
