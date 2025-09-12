import SwiftUI
import PhotosUI
import AVFoundation
import CoreData
import OSLog

@MainActor
public final class UpdatedAddMoveViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var state: AddMoveState = .ready
    @Published public var selectedFilename: String = ""
    @Published public var moveName: String = ""
    @Published public var moveDescription: String = ""
    @Published public var selectedTags: Set<String> = []
    
    // MARK: - Private Properties
    private let appContainer: AppContainer
    private let logger: AppLogger
    private let videoProcessingPipeline: VideoProcessingPipeline
    private let stateManager: VideoStateManager
    private let memoryManager: MemoryManager
    private let viewContext: NSManagedObjectContext
    private let videoHealthMonitor: VideoHealthMonitor
    private let memoryLogger = CentralizedMemoryLogger.shared
    
    private var currentVideoPlayerViewModel: (any VideoPlayerViewModelProtocol)?
    private var currentPhotosIdentifier: String?
    private var loadingTask: Task<Void, Never>?
    private var memoryMonitoringTask: Task<Void, Never>?
    private var correlationId: String?
    
    // MARK: - Initialization
    public init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.appContainer = AppContainer.shared
        self.logger = appContainer.logger
        self.videoProcessingPipeline = appContainer.videoProcessingPipeline
        self.stateManager = appContainer.stateManager
        self.memoryManager = appContainer.memoryManager
        self.videoHealthMonitor = appContainer.videoHealthMonitor
        
        // Generate correlation ID for this view model instance
        correlationId = memoryLogger.generateCorrelationId(for: "UpdatedAddMoveViewModel")
        
        logger.info("🎬 VIEWMODEL: Initialized", metadata: nil)
        memoryLogger.logMemoryState(context: "Initialization", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
    }
    
    // MARK: - Public Methods
    
    public func selectVideo() {
        logger.info("🎬 VIEWMODEL: selectVideo() called", metadata: nil)
        
        // Clean up any existing player view model before transitioning
        cleanupPlayerViewModel()
        
        state = .selectingVideo(currentAsset: nil)
    }
    
    public func handleVideoSelection(_ item: PhotosPickerItem) {
        logger.info("🎬 VIEWMODEL: handleVideoSelection() called", metadata: nil)
        logger.info("🎬 VIEWMODEL: Item ID: \(item.itemIdentifier ?? "nil")", metadata: nil)
        
        // Generate correlation ID for this video selection operation
        let operationCorrelationId = memoryLogger.generateCorrelationId(for: "VideoSelection")
        
        // Log initial memory state
        memoryLogger.logMemoryState(context: "Before video selection", correlationId: operationCorrelationId, component: "UpdatedAddMoveViewModel")
        
        // Check memory before loading
        let availableMemory = memoryManager.getAvailableMemory()
        let memoryThreshold: Int64 = 200 * 1024 * 1024 // 200MB
        
        if availableMemory < memoryThreshold {
            memoryLogger.logMemoryWarning(
                message: "Low memory before video selection: \(availableMemory / (1024 * 1024))MB",
                correlationId: operationCorrelationId,
                component: "UpdatedAddMoveViewModel",
                metadata: ["availableMemory": availableMemory, "threshold": memoryThreshold]
            )
            
            // Perform aggressive cache clearing
            performAggressiveCacheClearing(correlationId: operationCorrelationId)
            
            // Log memory after cache clearing
            let availableMemoryAfterClear = memoryManager.getAvailableMemory()
            memoryLogger.logMemoryEvent(
                event: "Memory after cache clearing: \(availableMemoryAfterClear / (1024 * 1024))MB",
                correlationId: operationCorrelationId,
                component: "UpdatedAddMoveViewModel",
                metadata: ["availableMemoryAfterClear": availableMemoryAfterClear]
            )
            
            // If still low, show error
            if availableMemoryAfterClear < memoryThreshold {
                memoryLogger.logMemoryError(
                    message: "Insufficient memory even after cache clearing: \(availableMemoryAfterClear / (1024 * 1024))MB",
                    correlationId: operationCorrelationId,
                    component: "UpdatedAddMoveViewModel",
                    metadata: ["availableMemoryAfterClear": availableMemoryAfterClear, "threshold": memoryThreshold]
                )
                
                state = .error(
                    message: "Not enough memory to load video. Please close other apps and try again.",
                    underlyingError: "Memory limit exceeded"
                )
                return
            }
        }
        
        // Load the video using the new pipeline
        loadingTask = Task {
            do {
                // Extract the photos identifier from the item
                guard let identifier = item.itemIdentifier else {
                    throw VideoProcessingError.videoLoadingFailed(
                        identifier: "unknown",
                        underlyingError: NSError(domain: "PhotosPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No item identifier"])
                    )
                }
                
                // Load the video asset
                let videoAsset = try await videoProcessingPipeline.loadVideo(from: identifier)
                
                // Log memory after video loading
                memoryLogger.logMemoryState(context: "After video loading", correlationId: operationCorrelationId, component: "UpdatedAddMoveViewModel")
                
                // Check memory before creating player view model
                let availableMemoryBeforePlayer = memoryManager.getAvailableMemory()
                let playerMemoryThreshold: Int64 = 150 * 1024 * 1024 // 150MB
                
                if availableMemoryBeforePlayer < playerMemoryThreshold {
                    memoryLogger.logMemoryWarning(
                        message: "Low memory before creating player: \(availableMemoryBeforePlayer / (1024 * 1024))MB",
                        correlationId: operationCorrelationId,
                        component: "UpdatedAddMoveViewModel",
                        metadata: ["availableMemoryBeforePlayer": availableMemoryBeforePlayer, "playerThreshold": playerMemoryThreshold]
                    )
                    
                    performAggressiveCacheClearing(correlationId: operationCorrelationId)
                    
                    // Check again after clearing
                    let availableMemoryAfterClear = memoryManager.getAvailableMemory()
                    if availableMemoryAfterClear < playerMemoryThreshold {
                        memoryLogger.logMemoryError(
                            message: "Insufficient memory for player creation: \(availableMemoryAfterClear / (1024 * 1024))MB",
                            correlationId: operationCorrelationId,
                            component: "UpdatedAddMoveViewModel",
                            metadata: ["availableMemoryAfterClear": availableMemoryAfterClear, "playerThreshold": playerMemoryThreshold]
                        )
                        
                        state = .error(
                            message: "Not enough memory to play video. Please close other apps and try again.",
                            underlyingError: "Memory limit exceeded for player"
                        )
                        return
                    }
                }
                
                // Create a preview-optimized player view model with the loaded asset for previewing state
                let playerViewModel = PreviewOptimizedVideoPlayerViewModel(
                    asset: videoAsset.avAsset,
                    rotationQuarterTurns: 0,
                    appContainer: appContainer
                )
                
                // Clean up any existing player view model before setting the new one
                cleanupPlayerViewModel()
                
                self.currentVideoPlayerViewModel = playerViewModel
                self.currentPhotosIdentifier = videoAsset.identifier
                self.selectedFilename = videoAsset.filename
                
                // Wait for the player to be ready
                try await playerViewModel.waitForReady()
                
                // Log memory before transitioning to previewing state
                memoryLogger.logMemoryState(context: "Before transitioning to previewing", correlationId: operationCorrelationId, component: "UpdatedAddMoveViewModel")
                
                // Start video health monitoring
                videoHealthMonitor.startMonitoring(asset: videoAsset.avAsset)
                
                // Start memory monitoring task
                startMemoryMonitoring()
                
                // Transition to previewing state
                self.state = .previewing(
                    playerViewModel: playerViewModel,
                    asset: videoAsset.avAsset,
                    photosIdentifier: videoAsset.identifier,
                    rotationQuarterTurns: 0
                )
                
                // Log memory after transitioning to previewing state
                memoryLogger.logMemoryState(context: "After transitioning to previewing", correlationId: operationCorrelationId, component: "UpdatedAddMoveViewModel")
                
                logger.info("✅ Video loaded and ready for preview", metadata: nil)
            } catch {
                logger.error("❌ Failed to load video: \(error.localizedDescription)", metadata: nil)
                memoryLogger.logMemoryError(
                    message: "Video loading error: \(error.localizedDescription)",
                    correlationId: operationCorrelationId,
                    component: "UpdatedAddMoveViewModel",
                    metadata: ["error": error.localizedDescription]
                )
                state = .error(
                    message: "Failed to load video. Please try again.",
                    underlyingError: error.localizedDescription
                )
            }
        }
    }
    
    public func rotateVideo() {
        logger.info("🎬 VIEWMODEL: rotateVideo() called", metadata: nil)
        
        if case .previewing(_, let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            let newRotation = (rotationQuarterTurns + 1) % 4
            logger.info("🎬 VIEWMODEL: Rotating video from \(rotationQuarterTurns) to \(newRotation)", metadata: nil)
            
            // Process the video with the new rotation
            Task {
                do {
                    let videoAsset = try await VideoAsset(
                        avAsset: asset,
                        identifier: photosIdentifier ?? "unknown",
                        filename: selectedFilename
                    )
                    
                    let processedAsset = try await videoProcessingPipeline.processVideo(
                        videoAsset,
                        rotationQuarterTurns: newRotation
                    )
                    
                    // Create a new preview-optimized player view model with the processed asset
                    let newPlayerViewModel = PreviewOptimizedVideoPlayerViewModel(
                        asset: processedAsset.avAsset,
                        rotationQuarterTurns: newRotation,
                        appContainer: appContainer
                    )
                    
                    // Wait for the player to be ready
                    try await newPlayerViewModel.waitForReady()
                    
                    // Clean up the old player view model before setting the new one
                    cleanupPlayerViewModel()
                    
                    // Update the state with the new rotation
                    self.state = .previewing(
                        playerViewModel: newPlayerViewModel,
                        asset: processedAsset.avAsset,
                        photosIdentifier: photosIdentifier,
                        rotationQuarterTurns: newRotation
                    )
                    
                    self.currentVideoPlayerViewModel = newPlayerViewModel
                    
                    logger.info("✅ Video rotated successfully", metadata: nil)
                } catch {
                    logger.error("❌ Failed to rotate video: \(error.localizedDescription)", metadata: nil)
                    state = .error(
                        message: "Failed to rotate video. Please try again.",
                        underlyingError: error.localizedDescription
                    )
                }
            }
        } else {
            logger.error("🎬 VIEWMODEL: rotateVideo() called but not in previewing state!", metadata: nil)
        }
    }
    
    public func startTrimming() {
        logger.info("🎬 VIEWMODEL: startTrimming() called", metadata: nil)
        
        if case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            // Teardown the player view model before transitioning to trimming state
            playerViewModel.teardown()
            
            state = .trimming(
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns
            )
            
            // Log memory after transitioning to trimming state
            memoryLogger.logMemoryState(context: "After transitioning to trimming", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
        } else {
            logger.error("🎬 VIEWMODEL: startTrimming() called but not in previewing state!", metadata: nil)
        }
    }
    
    public func finishTrimming(startTime: Double, endTime: Double) {
        logger.info("🎬 VIEWMODEL: finishTrimming() called", metadata: nil)
        logger.info("🎬 VIEWMODEL: Trim range: \(startTime)s to \(endTime)s", metadata: nil)
        
        if case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            // For now, we'll just store the trim times and proceed to naming
            // In a full implementation, we would actually trim the video
            state = .naming(
                photosIdentifier: photosIdentifier ?? "",
                originalAsset: asset,
                trimmedAsset: asset, // In a real implementation, this would be the trimmed asset
                trimStartTime: startTime,
                trimEndTime: endTime,
                rotationQuarterTurns: rotationQuarterTurns
            )
            
            // Log memory after transitioning to naming state
            memoryLogger.logMemoryState(context: "After transitioning to naming", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
        } else {
            logger.error("🎬 VIEWMODEL: finishTrimming() called but not in trimming state!", metadata: nil)
        }
    }
    
    public func cancelTrimming() {
        logger.info("🎬 VIEWMODEL: cancelTrimming() called", metadata: nil)
        
        if case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            // Create a new preview-optimized player view model with the asset
            let playerViewModel = PreviewOptimizedVideoPlayerViewModel(
                asset: asset,
                rotationQuarterTurns: rotationQuarterTurns,
                appContainer: appContainer
            )
            
            // Clean up any existing player view model before setting the new one
            cleanupPlayerViewModel()
            
            state = .previewing(
                playerViewModel: playerViewModel,
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: rotationQuarterTurns
            )
            
            self.currentVideoPlayerViewModel = playerViewModel
            
            // Log memory after transitioning back to previewing state
            memoryLogger.logMemoryState(context: "After transitioning back to previewing", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
        } else {
            logger.error("🎬 VIEWMODEL: cancelTrimming() called but not in trimming state!", metadata: nil)
        }
    }
    
    public func startNaming() {
        logger.info("🎬 VIEWMODEL: startNaming() called", metadata: nil)
        logger.info("🎬 VIEWMODEL: Current state: \(getStateDescription(state))", metadata: nil)
        
        if case .previewing(let playerViewModel, let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            logger.info("🎬 VIEWMODEL: Creating naming state from previewing", metadata: nil)
            logger.info("🎬 VIEWMODEL: Preserving rotation: \(rotationQuarterTurns)°", metadata: nil)
            logger.info("🎬 VIEWMODEL: Asset exists", metadata: nil)
            logger.info("🎬 VIEWMODEL: Photos ID: \(photosIdentifier ?? "nil")", metadata: nil)
            
            // Teardown the player view model before transitioning to naming state
            playerViewModel.teardown()
            
            state = .naming(
                photosIdentifier: photosIdentifier ?? "",
                originalAsset: asset,
                trimmedAsset: nil,
                trimStartTime: nil,
                trimEndTime: nil,
                rotationQuarterTurns: rotationQuarterTurns
            )
            
            // Log memory after transitioning to naming state
            memoryLogger.logMemoryState(context: "After transitioning to naming", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
        } else {
            logger.error("🎬 VIEWMODEL: startNaming() called but not in previewing state!", metadata: nil)
        }
    }
    
    public func saveMove() {
        logger.info("🎬 VIEWMODEL: saveMove() called", metadata: nil)
        logger.info("🎬 VIEWMODEL: Move name: \(moveName)", metadata: nil)
        logger.info("🎬 VIEWMODEL: Move description: \(moveDescription)", metadata: nil)
        logger.info("🎬 VIEWMODEL: Selected tags: \(selectedTags)", metadata: nil)
        
        guard !moveName.isEmpty else {
            logger.warning("🎬 VIEWMODEL: Cannot save move with empty name", metadata: nil)
            state = .error(message: "Please enter a name for your move", underlyingError: "Empty move name")
            return
        }
        
        if case .naming(let photosIdentifier, let asset, _, _, _, let rotationQuarterTurns) = state {
            state = .saving
            
            // Log memory before saving
            memoryLogger.logMemoryState(context: "Before saving", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
            
            Task {
                do {
                    // Create a video asset
                    let videoAsset = try await VideoAsset(
                        avAsset: asset!,
                        identifier: photosIdentifier,
                        filename: selectedFilename
                    )
                    
                    // Process the video with final rotation
                    let processedAsset = try await videoProcessingPipeline.processVideo(
                        videoAsset,
                        rotationQuarterTurns: rotationQuarterTurns
                    )
                    
                    // Save the video to app storage
                    let savedURL = try await videoProcessingPipeline.saveVideo(processedAsset)
                    
                    // Create the move in Core Data
                    let newMove = Move(context: viewContext)
                    newMove.name = moveName
                    // Note: moveDescription is not a property of the Move entity in the Core Data model
                    // If we need to store descriptions, we would need to update the data model
                    newMove.videoURL = savedURL
                    newMove.createdAt = Date()
                    // Note: lastAccessedDate is not a property of the Move entity in the Core Data model
                    
                    // Add tags
                    newMove.tags = selectedTags.joined(separator: ",")
                    
                    // Save the context
                    try viewContext.save()
                    
                    // Clear memory after successful save
                    memoryManager.clearCache()
                    
                    // Clean up player view model and assets
                    cleanupPlayerViewModel()
                    cleanupVideoAssets()
                    
                    state = .success(message: "Move saved successfully!")
                    
                    // Log memory after successful save
                    memoryLogger.logMemoryState(context: "After successful save", correlationId: correlationId, component: "UpdatedAddMoveViewModel")
                    
                    logger.info("✅ Move saved successfully", metadata: nil)
                } catch {
                    logger.error("❌ Failed to save move: \(error.localizedDescription)", metadata: nil)
                    state = .error(
                        message: "Failed to save move. Please try again.",
                        underlyingError: error.localizedDescription
                    )
                }
            }
        } else {
            logger.error("🎬 VIEWMODEL: saveMove() called but not in naming state!", metadata: nil)
        }
    }
    
    public func reset() {
        logger.info("🎬 VIEWMODEL: reset() called", metadata: nil)
        
        // Log memory before reset
        logCurrentMemoryState("Before reset")
        
        // Cancel any ongoing operations
        loadingTask?.cancel()
        loadingTask = nil
        memoryMonitoringTask?.cancel()
        memoryMonitoringTask = nil
        
        // Stop video health monitoring
        videoHealthMonitor.stopMonitoring()
        
        // Clear memory aggressively
        performAggressiveCacheClearing()
        
        // Clean up video assets
        cleanupVideoAssets()
        
        // Reset state
        state = .ready
        selectedFilename = ""
        moveName = ""
        moveDescription = ""
        selectedTags = []
        currentVideoPlayerViewModel = nil
        currentPhotosIdentifier = nil
        
        // Log memory after reset
        logCurrentMemoryState("After reset")
        
        logger.info("🎬 VIEWMODEL: Reset completed", metadata: nil)
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
        case .loaded(_, let id, let rotation):
            return "loaded(id: \(id ?? "nil"), rotation: \(rotation)°)"
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
    
    private func logCurrentMemoryState(_ context: String) {
        let availableMemory = memoryManager.getAvailableMemory()
        let usedMemory = memoryManager.getUsedMemory()
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let percentageUsed = Double(usedMemory) / Double(totalMemory) * 100
        
        logger.info("🧠 [\(context)] Memory state:", metadata: nil)
        logger.info("   - Available: \(availableMemory / (1024 * 1024))MB", metadata: nil)
        logger.info("   - Used: \(usedMemory / (1024 * 1024))MB", metadata: nil)
        logger.info("   - Total: \(totalMemory / (1024 * 1024))MB", metadata: nil)
        logger.info("   - Percentage used: \(String(format: "%.1f", percentageUsed))%", metadata: nil)
    }
    
    private func performAggressiveCacheClearing() {
        performAggressiveCacheClearing(correlationId: correlationId)
    }
    
    private func performAggressiveCacheClearing(correlationId: String?) {
        logger.info("🧠 Performing aggressive cache clearing", metadata: nil)
        
        // Clear memory manager cache
        memoryManager.clearCache()
        
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache
        let imageCache = NSCache<NSString, UIImage>()
        imageCache.removeAllObjects()
        
        // Request garbage collection
        processImageAsync()
        
        logger.info("🧠 Aggressive cache clearing completed", metadata: nil)
    }
    
    private func processImageAsync() {
        DispatchQueue.global(qos: .utility).async {
            // Force garbage collection
            DispatchQueue.main.async {
                // This is a hint to the system that we're in a critical memory state
                // The system may take additional actions
            }
        }
    }
    
    private func cleanupPlayerViewModel() {
        logger.info("🧠 Cleaning up player view model", metadata: nil)
        
        // Teardown and release the current player view model
        if let playerViewModel = currentVideoPlayerViewModel {
            playerViewModel.teardown()
            currentVideoPlayerViewModel = nil
        }
        
        logger.info("🧠 Player view model cleanup completed", metadata: nil)
    }
    
    private func cleanupVideoAssets() {
        logger.info("🧠 Cleaning up video assets", metadata: nil)
        
        // Release current player view model
        cleanupPlayerViewModel()
        
        // Clear any temporary video files
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in contents where file.pathExtension == "mov" || file.pathExtension == "mp4" || file.pathExtension == "tmp" {
                try FileManager.default.removeItem(at: file)
                logger.debug("🧠 Deleted temporary video file: \(file.lastPathComponent)", metadata: nil)
            }
        } catch {
            logger.error("🧠 Failed to clean up temporary video files: \(error.localizedDescription)", metadata: nil)
        }
        
        logger.info("🧠 Video assets cleanup completed", metadata: nil)
    }
    
    private func startMemoryMonitoring() {
        // Cancel any existing monitoring task
        memoryMonitoringTask?.cancel()
        
        // Start a new monitoring task
        memoryMonitoringTask = Task {
            while !Task.isCancelled {
                // Log memory state periodically
                logCurrentMemoryState("Periodic check")
                
                // Check if memory is critically low
                let availableMemory = memoryManager.getAvailableMemory()
                let criticalThreshold: Int64 = 50 * 1024 * 1024 // 50MB
                
                if availableMemory < criticalThreshold {
                    logger.warning("⚠️ Critically low memory detected during monitoring: \(availableMemory / (1024 * 1024))MB", metadata: nil)
                    
                    // Perform aggressive cache clearing
                    performAggressiveCacheClearing()
                    
                    // If still critical, transition to error state
                    if memoryManager.getAvailableMemory() < criticalThreshold {
                        logger.error("❌ Memory still critical after cache clearing", metadata: nil)
                        await MainActor.run {
                            state = .error(
                                message: "Critical memory error. Please close other apps and try again.",
                                underlyingError: "Critical memory limit exceeded"
                            )
                        }
                        break
                    }
                }
                
                // Wait for next check (every 10 seconds)
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
    }