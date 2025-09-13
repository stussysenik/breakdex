import Foundation
import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import SwiftUI

import OSLog

// Use the native PhotosUI PhotosPickerItem type

// MARK: - Video Loading Errors
public enum AddMoveVideoLoaderError: Error, LocalizedError {
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
public struct AddMoveVideoLoaderResult {
    let asset: AVAsset
    let photosIdentifier: String
    let filename: String
}

// MARK: - VideoLoader Actor
public actor AddMoveVideoLoader {
    private let imageManager = PHImageManager.default()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "VideoLoader")

    public func loadVideo(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        logger.info("🎬 VIDEO_LOADER: loadVideo called")
        logger.info("🎬 VIDEO_LOADER: Item ID: \(item.itemIdentifier ?? "nil")")
        logger.info("🎬 VIDEO_LOADER: Supported content types: \(item.supportedContentTypes)")
        logger.info("🎬 VIDEO_LOADER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")

        if let identifier = item.itemIdentifier {
            logger.info("🎬 VIDEO_LOADER: Loading from Photos library")
            return try await loadFromPhotos(identifier: identifier)
        } else {
            logger.info("🎬 VIDEO_LOADER: Loading directly from PhotosPicker")
            return try await loadDirectly(from: item)
        }
    }

    // MARK: - Private Loading Methods

    private func loadFromPhotos(identifier: String) async throws -> AddMoveVideoLoaderResult {
        logger.info("🎬 VIDEO_LOADER: loadFromPhotos called with identifier: \(identifier)")
        logger.info("🎬 VIDEO_LOADER: Fetching PHAsset from Photos library")

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        logger.info("🎬 VIDEO_LOADER: Fetch result count: \(fetchResult.count)")

        guard let phAsset = fetchResult.firstObject else {
            logger.error("🎬 VIDEO_LOADER: PHAsset not found for identifier: \(identifier)")
            throw AddMoveVideoLoaderError.assetNotFound
        }

        logger.info("🎬 VIDEO_LOADER: PHAsset found")
        logger.info("🎬 VIDEO_LOADER: Asset media type: \(phAsset.mediaType.rawValue)")
        logger.info("🎬 VIDEO_LOADER: Asset duration: \(phAsset.duration)")

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        logger.info("🎬 VIDEO_LOADER: Requesting AVAsset with high quality options")

        let avAsset = try await requestAVAsset(for: phAsset, options: options)
        logger.info("🎬 VIDEO_LOADER: AVAsset received successfully")

        let filename = await fetchFilename(for: phAsset)
        logger.info("🎬 VIDEO_LOADER: Filename fetched: \(filename)")

        logger.info("🎬 VIDEO_LOADER: Returning VideoLoaderResult from Photos")
        return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: identifier, filename: filename)
    }

    private func loadDirectly(from item: PhotosPickerItem) async throws -> AddMoveVideoLoaderResult {
        logger.info("🎬 VIDEO_LOADER: loadDirectly called")
        logger.info("🎬 VIDEO_LOADER: Checking content types for movie support")

        guard item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.movie) }) else {
            logger.error("🎬 VIDEO_LOADER: Unsupported file type - no movie content type found")
            throw AddMoveVideoLoaderError.unsupportedFileType
        }

        logger.info("🎬 VIDEO_LOADER: Content type supported, loading transferable data")
        guard let data = try await item.loadTransferable(type: Data.self) else {
            logger.error("🎬 VIDEO_LOADER: Failed to load transferable data")
            throw AddMoveVideoLoaderError.dataUnavailable
        }

        logger.info("🎬 VIDEO_LOADER: Data loaded successfully, size: \(data.count) bytes")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        logger.info("🎬 VIDEO_LOADER: Created temp URL: \(tempURL.absoluteString)")

        do {
            logger.info("🎬 VIDEO_LOADER: Writing data to temp file")
            try data.write(to: tempURL)
            logger.info("🎬 VIDEO_LOADER: Data written to temp file successfully")
        } catch {
            logger.error("🎬 VIDEO_LOADER: Failed to write data to temp file: \(error.localizedDescription)")
            throw AddMoveVideoLoaderError.temporaryFileError(error)
        }

        let avAsset = AVURLAsset(url: tempURL)
        let filename = "video-\(Date().timeIntervalSince1970).mov"
        let tempIdentifier = "temp-\(UUID().uuidString)"

        logger.info("🎬 VIDEO_LOADER: Created AVAsset from temp URL")
        logger.info("🎬 VIDEO_LOADER: Generated filename: \(filename)")
        logger.info("🎬 VIDEO_LOADER: Generated temp identifier: \(tempIdentifier)")
        logger.info("🎬 VIDEO_LOADER: Returning VideoLoaderResult from direct load")

        return AddMoveVideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename)
    }

    // MARK: - Helper Methods

    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        logger.info("🎬 VIDEO_LOADER: requestAVAsset called")
        logger.info("🎬 VIDEO_LOADER: Asset local identifier: \(phAsset.localIdentifier)")
        logger.info("🎬 VIDEO_LOADER: Network access allowed: \(options.isNetworkAccessAllowed)")
        logger.info("🎬 VIDEO_LOADER: Delivery mode: \(options.deliveryMode.rawValue)")

        return try await withCheckedThrowingContinuation { [self] continuation in
            self.logger.info("🎬 VIDEO_LOADER: Starting PHImageManager.requestAVAsset")
            self.imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                self.logger.info("🎬 VIDEO_LOADER: PHImageManager request completed")

                if let error = info?[PHImageErrorKey] as? Error {
                    self.logger.error("🎬 VIDEO_LOADER: PHImageManager error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    self.logger.info("🎬 VIDEO_LOADER: AVAsset received successfully")
                    self.logger.info("🎬 VIDEO_LOADER: Asset type: \(type(of: asset))")
                    if let urlAsset = asset as? AVURLAsset {
                        self.logger.info("🎬 VIDEO_LOADER: Asset URL: \(urlAsset.url.absoluteString)")
                    }
                    continuation.resume(returning: asset)
                } else {
                    self.logger.error("🎬 VIDEO_LOADER: No AVAsset or error received from PHImageManager")
                    continuation.resume(throwing: AddMoveVideoLoaderError.avAssetCreationFailed)
                }
            }
        }
    }

    private func fetchFilename(for phAsset: PHAsset) async -> String {
        logger.info("🎬 VIDEO_LOADER: fetchFilename called")
        let resources = PHAssetResource.assetResources(for: phAsset)
        logger.info("🎬 VIDEO_LOADER: Found \(resources.count) asset resources")

        if let resource = resources.first(where: { $0.type == .video }) {
            logger.info("🎬 VIDEO_LOADER: Video resource found: \(resource.originalFilename)")
            return resource.originalFilename
        }

        logger.info("🎬 VIDEO_LOADER: No video resource found, using default filename")
        return "Video"
    }
}
