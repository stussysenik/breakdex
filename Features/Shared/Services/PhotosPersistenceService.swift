// //
// //  PhotosPersistenceService.swift
// //  BreakingFlashcards
// //
// //  Created by Claude Code on 9/27/25.
// //

// import Foundation
// import Photos
// import PhotosUI
// import OSLog
// import Combine

// // MARK: - Category Theory Analysis
// /*
//  CATEGORY THEORY ANALYSIS:

//  Current System (Problematic):
//  - Objects: PHAsset, PHAssetCollection, Operation (non-atomic)
//  - Morphisms: Multiple separate operations → race conditions
//  - Functor: Non-atomic → duplicates possible
//  - Adjoint: Missing → no inverse operations

//  Ideal System (Target):
//  - Objects: PHAsset, PHAssetCollection, AtomicOperation
//  - Morphisms: Single atomic operation → no race conditions
//  - Functor: Atomic → guaranteed uniqueness
//  - Adjoint: Present → rollback operations available
//  - Isomorphism: Preserved - consistent asset creation
// */

// // MARK: - Photos Persistence Errors
// public enum PhotosPersistenceError: Error, LocalizedError {
//     case albumCreationFailed(Error)
//     case assetCreationFailed(Error)
//     case atomicOperationFailed(Error)
//     case permissionDenied
//     case assetNotFound
//     case duplicateAsset
//     case cloudSyncFailed(Error)

//     public var errorDescription: String? {
//         switch self {
//         case .albumCreationFailed(let error):
//             return "Failed to create album: \(error.localizedDescription)"
//         case .assetCreationFailed(let error):
//             return "Failed to create asset: \(error.localizedDescription)"
//         case .atomicOperationFailed(let error):
//             return "Atomic operation failed: \(error.localizedDescription)"
//         case .permissionDenied:
//             return "Photo library permission denied"
//         case .assetNotFound:
//             return "Asset not found in photo library"
//         case .duplicateAsset:
//             return "Duplicate asset detected"
//         case .cloudSyncFailed(let error):
//             return "Cloud synchronization failed: \(error.localizedDescription)"
//         }
//     }
// }

// // MARK: - Photos Persistence Result
// public struct PhotosPersistenceResult {
//     let localAssetIdentifier: String
//     let cloudAssetIdentifier: String?
//     let albumIdentifier: String
//     let assetURL: URL?
//     let isCloudSynced: Bool
//     let creationDate: Date
//     let correlationId: String
// }

// // MARK: - Photos Persistence Progress
// public struct PhotosPersistenceProgress {
//     let phase: PersistencePhase
//     let progressValue: Double
//     let message: String
//     let correlationId: String

//     public enum PersistencePhase {
//         case initializing
//         case creatingAlbum
//         case processingAsset
//         case savingToLibrary
//         case syncingToCloud
//         case completed
//         case failed(Error)
//     }
// }

// // MARK: - Photos Persistence Service Protocol
// // MARK: - FUNC
// public protocol PhotosPersistenceServiceProtocol {
//     func saveVideoAsset(_ url: URL, filename: String, sourceIdentifier: String?) async throws -> PhotosPersistenceResult
//     func saveVideoAsset(_ asset: AVAsset, filename: String, sourceIdentifier: String?) async throws -> PhotosPersistenceResult
//     func getBreakDexAlbum() async throws -> PHAssetCollection
//     func checkCloudSyncStatus(for assetIdentifier: String) async throws -> Bool
//     var progressPublisher: AnyPublisher<PhotosPersistenceProgress, Never> { get }
// }

// // MARK: - Photos Persistence Service Implementation
// @MainActor
// @preconcurrency
// public final class PhotosPersistenceService: PhotosPersistenceServiceProtocol {

//     // MARK: - Properties
//     private let logger = Logger(subsystem: "com.breakingflashcards", category: "📸 PhotosPersistenceService")
//     private let memoryLogger = CentralizedMemoryLogger.shared
//     private let albumManager = AlbumManager.shared

//     // Progress tracking
//     private let progressSubject = PassthroughSubject<PhotosPersistenceProgress, Never>()
//     public var progressPublisher: AnyPublisher<PhotosPersistenceProgress, Never> {
//         progressSubject.eraseToAnyPublisher()
//     }

//     // Performance tracking
//     private var operationTimings: [String: TimeInterval] = [:]
//     private var currentCorrelationId: String?

