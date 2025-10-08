import AVFoundation  // MARK: - "time-based audiovisual media", play, create, edit QuickTime movies, MPEG-4 files, play HSL streams, essentially build powerful media functionality
import Combine  // MARK: - "process values over time" like
import CoreMedia  // MARK: - media pipeline used by AVFoundation, use CoreMedia's low-level data types and interfaces to efficiently process media samples + manage queues of media data
import Foundation  // MARK: - data storage, pesistence, text processing, day/time calculations, sorting, filtering and networking
import OSLog  // MARK: - read logs, custom debug
import Photos  // MARK: - image/video assets
import PhotosUI  // MARK: - photo picker
import SwiftUI  // MARK: - UI framework
import UniformTypeIdentifiers  // MARK: - "describe file type"

// VideoLoadingService.swift

// MARK: - Video Loading Error
public enum VideoLoadingError: Error, LocalizedError {
    case itemIdentifierMissing
    case assetNotFound
    case avAssetCreationFailed
    case unsupportedFileType
    case dataUnavailable
    case temporaryFileError(Error)
    case transferableNotSupported
    case streamingFailed(Error)
    case dataTransferFailed(String)
    case validationFailed(String)

    // MARK: - Video Loading Error Description
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
            return
                "Failed to save video data to a temporary file: \(underlyingError.localizedDescription)"
        case .transferableNotSupported:
            return "Transferable type not supported by the PhotosPicker item."
        case .streamingFailed(let underlyingError):
            return
                "Streaming file copy failed: \(underlyingError.localizedDescription)"
        case .dataTransferFailed(let reason):
            return "Data transfer failed: \(reason)"
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

// MARK: - Video Loading source type
public enum VideoSourceType {
    case photosLibrary
    case directPicker
    case fileURL
    case cloudAsset
    // MARK: text description
    var description: String {
        switch self {
        case .photosLibrary: return "Photos Library"
        case .directPicker: return "Direct Picker"
        case .fileURL: return "File URL"
        case .cloudAsset: return "Cloud Asset"
        }
    }
}

// MARK: - STRUCT
struct PhotoFileRepresentation {
    let size: Int64
    let sourceURL: URL
}

// MARK: - keyword
@preconcurrency
public protocol ModernVideoLoadingServiceProtocol: AnyObject {  // protocol
    // MARK: - FUNC
    func loadVideo(from item: PhotosPickerItem) async throws
        -> VideoLoadingResult
    func loadVideo(from url: URL) async throws -> VideoLoadingResult
    func loadVideo(from phAsset: PHAsset) async throws -> VideoLoadingResult
    func cleanupTemporaryFiles() async
    func cancelCurrentOperation()
    var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> { get }
}

// MARK: - keyword
@MainActor
@preconcurrency
public final class ModernVideoLoadingService: ModernVideoLoadingServiceProtocol
{  // service
    private let imageManager = PHImageManager.default()

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "🎬 VideoLoadingService"
    )

    private let memoryLogger = CentralizedMemoryLogger.shared

    // MARK: - what's this
    private let progressSubject = PassthroughSubject<
        VideoLoadingProgress, Never
    >()

    // MARK: - PUBLISHER
    public var progressPublisher: AnyPublisher<VideoLoadingProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    // MARK: - VAR
    private var operationTimings: [String: TimeInterval] = [:]
    private var currentCorrelationId: String?
    private var temporaryFiles: Set<URL> = []

    // MARK: - INIT
    public init() {
        logger.info(
            "🎬 VIDEO_LOADING: 🚀 Initialized - streaming-based video loading service"
        )
    }

