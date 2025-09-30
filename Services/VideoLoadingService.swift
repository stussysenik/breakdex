//
//  VideoLoadingService.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/27/25.
//

import Foundation
import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import SwiftUI
import OSLog
import CoreMedia

// MARK: - Category Theory Analysis
/*
 CATEGORY THEORY ANALYSIS:

 Current System (Problematic):
 - Objects: PhotosPickerItem, Data, AVAsset (inefficient mapping)
 - Morphisms: loadTransferable(type: Data.self) → memory overload
 - Functor: Inefficient - maps entire video to memory
 - Isomorphism: Broken - WYSIWYG not maintained

 Ideal System (Target):
 - Objects: PhotosPickerItem, URL, AVAsset (streaming mapping)
 - Morphisms: loadTransferable(type: URL.self) → streaming file copy
 - Functor: Efficient - maps source to destination without memory load
 - Isomorphism: Preserved - WYSIWYG maintained through proper transforms
 - Adjoint: Atomic operations prevent race conditions
 - Object Gap: Closed by adding cloud identifier
*/

// MARK: - Video Loading Errors
public enum VideoLoadingError: Error, LocalizedError {
    case itemIdentifierMissing
    case assetNotFound
    case avAssetCreationFailed
    case unsupportedFileType
    case dataUnavailable
    case temporaryFileError(Error)
    case transferableNotSupported
    case streamingFailed(Error)
    case validationFailed(String)

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
        case .transferableNotSupported:
            return "Transferable type not supported by the PhotosPicker item."
        case .streamingFailed(let underlyingError):
            return "Streaming file copy failed: \(underlyingError.localizedDescription)"
        case .validationFailed(let reason):
            return "Video validation failed: \(reason)"
        }
    }
}

// MARK: - Video Loading Result
public struct VideoLoadingResult {
    let asset: AVAsset
    let photosIdentifier: String?
    let cloudIdentifier: String?
    let filename: String
    let temporaryFileURL: URL?
    let sourceType: VideoSourceType
    let fileSize: Int64?
    let duration: CMTime
    let correlationId: String
}

// MARK: - Video Source Type
public enum VideoSourceType {
    case photosLibrary
    case directPicker
    case fileURL
    case cloudAsset

    var description: String {
        switch self {
        case .photosLibrary: return "Photos Library"
        case .directPicker: return "Direct Picker"
        case .fileURL: return "File URL"
        case .cloudAsset: return "Cloud Asset"
        }
    }
}

// MARK: - Photo File Representation for Size Pre-fetching
// Simplified structure to avoid Transferable complexity for now
struct PhotoFileRepresentation {
    let size: Int64
    let sourceURL: URL
}

// VideoLoadingProgress is now defined in AddMoveFlowState.swift

// MARK: - Video Loading Service Protocol
@preconcurrency
public protocol ModernVideoLoadingServiceProtocol: AnyObject {
    func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoadingResult
    func loadVideo(from url: URL) async throws -> VideoLoadingResult
    func loadVideo(from phAsset: PHAsset) async throws -> VideoLoadingResult
    func cleanupTemporaryFiles() async
    var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> { get }
}

// MARK: - Unified Video Loading Service
@MainActor
@preconcurrency
public final class ModernVideoLoadingService: ModernVideoLoadingServiceProtocol {

    // MARK: - Properties
    private let imageManager = PHImageManager.default()
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎬 VideoLoadingService")
    private let memoryLogger = CentralizedMemoryLogger.shared

    // Progress tracking
    private let progressSubject = PassthroughSubject<VideoLoadingProgress, Never>()
    public var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // Performance tracking
    private var operationTimings: [String: TimeInterval] = [:]
    private var currentCorrelationId: String?

    // Temporary file management
    private var temporaryFiles: Set<URL> = []

    // MARK: - Initialization
    public init() {
        logger.info("🎬 VIDEO_LOADING: 🚀 Initialized - streaming-based video loading service")
    }