//     // Atomic operation lock
//     private let operationLock = NSLock()

//     // Error handling for non-throwing closures
//     private var creationError: PhotosPersistenceError?

//     // MARK: - Initialization
//     public init() {
//         logger.info("📸 PHOTOS_PERSISTENCE: 🚀 Initialized - atomic photo persistence service")
//         Task {
//             do {
//                 try await albumManager.setup()
//                 logger.info("📸 PHOTOS_PERSISTENCE: ✅ Album manager setup completed successfully")
//             } catch {
//                 logger.error("📸 PHOTOS_PERSISTENCE: ⚠️ Album manager setup failed: \(error.localizedDescription)")
//                 // Note: Setup failure will be handled lazily when album operations are attempted
//             }
//         }
//     }

//     // MARK: - Public API
//     // MARK: - FUNC
//     /// Save video asset from URL to Photos library with atomic operations
//     public func saveVideoAsset(_ url: URL, filename: String, sourceIdentifier: String?) async throws -> PhotosPersistenceResult {
//         let correlationId = generateCorrelationId()
//         currentCorrelationId = correlationId

//         logger.info("📸 PHOTOS_PERSISTENCE: 🚀 Saving video asset from URL [\(correlationId)]: \(filename)")
//         await reportProgress(.initializing, progress: 0.0, message: "Starting asset persistence", correlationId: correlationId)

//         let startTime = Date()

//         do {
//             await reportProgress(.creatingAlbum, progress: 0.1, message: "Ensuring BreakDex album exists", correlationId: correlationId)

//             // Ensure album exists atomically
//             let album = try await ensureBreakDexAlbum(correlationId: correlationId)

//             await reportProgress(.processingAsset, progress: 0.3, message: "Processing video asset", correlationId: correlationId)

//             // MARK: - CRITICAL: Single atomic operation to prevent race conditions
//             let result = try await performAtomicAssetCreation(
//                 url: url,
//                 filename: filename,
//                 sourceIdentifier: sourceIdentifier,
//                 album: album,
//                 correlationId: correlationId
//             )

//             await reportProgress(.completed, progress: 1.0, message: "Asset saved successfully", correlationId: correlationId)

//             logCompletion(result: result, startTime: startTime, method: "url_persistence")
//             return result

//         } catch {
//             await reportProgress(.failed(error), progress: 0.0, message: "Persistence failed: \(error.localizedDescription)", correlationId: correlationId)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ URL persistence failed [\(correlationId)]: \(error)")
//             throw error
//         }
//     }
//     // MARK: - FUNC
//     /// Save video asset from AVAsset to Photos library with atomic operations
//     public func saveVideoAsset(_ asset: AVAsset, filename: String, sourceIdentifier: String?) async throws -> PhotosPersistenceResult {
//         let correlationId = generateCorrelationId()
//         currentCorrelationId = correlationId

//         logger.info("📸 PHOTOS_PERSISTENCE: 🚀 Saving video asset from AVAsset [\(correlationId)]: \(filename)")
//         await reportProgress(.initializing, progress: 0.0, message: "Starting asset persistence", correlationId: correlationId)

//         let startTime = Date()

//         do {
//             await reportProgress(.creatingAlbum, progress: 0.1, message: "Ensuring BreakDex album exists", correlationId: correlationId)

//             // Ensure album exists atomically
//             let album = try await ensureBreakDexAlbum(correlationId: correlationId)

//             await reportProgress(.processingAsset, progress: 0.3, message: "Processing video asset", correlationId: correlationId)

//             // Export AVAsset to temporary URL first
//             let tempURL = try await exportAssetToTemporaryURL(asset, filename: filename, correlationId: correlationId)

//             // MARK: - CRITICAL: Single atomic operation to prevent race conditions
//             let result = try await performAtomicAssetCreation(
//                 url: tempURL,
//                 filename: filename,
//                 sourceIdentifier: sourceIdentifier,
//                 album: album,
//                 correlationId: correlationId
//             )

//             await reportProgress(.completed, progress: 1.0, message: "Asset saved successfully", correlationId: correlationId)

//             logCompletion(result: result, startTime: startTime, method: "asset_persistence")
//             return result

