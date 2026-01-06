import AVFoundation
import CoreMedia
import Foundation
import OSLog
import PhotosUI
import SwiftUI
import Combine

// MARK: - Add Move View Model
/// Simplified view model for AddMove feature with clean state management
/// Uses RobustVideoLoader internally while providing simple external interface
@MainActor
public final class AddMoveViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var loadingState: LoadingState = .idle
    @Published public private(set) var selectedVideo: AVAsset?
    @Published public private(set) var errorMessage: String?
    @Published public var moveName: String = ""
    @Published public var moveDescription: String = ""
    @Published public var moveCategory: String = ""
    @Published public var tags: [String] = []

    // MARK: - Save State Management
    @Published public private(set) var saveState: SaveState = .idle

    // MARK: - Video Properties
    @Published public var trimStartTime: TimeInterval = 0.0
    @Published public var trimEndTime: TimeInterval = 0.0
    @Published public private(set) var videoDuration: TimeInterval = 0.0
    @Published public var videoRotation: VideoRotation = .degrees0
    @Published public private(set) var currentTrimModification: TrimModification?

    // MARK: - Video Player
    @Published public var videoPlayer: SharedVideoPlayer = SharedVideoPlayer(mode: .main)

    // MARK: - Private Properties
    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "🎬 AddMoveViewModel"
    )

    private let videoLoader = RobustVideoLoader()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Workflow State Persistence
    /// Current workflow state for persistence across navigation and app lifecycle events
    @Published private var workflowState: WorkflowState = .idle
    /// Timestamp when workflow was suspended for quick return detection
    private var workflowSuspendedTime: Date?
    /// Cached video data for restoration after suspension
    private var suspendedVideoAsset: AVAsset?
    private var suspendedTrimRange: (start: TimeInterval, end: TimeInterval)?
    private var suspendedRotation: VideoRotation = .degrees0

    // MARK: - State Coordination Guard
    /// Prevents manual state setting during active video loading to eliminate race conditions
    private var isLoadingVideo = false
    
    /// Filters spurious state transitions from RobustVideoLoader during initialization
    private var isInitializing = true

    /// Workflow state for persistence across navigation and app lifecycle events
    enum WorkflowState {
        case idle              // No video loaded, ready to start
        case videoLoaded       // Video is loaded and ready for trimming
        case suspended         // Workflow is suspended and can be restored

        var description: String {
            switch self {
            case .idle: return "Idle"
            case .videoLoaded: return "Video Loaded"
            case .suspended: return "Suspended"
            }
        }
    }

    /// Save operation state for tracking save progress and completion
    public enum SaveState: Equatable {
        case idle              // No save operation in progress
        case saving            // Save operation in progress
        case saved             // Save operation completed successfully
        case failed(String)    // Save operation failed with error message

        var isSaving: Bool {
            switch self {
            case .saving: return true
            default: return false
            }
        }

        var isSaved: Bool {
            switch self {
            case .saved: return true
            default: return false
            }
        }

        var isFailed: Bool {
            switch self {
            case .failed: return true
            default: return false
            }
        }

        var errorMessage: String? {
            switch self {
            case .failed(let message): return message
            default: return nil
            }
        }

        var description: String {
            switch self {
            case .idle: return "Idle"
            case .saving: return "Saving"
            case .saved: return "Saved"
            case .failed(let message): return "Failed: \(message)"
            }
        }
    }

    // MARK: - Computed Properties
    public var isLoading: Bool {
        loadingState.isLoading
    }

    public var hasError: Bool {
        errorMessage != nil
    }

    public var isVideoReady: Bool {
        selectedVideo != nil && !isLoading
    }

    public var isValidForSave: Bool {
        !moveName.isEmpty && selectedVideo != nil && !hasError
    }

    public var progress: Double {
        loadingState.progress
    }

    public var trimDuration: TimeInterval {
        max(0.0, trimEndTime - trimStartTime)
    }

    public var workflowStateDescription: String {
        return workflowState.description
    }

    // MARK: - Initialization
    public init() {
        setupVideoLoaderObservation()
        setupLifecycleObservers()

        // Mark initialization completion after a short delay to ensure all
        // spurious state transitions from RobustVideoLoader initialization are filtered
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            completeInitialization()
        }

        logger.info("🎬 AddMoveViewModel initialized with simplified state management")
    }

    deinit {
        Task { @MainActor in
            cleanup()
        }
    }

    // MARK: - Video Loading Methods

    // MARK: - Video Loading Methods

    /// Load video from PhotosPicker item
    public func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
        logger.info("🎬 Loading video from PhotosPicker")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        
        do {
            // Load with timeout for large iCloud videos
            let asset = try await loadVideoWithTimeout(from: item, timeout: 60.0)

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                return
            }

            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
    }

    /// Load video from URL
    public func loadVideo(from url: URL) async {
        logger.info("🎬 Loading video from URL: \(url.lastPathComponent)")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true

        do {
            // Load with timeout for large videos
            let asset = try await loadVideoWithTimeout(from: url, timeout: 60.0)

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                return
            }

            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
    }

    /// Load video from PHAsset
    public func loadVideo(from phAsset: PHAsset) async {
        logger.info("🎬 Loading video from PHAsset: \(phAsset.localIdentifier)")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true

        do {
            // Load with timeout for large iCloud videos
            let asset = try await loadVideoWithTimeout(from: phAsset, timeout: 60.0)

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                return
            }

            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
    }

    /// Cancel current loading operation
    public func cancelLoading() {
        logger.info("🚫 Canceling video loading")
        videoLoader.cancelLoading()
    }

    /// Load video with timeout to handle large iCloud videos
    private func loadVideoWithTimeout(from item: PhotosUI.PhotosPickerItem, timeout: TimeInterval) async throws -> AVAsset {
        logger.info("⏱️ Loading video with timeout: \(timeout)s")

        return try await withThrowingTaskGroup(of: AVAsset.self) { group in
            // Add the main loading task
            group.addTask {
                return try await self.videoLoader.loadVideo(from: item)
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError.videoLoadingTimeout
            }

            // Wait for the first task to complete (either loading or timeout)
            let result = try await group.next()!

            // Cancel the remaining task
            group.cancelAll()

            return result
        }
    }

    /// Load video with timeout to handle large videos
    private func loadVideoWithTimeout(from url: URL, timeout: TimeInterval) async throws -> AVAsset {
        logger.info("⏱️ Loading video with timeout: \(timeout)s")

        return try await withThrowingTaskGroup(of: AVAsset.self) { group in
            // Add the main loading task
            group.addTask {
                return try await self.videoLoader.loadVideo(from: url)
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError.videoLoadingTimeout
            }

            // Wait for the first task to complete (either loading or timeout)
            let result = try await group.next()!

            // Cancel the remaining task
            group.cancelAll()

            return result
        }
    }

    /// Load video with timeout to handle large iCloud videos
    private func loadVideoWithTimeout(from phAsset: PHAsset, timeout: TimeInterval) async throws -> AVAsset {
        logger.info("⏱️ Loading video with timeout: \(timeout)s")

        return try await withThrowingTaskGroup(of: AVAsset.self) { group in
            // Add the main loading task
            group.addTask {
                return try await self.videoLoader.loadVideo(from: phAsset)
            }

            // Add the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError.videoLoadingTimeout
            }

            // Wait for the first task to complete (either loading or timeout)
            let result = try await group.next()!

            // Cancel the remaining task
            group.cancelAll()

            return result
        }
    }

    /// Timeout errors for video loading
    enum TimeoutError: LocalizedError {
        case videoLoadingTimeout

        var errorDescription: String? {
            switch self {
            case .videoLoadingTimeout:
                return "Video loading timed out. The video may be too large or there may be network issues. Please try again."
            }
        }
    }

    /// Validate video duration (30-minute maximum)
    private func validateVideoDuration(_ asset: AVAsset) async -> Bool {
        let maxDuration: TimeInterval = 30 * 60 // 30 minutes in seconds

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            
            if durationSeconds > maxDuration {
                let minutes = Int(durationSeconds / 60)
                let seconds = Int(durationSeconds.truncatingRemainder(dividingBy: 60))
                let errorMessage = "Video too long (\(minutes)m \(seconds)s). Maximum duration is 30 minutes."
                setError(errorMessage)
                logger.warning("⚠️ Video exceeds duration limit: \(minutes)m \(seconds)s")
                return false
            }

            return true

        } catch {
            logger.error("❌ Failed to load video duration: \(error.localizedDescription)")
            return true // Allow loading to continue despite validation error
        }
    }

    // MARK: - Video Management

    /// Set video asset and initialize trim bounds - unified reactive state management only
    private func handleVideoLoaded(_ asset: AVAsset) async {
        guard isLoadingVideo else { return }

        // UNIFIED STATE MANAGEMENT: Only update non-loadingState properties
        selectedVideo = asset
        logger.info("📦 Video asset selected")

        // Initialize trim bounds without interfering with loading state
        do {
            let duration = try await asset.load(.duration)
            videoDuration = duration.seconds
            trimEndTime = duration.seconds
            trimStartTime = 0.0

            logger.info("✅ Video loaded: \(String(format: "%.2f", videoDuration))s")

            // Update workflow state to reflect video is loaded
            workflowState = .videoLoaded
            logger.info("🔄 Workflow state: \(workflowState.description)")

        } catch {
            logger.error("💥 Failed to load video duration: \(error.localizedDescription)")
            setError("Failed to load video information")
        }
    }

    /// Handle loading errors with user-friendly messages
    private func handleLoadingError(_ error: Error) async {
        let loadingError = LoadingError.from(error)
        loadingState = .failed(loadingError.userFriendlyMessage)
        errorMessage = loadingError.userFriendlyMessage

        logger.error("❌ Video loading failed: \(error.localizedDescription)")
    }

    /// Update trim range
    public func updateTrimRange(startTime: TimeInterval, endTime: TimeInterval) async {
        guard selectedVideo != nil else { return }

        let clampedStart = max(0, min(startTime, videoDuration))
        let clampedEnd = max(clampedStart, min(endTime, videoDuration))

        trimStartTime = clampedStart
        trimEndTime = clampedEnd

        logger.debug("Trim range updated: \(trimStartTime)s - \(trimEndTime)s")
    }

    /// Update video rotation
    public func updateVideoRotation(_ rotation: VideoRotation) async {
        await MainActor.run {
            self.videoRotation = rotation
        }
        logger.debug("Video rotation updated: \(rotation.description)")
    }

    /// Save the move with the specified name using the current trim modification and video asset
    public func saveMove(name: String) async {
        logger.info("💾 AddMoveViewModel: saveMove called with name: '\(name)'")

        // Validate preconditions
        guard let asset = selectedVideo else {
            logger.error("❌ AddMoveViewModel: Cannot save - no video asset available")
            saveState = .failed("No video available to save")
            return
        }

        guard let trimModification = currentTrimModification else {
            logger.error("❌ AddMoveViewModel: Cannot save - no trim modification available")
            saveState = .failed("Please trim the video before saving")
            return
        }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            logger.error("❌ AddMoveViewModel: Cannot save - empty move name")
            saveState = .failed("Move name cannot be empty")
            return
        }

        // Set saving state
        saveState = .saving
        logger.info("🔄 AddMoveViewModel: Save operation started")

        do {
            // Create move persistence service
            let movePersistenceService = MovePersistenceService(
                persistentContainer: PersistenceController.shared.container
            )

            // Create move saver
            let moveSaver = MoveSaver(
                persistentContainer: PersistenceController.shared.container,
                movePersistenceService: movePersistenceService
            )

            // Convert VideoRotation to quarter turns
            let rotationQuarterTurns: Int
            switch trimModification.rotation {
            case .degrees0: rotationQuarterTurns = 0
            case .degrees90: rotationQuarterTurns = 1
            case .degrees180: rotationQuarterTurns = 2
            case .degrees270: rotationQuarterTurns = 3
            }

            // Save the move using the MoveSaver service
            let savedMove = try await moveSaver.saveMove(
                name: finalName,
                asset: asset,
                trimStartTime: trimModification.startTimeSeconds,
                trimEndTime: trimModification.endTimeSeconds,
                rotationQuarterTurns: rotationQuarterTurns
            )
            // Update state to saved
            saveState = .saved
            logger.info("✅ AddMoveViewModel: Move saved successfully: \(savedMove.name ?? "unnamed")")
            logger.info("📊 AddMoveViewModel: Save state updated to: \(saveState.description)")
            
            // CW&T: Legibility — user always knows what happened
            ToastManager.shared.showSuccess("\(finalName) saved")

        } catch {
            // Update state to failed
            saveState = .failed("Failed to save move: \(error.localizedDescription)")
            logger.error("❌ AddMoveViewModel: Save failed - \(error.localizedDescription)")
            logger.error("📊 AddMoveViewModel: Save state updated to: \(saveState.description)")
            
            // CW&T: Transparency — show specific error with retry option
            ToastManager.shared.showError("Failed to save: \(error.localizedDescription)")
        }
    }

    
    /// Update trim modification with complete data
    public func updateTrimModification(_ modification: TrimModification) async {
        await MainActor.run {
            self.currentTrimModification = modification
            self.trimStartTime = modification.startTimeSeconds
            self.trimEndTime = modification.endTimeSeconds
            self.videoRotation = modification.rotation
        }
        logger.debug("Trim modification updated - Duration: \(modification.durationSeconds)s, Rotation: \(modification.rotation.description)")
    }

    /// Get video thumbnail
    public func generateThumbnail(at time: TimeInterval? = nil) async -> UIImage? {
        guard let asset = selectedVideo else { return nil }

        let thumbnailTime = time ?? trimStartTime
        let cmTime = CMTime(seconds: thumbnailTime, preferredTimescale: 600)

        do {
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 320, height: 320)

            // Use the standard async API (available in iOS 15+)
            // Note: generateCGImageAsynchronously completion handler signature uses (cgImage, time, error)
            return try await withCheckedThrowingContinuation { continuation in
                imageGenerator.generateCGImageAsynchronously(for: cmTime) { cgImage, time, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let cgImage = cgImage {
                        let image = UIImage(cgImage: cgImage)
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ThumbnailGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CGImage"]))
                    }
                }
            }
        } catch {
            logger.warning("Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Error Management

    /// Set error message
    public func setError(_ message: String) {
        errorMessage = message
        logger.error("Error set: \(message)")
    }

    /// Clear error message
    public func clearError() {
        errorMessage = nil
        logger.debug("Error cleared")
    }

    // MARK: - State Management

    /// Reset view model for next move creation after successful save
    /// Maintains video player state while clearing form data for new input
    @MainActor
    public func resetForNextMove() {
        logger.info("🔄 Resetting AddMoveViewModel for next move creation")

        // Clear form data but maintain video player state
        moveName = ""
        moveDescription = ""
        moveCategory = ""
        tags = []

        // Reset trim data
        trimStartTime = 0.0
        trimEndTime = 0.0
        videoDuration = 0.0
        currentTrimModification = nil

        // Reset save state
        saveState = .idle

        // Clear selected video but maintain player state
        selectedVideo = nil
        errorMessage = nil

        // Reset workflow state to idle
        workflowState = .idle

        logger.info("✅ AddMoveViewModel reset for next move - video player state maintained")
    }

    /// Reset view model to initial state
    public func reset() {
        logger.info("🔄 Resetting AddMoveViewModel to initial state")

        // Reset all state properties
        loadingState = .idle
        selectedVideo = nil
        errorMessage = nil
        moveName = ""
        moveDescription = ""
        moveCategory = ""
        tags = []
        trimStartTime = 0.0
        trimEndTime = 0.0
        videoDuration = 0.0
        saveState = .idle
        workflowState = .idle
        
        suspendedVideoAsset = nil
        suspendedTrimRange = nil
        suspendedRotation = .degrees0
        workflowSuspendedTime = nil

        // Clean up video loader resources
        Task {
            await videoLoader.cleanupTemporaryFiles()
        }
    }

    // MARK: - Video Preloading for Tab Return

    /// Preload video for quick tab return to prevent video flashing
    /// This method starts video loading immediately when a suspended workflow is detected
    /// Preload video for quick tab return to prevent video flashing
    public func preloadVideoForQuickReturn() async {
        guard canRestoreWorkflow, let cachedAsset = suspendedVideoAsset else { return }

        logger.info("⚡ Preloading video for quick return")

        do {
            // Restore cached state first
            selectedVideo = cachedAsset
            if let cachedTrimRange = suspendedTrimRange {
                trimStartTime = cachedTrimRange.start
                trimEndTime = cachedTrimRange.end
            }
            videoRotation = suspendedRotation

            // Update video duration from cached asset
            let duration = try await cachedAsset.load(.duration)
            videoDuration = duration.seconds

            // Check if player can be quickly restored without reloading
            if videoPlayer.canQuickRestore {
                if await videoPlayer.prepareForQuickReturn() {
                    logger.info("✅ Player quick restore successful")
                } else {
                    logger.warning("⚠️ Player quick restore failed - reloading")
                    await videoPlayer.loadVideo(cachedAsset)
                }
            } else {
                await videoPlayer.loadVideo(cachedAsset)
            }

            workflowState = .videoLoaded

        } catch {
            logger.error("❌ Preloading failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Workflow State Persistence

    /// Suspend the current workflow state for later restoration
    /// Suspend the current workflow state for later restoration
    public func suspendWorkflow() {
        guard selectedVideo != nil else { return }

        logger.info("🔄 Suspending workflow")

        // Cache current state
        suspendedVideoAsset = selectedVideo
        suspendedTrimRange = (trimStartTime, trimEndTime)
        suspendedRotation = videoRotation
        workflowSuspendedTime = Date()

        if videoPlayer.isReady {
            videoPlayer.maintainPlayerStateForQuickReturn()
        }

        workflowState = .suspended
    }

    /// Restore a previously suspended workflow state
    public func restoreWorkflow() async {
        guard let cachedAsset = suspendedVideoAsset,
              let cachedTrimRange = suspendedTrimRange else { return }

        logger.info("🔄 Restoring workflow")

        // Restore cached state
        selectedVideo = cachedAsset
        trimStartTime = cachedTrimRange.start
        trimEndTime = cachedTrimRange.end
        videoRotation = suspendedRotation

        // Update video duration from cached asset
        do {
            let duration = try await cachedAsset.load(.duration)
            videoDuration = duration.seconds
        } catch {
            logger.error("❌ Failed to load video duration: \(error.localizedDescription)")
        }

        // Enhanced video player restoration with quick return support
        if videoPlayer.canQuickRestore {
            if await videoPlayer.prepareForQuickReturn() {
                logger.info("✅ Player quick restore successful")
            } else {
                logger.warning("⚠️ Player quick restore failed - reloading")
                await videoPlayer.loadVideo(cachedAsset)
            }
        } else {
            await videoPlayer.loadVideo(cachedAsset)
        }

        // Update workflow state
        workflowState = .videoLoaded

        // Clear suspension data
        suspendedVideoAsset = nil
        suspendedTrimRange = nil
        suspendedRotation = .degrees0
        workflowSuspendedTime = nil
    }

    /// Check if workflow can be restored
    public var canRestoreWorkflow: Bool {
        return workflowState == .suspended && suspendedVideoAsset != nil
    }

    /// Check if return to trimming is quick (< 5 seconds)
    public var isQuickReturn: Bool {
        guard let suspendedTime = workflowSuspendedTime else { return false }
        return Date().timeIntervalSince(suspendedTime) < 5.0
    }

    // MARK: - Private Methods

    /// Set up lifecycle observers for app backgrounding/foregrounding
    private func setupLifecycleObservers() {
        // Observe app backgrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppBackgrounded()
            }
        }

        // Observe app foregrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppForegrounded()
            }
        }

        logger.info("📱 Lifecycle observers configured for workflow persistence")
    }

    /// Handle app backgrounding by suspending workflow
    @MainActor
    private func handleAppBackgrounded() {
        logger.info("📱 App entered background - suspending workflow")
        suspendWorkflow()
    }

    /// Handle app foregrounding by checking if workflow should be restored
    @MainActor
    private func handleAppForegrounded() {
        logger.info("📱 App entering foreground - checking workflow restoration")
        // Note: Actual restoration will be handled by the view when it appears
        // This just logs the event and ensures state is consistent
    }

    /// Set up observation of video loader state with enhanced loading stage support
    private func setupVideoLoaderObservation() {
        videoLoader.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleVideoLoaderStateChange(newState)
            }
            .store(in: &cancellables)

        // Also observe progress updates
        videoLoader.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.handleProgressUpdate(progress)
            }
            .store(in: &cancellables)

        // REMOVED: Notification-based coordination observer - now using direct async coordination
        // Player initialization is coordinated through direct async with proper state propagation
    }

    /// Coordinate player initialization using direct async coordination
    @MainActor
    private func coordinatePlayerInitialization(asset: AVAsset) async {
        loadingState = .loading(progress: 0.9, stage: .initializingPlayer, message: "Preparing video player...")
        
        // Load the video player
        let playerReady = await videoPlayer.loadVideo(asset)

        if playerReady {
            loadingState = .loading(progress: 0.0, stage: .preparingPlayback, message: "Preparing for playback...")
            
            // Allow a brief moment for UI to update (essential for smooth transitions)
            await Task.yield()

            loadingState = .loading(progress: 0.0, stage: .finalizing, message: "Finalizing...")
            await Task.yield()

            // Update to fully ready state
            loadingState = .fullyReady(asset)
            logger.info("✅ Video player initialized and ready")
        } else {
            logger.error("❌ Video player initialization failed")
            loadingState = .failed("Failed to initialize video player")
            errorMessage = "Failed to initialize video player"
        }
    }

    /// Handle video loader state changes
    private func handleVideoLoaderStateChange(_ newState: LoadingState) {
        guard !isInitializing else { return }

        // Map loader state to view model state
        switch newState {
        case .loading(let progress, let stage, let message):
            loadingState = .loading(progress: progress, stage: stage, message: message)
            
        case .assetReady(let asset):
            selectedVideo = asset
            loadingState = .assetReady(asset)
            logger.info("📦 Video asset ready")
            
            // Coordinate player initialization
            Task { @MainActor in
                await coordinatePlayerInitialization(asset: asset)
            }

        case .playerReady(let asset):
            selectedVideo = asset
            loadingState = .playerReady(asset)

        case .fullyReady(let asset):
            selectedVideo = asset
            loadingState = .fullyReady(asset)
            logger.info("✅ Video fully ready")

        case .failed(let message):
            loadingState = .failed(message)
            errorMessage = message
            logger.error("❌ Video loading failed: \(message)")

        case .idle:
            loadingState = .idle
        }
    }

    /// Handle progress updates
    private func handleProgressUpdate(_ progress: LoadingProgress) {
        // UI BUG FIX: Check if this is a fullyReady state transition
        if progress.stage == nil && progress.value >= 1.0 {
            loadingState = .fullyReady(selectedVideo!)
        } else {
            let stage = progress.stage ?? .initializing
            loadingState = .loading(progress: progress.value, stage: stage, message: progress.message)
        }
    }

    /// Clean up resources
    private func cleanup() {
        cancellables.removeAll()
        Task {
            await videoLoader.cleanupTemporaryFiles()
        }
    }

    /// Complete initialization phase
    private func completeInitialization() {
        isInitializing = false
        
        // CRITICAL FIX: Ensure loadingState is explicitly idle after initialization
        loadingState = .idle
        
        logger.info("✅ Initialization completed")
    }


}

// MARK: - Validation Extension
extension AddMoveViewModel {
    /// Validate current state for saving
    public func validateForSaving() -> [String] {
        var issues: [String] = []

        if moveName.isEmpty {
            issues.append("Move name is required")
        }

        if selectedVideo == nil {
            issues.append("No video selected")
        }

        if trimDuration <= 0 {
            issues.append("Invalid trim duration")
        }

        if hasError {
            issues.append("Please resolve current error")
        }

        return issues
    }

    /// Check if move can be saved
    public var canSave: Bool {
        validateForSaving().isEmpty
    }


}

// MARK: - Progress Extension
extension AddMoveViewModel {
    /// Get formatted progress percentage
    public var progressPercentage: Int {
        let rawProgress = progress
        return Int(rawProgress * 100)
    }

    /// Get progress message with enhanced iCloud awareness
    public var progressMessage: String {
        switch loadingState {
        case .idle:
            return "Ready to load video"
        case .loading(_, _, let message):
            return message
        case .assetReady:
            return "Video loaded - preparing player..."
        case .playerReady:
            return "Player ready - finalizing..."
        case .fullyReady:
            return "Video ready for trimming"
        case .failed(let message):
            return message
        }
    }
}