    // MARK: - FUNC
    public func loadVideo(from item: PhotosPickerItem) async throws
        -> VideoLoadingResult
    {
        // MARK: - SETTER
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        // MARK: AWAIT
        logger.info(
            "🎬 VIDEO_LOADING: 🚀 Loading from PhotosPicker [\(correlationId)]"
        )
        await reportProgress(.initializing, correlationId: correlationId)

        // MARK: START TIME
        let startTime = Date()

        // MARK: ACTION
        do {
            logger.info(
                "🎬 VIDEO_LOADING: 📊 Fetching file metadata [\(correlationId)]"
            )

            // MARK: - TOTAL BYTES
            let totalBytes = try await getFileSize(
                from: item,
                correlationId: correlationId
            )

            // MARK: - PROGRESS
            await reportProgress(.transferring, correlationId: correlationId)

            // MARK: - if urlResult
            if let urlResult = try await loadViaStreaming(
                from: item,
                totalBytes: totalBytes,
                correlationId: correlationId
            ) {
                await reportProgress(
                    .creatingAsset,
                    correlationId: correlationId
                )
                logCompletion(
                    result: urlResult,
                    startTime: startTime,
                    method: "streaming"
                )
                return urlResult
            }

            // MARK: - PROGRESS
            await reportProgress(.transferring, correlationId: correlationId)

            // MARK: - if assetResult
            if let assetResult = try await loadViaPhotosLibrary(
                from: item,
                correlationId: correlationId
            ) {
                await reportProgress(
                    .creatingAsset,
                    correlationId: correlationId
                )
                logCompletion(
                    result: assetResult,
                    startTime: startTime,
                    method: "photos_library"
                )
                return assetResult
            }
            // MARK: - ERROR
            throw VideoLoadingError.transferableNotSupported
        } catch {
            // MARK: - ERROR
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error(
                "🎬 VIDEO_LOADING: ❌ Loading failed [\(correlationId)]: \(error)"
            )
            throw error
        }
    }

    // MARK: - FUNC
    public func loadVideo(from url: URL) async throws -> VideoLoadingResult {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info(
            "🎬 VIDEO_LOADING: 🚀 Loading from URL [\(correlationId)]: \(url.lastPathComponent)"
        )
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        do {
            let fileSize = try await getFileSize(url)  // FILE SIZE
            await reportProgress(.transferring, correlationId: correlationId)

            let result = try await loadFromURL(  // RESULT
                url,
                correlationId: correlationId
            )

            // MARK: - PROGRESS
            await reportProgress(.creatingAsset, correlationId: correlationId)
            logCompletion(
                result: result,
                startTime: startTime,
                method: "url_streaming"
            )

            return result

        } catch {
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error(
                "🎬 VIDEO_LOADING: ❌ URL loading failed [\(correlationId)]: \(error)"
            )
            throw error
        }
    }

    // MARK: - FUNC
    public func loadVideo(from phAsset: PHAsset) async throws
        -> VideoLoadingResult
    {
        let correlationId = generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info(
            "🎬 VIDEO_LOADING: 🚀 Loading from PHAsset [\(correlationId)]: \(phAsset.localIdentifier)"
        )
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        // MARK: - ACTION
        do {
            let fileSize = await getPHAssetFileSize(phAsset)
            await reportProgress(.transferring, correlationId: correlationId)

            let result = try await loadFromPHAsset(
                phAsset,
                correlationId: correlationId
            )

            // MARK: - waiting
            await reportProgress(.creatingAsset, correlationId: correlationId)
            logCompletion(
                result: result,
                startTime: startTime,
                method: "phasset"
            )

            return result

        } catch {
            await reportProgress(.initializing, correlationId: correlationId)
            logger.error(
                "🎬 VIDEO_LOADING: ❌ PHAsset loading failed [\(correlationId)]: \(error)"
            )
            throw error
        }
    }

