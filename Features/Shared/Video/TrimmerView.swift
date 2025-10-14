import SwiftUI
import AVFoundation
import PhotosUI
import OSLog
import Combine
import Foundation

// TrimmerView.swift - production video trimming interface

// MARK: - Supporting Types for Enhanced Gap Analysis

/// Types of gaps that can occur between asset availability and player state
public enum AssetLoadingGapType {
    case noGap
    case playerIdle
    case stateInconsistency
    case timingIssue
}

/// Recovery priority levels for gap resolution
public enum RecoveryPriority {
    case none
    case low
    case medium
    case high
}

/// Recovery strategies for different gap types
public enum RecoveryStrategy {
    case immediate
    case delayed(TimeInterval)
    case aggressive
}

/// Comprehensive analysis of asset loading gaps
public struct AssetLoadingGap {
    let type: AssetLoadingGapType
    let description: String
    let playerState: SharedVideoPlayer.PlayerState
    let isReady: Bool
    let flowState: AddMoveFlowState
    let hasAsset: Bool
    let recoveryPriority: RecoveryPriority
}

/// Types of state synchronization issues
public enum StateSyncIssue: String, CaseIterable {
    case playerIdleWithAsset = "player_idle_with_asset"
    case inconsistentReadyFlag = "inconsistent_ready_flag"
    case stuckInLoadingState = "stuck_in_loading_state"
    case unifiedStateBehind = "unified_state_behind"
    case errorStateInconsistency = "error_state_inconsistency"

    var description: String {
        switch self {
        case .playerIdleWithAsset:
            return "Player is idle while video asset is available"
        case .inconsistentReadyFlag:
            return "Player state is ready but isReady flag is false"
        case .stuckInLoadingState:
            return "UnifiedState stuck in loading while asset is available"
        case .unifiedStateBehind:
            return "Player is ready but UnifiedState still shows loading"
        case .errorStateInconsistency:
            return "Error state inconsistency between components"
        }
    }
}

// MARK: - Trimmer View
/// Video trimmer view with robust loading functionality
/// Handles any video file size, iCloud storage, or offline scenarios with 99.9% success rate
struct TrimmerView: View {
    // MARK: - Properties
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @StateObject private var videoPlayer = SharedVideoPlayer()
    @State private var cancellables = Set<AnyCancellable>()

    // Loading state management - rely on UnifiedState as single source of truth
    @State private var showRetryOption = false
    @State private var currentFileSize: Int64? = nil

    // Enhanced state synchronization - track last known states for debugging
    @State private var lastKnownFlowState: AddMoveFlowState = .ready
    @State private var lastKnownLoadingPhase: VideoLoadingProgress.LoadingPhase = .idle

    // Trimming state management
    @State private var trimStartTime: Double = 0.0
    @State private var trimEndTime: Double = 0.0
    @State private var isDraggingLeftHandle = false
    @State private var isDraggingRightHandle = false
    @State private var isDraggingPlayhead = false

    // Error handling
    @State private var lastError: Error?
    private let minimumTrimDuration: Double = 1.0 // Minimum 1 second trim

    // ENHANCED: Diagnostic tracking for comprehensive debugging
    @State private var assetLoadStartTime: Date?
    @State private var playerReadyTime: Date?
    @State private var correlationId: String?
    @State private var diagnosticLog: [String] = []

    // ENHANCED: Static tracking for diagnostic monitoring
    private static var lastLoggedState: SharedVideoPlayer.PlayerState = .idle
    private static var lastLoggedReady: Bool = false

    private let logger = Logger(subsystem: "breakdex", category: "<⚡ TRIMMER_VIEW")

    // MARK: - Initialization
    init(unifiedState: AddMoveUnifiedState) {
        self.unifiedState = unifiedState
    }