    // MARK: - Public API

    /// Load video from PhotosPicker item using streaming approach
    public func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoadingResult {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info("🎬 VIDEO_LOADING: 🚀 Loading from PhotosPicker [\(correlationId)]")
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        do {
            // 🎯 STEP 1: Get file representation to know the size beforehand
            logger.info("🎬 VIDEO_LOADING: 📊 Fetching file metadata [\(correlationId)]")
            let totalBytes = try await getFileSize(from: item, correlationId: correlationId)

            // 🎯 STEP 2: Report transferring phase with total size
            await reportProgress(.transferring, correlationId: correlationId)

            // Try streaming URL approach first
            if let urlResult = try await loadViaStreaming(from: item, totalBytes: totalBytes, correlationId: correlationId) {
                await reportProgress(.creatingAsset, correlationId: correlationId)
                logCompletion(result: urlResult, startTime: startTime, method: "streaming")
                return urlResult
            }

            // Fallback to PHAsset loading
            await reportProgress(.transferring, correlationId: correlationId)

            if let assetResult = try await loadViaPhotosLibrary(from: item, correlationId: correlationId) {
                await reportProgress(.creatingAsset, correlationId: correlationId)
                logCompletion(result: assetResult, startTime: startTime, method: "photos_library")
                return assetResult
            }

            throw VideoLoadingError.transferableNotSupported

        } catch {
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error("🎬 VIDEO_LOADING: ❌ Loading failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Load video from URL using streaming approach
    public func loadVideo(from url: URL) async throws -> VideoLoadingResult {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info("🎬 VIDEO_LOADING: 🚀 Loading from URL [\(correlationId)]: \(url.lastPathComponent)")
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        do {
            let fileSize = try await getFileSize(url)
            await reportProgress(.transferring, correlationId: correlationId)

            let result = try await loadFromURL(url, correlationId: correlationId)

            await reportProgress(.creatingAsset, correlationId: correlationId)
            logCompletion(result: result, startTime: startTime, method: "url_streaming")

            return result

        } catch {
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error("🎬 VIDEO_LOADING: ❌ URL loading failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Load video from PHAsset
    public func loadVideo(from phAsset: PHAsset) async throws -> VideoLoadingResult {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info("🎬 VIDEO_LOADING: 🚀 Loading from PHAsset [\(correlationId)]: \(phAsset.localIdentifier)")
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        do {
            let fileSize = await getPHAssetFileSize(phAsset)
            await reportProgress(.transferring, correlationId: correlationId)

            let result = try await loadFromPHAsset(phAsset, correlationId: correlationId)

            await reportProgress(.creatingAsset, correlationId: correlationId)
            logCompletion(result: result, startTime: startTime, method: "phasset")

            return result

        } catch {
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error("🎬 VIDEO_LOADING: ❌ PHAsset loading failed [\(correlationId)]: \(error)")
            throw error
        }
    }

    /// Clean up temporary files
    public func cleanupTemporaryFiles() async {
        logger.info("🎬 VIDEO_LOADING: 🧹 Cleaning up \(self.temporaryFiles.count) temporary files")

        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                logger.info("🎬 VIDEO_LOADING: ✅ Removed temporary file: \(url.lastPathComponent)")
            } catch {
                logger.warning("🎬 VIDEO_LOADING: ⚠️ Failed to remove temporary file: \(url.lastPathComponent) - \(error)")
            }
        }

        temporaryFiles.removeAll()
    }

    // MARK: - Private Loading Methods

    /// Load via streaming URL transfer (memory-efficient)
    private func loadViaStreaming(from item: PhotosPickerItem, totalBytes: Int64, correlationId: String) async throws -> VideoLoadingResult? {
        logger.info("🎬 VIDEO_LOADING: 🔄 Attempting streaming URL transfer [\(correlationId)]")

        let streamingStart = Date()

        do {
            // 🎯 CRITICAL FIX: Use URL.self for streaming instead of Data.self
            guard let sourceURL = try await item.loadTransferable(type: URL.self) else {
                logger.info("🎬 VIDEO_LOADING: ℹ️ URL transfer not supported, will try other methods [\(correlationId)]")
                return nil
            }

            logger.info("🎬 VIDEO_LOADING: ✅ URL transfer successful [\(correlationId)]: \(sourceURL.lastPathComponent)")

            // Create streaming destination
            let tempURL = createTemporaryURL(filename: sourceURL.lastPathComponent)
            temporaryFiles.insert(tempURL)

            // Stream copy without loading into memory - simulate progress for atomic operation
            await reportProgress(.transferring, correlationId: correlationId)

            try await streamCopy(from: sourceURL, to: tempURL, correlationId: correlationId)

            // Create AVAsset from streamed file
            await reportProgress(.creatingAsset, correlationId: correlationId)

            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)

            // Validate the asset
            try await validateAsset(asset, correlationId: correlationId)

            let result = VideoLoadingResult(
                asset: asset,
                photosIdentifier: item.itemIdentifier,
                cloudIdentifier: nil, // Will be populated by PhotosPersistenceService
                filename: sourceURL.lastPathComponent,
                temporaryFileURL: tempURL,
                sourceType: .directPicker,
                fileSize: totalBytes,
                duration: duration,
                correlationId: correlationId
            )

            operationTimings["streaming_transfer"] = Date().timeIntervalSince(streamingStart)

            logger.info("🎬 VIDEO_LOADING: 🏆 Streaming transfer completed [\(correlationId)]")
            return result

        } catch {
            logger.error("🎬 VIDEO_LOADING: ❌ Streaming transfer failed [\(correlationId)]: \(error)")
            throw VideoLoadingError.streamingFailed(error)
        }
    }

    /// Load via Photos library (PHAsset approach)
    private func loadViaPhotosLibrary(from item: PhotosPickerItem, correlationId: String) async throws -> VideoLoadingResult? {
        logger.info("🎬 VIDEO_LOADING: 📚 Attempting Photos library loading [\(correlationId)]")

        guard let itemIdentifier = item.itemIdentifier else {
            logger.warning("🎬 VIDEO_LOADING: ⚠️ No item identifier available [\(correlationId)]")
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            logger.warning("🎬 VIDEO_LOADING: ⚠️ PHAsset not found for identifier [\(correlationId)]: \(itemIdentifier)")
            return nil
        }

        return try await loadFromPHAsset(phAsset, correlationId: correlationId)
    }

    /// Load from PHAsset
    private func loadFromPHAsset(_ phAsset: PHAsset, correlationId: String) async throws -> VideoLoadingResult {
        logger.info("🎬 VIDEO_LOADING: 📚 Loading from PHAsset [\(correlationId)]: \(phAsset.localIdentifier)")

        let phAssetStart = Date()

        // Validate asset type
        guard phAsset.mediaType == .video else {
            throw VideoLoadingError.unsupportedFileType
        }

        // Request AVAsset from PHAsset
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let fileSize = await getPHAssetFileSize(phAsset)
        await reportProgress(.transferring, correlationId: correlationId)

        let asset = try await requestAVAsset(for: phAsset, options: options, correlationId: correlationId)

        // Get asset properties
        let duration = try await asset.load(.duration)
        let filename = await fetchFilename(for: phAsset, correlationId: correlationId)

        // Extract cloud identifier if available
        let cloudIdentifier = await extractCloudIdentifier(from: phAsset, correlationId: correlationId)

        await reportProgress(.validating, correlationId: correlationId)

        // Validate the asset
        try await validateAsset(asset, correlationId: correlationId)

        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: phAsset.localIdentifier,
            cloudIdentifier: cloudIdentifier,
            filename: filename,
            temporaryFileURL: nil, // No temporary file needed for PHAsset loading
            sourceType: phAsset.sourceType == .typeCloudShared ? .cloudAsset : .photosLibrary,
            fileSize: await getPHAssetFileSize(phAsset),
            duration: duration,
            correlationId: correlationId
        )

        operationTimings["phasset_loading"] = Date().timeIntervalSince(phAssetStart)

        logger.info("🎬 VIDEO_LOADING: 🏆 PHAsset loading completed [\(correlationId)]")
        return result
    }

    /// Load from URL
    private func loadFromURL(_ url: URL, correlationId: String) async throws -> VideoLoadingResult {
        logger.info("🎬 VIDEO_LOADING: 🌐 Loading from URL [\(correlationId)]: \(url.lastPathComponent)")

        let urlStart = Date()

        // Create streaming destination
        let tempURL = createTemporaryURL(filename: url.lastPathComponent)
        temporaryFiles.insert(tempURL)

        // Stream copy
        let fileSize = try await getFileSize(url)
        await reportProgress(.transferring, correlationId: correlationId)

        try await streamCopy(from: url, to: tempURL, correlationId: correlationId)

        // Create AVAsset
        await reportProgress(.creatingAsset, correlationId: correlationId)

        let asset = AVURLAsset(url: tempURL)
        let duration = try await asset.load(.duration)

        // Validate
        try await validateAsset(asset, correlationId: correlationId)

        // Get file size
        let urlFileSize = try await getFileSize(tempURL)

        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: nil,
            cloudIdentifier: nil,
            filename: url.lastPathComponent,
            temporaryFileURL: tempURL,
            sourceType: .fileURL,
            fileSize: urlFileSize,
            duration: duration,
            correlationId: correlationId
        )

        operationTimings["url_loading"] = Date().timeIntervalSince(urlStart)

        logger.info("🎬 VIDEO_LOADING: 🏆 URL loading completed [\(correlationId)]")
        return result
    }

    // MARK: - Helper Methods

    /// Stream copy from source to destination without loading into memory
    private func streamCopy(from sourceURL: URL, to destinationURL: URL, correlationId: String) async throws {
        logger.info("🎬 VIDEO_LOADING: 🔄 Streaming copy from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent) [\(correlationId)]")

        let copyStart = Date()

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            operationTimings["stream_copy"] = Date().timeIntervalSince(copyStart)

            logger.info("🎬 VIDEO_LOADING: ✅ Streaming copy completed [\(correlationId)]")

        } catch {
            logger.error("🎬 VIDEO_LOADING: ❌ Streaming copy failed [\(correlationId)]: \(error)")
            throw VideoLoadingError.streamingFailed(error)
        }
    }

