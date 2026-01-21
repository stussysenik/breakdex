// import AVFoundation
// import Foundation
// import Photos

// // MARK: - Video Saver Protocol
// /// Protocol for saving video assets to different destinations
// public protocol VideoSaver {
//     func saveVideo(_ asset: AVAsset) async throws -> URL
//     func saveVideo(_ asset: AVAsset, to destination: VideoSaverDestination) async throws -> URL
// }

// // MARK: - Video Saver Destination
// /// Enum representing different save destinations
// public enum VideoSaverDestination {
//     case temporaryDirectory
//     case documentsDirectory
//     case photoLibrary
//     case custom(URL)
// }

// // MARK: - Simple Video Saver
// /// Essentialist implementation of VideoSaver protocol
// /// Focuses on core functionality without over-engineering
// public struct SimpleVideoSaver: VideoSaver {

//     private let logger = Logger.video

//     public init() {}

//     /// Save video to temporary directory (default behavior)
//     public func saveVideo(_ asset: AVAsset) async throws -> URL {
//         return try await saveVideo(asset, to: .temporaryDirectory)
//     }

//     /// Save video to specified destination
//     public func saveVideo(_ asset: AVAsset, to destination: VideoSaverDestination) async throws -> URL {
//         logger.info("Saving video to destination: \(destination)")

//         switch destination {
//         case .temporaryDirectory:
//             return try await saveToTemporaryDirectory(asset: asset)
//         case .documentsDirectory:
//             return try await saveToDocumentsDirectory(asset: asset)
//         case .photoLibrary:
//             return try await saveToPhotoLibrary(asset: asset)
//         case .custom(let url):
//             return try await saveToCustomURL(asset: asset, url: url)
//         }
//     }

//     // MARK: - Private Save Methods
//     private func saveToTemporaryDirectory(asset: AVAsset) async throws -> URL {
//         let tempDir = FileManager.default.temporaryDirectory
//         let fileName = "video_\(UUID().uuidString).mov"
//         let outputURL = tempDir.appendingPathComponent(fileName)

//         return try await exportAsset(asset: asset, to: outputURL)
//     }

//     private func saveToDocumentsDirectory(asset: AVAsset) async throws -> URL {
//         let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//         let fileName = "video_\(UUID().uuidString).mov"
//         let outputURL = documentsDir.appendingPathComponent(fileName)

//         return try await exportAsset(asset: asset, to: outputURL)
//     }

//     private func saveToPhotoLibrary(asset: AVAsset) async throws -> URL {
//         // First export to temporary location
//         let tempURL = try await saveToTemporaryDirectory(asset: asset)

//         // Then save to photo library
//         try await saveToPhotoLibraryAt(url: tempURL)

//         // Return temporary URL (photo library doesn't provide URLs)
//         return tempURL
//     }

//     private func saveToCustomURL(asset: AVAsset, url: URL) async throws -> URL {
//         return try await exportAsset(asset: asset, to: url)
//     }

//     // MARK: - Export Implementation
//     private func exportAsset(asset: AVAsset, to outputURL: URL) async throws -> URL {
//         logger.info("Exporting video asset to: \(outputURL.path)")

//         // Create export session
//         guard let exportSession = AVAssetExportSession(
//             asset: asset,
//             presetName: AVAssetExportPresetHighestQuality
//         ) else {
//             throw VideoSaverError.exportSessionCreationFailed
//         }

//         exportSession.outputURL = outputURL
//         exportSession.outputFileType = .mov
//         exportSession.shouldOptimizeForNetworkUse = true

//         // Perform export
//         await exportSession.export()

//         switch exportSession.status {
//         case .completed:
//             logger.info("Video export completed successfully")
//             return outputURL
//         case .failed:
//             let underlyingError = exportSession.error
//             logger.error("Video export failed: \(underlyingError?.localizedDescription ?? "Unknown error")")
//             throw VideoSaverError.exportFailed(underlying: underlyingError)
//         case .cancelled:
//             logger.info("Video export cancelled")
//             throw VideoSaverError.exportCancelled
//         default:
//             throw VideoSaverError.unknownExportStatus
//         }
//     }

//     // MARK: - Photo Library Access
//     private func saveToPhotoLibraryAt(url: URL) async throws {
//         logger.info("Saving video to photo library")

//         // Check photo library permissions
//         let authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
//         guard authorizationStatus == .authorized || authorizationStatus == .limited else {
//             throw VideoSaverError.photoLibraryAccessDenied
//         }

//         // Save to photo library
//         try await withCheckedThrowingContinuation { continuation in
//             PHPhotoLibrary.shared().performChanges({
//                 PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
//             }) { success, error in
//                 if success {
//                     continuation.resume()
//                 } else {
//                     continuation.resume(throwing: VideoSaverError.photoLibrarySaveFailed(underlying: error))
//                 }
//             }
//         }

//         logger.info("Video saved to photo library successfully")
//     }
// }

// // MARK: - Video Saver Errors
// public enum VideoSaverError: Error, LocalizedError {
//     case exportSessionCreationFailed
//     case exportFailed(underlying: Error? = nil)
//     case exportCancelled
//     case unknownExportStatus
//     case photoLibraryAccessDenied
//     case photoLibrarySaveFailed(underlying: Error? = nil)
//     case fileSystemError(underlying: Error)

//     public var errorDescription: String? {
//         switch self {
//         case .exportSessionCreationFailed:
//             return "Failed to create video export session"
//         case .exportFailed(let error):
//             if let error = error {
//                 return "Video export failed: \(error.localizedDescription)"
//             } else {
//                 return "Video export failed"
//             }
//         case .exportCancelled:
//             return "Video export was cancelled"
//         case .unknownExportStatus:
//             return "Unknown video export status"
//         case .photoLibraryAccessDenied:
//             return "Photo library access denied. Please enable permissions in Settings."
//         case .photoLibrarySaveFailed(let error):
//             if let error = error {
//                 return "Failed to save to photo library: \(error.localizedDescription)"
//             } else {
//                 return "Failed to save to photo library"
//             }
//         case .fileSystemError(let error):
//             return "File system error: \(error.localizedDescription)"
//         }
//     }
// }