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
            Color.backgroundPrimary.ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Step indicator
                WorkflowStepIndicator(currentStep: 1, totalSteps: 4)
                    .padding(.top, Spacing.lg)

                Spacer()

                // Show loading state or guidance with selection button
                if viewModel.isLoading {
                    loadingView
                } else {
                    guidanceView
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

    // MARK: - Guidance View
    private var guidanceView: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            Image(systemName: "video.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.accent)

            // Title and description
            VStack(spacing: Spacing.sm) {
                Text("Add a New Move")
                    .font(.titleSmall)
                    .foregroundColor(.textPrimary)

                Text("Select a video clip from your library to add to your breaking arsenal.")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Workflow steps preview
            VStack(alignment: .leading, spacing: Spacing.sm) {
                WorkflowStepRow(number: 1, text: "Select video clip", isActive: true)
                WorkflowStepRow(number: 2, text: "Trim & rotate", isActive: false)
                WorkflowStepRow(number: 3, text: "Name your move", isActive: false)
                WorkflowStepRow(number: 4, text: "Save to arsenal", isActive: false)
            }
            .padding(.vertical, Spacing.md)

            // Select button
            Button("Select a Clip") {
                showPhotosPicker = true
            }
            .buttonStyle(SelectClipButtonStyle())
            .accessibilityLabel("Select a video clip from your library")
        }
        .padding(.horizontal, Spacing.lg)
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

// MARK: - Workflow Step Indicator
/// Shows current position in the add move workflow
struct WorkflowStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accent : Color.neutralGray200)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Step \(currentStep) of \(totalSteps)")
    }
}

// MARK: - Workflow Step Row
/// Shows a single step in the workflow preview
struct WorkflowStepRow: View {
    let number: Int
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(isActive ? Color.accent : Color.neutralGray200)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .white : .textSecondary)
            }

            // Step text
            Text(text)
                .font(.bodySmall)
                .foregroundColor(isActive ? .textPrimary : .textSecondary)
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