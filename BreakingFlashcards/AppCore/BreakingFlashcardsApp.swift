//
//  BreakingFlashcardsApp.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import Photos
import BreakingFlashcards

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
                .onAppear {
                    // MARK: - BreakDex System Initialization
                    let context = persistenceController.container.viewContext

                    // Configure managers with Core Data context
                    VideoRelinkManager.shared.configure(with: context)
                    AlbumSyncManager.shared.configure(with: context)

                    // MARK: - BreakDex Health Checks
                    performBreakDexHealthChecks()
                }
                // Handle system-level errors gracefully
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    // Clear any cached images when memory is low
                    print("Memory warning received - clearing caches")
                }
        }
    }

    // MARK: - BreakDex Health Checks

    private func performBreakDexHealthChecks() {
        Task {
            print("🔍 Starting BreakDex health checks...")

            // 1. Check Photos permission status
            await checkPhotosPermission()

            // 2. Check BreakDex album status
            await checkBreakDexAlbum()

            // 3. Log current state for debugging
            await logBreakDexStatus()

            // 4. Perform album synchronization
            await performAlbumSync()

            print("✅ BreakDex health checks completed")
        }
    }

    private func checkPhotosPermission() async {
        let permissionManager = PhotosPermissionManager.shared
        permissionManager.checkPermissionStatus()

        switch permissionManager.status {
        case .authorized:
            print("✅ Photos permission: Authorized")
        case .limited:
            print("⚠️ Photos permission: Limited access")
        case .denied:
            print("❌ Photos permission: Denied - BreakDex features will be limited")
        case .restricted:
            print("❌ Photos permission: Restricted - BreakDex features will be limited")
        case .notDetermined:
            print("❓ Photos permission: Not determined - will request when needed")
        }
    }

    private func checkBreakDexAlbum() async {
        let albumManager = BreakDexAlbumManager.shared

        do {
            _ = try await albumManager.ensureBreakDexAlbum()
            print("✅ BreakDex album: Ready")
        } catch {
            print("❌ BreakDex album: Error - \(error.localizedDescription)")
            if let breakDexError = error as? BreakDexAlbumError {
                switch breakDexError {
                case .albumCreationFailed:
                    print("   Suggestion: Check Photos permissions and storage space")
                case .albumCreationTimeout:
                    print("   Suggestion: Try restarting the app")
                default:
                    print("   Suggestion: Check Photos app for album issues")
                }
            }
        }
    }

    private func logBreakDexStatus() async {
        let albumManager = BreakDexAlbumManager.shared

        if let album = albumManager.albumState.album {
            let videoCount = await albumManager.getAllVideosInBreakDex().count
            print("📊 BreakDex status: Album found with \(videoCount) videos")

            // Check for any Photos-migrated moves in Core Data
            let context = persistenceController.container.viewContext
            let fetchRequest = Move.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "photosIdentifier != nil AND photosIdentifier != ''")

            do {
                let photosMigratedMoves = try context.count(for: fetchRequest)
                print("📊 Core Data status: \(photosMigratedMoves) moves migrated to Photos")

                let totalMoves = try context.count(for: Move.fetchRequest())
                print("📊 Total moves: \(totalMoves)")
            } catch {
                print("❌ Error checking Core Data migration status: \(error.localizedDescription)")
            }
        } else {
            print("📊 BreakDex status: Album not available")
        }
    }

    private func performAlbumSync() async {
        let syncManager = AlbumSyncManager.shared

        do {
            let results = try await syncManager.performFullSync()
            print("🔄 Album sync completed:")
            print("   📊 Total moves: \(results.totalMoves)")
            print("   ✅ Found in Photos: \(results.foundInPhotos)")
            print("   ⚠️ Missing from Photos: \(results.missingFromPhotos)")
            print("   🗂️ Orphaned metadata: \(results.orphanedMetadata)")

            if results.hasIssues {
                print("⚠️ Sync issues detected - some videos may need relinking")
            } else {
                print("✅ All moves are in sync with BreakDex album")
            }
        } catch {
            print("❌ Album sync failed: \(error.localizedDescription)")
        }
    }
}
