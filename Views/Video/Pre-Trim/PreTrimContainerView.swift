import SwiftUI
import AVFoundation
import Photos
import os.log

private let logger = Logger(subsystem: "com.breakingflashcards", category: "PreTrimContainerView")

/// A container view that manages the loading state transition for Pre-Trim with real-time progress
struct PreTrimContainerView: View {
    @StateObject private var playerViewModel: UnifiedVideoPlayerViewModel
    @State private var showLoadingOverlay = true
    let phAsset: PHAsset
    let rotationQuarterTurns: Int
    let onLoadingComplete: (AVPlayerItem) -> Void
    let onError: (String, Error?) -> Void
    
    // Track view lifecycle for debugging
    private let viewId = UUID()
    private let constructionTime = Date().timeIntervalSince1970
    
    init(
        phAsset: PHAsset,
        rotationQuarterTurns: Int,
        appContainer: AppContainer,
        onLoadingComplete: @escaping (AVPlayerItem) -> Void,
        onError: @escaping (String, Error?) -> Void
    ) {
        self.phAsset = phAsset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onLoadingComplete = onLoadingComplete
        self.onError = onError
        
        // Initialize the view model with the new progress-aware loading
        self._playerViewModel = StateObject(wrappedValue: UnifiedVideoPlayerViewModel(
            asset: AVAsset(), // Temporary asset, will be replaced during loading
            rotationQuarterTurns: rotationQuarterTurns,
            mode: .preview,
            appContainer: appContainer
        ))
    }
    
    var body: some View {
        let bodyTimestamp = Date().timeIntervalSince1970
        
        logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Body evaluated")
        
        return ZStack {
            // Main content - always present but conditionally visible
            PreTrimView(
                viewModel: AddMoveViewModel.create(viewContext: PersistenceController.shared.container.viewContext),
                asset: playerViewModel.playerItem?.asset ?? AVAsset(),
                photosIdentifier: phAsset.localIdentifier,
                rotationQuarterTurns: rotationQuarterTurns,
                selectedTab: .constant(.add)
            )
            .opacity(showLoadingOverlay ? 0 : 1)
            .animation(.linear(duration: 0.1), value: showLoadingOverlay)
            
            // Loading overlay - visible during loading
            if showLoadingOverlay || playerViewModel.isLoading {
                LoadingOverlayView(
                    progress: playerViewModel.progress,
                    status: getStatusFromState() ?? "Loading..."
                )
                .transition(.opacity.animation(.linear(duration: 0.1)))
            }
            
            // Error overlay
            if case .error(let message) = playerViewModel.state {
                ErrorView(
                    message: message,
                    onRetry: { retryLoading() },
                    onCancel: { onError(message, nil) }
                )
                .transition(.opacity.animation(.linear(duration: 0.1)))
            }
        }
        .onAppear {
            let appearTimestamp = Date().timeIntervalSince1970
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: View appeared")
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Starting progressive video loading")
            
            // Start progressive loading
            startProgressiveLoading()
        }
        .onDisappear {
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: View disappeared")
            playerViewModel.cancelLoading()
        }
    }
    
    // MARK: - Private Methods
    
    private func startProgressiveLoading() {
        logger.info("🎬 PRE_TRIM_CONTAINER: Starting progressive loading for asset: \(phAsset.localIdentifier)")
        
        // Use the new progress-aware loading method
        playerViewModel.loadVideoWithProgress(from: phAsset) {
            // Loading completed - hide overlay with 0.1s animation
            withAnimation(.linear(duration: 0.1)) {
                self.showLoadingOverlay = false
            }
        }
    }
    
    private func getStatusFromState() -> String? {
        guard case .loading(_, _, let status) = playerViewModel.state else {
            return nil
        }
        return status
    }
    
    private func retryLoading() {
        logger.info("🎬 PRE_TRIM_CONTAINER: Retrying video loading")
        showLoadingOverlay = true
        startProgressiveLoading()
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Loading Failed")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.appPrimary(size: .medium))
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.appSecondary(size: .medium))
            }
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}