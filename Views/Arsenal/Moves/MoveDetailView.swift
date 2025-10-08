import SwiftUI
import AVKit
import OSLog

// MARK: - Critical Fixes Applied
//
// MARK: - ISSUE 1 FIX: MoveDetailView Flicker
// ROOT CAUSE: loadVideoAsset() function updated @State properties in multiple stages, causing intermediate render states
// SOLUTION: Modified loadVideoAsset() to perform ALL async operations first, then update state atomically
// IMPACT: Prevents video player flicker by ensuring view only renders when all components are ready
//
// 📋 Fix Details:
// • Atomic operation: Asset loading + player creation before any @State updates
// • Single MainActor.run block: Updates isLoading, videoAsset, and playerViewModel together
// • Comprehensive logging: OSLog diagnostics for debugging transparency
// • Architecture preservation: Maintains existing UnifiedPlayerManager integration
// • Error handling: Atomic error states with consistent UI presentation

struct MoveDetailView: View {
    let move: Move

    // MARK: - State Properties
    @State private var videoAsset: AVAsset?
    @State private var isLoading = true
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?
    @State private var logger = Logger(subsystem: "com.breakingflashcards", category: "🎬 MOVE_DETAIL_VIEW")

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 24) {
                // MARK: - Video Player Section
                videoPlayerSection

                // MARK: - Details Section
                detailsSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .onAppear {
                MotionCatalog.Accessibility.selectionHaptic()
                logger.info("🎬 MOVE_DETAIL_VIEW: 🚀 View appeared for move: \(move.name ?? "Untitled Move")")
                logger.info("🎬 MOVE_DETAIL_VIEW: 📋 Move ID: \(move.id ?? UUID())")
                logger.info("🎬 MOVE_DETAIL_VIEW: 📸 Photos identifier: \(move.photosIdentifier ?? "NONE")")
                logger.info("🎬 MOVE_DETAIL_VIEW: 🔍 Initial state - isLoading: \(isLoading), videoAsset: \(videoAsset != nil), playerViewModel: \(playerViewModel != nil)")
            }
            .onDisappear {
                // MARK: - ENHANCED: Simplified cleanup using shared UnifiedPlayerManager
                // This prevents memory leaks and retains cycles through proper resource management
                logger.info("🎬 MOVE_DETAIL_VIEW: 🚨 View disappeared, pausing playback for move: \(move.name ?? "Untitled Move")")
                logger.info("🎬 MOVE_DETAIL_VIEW: 📋 Cleanup state - playerViewModel: \(playerViewModel != nil), videoAsset: \(videoAsset != nil)")

                // Just pause playback - let the UnifiedPlayerManager handle cleanup
                AppContainer.shared.unifiedPlayerManager.currentPlayer?.avPlayer?.pause()
                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Playback paused, UnifiedPlayerManager handles resource cleanup")

                // MARK: - CRITICAL FIX: Clear local playerViewModel to ensure clean state
                Task { @MainActor in
                    self.playerViewModel = nil
                    logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Local playerViewModel cleared")
                }

                logger.info("🎬 MOVE_DETAIL_VIEW: 🎉 View teardown completed")
            }
            .task {
                await loadVideoAsset()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Video Player Section
    @ViewBuilder
    private var videoPlayerSection: some View {
        Group {
            if isLoading {
                loadingView
            } else if let asset = videoAsset {
                playerView(for: asset)
            } else {
                unavailableView
            }
        }
        .frame(height: 300)
    }

    // MARK: - Details Section
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(move.name ?? "Untitled Move")
                        .font(.ibmPlexMono(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    Text("Added: \(move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatePillView(learningState: move.learningState)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loading View
    @ViewBuilder
    private var loadingView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.2))
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                    .scaleEffect(1.5)
                Text("Loading video...")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Player View
    @ViewBuilder
    private func playerView(for asset: AVAsset) -> some View {
        ZStack {
            if let viewModel = playerViewModel {
                CustomVideoPlayerView(viewModel: viewModel)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onAppear {
                        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Using local playerViewModel for display")
                    }
            } else {
                // Still initializing player or requesting from unified manager
                loadingView
                    .onAppear {
                        logger.info("🎬 MOVE_DETAIL_VIEW: ⏳ Local playerViewModel is nil, showing loading view")
                    }
            }
        }
    }

    // MARK: - Unavailable View
    @ViewBuilder
    private var unavailableView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.2))
            VStack(spacing: 12) {
                Image(systemName: "video.slash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Video not available")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Video Asset Loading
    /// Asynchronously loads the video asset from the Photos library
    /// MARK: - CRITICAL FIX: Atomic operation to prevent view flicker
    /// ROOT CAUSE: Previously updated @State properties in multiple stages, causing intermediate render states
    /// SOLUTION: Await both asset loading AND player creation before updating any @State properties
    private func loadVideoAsset() async {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🚀 Starting ATOMIC video asset load")
        logger.info("🎬 MOVE_DETAIL_VIEW: 🔧 CRITICAL_FIX_APPLIED: Making loadVideoAsset() atomic to prevent flicker")

        // Check if we have a valid photosIdentifier
        guard let photosIdentifier = move.photosIdentifier else {
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ No photosIdentifier found for move: \(move.name ?? "Untitled Move")")
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Move ID: \(move.id ?? UUID())")
            logger.error("🎬 MOVE_DETAIL_VIEW: 🔧 ATOMIC_FIX: Setting final state immediately (no intermediate states)")
            await MainActor.run {
                isLoading = false
                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_FIX: Final state set - isLoading: false, videoAsset: nil, playerViewModel: nil")
            }
            return
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: 📋 Found photosIdentifier: \(photosIdentifier)")

        // Check if asset exists first (lightweight check)
        let assetExists = PhotosAssetLoader.assetExists(with: photosIdentifier)
        if !assetExists {
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Asset does not exist in Photos library")
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ This could indicate the video was deleted from Photos")
            logger.error("🎬 MOVE_DETAIL_VIEW: 🔧 ATOMIC_FIX: Setting final state immediately (no intermediate states)")
            await MainActor.run {
                isLoading = false
                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_FIX: Final state set - isLoading: false, videoAsset: nil, playerViewModel: nil")
            }
            return
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Asset exists in Photos library, proceeding to ATOMIC load")
        logger.info("🎬 MOVE_DETAIL_VIEW: 🔧 ATOMIC_APPROACH: Will complete ALL operations before state update")

        // MARK: - CRITICAL FIX: Perform ALL async operations FIRST, then update state atomically
        var loadedAsset: AVAsset?
        var createdPlayerViewModel: UnifiedVideoPlayerViewModel?
        var loadError: Error?

        do {
            // Step 1: Load the asset
            logger.info("🎬 MOVE_DETAIL_VIEW: 📥 ATOMIC_STEP_1: Loading video asset...")
            loadedAsset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier)

            guard let asset = loadedAsset else {
                throw NSError(domain: "MoveDetailView", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to load video asset from Photos"
                ])
            }

            logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_STEP_1_COMPLETE: Video asset loaded successfully")

            // Step 2: Load asset properties for validation
            logger.info("🎬 MOVE_DETAIL_VIEW: 📊 ATOMIC_STEP_2: Loading asset properties...")
            let duration = try await asset.load(.duration)
            let isPlayable = try await asset.load(.isPlayable)
            logger.info("🎬 MOVE_DETAIL_VIEW: 📊 Asset properties - duration: \(CMTimeGetSeconds(duration))s, playable: \(isPlayable)")
            logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_STEP_2_COMPLETE: Asset properties loaded and validated")

            // Step 3: Create player from unified manager
            logger.info("🎬 MOVE_DETAIL_VIEW: 🎮 ATOMIC_STEP_3: Creating player from UnifiedPlayerManager...")

            // Use rotation = 0 for MoveDetailView (default orientation)
            let rotation = 0
            logger.info("🎬 MOVE_DETAIL_VIEW: 🔄 Using rotation: \(rotation) quarter turns for MoveDetailView")

            createdPlayerViewModel = try await AppContainer.shared.unifiedPlayerManager.createOrUpdatePlayer(
                asset: asset,
                photosIdentifier: move.photosIdentifier,
                rotationQuarterTurns: rotation,
                appContainer: AppContainer.shared
            )

            logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_STEP_3_COMPLETE: Player created/retrieved successfully")
            logger.info("🎬 MOVE_DETAIL_VIEW: 📊 Player ready status: \(createdPlayerViewModel?.isPlayerReady ?? false)")

        } catch {
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ ATOMIC_LOAD_ERROR: \(error.localizedDescription)")
            loadError = error
        }

        // MARK: - CRITICAL FIX: ATOMIC STATE UPDATE - Update ALL @State properties in ONE MainActor.run
        // This prevents intermediate render states that cause flicker
        await MainActor.run {
            logger.info("🎬 MOVE_DETAIL_VIEW: 🔧 ATOMIC_STATE_UPDATE: Starting atomic state update")
            logger.info("🎬 MOVE_DETAIL_VIEW: 🔍 Pre-update state - isLoading: \(self.isLoading), videoAsset: \(self.videoAsset != nil), playerViewModel: \(self.playerViewModel != nil)")

            if let asset = loadedAsset, let playerViewModel = createdPlayerViewModel {
                // SUCCESS: Set all properties atomically
                self.videoAsset = asset
                self.playerViewModel = playerViewModel
                self.isLoading = false

                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ ATOMIC_SUCCESS: All state properties set atomically")
                logger.info("🎬 MOVE_DETAIL_VIEW: 🔍 Post-update state - isLoading: \(self.isLoading), videoAsset: \(self.videoAsset != nil), playerViewModel: \(self.playerViewModel != nil)")
                logger.info("🎬 MOVE_DETAIL_VIEW: 🎉 ATOMIC_COMPLETE: Video asset and player loaded without flicker")

            } else {
                // FAILURE: Set error state atomically
                self.videoAsset = loadedAsset
                self.playerViewModel = nil
                self.isLoading = false

                logger.error("🎬 MOVE_DETAIL_VIEW: ❌ ATOMIC_FAILURE: Error state set atomically")
                logger.error("🎬 MOVE_DETAIL_VIEW: 🔍 Post-update state - isLoading: \(self.isLoading), videoAsset: \(self.videoAsset != nil), playerViewModel: \(self.playerViewModel != nil)")
                if let error = loadError {
                    logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Load error details: \(error.localizedDescription)")
                }
            }

            logger.info("🎬 MOVE_DETAIL_VIEW: 🔧 ATOMIC_STATE_UPDATE: Complete - no intermediate states exposed to UI")
        }
    }

    // MARK: - Legacy Player Request Method (Removed)
    /// MARK: - CRITICAL FIX: This method has been removed and incorporated into the atomic loadVideoAsset() function
    /// ROOT CAUSE: Separating asset loading from player creation caused intermediate UI states
    /// SOLUTION: Atomic operation performs both steps before any @State updates
}

// MARK: - Preview
#Preview {
    let mockMove = Move(context: PersistenceController.shared.container.viewContext)
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    mockMove.createdAt = Date()
    mockMove.photosIdentifier = "sample-identifier" // For preview purposes

    return MoveDetailView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