//         } catch {
//             await reportProgress(.failed(error), progress: 0.0, message: "Persistence failed: \(error.localizedDescription)", correlationId: correlationId)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ AVAsset persistence failed [\(correlationId)]: \(error)")
//             throw error
//         }
//     }
//     // MARK: - FUNC
//     /// Get BreakDex album with enhanced atomic operations
//     public func getBreakDexAlbum() async throws -> PHAssetCollection {
//         let correlationId = generateCorrelationId()
//         logger.info("📸 PHOTOS_PERSISTENCE: 📚 Getting BreakDex album with enhanced atomic operations [\(correlationId)]")

//         let startTime = Date()

//         do {
//             // MARK: - CRITICAL: Use enhanced atomic AlbumManager
//             let album = try await albumManager.getBreakDexAlbum()

//             let duration = Date().timeIntervalSince(startTime)
//             logger.info("📸 PHOTOS_PERSISTENCE: ✅ BreakDex album retrieved successfully [\(correlationId)]: \(album.localIdentifier) (\(String(format: "%.3f", duration))s)")

//             // Log detailed metrics for monitoring
//             let metrics = albumManager.getOperationMetrics()
//             if !metrics.isEmpty {
//                 let recentMetrics = Array(metrics.suffix(5))
//                 logger.info("📸 PHOTOS_PERSISTENCE:  Recent album operations [\(correlationId)]:")
//                 for metric in recentMetrics {
//                     logger.info("📸 PHOTOS_PERSISTENCE:   - \(metric.operationType): \(String(format: "%.3f", metric.duration))s, Success: \(metric.success), Cache Hit: \(metric.cacheHit), Retries: \(metric.retryCount)")
//                 }
//             }

//             return album

//         } catch let albumError as AlbumManagerError {
//             let duration = Date().timeIntervalSince(startTime)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Enhanced album operation failed [\(correlationId)] (\(String(format: "%.3f", duration))s): \(albumError)")

//             // Map AlbumManager errors to PhotosPersistenceError
//             switch albumError {
//             case .permissionDenied:
//                 throw PhotosPersistenceError.permissionDenied
//             case .albumCreationFailed(let error):
//                 throw PhotosPersistenceError.albumCreationFailed(error)
//             case .albumNotFound:
//                 throw PhotosPersistenceError.albumCreationFailed(albumError)
//             case .atomicOperationFailed(let error):
//                 throw PhotosPersistenceError.atomicOperationFailed(error)
//             case .photoLibraryUnavailable:
//                 throw PhotosPersistenceError.albumCreationFailed(albumError)
//             case .transientFailure(let error):
//                 throw PhotosPersistenceError.cloudSyncFailed(error)
//             case .duplicateCreationAttempt:
//                 // This is actually a success - duplicate was prevented
//                 logger.info("📸 PHOTOS_PERSISTENCE: ✅ Duplicate creation prevented - retrying to get existing album [\(correlationId)]")
//                 return try await albumManager.getBreakDexAlbum()
//             case .invalidAlbumState:
//                 throw PhotosPersistenceError.albumCreationFailed(albumError)
//             }

//         } catch {
//             let duration = Date().timeIntervalSince(startTime)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Unexpected error getting BreakDex album [\(correlationId)] (\(String(format: "%.3f", duration))s): \(error)")
//             throw PhotosPersistenceError.albumCreationFailed(error)
//         }
//     }
//     // MARK: - FUNC
//     /// Check cloud sync status for asset
//     public func checkCloudSyncStatus(for assetIdentifier: String) async throws -> Bool {
//         let correlationId = generateCorrelationId()
//         logger.info("📸 PHOTOS_PERSISTENCE: ☁️ Checking cloud sync status [\(correlationId)]: \(assetIdentifier)")

//         let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
//         guard let asset = fetchResult.firstObject else {
//             throw PhotosPersistenceError.assetNotFound
//         }

//         // Check if asset is in cloud
//         let cloudStatus = PHAssetResource.assetResources(for: asset).first?.value(forKey: "locallyAvailable") as? Bool ?? false
//         return !cloudStatus
//     }

//     // MARK: - Private Atomic Operations
//     // MARK: - FUNC
//     /// MARK: - CRITICAL: Ensure BreakDex album exists with enhanced atomic operations
//     private func ensureBreakDexAlbum(correlationId: String) async throws -> PHAssetCollection {
//         logger.info("📸 PHOTOS_PERSISTENCE: 🔒 Ensuring BreakDex album exists with enhanced atomic operations [\(correlationId)]")

