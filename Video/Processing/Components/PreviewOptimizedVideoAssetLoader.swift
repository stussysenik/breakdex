import Foundation
import AVFoundation
import Photos
import PhotosUI
import OSLog
import CoreData

@MainActor
public class PreviewOptimizedVideoAssetLoader {
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
                return "Item identifier is missing"
            case .assetNotFound:
                return "Asset not found"
            case .avAssetCreationFailed:
                return "Failed to create AVAsset"
            case .unsupportedFileType:
                return "Unsupported file type"
            case .dataUnavailable:
                return "Data unavailable"
            case .temporaryFileError(let error):
                return "Temporary file error: \(error.localizedDescription)"
            case .memoryLimitExceeded(let used, let available):
                return "Memory limit exceeded. Used: \(used)MB, Available: \(available)MB"
            }
        }
    }
    
    public init(memoryManager: MemoryManager, logger: AppLogger) {
        self.memoryManager = memoryManager
        self.logger = logger
        logger.info("📦 PreviewOptimizedVideoAssetLoader initialized", metadata: ["correlationID": correlationID])
    }
    
    public func loadAsset(from source: Source) async throws -> AVAsset {
        logger.info("🔄 Loading preview asset from source: \(sourceType(from: source))", metadata: ["correlationID": correlationID])
        
        // Check memory before loading
        let availableMemory = memoryManager.getAvailableMemory()
        let requiredMemory: Int64 = 50 * 1024 * 1024 // 50MB for preview (smaller than regular)
        
        if availableMemory < requiredMemory {
            logger.error("❌ Memory limit exceeded for preview", metadata: [
                "correlationID": correlationID,
                "availableMemory": "\(availableMemory / (1024*1024))MB",
                "requiredMemory": "\(requiredMemory / (1024*1024))MB"
            ])
            throw VideoAssetLoaderError.memoryLimitExceeded(used: requiredMemory, available: availableMemory)
        }
        
        let asset: AVAsset
        
        switch source {
        case .photos(let identifier):
            asset = try await loadAssetFromPhotos(identifier: identifier)
        case .url(let url):
            asset = try await loadAssetFromURL(url)
        case .move(let move):
            asset = try await loadAssetFromMove(move)
        case .asset(let avAsset):
            asset = avAsset
        }
        
        logger.info("✅ Preview asset loaded successfully", metadata: ["correlationID": correlationID])
        return asset
    }
    
    private func loadAssetFromPhotos(identifier: String) async throws -> AVAsset {
        logger.info("📱 Loading preview asset from Photos", metadata: ["correlationID": correlationID])
        
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            logger.error("❌ Asset not found in Photos", metadata: ["correlationID": correlationID])
            throw VideoAssetLoaderError.assetNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .automatic // Use automatic for preview
            options.isNetworkAccessAllowed = true
            
            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                Task { @MainActor in
                    if let error = info?[PHImageErrorKey] as? Error {
                        self.logger.error("❌ Failed to load preview asset from Photos: \(error.localizedDescription)", metadata: ["correlationID": self.correlationID])
                        continuation.resume(throwing: VideoAssetLoaderError.avAssetCreationFailed)
                        return
                    }
                    
                    guard let avAsset = avAsset else {
                        self.logger.error("❌ No AVAsset returned from Photos", metadata: ["correlationID": self.correlationID])
                        continuation.resume(throwing: VideoAssetLoaderError.avAssetCreationFailed)
                        return
                    }
                    
                    self.logger.info("✅ Preview asset loaded from Photos successfully", metadata: ["correlationID": self.correlationID])
                    continuation.resume(returning: avAsset)
                }
            }
        }
    }
    
    private func loadAssetFromURL(_ url: URL) async throws -> AVAsset {
        logger.info("🌐 Loading preview asset from URL", metadata: ["correlationID": correlationID])
        
        // Check if URL is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("❌ File does not exist at URL", metadata: ["correlationID": correlationID])
            throw VideoAssetLoaderError.assetNotFound
        }
        
        do {
            let asset = AVAsset(url: url)
            
            // Check if asset is playable
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                logger.error("❌ Asset is not playable", metadata: ["correlationID": correlationID])
                throw VideoAssetLoaderError.unsupportedFileType
            }
            
            logger.info("✅ Preview asset loaded from URL successfully", metadata: ["correlationID": correlationID])
            return asset
        } catch {
            logger.error("❌ Failed to load preview asset from URL: \(error.localizedDescription)", metadata: ["correlationID": correlationID])
            throw VideoAssetLoaderError.avAssetCreationFailed
        }
    }
    
    private func loadAssetFromMove(_ move: Move) async throws -> AVAsset {
        logger.info("🎯 Loading preview asset from Move", metadata: ["correlationID": correlationID])
        
        guard let videoURL = move.videoURL else {
            logger.error("❌ Move has no video URL", metadata: ["correlationID": correlationID])
            throw VideoAssetLoaderError.assetNotFound
        }
        
        return try await loadAssetFromURL(videoURL)
    }
    
    private func sourceType(from source: Source) -> String {
        switch source {
        case .photos:
            return "photos"
        case .url:
            return "url"
        case .move:
            return "move"
        case .asset:
            return "asset"
        }
    }
}