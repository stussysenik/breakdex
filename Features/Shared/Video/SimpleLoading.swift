import SwiftUI
import OSLog
import AVFoundation

// SimpleLoading.swift - actual UI of the loading screen

// MARK: - Simple Loading View
/// Comprehensive loading UI component for video operations
/// Supports progress indication, network status, and error handling
struct SimpleLoadingView: View {
    // MARK: - Properties
    let state: LoadingState
    let progress: LoadingProgress?
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
            if case .failed(let errorMessage) = state {
                errorView(errorMessage)
            }

            // Network information (when downloading)
            if case .loading(_, let stage, _) = state, stage == .downloadingFromCloud, let progress = progress {
                networkInfo(progress)
            }

            // Retry button (always shown for failed states)
            if case .failed = state, let retryAction = retryAction {
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
            Text(state.message)
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: state.message)

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
                    // Download percentage
                    HStack {
                        Text("Download:")
                            .font(.ibmPlexMono(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("\(Int(progress.value * 100))%")
                            .font(.ibmPlexMono(size: 12, weight: .regular))
                            .foregroundColor(.textPrimary)
                    }

                    // Download speed (available for iCloud downloads)
                    if let downloadSpeed = progress.downloadSpeed {
                        HStack {
                            Text("Speed:")
                                .font(.ibmPlexMono(size: 12, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .file) + "/s")
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
    private func errorView(_ errorMessage: String) -> some View {
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

                Text(errorMessage)
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.backgroundSecondary.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Network Information
    private func networkInfo(_ progress: LoadingProgress) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloading from iCloud")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    if let downloadSpeed = progress.downloadSpeed {
                        Text("\(ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .file))/s")
                            .font(.ibmPlexMono(size: 12, weight: .regular))
                            .foregroundColor(.blue)
                    } else {
                        Text("Large files may take longer")
                            .font(.ibmPlexMono(size: 12, weight: .regular))
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                // Animated iCloud indicator
                VStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                        .scaleEffect(1.2)
                        .opacity(0.8)
                }
            }
            .padding()
            .background(Color.backgroundTertiary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
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
        case .loading(_, let stage, _):
            switch stage {
            case .initializing:
                return "gear.badge"
            case .downloadingFromCloud:
                return "icloud.and.arrow.down"
            case .transferringFile:
                return "arrow.left.arrow.right"
            case .validatingFile:
                return "checkmark.shield"
            case .creatingAsset:
                return "video.badge.plus"
            case .initializingPlayer:
                return "play.rectangle"
            case .preparingPlayback:
                return "play.circle"
            case .finalizing:
                return "checkmark.circle"
            }
        case .assetReady:
            return "video.badge.checkmark"
        case .playerReady:
            return "play.rectangle.fill"
        case .fullyReady:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle, .assetReady, .playerReady, .fullyReady:
            return .success
        case .loading:
            return .primary
        case .failed:
            return .error
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Video loading idle"
        case .loading(_, let stage, _):
            switch stage {
            case .initializing:
                return "Initializing video load"
            case .downloadingFromCloud:
                return "Downloading video from iCloud"
            case .transferringFile:
                return "Transferring video file"
            case .validatingFile:
                return "Validating video file"
            case .creatingAsset:
                return "Creating video asset"
            case .initializingPlayer:
                return "Initializing video player"
            case .preparingPlayback:
                return "Preparing video playback"
            case .finalizing:
                return "Finalizing video preparation"
            }
        case .assetReady:
            return "Video asset ready"
        case .playerReady:
            return "Video player ready"
        case .fullyReady:
            return "Video fully ready"
        case .failed:
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
        state: .loading(progress: 0.6, stage: .downloadingFromCloud, message: "Downloading from iCloud..."),
        progress: .iCloudDownload(progress: 0.6, speed: 1024*1024),
        retryAction: nil
    )
    .preferredColorScheme(.dark)
}

#Preview("Error State") {
    SimpleLoadingView(
        state: .failed("Video file could not be loaded"),
        progress: nil,
        retryAction: { }
    )
    .preferredColorScheme(.dark)
}

#Preview("Ready State") {
    SimpleLoadingView(
        state: .fullyReady(AVURLAsset(url: URL(fileURLWithPath: "/dev/null"))),
        progress: nil,
        retryAction: nil
    )
    .preferredColorScheme(.dark)
}