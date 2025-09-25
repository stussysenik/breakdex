import Foundation
import AVFoundation
import Photos

// MARK: - Video Saver Protocol
protocol VideoSaver {
    func saveVideo(_ asset: AVAsset, filename: String) async throws -> URL
    func saveToPhotosLibrary(_ asset: AVAsset) async throws -> String
}

// MARK: - Video Saver Implementation
final class VideoSaverImpl: VideoSaver {
    private let logger: AppLogger
    private let breakDexAlbumManager = BreakDexAlbumManager.shared // ✨ ADD: BreakDex album manager integration

    init(logger: AppLogger) {
        self.logger = logger
    }
    
    func saveVideo(_ asset: AVAsset, filename: String) async throws -> URL {
        logger.info("💾 Saving video to app storage", metadata: ["filename": filename])
        
        // Create a URL in the app's documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videoURL = documentsDirectory.appendingPathComponent(filename)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: videoURL.path) {
            try FileManager.default.removeItem(at: videoURL)
            logger.info("🗑️ Removed existing video file", metadata: nil)
        }
        
        // Export the video to the specified URL
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            let error = VideoProcessingError.assetCreationFailed
            logger.error("❌ Failed to create export session: \(error.localizedDescription)", metadata: nil)
            throw error
        }
        
        exportSession.outputURL = videoURL
        exportSession.outputFileType = .mov
        
        // Export the video asynchronously
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }
        
        // Check for errors
        if let error = exportSession.error {
            logger.error("❌ Video export failed: \(error.localizedDescription)", metadata: nil)
            throw VideoProcessingError.videoProcessingFailed(
                operation: "saving",
                underlyingError: error
            )
        }
        
        logger.info("✅ Video saved successfully", metadata: ["url": videoURL.absoluteString])
        
        return videoURL
    }
    
    func saveToPhotosLibrary(_ asset: AVAsset) async throws -> String {
        logger.info("💾 Saving video to Photos library and BreakDex album...", metadata: nil)

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            let error = VideoProcessingError.photosPermissionDenied
            logger.error("❌ Photos library access denied.", metadata: nil)
            throw error
        }

        // Export the video to a temporary URL first
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.assetCreationFailed
        }
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov

        await exportSession.export()

        if let error = exportSession.error {
            logger.error("❌ Video export to temporary file failed: \(error.localizedDescription)", metadata: nil)
            throw VideoProcessingError.videoProcessingFailed(operation: "exporting for photos save", underlyingError: error)
        }

        // Find or create the "BreakDex" album
        let album = try await breakDexAlbumManager.ensureBreakDexAlbum()

        // Atomically save the video and add it to the album
        return try await withCheckedThrowingContinuation { continuation in
            var placeholder: PHObjectPlaceholder?

            PHPhotoLibrary.shared().performChanges({
                // 1. Create the asset creation request from the temporary file.
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL) else {
                    return
                }
                placeholder = assetRequest.placeholderForCreatedAsset

                // 2. Create the album change request.
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                      let assetPlaceholder = placeholder else {
                    return
                }

                // 3. Add the new asset placeholder to the album change request.
                albumChangeRequest.addAssets([assetPlaceholder] as NSArray)

            }) { success, error in
                // Clean up the temporary file regardless of outcome
                try? FileManager.default.removeItem(at: tempURL)

                if success, let localIdentifier = placeholder?.localIdentifier {
                    self.logger.info("✅ Video saved to Photos and added to BreakDex album successfully.", metadata: [
                        "identifier": localIdentifier
                    ])
                    continuation.resume(returning: localIdentifier)
                } else {
                    let saveError = error ?? NSError(domain: "Photos", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error saving to Photos."])
                    self.logger.error("❌ Failed to save video to Photos library: \(saveError.localizedDescription)", metadata: nil)
                    continuation.resume(throwing: VideoProcessingError.photosSaveFailed(underlyingError: saveError))
                }
            }
        }
    }
}