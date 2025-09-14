import SwiftUI
import PhotosUI
import AVKit
import CoreData
import OSLog
import Foundation
import AVFoundation
import Photos

// MARK: - Modern AddMove View Model
// Following iOS 18 best practices with proper SRP and single source of truth
@Observable
@MainActor
public final class AddMoveViewModel {
    
    // MARK: - Observable Properties
    public private(set) var state: AddMoveState = .ready
    public var selectedItem: PhotosPickerItem? {
        didSet {
            // Prevent duplicate processing of the same item
            guard oldValue != selectedItem else {
                logger.info("🎬 VIEWMODEL: Ignoring duplicate selection")
                return
            }
            
            guard selectedItem != nil else {
                logger.info("🎬 VIEWMODEL: Selection cleared")
                return
            }
            
            logger.info("🎬 VIEWMODEL: New item selected, starting loading process")
            
            // Cancel any existing loading task
            loadingTask?.cancel()
            
            Task {
                await handleVideoSelection()
            }
        }
    }
    public var moveName: String = ""
    public var importState: SelectionState = .idle
    
    // MARK: - Private Properties
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveViewModel")
    private var loadingTask: Task<Void, Never>?
    private var currentPhotosIdentifier: String?
    private var currentVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    
    // MARK: - Video Player Access
    var preparedVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)? {
        guard let viewModel = currentVideoPlayerViewModel,
              viewModel.isPlayerReady else {
            return nil
        }
        return viewModel
    }
    
    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        logger.info("🎬 VIEWMODEL: Initialized")
    }
    
    // MARK: - Factory Method
    public static func create(viewContext: NSManagedObjectContext) -> AddMoveViewModel {
        return AddMoveViewModel(viewContext: viewContext)
    }
    
    // MARK: - Public API
    
    /// Reset the entire AddMove flow
    public func reset() {
        logger.info("🎬 VIEWMODEL: Resetting")
        
        // Cancel any ongoing tasks
        loadingTask?.cancel()
        
        // Reset state and properties
        state = .ready
        selectedItem = nil
        moveName = ""
        currentPhotosIdentifier = nil
        currentVideoPlayerViewModel = nil
        
        logger.info("🎬 VIEWMODEL: Reset completed")
    }
    
    /// Handle video selection from PhotosPicker
    public func handleVideoSelection() {
        logger.info("🎬 VIEWMODEL: Handling video selection")
        
        guard let item = selectedItem else {
            logger.info("🎬 VIEWMODEL: No item selected")
            return
        }
        
        // Let loadVideo handle the initial loading state to avoid double state changes
        Task {
            do {
                try await loadVideo(from: item)
            } catch {
                logger.error("🎬 VIEWMODEL: Video loading failed: \(error.localizedDescription)")
                state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }
        }
    }
    
    /// Start trimming the current video
    public func startTrimming(rotationQuarterTurns: Int = 0) {
        logger.info("🎬 VIEWMODEL: Starting trimming")
        
        guard case .previewing(_, let asset, let photosIdentifier, let currentRotation) = state else {
            logger.error("🎬 VIEWMODEL: Cannot start trimming - not in previewing state")
            return
        }
        
        let rotationToUse = rotationQuarterTurns != 0 ? rotationQuarterTurns : 0
        
        state = .trimming(
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationToUse
        )
    }
    
    /// Cancel trimming and return to preview
    public func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: Canceling trimming")
        
        guard case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot cancel trimming - not in trimming state")
            return
        }
        
        // Create new player view model
        let playerViewModel = MainVideoPlayerViewModel(
            asset: asset,
            rotationQuarterTurns: rotationQuarterTurns,
            appContainer: AppContainer.shared
        )
        
        currentVideoPlayerViewModel = playerViewModel
        
        state = .previewing(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Cancel video selection and return to preview
    public func cancelChangeVideo() {
        logger.info("🎬 VIEWMODEL: Canceling video selection")
        
        guard case .selectingVideo(let asset) = state else {
            logger.error("🎬 VIEWMODEL: Cannot cancel video selection - not in selectingVideo state")
            return
        }
        
        guard let asset = asset else {
            logger.error("🎬 VIEWMODEL: No asset available to return to preview")
            state = .ready
            return
        }
        
        // Create new player view model
        let playerViewModel = MainVideoPlayerViewModel(
            asset: asset,
            rotationQuarterTurns: 0, // Default rotation
            appContainer: AppContainer.shared
        )
        
        currentVideoPlayerViewModel = playerViewModel
        
        state = .previewing(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: currentPhotosIdentifier,
            rotationQuarterTurns: 0
        )
        
        logger.info("🎬 VIEWMODEL: Video selection canceled, returned to preview")
    }
    
    /// Go back to trimming from naming
    public func backToTrimming() {
        logger.info("🎬 VIEWMODEL: Going back to trimming")
        
        guard case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot go back to trimming - not in naming state")
            return
        }
        
        // Use the original asset for going back to trimming
        guard let assetToUse = originalAsset else {
            logger.error("🎬 VIEWMODEL: No original asset available for trimming")
            state = .error(message: "No video asset available", underlyingError: nil)
            return
        }
        
        state = .trimming(
            asset: assetToUse,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
        
        logger.info("🎬 VIEWMODEL: Returned to trimming state")
    }
    
    /// Start video selection
    public func startVideoSelection(from currentAsset: AVAsset? = nil) {
        logger.info("🎬 VIEWMODEL: Starting video selection")
        
        state = .selectingVideo(currentAsset: currentAsset)
        
        logger.info("🎬 VIEWMODEL: Transitioned to selecting video state")
    }
    
    /// Complete trimming and proceed to naming
    public func completeTrimming(with trimmerViewModel: TrimmerViewModel) {
        finishTrimming(with: trimmerViewModel)
    }
    
    /// Finish trimming and proceed to naming
    public func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("🎬 VIEWMODEL: Finishing trimming")
        
        guard case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot finish trimming - not in trimming state")
            return
        }
        
        Task {
            do {
                let exportedURL = try await trimmerViewModel.exportVideo()
                let trimmedAsset = AVURLAsset(url: exportedURL)
                
                state = .naming(
                    photosIdentifier: photosIdentifier ?? "",
                    originalAsset: asset,
                    trimmedAsset: trimmedAsset,
                    trimStartTime: trimmerViewModel.startTime.seconds,
                    trimEndTime: trimmerViewModel.endTime.seconds,
                    rotationQuarterTurns: trimmerViewModel.rotationQuarterTurns
                )
            } catch {
                logger.error("🎬 VIEWMODEL: Trimming failed: \(error.localizedDescription)")
                state = .error(message: "Failed to trim video", underlyingError: error.localizedDescription)
            }
        }
    }
    
    /// Start naming the move
    public func startNaming() {
        logger.info("🎬 VIEWMODEL: Starting naming")
        
        guard case .previewing(_, let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot start naming - not in previewing state")
            return
        }
        
        state = .naming(
            photosIdentifier: photosIdentifier ?? "",
            originalAsset: asset,
            trimmedAsset: nil,
            trimStartTime: nil,
            trimEndTime: nil,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Set error state from external callback
    public func setErrorState(message: String, underlyingError: String? = nil) {
        state = .error(message: message, underlyingError: underlyingError)
    }
    
    /// Set trimming state with new rotation
    public func setTrimmingState(asset: AVAsset, rotationQuarterTurns: Int) {
        state = .trimming(asset: asset, photosIdentifier: nil, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    /// Save the move
    public func saveMove() {
        logger.info("🎬 VIEWMODEL: Saving move")
        
        guard case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot save - not in naming state")
            return
        }
        
        guard !moveName.isEmpty else {
            state = .error(message: "Please enter a name for your move", underlyingError: nil)
            return
        }
        
        state = .saving
        
        Task {
            do {
                // Use trimmed asset if available, otherwise use original
                guard let assetToSave = trimmedAsset ?? originalAsset else {
                    throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video asset available to save"])
                }
                
                // Save to Photos library (placeholder implementation)
                guard let urlAsset = assetToSave as? AVURLAsset else {
                    throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset is not a URL asset"])
                }
                
                // Create Move entity in Core Data
                let move = Move(context: viewContext)
                move.name = moveName
                move.videoURL = urlAsset.url
                move.photosIdentifier = photosIdentifier
                move.trimStartTime = trimStartTime ?? 0
                move.trimEndTime = trimEndTime ?? assetToSave.duration.seconds
                move.rotationQuarterTurns = Int16(rotationQuarterTurns)
                move.createdAt = Date()
                
                try viewContext.save()
                
                await MainActor.run {
                    moveName = ""
                    state = .success(message: "Move saved successfully!")
                    logger.info("🎬 VIEWMODEL: Move saved successfully")
                }
                
            } catch {
                logger.error("🎬 VIEWMODEL: Save failed: \(error.localizedDescription)")
                await MainActor.run {
                    state = .error(message: "Failed to save move", underlyingError: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadVideo(from item: PhotosPickerItem) async throws {
        logger.info("🎬 VIEWMODEL: Starting video loading")
        logger.info("🎬 VIEWMODEL: PhotosPickerItem - \(String(describing: item))")
        
        // Set loading state with initial progress
        await MainActor.run {
            state = .loading(progress: 0.1, status: "Preparing to load video...")
        }
        
        // Implement timeout mechanism
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000)) // 30 seconds
            throw NSError(domain: "AddMoveViewModel", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Video loading timed out after 30 seconds"])
        }
        
        loadingTask = Task {
            do {
                logger.info("🎬 VIEWMODEL: Loading video data from PhotosPicker")
                
                // Check Photos permissions first
                logger.info("🎬 VIEWMODEL: Updating to permission check state...")
                await MainActor.run {
                    state = .loading(progress: 0.2, status: "Checking permissions...")
                }
                logger.info("🎬 VIEWMODEL: Permission check state updated")
                
                let authorizationStatus = PHPhotoLibrary.authorizationStatus()
                if authorizationStatus != .authorized {
                    throw NSError(domain: "AddMoveViewModel", code: -1002, userInfo: [NSLocalizedDescriptionKey: "Photos permission not authorized"])
                }
                
                logger.info("🎬 VIEWMODEL: Photos permissions confirmed")
                
                // Load video using PhotosPicker - iOS 18.0 best practices
                logger.info("🎬 VIEWMODEL: Updating to loading data state...")
                await MainActor.run {
                    state = .loading(progress: 0.3, status: "Loading video data...")
                }
                logger.info("🎬 VIEWMODEL: Loading data state updated")
                
                // Ensure state transition is complete before proceeding
                logger.info("🎬 VIEWMODEL: About to load video file...")
                let startTime = Date()
                
                // Use timeout mechanism to prevent hanging
                logger.info("🎬 VIEWMODEL: Creating loading task...")
                let loadingTask = Task {
                    logger.info("🎬 VIEWMODEL: Loading task started, calling loadTransferable...")
                    // Use the correct iOS 18.0 approach - load as Data first for videos
                    // iOS 18.0 PhotosPicker has inconsistent URL access for videos
                    guard let videoData = try await item.loadTransferable(type: Data.self) else {
                        logger.error("🎬 VIEWMODEL: loadTransferable returned nil")
                        throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video data from PhotosPicker"])
                    }
                    logger.info("🎬 VIEWMODEL: Loading task completed successfully")
                    return videoData
                }
                logger.info("🎬 VIEWMODEL: Loading task created")
                
                let videoData: Data
                do {
                    logger.info("🎬 VIEWMODEL: Starting task group...")
                    videoData = try await withThrowingTaskGroup(of: Data.self) { group in
                        logger.info("🎬 VIEWMODEL: Adding loading task to group...")
                        group.addTask {
                            self.logger.info("🎬 VIEWMODEL: Loading task in group started...")
                            let result = try await loadingTask.value
                            self.logger.info("🎬 VIEWMODEL: Loading task in group completed")
                            return result
                        }
                        logger.info("🎬 VIEWMODEL: Adding timeout task to group...")
                        group.addTask {
                            self.logger.info("🎬 VIEWMODEL: Timeout task started...")
                            try await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000)) // 30 seconds
                            self.logger.info("🎬 VIEWMODEL: Timeout task completed, cancelling loading task...")
                            loadingTask.cancel()
                            throw NSError(domain: "AddMoveViewModel", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Video loading timed out after 30 seconds"])
                        }
                        logger.info("🎬 VIEWMODEL: Both tasks added, waiting for result...")
                        
                        for try await result in group {
                            logger.info("🎬 VIEWMODEL: Task group received result, cancelling others...")
                            group.cancelAll()
                            return result
                        }
                        
                        logger.error("🎬 VIEWMODEL: No task completed in group")
                        throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No task completed"])
                    }
                    logger.info("🎬 VIEWMODEL: Task group completed successfully")
                } catch {
                    logger.error("🎬 VIEWMODEL: Loading failed: \(error.localizedDescription)")
                    throw error
                }
                
                logger.info("🎬 VIEWMODEL: Video data loaded, size: \(videoData.count) bytes")
                
                // Create temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                do {
                    try videoData.write(to: tempURL)
                    logger.info("🎬 VIEWMODEL: Video data written to temp file: \(tempURL.path)")
                } catch {
                    logger.error("🎬 VIEWMODEL: Failed to write video data: \(error)")
                    throw error
                }
                
                let loadTime = Date().timeIntervalSince(startTime)
                logger.info("🎬 VIEWMODEL: Video file loaded: \(tempURL.path), took \(String(format: "%.2f", loadTime))s")
                
                await MainActor.run {
                    state = .loading(progress: 0.7, status: "Analyzing video format...")
                }
                
                let asset = AVURLAsset(url: tempURL)
                
                // Validate video asset - iOS 18.0 best practices
                let isPlayable = asset.isPlayable
                logger.info("🎬 VIEWMODEL: Video asset isPlayable: \(isPlayable)")
                
                if !isPlayable {
                    throw NSError(domain: "AddMoveViewModel", code: -1003, userInfo: [NSLocalizedDescriptionKey: "Video format is not supported or playable"])
                }
                
                // Load tracks with media characteristic for validation
                let videoTracks = try await asset.loadTracks(withMediaCharacteristic: .visual)
                if videoTracks.isEmpty {
                    throw NSError(domain: "AddMoveViewModel", code: -1004, userInfo: [NSLocalizedDescriptionKey: "No video tracks found in asset"])
                }
                
                let duration = try await asset.load(.duration).seconds
                logger.info("🎬 VIEWMODEL: Video duration: \(String(format: "%.2f", duration)) seconds")
                
                // Validate duration
                if duration <= 0 {
                    throw NSError(domain: "AddMoveViewModel", code: -1005, userInfo: [NSLocalizedDescriptionKey: "Video has invalid duration"])
                }
                
                // Validate file size
                let fileSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
                logger.info("🎬 VIEWMODEL: Video file size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    throw NSError(domain: "AddMoveViewModel", code: -1006, userInfo: [NSLocalizedDescriptionKey: "Video file is empty"])
                }
                
                guard Task.isCancelled == false else {
                    logger.info("🎬 VIEWMODEL: Task cancelled before creating player")
                    return
                }
                
                await MainActor.run {
                    state = .loading(progress: 0.8, status: "Preparing video player...")
                }
                
                logger.info("🎬 VIEWMODEL: Creating video player view model")
                
                // Create player view model
                let playerViewModel = MainVideoPlayerViewModel(
                    asset: asset,
                    rotationQuarterTurns: 0,
                    appContainer: AppContainer.shared
                )
                
                await MainActor.run {
                    state = .loading(progress: 0.9, status: "Initializing player...")
                }
                
                // Wait for player to be ready using proper async method with timeout
                logger.info("🎬 VIEWMODEL: Waiting for player to be ready")
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            try await playerViewModel.waitForReady()
                        }
                        group.addTask {
                            try await timeoutTask.value
                        }
                        
                        for try await _ in group {
                            // First result wins, cancel the other task
                            group.cancelAll()
                            return
                        }
                    }
                } catch {
                    logger.error("🎬 VIEWMODEL: Player readiness failed: \(error.localizedDescription)")
                    throw error
                }
                
                logger.info("🎬 VIEWMODEL: Player is ready, transitioning to preview state")
                
                await MainActor.run {
                    currentPhotosIdentifier = "temp-\(UUID().uuidString)"
                    currentVideoPlayerViewModel = playerViewModel
                    
                    state = .previewing(
                        playerViewModel: playerViewModel,
                        asset: asset,
                        photosIdentifier: currentPhotosIdentifier,
                        rotationQuarterTurns: 0
                    )
                    
                    logger.info("🎬 VIEWMODEL: Video loaded successfully")
                }
                
            } catch {
                if Task.isCancelled {
                    logger.info("🎬 VIEWMODEL: Video loading cancelled")
                    return
                }
                logger.error("🎬 VIEWMODEL: Video loading error: \(error.localizedDescription)")
                logger.error("🎬 VIEWMODEL: Error details: \(error)")
                
                await MainActor.run {
                    state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
                }
            }
        }
        
        // Wait for loading task to complete or timeout
        if let loadingTask = loadingTask {
            do {
                _ = try await loadingTask.value
            } catch {
                logger.error("🎬 VIEWMODEL: Loading task failed: \(error.localizedDescription)")
                await MainActor.run {
                    state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
                }
            }
        }
    }
    
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
}