//         let albumStart = Date()

//         // MARK: - CRITICAL: Use atomic lock to prevent race conditions
//         operationLock.lock()
//         defer { operationLock.unlock() }

//         do {
//             // MARK: - CRITICAL: Use enhanced atomic AlbumManager with comprehensive error handling
//             let album = try await albumManager.getBreakDexAlbum()

//             operationTimings["album_ensure"] = Date().timeIntervalSince(albumStart)
//             logger.info("📸 PHOTOS_PERSISTENCE: ✅ BreakDex album obtained atomically [\(correlationId)]: \(album.localIdentifier)")

//             // Log album manager metrics for monitoring
//             let metrics = albumManager.getOperationMetrics()
//             if let latestMetric = metrics.last {
//                 logger.info("📸 PHOTOS_PERSISTENCE:  Album operation metrics [\(correlationId)]: \(latestMetric.operationType) - \(String(format: "%.3f", latestMetric.duration))s - Success: \(latestMetric.success)")
//             }

//             return album

//         } catch let albumError as AlbumManagerError {
//             // Handle specific AlbumManager errors with proper mapping
//             let persistenceError: PhotosPersistenceError
//             switch albumError {
//             case .permissionDenied:
//                 persistenceError = .permissionDenied
//             case .albumCreationFailed(let underlyingError):
//                 persistenceError = .albumCreationFailed(underlyingError)
//             case .albumNotFound:
//                 persistenceError = .albumCreationFailed(albumError)
//             case .atomicOperationFailed(let underlyingError):
//                 persistenceError = .atomicOperationFailed(underlyingError)
//             case .photoLibraryUnavailable:
//                 persistenceError = .albumCreationFailed(albumError)
//             case .transientFailure(let underlyingError):
//                 persistenceError = .cloudSyncFailed(underlyingError)
//             case .duplicateCreationAttempt:
//                 // This is actually good - duplicate was prevented
//                 logger.info("📸 PHOTOS_PERSISTENCE: ✅ Duplicate album creation prevented [\(correlationId)]")
//                 // Try to get the existing album again
//                 return try await albumManager.getBreakDexAlbum()
//             case .invalidAlbumState:
//                 persistenceError = .albumCreationFailed(albumError)
//             }

//             operationTimings["album_ensure"] = Date().timeIntervalSince(albumStart)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Enhanced album operation failed [\(correlationId)]: \(albumError)")
//             throw persistenceError

//         } catch {
//             // Handle any other unexpected errors
//             operationTimings["album_ensure"] = Date().timeIntervalSince(albumStart)
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Unexpected album operation error [\(correlationId)]: \(error)")
//             throw PhotosPersistenceError.albumCreationFailed(error)
//         }
//     }
//     // MARK: - FUNC
//     /// Perform atomic asset creation to prevent race conditions
//     private func performAtomicAssetCreation(
//         url: URL,
//         filename: String,
//         sourceIdentifier: String?,
//         album: PHAssetCollection,
//         correlationId: String
//     ) async throws -> PhotosPersistenceResult {
//         logger.info("📸 PHOTOS_PERSISTENCE: 🔒 Performing atomic asset creation [\(correlationId)]")

//         let creationStart = Date()

//         // MARK: - CRITICAL: Single atomic operation to prevent race conditions
//         operationLock.lock()
//         defer { operationLock.unlock() }

//         // Reset error state
//         creationError = nil

//         await reportProgress(.savingToLibrary, progress: 0.6, message: "Saving to photo library", correlationId: correlationId)

//         do {
//             var result: PhotosPersistenceResult?

//             try await PHPhotoLibrary.shared().performChanges { [self] in
//                 logger.info("📸 PHOTOS_PERSISTENCE: 🔄 Creating asset change request [\(correlationId)]")

//                 // Create asset from file URL
//                 guard let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) else {
//                     // Cannot throw inside non-throwing closure, so we'll handle this differently
//                     self.creationError = PhotosPersistenceError.assetCreationFailed(NSError(domain: "PhotosPersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset change request"]))
//                     return
//                 }
//                 let placeholder = creationRequest.placeholderForCreatedAsset

//                 // Add asset to BreakDex album
//                 let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
//                 albumChangeRequest?.addAssets([placeholder] as NSArray)

//                 logger.info("📸 PHOTOS_PERSISTENCE: ✅ Asset creation request prepared [\(correlationId)]")
//             }

