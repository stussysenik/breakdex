import SwiftUI
import OSLog

/// A minimalist, data-driven overlay that provides transparent feedback on video loading progress.
/// Designed for "The Athlete" persona who values precision and mechanical watch aesthetics.
/// Enhanced with elapsed time display and diagnostic capabilities.
struct LoadingOverlayView: View {
    let progressPhase: VideoLoadingProgress.LoadingPhase
    @ObservedObject var unifiedState: AddMoveUnifiedState

    // Computed properties to derive UI state from the progressPhase object
    private var progress: Double {
        let progressObj = VideoLoadingProgress(phase: progressPhase, correlationId: "")
        return progressObj.progress
    }

    private var statusMessage: String {
        let progressObj = VideoLoadingProgress(phase: progressPhase, correlationId: "")
        return progressObj.message
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
                    // The status message is now the primary focus.
                    Text(statusMessage)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .animation(nil, value: statusMessage) // Prevent animation on text change

                    // Progress phase indicator for debugging
                    Text("Phase: \(progressPhase.displayName)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // A simple, clean, linear progress bar.
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .animation(.easeInOut, value: progress)

                // Progress percentage
                Text("\(Int(progress * 100))%")
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
        logger.info("🎬 LOADING_OVERLAY: 📊 Phase: \(progressPhase.displayName), Progress: \(Int(progress * 100))%")
        logger.info("🎬 LOADING_OVERLAY: ⏱️ Initial elapsed time: \(String(format: "%.1f", unifiedState.loadElapsedTime))s")
        logger.info("🎬 LOADING_OVERLAY: 📝 Status message: \(statusMessage)")
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
        }
    }
}

// Preview removed due to complex dependency injection requirements
// Can be added back later with proper mock setup
