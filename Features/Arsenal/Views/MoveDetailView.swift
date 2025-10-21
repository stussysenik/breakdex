//
//  MoveDetailView.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 10/10/25.
//  Optimized to use shared components and reduced complexity
//

import SwiftUI
import AVKit
import CoreData
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
    @State private var player: SharedVideoPlayer?
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
                // Simple haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                logger.info("🎬 NAVIGATION_PROOF: MoveDetailView appeared SUCCESSFULLY for move: \(move.name ?? "Untitled Move") - NavigationLink worked!")
                logger.info("🎬 MOVE_DETAIL_VIEW: 🚀 View appeared for move: \(move.name ?? "Untitled Move")")

                // Enhanced specific video instance logging
                logSpecificVideoInstanceDetails()
            }
            .onDisappear {
                cleanupPlayer()
            }
            .task {
                await loadVideoAsset()
            }
            .alert("Video Error", isPresented: .constant(errorMessage != nil), actions: {
                SharedButton(title: "OK", style: .secondary) {
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
                SharedLoadingView(message: "Loading video...")
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
                    if move.trimEndTime > move.trimStartTime {
                        Text("Duration: \(String(format: "%.1f", move.trimEndTime - move.trimStartTime))s")
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StatePillView(learningState: move.learningState ?? "NEW")
                    .fixedSize()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Player View
    @ViewBuilder
    private func playerView(for asset: AVAsset) -> some View {
        ZStack {
            if let player = player {
                // Use the state-managed SharedVideoPlayer with VideoPlayerView
                VideoPlayerView(player: player, showControls: true)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        logger.info("👆 INTERACTION_PROOF: Video tapped - Player type: SharedVideoPlayer, Move: \(move.name ?? "Untitled")")
                    }
            } else {
                // Fallback loading state
                SharedLoadingView(configuration: .minimal)
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
        logger.info("🚀 VIDEO_LOADING_START: MoveDetailView starting video loading")
        logger.info("🎬 MOVE_DETAIL: Move name: \(move.name ?? "Untitled Move")")
        logger.info("🎬 MOVE_DETAIL: Move ID: \(move.objectID)")

        // Validate photos identifier
        guard let photosIdentifier = move.photosIdentifier else {
            logger.error("❌ VIDEO_LOADING_ERROR: No photosIdentifier found for move")
            await MainActor.run {
                self.errorMessage = "No video identifier found for this move"
                self.isLoading = false
            }
            return
        }

        logger.info("🔍 VIDEO_LOADING_DEBUG: Photos identifier: \(photosIdentifier)")
        logger.info("🔍 VIDEO_LOADING_DEBUG: Identifier length: \(photosIdentifier.count) characters")
        logger.info("🔍 VIDEO_LOADING_DEBUG: Identifier format check: \(photosIdentifier.hasPrefix(" ") ? "Has spaces" : "Valid format")")

        // Check if asset exists
        logger.info("🔍 ASSET_EXISTS_CHECK: Checking if asset exists in Photos library")
        let assetExists = PhotosAssetLoader.assetExists(with: photosIdentifier)
        logger.info("🔍 ASSET_EXISTS_RESULT: Asset exists = \(assetExists)")

        guard assetExists else {
            logger.error("❌ VIDEO_LOADING_ERROR: Asset not found in Photos library")
            await MainActor.run {
                self.errorMessage = "Video not found in Photos library"
                self.isLoading = false
            }
            return
        }

        // Perform atomic loading to prevent UI flicker
        logger.info("⬇️ ASSET_FETCH_START: Starting asset fetch from Photos")
        do {
            let asset = await PhotosAssetLoader.fetchAsset(with: photosIdentifier)
            logger.info("⬇️ ASSET_FETCH_RESULT: Asset fetch completed, asset exists: \(asset != nil)")

            guard let asset = asset else {
                logger.error("❌ VIDEO_LOADING_ERROR: fetchAsset returned nil")
                await MainActor.run {
                    self.errorMessage = "Failed to load video from Photos"
                    self.isLoading = false
                }
                return
            }

            logger.info("🔍 ASSET_PROPERTIES_START: Validating asset properties")

            // Validate asset properties
            let duration = try await asset.load(.duration)
            let isPlayable = try await asset.load(.isPlayable)

            logger.info("🔍 ASSET_PROPERTIES_RESULT: Duration = \(CMTimeGetSeconds(duration))s, Playable = \(isPlayable)")

            guard isPlayable else {
                logger.error("❌ VIDEO_LOADING_ERROR: Asset is not playable")
                await MainActor.run {
                    self.errorMessage = "Video is not playable"
                    self.isLoading = false
                }
                return
            }

            logger.info("✅ VIDEO_LOADING_SUCCESS: Asset validated - duration: \(CMTimeGetSeconds(duration))s")

            // Create and configure the SharedVideoPlayer
            logger.info("🔄 PLAYER_CREATION_START: Creating SharedVideoPlayer")
            logger.info("🔄 ROTATION_DEBUG: Move.rotationQuarterTurns = \(move.rotationQuarterTurns)")

            let sharedPlayer = SharedVideoPlayer(mode: .preview)
            logger.info("🔄 PLAYER_CREATION_SUCCESS: SharedVideoPlayer created")

            logger.info("⬇️ PLAYER_LOADING_START: Loading video into SharedVideoPlayer")
            await sharedPlayer.loadVideo(asset)
            logger.info("⬇️ PLAYER_LOADING_SUCCESS: Video loaded into SharedVideoPlayer")

            // Apply trim boundaries if specified
            await applyTrimBoundaries(to: sharedPlayer)

            // Atomic state update
            await MainActor.run {
                logger.info("🎯 STATE_UPDATE: Updating UI state with loaded video")
                self.videoAsset = asset
                self.player = sharedPlayer
                self.isLoading = false
                logger.info("✅ VIDEO_LOADING_COMPLETE: MoveDetailView video loading successful!")
            }

        } catch {
            logger.error("❌ VIDEO_LOADING_ERROR: Exception during loading - \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load video: \(error.localizedDescription)"
                self.isLoading = false
            }
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

    // MARK: - Trim Boundary Enforcement
    /// Apply trim boundaries to video playback if specified
    /// - Parameter player: The SharedVideoPlayer to configure
    private func applyTrimBoundaries(to player: SharedVideoPlayer) async {
        let trimStartTime = move.trimStartTime
        let trimEndTime = move.trimEndTime

        // Check if move has trim bounds
        guard trimEndTime > trimStartTime else {
            logger.info("ℹ️ No trim bounds specified - playing full video")
            return
        }

        logger.info("✂️ Applying trim boundaries: \(trimStartTime)s - \(trimEndTime)s")

        // Apply trim boundaries to AVPlayer
        await MainActor.run {
            guard let playerRef = player.avPlayer else {
                logger.warning("⚠️ AVPlayer not available for trim boundary application")
                return
            }

            // Set forward playback end time on player item (iOS 18+ compatibility)
            let endTimeCM = CMTime(seconds: trimEndTime, preferredTimescale: 600)
            playerRef.currentItem?.forwardPlaybackEndTime = endTimeCM
            logger.info("✅ Set forwardPlaybackEndTime to \(trimEndTime)s")

            // Add boundary time observer to enforce trim limits
            addBoundaryTimeObserver(to: playerRef, endTime: trimEndTime)

            // Seek to trim start position
            let startTimeCM = CMTime(seconds: trimStartTime, preferredTimescale: 600)
            playerRef.seek(to: startTimeCM) { completed in
                if completed {
                    self.logger.info("✅ Successfully seeked to trim start position: \(trimStartTime)s")
                } else {
                    self.logger.warning("⚠️ Failed to seek to trim start position: \(trimStartTime)s")
                }
            }
        }
    }

    /// Add boundary time observer to enforce trim limits
    /// - Parameters:
    ///   - player: The AVPlayer to observe
    ///   - endTime: The trim end time to enforce
    private func addBoundaryTimeObserver(to player: AVPlayer, endTime: Double) {
        let endTimeCM = CMTime(seconds: endTime, preferredTimescale: 600)

        // Add boundary time observer with proper NSValue wrapping
        player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: endTimeCM)],
            queue: .main
        ) {
            self.logger.info("🎯 Trim end boundary reached")

            // Pause playback at trim end
            if player.timeControlStatus == .playing {
                player.pause()
                self.logger.info("⏸️ Paused playback at trim end boundary")

                // Seek back to trim start position after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let startTimeCM = CMTime(seconds: self.move.trimStartTime, preferredTimescale: 600)
                    player.seek(to: startTimeCM) { completed in
                        if completed {
                            self.logger.info("🔄 Seeked back to trim start after boundary enforcement")
                        }
                    }
                }
            }
        }

        logger.info("📡 Added boundary time observer for trim end time: \(endTime)s")

        // Store observer for cleanup (you might want to track this in a property)
        // For now, we'll rely on the player's internal cleanup
    }

    // MARK: - Player Cleanup
    /// Proper cleanup of SharedVideoPlayer resources
    private func cleanupPlayer() {
        logger.info("🎬 MOVE_DETAIL_VIEW: 🧹 Cleaning up player resources")

        // Cleanup the SharedVideoPlayer
        player?.cleanup()

        // Clear local reference
        Task { @MainActor in
            self.player = nil
        }

        logger.info("🎬 MOVE_DETAIL_VIEW: ✅ Cleanup completed")
    }

    // MARK: - Enhanced Video Instance Logging
    /// Enhanced logging for specific video instance details
    private func logSpecificVideoInstanceDetails() {
        logger.info("🎬 VIDEO_INSTANCE_ANALYSIS: Starting detailed video instance analysis for move: \(move.name ?? "Untitled Move")")

        // Log move-specific details
        logger.info("🎬 VIDEO_INSTANCE: Move name: \(move.name ?? "Untitled Move")")
        logger.info("🎬 VIDEO_INSTANCE: Move ID: \(move.objectID)")
        logger.info("🎬 VIDEO_INSTANCE: Learning state: \(move.learningState ?? "UNKNOWN")")
        logger.info("🎬 VIDEO_INSTANCE: Creation date: \(move.createdAt ?? Date())")

        // Log video-specific details
        if let photosIdentifier = move.photosIdentifier {
            logger.info("🎬 VIDEO_INSTANCE: Photos identifier: \(photosIdentifier)")
        } else {
            logger.warning("🎬 VIDEO_INSTANCE: No photos identifier found")
        }

        // Log trim details
        logger.info("🎬 VIDEO_INSTANCE: Trim range: \(move.trimStartTime)s - \(move.trimEndTime)s")
        logger.info("🎬 VIDEO_INSTANCE: Trim duration: \(move.trimEndTime - move.trimStartTime)s")

        // Log rotation details
        logger.info("🎬 VIDEO_INSTANCE: Rotation quarter turns: \(move.rotationQuarterTurns)")
        let rotationDegrees = Int(move.rotationQuarterTurns) * 90
        logger.info("🎬 VIDEO_INSTANCE: Rotation degrees: \(rotationDegrees)°")

        // Core Data entity details
        logger.info("🎬 VIDEO_INSTANCE: Core Data entity: \(move.entity.name ?? "Unknown")")
        logger.info("🎬 VIDEO_INSTANCE: Object URI: \(move.objectID.uriRepresentation().absoluteString)")

        // Create a unique instance identifier for tracking
        let instanceID = UUID().uuidString.prefix(8)
        logger.info("🎬 VIDEO_INSTANCE: Instance tracking ID: \(instanceID)")
        logger.info("🎬 VIDEO_INSTANCE_ANALYSIS: Complete - This specific instance can now be tracked through logs")
    }
}

// MARK: - Test Data Creation
private func createMockMoveWithVideo(in context: NSManagedObjectContext) -> Move {
    let mockMove = Move(context: context)
    mockMove.name = "Windmill"
    mockMove.learningState = "LEARNING"
    mockMove.createdAt = Date()
    mockMove.photosIdentifier = "sample-identifier"
    mockMove.trimStartTime = 0.0
    mockMove.trimEndTime = 5.0
    return mockMove
}

private func createMockMoveNoVideo(in context: NSManagedObjectContext) -> Move {
    let mockMove = Move(context: context)
    mockMove.name = "Top Rock"
    mockMove.learningState = "MASTERY"
    mockMove.createdAt = Date()
    // No photos identifier to test unavailable state
    return mockMove
}

// MARK: - Preview
#Preview("Move Detail - With Video") {
    let context = PersistenceController.shared.container.viewContext
    let mockMove = createMockMoveWithVideo(in: context)

    NavigationView {
        MoveDetailView(move: mockMove)
    }
    .environment(\.managedObjectContext, context)
}

#Preview("Move Detail - No Video") {
    let context = PersistenceController.shared.container.viewContext
    let mockMove = createMockMoveNoVideo(in: context)

    NavigationView {
        MoveDetailView(move: mockMove)
    }
    .environment(\.managedObjectContext, context)
}