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
    
    // Theme manager for light/dark mode control
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        // Core Data is now eagerly initialized in PersistenceController.shared
        // The container will be ready immediately when accessed
        Logger.coreData.info("App initialization completed - Core Data is ready")
    }

    var body: some Scene {
        WindowGroup {
            // Here, we create our MainView and inject the database context
            // into the environment, making it available to all sub-views.
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    // MARK: - Basic App Initialization
                    // Run migration after container is fully loaded
                    persistenceController.migrateDataStoreIfNeeded()
                }
            // Handle system-level errors gracefully
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    // Clear any cached images when memory is low
                    // print("Memory warning received - clearing caches")
                }
                // MARK: - App became active notification
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        // print("🚀 App became active")
                    }
                }
        }
    }
}
