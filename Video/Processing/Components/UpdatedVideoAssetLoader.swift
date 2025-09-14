import Foundation
import AVFoundation
import Photos
import PhotosUI
import OSLog
import CoreData

@MainActor
public class UpdatedVideoAssetLoader {
    private let imageManager = PHImageManager.default()
    private let correlationID = UUID().uuidString
    private let memoryManager: MemoryManager
    private let logger: AppLogger
    
    public enum Source {
        case photos(identifier: String)
        case url(URL)
        case move(Move)
        case asset(AVAsset)
    }
    
    public enum VideoAssetLoaderError: Error, LocalizedError {
        case itemIdentifierMissing
        case assetNotFound
        case avAssetCreationFailed
        case unsupportedFileType
        case dataUnavailable
        case temporaryFileError(Error)
        case memoryLimitExceeded(used: Int64, available: Int64)
        
        public var errorDescription: String? {
            switch self {
            case .itemIdentifierMissing:
                return "The selected item does not have a valid identifier."
            case .assetNotFound:
                return "Could not find the video in the Photos library."
            case .avAssetCreationFailed:
                return "Failed to create a playable video asset."
            case .unsupportedFileType:
                return "The selected file type is not a supported video format."
            case .dataUnavailable:
                return "Could not retrieve video data for the selected item."
            case .temporaryFileError(let underlyingError):
                return "Failed to save video data to a temporary file: \(underlyingError.localizedDescription)"
            case .memoryLimitExceeded(let used, let available):
                return "Memory limit exceeded. Used: \(used)MB, Available: \(available)MB"
            }
        }
    }
    
    init(memoryManager: MemoryManager, logger: AppLogger) {
        self.memoryManager = memoryManager
        self.logger = logger
    }
    
    public func loadAsset(from source: Source) async throws -> AVAsset {
        // Check memory before loading
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 200 * 1024 * 1024 // 200MB
        
        if availableMemory < memoryThreshold {
            logger.warning("⚠️ Low memory before loading asset: \(availableMemory / (1024 * 1024))MB", metadata: nil)
            memoryManager.clearCache()
            
            // If still low, throw error
            if memoryManager.getAvailableMemory() < memoryThreshold {
                let error = VideoAssetLoaderError.memoryLimitExceeded(
                    used: memoryManager.getUsedMemory() / (1024 * 1024),
                    available: availableMemory / (1024 * 1024)
                )
                logger.error("❌ Memory limit exceeded: \(error.localizedDescription)", metadata: nil)
                throw error
            }
        }
        
        switch source {
        case .photos(let identifier):
            return try await loadFromPhotos(identifier: identifier)
        case .url(let url):
            return AVURLAsset(url: url)
        case .move(let move):
            return try await loadFromMove(move: move)
        case .asset(let asset):
            // Return the pre-loaded asset directly without reloading it
            logger.info("✅ Using pre-loaded asset directly", metadata: nil)
            return asset
        }
    }
    
    private func loadFromPhotos(identifier: String) async throws -> AVAsset {
        logger.info("🔄 Loading asset from Photos library", metadata: ["identifier": identifier])
        
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            let error = VideoAssetLoaderError.assetNotFound
            logger.error("❌ PHAsset not found for identifier: \(identifier)", metadata: nil)
            throw error
        }
        
        // Request the AVAsset with memory-efficient options
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        // Use medium quality format to reduce memory usage
        options.deliveryMode = .mediumQualityFormat
        
        logger.info("🔄 Requesting AVAsset with medium quality options", metadata: nil)
        let asset = try await requestAVAsset(for: phAsset, options: options)
        
        logger.info("✅ Asset loaded successfully from Photos", metadata: ["identifier": identifier])
        return asset
    }
    
    private func loadFromMove(move: Move) async throws -> AVAsset {
        // Update last accessed date
        move.updateVideoLastAccessedDate()
        
        // Log the operation
        logger.info("🔄 Loading video from move", metadata: [
            "moveID": move.managedObjectID,
            "hasVideo": move.hasVideo
        ])
        
        // Check if the move has a video URL
        guard let videoURL = move.videoURL else {
            let error = VideoAssetLoaderError.assetNotFound
            logger.error("❌ Move does not have a video URL", metadata: nil)
            throw error
        }
        
        // Check if the file exists at the URL
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            let error = VideoAssetLoaderError.assetNotFound
            logger.error("❌ Video file does not exist at URL: \(videoURL.path)", metadata: nil)
            throw error
        }
        
        logger.info("✅ Asset loaded successfully from move", metadata: ["moveID": move.managedObjectID])
        return AVURLAsset(url: videoURL)
    }
    
    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    self.logger.error("❌ Failed to request AVAsset: \(error.localizedDescription)", metadata: nil)
                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    self.logger.info("✅ AVAsset requested successfully", metadata: nil)
                    continuation.resume(returning: asset)
                } else {
                    let error = VideoAssetLoaderError.avAssetCreationFailed
                    self.logger.error("❌ No AVAsset or error received from PHImageManager", metadata: nil)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}