import SwiftUI
import PhotosUI
import AVKit
import CoreData
import OSLog
import Foundation
import Combine
import AVFoundation
import Photos

// MARK: - Modern AddMove View Model
@Observable
@MainActor
public final class AddMoveViewModel {
    
    // MARK: - Observable Properties
    public private(set) var state: AddMoveState = .ready
    public var selectedItem: PhotosPickerItem? {
        didSet {
            guard selectedItem != nil else { return }
            // Immediately transition to loading state to provide instant feedback
            state = .loading(progress: 0.0, status: "Preparing to load video...")
            handleVideoSelection()
        }
    }
    public var moveName: String = ""
    public var importState: AddMoveImportState = .idle
    
    // MARK: - Private Properties
    private let viewContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveViewModel")
    private let loadingService: VideoLoadingService
    private var videoLoadingTask: Task<Void, Error>?
    private var currentVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    
    // MARK: - Video Player Access
    var preparedVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)? {
        didSet {
            logger.info("🎬 VIEWMODEL: preparedVideoPlayerViewModel changed to \(self.preparedVideoPlayerViewModel != nil)")
        }
    }
    
    private func updatePreparedVideoPlayerViewModel() {
        self.preparedVideoPlayerViewModel = {
            guard let viewModel = self.currentVideoPlayerViewModel,
                  viewModel.isPlayerReady else {
                return nil
            }
            return viewModel
        }()
    }
    
    // MARK: - Initialization
    init(viewContext: NSManagedObjectContext, loadingService: VideoLoadingService = LiveVideoLoadingService(memoryManager: AppContainer.shared.memoryManager, logger: AppContainer.shared.logger)) {
        self.viewContext = viewContext
        self.loadingService = loadingService
        logger.info("🎬 VIEWMODEL: Initialized")
    }
    
    // MARK: - Factory Method
    public static func create(viewContext: NSManagedObjectContext) -> AddMoveViewModel {
        return AddMoveViewModel(viewContext: viewContext)
    }
    
    // MARK: - Public API
    
    /// Resets the view model to its initial state.
    public func reset() {
        logger.info("🎬 VIEWMODEL: Resetting state.")
        
        // Cleanup video resources first to prevent memory leaks
        cleanupVideoResources()
        
        videoLoadingTask?.cancel()
        videoLoadingTask = nil
        state = .ready
        selectedItem = nil
        moveName = ""
        
        logger.info("🎬 VIEWMODEL: Reset completed - ready for new video selection")
    }
    
    /// Cancels the ongoing video loading process.
    public func cancelLoading() {
        logger.info("🎬 VIEWMODEL: Cancelling video loading.")
        videoLoadingTask?.cancel()
        state = .ready // Or some other appropriate state
    }
    
    // MARK: - Public API for Pre-Trim View
    
    /// Handles direct video selection from PhotosPicker
    public func handleDirectVideoSelection(_ item: PhotosPickerItem) async {
        logger.info("🎬 VIEWMODEL: Handling direct video selection for Change button")
        
        // Clean up current video player before loading new one
        logger.info("🎬 VIEWMODEL: Cleaning up current video player before change")
        cleanupVideoResources()
        
        // Set the selected item and start loading immediately
        selectedItem = item
        
        // Let loadVideo handle the initial loading state to avoid double state changes
        do {
            try await loadVideo(from: item)
        } catch let error as NSError where error.domain == "VideoLoadingService" && error.code == -100 {
            logger.error("⏰ VIEWMODEL: Direct video loading timed out")
            state = .error(
                message: "Download from iCloud timed out",
                underlyingError: "Please check your network connection and try again."
            )
        } catch {
            logger.error("🎬 VIEWMODEL: Direct video loading failed: \(error.localizedDescription)")
            state = .error(message: "Direct video loading failed", underlyingError: error.localizedDescription)
        }
    }
    
    /// Handles the selection of a video from the Photos picker.
    public func handleVideoSelection() {
        guard let item = selectedItem else {
            logger.warning("🎬 VIEWMODEL: handleVideoSelection called with no selected item.")
            return
        }
        
        // Cancel any previous loading task.
        videoLoadingTask?.cancel()
        
        videoLoadingTask = Task {
            do {
                try await loadVideo(from: item)
            } catch is CancellationError {
                logger.info("🎬 VIEWMODEL: Video loading task was cancelled.")
                // Do nothing, as the cancellation was intentional.
            } catch let error as NSError where error.domain == "VideoLoadingService" && error.code == -100 {
                logger.error("⏰ VIEWMODEL: Video loading timed out")
                state = .error(
                    message: "Download from iCloud timed out",
                    underlyingError: "Please check your network connection and try again."
                )
            } catch {
                logger.error("🎬 VIEWMODEL: Video loading failed: \(error.localizedDescription)")
                state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }
        }
    }
    
    /// Starts the naming process from previewing state
    public func startNaming() async {
        logger.info("🎬 VIEWMODEL: Starting naming")
        
        guard case .previewing(_, let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot start naming - not in previewing state")
            return
        }
        
        state = .naming(
            photosIdentifier: photosIdentifier ?? "",
            originalAsset: asset,
            trimStartTime: 0,
            trimEndTime: (try? await asset.load(.duration).seconds) ?? asset.duration.seconds,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Set error state from external callback
    public func setErrorState(message: String, underlyingError: String? = nil) {
        state = .error(message: message, underlyingError: underlyingError)
    }
    
    /// Update trimming state with new rotation (reuses existing playerViewModel)
    public func updateTrimmingRotation(rotationQuarterTurns: Int) {
        logger.info("🎬 VIEWMODEL: Updating trimming rotation to \(rotationQuarterTurns)")
        
        guard case .trimming(let playerViewModel, let asset, let photosIdentifier, _) = state else {
            logger.error("🎬 VIEWMODEL: Cannot update rotation - not in trimming state")
            return
        }
        
        state = .trimming(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Set trimming state with new rotation
    public func setTrimmingState(asset: AVAsset, rotationQuarterTurns: Int) {
        // Note: This method doesn't have access to the playerViewModel, so it creates a new one
        // This should be updated or used with caution
        logger.warning("🎬 VIEWMODEL: setTrimmingState called without playerViewModel - this may cause issues")
        
        // Apply the same fix as loadVideo - create player immediately to avoid deadlock
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: AppContainer.shared
        )
        state = .trimming(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: nil,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Cancel trimming and return to previewing state
    public func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: Canceling trimming")

        guard case .trimming(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot cancel trimming - not in trimming state")
            return
        }
        
        // Return to the previewing state, REUSING the same playerViewModel.
        state = .previewing(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    /// Go back to trimming from naming state
    public func backToTrimming() {
        logger.info("🎬 VIEWMODEL: Going back to trimming")
        
        guard case .naming(let photosIdentifier, let originalAsset, _, _, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot go back to trimming - not in naming state")
            return
        }
        
        // Create new playerViewModel for returning to trimming (using the fixed pattern)
        let playerItem = AVPlayerItem(asset: originalAsset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: AppContainer.shared
        )
        
        // Return to trimming state with original asset and new playerViewModel
        state = .trimming(
            playerViewModel: playerViewModel,
            asset: originalAsset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    // MARK: - Resource Cleanup
    
    /// Cleans up video player resources to prevent memory leaks and state conflicts
    private func cleanupVideoResources() {
        logger.info("🎬 CLEANUP: Starting video resource cleanup")
        
        // Safely cleanup video player if it exists
        if let playerViewModel = currentVideoPlayerViewModel {
            logger.info("🎬 CLEANUP: Tearing down video player")
            playerViewModel.teardown()
            currentVideoPlayerViewModel = nil
        }
        
        // Clear prepared video player reference
        preparedVideoPlayerViewModel = nil
        
        logger.info("🎬 CLEANUP: Video resources cleanup completed")
    }
    
    // MARK: - Video Loading - Single Source of Truth
    
    /// The single, unified, real-time video loading pipeline.
    private func loadVideo(from item: PhotosPickerItem) async throws {
        logger.info("🎬 VIEWMODEL: Starting real-time video loading.")
        guard let photosIdentifier = item.itemIdentifier else {
            throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No photos identifier"])
        }
        
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photosIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw NSError(domain: "AddMoveViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }
        
        // Use VideoLoadingService directly with real progress tracking
        let progressStream = loadingService.loadPHAssetWithProgress(phAsset)
        
        var finalAsset: AVAsset?
        
        // Consume real progress updates
        for try await event in progressStream {
            switch event {
            case .progress(let fraction, let status):
                // The progress is already properly scaled by the VideoLoadingService
                await updateProgress(to: fraction, status: status)
                logger.info("🎬 VIEWMODEL: 📊 Progress: \(Int(fraction * 100))% - \(status)")
                
            case .success(let asset):
                finalAsset = asset
                // Ensure we show 100% completion
                await updateProgress(to: 1.0, status: "🎉 Ready to trim your video!")
                logger.info("🎬 VIEWMODEL: 📊 Progress: 100% - 🎉 Ready to trim your video!")
            }
        }
        
        // --- Completion ---
        guard let asset = finalAsset else {
            throw NSError(domain: "AddMoveViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"])
        }
        
        // 1. Create the player item from the loaded asset
        logger.info("🎬 VIEWMODEL: Creating player item from loaded asset...")
        let playerItem = AVPlayerItem(asset: asset)

        // 2. FIX: Create the AVPlayer IMMEDIATELY to kick off the item's readiness process.
        let player = AVPlayer(playerItem: playerItem)
        
        // 3. NOW, await the readiness of the player item.
        logger.info("🎬 VIEWMODEL: Waiting for player item to become ready...")
        try await waitForPlayerItemReady(playerItem)
          
        // 4. Verify the player item is ready.
        guard playerItem.status == .readyToPlay else {
            logger.error("🎬 VIEWMODEL: 🚨 PlayerItem failed to become ready. Status: \(playerItem.status.rawValue), Error: \(String(describing: playerItem.error))")
            throw playerItem.error ?? NSError(domain: "AddMoveViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "AVPlayerItem failed to load."])
        }
        
        logger.info("🎬 VIEWMODEL: ✅ Player item is ready! Status: \(playerItem.status.rawValue)")
        
        // 5. The player is already created with the now-ready item. Create the ViewModel.
        let playerViewModel = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .preview,
            appContainer: AppContainer.shared
        )
        
        // 6. Get rotation and transition to the previewing state
        let rotation = await asset.rotation()
        logger.info("🎬 VIEWMODEL: ✅ Video loaded and player item is ready. Transitioning to previewing.")
        
        state = .previewing(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotation
        )
    }
    
    // MARK: - Player Readiness Helpers
    
    
    // MARK: - Progress Updates
    
    /// Updates the loading progress and status message.
    private func updateProgress(to progress: Double, status: String) async {
        // Ensure progress is between 0.0 and 1.0
        let clampedProgress = max(0.0, min(1.0, progress))
        state = .loading(progress: clampedProgress, status: status)
        logger.info("🎬 VIEWMODEL: 📊 Progress: \(Int(clampedProgress * 100))% - \(status)")
    }
    
    // MARK: - Other Public Methods (Trimming, Naming, Saving, etc.)
    // These methods are preserved from the original file but may need review
    // to ensure they work correctly with the new state flow.
    
    public func startTrimming() {
        logger.info("🎬 VIEWMODEL: Starting trimming")
        
        // 1. Get the current state, which now includes the ready playerViewModel.
        guard case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot start trimming - not in previewing state")
            return
        }
        
        // 2. Pass the EXISTING playerViewModel to the .trimming state to avoid re-initialization.
        state = .trimming(
            playerViewModel: playerViewModel,
            asset: asset,
            photosIdentifier: photosIdentifier,
            rotationQuarterTurns: rotationQuarterTurns
        )
    }
    
    public func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("🎬 VIEWMODEL: Finishing trimming - passing data to naming state.")
        
        guard case .trimming(_, let originalAsset, let photosIdentifier, _) = state else {
            logger.error("🎬 VIEWMODEL: Cannot finish trimming - not in trimming state")
            return
        }
        
        // Add diagnostic logging to track rotation transfer
        let finalRotation = trimmerViewModel.rotationQuarterTurns
        logger.info("🎬 VIEWMODEL: Rotation transfer diagnostics:")
        logger.info("🎬 VIEWMODEL: - TrimmerViewModel rotationQuarterTurns: \(finalRotation)")
        logger.info("🎬 VIEWMODEL: - Rotation in degrees: \(finalRotation * 90)°")
        
        // This is now a PURE data transition. No expensive export is performed.
        // We pass the ORIGINAL asset along with the NEW trim and rotation data.
        state = .naming(
            photosIdentifier: photosIdentifier ?? "",
            originalAsset: originalAsset,
            trimStartTime: trimmerViewModel.startTime.seconds,
            trimEndTime: trimmerViewModel.endTime.seconds,
            rotationQuarterTurns: finalRotation
        )
        
        logger.info("🎬 VIEWMODEL: ✅ State transition completed to naming with rotation: \(finalRotation * 90)°")
    }
    
    public func saveMove() {
        logger.info("🎬 VIEWMODEL: Saving move")
        guard case .naming(_, let originalAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = state else {
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
                logger.info("🎬 VIEWMODEL: Starting video export with rotation: \(rotationQuarterTurns) quarter turns")
                
                // Create output URL for exported video
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                // Create time range from trim data
                let timeRange = CMTimeRange(
                    start: CMTime(seconds: trimStartTime, preferredTimescale: 600),
                    duration: CMTime(seconds: trimEndTime - trimStartTime, preferredTimescale: 600)
                )
                
                logger.info("🎬 VIEWMODEL: Export parameters - trimRange: \(timeRange.start.seconds)-\(timeRange.end.seconds), rotation: \(rotationQuarterTurns)")
                
                // Export video with PROPER rotation applied using existing infrastructure
                let exportedURL = try await VideoTransformBuilder.exportVideo(
                    asset: originalAsset,
                    trimRange: timeRange,
                    quarterTurns: rotationQuarterTurns,
                    outputURL: outputURL
                )
                
                logger.info("🎬 VIEWMODEL: Video export completed successfully")
                
                // Save to BreakDex album
                logger.info("🎬 VIEWMODEL: Saving to BreakDex album")
                let newPhotosIdentifier = try await BreakDexAlbumManager.shared.saveVideoToBreakDexAlbum(exportedURL)
                
                logger.info("🎬 VIEWMODEL: Video saved to BreakDex album with identifier: \(newPhotosIdentifier)")
                
                // Update Core Data with properly processed video
                let move = Move(context: viewContext)
                move.name = moveName
                move.videoURL = exportedURL // Use the processed video URL
                move.photosIdentifier = newPhotosIdentifier // Update with new photos identifier
                move.trimStartTime = trimStartTime
                move.trimEndTime = trimEndTime
                move.rotationQuarterTurns = Int16(rotationQuarterTurns)
                move.createdAt = Date()
                
                try viewContext.save()
                
                logger.info("🎬 VIEWMODEL: Core Data updated successfully")
                
                await MainActor.run {
                    state = .success(message: "Move saved successfully to BreakDex album!")
                    logger.info("🎬 VIEWMODEL: Move saved successfully with proper rotation and album integration")
                }
            } catch {
                logger.error("🎬 VIEWMODEL: Save failed: \(error.localizedDescription)")
                await MainActor.run {
                    state = .error(message: "Failed to save move", underlyingError: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Player Item Readiness Helpers
    
    /// Waits for a player item to become ready with comprehensive KVO observation
    private func waitForPlayerItemReady(_ playerItem: AVPlayerItem) async throws {
        
        // Check if already ready to avoid race condition
        if playerItem.status == .readyToPlay {
            logger.info("🎬 VIEWMODEL: ✅ Player item was already ready.")
            return
        }
        if playerItem.status == .failed {
            logger.error("🎬 VIEWMODEL: 🚨 Player item had already failed.")
            throw playerItem.error ?? NSError(domain: "AddMoveViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "AVPlayerItem failed to load."])
        }
        
        logger.info("🎬 VIEWMODEL: 🔄 Starting robust player item readiness monitoring...")
        
        // Use the existing PlayerItemStatusMonitor which is proven to work
        let monitor = PlayerItemStatusMonitor(playerItem: playerItem)
        
        try await monitor.awaitReadyAndBuffered(timeout: 60.0) { progress in
            // Log progress at key milestones
            let progressPercent = Int(progress * 100)
            self.logger.info("🎬 VIEWMODEL: 📈 Buffer progress: \(progressPercent)%")
        }
        
        logger.info("🎬 VIEWMODEL: ✅ Player item readiness monitoring completed successfully!")
    }
}
