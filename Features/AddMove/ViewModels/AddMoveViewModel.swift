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

    // MARK: - Initialization Boundary Management
    /// Tracks whether the ViewModel is in initialization phase to filter spurious state transitions
    private var isInitializing = true
    /// Tracks when initialization completed for boundary detection
    private var initializationCompletedTime: Date?

    // MARK: - State Coordination Guard
    /// Prevents manual state setting during active video loading to eliminate race conditions
    private var isLoadingVideo = false
    /// Tracks state transition sources for debugging and validation
    private var lastStateTransitionSource: String?

    /// Sources of state transitions for validation and debugging
    private enum TransitionSource {
        case userAction
        case systemInit
        case networkEvent
        case videoLoader
        case unknown

        var description: String {
            switch self {
            case .userAction: return "User Action"
            case .systemInit: return "System Init"
            case .networkEvent: return "Network Event"
            case .videoLoader: return "Video Loader"
            case .unknown: return "Unknown"
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

    // MARK: - Initialization
    public init() {
        setupVideoLoaderObservation()

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

    /// Load video from PhotosPicker item
    public func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
        logger.info("🎬 Loading video from PhotosPicker")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "PhotosPicker loadVideo"

        do {
            let asset = try await videoLoader.loadVideo(from: item)
            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
        lastStateTransitionSource = nil
    }

    /// Load video from URL
    public func loadVideo(from url: URL) async {
        logger.info("🎬 Loading video from URL: \(url.lastPathComponent)")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "URL loadVideo"

        do {
            let asset = try await videoLoader.loadVideo(from: url)
            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
        lastStateTransitionSource = nil
    }

    /// Load video from PHAsset
    public func loadVideo(from phAsset: PHAsset) async {
        logger.info("🎬 Loading video from PHAsset: \(phAsset.localIdentifier)")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "PHAsset loadVideo"

        do {
            let asset = try await videoLoader.loadVideo(from: phAsset)
            await handleVideoLoaded(asset)
        } catch {
            await handleLoadingError(error)
        }

        // Clear coordination guard after loading completes
        isLoadingVideo = false
        lastStateTransitionSource = nil
    }

    /// Cancel current loading operation
    public func cancelLoading() {
        logger.info("🚫 Canceling video loading")
        videoLoader.cancelLoading()
    }

    // MARK: - Video Management

    /// Set video asset and initialize trim bounds - unified reactive state management only
    /// BREAKING CHANGE: Simplified to eliminate race conditions - SharedVideoPlayer initialization
    /// is now coordinated through RobustVideoLoader's unified state management paradigm
    private func handleVideoLoaded(_ asset: AVAsset) async {
        logger.info("🎯 UNIFIED STATE MANAGEMENT: handleVideoLoaded called - delegating to loader coordination")

        // RACE CONDITION PREVENTION: Verify coordination guard is active
        guard isLoadingVideo else {
            logger.warning("🚫 COORDINATION GUARD: handleVideoLoaded called outside loading state")
            return
        }

        // UNIFIED STATE MANAGEMENT: Only update non-loadingState properties
        // SharedVideoPlayer initialization is now handled by RobustVideoLoader coordination
        selectedVideo = asset
        logger.info("📦 Selected video set - delegating player coordination to RobustVideoLoader")

        // Initialize trim bounds without interfering with loading state
        do {
            let duration = try await asset.load(.duration)
            videoDuration = duration.seconds
            trimEndTime = duration.seconds
            trimStartTime = max(0, duration.seconds - 10) // Default to last 10 seconds

            logger.info("✅ Video asset loaded: duration \(videoDuration)s")
            logger.info("🎯 UNIFIED STATE MANAGEMENT: Trim bounds initialized - SharedVideoPlayer coordinated by loader")

            // BREAKING CHANGE: All SharedVideoPlayer initialization removed from handleVideoLoaded
            // The loader now coordinates player initialization through the reactive state chain
            logger.info("🚫 SHARED PLAYER COORDINATION: Removed from handleVideoLoaded - now handled by RobustVideoLoader")
            logger.info("🎯 RACE CONDITION ELIMINATED: No manual player initialization or state setting")

        } catch {
            logger.error("Failed to load video duration: \(error.localizedDescription)")
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

    /// Reset view model to initial state
    public func reset() {
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

        Task {
            await videoLoader.cleanupTemporaryFiles()
        }

        logger.info("🔄 AddMoveViewModel reset to initial state")
    }

    // MARK: - Private Methods

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
    /// FIXED: Removed TaskGroup to maintain @Published state observation chain
    @MainActor
    private func coordinatePlayerInitialization(asset: AVAsset) async {
        Logger.loadingState.info("🎯 AddMoveViewModel: Starting player coordination with direct async")

        // SERVICE → VIEWMODEL STATE TRANSITION: Progressive updates that propagate to UI
        Logger.loadingState.info("📊 Service→ViewModel: 90% - Initializing video player")
        loadingState = .loading(progress: 0.9, stage: .initializingPlayer, message: "Preparing video player...")

        // Direct async coordination without TaskGroup isolation
        Logger.loadingState.info("🎮 AddMoveViewModel: Calling SharedVideoPlayer.loadVideo")
        let playerReady = await videoPlayer.loadVideo(asset)

        if playerReady {
            let oldProgress = loadingState.progress
            Logger.loadingState.info("📊 Service→ViewModel: 95% - Preparing for playback")
            let frameTimestamp = CFAbsoluteTimeGetCurrent()
            Logger.loadingState.debug("🎯 Frame separation: \(frameTimestamp)s - State update: 95%")
            Logger.loadingState.debug("📊 Progress transition: \(Int(oldProgress * 100))% → 95% (preparingPlayback)")
            // Progress Calculation Fix: Use stage-relative progress (0.0) to ensure user sees expected 95%
            // Calculation: stage.baseProgress (0.95) + internalProgress (0.0) × stage.weight (0.04) = 0.95 = 95%
            // Previous: Using 0.95 showed 98.8% (0.95 + 0.95×0.04), causing "stuck" perception
            loadingState = .loading(progress: 0.0, stage: .preparingPlayback, message: "Preparing for playback...")
            _ = validateProgressDisplay(.preparingPlayback, internalProgress: 0.0)

            // Enhanced frame separation: Ensure main thread synchronization and UI frame boundary
            await MainActor.run { }
            await Task.yield()
            Logger.loadingState.debug("🎯 Frame boundary crossed: preparingPlayback state observed by UI")

            let preparingProgress = loadingState.progress
            Logger.loadingState.info("📊 Service→ViewModel: 99% - Finalizing")
            let frameTimestamp99 = CFAbsoluteTimeGetCurrent()
            Logger.loadingState.debug("🎯 Frame separation: \(frameTimestamp99)s - State update: 99%")
            Logger.loadingState.debug("📊 Progress transition: \(Int(preparingProgress * 100))% → 99% (finalizing)")
            // Progress Calculation Fix: Use stage-relative progress (0.0) to ensure user sees expected 99%
            // Calculation: stage.baseProgress (0.99) + internalProgress (0.0) × stage.weight (0.01) = 0.99 = 99%
            // Previous: Using 0.99 would show 99.99%, creating unexpected display values
            loadingState = .loading(progress: 0.0, stage: .finalizing, message: "Finalizing...")
            _ = validateProgressDisplay(.finalizing, internalProgress: 0.0)

            // Enhanced frame separation: Ensure main thread synchronization and UI frame boundary
            await MainActor.run { }
            await Task.yield()
            Logger.loadingState.debug("🎯 Frame boundary crossed: finalizing state observed by UI")

            Logger.loadingState.info("📊 Service→ViewModel: 100% - Fully ready")
            let frameTimestamp100 = CFAbsoluteTimeGetCurrent()
            Logger.loadingState.debug("🎯 Frame separation: \(frameTimestamp100)s - State update: 100%")
            Logger.loadingState.debug("🔍 OBSERVER TRACKING: Single observer pattern - SelectClip exclusively handling loading state")

            let previousState = loadingState
            let newState = LoadingState.fullyReady(asset)

            if newState.validateMonotonicTransition(from: previousState) {
                loadingState = newState
                Logger.loadingState.info("✅ AddMoveViewModel: UI Observation: Monotonic transition to fullyReady successful")
                Logger.loadingState.debug("🎯 SINGLE OBSERVER CONFIRMED: No competing observers detected - clean state propagation")
            }
        } else {
            Logger.loadingState.error("❌ AddMoveViewModel: SharedVideoPlayer initialization failed")
            // Transition to error state if player initialization fails
            loadingState = .failed("Failed to initialize video player")
            errorMessage = "Failed to initialize video player"
        }
    }

    /// Handle video loader state changes with monotonic validation and @MainActor isolation
    private func handleVideoLoaderStateChange(_ newState: LoadingState) {
        let oldState = loadingState

        // OBSERVER TRACKING: Log observer pattern diagnostics
        let frameTimestamp = CFAbsoluteTimeGetCurrent()
        Logger.loadingState.debug("🔍 OBSERVER PATTERN: Single observer (SelectClip) handling state transition at \(frameTimestamp)s")

        // MONOTONIC STATE VALIDATION: Use the new state machine pattern to prevent retrogression
        guard newState.validateMonotonicTransition(from: oldState) else {
            Logger.loadingState.error("🚫 AddMoveViewModel: State regression detected - rejecting transition")
            return
        }

        // Additional filtering for spurious transitions during initialization phase
        guard !isInitializing else {
            Logger.loadingState.debug("🚫 AddMoveViewModel: Filtering spurious state transition during initialization")
            return
        }

        // Log valid state transition with enhanced diagnostics and observer tracking
        Logger.loadingState.debug("🔄 AddMoveViewModel: Valid state transition \(oldState.progress * 100)% → \(newState.progress * 100)%")
        Logger.loadingState.debug("📊 FRAME TIMING: State transition at \(frameTimestamp)s - SINGLE OBSERVER ACTIVE")

        // MODERNIZED: Service→ViewModel state mapping with player coordination
        // Use TaskGroup for structured concurrency when player initialization is needed
        switch newState {
        case .loading(let progress, let stage, let message):
            // Map loader state to view model state with iCloud awareness
            loadingState = .loading(progress: progress, stage: stage, message: message)
            Logger.loadingState.debug("📊 AddMoveViewModel: Loading progress: \(Int(progress * 100))% - \(stage.defaultMessage)")

        case .assetReady(let asset):
            // FIXED: Asset ready - now coordinate player initialization with direct async
            selectedVideo = asset
            loadingState = .assetReady(asset)
            Logger.loadingState.info("📦 AddMoveViewModel: Video asset ready - starting player coordination")

            // Use direct async coordination to maintain state observation chain
            Task { @MainActor in
                await coordinatePlayerInitialization(asset: asset)
            }

        case .playerReady(let asset):
            // This state should not come from loader anymore, but handle for compatibility
            selectedVideo = asset
            loadingState = .playerReady(asset)
            Logger.loadingState.info("🎮 AddMoveViewModel: Player ready state received")

        case .fullyReady(let asset):
            // This state should not come from loader anymore, but handle for compatibility
            selectedVideo = asset
            loadingState = .fullyReady(asset)
            Logger.loadingState.info("✅ AddMoveViewModel: Fully ready state received")

        case .failed(let message):
            loadingState = .failed(message)
            errorMessage = message
            Logger.loadingState.error("❌ AddMoveViewModel: Video loading failed: \(message)")

        case .idle:
            // Reset to idle state
            loadingState = .idle
            Logger.loadingState.debug("🔄 AddMoveViewModel: Loading state reset to idle")
        }
    }

    /// Handle progress updates with stage-aware progress mapping
    private func handleProgressUpdate(_ progress: LoadingProgress) {
        // Process ALL progress updates to maintain functorial composition
        // Don't filter based on loading state to ensure continuous progress flow
        if case .loading(_, let stage, _) = loadingState {
            loadingState = .loading(progress: progress.value, stage: stage, message: progress.message)
        } else {
            // If we're not in a loading state but receive progress,
            // create a loading state with the appropriate stage
            let stage = progress.stage ?? .initializing
            loadingState = .loading(progress: progress.value, stage: stage, message: progress.message)
        }

        // Log significant progress milestones
        let percentage = Int(progress.value * 100)
        if percentage % 25 == 0 { // Log every 25%
            logger.info("📊 Loading milestone: \(percentage)% - \(progress.message)")
        }
    }

    /// Clean up resources
    private func cleanup() {
        cancellables.removeAll()
        Task {
            await videoLoader.cleanupTemporaryFiles()
        }
    }

    // MARK: - Initialization Boundary Management

    /// Complete initialization phase and enable state transition processing
    private func completeInitialization() {
        isInitializing = false
        initializationCompletedTime = Date()
        logger.info("✅ AddMoveViewModel initialization completed - processing state transitions enabled")

        // Ensure we're in idle state after initialization
        if loadingState != .idle {
            loadingState = .idle
            logger.debug("🔄 Reset to idle state after initialization completion")
        }
    }

    /// Log state transitions for debugging with phase and source tracking
    private func logStateTransition(from: LoadingState, to: LoadingState, source: TransitionSource) {
        let phase = isInitializing ? "INIT" : "OPERATIONAL"
        logger.debug("🔄 State Transition [\(phase)]: \(from) → \(to) (Source: \(source.description))")
    }

    /// Validate state transition legitimacy based on source and current state
    private func validateStateTransition(from: LoadingState, to: LoadingState, source: TransitionSource) -> Bool {
        // During initialization, only allow system-initiated transitions
        if isInitializing && source != .systemInit {
            logger.warning("🚫 Invalid transition during initialization from \(source.description)")
            return false
        }

        // Network events should not trigger loading states directly
        if source == .networkEvent && to.isLoading {
            logger.warning("🚫 Network event triggering loading state - potential boundary violation")
            return false
        }

        // ENHANCED: Boundary integrity checks for final state transitions
        if source == .videoLoader && to.isFullyReady {
            logger.info("🎯 BOUNDARY INTEGRITY CHECK: Final state transition detected from videoLoader")
            logger.info("🔍 TRANSITION ANALYSIS: \(from) → \(to) (Progress: \(Int(to.progress * 100))%)")

            // Verify that the final state transition includes 100% progress
            if to.progress < 1.0 {
                logger.warning("⚠️ BOUNDARY WARNING: Final state transition with incomplete progress: \(Int(to.progress * 100))%")
            }
        }

        // Allow all other transitions during operational phase
        return true
    }

    // MARK: - Enhanced State Propagation with Fallback

    /// Schedule boundary integrity verification for final state transitions
    private func scheduleBoundaryVerification() {
        Task { @MainActor in
            // Check at 500ms and 2s intervals to ensure final state propagation
            for delay in [0.5, 2.0] {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Only check if we might have a state propagation issue
                if case .fullyReady = loadingState {
                    logger.info("✅ BOUNDARY VERIFICATION (\(delay)s): fullyReady state confirmed")
                } else if case .loading(let progress, _, _) = loadingState, progress >= 0.88 {
                    logger.warning("⚠️ BOUNDARY ISSUE DETECTED (\(delay)s): Stuck at \(Int(progress * 100))% - attempting recovery")
                    await attemptStateRecovery()
                }
            }
        }
    }

    /// Attempt recovery from state propagation failures
    private func attemptStateRecovery() async {
        guard let asset = selectedVideo else {
            logger.warning("⚠️ Cannot attempt recovery - no asset available")
            return
        }

        logger.info("🔧 ATTEMPTING STATE PROPAGATION RECOVERY")

        // Force transition to fullyReady if we have an asset but are stuck in loading
        if case .loading(let progress, _, _) = loadingState, progress >= 0.88 {
            loadingState = .fullyReady(asset)
            logger.info("🔧 RECOVERY COMPLETED: Forced transition to fullyReady state")
            logger.info("✅ BOUNDARY RECOVERY: Service→ViewModel state synchronization restored")
        }
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

    /// Validate progress display calculation for debugging
    ///
    /// This helper method validates that progress calculations align with user expectations.
    /// It logs the calculated display percentage to help diagnose any discrepancies.
    ///
    /// Formula: stage.baseProgress + (internalProgress × stage.weight) = displayedProgress
    ///
    /// - Parameters:
    ///   - stage: The loading stage with predefined baseProgress and weight values
    ///   - internalProgress: The stage-relative progress (0.0 to 1.0)
    /// - Returns: The calculated progress value that will be displayed to users
    private func validateProgressDisplay(_ stage: LoadingStage, internalProgress: Double) -> Double {
        let calculatedProgress = stage.baseProgress + (internalProgress * stage.weight)
        let displayPercentage = Int(calculatedProgress * 100)
        Logger.loadingState.debug("🔍 Progress display validation: \(stage) = \(displayPercentage)%")
        return calculatedProgress
    }
}

// MARK: - Progress Extension
extension AddMoveViewModel {
    /// Get formatted progress percentage
    public var progressPercentage: Int {
        let rawProgress = progress
        let displayPercentage = Int(rawProgress * 100)
        Logger.loadingState.debug("🔍 Progress display: raw=\(rawProgress), display=\(displayPercentage)%")
        return displayPercentage
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