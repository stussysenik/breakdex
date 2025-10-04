import SwiftUI
import OSLog

/// A minimalist, data-driven overlay that provides transparent feedback on video loading progress.
/// Designed for "The Athlete" persona who values precision and mechanical watch aesthetics.
/// Enhanced with elapsed time display, trimming setup phases, and diagnostic capabilities.
/// Updated for simplified 5-stage state machine with SimpleProgress support.
/// 🎯 CRITICAL FIX: Progress decoupled from state enum - now only depends on unified state
struct LoadingOverlayView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState

    // ✅ BIND DIRECTLY to the engine's properties for real-time updates
    // This eliminates the stale value issue by observing the single source of truth
    private var progressValue: Double {
        return unifiedState.unifiedProgressEngine.unifiedProgress
    }

    private var statusMessage: String {
        return unifiedState.unifiedProgressEngine.unifiedStatus
    }

    // Enhanced status message based on progress
    private var enhancedStatusMessage: String {
        return statusMessage
    }

    var body: some View {
        ZStack {
            // 🚀 UNIFIED PROGRESS: Subtle background with smooth fade-in animation
            // Color.black.opacity(0.75)
            //     .ignoresSafeArea()
            //     .transition(.opacity.combined(with: .scale(scale: 0.95)))

            VStack(spacing: 16) {
                // 🎯 CRITICAL FIX: Enhanced status display with phase indicator
                VStack(spacing: 8) {
                    // 🚀 UNIFIED PROGRESS: Enhanced status message with smooth transitions
                    Text(enhancedStatusMessage)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.25), value: enhancedStatusMessage)

                    // Progress phase indicator with enhanced descriptions
                    Text("Loading Video")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    // Additional context for trimming setup phases
                    if isTrimmingSetupPhase {
                        Text("Setting up precise trimming tools...")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }

                // ✅ BIND DIRECTLY to the engine's progress with simple animation
                // The engine's internal timer already provides smoothness
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .animation(.linear(duration: 0.1), value: progressValue)

                // ✅ BIND DIRECTLY to the engine's progress percentage
                Text("\(Int(progressValue * 100))%")
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.white)
                    .animation(.linear(duration: 0.1), value: progressValue)

                // 🎯 STRATEGIC FIX: Enhanced elapsed time display for large video loading
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Text(formatTime(unifiedState.loadElapsedTime))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }

            }
            .padding(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))
            .background(Material.thick)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.horizontal, 40)
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.4), value: progressValue)
        }
        .onAppear {
            // 🎯 STRATEGIC FIX: Diagnostic logging for loading overlay appearance
            logLoadingOverlayAppearance()
        }
    }

    // MARK: - Private Methods

    /// Determines if current phase is part of trimming setup
    private var isTrimmingSetupPhase: Bool {
        return false
    }

    /// Format seconds into MM:SS format
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Log loading overlay appearance for diagnostics
    private func logLoadingOverlayAppearance() {
        let logger = Logger(subsystem: "BreakingFlashcards", category: "🎬 LOADING_OVERLAY")
        logger.info("🎬 LOADING_OVERLAY: 📱 Loading overlay appeared")
        logger.info("🎬 LOADING_OVERLAY: 📊 Progress: \(Int(progressValue * 100))% - \(statusMessage)")
        logger.info("🎬 LOADING_OVERLAY: ⏱️ Initial elapsed time: \(String(format: "%.1f", unifiedState.loadElapsedTime))s")
        logger.info("🎬 LOADING_OVERLAY: 📝 Status message: \(enhancedStatusMessage)")
        logger.info("🎬 LOADING_OVERLAY: 🎯 CRITICAL_FIX_LOG: State decoupled - loading overlay now depends only on unified state")
        logger.info("🎬 LOADING_OVERLAY: 📊 Engine Status: \(unifiedState.unifiedProgressEngine.unifiedStatus)")

        if isTrimmingSetupPhase {
            logger.info("🎬 LOADING_OVERLAY: 🎬 Trimming setup phase detected - preparing precision tools")
        }
    }
}

// MARK: - Loading Phase Display Extension

extension VideoLoadingProgress.LoadingPhase {
    /// Display name for the loading phase
    var displayName: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .downloadingFromCloud(progress: _):
            return "Downloading from Cloud"
        case .transferring:
            return "Transferring"
        case .validating:
            return "Validating"
        case .creatingAsset:
            return "Creating Asset"
        case .loadingTrimmerDuration:
            return "Loading Trimmer Duration"
        case .loadingTrimmerTracks:
            return "Loading Trimmer Tracks"
        case .validatingTrimmer:
            return "Validating Trimmer"
        }
    }
}

// Preview removed due to complex dependency injection requirements
// Can be added back later with proper mock setup