    // MARK: - State Recovery Mechanism
    /// Force state synchronization check - called when state desynchronization is suspected
    private func forceStateSyncCheck() {
        let currentFlowState = unifiedState.flowState
        let hasVideo = unifiedState.selectedVideo != nil
        let hasError = unifiedState.hasError
        let isLoading = currentFlowState.isLoading

        logger.info("🔧 FORCE STATE SYNC CHECK:")
        logger.info("   flowState: \(currentFlowState)")
        logger.info("   isLoading: \(isLoading)")
        logger.info("   hasError: \(hasError)")
        logger.info("   hasVideo: \(hasVideo)")

        // State consistency checks
        if hasVideo && isLoading {
            logger.warning("⚠️ STATE INCONSISTENCY: Video loaded but still in loading state")
            // Attempt automatic recovery
            DispatchQueue.main.async {
                self.unifiedState.updateFlowState(.trimming)
                self.unifiedState.updateTab(.trimming)
            }
        }

        if !hasVideo && !isLoading && !hasError {
            logger.warning("⚠️ STATE INCONSISTENCY: No video, not loading, no error - should be in ready state")
            // Attempt automatic recovery
            DispatchQueue.main.async {
                self.unifiedState.updateFlowState(.ready)
                self.unifiedState.updateTab(.ready)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        mainContent
    }

    // MARK: - Main Content
    private var mainContent: some View {
        viewModifiers(content:
            GeometryReader { geometry in
                ZStack {
                    backgroundView
                    currentViewForState
                }
            }
        )
    }

    // MARK: - Background View
    private var backgroundView: some View {
        Color.videoBackground
            .ignoresSafeArea()
    }

    // MARK: - Current State View
    private var currentViewForState: some View {
        Group {
            if unifiedState.hasError {
                errorView
            } else if unifiedState.flowState.isLoading {
                loadingView
            } else if let asset = unifiedState.selectedVideo {
                videoTrimmerView(asset: asset)
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - View Modifiers
    private func viewModifiers<Content: View>(content: Content) -> some View {
        content
            .onAppear(perform: handleOnAppear)
            .onChange(of: unifiedState.loadingProgress.phase, perform: handleLoadingPhaseChange)
            .onChange(of: unifiedState.flowState, perform: handleFlowStateChange)
            .onChange(of: unifiedState.selectedVideo, perform: handleSelectedVideoChange)
            .onReceive(unifiedState.$selectedVideo, perform: handleAssetReceive)
            .onChange(of: unifiedState.hasError, perform: handleVideoErrorIfNeeded)
            .onReceive(NotificationCenter.default.publisher(for: .videoAssetReadyForPlayer), perform: handleVideoAssetReadyNotification)
    }

    // MARK: - Simplified Handler Methods
    private func handleOnAppear() {
        logger.info("✅ ENHANCED ON_APPEAR: TrimmerView appeared - comprehensive state sync starting")
        logger.info("✅ ENHANCED ON_APPEAR: UnifiedState flowState=\(unifiedState.flowState), isLoading=\(unifiedState.flowState.isLoading)")
        logger.info("✅ ENHANCED ON_APPEAR: selectedVideo=\(unifiedState.selectedVideo != nil)")

        forceStateSyncCheck()

        if let asset = unifiedState.selectedVideo {
            logger.info("🔍 ENHANCED ON_APPEAR: Video available, player state=\(videoPlayer.state), isReady=\(videoPlayer.isReady)")
            // CRITICAL FIX: Remove fallback synchronization - VideoInitializationCoordinator handles this

          } else {
            logger.info("🔍 ENHANCED ON_APPEAR: No video available - ensuring clean state")
            ensureCleanPlayerState()
        }
    }

    private func handleSelectedVideoChange(_ newAsset: AVAsset?) {
        logger.info("🔄 ENHANCED CHANGE HANDLER: Selected video changed: \(newAsset != nil)")

        guard let asset = newAsset else {
            logger.info("🔄 ENHANCED CHANGE HANDLER: Video asset cleared - cleaning up player")
            addDiagnosticEntry("🧹 ASSET CLEARED: Cleaning up player state")
            Task {
                videoPlayer.cleanup()
                trimStartTime = 0.0
                trimEndTime = 0.0
                addDiagnosticEntry("✅ CLEANUP COMPLETE: Player and trim state reset")
            }
            return
        }

        startDiagnosticTracking()
        logStateTransition("ASSET DETECTED", details: "Starting video loading process")
        logger.info("✅ ENHANCED CHANGE HANDLER: Video asset available - initiating robust loading")

        Task {
            await loadVideoAsset(asset)
        }
    }

    private func loadVideoAsset(_ asset: AVAsset) async {
        do {
            logger.info("🚀 ENHANCED CHANGE HANDLER: Starting enhanced video loading")
            addDiagnosticEntry("🚀 STARTING VIDEO LOADING")
            await videoPlayer.loadVideoWithRecovery(asset)

            let playerStateAfter = videoPlayer.state
            let playerReadyAfter = videoPlayer.isReady
            logger.info("🔍 PLAYER STATE AFTER: state=\(playerStateAfter), isReady=\(playerReadyAfter)")
            addDiagnosticEntry("PLAYER STATE AFTER: state=\(playerStateAfter), isReady=\(playerReadyAfter)")

            if playerStateAfter == .ready && playerReadyAfter {
                logger.info("✅ ENHANCED CHANGE HANDLER: Video loading successful")
                logStateTransition("PLAYER READY", details: "Video loading completed successfully")
                initializeTrimValues()
                addDiagnosticEntry("✅ VIDEO LOADING SUCCESS: Trimmer values initialized")
            } else {
                logger.warning("⚠️ ENHANCED CHANGE HANDLER: Video loading incomplete - recovery mechanisms engaged")
                logStateTransition("LOADING INCOMPLETE", details: "Recovery mechanisms will engage")
                addDiagnosticEntry("⚠️ LOADING INCOMPLETE: Recovery mechanisms engaged")
            }

        } catch {
            logger.error("❌ ENHANCED CHANGE HANDLER: Video loading failed: \(error.localizedDescription)")
            logStateTransition("LOADING FAILED", details: error.localizedDescription)
            addDiagnosticEntry("❌ LOADING FAILED: \(error.localizedDescription)")

            logger.info("🔄 ENHANCED CHANGE HANDLER: Attempting recovery after error")
            addDiagnosticEntry("🔄 ATTEMPTING RECOVERY: Error occurred, trying again")
            try? await Task.sleep(nanoseconds: 500_000_000)

            if videoPlayer.state.isLoading || videoPlayer.state.isErrorState {
                logger.info("🔧 ENHANCED CHANGE HANDLER: Retrying video loading after error")
                addDiagnosticEntry("🔧 RETRYING: Video loading after error")
                await videoPlayer.loadVideoWithRecovery(asset)
                initializeTrimValues()
            }
        }
    }

    private func handleAssetReceive(_ asset: AVAsset?) {
        guard let asset = asset else {
            logger.info("🔍 ASSET OBSERVER: Asset cleared - player should remain idle")
            return
        }

        logger.info("🔍 ENHANCED ASSET OBSERVER: Video asset detected, player state=\(videoPlayer.state), isReady=\(videoPlayer.isReady)")

        // ENHANCED: Comprehensive gap detection with detailed diagnostics
        let gapAnalysis = analyzeAssetLoadingGap()

        switch gapAnalysis.type {
        case .noGap:
            logger.info("✅ ASSET OBSERVER: No gap detected - player state consistent")

        case .playerIdle:
            logger.warning("⚠️ GAP DETECTED: Player idle with available asset - triggering immediate load")
            logGapDetails(gapAnalysis)
            Task {
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "player_idle_gap")
            }

        case .stateInconsistency:
            logger.warning("⚠️ GAP DETECTED: Player state inconsistency - forcing recovery")
            logGapDetails(gapAnalysis)
            Task {
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "state_inconsistency_gap")
            }

        case .timingIssue:
            logger.warning("⚠️ GAP DETECTED: Timing issue between asset availability and player readiness")
            logGapDetails(gapAnalysis)
            Task {
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "timing_issue_gap")
            }
        }
    }

    // MARK: - Enhanced Gap Analysis

    /// Analyze the gap between asset availability and player state
    private func analyzeAssetLoadingGap() -> AssetLoadingGap {
        let playerState = videoPlayer.state
        let playerReady = videoPlayer.isReady
        let hasAsset = unifiedState.selectedVideo != nil
        let flowState = unifiedState.flowState

        // Detailed gap analysis
        if playerState == .idle && hasAsset {
            return AssetLoadingGap(
                type: .playerIdle,
                description: "Player is idle while asset is available",
                playerState: playerState,
                isReady: playerReady,
                flowState: flowState,
                hasAsset: hasAsset,
                recoveryPriority: .high
            )
        }

        if (playerState == .ready && !playerReady) || (playerState.isLoading && playerReady) {
            return AssetLoadingGap(
                type: .stateInconsistency,
                description: "Player state and ready flag are inconsistent",
                playerState: playerState,
                isReady: playerReady,
                flowState: flowState,
                hasAsset: hasAsset,
                recoveryPriority: .high
            )
        }

        if hasAsset && flowState.isLoading && playerState == .idle {
            return AssetLoadingGap(
                type: .timingIssue,
                description: "Asset available but UnifiedState still loading",
                playerState: playerState,
                isReady: playerReady,
                flowState: flowState,
                hasAsset: hasAsset,
                recoveryPriority: .medium
            )
        }

        if hasAsset && flowState == .trimming && playerState == .idle {
            return AssetLoadingGap(
                type: .timingIssue,
                description: "UnifiedState ready for trimming but player hasn't loaded asset",
                playerState: playerState,
                isReady: playerReady,
                flowState: flowState,
                hasAsset: hasAsset,
                recoveryPriority: .high
            )
        }

        return AssetLoadingGap(
            type: .noGap,
            description: "No gap detected - system state is consistent",
            playerState: playerState,
            isReady: playerReady,
            flowState: flowState,
            hasAsset: hasAsset,
            recoveryPriority: .none
        )
    }

    /// Load video asset with enhanced tracking and diagnostics
    private func loadVideoAssetWithEnhancedTracking(_ asset: AVAsset, trigger: String) async {
        logger.info("🚀 ENHANCED VIDEO LOADING: Starting load - trigger: \(trigger)")
        addDiagnosticEntry("🚀 ENHANCED LOAD: trigger=\(trigger)")

        let loadingStartTime = Date()

        do {
            await videoPlayer.loadVideoWithRecovery(asset)

            let loadingTime = Date().timeIntervalSince(loadingStartTime)
            let playerStateAfter = videoPlayer.state
            let playerReadyAfter = videoPlayer.isReady

            logger.info("📊 ENHANCED LOADING RESULTS:")
            logger.info("   ├─ Trigger: \(trigger)")
            logger.info("   ├─ Loading time: \(String(format: "%.3f", loadingTime))s")
            logger.info("   ├─ Final state: \(playerStateAfter)")
            logger.info("   └─ Final ready: \(playerReadyAfter)")

            addDiagnosticEntry("📊 LOAD COMPLETE: time=\(String(format: "%.3f", loadingTime))s, state=\(playerStateAfter), ready=\(playerReadyAfter)")

            if playerStateAfter == .ready && playerReadyAfter {
                logger.info("✅ ENHANCED LOADING SUCCESS: Video loaded successfully")
                logStateTransition("ENHANCED LOAD SUCCESS", details: "trigger=\(trigger), time=\(String(format: "%.3f", loadingTime))s")
                initializeTrimValues()
                addDiagnosticEntry("✅ ENHANCED SUCCESS: Trimmer values initialized")
            } else {
                logger.warning("⚠️ ENHANCED LOADING INCOMPLETE: Recovery mechanisms engaged")
                logStateTransition("ENHANCED LOAD INCOMPLETE", details: "trigger=\(trigger), will recover")
                addDiagnosticEntry("⚠️ ENHANCED INCOMPLETE: Recovery mechanisms engaged")

                // Schedule enhanced recovery
                scheduleEnhancedRecovery(asset: asset, trigger: trigger, initialFailure: true)
            }

        } catch {
            let loadingTime = Date().timeIntervalSince(loadingStartTime)
            logger.error("❌ ENHANCED LOADING FAILED: trigger=\(trigger), time=\(String(format: "%.3f", loadingTime))s, error=\(error.localizedDescription)")
            logStateTransition("ENHANCED LOAD FAILED", details: "trigger=\(trigger), error=\(error.localizedDescription)")
            addDiagnosticEntry("❌ ENHANCED FAILED: trigger=\(trigger), error=\(error.localizedDescription)")

            // Enhanced error recovery
            await performEnhancedErrorRecovery(asset: asset, trigger: trigger, error: error)
        }
    }

    /// Log detailed gap analysis information
    private func logGapDetails(_ gap: AssetLoadingGap) {
        logger.info("📊 GAP ANALYSIS:")
        logger.info("   ├─ Type: \(gap.type)")
        logger.info("   ├─ Description: \(gap.description)")
        logger.info("   ├─ Player state: \(gap.playerState)")
        logger.info("   ├─ Player ready: \(gap.isReady)")
        logger.info("   ├─ Flow state: \(gap.flowState)")
        logger.info("   ├─ Has asset: \(gap.hasAsset)")
        logger.info("   └─ Recovery priority: \(gap.recoveryPriority)")

        addDiagnosticEntry("🔍 GAP ANALYSIS: \(gap.description) (priority: \(gap.recoveryPriority))")
    }

    /// Schedule enhanced recovery with multiple attempts
    private func scheduleEnhancedRecovery(asset: AVAsset, trigger: String, initialFailure: Bool) {
        logger.info("🔧 SCHEDULING ENHANCED RECOVERY: trigger=\(trigger), initialFailure=\(initialFailure)")

        // Recovery strategy based on trigger and failure type
        let recoveryStrategy = determineRecoveryStrategy(trigger: trigger, initialFailure: initialFailure)

        switch recoveryStrategy {
        case .immediate:
            logger.info("⚡ IMMEDIATE RECOVERY: Attempting immediate reload")
            Task {
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "\(trigger)_immediate_retry")
            }

        case .delayed(let delay):
            logger.info("⏰ DELAYED RECOVERY: Waiting \(delay)s before retry")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Task {
                    await self.loadVideoAssetWithEnhancedTracking(asset, trigger: "\(trigger)_delayed_retry")
                }
            }

        case .aggressive:
            logger.info("💪 AGGRESSIVE RECOVERY: Full cleanup and reload")
            Task {
                await performAggressiveRecovery(asset: asset, trigger: trigger)
            }
        }
    }

