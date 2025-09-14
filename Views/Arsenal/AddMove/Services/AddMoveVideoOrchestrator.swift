import SwiftUI
import PhotosUI
import AVKit
import OSLog
import Photos

// MARK: - AddMove Video Orchestrator
// Single Responsibility: Handle all video loading, import, and preparation operations
@MainActor
public class AddMoveVideoOrchestrator: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isLoadingVideo = false
    @Published public private(set) var loadingProgress: Double = 0.0
    @Published public private(set) var currentAsset: AVAsset?
    @Published public private(set) var currentPhotosIdentifier: String?
    @Published public private(set) var selectedFilename: String?
    
    // MARK: - Import State
    @Published public var importState: SelectionState = .idle
    
    // MARK: - Services
    private let photosImportService: PhotosImportServiceProtocol
    private let videoAssetPreparer: VideoAssetPreparerProtocol
    private let videoLoader = AddMoveVideoLoader()
    private let logger: AppLogger
    
    // MARK: - Private State
    private var loadingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(
        photosImportService: PhotosImportServiceProtocol,
        videoAssetPreparer: VideoAssetPreparerProtocol,
        logger: AppLogger
    ) {
        self.photosImportService = photosImportService
        self.videoAssetPreparer = videoAssetPreparer
        self.logger = logger
        
        // Sync importState with photosImportService if it's a concrete type
        if let concreteService = photosImportService as? PhotosImportService {
            importState = concreteService.importState
        }
    }
    
    // MARK: - Public API
    
    /// Load and prepare video from PhotosPicker item
    public func loadAndPrepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult {
        logger.info("🎬 ORCHESTRATOR: Starting video load and preparation", metadata: nil)
        
        isLoadingVideo = true
        loadingProgress = 0.0
        
        defer {
            isLoadingVideo = false
            loadingProgress = 1.0
        }
        
        do {
            // Step 1: Import video using PhotosImportService
            loadingProgress = 0.2
            logger.info("🎬 ORCHESTRATOR: Importing video from PhotosPicker", metadata: nil)
            
            // Sync importState if we have access to the concrete service
            if let concreteService = photosImportService as? PhotosImportService {
                importState = concreteService.importState
            }
            
            let importResult = try await photosImportService.importVideo(from: item)
            
            // Update importState after import completes
            if let concreteService = photosImportService as? PhotosImportService {
                importState = concreteService.importState
            }
            
            // Step 2: Load video asset using VideoLoader
            loadingProgress = 0.4
            logger.info("🎬 ORCHESTRATOR: Loading video asset", metadata: nil)
            let loaderResult = try await videoLoader.loadVideo(from: item)
            
            // Step 3: Prepare asset for display
            loadingProgress = 0.6
            logger.info("🎬 ORCHESTRATOR: Preparing asset for display", metadata: nil)
            let preparationResult = try await videoAssetPreparer.prepareAssetForDisplay(
                asset: loaderResult.asset,
                photosIdentifier: loaderResult.photosIdentifier
            )
            
            // Step 4: Update state
            await MainActor.run {
                self.currentAsset = preparationResult.asset
                self.currentPhotosIdentifier = loaderResult.photosIdentifier
                self.selectedFilename = loaderResult.filename
                self.loadingProgress = 1.0
            }
            
            logger.info("🎬 ORCHESTRATOR: Video preparation completed successfully", metadata: nil)
            
            return PreparedVideoResult(
                asset: preparationResult.asset,
                photosIdentifier: loaderResult.photosIdentifier,
                filename: loaderResult.filename,
                playerViewModel: preparationResult.playerViewModel
            )
            
        } catch {
            logger.error("🎬 ORCHESTRATOR: ❌ Video preparation failed: \(error.localizedDescription)", metadata: nil)
            
            await MainActor.run {
                self.currentAsset = nil
                self.currentPhotosIdentifier = nil
                self.selectedFilename = nil
                self.loadingProgress = 0.0
            }
            
            throw error
        }
    }
    
    /// Prepare video asset for display with specific rotation
    public func prepareAssetWithRotation(
        asset: AVAsset,
        photosIdentifier: String,
        rotationQuarterTurns: Int
    ) async throws -> PreparedVideoResult {
        logger.info("🎬 ORCHESTRATOR: Preparing asset with rotation: \(rotationQuarterTurns)°", metadata: nil)
        
        let preparationResult = try await videoAssetPreparer.prepareAssetForDisplay(
            asset: asset,
            photosIdentifier: photosIdentifier
        )
        
        await MainActor.run {
            self.currentAsset = preparationResult.asset
            self.currentPhotosIdentifier = photosIdentifier
        }
        
        return PreparedVideoResult(
            asset: preparationResult.asset,
            photosIdentifier: photosIdentifier,
            filename: selectedFilename ?? "Video",
            playerViewModel: preparationResult.playerViewModel
        )
    }
    
    /// Cancel current video loading operation
    public func cancelLoading() {
        logger.info("🎬 ORCHESTRATOR: Cancelling video loading", metadata: nil)
        loadingTask?.cancel()
        loadingTask = nil
        
        Task {
            await MainActor.run {
                self.isLoadingVideo = false
                self.loadingProgress = 0.0
            }
        }
    }
    
    /// Reset orchestrator state
    public func reset() {
        logger.info("🎬 ORCHESTRATOR: Resetting state", metadata: nil)
        
        Task {
            await MainActor.run {
                self.isLoadingVideo = false
                self.loadingProgress = 0.0
                self.currentAsset = nil
                self.currentPhotosIdentifier = nil
                self.selectedFilename = nil
            }
        }
        
        loadingTask?.cancel()
        loadingTask = nil
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(_ progress: Double) {
        Task {
            await MainActor.run {
                self.loadingProgress = progress
            }
        }
    }
}

// MARK: - Video Orchestrator Protocol
@MainActor
public protocol AddMoveVideoOrchestratorProtocol: ObservableObject {
    var isLoadingVideo: Bool { get }
    var loadingProgress: Double { get }
    var currentAsset: AVAsset? { get }
    var currentPhotosIdentifier: String? { get }
    var selectedFilename: String? { get }
    var importState: SelectionState { get }
    
    func loadAndPrepareVideo(from item: PhotosPickerItem) async throws -> PreparedVideoResult
    func prepareAssetWithRotation(asset: AVAsset, photosIdentifier: String, rotationQuarterTurns: Int) async throws -> PreparedVideoResult
    func cancelLoading()
    func reset()
}

// MARK: - Conformance
extension AddMoveVideoOrchestrator: AddMoveVideoOrchestratorProtocol {}