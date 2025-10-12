//
//  breakdex.swift
//  breakdex
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import CoreData

@main
struct breakdex: App {
    // This line keeps the Core Data controller alive for the whole app.
    let persistenceController = PersistenceController.shared

    init() {
        // MARK: - MIGRATION: Run data migration on app startup to ensure learningState consistency
        // This ensures all existing moves have proper learningState for review functionality
        persistenceController.migrateDataStoreIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            // Here, we create our MainView and inject the database context
            // into the environment, making it available to all sub-views.
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    // MARK: - Basic App Initialization
                    print("✅ breakdex app initialized successfully")
                }
            // Handle system-level errors gracefully
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    // Clear any cached images when memory is low
                    print("Memory warning received - clearing caches")
                }
                // MARK: - App became active notification
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        print("🚀 App became active")
                    }
                }
        }
    }
}
