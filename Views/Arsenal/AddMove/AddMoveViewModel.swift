import SwiftUI
import PhotosUI
import AVKit
import CoreData
import Combine
import OSLog
import Foundation
import AVFoundation
import Photos



// MARK: - AddMoveError
public enum AddMoveError: LocalizedError {
    case photosPermissionDenied
    case iCloudUnavailable
    case videoLoadFailed(underlyingError: Error?)
    case videoFormatUnsupported
    case videoCopyFailed(underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error?)
    case unknown(underlyingError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .photosPermissionDenied:
            return "Photos access denied. Please enable Photos access in Settings."
        case .iCloudUnavailable:
            return "iCloud is unavailable. Please check your iCloud settings."
        case .videoLoadFailed(let error):
            return "Failed to load video. " + (error?.localizedDescription ?? "")
        case .videoFormatUnsupported:
            return "Unsupported video format. Please choose an MP4 or MOV file."
        case .videoCopyFailed(let error):
            return "Failed to copy video to BreakDex. " + (error?.localizedDescription ?? "")
        case .coreDataSaveFailed(let error):
            return "Failed to save your move. " + (error?.localizedDescription ?? "")
        case .unknown(let error):
            return "An unexpected error occurred. " + (error?.localizedDescription ?? "")
        }
    }
}

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
        
        guard item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) else {
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
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.logger.info("🎬 VIDEO_LOADER: Starting PHImageManager.requestAVAsset")
            self?.imageManager.requestAVAsset(forVideo: phAsset, options: options) { [weak self] avAsset, _, info in
                self?.logger.info("🎬 VIDEO_LOADER: PHImageManager request completed")
                
                if let error = info?[PHImageErrorKey] as? Error {
                    self?.logger.error("🎬 VIDEO_LOADER: PHImageManager error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    self?.logger.info("🎬 VIDEO_LOADER: AVAsset received successfully")
                    self?.logger.info("🎬 VIDEO_LOADER: Asset type: \(type(of: asset))")
                    if let urlAsset = asset as? AVURLAsset {
                        self?.logger.info("🎬 VIDEO_LOADER: Asset URL: \(urlAsset.url.absoluteString)")
                    }
                    continuation.resume(returning: asset)
                } else {
                    self?.logger.error("🎬 VIDEO_LOADER: No AVAsset or error received from PHImageManager")
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

@MainActor
class AddMoveViewModel: ObservableObject {
    // MARK: - State Management
    @Published var state: AddMoveState {
        didSet {
            // Delegate state transitions to state manager
            stateManager.transition(to: state)
        }
    }
    
    // MARK: - Published Properties
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            self.logger.info("🎬 VIEWMODEL: selectedItem didSet triggered")
            self.logger.info("🎬 VIEWMODEL: Old value: \(oldValue?.itemIdentifier ?? "nil")")
            self.logger.info("🎬 VIEWMODEL: New value: \(self.selectedItem?.itemIdentifier ?? "nil")")
            self.logger.info("🎬 VIEWMODEL: Current thread: \(Thread.current.isMainThread ? "Main" : "Background")")
            
            // Handle selection change through the new pipeline
            self.handleSelectionChanged()
        }
    }
    @Published var moveName: String = ""
    @Published var selectedFilename: String?
    
    // MARK: - Services
    private let viewContext: NSManagedObjectContext
    private let stateManager: AddMoveStateManagerProtocol
    private let videoAssetPreparer: VideoAssetPreparerProtocol
    private let videoPlayerCacheManager: VideoPlayerCacheManagerProtocol
    private let photosImportService: PhotosImportServiceProtocol
    private let movePersistenceService: MovePersistenceServiceProtocol
    private let videoLoader = AddMoveVideoLoader()
    private let appContainer = AppContainer.shared
    
    // MARK: - Private State
    private var loadingTask: Task<Void, Never>?
    private var currentPhotosIdentifier: String?
    
    // MARK: - Video Player Access
    /// Single Responsibility: Provide access to prepared VideoPlayerViewModelProtocol
    /// Used by PreTrimView for direct rendering without conditional logic
    private(set) var currentVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    
    /// Computed property for PreTrimView to access prepared ViewModel
    /// Returns nil if not ready, allowing PreTrimView to show loading state
    var preparedVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)? {
        // Only return ViewModel if it's actually ready to prevent rendering issues
        guard let viewModel = currentVideoPlayerViewModel,
              viewModel.isPlayerReady else {
            return nil
        }
        return viewModel
    }
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMove")
    
    
    
    init(
        viewContext: NSManagedObjectContext,
        stateManager: AddMoveStateManagerProtocol,
        videoAssetPreparer: VideoAssetPreparerProtocol,
        videoPlayerCacheManager: VideoPlayerCacheManagerProtocol,
        photosImportService: PhotosImportServiceProtocol,
        movePersistenceService: MovePersistenceServiceProtocol
    ) {
        self.viewContext = viewContext
        self.stateManager = stateManager
        self.videoAssetPreparer = videoAssetPreparer
        self.videoPlayerCacheManager = videoPlayerCacheManager
        self.photosImportService = photosImportService
        self.movePersistenceService = movePersistenceService
        
        // Initialize state
        self.state = .ready
        
        // Subscribe to state manager updates
        setupStateManagerSubscription()
        
        logger.info("🎬 VIEWMODEL: Initialized with all services")
    }
    
    // MARK: - Factory Method
    
    static func create(viewContext: NSManagedObjectContext) -> AddMoveViewModel {
        @MainActor
        func createServices() -> (
            AddMoveStateManagerProtocol,
            VideoAssetPreparerProtocol,
            VideoPlayerCacheManagerProtocol,
            PhotosImportServiceProtocol,
            MovePersistenceServiceProtocol
        ) {
            return (
                AddMoveStateManager(),
                VideoAssetPreparer(),
                VideoPlayerCacheManager(),
                PhotosImportService(),
                MovePersistenceService(viewContext: viewContext)
            )
        }
        
        let (stateManager, videoAssetPreparer, videoPlayerCacheManager, photosImportService, movePersistenceService) = createServices()
        
        return AddMoveViewModel(
            viewContext: viewContext,
            stateManager: stateManager,
            videoAssetPreparer: videoAssetPreparer,
            videoPlayerCacheManager: videoPlayerCacheManager,
            photosImportService: photosImportService,
            movePersistenceService: movePersistenceService
        )
    }
    
    // MARK: - State Manager Setup
    
    private func setupStateManagerSubscription() {
        // Subscribe to state changes from state manager
        // This ensures state synchronization
        logger.info("🎬 VIEWMODEL: Setting up state manager subscription")
    }
    
    
    // MARK: - Public API
    
    public func reset() {
        logger.info("🎬 VIEWMODEL: reset() called")
        logger.info("🎬 VIEWMODEL: Current state before reset: \(self.stateManager.getStateDescription(self.stateManager.currentState))")
        logger.info("🎬 VIEWMODEL: Cancelling loading task: \(self.loadingTask != nil)")
        
        // Cancel any ongoing tasks
        loadingTask?.cancel()
        // photosImportService.cancelImport() // Method not available in protocol
        
        // Reset all services
        stateManager.reset()
        videoPlayerCacheManager.clearCache()
        photosImportService.cleanupTempArtifacts()
        
        // Reset view model properties
        selectedItem = nil
        moveName = ""
        currentPhotosIdentifier = nil
        selectedFilename = nil
        currentVideoPlayerViewModel = nil
        
        logger.info("🎬 VIEWMODEL: reset() completed - state is now ready")
    }
    
    // MARK: - PhotosPicker Import Pipeline
    
    private func handleSelectionChanged() {
        logger.info("🎬 VIEWMODEL: handleSelectionChanged() called")
        
        guard let item = selectedItem else {
            logger.info("🎬 VIEWMODEL: No item selected")
            return
        }
        
        logger.info("🎬 VIEWMODEL: Item selected, starting import pipeline")
        
        Task {
            do {
                // Use PhotosImportService to handle the import
                _ = try await photosImportService.importVideo(from: item)
                
                // Now proceed with video preparation
                await prepareVideoForDisplay(from: item)
                
            } catch {
                logger.error("🎬 VIEWMODEL: ❌ Import pipeline failed: \(error.localizedDescription)")
                await stateManager.transitionToError(
                    message: "Failed to import video",
                    underlyingError: error.localizedDescription
                )
            }
        }
    }
    
    // MARK: - Public Methods for Player Access
    
    /// Get cached player view model for the given asset and rotation
    public func getCachedPlayerViewModel(asset: AVAsset, rotationQuarterTurns: Int) -> (any VideoPlayerViewModelProtocol)? {
        logger.info("🎬 VIEWMODEL: 🔍 Getting cached player for rotation: \(rotationQuarterTurns)")
        return videoPlayerCacheManager.getCachedPlayerViewModel(
            asset: asset,
            photosIdentifier: currentPhotosIdentifier,
            rotation: rotationQuarterTurns
        )
    }
    
    public func startTrimming(rotationQuarterTurns: Int = 0) {
        logger.info("🎬 VIEWMODEL: startTrimming() called")
        logger.info("🎬 VIEWMODEL: Parameter rotation: \(rotationQuarterTurns)")
        logger.info("🎬 VIEWMODEL: Current state: \(self.stateManager.currentStateDescription)")
        
        guard case .previewing(let playerViewModel, let asset, let photosIdentifier, let currentRotation) = state else {
            logger.error("🎬 VIEWMODEL: startTrimming() called but not in previewing state!")
            return
        }
        
        let rotationToUse = rotationQuarterTurns != 0 ? rotationQuarterTurns : currentRotation
        logger.info("🎬 VIEWMODEL: Using rotation: \(rotationToUse)° (from \(rotationQuarterTurns != 0 ? "parameter" : "current state"))")
        logger.info("🎬 VIEWMODEL: Asset exists: true")
        logger.info("🎬 VIEWMODEL: Photos ID: \(photosIdentifier ?? "nil")")
        
        // Cache the view model before tearing down for instant return from trimming
        logger.info("🎬 VIEWMODEL: 📦 Caching view model before transitioning to trimming")
        videoPlayerCacheManager.cacheVideoPlayerViewModel(
            playerViewModel,
            for: asset,
            photosIdentifier: photosIdentifier,
            rotation: rotationToUse
        )
        
        // CRITICAL: Removed aggressive pauseForTrimming() call
        // The VideoPlayerManager now handles player lifecycle across view transitions
        logger.info("🎬 VIEWMODEL: 🔄 Using VideoPlayerManager - no individual pause needed")
        logger.info("🎬 VIEWMODEL: 🎯 Player state preserved by VideoPlayerManager")
        
        // Clear the current video player view model reference
        self.currentVideoPlayerViewModel = nil
        
        // Transition to trimming state
        logger.info("🎬 VIEWMODEL: Transitioning to trimming state")
        stateManager.transitionToTrimming(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationToUse
        )
    }
    
    func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: cancelTrimming() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.stateManager.currentStateDescription)")
        
        guard case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: cancelTrimming() called but not in trimming state!")
            return
        }
        
        logger.info("🎬 VIEWMODEL: Returning to previewing state")
        logger.info("🎬 VIEWMODEL: Preserving rotation: \(rotationQuarterTurns)°")
        logger.info("🎬 VIEWMODEL: Asset exists: true")
        logger.info("🎬 VIEWMODEL: Photos ID: \(photosIdentifier ?? "nil")")
        
        // Try to get cached view model for instant loading
        let playerViewModel: any VideoPlayerViewModelProtocol
        
        if let cachedViewModel = videoPlayerCacheManager.getCachedPlayerViewModel(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotation: rotationQuarterTurns
        ) {
            logger.info("🎬 VIEWMODEL: 🚀 Cache HIT! Using preserved view model for instant return to preview")
            
            playerViewModel = cachedViewModel
            
            // Resume the preserved player for instant playback
            logger.info("🎬 VIEWMODEL: 🔄 Resuming preserved player (expecting instant playback)")
            let resumeStartTime = CFAbsoluteTimeGetCurrent()
            
            // Check if player needs reinitialization
            if let updatedPlayerViewModel = playerViewModel as? UpdatedVideoPlayerViewModel {
                if case .loading = updatedPlayerViewModel.state {
                    logger.info("🎬 VIEWMODEL: 🔄 Cached player in loading state, reinitializing")
                    let setupStartTime = CFAbsoluteTimeGetCurrent()
                    updatedPlayerViewModel.startPlayback()
                    let setupEndTime = CFAbsoluteTimeGetCurrent()
                    let setupTime = (setupEndTime - setupStartTime) * 1000
                    logger.info("🎬 VIEWMODEL: ⚡ Player reinitialization took \(String(format: "%.2f", setupTime))ms")
                } else {
                    logger.info("🎬 VIEWMODEL: 🎯 Cached player in playable state, resuming normally")
                    updatedPlayerViewModel.resumeAfterTrimming()
                }
            } else {
                logger.warning("🎬 VIEWMODEL: ⚠️ Cannot cast to UpdatedVideoPlayerViewModel, using generic resume")
                playerViewModel.resumeAfterTrimming()
            }
            
            let resumeEndTime = CFAbsoluteTimeGetCurrent()
            let totalResumeTime = (resumeEndTime - resumeStartTime) * 1000
            logger.info("🎬 VIEWMODEL: ⚡ Total resume from cache took \(String(format: "%.2f", totalResumeTime))ms")
            logger.info("🎬 VIEWMODEL: ✅ Instant playback achieved through player preservation")
            
        } else {
            logger.warning("🎬 VIEWMODEL: ⚠️ Cache MISS! Creating new view model")
            logger.info("🎬 VIEWMODEL: This should not happen with proper preservation")
            
            let createStartTime = CFAbsoluteTimeGetCurrent()
            playerViewModel = UpdatedVideoPlayerViewModel(
                asset: asset,
                rotationQuarterTurns: rotationQuarterTurns,
                appContainer: AppContainer.shared
            )
            videoPlayerCacheManager.cacheVideoPlayerViewModel(
                playerViewModel,
                for: asset,
                photosIdentifier: photosIdentifier,
                rotation: rotationQuarterTurns
            )
            
            let createEndTime = CFAbsoluteTimeGetCurrent()
            let createTime = (createEndTime - createStartTime) * 1000
            logger.info("🎬 VIEWMODEL: ⚠️ New player creation took \(String(format: "%.2f", createTime))ms (slower than preservation)")
        }
        
        // Assign player view model and transition state
        logger.info("🎬 VIEWMODEL: 📤 Assigning player view model to currentVideoPlayerViewModel")
        self.currentVideoPlayerViewModel = playerViewModel
        logger.info("🎬 VIEWMODEL: ✅ Player view model assigned successfully")
        
        logger.info("🎬 VIEWMODEL: 🔄 Transitioning state to previewing")
        stateManager.transitionToPreviewing(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    func backToTrimming() {
        logger.info("🎬 VIEWMODEL: backToTrimming() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.getStateDescription(self.state))")
        if case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = self.state {
            logger.info("🎬 VIEWMODEL: Returning to trimming state")
            logger.info("🎬 VIEWMODEL: Preserving rotation: \(rotationQuarterTurns)°")
            logger.info("🎬 VIEWMODEL: Asset exists: \(originalAsset != nil)")
            logger.info("🎬 VIEWMODEL: Photos ID: \(photosIdentifier)")
            
            // Return to trimming state with original asset and preserved rotation
            guard let originalAsset = originalAsset else {
                logger.error("🎬 VIEWMODEL: Original asset is nil in backToTrimming()")
                return
            }
            self.state = .trimming(
                asset: originalAsset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns
            )
        } else {
            logger.error("🎬 VIEWMODEL: backToTrimming() called but not in naming state!")
        }
    }
    
    func cancelChangeVideo() {
        logger.info("🎬 VIEWMODEL: cancelChangeVideo() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.getStateDescription(self.state))")
        
        if case .selectingVideo(let currentAsset) = self.state {
            if let currentAsset = currentAsset {
                logger.info("🎬 VIEWMODEL: Returning to previewing with existing asset")
                logger.info("🎬 VIEWMODEL: Asset exists: \(currentAsset != nil)")
                
                // Check cache first
                let playerViewModel: any VideoPlayerViewModelProtocol
                
                if let cachedViewModel = videoPlayerCacheManager.getCachedPlayerViewModel(
                    asset: currentAsset,
                    photosIdentifier: nil,
                    rotation: 0
                ) {
                    logger.info("🎬 VIEWMODEL: 🚀 Using cached view model for cancelChangeVideo")
                    playerViewModel = cachedViewModel
                } else {
                    logger.info("🎬 VIEWMODEL: Creating new view model for cancelChangeVideo")
                    playerViewModel = UpdatedVideoPlayerViewModel(asset: currentAsset, rotationQuarterTurns: 0, appContainer: appContainer)
                    videoPlayerCacheManager.cacheVideoPlayerViewModel(playerViewModel, for: currentAsset, photosIdentifier: nil, rotation: 0)
                }
                
                self.currentVideoPlayerViewModel = playerViewModel
                self.state = .previewing(playerViewModel: playerViewModel, asset: currentAsset, photosIdentifier: Optional<String>.none, rotationQuarterTurns: 0)
            } else {
                logger.info("🎬 VIEWMODEL: No current asset, returning to ready state")
                self.state = .ready
            }
        } else {
            logger.error("🎬 VIEWMODEL: cancelChangeVideo() called but not in selectingVideo state!")
        }
    }
    
    func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("🎬 VIEWMODEL: finishTrimming() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.getStateDescription(self.state))")
        logger.info("🎬 VIEWMODEL: Trimmer VM start time: \(String(describing: trimmerViewModel.startTime))")
        logger.info("🎬 VIEWMODEL: Trimmer VM end time: \(String(describing: trimmerViewModel.endTime))")
        logger.info("🎬 VIEWMODEL: Trimmer VM rotation: \(trimmerViewModel.rotationQuarterTurns)°")
        
        if case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = self.state {
            logger.info("🎬 VIEWMODEL: Starting trimming task")
            Task {
                do {
                    logger.info("🎬 VIEWMODEL: Calling trimmerViewModel.exportVideo()")
                    let exportedURL = try await trimmerViewModel.exportVideo()
                    logger.info("🎬 VIEWMODEL: Video export successful")
                    logger.info("🎬 VIEWMODEL: Exported URL: \(exportedURL.absoluteString)")
                    
                    let trimmedAsset = AVURLAsset(url: exportedURL)
                    logger.info("🎬 VIEWMODEL: Created trimmed asset from URL")
                    logger.info("🎬 VIEWMODEL: Setting naming state with trimmed asset")
                    logger.info("🎬 VIEWMODEL: Trim start: \(trimmerViewModel.startTime.seconds), end: \(trimmerViewModel.endTime.seconds)")
                    logger.info("🎬 VIEWMODEL: Original rotation: \(rotationQuarterTurns)°")
                    logger.info("🎬 VIEWMODEL: Updated rotation from trimmer: \(trimmerViewModel.rotationQuarterTurns)°")
                    
                    self.state = .naming(
                        photosIdentifier: photosIdentifier ?? "",
                        originalAsset: asset,
                        trimmedAsset: trimmedAsset,
                        trimStartTime: trimmerViewModel.startTime.seconds,
                        trimEndTime: trimmerViewModel.endTime.seconds,
                        rotationQuarterTurns: trimmerViewModel.rotationQuarterTurns
                    )
                } catch {
                    logger.error("🎬 VIEWMODEL: Video export failed: \(error.localizedDescription)")
                    logger.error("🎬 VIEWMODEL: Error type: \(type(of: error))")
                    self.state = .error(message: "Failed to export video.", underlyingError: error.localizedDescription)
                }
            }
        } else {
            logger.error("🎬 VIEWMODEL: finishTrimming() called but not in trimming state!")
        }
    }
    
    func saveMove() {
        logger.info("🎬 VIEWMODEL: saveMove() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.getStateDescription(self.state))")
        logger.info("🎬 VIEWMODEL: Move name: \(self.moveName)")
        
        guard case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = self.state else {
            logger.error("🎬 VIEWMODEL: saveMove() called but not in naming state!")
            return
        }
        
        self.state = .saving
        logger.info("🎬 VIEWMODEL: State set to saving")
        
        Task {
            do {
                // Use the trimmed asset if available, otherwise use original
                guard let assetToSave = trimmedAsset ?? originalAsset else {
                    logger.error("🎬 VIEWMODEL: No asset available to save")
                    throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No asset available to save"])
                }
                logger.info("🎬 VIEWMODEL: Using asset for save: \(assetToSave)")
                
                // Save to Photos library
                let savedVideoURL = try await movePersistenceService.saveVideoToPhotos(asset: assetToSave, moveName: self.moveName)
                logger.info("🎬 VIEWMODEL: Video saved to Photos at: \(savedVideoURL)")
                
                // Create Move entity in Core Data
                let move = try await movePersistenceService.createMoveEntity(
                    name: self.moveName,
                    videoURL: savedVideoURL,
                    originalPhotosIdentifier: photosIdentifier,
                    trimStartTime: trimStartTime,
                    trimEndTime: trimEndTime,
                    rotationQuarterTurns: rotationQuarterTurns
                )
                logger.info("🎬 VIEWMODEL: Move entity created: \(move)")
                
                // Reset and return to ready state
                await MainActor.run { [weak self] in
                    self?.moveName = ""
                    self?.currentPhotosIdentifier = nil
                    self?.currentVideoPlayerViewModel = nil
                    self?.state = .ready
                    logger.info("🎬 VIEWMODEL: Save completed successfully")
                }
                
            } catch {
                logger.error("🎬 VIEWMODEL: Save failed with error: \(error.localizedDescription)")
                await MainActor.run { [weak self] in
                    self?.state = .error(message: "Failed to save move: \(error.localizedDescription)", underlyingError: error.localizedDescription)
                }
            }
        }
    }
    
    func startNaming() {
        logger.info("🎬 VIEWMODEL: startNaming() called")
        logger.info("🎬 VIEWMODEL: Current state: \(self.getStateDescription(self.state))")
        
        if case .previewing(_, let asset, let photosIdentifier, let rotationQuarterTurns) = self.state {
            logger.info("🎬 VIEWMODEL: Creating naming state from previewing")
            logger.info("🎬 VIEWMODEL: Preserving rotation: \(rotationQuarterTurns)°")
            logger.info("🎬 VIEWMODEL: Asset exists: true")
            logger.info("🎬 VIEWMODEL: Photos ID: \(photosIdentifier ?? "nil")")
            self.state = .naming(photosIdentifier: photosIdentifier ?? "", originalAsset: asset, trimmedAsset: Optional<AVAsset>.none, trimStartTime: Optional<Double>.none, trimEndTime: Optional<Double>.none, rotationQuarterTurns: rotationQuarterTurns)
        } else {
            logger.error("🎬 VIEWMODEL: startNaming() called but not in previewing state!")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStateDescription(_ state: AddMoveState) -> String {
        switch state {
        case .ready:
            return "ready"
        case .loading(let progress, let status):
            return "loading(\(progress), \(status))"
        case .initializing(let progress, let status):
            return "initializing(\(progress), \(status))"
        case .loaded(_, let id, _):
            return "loaded(id: \(id ?? "nil"), rotation: 0°)"
        case .previewing(_, _, let id, let rotation):
            return "previewing(id: \(id ?? "nil"), rotation: \(rotation)°)"
        case .selectingVideo(let asset):
            return "selectingVideo(asset: \(asset != nil ? "exists" : "nil"))"
        case .trimming(_, let id, let rotation):
            return "trimming(id: \(id ?? "nil"), rotation: \(rotation)°)"
        case .naming(let id, _, _, let start, let end, let rotation):
            return "naming(id: \(id), start: \(start ?? -1), end: \(end ?? -1), rotation: \(rotation)°)"
        case .saving:
            return "saving"
        case .success(let message):
            return "success(\(message))"
        case .error(let message, let underlying):
            return "error(\(message), underlying: \(underlying ?? "nil"))"
        }
    }
    
    // MARK: - Private Video Preparation (SRP)
    
    /// Single Responsibility: Coordinate video preparation workflow
    /// Uses VideoAssetPreparer for async processing, then manages state
    private func prepareVideoForDisplay(from item: PhotosPickerItem) async {
        logger.info("🎬 VIEWMODEL: prepareVideoForDisplay called")
        logger.info("🎬 VIEWMODEL: Item ID: \(item.itemIdentifier ?? "nil")")
        logger.info("🎬 VIEWMODEL: Supported content types: \(item.supportedContentTypes)")
        logger.info("🎬 VIEWMODEL: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")
        
        // Cancel any existing loading task
        if let existingTask = self.loadingTask {
            logger.info("🎬 VIEWMODEL: Cancelling existing loading task")
            existingTask.cancel()
        }
        self.loadingTask?.cancel()
        
        logger.info("🎬 VIEWMODEL: Setting loading state")
        self.state = .loading(progress: 0.0, status: "Preparing to load video...")
        
        self.loadingTask = Task {
            logger.info("🎬 VIEWMODEL: 🚀 Starting video preparation Task")
            logger.info("🎬 VIEWMODEL: 🔄 About to begin video loading retry loop")
            
            // Implement retry logic with exponential backoff
            var lastError: Error?
            let maxRetries = 3
            var retryCount = 0
            
            logger.info("🎬 VIEWMODEL: 🔄 Starting retry loop (max retries: \(maxRetries))")
            while retryCount < maxRetries {
                logger.info("🎬 VIEWMODEL: 🔄 Attempt #\(retryCount + 1) of \(maxRetries)")
                do {
                    if retryCount > 0 {
                        let delay = pow(2.0, Double(retryCount)) * 1_000_000_000 // Exponential backoff in nanoseconds
                        logger.info("🎬 VIEWMODEL: Retry attempt #\(retryCount + 1) after \(delay / 1_000_000_000) seconds delay")
                        try await Task.sleep(nanoseconds: UInt64(delay))
                    }
                    
                    logger.info("🎬 VIEWMODEL: Calling VideoLoader.loadVideo() (Attempt #\(retryCount + 1))")
                    logger.info("🎬 VIEWMODEL: 📊 Memory before loading: \(os_proc_available_memory() / (1024*1024)) MB available")
                    
                    // Single Responsibility: VideoLoader handles all async video processing
                    let result = try await videoLoader.loadVideo(from: item)
                    logger.info("🎬 VIEWMODEL: 📊 Memory after loading: \(os_proc_available_memory() / (1024*1024)) MB available")
                    let duration = try await result.asset.load(.duration).seconds
                    let trackCount = (try await result.asset.load(.tracks)).count
                    logger.info("🎬 VIEWMODEL: 📊 Asset details - duration: \(duration)s, tracks: \(trackCount)")
                    
                    logger.info("🎬 VIEWMODEL: Creating UpdatedVideoPlayerViewModel synchronously.")
                    let playerViewModel = UpdatedVideoPlayerViewModel(asset: result.asset, rotationQuarterTurns: 0, appContainer: appContainer)
                    self.currentVideoPlayerViewModel = playerViewModel
                    
                    // Cache the initial view model for potential future use
                    videoPlayerCacheManager.cacheVideoPlayerViewModel(playerViewModel, for: result.asset, photosIdentifier: result.photosIdentifier, rotation: 0)
                    logger.info("🎬 VIEWMODEL: 📊 Memory after creating player VM: \(os_proc_available_memory() / (1024*1024)) MB available")
                    
                    // --- NEW LOGIC ---
                    logger.info("🎬 VIEWMODEL: ⏳ Transitioning to initializing state...")
                    self.state = .initializing(progress: 0.5, status: "Initializing video player...")
                    
                    logger.info("🎬 VIEWMODEL: ⏳ Waiting for UpdatedVideoPlayerViewModel to become ready...")
                    let readyStartTime = Date()
                    // Wait for the player's async setup to complete.
                    while !playerViewModel.isPlayerReady {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                        if Task.isCancelled {
                            logger.info("🎬 VIEWMODEL: Video preparation task was cancelled during player readiness wait.")
                            return
                        }
                    }
                    let readyTime = Date().timeIntervalSince(readyStartTime)
                    logger.info("🎬 VIEWMODEL: ✅ UpdatedVideoPlayerViewModel is ready (took \(String(format: "%.2f", readyTime))s)")
                    logger.info("🎬 VIEWMODEL: 📊 Memory after player ready: \(os_proc_available_memory() / (1024*1024)) MB available")
                    // --- END NEW LOGIC ---
                    
                    if Task.isCancelled {
                        logger.info("🎬 VIEWMODEL: Video preparation task was cancelled after player readiness wait.")
                        return
                    }
                    
                    self.selectedFilename = result.filename
                    self.currentPhotosIdentifier = result.photosIdentifier
                    logger.info("🎬 VIEWMODEL: 📊 Video details - filename: \(result.filename), photosID: \(result.photosIdentifier ?? "nil")")
                    
                    logger.info("🎬 VIEWMODEL: Transitioning to previewing state with prepared player.")
                    let stateChangeStartTime = Date()
                    self.state = .previewing(
                        playerViewModel: playerViewModel,
                        asset: result.asset,
                        photosIdentifier: result.photosIdentifier,
                        rotationQuarterTurns: 0
                    )
                    let stateChangeTime = Date().timeIntervalSince(stateChangeStartTime)
                    logger.info("🎬 VIEWMODEL: ✅ State change completed (took \(String(format: "%.2f", stateChangeTime))s)")
                    
                    // Success - break out of retry loop
                    return
                    
                } catch {
                    if Task.isCancelled {
                        logger.info("🎬 VIEWMODEL: Video preparation task was cancelled (error handling)")
                        return
                    }
                    
                    retryCount += 1
                    lastError = error
                    
                    logger.error("🎬 VIEWMODEL: ❌ Video preparation failed (Attempt #\(retryCount))")
                    logger.error("🎬 VIEWMODEL: Error type: \(type(of: error))")
                    logger.error("🎬 VIEWMODEL: Error details: \(error.localizedDescription)")
                    logger.error("🎬 VIEWMODEL: 📊 Memory after error: \(os_proc_available_memory() / (1024*1024)) MB available")
                    
                    if retryCount < maxRetries {
                        let delay = pow(2.0, Double(retryCount))
                        logger.info("🎬 VIEWMODEL: ⏳ Will retry after \(delay) seconds (Attempt \(retryCount) of \(maxRetries))")
                    }
                }
            }
            
            // If we get here, all retries failed
            logger.error("🎬 VIEWMODEL: ❌ Video preparation loop completed without success")
            if let error = lastError {
                logger.error("🎬 VIEWMODEL: ❌ All \(maxRetries) retry attempts failed")
                logger.error("🎬 VIEWMODEL: Final error: \(error.localizedDescription)")
                logger.error("🎬 VIEWMODEL: 📊 Memory at failure: \(os_proc_available_memory() / (1024*1024)) MB available")
                logger.error("🎬 VIEWMODEL: 🔍 Detailed error info: \(String(describing: error))")
                self.state = .error(message: "Failed to load video after \(maxRetries) attempts.", underlyingError: error.localizedDescription)
            } else {
                logger.error("🎬 VIEWMODEL: ❌ No error recorded but video preparation failed")
                self.state = .error(message: "Video preparation failed for unknown reasons.", underlyingError: nil)
            }
        }
    }
    
    // MARK: - Legacy Video Loading (for backward compatibility)
    
    /// Async setup method - called from didSet to prevent UI blocking
    private func loadVideoAsync(from item: PhotosPickerItem) async {
        logger.info("🎬 VIEWMODEL: loadVideoAsync called")
        logger.info("🎬 VIEWMODEL: Item ID: \(item.itemIdentifier ?? "nil")")
        logger.info("🎬 VIEWMODEL: Supported content types: \(item.supportedContentTypes)")
        logger.info("🎬 VIEWMODEL: Thread: \(Thread.current.isMainThread ? "Main" : "Background")")
        
        // Cancel any existing loading task
        if let existingTask = self.loadingTask {
            logger.info("🎬 VIEWMODEL: Cancelling existing loading task")
            existingTask.cancel()
        }
        self.loadingTask?.cancel()
        
        logger.info("🎬 VIEWMODEL: Setting loading state")
        self.state = .loading(progress: 0.0, status: "Preparing to load video...")
        
        self.loadingTask = Task {
            logger.info("🎬 VIEWMODEL: Starting video loading Task")
            do {
                logger.info("🎬 VIEWMODEL: Calling videoLoader.loadVideo()")
                let result = try await self.videoLoader.loadVideo(from: item)
                
                if Task.isCancelled {
                    logger.info("🎬 VIEWMODEL: Video loading task was cancelled")
                    return
                }
                
                logger.info("🎬 VIEWMODEL: Video loading successful")
                logger.info("🎬 VIEWMODEL: Result filename: \(result.filename)")
                logger.info("🎬 VIEWMODEL: Result photos ID: \(result.photosIdentifier ?? "nil")")
                logger.info("🎬 VIEWMODEL: Result asset exists: \(result.asset != nil)")
                
                self.selectedFilename = result.filename
                self.currentPhotosIdentifier = result.photosIdentifier
                logger.info("🎬 VIEWMODEL: Setting previewing state with rotation 0")
                // Note: In the legacy method, we don't have a prepared UpdatedVideoPlayerViewModel yet
                // This would need to be updated if this method is still used
                let playerViewModel = UpdatedVideoPlayerViewModel(asset: result.asset, rotationQuarterTurns: 0, appContainer: appContainer)
                self.currentVideoPlayerViewModel = playerViewModel
                
                // Cache the view model for future use
                videoPlayerCacheManager.cacheVideoPlayerViewModel(playerViewModel, for: result.asset, photosIdentifier: result.photosIdentifier, rotation: 0)
                self.state = .previewing(playerViewModel: playerViewModel, asset: result.asset, photosIdentifier: result.photosIdentifier, rotationQuarterTurns: 0)
                
            } catch {
                if Task.isCancelled {
                    logger.info("🎬 VIEWMODEL: Video loading task was cancelled (error handling)")
                    return
                }
                logger.error("🎬 VIEWMODEL: Video loading failed with error: \(error.localizedDescription)")
                logger.error("🎬 VIEWMODEL: Error type: \(type(of: error))")
                self.state = .error(message: "Failed to load video.", underlyingError: error.localizedDescription)
            }
        }
    }
}
