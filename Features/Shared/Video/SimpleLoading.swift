import SwiftUI
import OSLog
import AVFoundation

// SimpleLoading.swift - actual UI of the loading screen

// MARK: - Simple Loading View
/// Comprehensive loading UI component for video operations
/// Supports progress indication, network status, and error handling
struct SimpleLoadingView: View {
    // MARK: - Properties
    let state: VideoLoadingState
    let progress: VideoLoadingProgress?
    let retryAction: (() -> Void)?

    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SimpleLoadingView")

    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            // Main loading indicator
            loadingIndicator

            // Status message
            statusMessage

            // Progress details (when available)
            if state.isLoading {
                progressDetails
            }

            // Error state (when applicable)
            if case .error(let error, _) = state {
                errorView(error)
            }

            // Network information (when downloading)
            if case .downloadingFromCloud = state, let progress = progress {
                networkInfo(progress)
            }

            // Retry button (when applicable)
            if state.canRetry, let retryAction = retryAction {
                retryButton(action: retryAction)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.videoBackground)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Loading Indicator
    private var loadingIndicator: some View {
        Group {
            if state.isLoading {
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 3)
                        .frame(width: 60, height: 60)

                    // Inner rotating arc
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.primary, Color.primary.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotationAngle))
                        .scaleEffect(pulseScale)

                    // Progress circle (when progress is available)
                    if state.progress > 0 {
                        Circle()
                            .trim(from: 0, to: state.progress)
                            .stroke(Color.success, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                    }

                    // Center icon
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.primary)
                        .scaleEffect(1.2)
                }
            } else {
                // Static icon for non-loading states
                Image(systemName: iconName)
                    .font(.system(size: 50))
                    .foregroundColor(stateColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Status Message
    private var statusMessage: some View {
        VStack(spacing: 8) {
            Text(state.statusMessage)
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: state.statusMessage)

            // Progress percentage
            if state.isLoading && state.progress > 0 {
                Text("\(Int(state.progress * 100))%")
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    // MARK: - Progress Details
    private var progressDetails: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: state.progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                .frame(height: 6)
                .scaleEffect(x: 1.2, y: 2.0)
                .accessibilityLabel("Loading progress: \(Int(state.progress * 100)) percent")

            // Additional progress information
            if let progress = progress {
                VStack(spacing: 4) {
                    if let downloadPercentage = progress.downloadPercentage {
                        HStack {
                            Text("Download:")
                                .font(.ibmPlexMono(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text("\(Int(downloadPercentage * 100))%")
                                .font(.ibmPlexMono(size: 12, weight: .regular))
                                .foregroundColor(.textPrimary)
                        }
                    }

                    if let downloadSpeed = progress.formattedDownloadSpeed {
                        HStack {
                            Text("Speed:")
                                .font(.ibmPlexMono(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text(downloadSpeed)
                                .font(.ibmPlexMono(size: 12, weight: .regular))
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Error View
    private func errorView(_ error: VideoLoadingError) -> some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.error)

            // Error details
            VStack(spacing: 8) {
                Text("Loading Failed")
                    .font(.ibmPlexMono(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)

                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.ibmPlexMono(size: 14, weight: .regular))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            // Debug information (in debug builds)
            #if DEBUG
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.textSecondary)

                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(8)
            #endif
        }
        .padding()
        .background(Color.backgroundSecondary.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Network Information
    private func networkInfo(_ progress: VideoLoadingProgress) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.primary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloading from iCloud")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Text("Large files may take longer")
                        .font(.ibmPlexMono(size: 12, weight: .regular))
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.backgroundTertiary)
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }

    // MARK: - Retry Button
    private func retryButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Retry")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.primary)
            .cornerRadius(8)
        }
        .accessibilityLabel("Retry loading video")
        .accessibilityHint("Attempts to load the video again")
    }

    // MARK: - Helper Properties
    private var iconName: String {
        switch state {
        case .idle:
            return "video.slash"
        case .initializing:
            return "gear.badge"
        case .requestingDownload:
            return "icloud.and.arrow.down"
        case .downloadingFromCloud:
            return "icloud.and.arrow.down"
        case .transferringFile:
            return "arrow.left.arrow.right"
        case .validatingFile:
            return "checkmark.shield"
        case .creatingAsset:
            return "video.badge.plus"
        case .generatingThumbnail:
            return "photo"
        case .loadingTrimmerComponents:
            return "slider.horizontal.3"
        case .ready:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle, .ready:
            return .success
        case .initializing, .requestingDownload, .downloadingFromCloud,
             .transferringFile, .validatingFile, .creatingAsset,
             .generatingThumbnail, .loadingTrimmerComponents:
            return .primary
        case .error:
            return .error
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Video loading idle"
        case .initializing:
            return "Initializing video load"
        case .requestingDownload:
            return "Requesting video download"
        case .downloadingFromCloud:
            return "Downloading video from iCloud"
        case .transferringFile:
            return "Transferring video file"
        case .validatingFile:
            return "Validating video file"
        case .creatingAsset:
            return "Creating video asset"
        case .generatingThumbnail:
            return "Generating video thumbnail"
        case .loadingTrimmerComponents:
            return "Loading trimming interface"
        case .ready:
            return "Video loaded successfully"
        case .error:
            return "Video loading failed"
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        if state.isLoading {
            // Continuous rotation animation
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

// MARK: - Preview
#Preview("Loading State") {
    SimpleLoadingView(
        state: .downloadingFromCloud(progress: 0.6),
        progress: VideoLoadingProgress(
            phase: .downloadingFromCloud(0.6),
            correlationId: "preview-loading"
        ),
        retryAction: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    SimpleLoadingView(
        state: .error(error: .dataUnavailable, retryAvailable: true),
        progress: nil,
        retryAction: { }
    )
    .preferredColorScheme(.dark)
}

#Preview("Ready State") {
    SimpleLoadingView(
        state: .ready(asset: AVURLAsset(url: URL(fileURLWithPath: "/dev/null")), url: URL(fileURLWithPath: "/dev/null")),
        progress: nil,
        retryAction: nil
    )
    .preferredColorScheme(.dark)
}