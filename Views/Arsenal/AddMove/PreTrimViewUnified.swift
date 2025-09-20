import SwiftUI
import AVFoundation
import OSLog
import PhotosUI

private let logger = Logger(subsystem: "com.breakingflashcards", category: "PreTrimViewUnified")

/// State-driven Pre-Trim view that uses AddMoveUnifiedState
/// Eliminates direct ViewModel dependencies and State Object Churn
struct PreTrimViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @Binding var selectedTab: TabSelection
    
    // MARK: - State
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosPickerItem?
    
    // MARK: - Initialization
    init(unifiedState: AddMoveUnifiedState, selectedTab: Binding<TabSelection>) {
        self.unifiedState = unifiedState
        self._selectedTab = selectedTab
        
        logger.info("🎬 PRE_TRIM_UNIFIED: Initialized with unified state")
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let playerViewModel = unifiedState.currentPlayerViewModel {
                mainContent(with: playerViewModel)
            } else {
                loadingView
            }
        }
        .onAppear {
            logger.info("🎬 PRE_TRIM_UNIFIED: View appeared - player available: \(unifiedState.currentPlayerViewModel != nil)")
        }
        .onDisappear {
            logger.info("🎬 PRE_TRIM_UNIFIED: View disappeared - preparing for transition")
            unifiedState.prepareForTransition()
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $tempSelection,
            matching: .videos,
            preferredItemEncoding: .automatic,
            photoLibrary: .shared()
        )
        .onChange(of: tempSelection) { _, newItem in
            if let newItem = newItem {
                handleVideoSelection(newItem)
                tempSelection = nil
            }
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private func mainContent(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 0) {
            renderHeader()
            Spacer()
            renderVideoPlayerSection(with: playerViewModel)
                .padding(.bottom, 10)
            Spacer()
            renderActionButtons()
            Spacer()
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }
    
    // MARK: - UI Components
    
    private func renderHeader() -> some View {
        HStack {
            Button(action: {
                handleBackButton()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
            Text("Video Preview")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                showPhotosPicker = true
            }) {
                Text("Change")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private func renderVideoPlayerSection(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        logger.info("🎬 PRE_TRIM_UNIFIED: Rendering video player - ready: \(playerViewModel.isPlayerReady)")
        
        return CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false)
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    private func renderActionButtons() -> some View {
        VStack(spacing: 20) {
            Button(action: {
                handleTrimAndEdit()
            }) {
                Text("Trim & Edit")
                    .frame(maxWidth: 275)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(!unifiedState.canProceed)

            Button(action: {
                handleUseFullVideo()
            }) {
                Text("Use Full Video")
                    .frame(maxWidth: 275)
            }
            .buttonStyle(.appSecondary(size: .medium))
            .disabled(!unifiedState.canProceed)
        }
        .padding(.bottom, 10)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Preparing video...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Action Handlers
    
    private func handleBackButton() {
        logger.info("🎬 PRE_TRIM_UNIFIED: Back button tapped - resetting to ready state")
        
        // Pause player before transition
        unifiedState.currentPlayerViewModel?.avPlayer?.pause()
        
        // Reset unified state
        unifiedState.reset()
        
        // Switch back to add tab
        selectedTab = .add
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem) {
        logger.info("🎬 PRE_TRIM_UNIFIED: New video selected - \(item.itemIdentifier ?? "unknown")")
        
        // Update unified state with new selection
        unifiedState.didSelectVideo(item)
    }
    
    private func handleTrimAndEdit() {
        logger.info("🎬 PRE_TRIM_UNIFIED: Trim & Edit button tapped")
        
        // Transition to trimming state
        unifiedState.transitionTo(.trimming)
    }
    
    private func handleUseFullVideo() {
        logger.info("🎬 PRE_TRIM_UNIFIED: Use Full Video button tapped")
        
        // Set trim range to full video
        guard let asset = unifiedState.videoAsset else {
            unifiedState.setError(message: "No video asset available")
            return
        }
        
        Task {
            do {
                // Apply full video trim (no actual trimming needed)
                try await unifiedState.applyTrimSettings(
                    startTime: 0.0,
                    endTime: asset.duration.seconds,
                    rotation: unifiedState.rotationQuarterTurns
                )
                
                // Transition to naming state
                unifiedState.transitionTo(.naming)
            } catch {
                unifiedState.setError(message: "Failed to prepare video", underlying: error.localizedDescription)
            }
        }
    }
}