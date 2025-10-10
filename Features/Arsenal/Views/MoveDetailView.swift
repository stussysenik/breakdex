//
//  MoveDetailView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Optimized to use shared components and reduced complexity
//

import SwiftUI
import AVKit
import OSLog

// MARK: - Move Detail View
/// Clean view for displaying move details with optimized video loading
/// Uses shared components and follows single responsibility principle
struct MoveDetailView: View {

    // MARK: - Properties
    let move: Move
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "🎬 MOVE_DETAIL_VIEW")

    // MARK: - State
    @State private var videoAsset: AVAsset?
    @State private var isLoading = true
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?
    @State private var errorMessage: String?

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
            .onDisappear {
                cleanupPlayer()
            }
            .task {
                await loadVideoAsset()
            }
            .alert("Video Error", isPresented: .constant(errorMessage != nil), actions: {
                SharedButton("OK", style: .secondary) {
                    errorMessage = nil
                }
            }, message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            })
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Video Player Section
    @ViewBuilder
    private var videoPlayerSection: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading video...", style: .spinner)
                    .frame(height: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.1))
                    )
            } else if let asset = videoAsset {
                playerView(for: asset)
            } else {
                unavailableVideoView
            }
        }
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

                    // Additional move details if available
                    if let trimStartTime = move.trimStartTime,
                       let trimEndTime = move.trimEndTime,
                       trimEndTime > trimStartTime {
                        Text("Duration: \(String(format: "%.1f", trimEndTime - trimStartTime))s")
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatePillView(learningState: move.learningState)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Player View
    @ViewBuilder
    private func playerView(for asset: AVAsset) -> some View {
        ZStack {
            if let viewModel = playerViewModel {
                VideoPlayerView(
                    viewModel: viewModel,
                    configuration: .default,
                    controlsEnabled: true
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Fallback loading state
                LoadingView(message: "Preparing player...", style: .minimal)
                    .frame(height: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Unavailable Video View
    @ViewBuilder
    private var unavailableVideoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 300)

            VStack(spacing: 12) {
                Image(systemName: "video.slash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)

                Text("Video not available")
                    .font(.ibmPlexMono(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("The video may have been deleted from Photos")
                    .font(.ibmPlexMono(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Video Asset Loading
    /// Simplified and optimized video asset loading
    private func loadVideoAsset() async {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🚀 Starting optimized video asset load")

        // Validate photos identifier
        guard let photosIdentifier = move.photosIdentifier else {
            await handleError("No video identifier found for this move")
            return
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: 📋 Loading video with identifier: \(photosIdentifier)")

        // Check if asset exists
        guard PhotosAssetLoader.assetExists(with: photosIdentifier) else {
            await handleError("Video not found in Photos library")
            return
        }

        // Perform atomic loading to prevent UI flicker
        do {
            let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier)
            guard let asset = asset else {
                await handleError("Failed to load video from Photos")
                return
            }

            // Validate asset properties
            let duration = try await asset.load(.duration)
            let isPlayable = try await asset.load(.isPlayable)

            guard isPlayable else {
                await handleError("Video is not playable")
                return
            }

            logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Asset loaded - duration: \(CMTimeGetSeconds(duration))s")

            // Create player from unified manager
            let playerViewModel = try await AppContainer.shared.unifiedPlayerManager.createOrUpdatePlayer(
                asset: asset,
                photosIdentifier: photosIdentifier,
                rotationQuarterTurns: 0,
                appContainer: AppContainer.shared
            )

            // Atomic state update
            await MainActor.run {
                self.videoAsset = asset
                self.playerViewModel = playerViewModel
                self.isLoading = false
                logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Video loaded successfully")
            }

        } catch {
            await handleError("Failed to load video: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Handling
    /// Centralized error handling for video loading
    private func handleError(_ message: String) async {
        logger.error("🎬 MOVE_DETAIL_VIEW: ❌ \(message)")
        await MainActor.run {
            self.errorMessage = message
            self.isLoading = false
        }
    }

    // MARK: - Player Cleanup
    /// Simplified player cleanup using unified manager
    private func cleanupPlayer() {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🧹 Cleaning up player resources")

        // Let unified manager handle cleanup
        AppContainer.shared.unifiedPlayerManager.currentPlayer?.avPlayer?.pause()

        // Clear local reference
        Task { @MainActor in
            self.playerViewModel = nil
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Cleanup completed")
    }
}

// MARK: - Preview
#Preview("Move Detail - With Video") {
    let context = PersistenceController.shared.container.viewContext
    let mockMove = Move(context: context)
    mockMove.name = "Windmill"
    mockMove.learningState = "LEARNING"
    mockMove.createdAt = Date()
    mockMove.photosIdentifier = "sample-identifier"
    mockMove.trimStartTime = 0.0
    mockMove.trimEndTime = 5.0

    return NavigationView {
        MoveDetailView(move: mockMove)
    }
    .environment(\.managedObjectContext, context)
}

#Preview("Move Detail - No Video") {
    let context = PersistenceController.shared.container.viewContext
    let mockMove = Move(context: context)
    mockMove.name = "Top Rock"
    mockMove.learningState = "MASTERY"
    mockMove.createdAt = Date()
    // No photos identifier to test unavailable state

    return NavigationView {
        MoveDetailView(move: mockMove)
    }
    .environment(\.managedObjectContext, context)
}