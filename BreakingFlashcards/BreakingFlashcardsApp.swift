//
//  BreakingFlashcardsApp.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI

@main
struct BreakingFlashcardsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