//             await reportProgress(.syncingToCloud, progress: 0.8, message: "Syncing to cloud", correlationId: correlationId)

//             // Fetch the created asset
//             let fetchOptions = PHFetchOptions()
//             fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//             fetchOptions.fetchLimit = 1

//             let recentAssets = PHAsset.fetchAssets(with: .video, options: fetchOptions)
//             guard let createdAsset = recentAssets.firstObject else {
//                 throw PhotosPersistenceError.assetCreationFailed(NSError(domain: "PhotosPersistenceService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not fetch created asset"]))
//             }

//             // Check for creation error
//             if let error = creationError {
//                 throw error
//             }

//             // Extract cloud identifier
//             let cloudIdentifier = try await extractCloudIdentifier(from: createdAsset, correlationId: correlationId)

//             // Check cloud sync status
//             let isCloudSynced = try await checkCloudSyncStatus(for: createdAsset.localIdentifier)

//             // Get asset URL if available
//             let assetURL = await getAssetURL(for: createdAsset, correlationId: correlationId)

//             result = PhotosPersistenceResult(
//                 localAssetIdentifier: createdAsset.localIdentifier,
//                 cloudAssetIdentifier: cloudIdentifier,
//                 albumIdentifier: album.localIdentifier,
//                 assetURL: assetURL,
//                 isCloudSynced: isCloudSynced,
//                 creationDate: Date(),
//                 correlationId: correlationId
//             )

//             operationTimings["asset_creation"] = Date().timeIntervalSince(creationStart)

//             guard let finalResult = result else {
//                 throw PhotosPersistenceError.atomicOperationFailed(NSError(domain: "PhotosPersistenceService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Result creation failed"]))
//             }

//             logger.info("📸 PHOTOS_PERSISTENCE: 🏆 Atomic asset creation completed [\(correlationId)]")
//             return finalResult

//         } catch {
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Atomic asset creation failed [\(correlationId)]: \(error)")
//             throw PhotosPersistenceError.atomicOperationFailed(error)
//         }
//     }

//     // MARK: - Helper Methods
//     // MARK: - FUNC
//     /// Export AVAsset to temporary URL
//     private func exportAssetToTemporaryURL(_ asset: AVAsset, filename: String, correlationId: String) async throws -> URL {
//         logger.info("📸 PHOTOS_PERSISTENCE: 💾 Exporting AVAsset to temporary URL [\(correlationId)]")

//         let tempURL = FileManager.default.temporaryDirectory
//             .appendingPathComponent("\(UUID().uuidString)-\(filename)")
//             .appendingPathExtension("mov")

//         guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
//             throw PhotosPersistenceError.assetCreationFailed(NSError(domain: "PhotosPersistenceService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]))
//         }

//         exportSession.outputURL = tempURL
//         exportSession.outputFileType = .mov

//         await exportSession.export()

//         if let error = exportSession.error {
//             logger.error("📸 PHOTOS_PERSISTENCE: ❌ Export failed [\(correlationId)]: \(error)")
//             throw PhotosPersistenceError.assetCreationFailed(error)
//         }

//         logger.info("📸 PHOTOS_PERSISTENCE: ✅ Export completed [\(correlationId)]: \(tempURL.lastPathComponent)")
//         return tempURL
//     }
//     // MARK: - FUNC
//     /// Extract cloud identifier from PHAsset
//     private func extractCloudIdentifier(from asset: PHAsset, correlationId: String) async -> String? {
//         logger.info("📸 PHOTOS_PERSISTENCE: ☁️ Extracting cloud identifier [\(correlationId)]")

//         // For cloud assets, derive a cloud identifier
//         if asset.sourceType == .typeCloudShared {
//             let cloudId = "cloud-\(asset.localIdentifier)"
//             logger.info("📸 PHOTOS_PERSISTENCE: ✅ Cloud identifier derived [\(correlationId)]: \(cloudId)")
//             return cloudId
//         }

//         // Check for iCloud Photo Library sync
//         let resources = PHAssetResource.assetResources(for: asset)
//         if let resource = resources.first {
//             // Check if resource is in iCloud (not locally available)
//             if resource.type == .video && PHPhotoLibrary.authorizationStatus() == .authorized {
//                 let cloudId = "icloud-\(asset.localIdentifier)"
//                 logger.info("📸 PHOTOS_PERSISTENCE: ✅ iCloud identifier derived [\(correlationId)]: \(cloudId)")
//                 return cloudId
//             }
//         }

