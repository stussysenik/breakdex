import SwiftUI
import PhotosUI

// SelectClip.swift - "select a clip" UI

// MARK: - SelectClip
/// Enhanced view for selecting a clip with loading feedback
/// Updated to work with simplified AddMoveViewModel
struct SelectClip: View {
    @Binding var selectedTab: Int
    @ObservedObject var viewModel: AddMoveViewModel
    let onStepChange: (AddMoveStep) -> Void
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosUI.PhotosPickerItem?
    @State private var lastStateObservationTime: CFAbsoluteTime?

    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "SelectClip")

    var body: some View {
        ZStack {
            // Main content
            VStack {
                Spacer()

                // Show loading state or selection button
                if viewModel.isLoading {
                    loadingView
                } else {
                    Button("Select a Clip") {
                        // Show Photos picker for video selection
                        showPhotosPicker = true
                    }
                    .buttonStyle(SelectClipButtonStyle())
                }

                Spacer()
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $tempSelection,
                matching: .videos,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: tempSelection) { _, newItem in
                handleVideoSelection(newItem)
            }
            .onChange(of: viewModel.loadingState) { _, newState in
                handleLoadingStateChange(newState)
            }
            .disabled(viewModel.isLoading) // Disable interaction during loading

            // Error overlay
            if viewModel.hasError {
                errorOverlay
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.blue))

            Text(viewModel.progressMessage)
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            if viewModel.progress > 0 {
                ProgressView(value: viewModel.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                    .frame(width: 200, height: 6)

                Text("\(viewModel.progressPercentage)%")
                    .font(.ibmPlexMono(size: 14, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding()
    }

    // MARK: - Error Overlay
    private var errorOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.error)

            Text(viewModel.errorMessage ?? "An error occurred")
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.clearError()
                tempSelection = nil
                showPhotosPicker = true
            }
            .buttonStyle(.appPrimary())

            Button("Select Different Video") {
                viewModel.clearError()
                tempSelection = nil
                showPhotosPicker = true
            }
            .buttonStyle(.appSecondary())
        }
        .padding(24)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }

    // MARK: - Private Methods

    private func retryLastVideoSelection() {
        viewModel.clearError()
        onStepChange(.ready)
        // Retry logic would go here if we stored the last selection
        // For now, we just clear the error and return to ready state
    }

    private func handleVideoSelection(_ item: PhotosUI.PhotosPickerItem?) {
        guard let newItem = item else { return }

        viewModel.clearError()
        tempSelection = nil

        Task {
            await viewModel.loadVideo(from: newItem)
            // The step change will be handled automatically by the loading state change
        }
    }

    private func handleLoadingStateChange(_ newState: LoadingState) {
        Task { @MainActor in
            await handleLoadingStateChangeAsync(newState)
        }
    }

    @MainActor
    private func handleLoadingStateChangeAsync(_ newState: LoadingState) async {
        lastStateObservationTime = CFAbsoluteTimeGetCurrent()

        switch newState {
        case .idle:
            break

        case .loading(_, let stage, _):
            logger.debug("Loading: \(stage)")

        case .fullyReady:
            guard let selectedVideo = viewModel.selectedVideo else {
                logger.error("Cannot coordinate - no video selected")
                return
            }

            // Prevent duplicate loadVideo calls
            if viewModel.videoPlayer.isReady && viewModel.videoPlayer.state != .idle {
                onStepChange(.trimming)
                return
            }

            let loadSuccess = await viewModel.videoPlayer.loadVideo(selectedVideo)

            if loadSuccess && viewModel.videoPlayer.isReady {
                logger.info("Video ready - transitioning to trimming")
                onStepChange(.trimming)
            } else {
                logger.error("Player coordination failed")
            }

        case .assetReady, .playerReady:
            break

        case .failed(let message):
            logger.error("Video loading failed: \(message)")
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: Int = 1 // Add Move tab

        var body: some View {
            SelectClip(
                selectedTab: $selectedTab,
                viewModel: AddMoveViewModel(),
                onStepChange: { _ in }
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}