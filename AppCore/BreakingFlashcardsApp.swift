//
//  BreakingFlashcardsApp.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/25/25.
//

import SwiftUI
import Photos
import CoreData

// MARK: - Supporting Types

/// Results of data consistency verification
struct ConsistencyResults {
    let coreDataMoves: Int
    let photosAssets: Int
    let mismatches: Int

    var isConsistent: Bool {
        return mismatches == 0
    }

    var summary: String {
        if isConsistent {
            return "✅ Data is consistent - \(coreDataMoves) moves, \(photosAssets) assets"
        } else {
            return "⚠️ Data inconsistencies found - \(mismatches) mismatches"
        }
    }
}

@main
struct BreakingFlashcardsApp: App {
    // This line keeps the Core Data controller alive for the whole app.
    let persistenceController = PersistenceController.shared

    init() {
        // 🎯 MIGRATION: Run data migration on app startup to ensure learningState consistency
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
                    // MARK: - BreakDex System Initialization
                    let context = persistenceController.container.viewContext

                    // Configure managers with Core Data context
                    VideoRelinkManager.shared.configure(with: context)
                    AlbumSyncManager.shared.configure(with: context)

                    // MARK: - Initialize AlbumManager (single source of truth for BreakDex album)
                    await AlbumManager.shared.setup()

                    // MARK: - Orphaned Asset Reconciliation
                    await performOrphanedAssetReconciliation()

                    // MARK: - BreakDex Health Checks
                    await performBreakDexHealthChecks()
                }
            // Handle system-level errors gracefully
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    // Clear any cached images when memory is low
                    print("Memory warning received - clearing caches")
                }
                // 🎯 NEW: Trigger sync when app becomes active (user returns to app)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        print("🚀 App became active, triggering album sync.")
                        do {
                            AlbumSyncManager.shared.configure(with: persistenceController.container.viewContext)
                            let results = try await AlbumSyncManager.shared.performFullSync()
                            print("📊 App active sync completed:")
                            print("   📊 Total moves: \(results.totalMoves)")
                            print("   ✅ Found in Photos: \(results.foundInPhotos)")
                            print("   ⚠️ Missing from Photos: \(results.missingFromPhotos)")
                            print("   🗂️ Orphaned metadata: \(results.orphanedMetadata)")
                        } catch {
                            print("❌ App active sync failed: \(error.localizedDescription)")
                        }
                    }
                }
        }
    }
    
    // MARK: - Orphaned Asset Reconciliation

    private func performOrphanedAssetReconciliation() {
        Task {
            print("🧹 Starting orphaned asset reconciliation...")

            do {
                let consistencyResults = await performDataConsistencyCheck()
                print(consistencyResults.summary)

                if consistencyResults.isConsistent {
                    print("✅ Orphaned asset reconciliation completed successfully")
                } else {
                    print("⚠️ Orphaned asset reconciliation completed with issues")
                    print("   📊 Core Data moves: \(consistencyResults.coreDataMoves)")
                    print("   📊 Photos assets: \(consistencyResults.photosAssets)")
                    print("   📊 Mismatches: \(consistencyResults.mismatches)")
                }
            } catch {
                print("❌ Orphaned asset reconciliation failed: \(error.localizedDescription)")
            }
        }
    }

    /// Perform data consistency check between Core Data and Photos library
    private func performDataConsistencyCheck() async -> ConsistencyResults {
        print("🧹 Checking data consistency between Core Data and Photos library...")

        // Count Core Data moves
        let coreDataMoves: Int
        do {
            coreDataMoves = try persistenceController.container.viewContext.count(for: Move.fetchRequest())
        } catch {
            coreDataMoves = 0
        }

        // Count Photos assets in BreakDex album
        var photosAssets = 0
        if let breakDexAlbum = await AlbumManager.shared.getBreakDexAlbum() {
            let fetchOptions = PHFetchOptions()
            let assets = PHAsset.fetchAssets(in: breakDexAlbum, options: fetchOptions)
            photosAssets = assets.count
        }

        // Count mismatches
        let knownIdentifiers = await getKnownPhotosIdentifiers()
        var mismatches = 0

        if let breakDexAlbum = await AlbumManager.shared.getBreakDexAlbum() {
            let fetchOptions = PHFetchOptions()
            let assets = PHAsset.fetchAssets(in: breakDexAlbum, options: fetchOptions)

            assets.enumerateObjects { asset, _, _ in
                if !knownIdentifiers.contains(asset.localIdentifier) {
                    mismatches += 1
                }
            }
        }

        return ConsistencyResults(
            coreDataMoves: coreDataMoves,
            photosAssets: photosAssets,
            mismatches: mismatches
        )
    }

    /// Get all known photosIdentifiers from Core Data
    private func getKnownPhotosIdentifiers() async -> Set<String> {
        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "photosIdentifier != nil AND photosIdentifier != ''")

        do {
            let moves = try persistenceController.container.viewContext.fetch(fetchRequest)
            let identifiers = moves.compactMap { $0.photosIdentifier }
            return Set(identifiers)
        } catch {
            print("🧹 Failed to fetch known identifiers: \(error.localizedDescription)")
            return Set()
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
        let albumManager = AlbumManager.shared

        let album = await albumManager.getBreakDexAlbum()
        if album != nil {
            print("✅ BreakDex album: Ready")
        } else {
            print("❌ BreakDex album: Error - Album not available")
            print("   Suggestion: Check Photos permissions and storage space")
        }
    }
    
    private func logBreakDexStatus() async {
        let albumManager = AlbumManager.shared

        if let album = await albumManager.getBreakDexAlbum() {
            // Count videos in the BreakDex album
            let fetchOptions = PHFetchOptions()
            let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
            let videoCount = assets.count
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