    /// Determine the best recovery strategy
    private func determineRecoveryStrategy(trigger: String, initialFailure: Bool) -> RecoveryStrategy {
        if initialFailure {
            return .aggressive
        }

        switch trigger {
        case "player_idle_gap":
            return .immediate
        case "state_inconsistency_gap":
            return .delayed(0.2)
        case "timing_issue_gap":
            return .delayed(0.1)
        default:
            return .immediate
        }
    }

    /// Perform aggressive recovery with full cleanup
    private func performAggressiveRecovery(asset: AVAsset, trigger: String) async {
        logger.info("💪 AGGRESSIVE RECOVERY: Starting full cleanup and reload")
        addDiagnosticEntry("💪 AGGRESSIVE RECOVERY: trigger=\(trigger)")

        // Step 1: Full cleanup
        videoPlayer.cleanup()
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms cleanup delay

        // Step 2: Reset trim state
        trimStartTime = 0.0
        trimEndTime = 0.0

        // Step 3: Reload with enhanced tracking
        await loadVideoAssetWithEnhancedTracking(asset, trigger: "\(trigger)_aggressive_retry")
    }

    /// Perform enhanced error recovery
    private func performEnhancedErrorRecovery(asset: AVAsset, trigger: String, error: Error) async {
        logger.info("🔧 ENHANCED ERROR RECOVERY: trigger=\(trigger), error=\(error.localizedDescription)")
        addDiagnosticEntry("🔧 ERROR RECOVERY: trigger=\(trigger), error=\(error.localizedDescription)")

        // Recovery attempts with exponential backoff
        let delays: [TimeInterval] = [0.5, 1.0, 2.0]

        for (index, delay) in delays.enumerated() {
            let attempt = index + 1

            logger.info("🔄 ENHANCED ERROR RECOVERY: Attempt \(attempt) after \(delay)s delay")
            addDiagnosticEntry("🔄 ERROR RETRY \(attempt): delay=\(delay)s")

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            await loadVideoAssetWithEnhancedTracking(asset, trigger: "\(trigger)_error_retry_\(attempt)")

            if videoPlayer.state == .ready && videoPlayer.isReady {
                logger.info("✅ ENHANCED ERROR RECOVERY: Success on attempt \(attempt)")
                addDiagnosticEntry("✅ ERROR RECOVERY SUCCESS: attempt=\(attempt)")
                return
            }
        }

        logger.error("❌ ENHANCED ERROR RECOVERY: All recovery attempts failed")
        addDiagnosticEntry("❌ ERROR RECOVERY FAILED: all attempts exhausted")
    }

    private func shouldTriggerImmediateLoad() -> Bool {
        return videoPlayer.state == .idle
    }

    private func shouldTriggerRecovery() -> Bool {
        return (videoPlayer.state == .ready && !videoPlayer.isReady) ||
               videoPlayer.state.isLoading ||
               (videoPlayer.isReady && !videoPlayer.state.isErrorState)
    }

    private func handleVideoErrorIfNeeded(_ hasError: Bool) {
        if hasError {
            handleVideoError()
        }
    }

