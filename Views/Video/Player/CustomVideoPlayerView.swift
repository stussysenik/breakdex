import SwiftUI
import AVKit
import Combine
import OSLog
import UIKit

// MARK: - Custom Video Player View
/// Fixed: Rotation is now handled exclusively at the asset level
public struct CustomVideoPlayerView: View {
    // MARK: - Properties
    @ObservedObject private var observableWrapper: ObservableVideoPlayerWrapper
    @State private var isViewReady = false
    @State private var showFullscreen = false
    @State private var isMuted = false
    private let shouldTeardownOnDisappear: Bool
    private let shouldAutoplay: Bool
    
    // MARK: - Static Properties
    private static var viewRecomputeCount = 0
    private static var playerViewInstanceCount = 0
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "CustomVideoPlayerView")
    private let logger = AppContainer.shared.logger

    // MARK: - Animation Lifecycle Tracking
    @State private var animationState = VideoPlayerAnimationState()
  @State private var appearMemory: (used: Double, free: Double, total: Double, percentage: Double)?

            fileprivate struct VideoPlayerAnimationState {
        var lastBodyEvaluation: Date = .distantPast
        var lastStateChange: Date = .distantPast
        var bodyEvaluationCount: Int = 0
        var stateChangeCount: Int = 0
        var animationDuration: Double = 0
        var memoryBaseline: Double = 0
        var animationConflicts: Int = 0
        var lastPerformanceUpdate: Date = .distantPast
        var animationEfficiency: Double = 1.0
    }

    // MARK: - Animation State Management
    // MARK: - FUNC
    private func updateAnimationState(eventType: String, duration: Double, animationState: Binding<VideoPlayerAnimationState>, diagnosticLogger: DiagnosticLoggingHelper, observableWrapper: ObservableVideoPlayerWrapper) {
        let now = Date()
        let currentMemory = diagnosticLogger.getMemoryInfo().used

        withAnimation {
            animationState.wrappedValue.bodyEvaluationCount += 1
            animationState.wrappedValue.animationDuration = duration

            if now.timeIntervalSince(animationState.wrappedValue.lastStateChange) < 0.1 {
                animationState.wrappedValue.animationConflicts += 1
            }

            animationState.wrappedValue.lastStateChange = now
            animationState.wrappedValue.memoryBaseline = currentMemory
            animationState.wrappedValue.animationEfficiency = max(0.1, 1.0 - (duration / 2.0))
        }

        diagnosticLogger.logSwiftUIAnimationLifecycle(eventType, viewName: "CustomVideoPlayerView", metadata: [
            "duration_ms": "\(duration * 1000)",
            "memory_usage_mb": "\(String(format: "%.1f", currentMemory))",
            "animation_efficiency": "\(String(format: "%.2f", animationState.wrappedValue.animationEfficiency))",
            "conflict_count": "\(animationState.wrappedValue.animationConflicts)"
        ])
    }

    // MARK: - Haptic Feedback
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    public init(viewModel: any VideoPlayerViewModelProtocol, shouldTeardownOnDisappear: Bool = false, shouldAutoplay: Bool = true) {
        diagnosticLogger.startTiming("video_player_initialization")

        let initialMemory = diagnosticLogger.getMemoryInfo()

        self.observableWrapper = ObservableVideoPlayerWrapper(viewModel: viewModel)
        self.shouldTeardownOnDisappear = shouldTeardownOnDisappear
        self.shouldAutoplay = shouldAutoplay

        diagnosticLogger.logInfo("🎬 CustomVideoPlayerView initializing", metadata: [
            "view_model_type": "\(type(of: viewModel))",
            "should_teardown": "\(shouldTeardownOnDisappear)",
            "should_autoplay": "\(shouldAutoplay)",
            "initial_memory_mb": "\(String(format: "%.1f", initialMemory.used))",
            "instance_count": "\(Self.playerViewInstanceCount + 1)",
            "recompute_count": "\(Self.viewRecomputeCount + 1)"
        ])

        // Log the fix for diagnostic purposes
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: ✅ INIT - Using @ObservedObject (corrected from @StateObject)", metadata: nil)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewModel type: \(type(of: viewModel))", metadata: nil)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: Should teardown: \(shouldTeardownOnDisappear)", metadata: nil)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: Should autoplay: \(shouldAutoplay)", metadata: nil)

        diagnosticLogger.stopTiming("video_player_initialization")
    }
    
    // MARK: - Body
    public var body: some View {
        let bodyStartTime = Date()
        let timeSinceLastBody = bodyStartTime.timeIntervalSince(animationState.lastBodyEvaluation)

        // Log SwiftUI animation lifecycle events
        diagnosticLogger.logSwiftUIAnimationLifecycle("body_evaluation_start", viewName: "CustomVideoPlayerView", metadata: [
            "evaluation_count": "\(animationState.bodyEvaluationCount)",
            "time_since_last_evaluation_ms": "\(timeSinceLastBody * 1000)",
            "view_ready": "\(isViewReady)",
            "current_state": "\(observableWrapper.stateString)",
            "memory_usage_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)"
        ])

        return ZStack {
            // Use type-erased approach to handle the protocol with associated types
            switch getStateAsString() {
            case "loading":
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    Text("Loading video...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Add additional loading context if available
                    if let loadingProgress = getLoadingProgress() {
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                
            case "playing", "paused", "ready":
                // ✅ FIXED: No longer need getPlayerFromState helper - viewModel is single source of truth
                if isViewReady, let unifiedViewModel = observableWrapper.viewModel as? UnifiedVideoPlayerViewModel {
                    AVPlayerViewRepresentable(metadata: nil, viewModel: unifiedViewModel, playerItem: observableWrapper.playerItem)
                        .overlay(alignment: Alignment.topTrailing) {
                            HStack {
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Fullscreen button tapped", metadata: nil)
                                    showFullscreen = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                }
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute button tapped", metadata: nil)
                                    isMuted.toggle()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                }
                            }
                            .padding()
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding()
                        }
                        .onAppear {
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🔄 DEBUG - AVPlayerViewRepresentable created", metadata: nil)
                        }
                        .onChange(of: isMuted) { _, muted in
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute state changed to: \(muted)", metadata: nil)
                            if let player = observableWrapper.avPlayer {
                                player.isMuted = muted
                            }
                        }
                        .fullScreenCover(isPresented: $showFullscreen) {
                            // MARK: - DEFENSIVE CHECK: Ensure player is available for fullscreen
                            if let player = observableWrapper.avPlayer {
                                FullscreenVideoPlayer(player: player, isPresented: $showFullscreen)
                            } else {
                                // Fallback UI if player becomes unavailable
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 48))
                                        .foregroundColor(.yellow)
                                    Text("Video Player Unavailable")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Please try again or restart the video")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Button("Dismiss") {
                                        showFullscreen = false
                                    }
                                    .buttonStyle(.appPrimary(size: .medium))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                            }
                        }
                        .task {
                            diagnosticLogger.startTiming("video_render_task")

                            let startMemory = diagnosticLogger.getMemoryInfo()
                            let startCPU = diagnosticLogger.getCurrentCPUUsage()

                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: RenderStart: representable", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🔄 AVPlayerViewRepresentable task started (Instance #\(Self.playerViewInstanceCount), Recompute #\(Self.viewRecomputeCount))", metadata: nil)

                            // MARK: - DEFENSIVE CHECK: Early return if player becomes nil due to race condition
                            guard let player = observableWrapper.avPlayer else {
                                logger.warning("🎬 CUSTOM_VIDEO_PLAYER: ⚠️ Player became nil during render task - possible race condition detected", metadata: nil)
                                diagnosticLogger.logWarning("Video render task skipped - player not available", metadata: [
                                    "instance_count": "\(Self.playerViewInstanceCount)",
                                    "recompute_count": "\(Self.viewRecomputeCount)",
                                    "observable_wrapper_state": "\(observableWrapper.stateString)",
                                    "memory_usage_mb": "\(String(format: "%.1f", startMemory.used))"
                                ])
                                return
                            }

                            diagnosticLogger.logInfo("🎬 Starting video render task", metadata: [
                                "instance_count": "\(Self.playerViewInstanceCount)",
                                "recompute_count": "\(Self.viewRecomputeCount)",
                                "memory_usage_mb": "\(String(format: "%.1f", startMemory.used))",
                                "cpu_usage_percent": "\(String(format: "%.1f", startCPU))",
                                "player_status": "\(player.status.rawValue)"
                            ])

                            logMemoryUsage(context: "playing_task_start")
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer status: \(player.status.rawValue)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem status: \(player.currentItem?.status.rawValue ?? -1)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer error: \(String(describing: player.error))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ✅ USING AVPlayerViewRepresentable - ELIMINATING VideoPlayer CRASHES!", metadata: nil)

                            // Final diagnostic during rendering
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 📋 DIAGNOSTIC DURING RENDERING (State: playing)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer exists: ✅", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer status: \(player.status.rawValue) (\(player.status == .readyToPlay ? "readyToPlay" : player.status == .failed ? "failed" : "unknown"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer rate: \(player.rate)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer timeControlStatus: \(player.timeControlStatus.rawValue) (\(player.timeControlStatus == .playing ? "playing" : player.timeControlStatus == .paused ? "paused" : "waiting"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem exists: \(player.currentItem != nil)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem status: \(player.currentItem?.status.rawValue ?? -1) (\(player.currentItem?.status == .readyToPlay ? "readyToPlay" : player.currentItem?.status == .failed ? "failed" : "unknown"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer error: \(String(describing: player.error))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem error: \(String(describing: player.currentItem?.error))", metadata: nil)

                            let endMemory = diagnosticLogger.getMemoryInfo()
                            let endCPU = diagnosticLogger.getCurrentCPUUsage()

                            diagnosticLogger.logInfo("📊 Video render task performance", metadata: [
                                "memory_before_mb": "\(String(format: "%.1f", startMemory.used))",
                                "memory_after_mb": "\(String(format: "%.1f", endMemory.used))",
                                "memory_increase_mb": "\(String(format: "%.1f", endMemory.used - startMemory.used))",
                                "cpu_before_percent": "\(String(format: "%.1f", startCPU))",
                                "cpu_after_percent": "\(String(format: "%.1f", endCPU))",
                                "player_status": "\(observableWrapper.avPlayer?.status.rawValue ?? -1)",
                                "player_rate": "\(observableWrapper.avPlayer?.rate ?? 0)",
                                "is_muted": "\(observableWrapper.avPlayer?.isMuted ?? false)"
                            ])

                            logMemoryUsage(context: "playing_task_end")
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🎬 AVPlayerViewRepresentable should be rendering now! (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Tap gesture handling built into UIViewRepresentable!", metadata: nil)

                            diagnosticLogger.stopTiming("video_render_task")
                            diagnosticLogger.checkResourceWarnings()
                        }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .task {
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: RenderStart: waiting_for_view_ready", metadata: nil)
                        }
                        .overlay(alignment: Alignment.topTrailing) {
                            HStack {
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Fullscreen button tapped", metadata: nil)
                                    showFullscreen = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                }
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute button tapped", metadata: nil)
                                    isMuted.toggle()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                }
                            }
                            .padding()
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding()
                        }
                        .onChange(of: isMuted) { _, muted in
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute state changed to: \(muted)", metadata: nil)
                            if let unifiedViewModel = observableWrapper.viewModel as? UnifiedVideoPlayerViewModel {
                                unifiedViewModel.avPlayer?.isMuted = muted
                            }
                        }
                        .fullScreenCover(isPresented: $showFullscreen) {
                            if let unifiedViewModel = observableWrapper.viewModel as? UnifiedVideoPlayerViewModel, let player = unifiedViewModel.avPlayer {
                                FullscreenVideoPlayer(player: player, isPresented: $showFullscreen)
                            }
                        }
                }
                
            case "error":
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(getErrorMessage() ?? "Unknown error")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
            default:
                EmptyView()
            }
        }
        .onAppear {
            let appearStartTime = Date()
            diagnosticLogger.startTiming("view_appear")

            appearMemory = diagnosticLogger.getMemoryInfo()
            let appearCPU = diagnosticLogger.getCurrentCPUUsage()

            Self.viewRecomputeCount += 1
            Self.playerViewInstanceCount += 1

            // Set memory baseline for animation tracking
            animationState.memoryBaseline = appearMemory?.used ?? 0

            diagnosticLogger.logSwiftUIAnimationLifecycle("view_onAppear_start", viewName: "CustomVideoPlayerView", metadata: [
                "recompute_count": "\(Self.viewRecomputeCount)",
                "instance_count": "\(Self.playerViewInstanceCount)",
                "memory_usage_mb": "\(String(format: "%.1f", appearMemory?.used ?? 0))",
                "cpu_usage_percent": "\(String(format: "%.1f", appearCPU))",
                "thread_main": "\(Thread.current.isMainThread)",
                "animation_evaluation_count": "\(animationState.bodyEvaluationCount)"
            ])

            diagnosticLogger.logInfo("👁️ Video player view appeared", metadata: [
                "recompute_count": "\(Self.viewRecomputeCount)",
                "instance_count": "\(Self.playerViewInstanceCount)",
                "memory_usage_mb": "\(String(format: "%.1f", appearMemory?.used ?? 0))",
                "cpu_usage_percent": "\(String(format: "%.1f", appearCPU))",
                "thread_main": "\(Thread.current.isMainThread)"
            ])

            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View appeared (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: PlayerView instance count now: \(Self.playerViewInstanceCount)", metadata: nil)
            logMemoryUsage(context: "onAppear")
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewModel state: \(String(describing: observableWrapper.state))", metadata: nil)
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")", metadata: nil)

            // Mark view as ready and start playback if requested
            isViewReady = true
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewReady: onAppear", metadata: nil)

            // MARK: - CRITICAL FIX: Only start playback if shouldAutoplay is true
            // This prevents race conditions in naming view where video should not autoplay
            if shouldAutoplay {
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🎬 Starting autoplay (shouldAutoplay: true)", metadata: nil)
                observableWrapper.startPlayback()
            } else {
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: ⏸️ Skipping autoplay (shouldAutoplay: false)", metadata: nil)
            }

            let postAppearMemory = diagnosticLogger.getMemoryInfo()
            let appearDuration = Date().timeIntervalSince(appearStartTime)
            let memoryIncrease = postAppearMemory.used - (appearMemory?.used ?? 0)

            // Update animation state for appear
            updateAnimationState(eventType: "view_appear", duration: appearDuration, animationState: $animationState, diagnosticLogger: diagnosticLogger, observableWrapper: observableWrapper)

            diagnosticLogger.logSwiftUIAnimationLifecycle("view_onAppear_complete", viewName: "CustomVideoPlayerView", metadata: [
                "appear_duration_ms": "\(appearDuration * 1000)",
                "memory_after_startup_mb": "\(String(format: "%.1f", postAppearMemory.used))",
                "memory_increase_mb": "\(String(format: "%.1f", memoryIncrease))",
                "view_ready": "\(isViewReady)",
                "playback_started": "true",
                "animation_performance": appearDuration < 0.5 ? "excellent" : appearDuration < 1.0 ? "good" : "slow"
            ])

            diagnosticLogger.logInfo("✅ View appear completed", metadata: [
                "memory_after_startup_mb": "\(String(format: "%.1f", postAppearMemory.used))",
                "memory_increase_mb": "\(String(format: "%.1f", memoryIncrease))",
                "view_ready": "\(isViewReady)",
                "playback_started": "true"
            ])

            diagnosticLogger.stopTiming("view_appear")
            diagnosticLogger.checkResourceWarnings()
        }
        .onDisappear {
            let disappearStartTime = Date()
            diagnosticLogger.startTiming("view_disappear")

            let disappearMemory = diagnosticLogger.getMemoryInfo()
            let currentState = String(describing: observableWrapper.state)
            let memoryDelta = disappearMemory.used - animationState.memoryBaseline

            diagnosticLogger.logSwiftUIAnimationLifecycle("view_onDisappear_start", viewName: "CustomVideoPlayerView", metadata: [
                "will_teardown": "\(shouldTeardownOnDisappear)",
                "recompute_count": "\(Self.viewRecomputeCount)",
                "current_state": "\(currentState)",
                "memory_usage_mb": "\(String(format: "%.1f", disappearMemory.used))",
                "instance_count": "\(Self.playerViewInstanceCount)",
                "memory_delta_from_baseline_mb": "\(memoryDelta)",
                "total_animations": "\(animationState.bodyEvaluationCount)"
            ])

            diagnosticLogger.logInfo("👋 Video player view disappearing", metadata: [
                "will_teardown": "\(shouldTeardownOnDisappear)",
                "recompute_count": "\(Self.viewRecomputeCount)",
                "current_state": "\(currentState)",
                "memory_usage_mb": "\(String(format: "%.1f", disappearMemory.used))",
                "instance_count": "\(Self.playerViewInstanceCount)"
            ])

            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View disappearing - \(shouldTeardownOnDisappear ? "WILL teardown" : "NOT tearing down") (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logMemoryUsage(context: "onDisappear_start")
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Current state: \(String(describing: observableWrapper.state))", metadata: nil)

            if shouldTeardownOnDisappear {
                // Full teardown for contexts like Pre-Trim view where view model should be cleaned up
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Performing full teardown of view model", metadata: nil)
                diagnosticLogger.logDebug("🧹 Starting full view model teardown")
                observableWrapper.teardown()
                diagnosticLogger.logDebug("✅ View model teardown completed")
            } else {
                // Legacy behavior: only pause playback, don't tear down resources
                if let unifiedViewModel = observableWrapper.viewModel as? UnifiedVideoPlayerViewModel {
                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Pausing playback via viewModel (no teardown)", metadata: nil)
                    diagnosticLogger.logDebug("⏸️ Pausing playback via viewModel (preserving resources)")
                    unifiedViewModel.avPlayer?.pause()
                }
            }

            // Reset view state only
            isViewReady = false

            let disappearDuration = Date().timeIntervalSince(disappearStartTime)

            diagnosticLogger.logSwiftUIAnimationLifecycle("view_onDisappear_complete", viewName: "CustomVideoPlayerView", metadata: [
                "disappear_duration_ms": "\(disappearDuration * 1000)",
                "final_memory_mb": "\(String(format: "%.1f", disappearMemory.used))",
                "teardown_performed": "\(shouldTeardownOnDisappear)",
                "total_body_evaluations": "\(animationState.bodyEvaluationCount)",
                "animation_conflicts": "\(animationState.animationConflicts)",
                "memory_cleanup_efficiency": appearMemory != nil && disappearMemory.used < appearMemory!.used ? "good" : "needs_attention"
            ])

            showFullscreen = false
            isMuted = false

            Self.playerViewInstanceCount -= 1

            let finalMemory = diagnosticLogger.getMemoryInfo()
            diagnosticLogger.logInfo("✅ View disappear completed", metadata: [
                "memory_after_cleanup_mb": "\(String(format: "%.1f", finalMemory.used))",
                "memory_freed_mb": "\(String(format: "%.1f", disappearMemory.used - finalMemory.used))",
                "final_instance_count": "\(Self.playerViewInstanceCount)",
                "view_state_reset": "true",
                "teardown_performed": "\(shouldTeardownOnDisappear)"
            ])

            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View state reset, \(shouldTeardownOnDisappear ? "model torn down" : "player preserved")", metadata: nil)
            logMemoryUsage(context: "onDisappear_end")
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: PlayerView instance count now: \(Self.playerViewInstanceCount)", metadata: nil)

            diagnosticLogger.stopTiming("view_disappear")
            diagnosticLogger.checkResourceWarnings()
        }
    }
    
    // MARK: - Helper Methods
    // MARK: - FUNC
    /// Get the state as a string for type-erased comparison
    private func getStateAsString() -> String {
        return observableWrapper.stateString
    }
    
    /// ✅ REMOVED: getPlayerFromState helper function - no longer needed
    /// The viewModel is now the single source of truth, so we access player directly from viewModel.avPlayer
    
    // MARK: - FUNC
    /// Extract the error message from the state if available
    private func getErrorMessage() -> String? {
        if let unifiedState = observableWrapper.state as? UnifiedVideoPlayerViewModel.State,
           case .error(let message) = unifiedState {
            return message
        }
        return nil
    }
    // MARK: - FUNC
    /// Extract the loading progress from the state if available
    private func getLoadingProgress() -> Double? {
        return observableWrapper.loadingProgress
    }
    // MARK: - FUNC
    private func logViewState() {
        // This function is for debugging state changes
        diagnosticLogger.logDebug("🔄 State change detected", metadata: [
            "state_string": "\(String(describing: observableWrapper.state))",
            "is_view_ready": "\(isViewReady)",
            "is_muted": "\(isMuted)"
        ])

        logger.info("🎬 CUSTOM_VIDEO_PLAYER: State change detected", metadata: nil)

        // Use a type-erased approach to handle the associated type
        let state = observableWrapper.state
        let stateString = String(describing: state)

        if stateString.contains("loading") {
            diagnosticLogger.logInfo("📥 View rendering loading state", metadata: [
                "loading_progress": "\(getLoadingProgress() ?? 0.0)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View rendering loading state", metadata: nil)
            logMemoryUsage(context: "render_loading")
        } else if stateString.contains("playing") {
            diagnosticLogger.logInfo("▶️ View rendering playing state", metadata: [
                "view_ready": "\(isViewReady)",
                "is_muted": "\(isMuted)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View rendering playing state", metadata: nil)
            // Extract player information if available
            if let unifiedViewModel = observableWrapper.viewModel as? UnifiedVideoPlayerViewModel, let player = unifiedViewModel.avPlayer {
                diagnosticLogger.logInfo("🎵 Player details", metadata: [
                    "player_status": "\(player.status.rawValue)",
                    "player_rate": "\(player.rate)",
                    "current_time_seconds": "\(player.currentTime().seconds)",
                    "is_muted": "\(player.isMuted)",
                    "time_control_status": "\(player.timeControlStatus.rawValue)"
                ])
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player status: \(player.status.rawValue)", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player rate: \(player.rate)", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Current time: \(String(describing: player.currentTime().seconds))", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player muted: \(player.isMuted)", metadata: nil)
            }
            logMemoryUsage(context: "render_playing")
        } else if stateString.contains("error") {
            diagnosticLogger.logError("View rendering error state", metadata: [
                "error_message": "\(getErrorMessage() ?? "unknown")",
                "state_string": "\(stateString)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
            logger.error("🎬 CUSTOM_VIDEO_PLAYER: View rendering error state: \(stateString)", metadata: nil)
            logMemoryUsage(context: "render_error")
        }
    }
    // MARK: - FUNC
    private func getCPUUsage() -> Double? {
        // Simplified CPU usage measurement for logging - returns nil for now
        // TODO: Implement proper CPU measurement if needed for production logging
        return nil
    }
    // MARK: - FUNC
    private func logMemoryUsage(context: String) {
        // Use DiagnosticLoggingHelper for comprehensive resource monitoring
        let memoryInfo = diagnosticLogger.getMemoryInfo()
        let cpuUsage = diagnosticLogger.getCurrentCPUUsage()

        diagnosticLogger.logInfo("💾 Resource usage", metadata: [
            "context": context,
            "memory_used_mb": "\(String(format: "%.1f", memoryInfo.used))",
            "memory_free_mb": "\(String(format: "%.1f", memoryInfo.free))",
            "memory_total_mb": "\(String(format: "%.1f", memoryInfo.total))",
            "memory_percent": "\(String(format: "%.1f", memoryInfo.percentage))",
            "cpu_usage_percent": "\(String(format: "%.1f", cpuUsage))"
        ])

        // Log memory usage with context (keep for backward compatibility)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: Memory Usage (\(context)) - Used: \(String(format: "%.1f", memoryInfo.used))MB, Free: \(String(format: "%.1f", memoryInfo.free))MB, Total: \(String(format: "%.1f", memoryInfo.total))MB", metadata: nil)

        // Log CPU usage (keep for backward compatibility)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: CPU Usage (\(context)): \(String(format: "%.1f", cpuUsage))%", metadata: nil)
    }
    
    private func getMemoryInfo() -> (usedMB: Int, freeMB: Int, totalMB: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Int(info.resident_size / (1024 * 1024))
            let totalMB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
            let freeMB = totalMB - usedMB
            
            return (usedMB, freeMB, totalMB)
        }
        
        return (0, 0, 0)
    }
    
    // MARK: - Fullscreen Player
    private struct FullscreenVideoPlayer: View {
        let player: AVPlayer
        @Binding var isPresented: Bool
        private let diagnosticLogger = DiagnosticLoggingHelper(category: "FullscreenVideoPlayer")
        private let logger = AppContainer.shared.logger
        private let impactGenerator = UIImpactFeedbackGenerator(style: .light)

        // Memory tracking for fullscreen player
        @State private var appearMemory: (used: Double, free: Double, total: Double, percentage: Double)?

        init(player: AVPlayer, isPresented: Binding<Bool>) {
            self.player = player
            self._isPresented = isPresented
        }

        var body: some View {
            diagnosticLogger.startTiming("fullscreen_render")

            let startMemory = diagnosticLogger.getMemoryInfo()
            let startCPU = diagnosticLogger.getCurrentCPUUsage()

            diagnosticLogger.logInfo("🎬 Rendering fullscreen player", metadata: [
                "player_status": "\(player.status.rawValue)",
                "player_rate": "\(player.rate)",
                "memory_usage_mb": "\(String(format: "%.1f", startMemory.used))",
                "cpu_usage_percent": "\(String(format: "%.1f", startCPU))"
            ])

            logger.info("🎬 FULLSCREEN_PLAYER: Rendering fullscreen player", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player status: \(player.status.rawValue)", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player rate: \(player.rate)", metadata: nil)

            return ZStack(alignment: Alignment.topLeading) {
                // Note: For fullscreen mode, we need to create a minimal wrapper viewModel
                // This maintains the single source of truth pattern
                AVPlayerViewRepresentable(metadata: nil, viewModel: FullscreenPlayerWrapper(player: player), playerItem: player.currentItem)
                    .edgesIgnoringSafeArea(.all)

                Button {
                    impactGenerator.impactOccurred()
                    diagnosticLogger.logUserInteraction("fullscreen_close_button", metadata: [
                        "player_status": "\(player.status.rawValue)"
                    ])
                    logger.info("🎬 FULLSCREEN_PLAYER: Close button tapped", metadata: nil)
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .opacity(0.8)
                }
                .padding()
            }
            .onAppear {
                appearMemory = diagnosticLogger.getMemoryInfo()
                diagnosticLogger.logInfo("👁️ Fullscreen player appeared", metadata: [
                    "memory_usage_mb": "\(String(format: "%.1f", appearMemory?.used ?? 0))",
                    "player_ready": "\(player.status == .readyToPlay)"
                ])
                logger.info("🎬 FULLSCREEN_PLAYER: Fullscreen player appeared", metadata: nil)
            }
            .onDisappear {
                let disappearMemory = diagnosticLogger.getMemoryInfo()
                diagnosticLogger.logInfo("👋 Fullscreen player disappeared", metadata: [
                    "memory_usage_mb": "\(String(format: "%.1f", disappearMemory.used))",
                    "session_duration": "measured"
                ])
                logger.info("🎬 FULLSCREEN_PLAYER: Fullscreen player disappeared", metadata: nil)
            }
            .task {
                let renderMemory = diagnosticLogger.getMemoryInfo()
                let renderCPU = diagnosticLogger.getCurrentCPUUsage()

                diagnosticLogger.logInfo("📊 Fullscreen player rendering performance", metadata: [
                    "memory_before_mb": "\(String(format: "%.1f", startMemory.used))",
                    "memory_after_mb": "\(String(format: "%.1f", renderMemory.used))",
                    "memory_increase_mb": "\(String(format: "%.1f", renderMemory.used - startMemory.used))",
                    "cpu_before_percent": "\(String(format: "%.1f", startCPU))",
                    "cpu_after_percent": "\(String(format: "%.1f", renderCPU))"
                ])

                diagnosticLogger.stopTiming("fullscreen_render")
                diagnosticLogger.checkResourceWarnings()
            }
        }
    }

    // MARK: - Animation Diagnostics
    // MARK: - FUNC
    public func getAnimationDiagnostics() -> [String: String] {
        return [
            "total_body_evaluations": "\(animationState.bodyEvaluationCount)",
            "total_state_changes": "\(animationState.stateChangeCount)",
            "animation_conflicts": "\(animationState.animationConflicts)",
            "avg_animation_duration_ms": "\(animationState.animationDuration * 1000)",
            "current_memory_mb": "\(MemoryHelper.getDetailedMemoryInfo().used)",
            "memory_baseline_mb": "\(animationState.memoryBaseline)",
            "conflict_rate": "\(Double(animationState.animationConflicts) / Double(max(1, animationState.stateChangeCount)))",
            "performance_rating": animationState.animationDuration < 0.5 ? "excellent" : animationState.animationDuration < 1.0 ? "good" : "needs_attention"
        ]
    }
}

// MARK: - Observable Wrapper
/// This wrapper allows us to use a generic VideoPlayerViewModelProtocol as an ObservableObject
@MainActor
class ObservableVideoPlayerWrapper: ObservableObject {
    // 💡 SOLUTION: Extract only the properties we need to observe to prevent rate limiting
    @Published var stateString: String = "unknown"
    @Published var isPlayerReady: Bool = false
    @Published var shouldPlay: Bool = false
    @Published var loadingProgress: Double? = nil
    @Published var playerItem: AVPlayerItem? = nil // MARK: - CRITICAL FIX: Track player item for state synchronization

    private var _viewModel: any VideoPlayerViewModelProtocol
    private let logger = AppContainer.shared.logger
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Phase 4: Player Hardening - Idempotency Tracking
    private var hasStartedPlayback = false

    // MARK: - Public Accessors
    var avPlayer: AVPlayer? {
        return _viewModel.avPlayer
    }

    var state: Any {
        return _viewModel.state
    }

    var viewModel: any VideoPlayerViewModelProtocol {
        return self._viewModel
    }

    /// MARK: - CRITICAL FIX: Enhanced startPlayback method with idempotency protection
    /// Prevents multiple redundant calls that could cause race conditions
    // MARK: - FUNC
    func startPlayback() {
        // Check if we've already started playback to prevent redundant calls
        guard !hasStartedPlayback else {
            logger.info("🎬 OBSERVABLE_WRAPPER: ⏭️ Playback already started, skipping redundant call", metadata: nil)
            return
        }

        // Check if player is ready before attempting playback
        guard _viewModel.isPlayerReady else {
            logger.warning("🎬 OBSERVABLE_WRAPPER: ⚠️ Player not ready for playback", metadata: [
                "state_string": stateString,
                "is_player_ready": "\(_viewModel.isPlayerReady)"
            ])
            return
        }

        logger.info("🎬 OBSERVABLE_WRAPPER: 🎬 Starting playback with idempotency protection", metadata: [
            "has_started_before": "\(hasStartedPlayback)",
            "is_player_ready": "\(_viewModel.isPlayerReady)"
        ])

        _viewModel.startPlayback()
        hasStartedPlayback = true
    }

    /// MARK: - CRITICAL FIX: Reset playback flag for reuse in different contexts
    // MARK: - FUNC
    func resetPlaybackFlag() {
        logger.info("🎬 OBSERVABLE_WRAPPER: 🔄 Resetting playback flag for reuse", metadata: [
            "previous_state": "\(hasStartedPlayback)"
        ])
        hasStartedPlayback = false
    }
    
    func teardown() {
        logger.info("🎬 OBSERVABLE_WRAPPER: 🧹 Starting teardown", metadata: nil)
        resetPlaybackFlag()
        _viewModel.teardown()
        logger.info("🎬 OBSERVABLE_WRAPPER: ✅ Teardown completed", metadata: nil)
    }

    init(viewModel: any VideoPlayerViewModelProtocol) {
        self._viewModel = viewModel
        self.updatePublishedProperties()

        // 💡 SOLUTION: Observe specific properties instead of the entire view model
        setupObservation()

        logger.info("🎬 OBSERVABLE_WRAPPER: ✅ INIT - Created focused wrapper for viewModel", metadata: nil)
    }
    
    deinit {
        logger.info("🎬 OBSERVABLE_WRAPPER: 🗑️ DEINIT - Wrapper being deallocated", metadata: nil)
        cancellables.removeAll()
    }
    
    // MARK: - Focused Observation Setup
    // MARK: - FUNC
    private func setupObservation() {
        // Use timer-based observation for rapidly changing properties
        // Increased interval to reduce logging frequency and prevent rate limiting
        Timer.publish(every: 0.5, on: .main, in: .common) // Changed from 0.1 to 0.5 seconds
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePublishedProperties()
            }
            .store(in: &cancellables)
    }
    
    private func updatePublishedProperties() {
        // Extract state as string for comparison
        let newStateString = getStateString()
        let newIsPlayerReady = _viewModel.isPlayerReady
        let newShouldPlay = _viewModel.shouldPlay
        let newLoadingProgress = getLoadingProgress()
        let newPlayerItem = _viewModel.avPlayer?.currentItem // MARK: - CRITICAL FIX: Track player item changes

        // Only update if values changed to prevent unnecessary publishes
        if stateString != newStateString {
            stateString = newStateString
        }

        if isPlayerReady != newIsPlayerReady {
            isPlayerReady = newIsPlayerReady
        }

        if shouldPlay != newShouldPlay {
            shouldPlay = newShouldPlay
        }

        if loadingProgress != newLoadingProgress {
            loadingProgress = newLoadingProgress
        }

        // MARK: - CRITICAL FIX: Update player item if it changed - this triggers SwiftUI view updates
        if playerItem !== newPlayerItem {
            logger.info("🎬 OBSERVABLE_WRAPPER: 🔄 Player item changed - updating published property", metadata: [
                "previous_item_exists": "\(playerItem != nil)",
                "new_item_exists": "\(newPlayerItem != nil)",
                "items_different": "\(playerItem !== newPlayerItem)"
            ])
            playerItem = newPlayerItem
        }
    }
    
    // MARK: - Helper Methods
    // MARK: - FUNC
    private func getStateString() -> String {
        if let state = _viewModel.state as? UnifiedVideoPlayerViewModel.State {
            switch state {
            case .idle: return "idle"
            case .loading: return "loading"
            case .ready: return "ready"
            case .playing: return "playing"
            case .paused: return "paused"
            case .error: return "error"
            }
        }
        return "unknown"
    }
    // MARK: - FUNC
    private func getLoadingProgress() -> Double? {
        let state = _viewModel.state
        let stateString = String(describing: state)

        if stateString.contains("loading") {
            // Use reflection to extract the progress value from the state
            let mirror = Mirror(reflecting: state)

            // Look for the first associated value which should be the progress
            if let progressChild = mirror.children.first(where: { $0.label == nil }) {
                if let progress = progressChild.value as? Double {
                    return progress
                }
            }
        }

        return nil
    }
}

