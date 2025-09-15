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
    init(viewContext: NSManagedObjectContext, loadingService: VideoLoadingService = LiveVideoLoadingService()) {
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
        videoLoadingTask?.cancel()
        videoLoadingTask = nil
        state = .ready
        selectedItem = nil
        moveName = ""
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
        logger.info("🎬 VIEWMODEL: Handling direct video selection")
        
        // Set the selected item and start loading immediately
        selectedItem = item
        
        // Let loadVideo handle the initial loading state to avoid double state changes
        do {
            try await loadVideo(from: item)
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
            } catch {
                logger.error("🎬 VIEWMODEL: Video loading failed: \(error.localizedDescription)")
                state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }
        }
    }
    
    /// Starts the naming process from previewing state
    public func startNaming() {
        logger.info("🎬 VIEWMODEL: Starting naming")
        
        guard case .previewing(let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
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
    
    /// Cancel trimming and return to previewing state
    public func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: Canceling trimming")
        
        guard case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot cancel trimming - not in trimming state")
            return
        }
        
        // Return to previewing state
        state = .previewing(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    /// Go back to trimming from naming state
    public func backToTrimming() {
        logger.info("🎬 VIEWMODEL: Going back to trimming")
        
        guard case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = state else {
            logger.error("🎬 VIEWMODEL: Cannot go back to trimming - not in naming state")
            return
        }
        
        guard let asset = originalAsset ?? trimmedAsset else {
            logger.error("🎬 VIEWMODEL: Cannot go back to trimming - no asset available")
            return
        }
        
        // Return to trimming state with available asset
        state = .trimming(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
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
            let progress = event.fraction
            let status = event.status
            let stage = event.stage
            
            // Map progress to overall loading progress
            let overallProgress: Double
            switch stage {
            case .downloadingFromICloud:
                overallProgress = progress * 0.7 // 0-70%
            case .loadingAssetProperties:
                overallProgress = 0.7 + (progress * 0.2) // 70-90%
            case .preparingPlayerItem:
                overallProgress = 0.9 + (progress * 0.05) // 90-95%
            case .monitoringReadiness:
                overallProgress = 0.95 + (progress * 0.05) // 95-100%
            case .completed:
                overallProgress = 1.0
                finalAsset = event.asset
            }
            
            await updateProgress(to: overallProgress, status: status)
            
            logger.info("🎬 VIEWMODEL: 📊 Progress: \(Int(overallProgress * 100))% - \(status)")
        }
        
        // Create final player item
        guard let asset = finalAsset else {
            throw NSError(domain: "AddMoveViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"])
        }
        
        await updateProgress(to: 1.0, status: "🎉 Ready to trim your video!")
        
        // --- Completion ---
        let rotation = await asset.rotation()
        logger.info("🎬 VIEWMODEL: ✅ Real-time loading complete. Transitioning to trimming.")
        
        state = .trimming(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotation)
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
    
    public func startTrimming(rotationQuarterTurns: Int = 0) {
        logger.info("🎬 VIEWMODEL: Starting trimming")
        guard case .previewing(let asset, let photosIdentifier, _) = state else {
            logger.error("🎬 VIEWMODEL: Cannot start trimming - not in previewing state")
            return
        }
        state = .trimming(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    public func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("🎬 VIEWMODEL: Finishing trimming")
        guard case .trimming(let asset, let photosIdentifier, _) = state else {
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
                guard let assetToSave = trimmedAsset ?? originalAsset, let urlAsset = assetToSave as? AVURLAsset else {
                    throw NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid video asset to save."])
                }
                
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
}