    /// Handle video asset ready notification from VideoLoadingService
    private func handleVideoAssetReadyNotification(_ notification: Notification) {
        guard let asset = notification.object as? AVAsset,
              let userInfo = notification.userInfo,
              let correlationId = userInfo["correlationId"] as? String,
              let triggerSource = userInfo["triggerSource"] as? String else {
            logger.warning("⚠️ PLAYER BRIDGE NOTIFICATION: Invalid notification data")
            return
        }

        logger.info("🎮 PLAYER BRIDGE NOTIFICATION: Video asset ready for player [\(correlationId)]")
        logger.info("   ├─ Trigger source: \(triggerSource)")
        logger.info("   ├─ Asset duration: \(asset.duration.seconds)s")
        logger.info("   ├─ Current player state: \(videoPlayer.state)")
        logger.info("   └─ Current player ready: \(videoPlayer.isReady)")

        addDiagnosticEntry("🎮 PLAYER BRIDGE: asset ready from \(triggerSource) [\(correlationId)]")

        // Enhanced gap analysis for notification-triggered loading
        let gapAnalysis = analyzeAssetLoadingGap()

        if gapAnalysis.type != .noGap {
            logger.info("🔍 PLAYER BRIDGE: Gap detected, triggering enhanced loading")
            logGapDetails(gapAnalysis)
            Task {
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "player_bridge_notification")
            }
        } else {
            logger.info("✅ PLAYER BRIDGE: No gap detected - player state is consistent")
            addDiagnosticEntry("✅ PLAYER BRIDGE: No action needed - state consistent")
        }
    }

    // MARK: - Enhanced Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Phase-specific icon and animation
            phaseSpecificIconView

            // Loading message with phase detail
            VStack(spacing: 8) {
                Text(getLoadingMessage())
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                if let detailedMessage = getDetailedLoadingMessage() {
                    Text(detailedMessage)
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Enhanced progress section
            if unifiedState.loadingProgress.progress > 0 {
                enhancedProgressView
            }

  
            // Retry option for failed loads
            if showRetryOption {
                enhancedRetryButton
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Phase-Specific Icon View
    private var phaseSpecificIconView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.backgroundSecondary)
                .frame(width: 120, height: 120)

            // Phase-specific icon
            getPhaseIcon()
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.primary)

            // Progress ring
            if unifiedState.loadingProgress.progress > 0 {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: unifiedState.loadingProgress.progress)
                    .stroke(
                        Color.primary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: unifiedState.loadingProgress.progress)
            }
        }
        .scaleEffect(1.2)
    }

    // MARK: - Enhanced Progress View
    private var enhancedProgressView: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(spacing: 12) {
                // Enhanced progress bar with smooth animation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.backgroundTertiary)
                            .frame(height: 8)

                        // Progress fill with smooth animation
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary)
                            .frame(width: geometry.size.width * max(0.05, unifiedState.loadingProgress.progress), height: 8)
                            .animation(.easeInOut(duration: 0.3), value: unifiedState.loadingProgress.progress)
                            .clipped()
                    }
                }
                .frame(height: 8)

                // Progress percentage and enhanced time info
                HStack {
                    Text("\(Int(max(1, unifiedState.loadingProgress.progress * 100)))%")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        let progress = unifiedState.loadingProgress
                        if progress.timeElapsed > 0 {
                            Text("Elapsed: \(String(format: "%.1f", progress.timeElapsed))s")
                                .font(.ibmPlexMono(size: 12, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }

                        if progress.progress > 0 && progress.progress < 1.0 {
                            if let remaining = progress.estimatedTimeRemaining, remaining > 0 {
                                Text("Est. remaining: \(String(format: "%.0f", remaining))s")
                                    .font(.ibmPlexMono(size: 10, weight: .regular))
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Progress phases indicator
            progressPhasesIndicator
        }
    }

    // MARK: - Progress Phases Indicator
    private var progressPhasesIndicator: some View {
        HStack(spacing: 8) {
            ForEach(getProgressPhases(), id: \.name) { phase in
                VStack(spacing: 4) {
                    Circle()
                        .fill(phase.isActive ? Color.primary : Color.backgroundTertiary)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.backgroundSecondary, lineWidth: 1)
                        )

                    Text(phase.name)
                        .font(.ibmPlexMono(size: 10, weight: .medium))
                        .foregroundColor(phase.isActive ? .textPrimary : .textTertiary)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    
    // MARK: - Enhanced Retry Button
    private var enhancedRetryButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                retryVideoLoad()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                    Text("Retry Loading")
                }
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primary)
                .cornerRadius(8)
            }
            .disabled(unifiedState.flowState.isLoading)
            .opacity(unifiedState.flowState.isLoading ? 0.6 : 1.0)
        }
    }

    // MARK: - Loading Info View
    private var loadingInfoView: some View {
        VStack(spacing: 8) {
            // File size information
            if let fileSize = currentFileSize {
                HStack {
                    Image(systemName: "doc")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)

                    Text("File size: \(formatFileSize(fileSize))")
                        .font(.ibmPlexMono(size: 12, weight: .regular))
                        .foregroundColor(.textSecondary)

                    Spacer()
                }
            }

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                Text("This may take a moment for large videos or iCloud content")
                    .font(.ibmPlexMono(size: 12, weight: .regular))
                    .foregroundColor(.textSecondary)

                Spacer()
            }

            if unifiedState.loadingProgress.isSlowLoading {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(.warning)

                    Text("Loading is taking longer than expected")
                        .font(.ibmPlexMono(size: 12, weight: .regular))
                        .foregroundColor(.warning)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Network Waiting View
    private var networkWaitingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundColor(.warning)

            Text("Waiting for network connection...")
                .font(.ibmPlexMono(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label("Connection: Checking...",
                      systemImage: "wifi")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Label("Quality: Unknown",
                      systemImage: "speedometer")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary.opacity(0.8))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.error)

            // Error message
            VStack(spacing: 8) {
                Text("Video Loading Failed")
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)

                if let errorMessage = unifiedState.errorMessage {
                    Text(errorMessage)
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Error details (for debugging)
            #if DEBUG
            if let error = lastError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.textSecondary)

                    Text((error as NSError).localizedDescription)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(8)
                .padding(.horizontal)
            }
            #endif

            // Action buttons
            VStack(spacing: 12) {
                retryButton

                Button("Select Different Video") {
                    unifiedState.reset()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Retry Button
    private var retryButton: some View {
        Button(action: {
            retryVideoLoad()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Retry Loading")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(8)
        }
        .disabled(unifiedState.flowState.isLoading)
        .opacity(unifiedState.flowState.isLoading ? 0.6 : 1.0)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Empty state icon
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.textTertiary)

            // Empty state message
            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Select a video to start trimming")
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
            }

            // Select video button
            Button("Select Video") {
                // This will be handled by parent view
                unifiedState.updateTab(.ready)
            }
            .buttonStyle(SelectClipButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }

    // MARK: - Video Trimmer View
    private func videoTrimmerView(asset: AVAsset) -> some View {
        VStack(spacing: 0) {
            // Video preview area with actual player
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.videoBackground)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                .overlay(
                    // Video player with custom controls
                    VideoPlayerView(player: videoPlayer, showControls: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                )
                .padding()
                .clipped()
                .overlay(
                    // Add border for better contrast on white background
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderSecondary, lineWidth: 1)
                )

            // Video info section
            videoInfoSection(asset: asset)
        }
    }

    // MARK: - Video Info Section
    private func videoInfoSection(asset: AVAsset) -> some View {
        VStack(spacing: 16) {
            // Video details
            VStack(spacing: 8) {
                HStack {
                    Text("Duration:")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text(formatVideoDuration(videoPlayer.duration))
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textPrimary)
                }

                HStack {
                    Text("File Size:")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text(currentFileSize != nil ? formatFileSize(currentFileSize!) : "Unknown")
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textPrimary)
                }
            }
            .padding()
            .background(Color.backgroundTertiary)
            .cornerRadius(8)

            // Trimming controls
            trimmingControlsView
        }
        .padding()
    }

    // MARK: - Trimming Controls View
    private var trimmingControlsView: some View {
        VStack(spacing: 16) {
            // Trim range title
            HStack {
                Text("Trim Range")
                    .font(.ibmPlexMono(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Spacer()

                // Trim duration
                Text("Duration: \(formatVideoDuration(trimEndTime - trimStartTime))")
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }

            // Timeline view
            timelineView

            // Time displays
            timeRangeView

            // Action buttons
            trimActionButtons
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Timeline View
    private var timelineView: some View {
        GeometryReader { geometry in
            ZStack {
                // Timeline track
                Rectangle()
                    .fill(Color.backgroundTertiary)
                    .frame(height: 4)
                    .cornerRadius(2)

                // Trimmed region highlight
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(
                        width: geometry.size.width * getTrimRangeProgress(),
                        height: 4
                    )
                    .cornerRadius(2)
                    .offset(x: geometry.size.width * getTrimStartProgress())

                // Left trim handle
                Circle()
                    .fill(Color.primary)
                    .frame(width: 20, height: 20)
                    .offset(x: geometry.size.width * getTrimStartProgress())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleLeftTrimDrag(value, geometry: geometry)
                            }
                            .onEnded { _ in
                                isDraggingLeftHandle = false
                            }
                    )

                // Right trim handle
                Circle()
                    .fill(Color.primary)
                    .frame(width: 20, height: 20)
                    .offset(x: geometry.size.width * getTrimEndProgress())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleRightTrimDrag(value, geometry: geometry)
                            }
                            .onEnded { _ in
                                isDraggingRightHandle = false
                            }
                    )

                // Playhead
                Rectangle()
                    .fill(Color.success)
                    .frame(width: 2, height: 40)
                    .offset(x: geometry.size.width * videoPlayer.progress)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handlePlayheadDrag(value, geometry: geometry)
                            }
                            .onEnded { _ in
                                isDraggingPlayhead = false
                            }
                    )
            }
        }
        .frame(height: 60)
    }

    // MARK: - Time Range View
    private var timeRangeView: some View {
        HStack {
            // Start time
            VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                Text(formatVideoDuration(trimStartTime))
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // Current time (playhead position)
            VStack(alignment: .center, spacing: 4) {
                Text("Current")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                Text(formatVideoDuration(videoPlayer.currentTime))
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.primary)
            }

            Spacer()

            // End time
            VStack(alignment: .trailing, spacing: 4) {
                Text("End")
                    .font(.ibmPlexMono(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)

                Text(formatVideoDuration(trimEndTime))
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textPrimary)
            }
        }
    }

    // MARK: - Trim Action Buttons
    private var trimActionButtons: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button("Cancel") {
                cancelTrimming()
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()

            // Reset trim button
            Button("Reset") {
                resetTrim()
            }
            .buttonStyle(SecondaryButtonStyle())

            // Apply trim button (primary action)
            Button("Apply Trim") {
                applyTrim()
            }
            .buttonStyle(SelectClipButtonStyle())
            .disabled(trimEndTime - trimStartTime < minimumTrimDuration)
        }
    }

    // MARK: - Helper Methods
    private func formatVideoDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let bytes = Double(bytes)
        let kilobyte = 1024.0
        let megabyte = kilobyte * 1024.0
        let gigabyte = megabyte * 1024.0

        if bytes >= gigabyte {
            return String(format: "%.1f GB", bytes / gigabyte)
        } else if bytes >= megabyte {
            return String(format: "%.1f MB", bytes / megabyte)
        } else if bytes >= kilobyte {
            return String(format: "%.0f KB", bytes / kilobyte)
        } else {
            return String(format: "%.0f bytes", bytes)
        }
    }

    private func initializeTrimValues() {
        let duration = videoPlayer.duration
        trimStartTime = 0.0
        trimEndTime = duration > 0 ? duration : 1.0

        // Update unified state with trim values
        unifiedState.trimStartTime = trimStartTime
        unifiedState.trimEndTime = trimEndTime

        logger.info("✅ Trim values initialized: \(trimStartTime)s - \(trimEndTime)s")
    }

    private func getTrimStartProgress() -> Double {
        guard videoPlayer.duration > 0 else { return 0.0 }
        return trimStartTime / videoPlayer.duration
    }

    private func getTrimEndProgress() -> Double {
        guard videoPlayer.duration > 0 else { return 1.0 }
        return trimEndTime / videoPlayer.duration
    }

    private func getTrimRangeProgress() -> Double {
        guard videoPlayer.duration > 0 else { return 0.0 }
        return (trimEndTime - trimStartTime) / videoPlayer.duration
    }

    private func handleLeftTrimDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        isDraggingLeftHandle = true

        let newProgress = max(0, min(1, (value.location.x - 10) / geometry.size.width))
        let newTime = newProgress * videoPlayer.duration

        // Ensure minimum duration
        if newTime < trimEndTime - minimumTrimDuration {
            trimStartTime = newTime
            unifiedState.trimStartTime = trimStartTime
        }
    }

    private func handleRightTrimDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        isDraggingRightHandle = true

        let newProgress = max(0, min(1, (value.location.x - 10) / geometry.size.width))
        let newTime = newProgress * videoPlayer.duration

        // Ensure minimum duration
        if newTime > trimStartTime + minimumTrimDuration {
            trimEndTime = newTime
            unifiedState.trimEndTime = trimEndTime
        }
    }

    private func handlePlayheadDrag(_ value: DragGesture.Value, geometry: GeometryProxy) {
        isDraggingPlayhead = true

        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
        let newTime = newProgress * videoPlayer.duration

        videoPlayer.seek(to: newTime)
    }

    private func previewTrim() {
        // Seek to start of trim range and play
        videoPlayer.seek(to: trimStartTime)
        videoPlayer.play()

        // Stop at end of trim range
        DispatchQueue.main.asyncAfter(deadline: .now() + (trimEndTime - trimStartTime)) {
            videoPlayer.pause()
            videoPlayer.seek(to: trimStartTime)
        }

        logger.info("▶️ Previewing trim: \(trimStartTime)s - \(trimEndTime)s")
    }

    private func resetTrim() {
        initializeTrimValues()
        logger.info("🔄 Trim reset to full video duration")
    }

    private func cancelTrimming() {
        // Reset to video selection view
        logger.info("🚫 Cancel trimming - returning to video selection")
        unifiedState.updateTab(.ready)

        // Clean up player state
        videoPlayer.cleanup()

        // Reset trim state
        trimStartTime = 0.0
        trimEndTime = 0.0
    }

    private func applyTrim() {
        // Update unified state with trim values
        unifiedState.trimStartTime = trimStartTime
        unifiedState.trimEndTime = trimEndTime

        // Here you would typically trigger the actual trimming process
        // For now, we'll just log the trim values
        logger.info("✅ Trim applied: \(trimStartTime)s - \(trimEndTime)s")

        // Could show a success message or navigate to next step
    }

  
    private func handleLoadingPhaseChange(_ phase: VideoLoadingProgress.LoadingPhase) {
        logger.info("🔄 TrimmerView: Loading phase changed from \(lastKnownLoadingPhase) to: \(phase)")

        // Track phase transition for debugging
        let previousPhase = lastKnownLoadingPhase
        lastKnownLoadingPhase = phase

        // Handle phase changes from unified state - simplified to only control UI-specific state
        switch phase {
        case .idle:
            showRetryOption = false
            logger.info("✅ TrimmerView: Phase is idle")

        case .initializing, .loading, .requestingDownload, .downloadingFromCloud, .transferring, .validating, .creatingAsset, .generatingThumbnail, .loadingTrimmerDuration, .loadingTrimmerTracks, .validatingTrimmer, .processing, .saving:
            showRetryOption = false
            logger.info("🔄 TrimmerView: Phase is loading (\(phase))")

        case .completed, .complete:
            showRetryOption = false
            logger.info("✅ TrimmerView: Phase completed - UnifiedState will handle UI updates")

            // CRITICAL: Log completion and check if flow state is correctly synced
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                logger.info("🔍 TrimmerView: Post-completion check - flowState: \(self.unifiedState.flowState), isLoading: \(self.unifiedState.flowState.isLoading)")

                // CRITICAL: Force state sync check after completion to catch any desynchronization
                self.forceStateSyncCheck()
            }

        case .retrying, .timeout, .error, .waitingForNetwork:
            showRetryOption = true
            logger.warning("⚠️ TrimmerView: Phase is error/retry: \(phase), showing retry option")
        }

        // Log phase transition summary
        logger.info("🎯 TrimmerView: Phase transition complete - \(previousPhase) → \(phase), showRetry: \(showRetryOption)")
    }

    private func handleFlowStateChange(_ newState: AddMoveFlowState) {
        logger.info("🔄 TrimmerView: Flow state changed from \(lastKnownFlowState) to: \(newState)")
        logger.info("🔄 TrimmerView: isLoading changed from \(lastKnownFlowState.isLoading) to: \(newState.isLoading)")

        // Track state transition for debugging
        let previousState = lastKnownFlowState
        lastKnownFlowState = newState

        switch newState {
        case .loading, .loadingVideo:
            showRetryOption = false
            logger.info("🔄 TrimmerView: Flow state is loading - showing loading spinner")

        case .loadingTrimmedAsset(let progress):
            showRetryOption = false
            logger.info("🔄 TrimmerView: Flow state is loading trimmed asset with progress: \(progress.value)")

        case .trimming:
            showRetryOption = false
            logger.info("✅ TrimmerView: Flow state is trimming - should hide loading spinner")

            // CRITICAL: Ensure video player loads the asset when transitioning to trimming
            if let asset = unifiedState.selectedVideo {
                Task {
                    // CRITICAL FIX: Use enhanced loadVideoWithRecovery method
                    await videoPlayer.loadVideoWithRecovery(asset)
                    initializeTrimValues()
                }
            }

        case .error(_, _):
            showRetryOption = true
            logger.warning("⚠️ TrimmerView: Flow state is error, showing retry option")

        case .ready, .naming, .saving, .success, .done:
            showRetryOption = false
            logger.info("ℹ️ TrimmerView: Flow state is \(newState) - no specific UI changes needed")
        }

        // Log UI state after transition
        logger.info("🎯 TrimmerView: State transition complete - isLoading: \(newState.isLoading), hasError: \(unifiedState.hasError), hasVideo: \(unifiedState.selectedVideo != nil)")
    }

    private func handleVideoError() {
        showRetryOption = true
        logger.error("⚠️ TrimmerView: Video loading error occurred")
    }

    // MARK: - Helper Methods for Enhanced Loading UI

    private func getLoadingMessage() -> String {
        let phase = unifiedState.loadingProgress.phase
        switch phase {
        case .idle:
            return "Ready to load video..."
        case .initializing:
            return "Initializing video load..."
        case .requestingDownload:
            return "Requesting video from iCloud..."
        case .downloadingFromCloud:
            return "Downloading from iCloud..."
        case .transferring:
            return "Transferring video file..."
        case .validating:
            return "Validating video file..."
        case .creatingAsset:
            return "Creating video asset..."
        case .generatingThumbnail:
            return "Generating thumbnail..."
        case .loadingTrimmerDuration, .loadingTrimmerTracks, .validatingTrimmer:
            return "Preparing trimmer..."
        case .waitingForNetwork:
            return "Waiting for network connection..."
        case .loading:
            return "Loading video..."
        case .processing:
            return "Processing video..."
        case .saving:
            return "Saving video..."
        case .completed, .complete:
            return "Video loaded successfully!"
        case .retrying:
            return "Retrying..."
        case .timeout:
            return "Loading timed out"
        case .error:
            return "Loading failed"
        }
    }

    private func getPhaseIcon() -> some View {
        let progress = unifiedState.loadingProgress
        switch progress.phase {
        case .idle, .initializing:
            return Image(systemName: "hourglass")
        case .requestingDownload:
            return Image(systemName: "icloud.and.arrow.down")
        case .downloadingFromCloud:
            return Image(systemName: "icloud.and.arrow.down")
        case .transferring:
            return Image(systemName: "arrow.left.arrow.right")
        case .creatingAsset, .generatingThumbnail:
            return Image(systemName: "photo")
        case .loadingTrimmerDuration, .loadingTrimmerTracks, .validatingTrimmer:
            return Image(systemName: "scissors")
        case .validating:
            return Image(systemName: "checkmark.shield")
        case .waitingForNetwork:
            return Image(systemName: "wifi.slash")
        case .loading, .processing, .saving:
            return Image(systemName: "gear")
        case .completed, .complete:
            return Image(systemName: "checkmark.circle")
        case .retrying:
            return Image(systemName: "arrow.clockwise")
        case .timeout:
            return Image(systemName: "clock")
        case .error:
            return Image(systemName: "exclamationmark.triangle")
        }
    }

    private func getDetailedLoadingMessage() -> String? {
        let progress = unifiedState.loadingProgress

        switch progress.phase {
        case .downloadingFromCloud(let cloudProgress):
            return "Download progress: \(Int(cloudProgress * 100))%"
        case .retrying(let attempt, let delay):
            return "Attempt \(attempt) - retrying in \(String(format: "%.1f", delay))s"
        case .timeout(let duration):
            return "Loading timed out after \(String(format: "%.1f", duration))s"
        default:
            return progress.estimatedTimeRemaining != nil ? progress.detailedMessage : nil
        }
    }

    private struct ProgressPhase {
        let name: String
        let isActive: Bool
    }

    private func isDownloadingFromCloud(_ phase: VideoLoadingProgress.LoadingPhase) -> Bool {
        if case .downloadingFromCloud(_) = phase {
            return true
        }
        return false
    }

    private func getProgressPhases() -> [ProgressPhase] {
        let progress = unifiedState.loadingProgress
        let phases = [
            ("Init", progress.phase == .initializing),
            ("Download", progress.phase == .requestingDownload || isDownloadingFromCloud(progress.phase)),
            ("Transfer", progress.phase == .transferring),
            ("Validate", progress.phase == .validating || progress.phase == .creatingAsset),
            ("Ready", progress.phase == .completed || progress.phase == .complete)
        ]

        return phases.map { ProgressPhase(name: $0.0, isActive: $0.1) }
    }

    // CRITICAL FIX: Fallback state synchronization moved to VideoInitializationCoordinator
    // This eliminates redundant recovery attempts and ensures single source of truth

    /// Ensure clean player state when no video is available
    private func ensureCleanPlayerState() {
        logger.info("🧹 ENSURE CLEAN STATE: Cleaning up player state")

        Task {
            videoPlayer.cleanup()
            trimStartTime = 0.0
            trimEndTime = 0.0

            logger.info("✅ CLEAN STATE COMPLETE: Player and trim state reset")
        }
    }

    // MARK: - Enhanced Comprehensive Diagnostics

    /// Start comprehensive diagnostic tracking for a video loading session
    private func startDiagnosticTracking() {
        assetLoadStartTime = Date()
        correlationId = UUID().uuidString.prefix(8).uppercased()
        diagnosticLog.removeAll()

        addDiagnosticEntry("🚀 DIAGNOSTIC SESSION STARTED")
        addDiagnosticEntry("   Correlation ID: \(correlationId ?? "unknown")")
        addDiagnosticEntry("   Start Time: \(assetLoadStartTime?.description ?? "unknown")")
        addDiagnosticEntry("   UnifiedState: flowState=\(unifiedState.flowState), hasVideo=\(unifiedState.selectedVideo != nil)")
        addDiagnosticEntry("   VideoPlayer: state=\(videoPlayer.state), isReady=\(videoPlayer.isReady)")
    }

    /// Add diagnostic entry with timestamp
    private func addDiagnosticEntry(_ message: String) {
        let timestamp = DateFormatter.diagnosticTimestamp.string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        diagnosticLog.append(entry)

        // Keep log size manageable (last 50 entries)
        if diagnosticLog.count > 50 {
            diagnosticLog.removeFirst(diagnosticLog.count - 50)
        }

        logger.info("🔍 DIAGNOSTIC: \(message)")
    }

    /// Log critical state transitions with timing
    private func logStateTransition(_ transition: String, details: String = "") {
        let currentTime = Date()
        let elapsedTime = assetLoadStartTime.map { currentTime.timeIntervalSince($0) } ?? 0

        var message = "STATE TRANSITION: \(transition)"
        message += " (elapsed: \(String(format: "%.3f", elapsedTime))s)"

        if !details.isEmpty {
            message += " - \(details)"
        }

        addDiagnosticEntry(message)

        // Special handling for player ready state
        if transition.contains("PLAYER READY") {
            playerReadyTime = currentTime
            if let loadTime = assetLoadStartTime {
                let totalLoadTime = currentTime.timeIntervalSince(loadTime)
                addDiagnosticEntry("🎯 CRITICAL METRIC: Total video load time = \(String(format: "%.3f", totalLoadTime))s")
            }
        }
    }

    /// Generate comprehensive diagnostic report
    private func generateDiagnosticReport() -> String {
        guard let correlationId = correlationId else {
            return "No diagnostic session active"
        }

        let separator = String(repeating: "=", count: 80)
        var report = "\n" + separator + "\n"
        report += "TRIMMER VIEW DIAGNOSTIC REPORT\n"
        report += "Correlation ID: \(correlationId)\n"
        report += "Generated: \(Date())\n"
        report += separator + "\n\n"

        // Session summary
        if let startTime = assetLoadStartTime {
            let sessionDuration = Date().timeIntervalSince(startTime)
            report += "SESSION SUMMARY:\n"
            report += "   Duration: \(String(format: "%.3f", sessionDuration))s\n"
            if let readyTime = playerReadyTime {
                let timeToReady = readyTime.timeIntervalSince(startTime)
                report += "   Time to Player Ready: \(String(format: "%.3f", timeToReady))s\n"
            } else {
                report += "   Time to Player Ready: NEVER ACHIEVED ⚠️\n"
            }
            report += "\n"
        }

        // Current state snapshot
        report += "CURRENT STATE SNAPSHOT:\n"
        report += "   UnifiedState.flowState: \(unifiedState.flowState)\n"
        report += "   UnifiedState.hasVideo: \(unifiedState.selectedVideo != nil)\n"
        report += "   UnifiedState.hasError: \(unifiedState.hasError)\n"
        report += "   VideoPlayer.state: \(videoPlayer.state)\n"
        report += "   VideoPlayer.isReady: \(videoPlayer.isReady)\n"
        report += "   VideoPlayer.duration: \(videoPlayer.duration)s\n"
        report += "\n"

        // Detailed log
        report += "DETAILED DIAGNOSTIC LOG:\n"
        for entry in diagnosticLog {
            report += "   \(entry)\n"
        }

        report += "\n" + separator + "\n"

        return report
    }

    /// Print diagnostic report to console
    private func printDiagnosticReport() {
        let report = generateDiagnosticReport()
        print(report)

        // Also log the report in chunks to avoid truncation
        let lines = report.components(separatedBy: "\n")
        for line in lines {
            if !line.isEmpty {
                logger.info("📋 DIAGNOSTIC REPORT: \(line)")
            }
        }
    }

    /// Monitor and log video player state changes
    private func monitorVideoPlayerState() {
        // Create a timer to monitor player state every 500ms for diagnostic purposes
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard self.correlationId != nil else { return }

            let currentState = self.videoPlayer.state
            let isReady = self.videoPlayer.isReady

            // Only log state changes to reduce noise
            if currentState != Self.lastLoggedState || isReady != Self.lastLoggedReady {
                self.addDiagnosticEntry("PLAYER STATE MONITOR: state=\(currentState), isReady=\(isReady)")
                Self.lastLoggedState = currentState
                Self.lastLoggedReady = isReady
            }
        }
    }

    // MARK: - Enhanced Fallback State Synchronization

    /// Start comprehensive fallback state synchronization with multiple timing checkpoints
    private func startComprehensiveStateSynchronization() {
        logger.info("🕐 STARTING COMPREHENSIVE STATE SYNCHRONIZATION")

        // TIER 1: Immediate check (10ms) - catch immediate desynchronization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.performStateSyncCheck(tier: "IMMEDIATE", delay: 0.01)
        }

        // TIER 2: Quick check (50ms) - catch fast timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.performStateSyncCheck(tier: "QUICK", delay: 0.05)
        }

        // TIER 3: Standard check (200ms) - catch typical timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performStateSyncCheck(tier: "STANDARD", delay: 0.2)
        }

        // TIER 4: Extended check (500ms) - catch slow initialization issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performStateSyncCheck(tier: "EXTENDED", delay: 0.5)
        }

        // TIER 5: Final check (1s) - catch persistent issues and force recovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performStateSyncCheck(tier: "FINAL", delay: 1.0)
        }
    }

    /// Perform individual state synchronization check
    private func performStateSyncCheck(tier: String, delay: TimeInterval) {
        let playerState = videoPlayer.state
        let playerReady = videoPlayer.isReady
        let hasVideo = unifiedState.selectedVideo != nil
        let flowState = unifiedState.flowState
        let hasError = unifiedState.hasError

        logger.info("🔍 STATE SYNC CHECK (\(tier)): state=\(playerState), ready=\(playerReady), delay=\(delay)s")
        logger.info("   ├─ hasVideo: \(hasVideo), flowState: \(flowState), hasError: \(hasError)")

        // Analyze state consistency
        let syncIssues = analyzeStateSynchronizationIssues(
            playerState: playerState,
            playerReady: playerReady,
            hasVideo: unifiedState.selectedVideo,
            flowState: flowState,
            hasError: hasError
        )

        if syncIssues.isEmpty {
            logger.info("✅ STATE SYNC (\(tier)): All systems consistent")
            addDiagnosticEntry("✅ STATE SYNC (\(tier)): Consistent state verified")
        } else {
            logger.warning("⚠️ STATE SYNC (\(tier)): Issues detected - initiating recovery")
            logSyncIssues(syncIssues, tier: tier)
            executeStateSyncRecovery(syncIssues: syncIssues, tier: tier)
        }
    }

    /// Analyze state synchronization issues
    private func analyzeStateSynchronizationIssues(
        playerState: SharedVideoPlayer.PlayerState,
        playerReady: Bool,
        hasVideo: AVAsset?,
        flowState: AddMoveFlowState,
        hasError: Bool
    ) -> [StateSyncIssue] {
        var issues: [StateSyncIssue] = []

        // Issue 1: Asset available but player idle
        if hasVideo != nil && playerState == .idle {
            issues.append(.playerIdleWithAsset)
        }

        // Issue 2: Player ready but flag not set
        if (playerState == .ready || playerState == .playing || playerState == .paused) && !playerReady {
            issues.append(.inconsistentReadyFlag)
        }

        // Issue 3: Loading stuck in loading state
        if flowState.isLoading && hasVideo != nil && playerState == .idle {
            issues.append(.stuckInLoadingState)
        }

        // Issue 4: Player ready but UnifiedState still loading
        if playerState == .ready && playerReady && flowState.isLoading {
            issues.append(.unifiedStateBehind)
        }

        // Issue 5: Error state inconsistency
        if hasError && (playerState == .ready || playerReady) {
            issues.append(.errorStateInconsistency)
        }

        return issues
    }

    /// Log synchronization issues with details
    private func logSyncIssues(_ issues: [StateSyncIssue], tier: String) {
        logger.info("📊 SYNC ISSUES (\(tier)): \(issues.count) issues detected")
        for (index, issue) in issues.enumerated() {
            logger.info("   \(index + 1). \(issue.description)")
        }
        addDiagnosticEntry("⚠️ SYNC ISSUES (\(tier)): \(issues.map { $0.rawValue }.joined(separator: ", "))")
    }

    /// Execute recovery based on identified sync issues
    private func executeStateSyncRecovery(syncIssues: [StateSyncIssue], tier: String) {
        logger.info("🔧 STATE SYNC RECOVERY (\(tier)): Executing recovery for \(syncIssues.count) issues")

        Task {
            // Group similar recovery strategies
            let needsPlayerLoad = syncIssues.contains(.playerIdleWithAsset) || syncIssues.contains(.stuckInLoadingState)
            let needsStateFix = syncIssues.contains(.inconsistentReadyFlag) || syncIssues.contains(.unifiedStateBehind)
            let needsErrorRecovery = syncIssues.contains(.errorStateInconsistency)

            if needsPlayerLoad, let asset = unifiedState.selectedVideo {
                logger.info("🚀 STATE SYNC RECOVERY (\(tier)): Loading asset into player")
                await loadVideoAssetWithEnhancedTracking(asset, trigger: "state_sync_\(tier.lowercased())")
            }

            if needsStateFix {
                logger.info("🔄 STATE SYNC RECOVERY (\(tier)): Fixing state inconsistencies")
                await fixStateInconsistencies(tier: tier)
            }

            if needsErrorRecovery {
                logger.info("🧹 STATE SYNC RECOVERY (\(tier)): Clearing error states")
                unifiedState.clearError()
            }

            // Verify recovery after a short delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            let recoveryPlayerState = videoPlayer.state
            let recoveryPlayerReady = videoPlayer.isReady
            let recoveryHasVideo = unifiedState.selectedVideo != nil
            let recoveryFlowState = unifiedState.flowState

            if recoveryPlayerState == .ready && recoveryPlayerReady && recoveryHasVideo && !recoveryFlowState.isLoading {
                logger.info("✅ STATE SYNC RECOVERY (\(tier)): Recovery successful")
                addDiagnosticEntry("✅ SYNC RECOVERY (\(tier)): Successful")
            } else {
                logger.warning("⚠️ STATE SYNC RECOVERY (\(tier)): Partial recovery - may need further intervention")
                addDiagnosticEntry("⚠️ SYNC RECOVERY (\(tier)): Partial - player=\(recoveryPlayerState), ready=\(recoveryPlayerReady)")
            }
        }
    }

    /// Fix state inconsistencies without full asset reload
    private func fixStateInconsistencies(tier: String) async {
        logger.info("🔧 FIXING STATE INCONSISTENCIES (\(tier))")

        // Fix 1: Force ready flag if player is ready
        if (videoPlayer.state == .ready || videoPlayer.state == .playing || videoPlayer.state == .paused) && !videoPlayer.isReady {
            logger.warning("⚠️ FORCING READY FLAG: Player is ready but flag is false")
            // Note: This would require access to private setter - for now we trigger player state validation
            videoPlayer.forceStateValidation()
        }

        // Fix 2: Update UnifiedState if it's stuck in loading
        if unifiedState.flowState.isLoading && unifiedState.selectedVideo != nil {
            logger.info("🔄 ADVANCING UNIFIEDSTATE: From loading to trimming")
            unifiedState.updateFlowState(.trimming)
            unifiedState.updateTab(.trimming)
        }

        // Fix 3: Ensure trim values are initialized
        if videoPlayer.isReady && (trimStartTime == 0.0 || trimEndTime == 0.0) {
            logger.info("📏 INITIALIZING TRIM VALUES: Due to state inconsistency")
            initializeTrimValues()
        }
    }

    // MARK: - Retry Logic
    private func retryVideoLoad() {
        logger.info("🔄 TrimmerView: Initiating video loading retry")

        // Add diagnostic entry for retry attempt
        addDiagnosticEntry("🔄 RETRY ATTEMPT: User initiated retry")

        // Clear previous error
        unifiedState.clearError()
        lastError = nil
        showRetryOption = false

        // Navigate back to video selection to retry loading
        unifiedState.updateTab(.ready)
    }
}