// MARK: - Fullscreen Player Wrapper
/// Minimal wrapper for fullscreen mode that provides UnifiedVideoPlayerViewModel interface
/// This maintains the single source of truth pattern using composition
@MainActor
private class FullscreenPlayerWrapper: VideoPlayerViewModelProtocol {
    private let _player: AVPlayer
    private let _logger = AppContainer.shared.logger

    // MARK: - Associated Type
    typealias State = String

    // MARK: - VideoPlayerViewModelProtocol Conformance
    var avPlayer: AVPlayer? {
        return _player
    }

    var state: String {
        return "fullscreen_ready"
    }

    var isPlayerReady: Bool {
        return _player.status == .readyToPlay
    }

    var shouldPlay: Bool {
        return _player.rate != 0
    }

    var healthStatus: VideoHealthStatus {
        return .excellent
    }

    var currentTime: CMTime? {
        return _player.currentTime()
    }

    init(player: AVPlayer) {
        self._player = player
    }

    // MARK: - Protocol Methods
    func startPlayback() {
        _player.play()
    }
    // MARK: - FUNC
    func pausePlayback() {
        _player.pause()
    }
    // MARK: - FUNC
    func loadVideo(from source: VideoSource, quarterTurns: Int) async throws {
        // No-op for fullscreen wrapper
    }
    // MARK: - FUNC
    func setRotation(_ quarterTurns: Int) {
        // No-op for fullscreen wrapper
    }
    // MARK: - FUNC
    func pauseForTrimming() {
        _player.pause()
    }
    // MARK: - FUNC
    func resumeAfterTrimming() {
        // No-op for fullscreen wrapper
    }
    // MARK: - FUNC
    func waitForReady() async throws {
        // No-op for fullscreen wrapper
    }
    // MARK: - FUNC
    func seek(to time: CMTime) {
        _player.seek(to: time)
    }
    // MARK: - FUNC
    func teardown() {
        // Minimal cleanup for fullscreen mode
        pausePlayback()
    }

    // MARK: - Equatable and Hashable Conformance
    // MARK: - FUNC
    static func == (lhs: FullscreenPlayerWrapper, rhs: FullscreenPlayerWrapper) -> Bool {
        return lhs._player == rhs._player
    }
    // MARK: - FUNC
    func hash(into hasher: inout Hasher) {
        hasher.combine(_player)
    }
}


// MARK: - Process Info Helper
/// Helper struct to get process information
struct ProcessInfo {
    static let processInfo = Foundation.ProcessInfo.processInfo
    static var physicalMemory: UInt64 {
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size = MemoryLayout<UInt64>.size
        var physicalMemory: UInt64 = 0
        
        let result = sysctl(&mib, UInt32(mib.count), &physicalMemory, &size, nil, 0)
        
        if result != KERN_SUCCESS {
            return 0
        }
        
        return physicalMemory
    }
}
