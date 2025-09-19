import SwiftUI
import AVFoundation
import Photos
import os.log

private let logger = Logger(subsystem: "com.breakingflashcards", category: "PreTrimContainerView")

/// A container view that manages the loading state transition for Pre-Trim with real-time progress
struct PreTrimContainerView: View {
    @State private var playerViewModel: UnifiedVideoPlayerViewModel
    @State private var showLoadingOverlay = true
    @StateObject private var unifiedPlayerManager: UnifiedPlayerManager
    let phAsset: PHAsset
    let rotationQuarterTurns: Int
    let onLoadingComplete: () -> Void
    let onError: (String, Error?) -> Void
    
    // Track view lifecycle for debugging
    private let viewId = UUID()
    private let constructionTime = Date().timeIntervalSince1970
    
    init(
        phAsset: PHAsset,
        rotationQuarterTurns: Int,
        appContainer: AppContainer,
        onLoadingComplete: @escaping () -> Void,
        onError: @escaping (String, Error?) -> Void
    ) {
        self.phAsset = phAsset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onLoadingComplete = onLoadingComplete
        self.onError = onError
        
        // Initialize the view model with the new progress-aware loading
        self.playerViewModel = UnifiedVideoPlayerViewModel(
            player: AVPlayer(), // Corrected: Use a valid, empty player as a placeholder
            mode: .preview,
            appContainer: appContainer
        )
        
        // Initialize unified player manager
        self._unifiedPlayerManager = StateObject(wrappedValue: UnifiedPlayerManager())
        
        // Logging moved to onAppear to avoid capturing self during init
    }
    
    var body: some View {
        let bodyTimestamp = Date().timeIntervalSince1970
        
        logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Body evaluated")
        
        return ZStack {
            // Main content - always present but conditionally visible
            PreTrimView(
                viewModel: AddMoveViewModel.create(viewContext: PersistenceController.shared.container.viewContext),
                playerViewModel: self.playerViewModel, // Pass the container's ViewModel down
                asset: playerViewModel.playerItem?.asset ?? AVAsset(url: URL(fileURLWithPath: "")), // Fallback remains for safety
                photosIdentifier: phAsset.localIdentifier,
                rotationQuarterTurns: rotationQuarterTurns,
                selectedTab: .constant(.add),
                unifiedPlayerManager: unifiedPlayerManager
            )
            .opacity(showLoadingOverlay ? 0 : 1)
            .animation(.linear(duration: 0.1), value: showLoadingOverlay)
            
            // Loading overlay - visible during loading
            if showLoadingOverlay {
                LoadingOverlayView(
                    progress: getProgressFromState(),
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
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: View appeared")
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Created playerViewModel (viewId: \(viewId.uuidString.prefix(8)), mode: preview)")
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: PreTrimView created with shared playerViewModel (state: \(String(describing: self.playerViewModel.state)), playerExists: \(self.playerViewModel.avPlayer != nil), itemExists: \(self.playerViewModel.playerItem != nil))")
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Starting progressive video loading")
            
            // Start progressive loading
            startProgressiveLoading()
        }
        .onDisappear(perform: {
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: View disappeared")
            playerViewModel.teardown()
        })
    }
    
    // MARK: - Private Methods
    
    private func startProgressiveLoading() {
        logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Starting progressive loading for asset: \(phAsset.localIdentifier)")
        logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Current player state before loading: \(String(describing: playerViewModel.state))")
        
        // Use the available loadVideo method
        Task { @MainActor in
            logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: 🚀 Entering loadVideo Task")
            do {
                logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: ⬇️ Calling playerViewModel.loadVideo...")
                try await playerViewModel.loadVideo(from: .photos(identifier: phAsset.localIdentifier), quarterTurns: rotationQuarterTurns)
                logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: ✅ loadVideo completed successfully")
                
                // Loading completed - hide overlay with 0.1s animation and call completion
                await MainActor.run {
                    logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: 🎬 Hiding loading overlay and calling completion")
                    let oldOverlayState = self.showLoadingOverlay
                    withAnimation(.linear(duration: 0.1)) {
                        self.showLoadingOverlay = false
                    }
                    logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: Loading overlay state: \(oldOverlayState) → \(self.showLoadingOverlay)")
                    self.onLoadingComplete()
                    logger.info("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: ✅ onLoadingComplete() called")
                }
            } catch {
                logger.error("🎬 PRE_TRIM_CONTAINER [\(viewId.uuidString.prefix(8))]: ❌ loadVideo failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.onError("Failed to load video", error)
                }
            }
        }
    }
    
    private func getProgressFromState() -> Double {
        guard case .loading(let progress, _, _) = playerViewModel.state else {
            return 0.0
        }
        return progress
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