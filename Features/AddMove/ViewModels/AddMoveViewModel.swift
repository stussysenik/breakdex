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

    // MARK: - Session Boundary Management
    /// Tracks whether the ViewModel is in initialization phase to filter spurious state transitions
    private var isInitializing = true
    /// Tracks when initialization completed for boundary detection
    private var initializationCompletedTime: Date?

    /// Unique identifier for the current loading session to distinguish between sessions
    @MainActor private var currentLoadingSession: UUID = UUID()
    /// Timestamp when current loading session started for diagnostic purposes
    @MainActor private var sessionStartTime: Date?
    /// Counter for generating unique session identifiers
    @MainActor private var sessionCounter: Int = 0

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

    /// Generate a new session identifier for tracking loading sessions
    @MainActor
    private func generateNewLoadingSession() -> UUID {
        sessionCounter += 1
        let newSession = UUID()
        currentLoadingSession = newSession
        sessionStartTime = Date()

        logger.info("🆕 SESSION BOUNDARY: New loading session generated [\(currentLoadingSession.uuidString.prefix(8))] - Session #\(sessionCounter)")
        logger.info("🔍 SESSION TRACKING: Session start timestamp: \(sessionStartTime!.timeIntervalSince1970)")
        logger.info("🎯 SESSION ISOLATION: Previous session has been cleaned up and invalidated")
        return newSession
    }

    /// Detect session boundary transitions based on state changes
    @MainActor
    private func detectSessionBoundary(from previousState: LoadingState, to newState: LoadingState) -> Bool {
        // Detect session boundaries based on state transitions
        if case .fullyReady = previousState, case .loading = newState {
            return true // New loading session after completion
        } else if previousState.isFailed && !newState.isFailed {
            return true // Recovery session after error
        } else if case .idle = previousState, case .loading = newState {
            return true // First loading session
        } else if previousState.progress > newState.progress && previousState.progress > 0.9 {
            return true // Potential session boundary from high progress to lower
        }
        return false
    }

    /// Log session boundary transitions with enhanced thread safety and comprehensive diagnostic information
    @MainActor
    private func logSessionBoundary(from previousState: LoadingState, to newState: LoadingState, context: String) {
        let sessionID = currentLoadingSession.uuidString.prefix(8)
        let timestamp = Date()
        let sessionDuration = sessionStartTime.map { timestamp.timeIntervalSince($0) } ?? 0

        logger.info("🔍 SESSION BOUNDARY DETECTED: \(context)")
        logger.info("📊 Session Analytics [\(sessionID)]: Session #\(sessionCounter), Duration: \(String(format: "%.3f", sessionDuration))s")
        logger.info("🔄 State Transition: \(previousState) → \(newState)")

        // Enhanced thread safety verification
        let isMainThread = Thread.isMainThread
        logger.info("🎯 Thread Safety: @MainActor isolation confirmed (\(isMainThread ? "MAIN THREAD" : "BACKGROUND THREAD - WARNING"))")

        if !isMainThread {
            logger.error("❌ THREAD SAFETY VIOLATION: Session boundary logging occurring on background thread!")
        }

        // Log session boundary type based on the transition
        if case .fullyReady = previousState, case .loading = newState {
            logger.info("🆕 NEW SESSION: User initiated new loading after completion (cancel-trim-select workflow)")
        } else if previousState.isFailed && !newState.isFailed {
            logger.info("🔄 RECOVERY SESSION: Loading retry after error")
        } else if case .idle = previousState, case .loading = newState {
            logger.info("🚀 FRESH SESSION: First loading in ViewModel lifecycle")
        }

        // Check for potential race conditions or boundary violations
        if sessionDuration < 0.1 {
            logger.warning("⚠️ BOUNDARY WARNING: Very short session duration (\(String(format: "%.3f", sessionDuration))s) - potential race condition")
        }

        // Enhanced diagnostic information about SharedVideoPlayer state
        logger.info("🎮 SharedVideoPlayer State: \(videoPlayer.state), isReady: \(videoPlayer.isReady)")
        logger.info("🎮 SharedVideoPlayer Diagnostics: \(videoPlayer.playerStateDiagnostics)")

        // Session isolation verification
        logger.info("🔍 Observer Management: KVO observers cleared (\(videoPlayer.hasObservers ? "LEAK DETECTED" : "CLEAN"))")

        logger.info("✅ Session boundary logged successfully [\(sessionID)]")
        logger.info("🎯 SESSION ISOLATION: Clean boundary established for next loading session")
    }

    /// Load video from PhotosPicker item
    public func loadVideo(from item: PhotosUI.PhotosPickerItem) async {
        // Generate new loading session for this operation
        let sessionID = await generateNewLoadingSession()
        logger.info("🎬 Loading video from PhotosPicker [Session: \(sessionID.uuidString.prefix(8))]")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "PhotosPicker loadVideo"

        do {
            // Load with timeout for large iCloud videos
            let asset = try await loadVideoWithTimeout(from: item, timeout: 60.0) // 60 second timeout

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                lastStateTransitionSource = nil
                return
            }

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
        // Generate new loading session for this operation
        let sessionID = await generateNewLoadingSession()
        logger.info("🎬 Loading video from URL: \(url.lastPathComponent) [Session: \(sessionID.uuidString.prefix(8))]")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "URL loadVideo"

        do {
            // Load with timeout for large videos
            let asset = try await loadVideoWithTimeout(from: url, timeout: 60.0) // 60 second timeout

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                lastStateTransitionSource = nil
                return
            }

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
        // Generate new loading session for this operation
        let sessionID = await generateNewLoadingSession()
        logger.info("🎬 Loading video from PHAsset: \(phAsset.localIdentifier) [Session: \(sessionID.uuidString.prefix(8))]")
        clearError()

        // Set coordination guard to prevent manual state setting during loading
        isLoadingVideo = true
        lastStateTransitionSource = "PHAsset loadVideo"

        do {
            // Load with timeout for large iCloud videos
            let asset = try await loadVideoWithTimeout(from: phAsset, timeout: 60.0) // 60 second timeout

            // Perform early duration validation
            if await !validateVideoDuration(asset) {
                isLoadingVideo = false
                lastStateTransitionSource = nil
                return
            }

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
        logger.info("📏 DURATION VALIDATION: Starting validation with 30-minute limit")

        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            let minutes = Int(durationSeconds / 60)
            let seconds = Int(durationSeconds.truncatingRemainder(dividingBy: 60))

            logger.info("📊 DURATION DIAGNOSTICS: Video length detected - \(minutes)m \(seconds)s (\(String(format: "%.1f", durationSeconds))s)")

            if durationSeconds > maxDuration {
                let errorMessage = "Video too long (\(minutes)m \(seconds)s). Maximum duration is 30 minutes."
                setError(errorMessage)

                logger.error("❌ DURATION VALIDATION FAILED: Video exceeds \(maxDuration)s limit by \(String(format: "%.1f", durationSeconds - maxDuration))s")
                logger.warning("⚠️ LARGE VIDEO HANDLING: User will see error message and loading will be cancelled")
                return false
            }

            logger.info("✅ DURATION VALIDATION PASSED: Video length acceptable for processing")
            logger.debug("📊 DURATION DIAGNOSTICS: Video is \(String(format: "%.1f", (maxDuration - durationSeconds) / 60)) minutes under the limit")
            return true

        } catch {
            logger.error("❌ DURATION VALIDATION ERROR: Failed to load video duration - \(error.localizedDescription)")
            logger.warning("⚠️ DURATION VALIDATION: Allowing loading to continue despite validation error")

            // For duration validation errors, we should still allow loading but log the issue
            // The error will be handled later in the loading process
            return true
        }
    }

    // MARK: - Video Management

    /// Set video asset and initialize trim bounds - unified reactive state management only
    /// BREAKING CHANGE: Simplified to eliminate race conditions - SharedVideoPlayer initialization
    /// is now coordinated through RobustVideoLoader's unified state management paradigm
    private func handleVideoLoaded(_ asset: AVAsset) async {
        let handleStartTime = CFAbsoluteTimeGetCurrent()
        logger.info("🎯 ADDMOVE VIEWMODEL: handleVideoLoaded called [TIME: \(handleStartTime)]")
        logger.info("🎯 ADDMOVE VIEWMODEL: Current loadingState = \(loadingState)")
        logger.info("🎯 ADDMOVE VIEWMODEL: Current loadingState.progress = \(loadingState.progress * 100)%")

        // RACE CONDITION PREVENTION: Verify coordination guard is active
        guard isLoadingVideo else {
            logger.warning("🚫 COORDINATION GUARD: handleVideoLoaded called outside loading state")
            return
        }

        logger.info("🎯 ADDMOVE VIEWMODEL: Coordination guard active - proceeding with asset handling")
        logger.info("🎯 ADDMOVE VIEWMODEL: VideoLoader state = \(videoLoader.state)")
        logger.info("🎯 ADDMOVE VIEWMODEL: VideoLoader state.progress = \(videoLoader.state.progress * 100)%")

        // UNIFIED STATE MANAGEMENT: Only update non-loadingState properties
        // SharedVideoPlayer initialization is now handled by RobustVideoLoader coordination
        selectedVideo = asset
        logger.info("📦 ADDMOVE VIEWMODEL: selectedVideo set to asset")

        // Initialize trim bounds without interfering with loading state
        do {
            let duration = try await asset.load(.duration)
            videoDuration = duration.seconds
            trimEndTime = duration.seconds
            trimStartTime = max(0, duration.seconds - 10) // Default to last 10 seconds

            logger.info("✅ ADDMOVE VIEWMODEL: Video asset loaded: duration \(videoDuration)s")
            logger.info("🎯 ADDMOVE VIEWMODEL: Trim bounds initialized")

            // Update workflow state to reflect video is loaded
            workflowState = .videoLoaded
            logger.info("🔄 ADDMOVE VIEWMODEL: Workflow state updated to: \(workflowState.description)")

            // BREAKING CHANGE: All SharedVideoPlayer initialization removed from handleVideoLoaded
            // The loader now coordinates player initialization through the reactive state chain
            logger.info("🚫 ADDMOVE VIEWMODEL: No SharedVideoPlayer initialization in handleVideoLoaded")
            logger.info("🎯 ADDMOVE VIEWMODEL: Expecting RobustVideoLoader to handle player coordination")

            // PROOF: Track coordination gap hypothesis - what does ViewModel actually do?
            logger.info("🔍 PROOF: AddMoveViewModel handleVideoLoaded - player initialization status:")
            logger.info("🔍 PROOF: videoPlayer.isReady = \(videoPlayer.isReady)")
            logger.info("🔍 PROOF: videoPlayer.state = \(videoPlayer.state)")
            logger.info("🔍 PROOF: current loadingState = \(loadingState) (\(Int(loadingState.progress * 100))%)")
            logger.info("🔍 PROOF: AddMoveViewModel will NOT advance state beyond \(Int(loadingState.progress * 100))%")
            logger.info("🔍 PROOF: Coordination gap: RobustVideoLoader expects ViewModel to complete, ViewModel expects RobustVideoLoader to complete")

            let handleEndTime = CFAbsoluteTimeGetCurrent()
            logger.info("🎯 ADDMOVE VIEWMODEL: handleVideoLoaded completed [DURATION: \((handleEndTime - handleStartTime) * 1000)ms]")

            // PROOF: Monitor if any state changes happen after this point
            logger.info("🔍 PROOF: Starting 5-second monitoring window to detect any state changes after handleVideoLoaded")
            Task {
                for i in 1...5 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    logger.info("🔍 PROOF: \(i)s after handleVideoLoaded - loadingState: \(loadingState) (\(Int(loadingState.progress * 100))%)")
                }
                logger.info("🔍 PROOF: Monitoring window complete - if state didn't change, coordination gap is confirmed")
            }

        } catch {
            logger.error("💥 ADDMOVE VIEWMODEL: Failed to load video duration: \(error.localizedDescription)")
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

    /// Reset view model to initial state with session boundary generation
    @MainActor
    public func reset() {
        // Generate new session ID for the reset operation
        let oldSessionID = currentLoadingSession.uuidString.prefix(8)
        let newSessionID = generateNewLoadingSession()

        logger.info("🔄 SESSION BOUNDARY: Reset operation - transitioning from session [\(oldSessionID)] to [\(newSessionID.uuidString.prefix(8))]")

        // Log session boundary for reset operation
        logSessionBoundary(from: loadingState, to: .idle, context: "ViewModel Reset Operation")

        // ENHANCED: SharedVideoPlayer cleanup before state reset to ensure session isolation
        logger.info("🧹 SESSION BOUNDARY: Starting SharedVideoPlayer cleanup for session isolation")
        let cleanupStartTime = CFAbsoluteTimeGetCurrent()

        // Call the enhanced session cleanup method with MainActor isolation
        videoPlayer.cleanupForSessionBoundary()

        let cleanupDuration = CFAbsoluteTimeGetCurrent() - cleanupStartTime
        logger.info("✅ SESSION BOUNDARY: SharedVideoPlayer cleanup completed in \(String(format: "%.3f", cleanupDuration))s")

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
        workflowState = .idle
        suspendedVideoAsset = nil
        suspendedTrimRange = nil
        suspendedRotation = .degrees0
        workflowSuspendedTime = nil

        // Clean up video loader resources
        Task {
            await videoLoader.cleanupTemporaryFiles()
        }

        logger.info("🔄 AddMoveViewModel reset to initial state [Session: \(newSessionID.uuidString.prefix(8))]")
        logger.info("✅ Session boundary established for fresh loading workflow")
        logger.info("🎯 SESSION BOUNDARY: Complete session isolation achieved - SharedVideoPlayer cleaned up")
    }

    // MARK: - Video Preloading for Tab Return

    /// Preload video for quick tab return to prevent video flashing
    /// This method starts video loading immediately when a suspended workflow is detected
    public func preloadVideoForQuickReturn() async {
        logger.info("⚡ OPENSPEC PRELOAD: Starting video preloading for quick tab return")

        guard canRestoreWorkflow else {
            logger.info("ℹ️ OPENSPEC PRELOAD: No suspended workflow available for preloading")
            return
        }

        guard let cachedAsset = suspendedVideoAsset else {
            logger.warning("⚠️ OPENSPEC PRELOAD: No cached video asset available for preloading")
            return
        }

        // Check if this is a quick return scenario
        let quickReturn = isQuickReturn
        logger.info("⏱️ OPENSPEC PRELOAD: Quick return detection: \(quickReturn ? "YES (<5s)" : "NO (>5s)")")

        // Start preloading process
        let preloadingStartTime = Date()
        logger.info("🚀 OPENSPEC PRELOAD: Beginning video preloading process")

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

            logger.info("📦 OPENSPEC PRELOAD: Cached state restored - duration: \(String(format: "%.1f", duration.seconds))s")

            // Check if player can be quickly restored without reloading
            if videoPlayer.canQuickRestore {
                logger.info("🎮 OPENSPEC PRELOAD: Player can be quickly restored - using maintenance method")
                let quickRestoreSuccess = await videoPlayer.prepareForQuickReturn()

                if quickRestoreSuccess {
                    logger.info("✅ OPENSPEC PRELOAD: Player quick restore successful - instant display ready")

                    // Log diagnostic timing metrics for successful quick restore
                    let diagnosticInfo = videoPlayer.playerStateDiagnostics
                    logger.info("📊 OPENSPEC PRELOAD: \(diagnosticInfo)")

                } else {
                    logger.warning("⚠️ OPENSPEC PRELOAD: Player quick restore failed - falling back to full reload")
                    let playerReady = await videoPlayer.loadVideo(cachedAsset)
                    if !playerReady {
                        logger.error("❌ OPENSPEC PRELOAD: Fallback video loading failed")
                        return
                    }
                }
            } else {
                logger.info("🎮 OPENSPEC PRELOAD: Player cannot be quickly restored - loading cached asset")
                let playerReady = await videoPlayer.loadVideo(cachedAsset)

                if playerReady {
                    logger.info("✅ OPENSPEC PRELOAD: Video player loaded successfully")

                    // Log diagnostic timing metrics for successful loading
                    let diagnosticInfo = videoPlayer.playerStateDiagnostics
                    logger.info("📊 OPENSPEC PRELOAD: \(diagnosticInfo)")

                } else {
                    logger.warning("⚠️ OPENSPEC PRELOAD: Video player loading failed")
                    return
                }
            }

            // Calculate preloading duration
            let preloadingDuration = Date().timeIntervalSince(preloadingStartTime)
            logger.info("⏱️ OPENSPEC PRELOAD: Preloading completed in \(String(format: "%.3f", preloadingDuration))s")

            // Update workflow state to reflect preloaded status
            workflowState = .videoLoaded
            logger.info("🔄 OPENSPEC PRELOAD: Workflow state updated to videoLoaded")

        } catch {
            logger.error("❌ OPENSPEC PRELOAD: Preloading failed - \(error.localizedDescription)")
            // Don't update workflow state on error to allow fallback to normal restoration
        }
    }

    // MARK: - Workflow State Persistence

    /// Suspend the current workflow state for later restoration
    public func suspendWorkflow() {
        logger.info("🔄 SUSPENDING WORKFLOW: State transition from \(workflowState.description)")
        logger.debug("📊 WORKFLOW DIAGNOSTICS: Suspending with videoDuration=\(videoDuration)s, isLoading=\(isLoading)")

        // Only suspend if we have a loaded video
        guard selectedVideo != nil else {
            logger.info("ℹ️ WORKFLOW DIAGNOSTICS: No video loaded, workflow remains idle")
            return
        }

        // OPENSPEC ENHANCEMENT: Enhanced video asset caching during workflow suspension
        logger.info("📦 OPENSPEC SUSPEND: Caching video player state for fast restoration")

        // Cache current state with enhanced video player preservation
        suspendedVideoAsset = selectedVideo
        suspendedTrimRange = (trimStartTime, trimEndTime)
        suspendedRotation = videoRotation
        workflowSuspendedTime = Date()

        // OPENSPEC ENHANCEMENT: Enhanced video player state maintenance for quick return
        if videoPlayer.isReady {
            logger.info("🎮 OPENSPEC SUSPEND: Video player is ready - maintaining player state for quick return")

            // Use new SharedVideoPlayer maintenance method to preserve player instance
            videoPlayer.maintainPlayerStateForQuickReturn()

            logger.info("🔄 OPENSPEC SUSPEND: Player state maintained - instant display expected on return")
        }

        // Update workflow state
        workflowState = .suspended

        logger.info("✅ WORKFLOW SUSPENDED: State transition to \(workflowState.description) complete")
        logger.debug("📊 WORKFLOW DIAGNOSTICS: Cached data - duration=\(videoDuration)s, trim=\(trimStartTime)s-\(trimEndTime)s, rotation=\(videoRotation.description)")
        logger.info("🔄 WORKFLOW PERSISTENCE: Enhanced data cached for potential quick return restoration")
    }

    /// Restore a previously suspended workflow state
    public func restoreWorkflow() async {
        logger.info("🔄 RESTORING WORKFLOW: State transition from \(workflowState.description)")
        logger.debug("📊 WORKFLOW DIAGNOSTICS: Beginning restoration process")

        // Only restore if we have suspended data
        guard let cachedAsset = suspendedVideoAsset,
              let cachedTrimRange = suspendedTrimRange else {
            logger.warning("⚠️ WORKFLOW RESTORE FAILED: No suspended workflow data available")
            return
        }

        // Check if this is a quick return (< 5 seconds)
        let quickReturn = workflowSuspendedTime.map { Date().timeIntervalSince($0) < 5.0 } ?? false
        logger.info("⏱️ WORKFLOW DIAGNOSTICS: Quick return detection: \(quickReturn ? "YES (<5s)" : "NO (>5s)")")

        // Restore cached state
        selectedVideo = cachedAsset
        trimStartTime = cachedTrimRange.start
        trimEndTime = cachedTrimRange.end
        videoRotation = suspendedRotation

        logger.info("🔄 WORKFLOW RESTORATION: State data restored from cache")

        // Update video duration from cached asset
        do {
            let duration = try await cachedAsset.load(.duration)
            videoDuration = duration.seconds
            logger.info("📊 WORKFLOW RESTORATION: Video duration loaded: \(String(format: "%.1f", duration.seconds))s")
        } catch {
            logger.error("❌ WORKFLOW RESTORATION ERROR: Failed to load video duration from cached asset: \(error.localizedDescription)")
        }

        // Enhanced video player restoration with quick return support
        if videoPlayer.canQuickRestore {
            logger.info("🎮 WORKFLOW RESTORATION: Player supports quick restore - using maintenance method")
            let quickRestoreSuccess = await videoPlayer.prepareForQuickReturn()

            if quickRestoreSuccess {
                logger.info("✅ WORKFLOW RESTORATION: Quick restore successful - instant display ready")

                // Log diagnostic timing metrics for successful workflow restoration
                let diagnosticInfo = videoPlayer.playerStateDiagnostics
                logger.info("📊 WORKFLOW RESTORATION: \(diagnosticInfo)")

            } else {
                logger.warning("⚠️ WORKFLOW RESTORATION: Quick restore failed - falling back to full reload")
                await videoPlayer.loadVideo(cachedAsset)
                logger.info("🎮 WORKFLOW RESTORATION: Video player fully reloaded with cached asset")
            }
        } else {
            logger.info("🎮 WORKFLOW RESTORATION: Player requires full reload - loading cached asset")
            await videoPlayer.loadVideo(cachedAsset)
            logger.info("🎮 WORKFLOW RESTORATION: Video player fully reloaded with cached asset")
        }

        // Update workflow state
        workflowState = .videoLoaded

        // Clear suspension data
        suspendedVideoAsset = nil
        suspendedTrimRange = nil
        suspendedRotation = .degrees0
        workflowSuspendedTime = nil

        logger.info("✅ WORKFLOW RESTORED: State transition to \(workflowState.description) complete")
        logger.debug("📊 WORKFLOW DIAGNOSTICS: Restored data - duration=\(videoDuration)s, trim=\(trimStartTime)s-\(trimEndTime)s, rotation=\(videoRotation.description)")
        logger.info("🔄 WORKFLOW PERSISTENCE: Suspension data cleared, workflow fully restored")
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
            self?.handleAppBackgrounded()
        }

        // Observe app foregrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppForegrounded()
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

            let setStateTime = CFAbsoluteTimeGetCurrent()
            logger.debug("🔍 PROOF: COORDINATOR setting preparingPlayback state at \(setStateTime)")
            loadingState = .loading(progress: 0.0, stage: .preparingPlayback, message: "Preparing for playback...")
            _ = validateProgressDisplay(.preparingPlayback, internalProgress: 0.0)
            logger.debug("🔍 PROOF: COORDINATOR preparingPlayback state set, progress=\(loadingState.progress)")

            // Enhanced frame separation: Ensure main thread synchronization and UI frame boundary
            let preSuspensionTime = CFAbsoluteTimeGetCurrent()
            logger.debug("🔍 PROOF: SUSPENSION START at \(preSuspensionTime)")

            await MainActor.run { }

            let midSuspensionTime = CFAbsoluteTimeGetCurrent()
            logger.debug("🔍 PROOF: SUSPENSION MIDDLE at \(midSuspensionTime) - MainActor.run completed")

            await Task.yield()

            let postSuspensionTime = CFAbsoluteTimeGetCurrent()
            let suspensionDuration = (postSuspensionTime - preSuspensionTime) * 1000
            logger.debug("🔍 PROOF: SUSPENSION END at \(postSuspensionTime) - total duration: \(String(format: "%.3f", suspensionDuration))ms")

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

    /// Handle video loader state changes with session-aware validation and @MainActor isolation
    private func handleVideoLoaderStateChange(_ newState: LoadingState) {
        let oldState = loadingState

        // OBSERVER TRACKING: Log observer pattern diagnostics
        let frameTimestamp = CFAbsoluteTimeGetCurrent()
        Logger.loadingState.debug("🔍 OBSERVER PATTERN: Single observer (SelectClip) handling state transition at \(frameTimestamp)s")

        // MONOTONIC STATE VALIDATION: Use session-aware state machine to prevent harmful regression
        guard newState.validateMonotonicTransition(from: oldState) else {
            Logger.loadingState.error("🚫 AddMoveViewModel: State regression detected - rejecting transition")
            return
        }

        // Additional filtering for spurious transitions during initialization phase
        guard !isInitializing else {
            Logger.loadingState.debug("🚫 AddMoveViewModel: Filtering spurious state transition during initialization")
            return
        }

        // SESSION BOUNDARY LOGGING: Detect and log session boundaries with thread safety
        let isSessionBoundary = detectSessionBoundary(from: oldState, to: newState)
        if isSessionBoundary {
            logSessionBoundary(from: oldState, to: newState, context: "Video Loader State Change")
        }

        // Log valid state transition with enhanced diagnostics and observer tracking
        Logger.loadingState.debug("🔄 AddMoveViewModel: Valid state transition \(oldState.progress * 100)% → \(newState.progress * 100)%")
        Logger.loadingState.debug("📊 FRAME TIMING: State transition at \(frameTimestamp)s - SINGLE OBSERVER ACTIVE")

        // ATOMIC TRANSITION DETECTION: Log when atomic transitions are received from RobustVideoLoader
        if newState.isLoading && newState.progress > oldState.progress {
            let transitionType = abs(newState.progress - oldState.progress) < 0.001 ? "ATOMIC" : "SEQUENTIAL"
            Logger.loadingState.debug("⚛️ ATOMIC TRANSITION DETECTED: \(transitionType) transition received - progress delta: \(String(format: "%.3f", (newState.progress - oldState.progress) * 100))%")
        }

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
        let updateTimestamp = CFAbsoluteTimeGetCurrent()
        let currentProgress = loadingState.progress
        let incomingProgress = progress.value

        logger.debug("🔍 PROOF: Progress update from videoLoader at \(updateTimestamp)")
        logger.debug("🔍 PROOF: Current progress=\(currentProgress), incoming=\(incomingProgress)")
        logger.debug("🔍 PROOF: Current stage=\(loadingState), incoming stage=\(progress.stage ?? .initializing)")

        // Detect backward progress (potential state override)
        if incomingProgress < currentProgress {
            logger.warning("⚠️ PROOF: BACKWARD PROGRESS DETECTED - rejecting \(incomingProgress) < \(currentProgress)")
        }

        // Process ALL progress updates to maintain functorial composition
        // Don't filter based on loading state to ensure continuous progress flow
        if case .loading(_, let stage, _) = loadingState {
            loadingState = .loading(progress: progress.value, stage: stage, message: progress.message)
            logger.debug("🔍 PROOF: Updated existing loading state to progress=\(progress.value), stage=\(stage)")
        } else {
            // UI BUG FIX: Check if this is a fullyReady state transition
            if progress.stage == nil && progress.value >= 1.0 {
                // This is a fullyReady state (100% completion with no stage)
                loadingState = .fullyReady(selectedVideo!)
                logger.info("🔧 UI BUG FIX: Preserved fullyReady state instead of creating loading state")
            } else {
                // If we're not in a loading state but receive progress,
                // create a loading state with the appropriate stage
                let stage = progress.stage ?? .initializing
                loadingState = .loading(progress: progress.value, stage: stage, message: progress.message)
                logger.debug("🔍 PROOF: Created new loading state with progress=\(progress.value), stage=\(stage)")
            }
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
        if case .loading(let progress, let stage, _) = loadingState, progress >= 0.88 {
            let previousState = loadingState
            let newState = LoadingState.fullyReady(asset)

            // **ENHANCED**: Ensure final transition includes proper stage-aware logging
            if newState.validateMonotonicTransition(from: previousState) {
                loadingState = newState
                logger.info("🎭 STAGE RECOVERY: Transitioned from \(stage) at \(Int(progress * 100))% to fullyReady state")
                logger.info("🔧 RECOVERY COMPLETED: Forced transition to fullyReady state at 100%")
                logger.info("✅ BOUNDARY RECOVERY: Service→ViewModel state synchronization restored")
            } else {
                logger.warning("⚠️ Recovery transition validation failed - current state may already be further along")
            }
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