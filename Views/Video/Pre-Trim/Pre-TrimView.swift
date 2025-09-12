import SwiftUI
import AVKit
import OSLog
import PhotosUI
import Foundation
import UIKit

private let logger = Logger(subsystem: "com.breakingflashcards", category: "PreTrimView")

struct PreTrimView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @ObservedObject private var observableWrapper: ObservableVideoPlayerWrapper // Type-erased wrapper
    var playerViewModel: any VideoPlayerViewModelProtocol { // Computed property for access
        return observableWrapper.viewModel
    }
    let asset: AVAsset
    let photosIdentifier: String?
    let rotationQuarterTurns: Int
    @Binding var selectedTab: TabSelection

    // Track view lifecycle for debugging
    private let viewId = UUID()
    private let constructionTime = Date().timeIntervalSince1970

    init(viewModel: AddMoveViewModel, playerViewModel: any VideoPlayerViewModelProtocol, asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int, selectedTab: Binding<TabSelection>) {
        self.viewModel = viewModel
        self.observableWrapper = ObservableVideoPlayerWrapper(viewModel: playerViewModel) // Initialize the wrapper
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.rotationQuarterTurns = rotationQuarterTurns
        self._selectedTab = selectedTab
    }
    
    // Haptic feedback generator
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        let bodyTimestamp = Date().timeIntervalSince1970
        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"

        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Body evaluated on \(threadInfo) thread")
        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Time since construction: \(String(format: "%.3f", bodyTimestamp - constructionTime))s")
        // logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Memory pressure: \(MemoryMonitor.currentPressure())")

        let content = mainContent

        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: ✅ BODY COMPUTATION COMPLETED - returning mainContent")

        return content
            .onAppear {
                let appearTimestamp = Date().timeIntervalSince1970
                let threadInfo = Thread.isMainThread ? "MAIN" : "BG"

                // Log initialization details now that view is fully constructed
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Initialized on \(threadInfo) thread")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Asset: \(asset.description.prefix(50))...")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Rotation: \(rotationQuarterTurns)")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Photos ID: \(photosIdentifier ?? "nil")")

                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: View appeared - starting safe async setup")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Construction to appear: \(String(format: "%.3f", appearTimestamp - constructionTime))s")

                // Perform async setup after view is fully constructed
                Task {
                    let taskStartTime = Date().timeIntervalSince1970
                    logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Starting safe async operations")

                    do {
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Starting playerViewModel.waitForReady()")
                        try await playerViewModel.waitForReady()
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: playerViewModel.waitForReady() completed successfully")

                        let taskEndTime = Date().timeIntervalSince1970
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: All async operations completed successfully")
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Total time: \(String(format: "%.3f", taskEndTime - taskStartTime)) seconds")
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Final state: player ready")

                    } catch {
                        let errorTime = Date().timeIntervalSince1970
                        logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Async operation failed")
                        logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error: \(error.localizedDescription)")
                        logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error type: \(type(of: error))")
                        logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error context: setup phase after \(String(format: "%.3f", errorTime - taskStartTime))s")

                        // Log additional error context
                        if let nsError = error as NSError? {
                            logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error domain: \(nsError.domain)")
                            logger.error("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error code: \(nsError.code)")
                        }

                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Setting error state on main viewModel")
                        viewModel.state = .error(message: "Failed to prepare video for preview.", underlyingError: error.localizedDescription)
                        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Error state set")
                    }
                }
            }
            .onDisappear {
                let disappearTime = Date().timeIntervalSince1970
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: View disappeared")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Total lifetime: \(String(format: "%.3f", disappearTime - constructionTime))s")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Final player state: \(String(describing: playerViewModel.state))")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Final player is ready: \(playerViewModel.isPlayerReady)")
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            renderHeader()
            renderVideoPlayerSection()
            renderActionButtons()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: - UI Components

    private func renderHeader() -> some View {
        HStack {
            Button(action: {
                impactGenerator.impactOccurred()
                logger.info("🎬 PRE_TRIM_VIEW: Back button tapped")
                viewModel.reset()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
            Text(viewModel.selectedFilename ?? "Video Preview")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                impactGenerator.impactOccurred()
                logger.info("🎬 PRE_TRIM_VIEW: Change video button tapped")
                viewModel.state = .selectingVideo(currentAsset: asset)
            }) {
                Text("Change")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }

    private func renderVideoPlayerSection() -> some View {
        logger.info("🎬 PRE_TRIM_VIEW: Rendering video player section with directly provided ViewModel.")
        logger.info("🎬 PRE_TRIM_VIEW: Player is ready: \(playerViewModel.isPlayerReady)")
        
        // Pass the guaranteed-to-be-ready playerViewModel.
        return CustomVideoPlayerView(viewModel: playerViewModel) 
            .cornerRadius(12)
            .padding(.horizontal)
    }

    private func renderActionButtons() -> some View {
        VStack(spacing: 16) {
            Button(action: {
                impactGenerator.impactOccurred()
                logger.info("🎬 PRE_TRIM_VIEW: Trim & Edit button tapped")
                viewModel.startTrimming()
            }) {
                Text("Trim & Edit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary(size: .large))

            Button(action: {
                impactGenerator.impactOccurred()
                logger.info("🎬 PRE_TRIM_VIEW: Use Full Video button tapped")
                viewModel.startNaming()
            }) {
                Text("Use Full Video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appSecondary(size: .large))
        }
        .padding()
    }

    // MARK: - State Validation and Fallback

    private func renderFallbackUI() -> some View {
        logger.info("🎬 PRE_TRIM_VIEW: Rendering fallback UI")

        return VStack {
            Spacer()
            Text("Unable to load video preview")
                .font(.headline)
                .foregroundColor(.white)
            Text("The video may be corrupted or in an unsupported format.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Go Back") {
                logger.info("🎬 PRE_TRIM_VIEW: Fallback - Go Back button tapped")
                viewModel.reset()
                selectedTab = .add
                logger.info("🎬 PRE_TRIM_VIEW: Fallback - Reset completed")
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            logger.info("🎬 PRE_TRIM_VIEW: Fallback UI appeared")
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let viewModel = AddMoveViewModel(viewContext: context)
    let asset = AVAsset() // Dummy asset for preview
    let playerViewModel = UpdatedVideoPlayerViewModel(asset: asset, rotationQuarterTurns: 0, appContainer: AppContainer.shared)

    return PreTrimView(
        viewModel: viewModel,
        playerViewModel: playerViewModel,
        asset: asset,
        photosIdentifier: "preview-id",
        rotationQuarterTurns: 0,
        selectedTab: .constant(.add)
    )
    .environment(\.managedObjectContext, context)
    .preferredColorScheme(.dark)
}