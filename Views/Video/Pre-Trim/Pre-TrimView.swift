import SwiftUI
import AVKit
import OSLog
import PhotosUI
import Foundation
import UIKit

private let logger = Logger(subsystem: "com.breakingflashcards", category: "PreTrimView")

struct PreTrimView: View {
    var viewModel: AddMoveViewModel
    @ObservedObject private var playerViewModel: UnifiedVideoPlayerViewModel
    let asset: AVAsset
    let photosIdentifier: String?
    let rotationQuarterTurns: Int
    @Binding var selectedTab: TabSelection
    
    // Direct PhotosPicker state
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosPickerItem?
    
    // Track view lifecycle for debugging
    private let viewId = UUID()
    private let constructionTime = Date().timeIntervalSince1970
    
    init(viewModel: AddMoveViewModel, playerViewModel: UnifiedVideoPlayerViewModel, asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int, selectedTab: Binding<TabSelection>) {
        self.viewModel = viewModel
        self.playerViewModel = playerViewModel // Assign the received ViewModel
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.rotationQuarterTurns = rotationQuarterTurns
        self._selectedTab = selectedTab
        
        // Log initialization in onAppear to avoid capturing self during init
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
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: PlayerViewModel state: \(String(describing: playerViewModel.state))")
                
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: View appeared - loading video with unified player")
                logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Construction to appear: \(String(format: "%.3f", appearTimestamp - constructionTime))s")
                
                // Video loading is handled automatically by UnifiedVideoPlayerViewModel
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
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $tempSelection,
            matching: .videos,
            preferredItemEncoding: .automatic, // iOS 18.0 best practice - let system choose optimal encoding
            photoLibrary: .shared()
        )
        .onChange(of: tempSelection) { _, newItem in
            if let newItem = newItem {
                logger.info("🎬 PRE_TRIM_VIEW: Direct PhotosPicker selection received: \(newItem.itemIdentifier ?? "unknown")")
                // Handle the new selection directly without intermediate state
                Task {
                    await viewModel.handleDirectVideoSelection(newItem)
                }
                tempSelection = nil // Reset for next use
            }
        }
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
            Text("Video Preview")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                impactGenerator.impactOccurred()
                logger.info("🎬 PRE_TRIM_VIEW: Change video button tapped - showing direct PhotosPicker")
                showPhotosPicker = true
            }) {
                Text("Change")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private func renderVideoPlayerSection() -> some View {
        logger.info("🎬 PRE_TRIM_VIEW [\(viewId.uuidString.prefix(8))]: Rendering video player section (state: \(String(describing: playerViewModel.state)), playerExists: \(playerViewModel.avPlayer != nil), itemExists: \(playerViewModel.playerItem != nil), isReady: \(playerViewModel.isPlayerReady), health: \(String(describing: playerViewModel.healthStatus)))")
        
        // Use the unified video player with the view model
        return CustomVideoPlayerView(viewModel: playerViewModel)
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    private func renderActionButtons() -> some View {
        return VStack(spacing: 16) {
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