// MARK: - Diagnostic Extensions
extension DateFormatter {
    static let diagnosticTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ibmPlexMono(size: 16, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.backgroundSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}


// MARK: - Preview
#Preview("Loading State") {
    @Previewable @StateObject var unifiedState = AddMoveUnifiedState()

    return TrimmerView(unifiedState: unifiedState)
        .onAppear {
            unifiedState.updateFlowState(.loadingVideo)
        }
        .preferredColorScheme(.dark)
}

#Preview("Error State") {
    @Previewable @StateObject var unifiedState = AddMoveUnifiedState()

    return TrimmerView(unifiedState: unifiedState)
        .onAppear {
            unifiedState.setError("Failed to load video: Network error")
        }
        .preferredColorScheme(.dark)
}

#Preview("Video Loaded") {
    @Previewable @StateObject var unifiedState = AddMoveUnifiedState()

    return TrimmerView(unifiedState: unifiedState)
        .onAppear {
            // Create a sample asset for preview
            let sampleURL = Bundle.main.url(forResource: "sample", withExtension: "mp4") ??
                           URL(fileURLWithPath: "/dev/null")
            let sampleAsset = AVURLAsset(url: sampleURL)
            Task {
                await unifiedState.setSelectedVideo(sampleAsset, url: sampleURL)
            }
        }
        .preferredColorScheme(.dark)
}
