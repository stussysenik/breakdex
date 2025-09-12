import Foundation
import AVFoundation
import Photos
import PhotosUI
import OSLog
import CoreData

@MainActor
public class VideoAssetLoader {
    private let imageManager = PHImageManager.default()
    private let correlationID = VideoLogger.generateCorrelationID()
    
    public enum Source {
        case photos(identifier: String)
        case url(URL)
        case move(Move)
    }
    
    public enum VideoAssetLoaderError: Error, LocalizedError {
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
    
    public func loadAsset(from source: Source) async throws -> AVAsset {
        switch source {
        case .photos(let identifier):
            return try await loadFromPhotos(identifier: identifier)
        case .url(let url):
            return AVURLAsset(url: url)
        case .move(let move):
            return try await loadFromMove(move: move)
        }
    }
    
    private func loadFromPhotos(identifier: String) async throws -> AVAsset {
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw VideoAssetLoaderError.assetNotFound
        }
        
        // Request the AVAsset
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return try await requestAVAsset(for: phAsset, options: options)
    }
    
    private func loadFromMove(move: Move) async throws -> AVAsset {
        // Update last accessed date
        move.updateVideoLastAccessedDate()
        
        // Log the operation
        VideoLogger.log("Loading video from move [moveID: \(move.managedObjectID), hasVideo: \(move.hasVideo)]",
                       category: "ASSET_LOADING",
                       correlationID: correlationID)
        
        // Check if the move has a video URL
        guard let videoURL = move.videoURL else {
            let error = VideoAssetLoaderError.assetNotFound
            VideoLogger.error("Move does not have a video URL",
                             error: error,
                             category: "ASSET_LOADING",
                             correlationID: correlationID)
            throw error
        }
        
        // Check if the file exists at the URL
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            let error = VideoAssetLoaderError.assetNotFound
            VideoLogger.error("Video file does not exist at URL: \(videoURL.path)",
                             error: error,
                             category: "ASSET_LOADING",
                             correlationID: correlationID)
            throw error
        }
        
        return AVURLAsset(url: videoURL)
    }
    
    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    continuation.resume(returning: asset)
                } else {
                    continuation.resume(throwing: VideoAssetLoaderError.avAssetCreationFailed)
                }
            }
        }
    }
}