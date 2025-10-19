import SwiftUI
import PhotosUI

// SelectClip.swift - "select a clip" UI

// MARK: - SelectClip
/// Enhanced view for selecting a clip with loading feedback
/// Updated to work with simplified AddMoveViewModel
struct SelectClip: View {
    @Binding var selectedTab: TabSelection
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
        let observationTimestamp = CFAbsoluteTimeGetCurrent()
        Logger.addMove.info("SelectClip: State transition: \(viewModel.loadingState) → \(newState)", emoji: "🔄")
        Logger.addMove.debug("SelectClip: Player ready: \(viewModel.videoPlayer.isReady), Loading progress: \(viewModel.progressPercentage)%", emoji: "📊")
        Logger.addMove.debug("🎯 UI Observation: SelectClip observed state at \(observationTimestamp)s")
        logger.debug("🔍 PROOF: SELECTCLIP observing state change at \(observationTimestamp)")

        switch newState {
        case .idle:
            // Ready state - no active loading
            logger.debug("🔍 PROOF: SELECTCLIP observed idle state")
            break

        case .loading(let progress, let stage, _):
            // Track intermediate loading states with detailed observation logging
            let calculatedProgress = newState.progress
            let rawProgressPercent = Int(progress * 100)
            let calculatedProgressPercent = Int(calculatedProgress * 100)

            logger.debug("🔍 PROOF: SELECTCLIP observing loading state:")
            logger.debug("🔍 PROOF: Raw progress parameter: \(progress) (\(rawProgressPercent)%)")
            logger.debug("🔍 PROOF: Calculated progress property: \(calculatedProgress) (\(calculatedProgressPercent)%)")
            logger.debug("🔍 PROOF: Loading stage: \(stage)")
            logger.debug("🔍 PROOF: State observation timing: \(observationTimestamp)")

            Logger.addMove.debug("SelectClip: Loading progress observed - raw: \(rawProgressPercent)%, calculated: \(calculatedProgressPercent)% (\(stage))", emoji: "📊")
            Logger.addMove.debug("🎯 UI Observation: \(stage) state observed at \(observationTimestamp)s")

            // Detect suspicious same-frame state updates (< 16.67ms indicates potential frame coalescing)
            if let lastObservationTime = lastStateObservationTime {
                let timeDelta = observationTimestamp - lastObservationTime
                if timeDelta < 0.0167 { // Less than one frame at 60fps
                    Logger.addMove.warning("⚠️ Potential frame coalescing detected: State update observed within \(String(format: "%.3f", timeDelta * 1000))ms")
                }
            }
            lastStateObservationTime = observationTimestamp

        case .fullyReady:
            // Only transition when video player is fully ready for trimming
            Logger.addMove.info("SelectClip: Video player fully ready - transitioning to trimming", emoji: "✅")
            Logger.addMove.info("SelectClip: Transitioning to trimming - PlayerReady: \(viewModel.videoPlayer.isReady), Asset: \(viewModel.selectedVideo != nil)", emoji: "✅")
            Logger.addMove.info("🎯 SelectClip: About to call onStepChange(.trimming) - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "🎯")
            onStepChange(.trimming)
            Logger.addMove.info("✅ SelectClip: onStepChange(.trimming) completed", emoji: "✅")

        case .assetReady, .playerReady:
            // Continue loading - don't transition yet
            Logger.addMove.debug("SelectClip: Video loading in progress - \(newState)", emoji: "⏳")

        case .failed(let message):
            // Handle error state - stay in selecting state, let UI show error
            Logger.addMove.error("SelectClip: Video loading failed: \(message)", emoji: "❌")
            // Step change handled by parent error handling
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

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