    /// Request AVAsset from PHAsset
    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions, correlationId: String) async throws -> AVAsset {
        logger.info("🎬 VIDEO_LOADING: 📡 Requesting AVAsset from PHAsset [\(correlationId)]")

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    self.logger.error("🎬 VIDEO_LOADING: ❌ AVAsset request failed [\(correlationId)]: \(error)")
                    continuation.resume(throwing: VideoLoadingError.avAssetCreationFailed)
                    return
                }

                guard let asset = avAsset else {
                    self.logger.error("🎬 VIDEO_LOADING: ❌ No AVAsset returned [\(correlationId)]")
                    continuation.resume(throwing: VideoLoadingError.avAssetCreationFailed)
                    return
                }

                self.logger.info("🎬 VIDEO_LOADING: ✅ AVAsset received [\(correlationId)]")
                continuation.resume(returning: asset)
            }
        }
    }

    /// Validate AVAsset
    private func validateAsset(_ asset: AVAsset, correlationId: String) async throws {
        logger.info("🎬 VIDEO_LOADING: 🔍 Validating AVAsset [\(correlationId)]")

        let validationStart = Date()

        // Check duration
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw VideoLoadingError.validationFailed("Invalid video duration: \(duration.seconds)s")
        }

        // Check video tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoLoadingError.validationFailed("No video tracks found")
        }

        // Check if asset is playable
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoLoadingError.validationFailed("Asset is not playable")
        }

        operationTimings["validation"] = Date().timeIntervalSince(validationStart)

        logger.info("🎬 VIDEO_LOADING: ✅ Asset validation completed [\(correlationId)] - Duration: \(duration.seconds)s, Tracks: \(videoTracks.count)")
    }

    /// Fetch filename from PHAsset
    private func fetchFilename(for phAsset: PHAsset, correlationId: String) async -> String {
        logger.info("🎬 VIDEO_LOADING: 📋 Fetching filename [\(correlationId)]")

        let resources = PHAssetResource.assetResources(for: phAsset)

        if let videoResource = resources.first(where: { $0.type == .video }) {
            logger.info("🎬 VIDEO_LOADING: ✅ Found video resource filename [\(correlationId)]: \(videoResource.originalFilename)")
            return videoResource.originalFilename
        }

        // Fallback
        logger.warning("🎬 VIDEO_LOADING: ⚠️ Using fallback filename [\(correlationId)]")
        return "video-\(Date().timeIntervalSince1970).mov"
    }

    /// Extract cloud identifier from PHAsset
    private func extractCloudIdentifier(from phAsset: PHAsset, correlationId: String) async -> String? {
        logger.info("🎬 VIDEO_LOADING: ☁️ Extracting cloud identifier [\(correlationId)]")

        // For cloud assets, the cloud identifier can be derived from the asset
        if phAsset.sourceType == .typeCloudShared {
            // Use the localIdentifier as a base for cloud identifier
            // This will be enhanced by the PhotosPersistenceService
            let cloudId = "cloud-\(phAsset.localIdentifier)"
            logger.info("🎬 VIDEO_LOADING: ✅ Derived cloud identifier [\(correlationId)]: \(cloudId)")
            return cloudId
        }

        return nil
    }

    /// Get file size from URL
    private func getFileSize(_ url: URL) async throws -> Int64 {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resources.fileSize ?? 0)
    }

    /// Get PHAsset file size
    private func getPHAssetFileSize(_ phAsset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: phAsset)
        if let videoResource = resources.first(where: { $0.type == .video }) {
            return videoResource.value(forKey: "fileSize") as? Int64 ?? 0
        }
        return 0
    }

    /// Create temporary URL
    private func createTemporaryURL(filename: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension

        return tempDir
            .appendingPathComponent("\(baseName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension.isEmpty ? "mov" : fileExtension)
    }

    /// Get file size from PhotosPickerItem before transfer
    private func getFileSize(from item: PhotosPickerItem, correlationId: String) async throws -> Int64 {
        logger.info("🎬 VIDEO_LOADING: 📏 Getting file size from PhotosPickerItem [\(correlationId)]")

        do {
            // Try to get file size from URL transfer first
            if let url = try await item.loadTransferable(type: URL.self) {
                let fileSize = try await getFileSize(url)
                logger.info("🎬 VIDEO_LOADING: ✅ Got file size from URL transfer [\(correlationId)]: \(fileSize) bytes")
                return fileSize
            }

            // Fallback: try to get size from PHAsset
            guard let itemIdentifier = item.itemIdentifier else {
                logger.warning("🎬 VIDEO_LOADING: ⚠️ No item identifier, using default size [\(correlationId)]")
                return 50 * 1024 * 1024 // 50MB default
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
            guard let phAsset = fetchResult.firstObject else {
                logger.warning("🎬 VIDEO_LOADING: ⚠️ No PHAsset found, using default size [\(correlationId)]")
                return 50 * 1024 * 1024 // 50MB default
            }

            let assetSize = await getPHAssetFileSize(phAsset)
            logger.info("🎬 VIDEO_LOADING: ✅ Got file size from PHAsset [\(correlationId)]: \(assetSize) bytes")
            return assetSize > 0 ? assetSize : 50 * 1024 * 1024

        } catch {
            logger.warning("🎬 VIDEO_LOADING: ⚠️ Failed to get file size, using default [\(correlationId)]: \(error)")
            return 50 * 1024 * 1024 // 50MB default
        }
    }

    /// Generate correlation ID
    private func generateCorrelationId() -> String {
        return memoryLogger.generateCorrelationId(for: "VideoLoadingService")
    }

    /// Report progress
    private func reportProgress(_ phase: VideoLoadingProgress.LoadingPhase, correlationId: String) async {
        let progressReport = VideoLoadingProgress(
            phase: phase,
            correlationId: correlationId
        )

        progressSubject.send(progressReport)

        let progressPercentage = Int(progressReport.progress * 100)
        let phaseString = "\(phase)"
        logger.info("🎬 VIDEO_LOADING: 📊 Progress [\(correlationId)]: \(phaseString) - \(progressPercentage)% - \(progressReport.message)")
    }

    /// Log completion
    private func logCompletion(result: VideoLoadingResult, startTime: Date, method: String) {
        let duration = Date().timeIntervalSince(startTime)

        logger.info("🎬 VIDEO_LOADING: 🏆 COMPLETION [\(result.correlationId)]:")
        logger.info("🎬 VIDEO_LOADING:   - Method: \(method)")
        logger.info("🎬 VIDEO_LOADING:   - Duration: \(String(format: "%.2f", duration))s")
        logger.info("🎬 VIDEO_LOADING:   - Source: \(result.sourceType.description)")
        logger.info("🎬 VIDEO_LOADING:   - Filename: \(result.filename)")
        logger.info("🎬 VIDEO_LOADING:   - File size: \(result.fileSize ?? 0) bytes")
        logger.info("🎬 VIDEO_LOADING:   - Asset duration: \(result.duration.seconds)s")
        logger.info("🎬 VIDEO_LOADING:   - Has temp file: \(result.temporaryFileURL != nil)")
        logger.info("🎬 VIDEO_LOADING:   - Photos ID: \(result.photosIdentifier ?? "none")")
        logger.info("🎬 VIDEO_LOADING:   - Cloud ID: \(result.cloudIdentifier ?? "none")")

        // Log memory state
        memoryLogger.logMemoryState(
            context: "After Video Loading",
            correlationId: result.correlationId,
            component: "VideoLoadingService"
        )

        // 🎯 CRITICAL FIX: Send final completion progress signal
        let finalProgress = VideoLoadingProgress(
            phase: .validatingTrimmer,
            correlationId: result.correlationId
        )
        progressSubject.send(finalProgress)
        logger.info("🎬 VIDEO_LOADING: ✅ Final completion signal sent [\(result.correlationId)]")

        // Clean up correlation ID
        memoryLogger.clearCorrelationId(for: "VideoLoadingService")
        currentCorrelationId = nil
    }

    // MARK: - Deinitialization
    deinit {
        logger.info("🎬 VIDEO_LOADING: 🧹 Deinit - cleaning up resources")
        Task { [weak self] in
            await self?.cleanupTemporaryFiles()
        }
    }
}

// MARK: - Combine Integration
import Combine

extension ModernVideoLoadingService {
    /// Stream-based loading with Combine publishers
    func loadVideoWithProgress(from item: PhotosPickerItem) -> AnyPublisher<VideoLoadingResult, VideoLoadingError> {
        Future<VideoLoadingResult, VideoLoadingError> { promise in
            Task {
                do {
                    let result = try await self.loadVideo(from: item)
                    promise(.success(result))
                } catch {
                    if let loadingError = error as? VideoLoadingError {
                        promise(.failure(loadingError))
                    } else {
                        promise(.failure(.streamingFailed(error)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}