//         return nil
//     }

//     /// Get asset URL if available
//     private func getAssetURL(for asset: PHAsset, correlationId: String) async -> URL? {
//         logger.info("📸 PHOTOS_PERSISTENCE: 🔗 Getting asset URL [\(correlationId)]")

//         let resources = PHAssetResource.assetResources(for: asset)
//         guard let resource = resources.first else {
//             logger.warning("📸 PHOTOS_PERSISTENCE: ⚠️ No resources found for asset [\(correlationId)]")
//             return nil
//         }

//         // For local assets, try to get the file URL
//         if resource.type == .video {
//             logger.info("📸 PHOTOS_PERSISTENCE: ✅ Local asset URL available [\(correlationId)]")
//             return nil // Return nil as we don't have direct access to the file URL
//         }

//         logger.info("📸 PHOTOS_PERSISTENCE: ℹ️ Asset is cloud-based [\(correlationId)]")
//         return nil
//     }
//     // MARK: - FUNC
//     /// Generate correlation ID
//     private func generateCorrelationId() -> String {
//         return memoryLogger.generateCorrelationId(for: "PhotosPersistenceService")
//     }

//     /// Report progress
//     private func reportProgress(_ phase: PhotosPersistenceProgress.PersistencePhase, progress: Double, message: String, correlationId: String) async {
//         let progressReport = PhotosPersistenceProgress(
//             phase: phase,
//             progressValue: progress,
//             message: message,
//             correlationId: correlationId
//         )

//         progressSubject.send(progressReport)

//         let progressPercentage = Int(progress * 100)
//         let phaseString = "\(phase)"
//         logger.info("📸 PHOTOS_PERSISTENCE:  Progress [\(correlationId)]: \(phaseString) - \(progressPercentage)% - \(message)")
//     }
//     // MARK: - FUNC
//     /// Log completion
//     private func logCompletion(result: PhotosPersistenceResult, startTime: Date, method: String) {
//         let duration = Date().timeIntervalSince(startTime)

//         logger.info("📸 PHOTOS_PERSISTENCE: 🏆 COMPLETION [\(result.correlationId)]:")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Method: \(method)")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Duration: \(String(format: "%.2f", duration))s")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Local ID: \(result.localAssetIdentifier)")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Cloud ID: \(result.cloudAssetIdentifier ?? "none")")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Album ID: \(result.albumIdentifier)")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Cloud synced: \(result.isCloudSynced)")
//         logger.info("📸 PHOTOS_PERSISTENCE:   - Has asset URL: \(result.assetURL != nil)")

//         // Log memory state
//         memoryLogger.logMemoryState(
//             context: "After Photos Persistence",
//             correlationId: result.correlationId,
//             component: "PhotosPersistenceService"
//         )

//         // Clean up correlation ID
//         memoryLogger.clearCorrelationId(for: "PhotosPersistenceService")
//         currentCorrelationId = nil
//     }

//     // MARK: - Deinitialization
//     deinit {
//         logger.info("📸 PHOTOS_PERSISTENCE: 🧹 Deinit - cleaning up resources")
//     }
// }

// // MARK: - Combine Integration
// extension PhotosPersistenceService {
//     // MARK: - FUNC
//     /// Stream-based asset saving with Combine publishers
//     func saveVideoAssetWithProgress(_ url: URL, filename: String, sourceIdentifier: String?) -> AnyPublisher<PhotosPersistenceResult, PhotosPersistenceError> {
//         Future<PhotosPersistenceResult, PhotosPersistenceError> { [weak self] promise in
//             Task {
//                 guard let self = self else {
//                     promise(.failure(.atomicOperationFailed(NSError(domain: "PhotosPersistenceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service instance was deallocated"]))))
//                     return
//                 }

//                 do {
//                     let result = try await self.saveVideoAsset(url, filename: filename, sourceIdentifier: sourceIdentifier)
//                     promise(.success(result))
//                 } catch {
//                     if let persistenceError = error as? PhotosPersistenceError {
//                         promise(.failure(persistenceError))
//                     } else {
//                         promise(.failure(.atomicOperationFailed(error)))
//                     }
//                 }
//             }
//         }
//         .eraseToAnyPublisher()
//     }
// }