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
    // Using new AlbumManager singleton for centralized album management

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

        // ✅ CRITICAL: Add defer block to ensure temporary file cleanup
        defer {
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                    logger.info("🧹 Temporary video file cleaned up: \(tempURL.lastPathComponent)", metadata: nil)
                }
            } catch {
                logger.warning("⚠️ Failed to clean up temporary file: \(error.localizedDescription)", metadata: nil)
            }
        }

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

        // Use the new atomic PhotoKitService to save video to BreakDex album
        do {
            let localIdentifier = try await PhotoKitService.shared.saveVideoToBreakDexAlbum(tempURL)
            logger.info("✅ Video saved to Photos and BreakDex album atomically.", metadata: [
                "identifier": localIdentifier
            ])
            return localIdentifier
        } catch {
            logger.error("❌ Atomic save to BreakDex album failed: \(error.localizedDescription)", metadata: nil)
            throw VideoProcessingError.photosSaveFailed(underlyingError: error)
        }
    }
}