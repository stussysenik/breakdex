import SwiftUI
import AVKit
import OSLog

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
            } else {
                // Still initializing player
                loadingView
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
    /// This replaces the deprecated synchronous getVideoAsset(for:) method
    private func loadVideoAsset() async {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🚀 Starting video asset load")

        // Check if we have a valid photosIdentifier
        guard let photosIdentifier = move.photosIdentifier else {
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ No photosIdentifier found for move: \(move.name ?? "Untitled Move")")
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Move ID: \(move.id ?? UUID())")
            await MainActor.run {
                isLoading = false
            }
            return
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: 📋 Found photosIdentifier: \(photosIdentifier)")

        // Check if asset exists first (lightweight check)
        let assetExists = PhotosAssetLoader.assetExists(with: photosIdentifier)
        if !assetExists {
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Asset does not exist in Photos library")
            logger.error("🎬 MOVE_DETAIL_VIEW: ❌ This could indicate the video was deleted from Photos")
            await MainActor.run {
                isLoading = false
            }
            return
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Asset exists in Photos library, proceeding to load")

        // Fetch the asset asynchronously
        let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier)

        await MainActor.run {
            self.videoAsset = asset
            self.isLoading = false

            if let asset = asset {
                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Video asset loaded successfully")
                logger.info("🎬 MOVE_DETAIL_VIEW: 📊 Asset duration: \(CMTimeGetSeconds(asset.duration))")
                logger.info("🎬 MOVE_DETAIL_VIEW: 📊 Asset is playable: \(asset.isPlayable)")

                // Initialize the player view model
                initializePlayerViewModel(with: asset)
            } else {
                logger.error("🎬 MOVE_DETAIL_VIEW: ❌ Failed to load video asset")
            }
        }
    }

    // MARK: - Player View Model Initialization
    /// Initializes the player view model with the loaded asset
    /// This replaces the deprecated Timer-based polling approach
    private func initializePlayerViewModel(with asset: AVAsset) {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🎮 Initializing player view model")

        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        let viewModel = UnifiedVideoPlayerViewModel(
            player: player,
            mode: .main,
            appContainer: AppContainer.shared
        )

        self.playerViewModel = viewModel
        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Player view model initialized")

        // Log player readiness status for debugging
        logger.info("🎬 MOVE_DETAIL_VIEW: 📊 Player ready status: \(viewModel.isPlayerReady)")
    }
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
