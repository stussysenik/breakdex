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
        logger.info("💾 Saving video to Photos library", metadata: nil)
        
        // Check Photos library access
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            let error = VideoProcessingError.videoProcessingFailed(
                operation: "saving to photos",
                underlyingError: NSError(domain: "Photos", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos library access denied"])
            )
            logger.error("❌ Photos library access denied: \(error.localizedDescription)", metadata: nil)
            throw error
        }
        
        // Create a temporary file URL for the exported video
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        // Export the video to the temporary URL
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            let error = VideoProcessingError.assetCreationFailed
            logger.error("❌ Failed to create export session: \(error.localizedDescription)", metadata: nil)
            throw error
        }
        
        exportSession.outputURL = tempURL
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
                operation: "saving to photos",
                underlyingError: error
            )
        }
        
        // Save the video to Photos library
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
            }) { success, error in
                if success {
                    // Generate a unique identifier for the saved video
                    let identifier = "photos-\(UUID().uuidString)"
                    self.logger.info("✅ Video saved to Photos library successfully", metadata: ["identifier": identifier])
                    continuation.resume(returning: identifier)
                } else {
                    let error = error ?? NSError(domain: "Photos", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error saving to Photos library"])
                    self.logger.error("❌ Failed to save video to Photos library: \(error.localizedDescription)", metadata: nil)
                    continuation.resume(throwing: VideoProcessingError.videoProcessingFailed(
                        operation: "saving to photos",
                        underlyingError: error
                    ))
                }
            }
        }
    }
}