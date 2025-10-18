import AVFoundation
import Combine
import CoreMedia
import Foundation
import Network
import OSLog
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Robust Video Loader
/// Focused, self-contained service for robust video loading.
/// Handles iCloud downloads, large files, and network conditions internally
/// while providing a simple external interface.
@MainActor
public final class RobustVideoLoader: ObservableObject {

    // MARK: - Public Interface
    @Published public private(set) var state: LoadingState = .idle
    @Published public private(set) var progress: LoadingProgress = .initial

    // MARK: - Private Properties
    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "🚀 RobustVideoLoader"
    )

    private let imageManager = PHImageManager.default()
    private var temporaryFiles: Set<URL> = []
    private var currentLoadingTask: Task<Void, Never>?

    // MARK: - Async Boundary State Coordination
    /// Removed player coordination logic - now focuses on pure asset loading
    /// State transitions are handled by AddMoveViewModel using monotonic validation

    // MARK: - Network Configuration
    static let defaultTimeout: TimeInterval = 45.0
    private static let maxRetryAttempts = 3
    private static let baseRetryDelay: TimeInterval = 2.0
    private static let maxRetryDelay: TimeInterval = 16.0

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "breakdex.robust.network", qos: .utility)
    private var retryCount = 0
    private var isNetworkAvailable = true

    // MARK: - Initialization Boundary Management
    /// Tracks whether the loader is in initialization phase to prevent spurious @Published updates
    private var isInitializing = true
    /// Tracks when initialization completed for boundary detection
    private var initializationCompletedTime: Date?

    // MARK: - Initialization
    public init() {
        // Defer network monitoring setup until after initialization to prevent spurious state transitions
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            completeInitialization()
        }

        logger.info("🚀 RobustVideoLoader initialized - network monitoring deferred")
    }

    deinit {
        Task { @MainActor in
            cleanup()
        }
    }

    // MARK: - Public Loading Methods

    /// Load video from PhotosPicker item
    public func loadVideo(from item: PhotosUI.PhotosPickerItem) async throws -> AVAsset {
        logger.info("🎬 Loading video from PhotosPicker")

        let previousState = state
        await updateState(.loading(progress: 0.0, stage: .initializing, message: "Initializing video load..."))
        await updateProgress(.initial)

        do {
            let asset = try await loadFromPhotosPicker(item)
            // MODERNIZED: Only set assetReady state - player initialization handled by ViewModel
            let newState = LoadingState.assetReady(asset)
            if newState.validateMonotonicTransition(from: previousState) {
                await updateState(newState)
                await updateProgress(.creatingAsset)
                Logger.loadingState.info("✅ Asset loading completed - assetReady state set")
            } else {
                Logger.loadingState.error("❌ Invalid state transition detected, using monotonic validation")
                throw LoadingError.unknown("State transition validation failed")
            }
            return asset
        } catch {
            await updateState(.failed(error.localizedDescription))
            throw LoadingError.from(error)
        }
    }

    /// Load video from URL
    public func loadVideo(from url: URL) async throws -> AVAsset {
        logger.info("🎬 Loading video from URL: \(url.lastPathComponent)")

        let previousState = state
        await updateState(.loading(progress: 0.0, stage: .initializing, message: "Initializing video load..."))
        await updateProgress(.initial)

        do {
            let asset = try await loadFromURL(url)
            // MODERNIZED: Only set assetReady state - player initialization handled by ViewModel
            let newState = LoadingState.assetReady(asset)
            if newState.validateMonotonicTransition(from: previousState) {
                await updateState(newState)
                await updateProgress(.creatingAsset)
                Logger.loadingState.info("✅ Asset loading completed - assetReady state set")
            } else {
                Logger.loadingState.error("❌ Invalid state transition detected, using monotonic validation")
                throw LoadingError.unknown("State transition validation failed")
            }
            return asset
        } catch {
            await updateState(.failed(error.localizedDescription))
            throw LoadingError.from(error)
        }
    }

    /// Load video from PHAsset
    public func loadVideo(from phAsset: PHAsset) async throws -> AVAsset {
        logger.info("🎬 Loading video from PHAsset: \(phAsset.localIdentifier)")

        let previousState = state
        await updateState(.loading(progress: 0.0, stage: .initializing, message: "Initializing video load..."))
        await updateProgress(.initial)

        do {
            let asset = try await loadFromPHAsset(phAsset)
            // MODERNIZED: Only set assetReady state - player initialization handled by ViewModel
            let newState = LoadingState.assetReady(asset)
            if newState.validateMonotonicTransition(from: previousState) {
                await updateState(newState)
                await updateProgress(.creatingAsset)
                Logger.loadingState.info("✅ Asset loading completed - assetReady state set")
            } else {
                Logger.loadingState.error("❌ Invalid state transition detected, using monotonic validation")
                throw LoadingError.unknown("State transition validation failed")
            }
            return asset
        } catch {
            await updateState(.failed(error.localizedDescription))
            throw LoadingError.from(error)
        }
    }

    /// Cancel current loading operation
    public func cancelLoading() {
        logger.info("🚫 Canceling loading operation")
        currentLoadingTask?.cancel()
        currentLoadingTask = nil
        cleanup()
        updateState(.idle)
    }

    /// Clean up temporary files
    public func cleanupTemporaryFiles() async {
        logger.info("🧹 Cleaning up \(temporaryFiles.count) temporary files")

        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                logger.debug("Removed temporary file: \(url.lastPathComponent)")
            } catch {
                logger.warning("Failed to remove temporary file: \(url.lastPathComponent)")
            }
        }

        temporaryFiles.removeAll()
        logger.info("Temporary files cleanup completed")
    }

    // MARK: - Private Loading Implementation

    private func loadFromPhotosPicker(_ item: PhotosUI.PhotosPickerItem) async throws -> AVAsset {
        guard let itemIdentifier = item.itemIdentifier else {
            throw LoadingError.assetNotFound
        }

        // Try streaming first, then fallback to Photos library
        if let url = try await item.loadTransferable(type: URL.self) {
            await updateProgress(.downloading)
            return try await loadFromURL(url)
        }

        // Fallback to Photos library
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw LoadingError.assetNotFound
        }

        return try await loadFromPHAsset(phAsset)
    }

    private func loadFromPHAsset(_ phAsset: PHAsset) async throws -> AVAsset {
        guard phAsset.mediaType == .video else {
            throw LoadingError.unsupportedFileType
        }

        Logger.loadingState.info("🎬 Starting PHAsset loading with modern async APIs")
        await updateProgress(.downloading)

        // MODERNIZED: Use iOS 18's async AVAsset loading with proper structured concurrency
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        // Set up progress handler for iCloud downloads
        options.progressHandler = { progress, _, _, _ in
            Task { @MainActor in
                let progressValue = Double(progress)
                let iCloudProgress = LoadingProgress.iCloudDownload(progress: progressValue, speed: 0)
                self.updateProgress(iCloudProgress)
                let loadingState = LoadingState.loading(progress: progressValue, stage: .downloadingFromCloud, message: "Downloading from iCloud...")
                Logger.loadingState.debug("📥 iCloud download progress: \(Int(progressValue * 100))%")
                self.updateState(loadingState)
            }
        }

        // MODERNIZED: Use structured concurrency with callback-based API
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { asset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    Logger.loadingState.error("❌ PHAsset loading failed: \(error.localizedDescription)")
                    continuation.resume(throwing: LoadingError.from(error))
                    return
                }

                guard let asset = asset else {
                    Logger.loadingState.error("❌ PHAsset loading failed: asset not found")
                    continuation.resume(throwing: LoadingError.assetNotFound)
                    return
                }

                Logger.loadingState.info("✅ PHAsset loading completed successfully")

                // Validate the asset asynchronously
                Task { @MainActor in
                    do {
                        try await self.validateAsset(asset)
                        continuation.resume(returning: asset)
                    } catch {
                        Logger.loadingState.error("❌ Asset validation failed: \(error.localizedDescription)")
                        continuation.resume(throwing: LoadingError.from(error))
                    }
                }
            }
        }
    }

    private func loadFromURL(_ url: URL) async throws -> AVAsset {
        await updateProgress(.downloading)

        let tempURL = createTemporaryURL(filename: url.lastPathComponent)

        // Copy file to temporary location for robust access
        try await streamCopy(from: url, to: tempURL)
        temporaryFiles.insert(tempURL)

        await updateProgress(.validating)

        let asset = AVURLAsset(url: tempURL)

        // Validate asset
        try await validateAsset(asset)

        return asset
    }

    // MARK: - Post-Download Processing
    // REMOVED: Complex player coordination logic - now handled by AddMoveViewModel
    // This section now focuses only on asset loading and validation

    // MARK: - Asset Validation

    private func validateAsset(_ asset: AVAsset) async throws {
        updateProgress(LoadingProgress(value: 0.8, message: "Validating video..."))

        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 else {
            throw LoadingError.corruptedFile
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw LoadingError.unsupportedFileType
        }

        logger.debug("Asset validated: \(duration.seconds)s, \(videoTracks.count) video tracks")
    }

    // MARK: - File Operations

    private func createTemporaryURL(filename: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let baseName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: filename).pathExtension

        let tempURL = tempDir
            .appendingPathComponent("\(baseName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension.isEmpty ? "mov" : fileExtension)

        return tempURL
    }

    private func streamCopy(from sourceURL: URL, to destinationURL: URL) async throws {
        // Check if source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw LoadingError.assetNotFound
        }

        // Remove destination if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        // Perform copy with progress feedback
        updateProgress(LoadingProgress(value: 0.2, message: "Transferring file..."))

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        updateProgress(LoadingProgress(value: 0.6, message: "File transferred"))
    }

    // MARK: - Network Resilience

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkChange(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func handleNetworkChange(_ path: NWPath) {
        let newNetworkState = path.status == .satisfied

        if isNetworkAvailable != newNetworkState {
            logger.info("🌐 Network state changed: \(newNetworkState ? "Available" : "Unavailable")")
            isNetworkAvailable = newNetworkState
        }
    }

    private func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = Self.baseRetryDelay * pow(2.0, Double(attempt - 1))
        return min(delay, Self.maxRetryDelay)
    }

    // MARK: - State Management

    private func updateState(_ newState: LoadingState) {
        // Prevent @Published updates during initialization to avoid spurious state transitions
        guard !isInitializing else {
            logger.debug("🚫 Suppressing state update during initialization: \(newState)")
            return
        }

        state = newState
        logger.debug("State updated: \(state)")
    }

    private func updateProgress(_ newProgress: LoadingProgress) {
        // Prevent @Published updates during initialization to avoid spurious progress notifications
        guard !isInitializing else {
            logger.debug("🚫 Suppressing progress update during initialization: \(Int(newProgress.value * 100))%")
            return
        }

        progress = newProgress
        logger.debug("Progress updated: \(Int(newProgress.value * 100))%")
    }

    // MARK: - Initialization Boundary Management

    /// Complete initialization phase and set up network monitoring
    private func completeInitialization() {
        isInitializing = false
        initializationCompletedTime = Date()

        // Now set up network monitoring after initialization boundary
        setupNetworkMonitoring()

        logger.info("✅ RobustVideoLoader initialization completed - network monitoring enabled")
    }

    // MARK: - Cleanup

    private func cleanup() {
        currentLoadingTask?.cancel()
        currentLoadingTask = nil
        networkMonitor.cancel()

        Task {
            await cleanupTemporaryFiles()
        }
    }
}

// MARK: - LoadingError Extension
extension LoadingError {
    static func from(_ error: Error) -> LoadingError {
        if let loadingError = error as? LoadingError {
            return loadingError
        }

        // Map common error types
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkUnavailable
        } else if errorDescription.contains("permission") || errorDescription.contains("denied") {
            return .permissionDenied
        } else if errorDescription.contains("timeout") || errorDescription.contains("timed out") {
            return .timeout(RobustVideoLoader.defaultTimeout)
        } else if errorDescription.contains("corrupt") || errorDescription.contains("invalid") {
            return .corruptedFile
        } else if errorDescription.contains("format") || errorDescription.contains("unsupported") {
            return .unsupportedFileType
        } else if errorDescription.contains("not found") {
            return .assetNotFound
        } else {
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Player Coordination Methods (REMOVED)
// REMOVED: Player coordination logic - now handled by AddMoveViewModel with monotonic state validation
// The loader now focuses exclusively on asset loading with proper async/await patterns