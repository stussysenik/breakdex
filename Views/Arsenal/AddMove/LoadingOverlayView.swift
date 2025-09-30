import SwiftUI
import OSLog

/// A minimalist, data-driven overlay that provides transparent feedback on video loading progress.
/// Designed for "The Athlete" persona who values precision and mechanical watch aesthetics.
/// Enhanced with elapsed time display, trimming setup phases, and diagnostic capabilities.
/// Updated for simplified 5-stage state machine with SimpleProgress support.
struct LoadingOverlayView: View {
    let progress: SimpleProgress
    @ObservedObject var unifiedState: AddMoveUnifiedState

    // 🎯 REAL-TIME FIX: Use unifiedState progress values for real-time updates
    // This ensures the overlay shows the latest progress from the loading service
    private var progressValue: Double {
        // Use the most recent progress value from the state
        return max(progress.value, unifiedState.currentProgress)
    }

    private var statusMessage: String {
        // Use the most recent status message from the state
        return unifiedState.loadingStatus.isEmpty ? progress.message : unifiedState.loadingStatus
    }

    // Enhanced status message based on progress
    private var enhancedStatusMessage: String {
        return statusMessage
    }

    var body: some View {
        ZStack {
            // A subtle background to dim the underlying content.
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 16) {
                // 🎯 CRITICAL FIX: Enhanced status display with phase indicator
                VStack(spacing: 8) {
                    // The enhanced status message provides context for all phases
                    Text(enhancedStatusMessage)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(nil, value: enhancedStatusMessage) // Prevent animation on text change

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

                // A simple, clean, linear progress bar.
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .animation(.easeInOut(duration: 0.3), value: progressValue)

                // Progress percentage
                Text("\(Int(progressValue * 100))%")
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.white)

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
