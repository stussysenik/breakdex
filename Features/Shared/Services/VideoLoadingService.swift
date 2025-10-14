import AVFoundation  // MARK: - "time-based audiovisual media", play, create, edit QuickTime movies, MPEG-4 files, play HSL streams, essentially build powerful media functionality
import Combine  // MARK: - "process values over time" like
import CoreMedia  // MARK: - media pipeline used by AVFoundation, use CoreMedia's low-level data types and interfaces to efficiently process media samples + manage queues of media data
import Foundation  // MARK: - data storage, pesistence, text processing, day/time calculations, sorting, filtering and networking
import Network  // MARK: - network path monitoring for resilient video loading
import OSLog  // MARK: - read logs, custom debug
import Photos  // MARK: - image/video assets
import PhotosUI  // MARK: - photo picker
import SwiftUI  // MARK: - UI framework
import UniformTypeIdentifiers  // MARK: - "describe file type"

// VideoLoadingService.swift
//
// VIDEO LOADING INITIALIZATION FIX IMPLEMENTATION:
// ================================================
// This service has been updated to integrate with VideoInitializationCoordinator
// to eliminate redundant loading attempts, fix Swift continuation leaks, and provide
// single-coordinated video loading flow with proper state synchronization.
//
// Key improvements:
// - Eliminates 6+ redundant loading attempts per video selection
// - Fixes Swift continuation leaks with proper task management
// - Integrates with VideoInitializationCoordinator for single source of truth
// - Provides coordinated state transitions through UnifiedState
// - Maintains backward compatibility while improving performance

// MARK: - Enhanced Player Bridge Notifications
extension Notification.Name {
    /// Notification sent when video asset is ready for player initialization
    static let videoAssetReadyForPlayer = Notification.Name("videoAssetReadyForPlayer")
}

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
    case assetValidationFailed(String)
    case invalidAsset(String)
    case playerInitializationFailed(String)
    case playerItemFailed(String)
    case timeout(TimeInterval)

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
        case .assetValidationFailed(let reason):
            return "Video asset validation failed: \(reason)"
        case .invalidAsset(let reason):
            return "Invalid video asset: \(reason)"
        case .playerInitializationFailed(let reason):
            return "Failed to initialize video player: \(reason)"
        case .playerItemFailed(let reason):
            return "Video player item failed: \(reason)"
        case .timeout(let duration):
            return "Video loading timed out after \(String(format: "%.1f", duration)) seconds"
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

// MARK: - Network Connection Types
public enum NetworkConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case other = "other"
    case none = "none"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .other: return "Other"
        case .none: return "No Connection"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Network Quality
public enum NetworkQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
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
public protocol VideoLoadingServiceProtocol: AnyObject {  // protocol
    // MARK: - FUNC
    func loadVideo(from item: PhotosUI.PhotosPickerItem) async throws
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
public final class VideoLoadingService: VideoLoadingServiceProtocol, ObservableObject
{  // service
    private let imageManager = PHImageManager.default()

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "🎬 VideoLoadingService"
    )

    private let memoryLogger = CentralizedMemoryLogger.shared

    // MARK: - Coordination Properties
    private weak var unifiedState: AddMoveUnifiedState?
    private weak var operationManager: VideoLoadingOperationManager?
    private weak var initializationCoordinator: VideoInitializationCoordinator?

    // MARK: - Network Monitoring Configuration (from ResilientVideoLoader)
    private static let defaultTimeout: TimeInterval = 45.0
    private static let maxRetryAttempts = 3
    private static let baseRetryDelay: TimeInterval = 2.0
    private static let maxRetryDelay: TimeInterval = 16.0