    // MARK: - FUNC
    public func cleanupTemporaryFiles() async {
        logger.info(
            "🎬 VIDEO_LOADING: 🧹 Cleaning up \(self.temporaryFiles.count) temporary files"
        )

        // MARK: - CONTROL FLOW
        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                logger.info(
                    "🎬 VIDEO_LOADING: ✅ Removed temporary file: \(url.lastPathComponent)"
                )
            } catch {
                logger.warning(
                    "🎬 VIDEO_LOADING: ⚠️ Failed to remove temporary file: \(url.lastPathComponent) - \(error)"
                )
            }
        }

        temporaryFiles.removeAll()
    }

    // MARK: - FUNC
    private func loadViaStreaming(
        from item: PhotosPickerItem,
        totalBytes: Int64,
        correlationId: String
    ) async throws -> VideoLoadingResult? {
        logger.info(
            "🎬 VIDEO_LOADING: 🔄 Attempting streaming URL transfer [\(correlationId)]"
        )

        let streamingStart = Date()

        do {
            guard
                let sourceURL = try await item.loadTransferable(type: URL.self)
            else {
                logger.info(
                    "🎬 VIDEO_LOADING: ℹ️ URL transfer not supported, will try other methods [\(correlationId)]"
                )
                return nil
            }

            logger.info(
                "🎬 VIDEO_LOADING: ✅ URL transfer successful [\(correlationId)]: \(sourceURL.lastPathComponent)"
            )

            // MARK: - TEMP URL
            let tempURL = createTemporaryURL(
                filename: sourceURL.lastPathComponent
            )
            temporaryFiles.insert(tempURL)

            // MARK: - PROGRESS
            await reportProgress(.transferring, correlationId: correlationId)

            // MARK: - WAIT
            try await streamCopy(
                from: sourceURL,
                to: tempURL,
                correlationId: correlationId
            )

            await reportProgress(.creatingAsset, correlationId: correlationId)

            // MARK: - ASSET
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)

            try await validateAsset(asset, correlationId: correlationId)

            // MARK: - RESULT
            let result = VideoLoadingResult(
                asset: asset,
                photosIdentifier: item.itemIdentifier,
                cloudIdentifier: nil,
                filename: sourceURL.lastPathComponent,
                temporaryFileURL: tempURL,
                sourceType: .directPicker,
                fileSize: totalBytes,
                duration: duration,
                correlationId: correlationId
            )

            operationTimings["streaming_transfer"] = Date().timeIntervalSince(
                streamingStart
            )

            logger.info(
                "🎬 VIDEO_LOADING: 🏆 Streaming transfer completed [\(correlationId)]"
            )
            return result

        } catch {
            logger.error(
                "🎬 VIDEO_LOADING: ❌ Streaming transfer failed [\(correlationId)]: \(error)"
            )
            throw VideoLoadingError.streamingFailed(error)
        }
    }

    // MARK: - FUNC
    private func loadViaPhotosLibrary(
        from item: PhotosPickerItem,
        correlationId: String
    ) async throws -> VideoLoadingResult? {
        logger.info(
            "🎬 VIDEO_LOADING: 📚 Attempting Photos library loading [\(correlationId)]"
        )

        guard let itemIdentifier = item.itemIdentifier else {
            logger.warning(
                "🎬 VIDEO_LOADING: ⚠️ No item identifier available [\(correlationId)]"
            )
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [itemIdentifier],
            options: nil
        )
        guard let phAsset = fetchResult.firstObject else {
            logger.warning(
                "🎬 VIDEO_LOADING: ⚠️ PHAsset not found for identifier [\(correlationId)]: \(itemIdentifier)"
            )
            return nil
        }

        return try await loadFromPHAsset(phAsset, correlationId: correlationId)
    }

    // MARK: - FUNC
    private func loadFromPHAsset(_ phAsset: PHAsset, correlationId: String)
        async throws -> VideoLoadingResult
    {
        logger.info(
            "🎬 VIDEO_LOADING: 📚 Loading from PHAsset [\(correlationId)]: \(phAsset.localIdentifier)"
        )

        let phAssetStart = Date()

        guard phAsset.mediaType == .video else {
            throw VideoLoadingError.unsupportedFileType
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let fileSize = await getPHAssetFileSize(phAsset)
        await reportProgress(.transferring, correlationId: correlationId)

        let asset = try await requestAVAsset(
            for: phAsset,
            options: options,
            correlationId: correlationId
        )

        let duration = try await asset.load(.duration)
        let filename = await fetchFilename(
            for: phAsset,
            correlationId: correlationId
        )

        let cloudIdentifier = await extractCloudIdentifier(
            from: phAsset,
            correlationId: correlationId
        )

        await reportProgress(.validating, correlationId: correlationId)

        try await validateAsset(asset, correlationId: correlationId)

        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: phAsset.localIdentifier,
            cloudIdentifier: cloudIdentifier,
            filename: filename,
            temporaryFileURL: nil,
            sourceType: phAsset.sourceType == .typeCloudShared
                ? .cloudAsset : .photosLibrary,
            fileSize: await getPHAssetFileSize(phAsset),
            duration: duration,
            correlationId: correlationId
        )

        operationTimings["phasset_loading"] = Date().timeIntervalSince(
            phAssetStart
        )

        logger.info(
            "🎬 VIDEO_LOADING: 🏆 PHAsset loading completed [\(correlationId)]"
        )
        return result
    }

    // MARK: - FUNC
    private func loadFromURL(_ url: URL, correlationId: String) async throws
        -> VideoLoadingResult
    {
        logger.info(
            "🎬 VIDEO_LOADING: 🌐 Loading from URL [\(correlationId)]: \(url.lastPathComponent)"
        )

        let urlStart = Date()

        let tempURL = createTemporaryURL(filename: url.lastPathComponent)
        temporaryFiles.insert(tempURL)

        let fileSize = try await getFileSize(url)
        await reportProgress(.transferring, correlationId: correlationId)

        try await streamCopy(
            from: url,
            to: tempURL,
            correlationId: correlationId
        )

        await reportProgress(.creatingAsset, correlationId: correlationId)

        let asset = AVURLAsset(url: tempURL)
        let duration = try await asset.load(.duration)

        try await validateAsset(asset, correlationId: correlationId)

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

        logger.info(
            "🎬 VIDEO_LOADING: 🏆 URL loading completed [\(correlationId)]"
        )
        return result
    }

    // MARK: - FUNC
    private func streamCopy(
        from sourceURL: URL,
        to destinationURL: URL,
        correlationId: String
    ) async throws {
        logger.info(
            "🎬 VIDEO_LOADING: 🔄 Streaming copy from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent) [\(correlationId)]"
        )

        let copyStart = Date()

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            operationTimings["stream_copy"] = Date().timeIntervalSince(
                copyStart
            )

            logger.info(
                "🎬 VIDEO_LOADING: ✅ Streaming copy completed [\(correlationId)]"
            )

        } catch {
            logger.error(
                "🎬 VIDEO_LOADING: ❌ Streaming copy failed [\(correlationId)]: \(error)"
            )
            throw VideoLoadingError.streamingFailed(error)
        }
    }

    // MARK: - FUNC
    private func requestAVAsset(
        for phAsset: PHAsset,
        options: PHVideoRequestOptions,
        correlationId: String
    ) async throws -> AVAsset {
        logger.info(
            "🎬 VIDEO_LOADING: 📡 Requesting AVAsset from PHAsset [\(correlationId)]"
        )

        options.progressHandler = { progress, _, _, _ in
            Task { @MainActor in
                let downloadProgress = VideoLoadingProgress(
                    phase: .downloadingFromCloud(progress: progress),
                    correlationId: correlationId
                )
                self.progressSubject.send(downloadProgress)

                let progressPercentage = Int(progress * 100)
                self.logger.info(
                    "🎬 VIDEO_LOADING: ☁️ iCloud download progress [\(correlationId)]: \(progressPercentage)%"
                )
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) {
                avAsset,
                _,
                info in
                if let error = info?[PHImageErrorKey] as? Error {
                    self.logger.error(
                        "🎬 VIDEO_LOADING: ❌ AVAsset request failed [\(correlationId)]: \(error)"
                    )
                    continuation.resume(
                        throwing: VideoLoadingError.avAssetCreationFailed
                    )
                    return
                }

                guard let asset = avAsset else {
                    self.logger.error(
                        "🎬 VIDEO_LOADING: ❌ No AVAsset returned [\(correlationId)]"
                    )
                    continuation.resume(
                        throwing: VideoLoadingError.avAssetCreationFailed
                    )
                    return
                }

                self.logger.info(
                    "🎬 VIDEO_LOADING: ✅ AVAsset received [\(correlationId)]"
                )
                continuation.resume(returning: asset)
            }
        }
    }

    // MARK: - FUNC
    private func validateAsset(_ asset: AVAsset, correlationId: String)
        async throws
    {
        logger.info("🎬 VIDEO_LOADING: 🔍 Validating AVAsset [\(correlationId)]")

        let validationStart = Date()

        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw VideoLoadingError.validationFailed(
                "Invalid video duration: \(duration.seconds)s"
            )
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoLoadingError.validationFailed("No video tracks found")
        }

        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoLoadingError.validationFailed("Asset is not playable")
        }

        operationTimings["validation"] = Date().timeIntervalSince(
            validationStart
        )

        logger.info(
            "🎬 VIDEO_LOADING: ✅ Asset validation completed [\(correlationId)] - Duration: \(duration.seconds)s, Tracks: \(videoTracks.count)"
        )
    }

    // MARK: - FUNC
    private func fetchFilename(for phAsset: PHAsset, correlationId: String)
        async -> String
    {
        logger.info("🎬 VIDEO_LOADING: 📋 Fetching filename [\(correlationId)]")

        let resources = PHAssetResource.assetResources(for: phAsset)

        if let videoResource = resources.first(where: { $0.type == .video }) {
            logger.info(
                "🎬 VIDEO_LOADING: ✅ Found video resource filename [\(correlationId)]: \(videoResource.originalFilename)"
            )
            return videoResource.originalFilename
        }

        logger.warning(
            "🎬 VIDEO_LOADING: ⚠️ Using fallback filename [\(correlationId)]"
        )
        return "video-\(Date().timeIntervalSince1970).mov"
    }

    // MARK: - FUNC
    private func extractCloudIdentifier(
        from phAsset: PHAsset,
        correlationId: String
    ) async -> String? {
        logger.info(
            "🎬 VIDEO_LOADING: ☁️ Extracting cloud identifier [\(correlationId)]"
        )

        if phAsset.sourceType == .typeCloudShared {

            let cloudId = "cloud-\(phAsset.localIdentifier)"
            logger.info(
                "🎬 VIDEO_LOADING: ✅ Derived cloud identifier [\(correlationId)]: \(cloudId)"
            )
            return cloudId
        }

        return nil
    }

    // MARK: - FUNC
    private func getFileSize(_ url: URL) async throws -> Int64 {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resources.fileSize ?? 0)
    }

    // MARK: - FUNC
    private func getPHAssetFileSize(_ phAsset: PHAsset) async -> Int64 {
        let resources = PHAssetResource.assetResources(for: phAsset)
        if let videoResource = resources.first(where: { $0.type == .video }) {
            return videoResource.value(forKey: "fileSize") as? Int64 ?? 0
        }
        return 0
    }

    // MARK: - FUNC
    private func createTemporaryURL(filename: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension()
            .lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension

        return
            tempDir
            .appendingPathComponent("\(baseName)-\(UUID().uuidString)")
            .appendingPathExtension(
                fileExtension.isEmpty ? "mov" : fileExtension
            )
    }

    // MARK: - FUNC
    private func getFileSize(from item: PhotosPickerItem, correlationId: String)
        async throws -> Int64
    {
        logger.info(
            "🎬 VIDEO_LOADING: 📏 Getting file size from PhotosPickerItem [\(correlationId)]"
        )

        do {

            if let url = try await item.loadTransferable(type: URL.self) {
                let fileSize = try await getFileSize(url)
                logger.info(
                    "🎬 VIDEO_LOADING: ✅ Got file size from URL transfer [\(correlationId)]: \(fileSize) bytes"
                )
                return fileSize
            }

            guard let itemIdentifier = item.itemIdentifier else {
                logger.warning(
                    "🎬 VIDEO_LOADING: ⚠️ No item identifier, using default size [\(correlationId)]"
                )
                return 50 * 1024 * 1024
            }

            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: [itemIdentifier],
                options: nil
            )
            guard let phAsset = fetchResult.firstObject else {
                logger.warning(
                    "🎬 VIDEO_LOADING: ⚠️ No PHAsset found, using default size [\(correlationId)]"
                )
                return 50 * 1024 * 1024
            }

            let assetSize = await getPHAssetFileSize(phAsset)
            logger.info(
                "🎬 VIDEO_LOADING: ✅ Got file size from PHAsset [\(correlationId)]: \(assetSize) bytes"
            )
            return assetSize > 0 ? assetSize : 50 * 1024 * 1024

        } catch {
            logger.warning(
                "🎬 VIDEO_LOADING: ⚠️ Failed to get file size, using default [\(correlationId)]: \(error)"
            )
            return 50 * 1024 * 1024
        }
    }

    // MARK: - FUNC
    private func generateCorrelationId() -> String {
        return memoryLogger.generateCorrelationId(for: "VideoLoadingService")
    }

    // MARK: - FUNC
    private func reportProgress(
        _ phase: VideoLoadingProgress.LoadingPhase,
        correlationId: String
    ) async {
        let progressReport = VideoLoadingProgress(
            phase: phase,
            correlationId: correlationId
        )

        progressSubject.send(progressReport)

        let progressPercentage = Int(progressReport.progress * 100)
        let phaseString = "\(phase)"
        logger.info(
            "🎬 VIDEO_LOADING: 📊 Progress [\(correlationId)]: \(phaseString) - \(progressPercentage)% - \(progressReport.message)"
        )
    }

    // MARK: - FUNC
    private func logCompletion(
        result: VideoLoadingResult,
        startTime: Date,
        method: String
    ) {
        let duration = Date().timeIntervalSince(startTime)

        logger.info("🎬 VIDEO_LOADING: 🏆 COMPLETION [\(result.correlationId)]:")
        logger.info("🎬 VIDEO_LOADING:   - Method: \(method)")
        logger.info(
            "🎬 VIDEO_LOADING:   - Duration: \(String(format: "%.2f", duration))s"
        )
        logger.info(
            "🎬 VIDEO_LOADING:   - Source: \(result.sourceType.description)"
        )
        logger.info("🎬 VIDEO_LOADING:   - Filename: \(result.filename)")
        logger.info(
            "🎬 VIDEO_LOADING:   - File size: \(result.fileSize ?? 0) bytes"
        )
        logger.info(
            "🎬 VIDEO_LOADING:   - Asset duration: \(result.duration.seconds)s"
        )
        logger.info(
            "🎬 VIDEO_LOADING:   - Has temp file: \(result.temporaryFileURL != nil)"
        )
        logger.info(
            "🎬 VIDEO_LOADING:   - Photos ID: \(result.photosIdentifier ?? "none")"
        )
        logger.info(
            "🎬 VIDEO_LOADING:   - Cloud ID: \(result.cloudIdentifier ?? "none")"
        )

        memoryLogger.logMemoryState(
            context: "After Video Loading",
            correlationId: result.correlationId,
            component: "VideoLoadingService"
        )

        let finalProgress = VideoLoadingProgress(
            phase: .validatingTrimmer,
            correlationId: result.correlationId
        )
        progressSubject.send(finalProgress)
        logger.info(
            "🎬 VIDEO_LOADING: ✅ Final completion signal sent [\(result.correlationId)]"
        )

        memoryLogger.clearCorrelationId(for: "VideoLoadingService")
        currentCorrelationId = nil
    }

    // MARK: - FUNC
    public func cancelCurrentOperation() {
        logger.info("🎬 VIDEO_LOADING: 🚫 Cancelling current operation")
        currentCorrelationId = nil

    }

    deinit {
        logger.info("🎬 VIDEO_LOADING: 🧹 Deinit - cleaning up resources")
        Task { [weak self] in
            await self?.cleanupTemporaryFiles()
        }
    }
}

// MARK: - EXTEONSION
extension ModernVideoLoadingService {
    // MARK: - FUNC
    func loadVideoWithProgress(from item: PhotosPickerItem) -> AnyPublisher<
        VideoLoadingResult, VideoLoadingError
    > {
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
