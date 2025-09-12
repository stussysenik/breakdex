import Foundation
import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import OSLog

// MARK: - Video Loading Errors
public enum VideoLoaderError: Error, LocalizedError {
    case itemIdentifierMissing
    case assetNotFound
    case avAssetCreationFailed
    case unsupportedFileType
    case dataUnavailable
    case temporaryFileError(Error)
    
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
        }
    }
}

// MARK: - Video Loader Result
public struct VideoLoaderResult {
    let asset: AVAsset
    let photosIdentifier: String
    let filename: String
}

// MARK: - VideoLoader Actor
public actor VideoLoader {
    private let imageManager = PHImageManager.default()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoader")
    
    public func loadVideo(fromPickerItem item: PhotosPickerItem) async throws -> VideoLoaderResult {
        if let identifier = item.itemIdentifier {
            // Load from Photos library using the identifier
            return try await loadFromPhotos(identifier: identifier)
        } else {
            // Load directly from the item's data
            return try await loadDirectly(from: item)
        }
    }
    
    public func loadVideo(fromIdentifier identifier: String) async throws -> VideoLoaderResult {
        // Load from Photos library using the identifier
        return try await loadFromPhotos(identifier: identifier)
    }
    
    // MARK: - Private Loading Methods
    
    private func loadFromPhotos(identifier: String) async throws -> VideoLoaderResult {
        // 1. Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw VideoLoaderError.assetNotFound
        }
        
        // 2. Request the AVAsset
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let avAsset = try await requestAVAsset(for: phAsset, options: options)
        
        // 3. Get the original filename
        let filename = await fetchFilename(for: phAsset)
        
        return VideoLoaderResult(asset: avAsset, photosIdentifier: identifier, filename: filename)
    }
    
    private func loadDirectly(from item: PhotosPickerItem) async throws -> VideoLoaderResult {
        // 1. Ensure it's a movie type
        guard item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.movie) }) else {
            throw VideoLoaderError.unsupportedFileType
        }
        
        // 2. Load transferable data
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw VideoLoaderError.dataUnavailable
        }
        
        // 3. Create a temporary file to host the data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        do {
            try data.write(to: tempURL)
        } catch {
            throw VideoLoaderError.temporaryFileError(error)
        }
        
        // 4. Create an AVURLAsset from the temporary file
        let avAsset = AVURLAsset(url: tempURL)
        
        // Since we don't have a filename, we'll generate one.
        let filename = "video-\(Date().timeIntervalSince1970).mov"
        
        // Create a temporary identifier for tracking
        let tempIdentifier = "temp-\(UUID().uuidString)"
        
        return VideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename)
    }
    
    // MARK: - Helper Methods
    
    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                Task {
                    if let error = info?[PHImageErrorKey] as? Error {
                        self.logger.error("🎬 VIDEO_LOADER: AVAsset request failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let asset = avAsset {
                        self.logger.info("🎬 VIDEO_LOADER: AVAsset request succeeded.")
                        continuation.resume(returning: asset)
                    } else {
                        self.logger.error("🎬 VIDEO_LOADER: AVAsset request failed with unknown error.")
                        continuation.resume(throwing: VideoLoaderError.avAssetCreationFailed)
                    }
                }
            }
        }
    }
    
    private func fetchFilename(for phAsset: PHAsset) async -> String {
        let resources = PHAssetResource.assetResources(for: phAsset)
        if let resource = resources.first(where: { $0.type == .video }) {
            return resource.originalFilename
        }
        return "Video" // Fallback filename
    }
}