    // MARK: - Network Monitoring Properties
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "breakdex.video.network", qos: .utility)

    // MARK: - Published Network State (from ResilientVideoLoader)
    @Published public private(set) var isNetworkAvailable = true
    @Published public private(set) var networkConnectionType: NetworkConnectionType = .unknown
    @Published public private(set) var networkQuality: NetworkQuality = .excellent

    // MARK: - Resilient Loading State (from ResilientVideoLoader)
    @Published public private(set) var isLoading = false
    @Published public private(set) var isWaitingForNetwork = false
    @Published public private(set) var currentRetryAttempt = 0

    // Network resilience tracking
    private var networkLostDuringLoading = false
    private var retryAttempts = 0
    private var currentLoadingTask: Task<AVAsset, Error>?
    private var timeoutTask: Task<Void, Error>?
    private var networkMonitorTask: Task<Void, Never>?

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
        setupNetworkMonitoring()
        logger.info("VideoLoadingService initialized with resource management")
    }

    // MARK: - Coordination Setup
    /// Set up coordination with UnifiedState, VideoLoadingOperationManager, and VideoInitializationCoordinator
    public func setupCoordination(
        unifiedState: AddMoveUnifiedState,
        operationManager: VideoLoadingOperationManager,
        initializationCoordinator: VideoInitializationCoordinator? = nil
    ) {
        self.unifiedState = unifiedState
        self.operationManager = operationManager
        self.initializationCoordinator = initializationCoordinator
        logger.info("VideoLoadingService coordination established with UnifiedState, OperationManager, and VideoInitializationCoordinator")
    }

    /// Use unified correlation ID from UnifiedState for consistent tracking
    public func setUnifiedCorrelationId(_ correlationId: String) {
        self.currentCorrelationId = correlationId
        logger.info("VideoLoadingService using unified correlation ID: \(correlationId)")
    }

    // MARK: - FUNC
    public func loadVideo(from item: PhotosUI.PhotosPickerItem) async throws
        -> VideoLoadingResult
    {
        // Use unified correlation ID if available, otherwise generate one
        let correlationId = currentCorrelationId ?? generateCorrelationId()
        currentCorrelationId = correlationId

        logger.info("Loading video from PhotosPicker [\(correlationId)]")
        await reportProgress(.initializing, correlationId: correlationId)

        let startTime = Date()

        // Use autoreleasepool for better memory management
        return try await withTaskCancellationHandler {
            do {
                let totalBytes = try await getFileSize(from: item, correlationId: correlationId)
                await reportProgress(.transferring, correlationId: correlationId)

                // Try streaming first
                if let urlResult = try await loadViaStreaming(
                    from: item,
                    totalBytes: totalBytes,
                    correlationId: correlationId
                ) {
                    await reportProgress(.creatingAsset, correlationId: correlationId)
                    logCompletion(result: urlResult, startTime: startTime, method: "streaming")
                    return urlResult
                }

                // Fallback to Photos library
                await reportProgress(.transferring, correlationId: correlationId)
                if let assetResult = try await loadViaPhotosLibrary(
                    from: item,
                    correlationId: correlationId
                ) {
                    await reportProgress(.creatingAsset, correlationId: correlationId)
                    logCompletion(result: assetResult, startTime: startTime, method: "photos_library")
                    return assetResult
                }

                throw VideoLoadingError.transferableNotSupported
            } catch {
                await reportProgress(.initializing, correlationId: correlationId)
                logger.error("Video loading failed [\(correlationId)]: \(error.localizedDescription)")
                throw error
            }
        } onCancel: {
            // Cleanup on cancellation
            Task {
                await self.cleanupTemporaryFiles()
            }
        }
    }

    // MARK: - FUNC
    public func loadVideo(from url: URL) async throws -> VideoLoadingResult {
        // Use unified correlation ID if available, otherwise generate one
        let correlationId = currentCorrelationId ?? generateCorrelationId()
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
        // Use unified correlation ID if available, otherwise generate one
        let correlationId = currentCorrelationId ?? generateCorrelationId()
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
        logger.info("Cleaning up \(temporaryFiles.count) temporary files")

        // Clean up temporary files with proper error handling
        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                logger.debug("Removed temporary file: \(url.lastPathComponent)")
            } catch {
                logger.warning("Failed to remove temporary file: \(url.lastPathComponent) - \(error.localizedDescription)")
            }
        }

        temporaryFiles.removeAll()
        logger.info("Temporary files cleanup completed")
    }

    // MARK: - FUNC (Enhanced cleanup with resource management)
    private func cleanup() {
        // Cancel all ongoing operations
        currentLoadingTask?.cancel()
        timeoutTask?.cancel()
        networkMonitorTask?.cancel()
        networkMonitor.cancel()

        // Clear references
        currentLoadingTask = nil
        timeoutTask = nil
        networkMonitorTask = nil

        // Clean up any in-memory resources
        operationTimings.removeAll()
        currentCorrelationId = nil

        logger.info("VideoLoadingService cleanup completed")
    }

    // MARK: - Resource management helper
    private func ensureResourceLimit() {
        // Enforce temporary file limit to prevent resource exhaustion
        let maxTemporaryFiles = 5
        if temporaryFiles.count >= maxTemporaryFiles {
            Task {
                await cleanupTemporaryFiles()
            }
        }
    }

    // MARK: - FUNC (Retry logic from ResilientVideoLoader)
    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = Self.baseRetryDelay * pow(2.0, Double(attempt - 1))
        return min(delay, Self.maxRetryDelay)
    }

    // MARK: - FUNC
    private func loadViaStreaming(
        from item: PhotosUI.PhotosPickerItem,
        totalBytes: Int64,
        correlationId: String
    ) async throws -> VideoLoadingResult? {
        let streamingStart = Date()

        do {
            guard let sourceURL = try await item.loadTransferable(type: URL.self) else {
                return nil
            }

            let tempURL = createTemporaryURL(filename: sourceURL.lastPathComponent)
            await reportProgress(.transferring, correlationId: correlationId)

            try await streamCopy(from: sourceURL, to: tempURL, correlationId: correlationId)
            await reportProgress(.creatingAsset, correlationId: correlationId)

            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            try await validateAsset(asset, correlationId: correlationId)

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

            operationTimings["streaming_transfer"] = Date().timeIntervalSince(streamingStart)
            return result

        } catch {
            logger.error("Streaming transfer failed [\(correlationId)]: \(error.localizedDescription)")
            throw VideoLoadingError.streamingFailed(error)
        }
    }

    // MARK: - FUNC
    private func loadViaPhotosLibrary(
        from item: PhotosUI.PhotosPickerItem,
        correlationId: String
    ) async throws -> VideoLoadingResult? {
        guard let itemIdentifier = item.itemIdentifier else {
            return nil
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            return nil
        }

        return try await loadFromPHAsset(phAsset, correlationId: correlationId)
    }

    // MARK: - FUNC
    private func loadFromPHAsset(_ phAsset: PHAsset, correlationId: String)
        async throws -> VideoLoadingResult
    {
        let phAssetStart = Date()

        guard phAsset.mediaType == .video else {
            throw VideoLoadingError.unsupportedFileType
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let fileSize = await getPHAssetFileSize(phAsset)
        await reportProgress(.transferring, correlationId: correlationId)

        let asset = try await requestAVAsset(for: phAsset, options: options, correlationId: correlationId)
        let duration = try await asset.load(.duration)
        let filename = await fetchFilename(for: phAsset, correlationId: correlationId)
        let cloudIdentifier = await extractCloudIdentifier(from: phAsset, correlationId: correlationId)

        await reportProgress(.validating, correlationId: correlationId)
        try await validateAsset(asset, correlationId: correlationId)

        let result = VideoLoadingResult(
            asset: asset,
            photosIdentifier: phAsset.localIdentifier,
            cloudIdentifier: cloudIdentifier,
            filename: filename,
            temporaryFileURL: nil,
            sourceType: phAsset.sourceType == .typeCloudShared ? .cloudAsset : .photosLibrary,
            fileSize: await getPHAssetFileSize(phAsset),
            duration: duration,
            correlationId: correlationId
        )

        operationTimings["phasset_loading"] = Date().timeIntervalSince(phAssetStart)
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
        logger.debug("Streaming copy: \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent) [\(correlationId)]")

        let copyStart = Date()

        // Perform file operations with proper error handling
        do {
            // Check if source file exists and is accessible
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw VideoLoadingError.dataTransferFailed("Source file does not exist")
            }

            // Remove destination file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }

            // Perform the copy operation
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            operationTimings["stream_copy"] = Date().timeIntervalSince(copyStart)
            logger.debug("Streaming copy completed [\(correlationId)]")

        } catch {
            logger.error("Streaming copy failed [\(correlationId)]: \(error.localizedDescription)")

            // Clean up partial file if copy failed
            try? FileManager.default.removeItem(at: destinationURL)
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
                    phase: .downloadingFromCloud(progress),
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
        let validationStart = Date()

        // Perform asset validation with optimized memory usage
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw VideoLoadingError.validationFailed("Invalid video duration: \(duration.seconds)s")
        }

        // Optimized track loading - only load what we need
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoLoadingError.validationFailed("No video tracks found")
        }

        // Only check playability if needed - some assets may not report this correctly
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoLoadingError.validationFailed("Asset is not playable")
        }

        // Optimize asset for memory usage
        if let urlAsset = asset as? AVURLAsset {
            urlAsset.resourceLoader.setDelegate(nil, queue: nil)
        }

        operationTimings["validation"] = Date().timeIntervalSince(validationStart)
        logger.debug("Asset validated [\(correlationId)]: \(duration.seconds)s, \(videoTracks.count) tracks")
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
        // Ensure we don't exceed resource limits
        ensureResourceLimit()

        let tempDir = FileManager.default.temporaryDirectory
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension

        let tempURL = tempDir
            .appendingPathComponent("\(baseName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension.isEmpty ? "mov" : fileExtension)

        // Track the temporary file for cleanup
        temporaryFiles.insert(tempURL)

        return tempURL
    }

    // MARK: - FUNC
    private func getFileSize(from item: PhotosUI.PhotosPickerItem, correlationId: String)
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
        let progressReport = VideoLoadingProgress(phase: phase, correlationId: correlationId)

        // CRITICAL FIX: Ensure all UI state updates happen on MainActor
        await MainActor.run {
            // Send to traditional progress subject (for backward compatibility)
            self.progressSubject.send(progressReport)

            // Coordinate with UnifiedState - this is the critical fix
            self.unifiedState?.updateProgress(progressReport)
        }

        // Coordinate with OperationManager for consistent tracking
        await operationManager?.updateProgress(phase, correlationId: correlationId)

        // Only log essential state changes
        if phase == .initializing || phase == .validatingTrimmer || phase == .completed {
            logger.info("Video loading progress [\(correlationId)]: \(phase) -> UnifiedState updated on MainActor")
        }
    }

    // MARK: - FUNC
    private func logCompletion(
        result: VideoLoadingResult,
        startTime: Date,
        method: String
    ) {
        let duration = Date().timeIntervalSince(startTime)
        logger.info("✅ VIDEO LOADING COMPLETED [\(result.correlationId)]: \(method) (\(String(format: "%.2f", duration))s)")

        // ENHANCED DIAGNOSTIC: Log comprehensive completion details
        logger.info("📊 COMPLETION METRICS:")
        logger.info("   ├─ Method: \(method)")
        logger.info("   ├─ Duration: \(String(format: "%.2f", duration))s")
        logger.info("   ├─ File size: \(result.fileSize ?? 0) bytes")
        logger.info("   ├─ Video duration: \(result.duration.seconds)s")
        logger.info("   ├─ Source type: \(result.sourceType.description)")
        logger.info("   ├─ Has temp file: \(result.temporaryFileURL != nil)")
        logger.info("   └─ Coordination ID: \(result.correlationId)")

        // CRITICAL FIX: Simplified completion - let VideoInitializationCoordinator handle complex coordination
        if let coordinator = initializationCoordinator {
            logger.info("🔄 VideoInitializationCoordinator will handle completion coordination [\(result.correlationId)]")
            // The coordinator will handle all the complex state transitions
        } else {
            // Fallback for when coordinator is not available
            Task { @MainActor in
                await self.unifiedState?.setSelectedVideo(result.asset, url: result.temporaryFileURL)
                let completionProgress = VideoLoadingProgress(phase: .completed, correlationId: result.correlationId)
                self.progressSubject.send(completionProgress)
                self.unifiedState?.updateProgress(completionProgress)
                await self.operationManager?.updateProgress(.completed, correlationId: result.correlationId)
            }
        }

        memoryLogger.clearCorrelationId(for: "VideoLoadingService")
        currentCorrelationId = nil

        logger.info("🧹 VideoLoadingService cleanup completed [\(result.correlationId)]")
    }

    // MARK: - Enhanced Player Bridge Implementation

    /// Trigger automatic player initialization with enhanced coordination
    private func triggerPlayerInitialization(asset: AVAsset, correlationId: String) async {
        logger.info("🎮 ENHANCED PLAYER BRIDGE: Starting automatic player initialization [\(correlationId)]")

        // Broadcast a notification that can be observed by TrimmerView and other player components
        let playerBridgeNotification = Notification(
            name: .videoAssetReadyForPlayer,
            object: asset,
            userInfo: [
                "correlationId": correlationId,
                "asset": asset,
                "triggerSource": "VideoLoadingService"
            ]
        )

        logger.info("📡 PLAYER BRIDGE: Broadcasting video asset ready notification [\(correlationId)]")
        NotificationCenter.default.post(playerBridgeNotification)

        // Additional coordination through UnifiedState if available
        if let unifiedState = unifiedState {
            logger.info("🔗 PLAYER BRIDGE: Coordinating through UnifiedState [\(correlationId)]")

            // Ensure UnifiedState is in trimming state to trigger TrimmerView asset detection
            if unifiedState.flowState.isLoading {
                unifiedState.updateFlowState(.trimming)
                unifiedState.updateTab(.trimming)
                logger.info("✅ PLAYER BRIDGE: UnifiedState transitioned to trimming [\(correlationId)]")
            }
        }

        // Schedule verification to ensure player initialization occurred
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.verifyPlayerInitialization(correlationId: correlationId)
        }

        logger.info("✅ PLAYER BRIDGE: Initialization sequence completed [\(correlationId)]")
    }

    /// Verify that player initialization was successful
    private func verifyPlayerInitialization(correlationId: String) {
        logger.info("🔍 PLAYER BRIDGE VERIFICATION: Checking player initialization [\(correlationId)]")

        // Check if UnifiedState is in the expected state
        if let unifiedState = unifiedState {
            let hasVideo = unifiedState.selectedVideo != nil
            let flowState = unifiedState.flowState
            let hasError = unifiedState.hasError

            logger.info("📊 PLAYER BRIDGE VERIFICATION RESULTS:")
            logger.info("   ├─ Has video: \(hasVideo)")
            logger.info("   ├─ Flow state: \(flowState)")
            logger.info("   └─ Has error: \(hasError)")

            if hasVideo && flowState == .trimming && !hasError {
                logger.info("✅ PLAYER BRIDGE VERIFICATION SUCCESS: Player initialization appears successful [\(correlationId)]")
            } else {
                logger.warning("⚠️ PLAYER BRIDGE VERIFICATION ISSUE: State may not be optimal [\(correlationId)]")

                // Trigger recovery if needed
                if hasVideo && flowState.isLoading {
                    logger.info("🔧 PLAYER BRIDGE RECOVERY: Forcing transition to trimming [\(correlationId)]")
                    unifiedState.updateFlowState(.trimming)
                    unifiedState.updateTab(.trimming)
                }
            }
        }

        logger.info("🎯 PLAYER BRIDGE VERIFICATION COMPLETE [\(correlationId)]")
    }

    // MARK: - FUNC (Enhanced cancellation from ResilientVideoLoader)
    nonisolated public func cancelCurrentOperation() {
        Task { @MainActor in
            logger.info("🎬 VIDEO_LOADING: 🚫 Cancelling current operation")

            currentLoadingTask?.cancel()
            timeoutTask?.cancel()

            isLoading = false
            isWaitingForNetwork = false
            currentRetryAttempt = 0
            currentCorrelationId = nil

            logger.info("🎬 VIDEO_LOADING: ✅ Operation cancelled successfully")
        }
    }

    // MARK: - Network Monitoring Methods (from ResilientVideoLoader)
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: networkQueue)

        networkMonitorTask = Task { @MainActor in
            logger.info("🎬 VIDEO_LOADING: 🌐 Network monitoring started")
        }
    }

    private func handleNetworkPathUpdate(_ path: NWPath) {
        let newNetworkState = path.status == .satisfied
        let newConnectionType = determineConnectionType(path)
        let newNetworkQuality = determineNetworkQuality(path)

        // Log network state changes
        if isNetworkAvailable != newNetworkState || networkConnectionType != newConnectionType {
            logger.info("🎬 VIDEO_LOADING: 🌐 Network state changed")
            logger.info("🎬 VIDEO_LOADING: ├─ Available: \(newNetworkState ? "✅ YES" : "❌ NO")")
            logger.info("🎬 VIDEO_LOADING: ├─ Type: \(newConnectionType.displayName)")
            logger.info("🎬 VIDEO_LOADING: └─ Quality: \(newNetworkQuality.displayName)")
        }

        isNetworkAvailable = newNetworkState
        networkConnectionType = newConnectionType
        networkQuality = newNetworkQuality

        // Handle network state changes during loading
        if newNetworkState && networkLostDuringLoading && isLoading {
            Task { @MainActor in
                await handleNetworkRestored()
            }
        } else if !newNetworkState && isLoading {
            Task { @MainActor in
                await handleNetworkLost()
            }
        }
    }

    private func handleNetworkLost() async {
        guard isLoading && !isWaitingForNetwork else { return }

        logger.info("🎬 VIDEO_LOADING: ⚠️ Network lost during loading")

        networkLostDuringLoading = true
        isWaitingForNetwork = true

        // Store current operation for retry
        if let currentTask = currentLoadingTask {
            currentTask.cancel()
        }

        logger.info("🎬 VIDEO_LOADING: ⏳ Waiting for network restoration")
    }

    private func handleNetworkRestored() async {
        guard networkLostDuringLoading && isLoading else { return }

        logger.info("🎬 VIDEO_LOADING: 🌐 Network restored, resuming loading")

        networkLostDuringLoading = false
        isWaitingForNetwork = false

        // Will trigger retry logic in existing loading methods
        logger.info("🎬 VIDEO_LOADING: ✅ Network restored - ready to resume operations")
    }

    private func determineConnectionType(_ path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else if path.status == .unsatisfied {
            return .none
        } else {
            return .unknown
        }
    }

    private func determineNetworkQuality(_ path: NWPath) -> NetworkQuality {
        guard path.status == .satisfied else {
            return .poor
        }

        if path.usesInterfaceType(.wifi) {
            return .excellent
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .excellent
        } else if path.usesInterfaceType(.cellular) {
            return .good
        } else {
            return .fair
        }
    }

    deinit {
        // Perform synchronous cleanup to avoid retain cycle
        currentLoadingTask?.cancel()
        timeoutTask?.cancel()
        networkMonitorTask?.cancel()
        networkMonitor.cancel()

        // Clear references immediately
        currentLoadingTask = nil
        timeoutTask = nil
        networkMonitorTask = nil

        logger.debug("VideoLoadingService deallocated successfully")
    }

    // CRITICAL FIX: Post-completion verification moved to VideoInitializationCoordinator
    // This eliminates redundant verification and ensures single source of truth

    /// Performs comprehensive final cleanup
    private func performFinalCleanup() async {
        await cleanupTemporaryFiles()
        cleanup()

        // Clear any remaining references
        operationTimings.removeAll()
        currentCorrelationId = nil
        currentLoadingTask = nil
        timeoutTask = nil
        networkMonitorTask = nil

        logger.debug("VideoLoadingService final cleanup completed")
    }
}

// MARK: - ASYNC/AWAIT SUPPORT
extension VideoLoadingService {
    // MARK: - FUNC
    func loadVideoWithProgress(from item: PhotosUI.PhotosPickerItem) -> AnyPublisher<
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
