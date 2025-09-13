//
//  VideoPlayerViewModel.swift
//  BreakingFlashcards
//
//  Created by AI Assistant on 09/10/25.
//

import SwiftUI
import AVKit
import AVFoundation
import Photos
import CoreData

/// ViewModel that owns AVPlayer lifecycle and handles all video processing operations.
/// This provides single ownership of media resources and proper async task management.
@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Types
    enum State {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }

    // MARK: - Published State
    @Published private(set) var state: State = .loading

    // MARK: - Player Ownership
    private(set) var player = AVPlayer()

    // MARK: - Async Task Management
    private var buildTask: Task<Void, Never>?
    private var buildGen: Int = 0

    // MARK: - Current Source Tracking (for rotation changes)
    private var currentAsset: AVAsset?
    private var currentPhotosIdentifier: String?
    private var currentURL: URL?
    private var currentMove: Move?
    private var currentQuarterTurns: Int = 0

    // MARK: - Public API

    /// Set the video source and rotation
    /// - Parameters:
    ///   - asset: The AVAsset to play
    ///   - quarterTurns: Rotation in quarter turns (0, 1, 2, 3)
    func setSource(asset: AVAsset, quarterTurns: Int = 0) {
        print("🎬 VideoPlayerViewModel.setSource(asset: \(asset), quarterTurns: \(quarterTurns))")
        // Store current source for rotation changes
        currentAsset = asset
        currentQuarterTurns = quarterTurns
        rebuildPlayer(with: asset, quarterTurns: quarterTurns, hardReset: quarterTurns == 0)
    }

    /// Set video source from Photos identifier
    /// - Parameters:
    ///   - identifier: Photos library asset identifier
    ///   - quarterTurns: Rotation in quarter turns
    func setSource(photosIdentifier: String, quarterTurns: Int = 0) {
        print("🎬 VideoPlayerViewModel.setSource(photosIdentifier: \(photosIdentifier), quarterTurns: \(quarterTurns))")
        // Store current source for rotation changes
        currentPhotosIdentifier = photosIdentifier
        currentQuarterTurns = quarterTurns
        setupPlayerFromPhotos(identifier: photosIdentifier, quarterTurns: quarterTurns)
    }

    /// Set video source from URL
    /// - Parameters:
    ///   - url: File URL to video
    ///   - quarterTurns: Rotation in quarter turns
    func setSource(url: URL, quarterTurns: Int = 0) {
        print("🎬 VideoPlayerViewModel.setSource(url: \(url), quarterTurns: \(quarterTurns))")
        // Store current source for rotation changes
        currentURL = url
        currentQuarterTurns = quarterTurns
        setupPlayerFromURL(url: url, quarterTurns: quarterTurns)
    }

    /// Set video source from Move object
    /// - Parameters:
    ///   - move: CoreData Move object
    ///   - quarterTurns: Rotation in quarter turns
    func setSource(move: Move, quarterTurns: Int = 0) {
        print("🎬 VideoPlayerViewModel.setSource(move: \(move.name ?? "unnamed"), quarterTurns: \(quarterTurns))")
        // Store current source for rotation changes
        currentMove = move
        currentQuarterTurns = quarterTurns
        setupPlayerFromMove(move: move, quarterTurns: quarterTurns)
    }

    /// Update rotation for current source
    /// - Parameter quarterTurns: New rotation in quarter turns
    func setRotation(_ quarterTurns: Int) {
        print("🎬 VideoPlayerViewModel.setRotation(\(quarterTurns))")
        currentQuarterTurns = quarterTurns

        // Rebuild based on current source type
        if let asset = currentAsset {
            rebuildPlayer(with: asset, quarterTurns: quarterTurns, hardReset: false)
        } else if let photosId = currentPhotosIdentifier {
            setupPlayerFromPhotos(identifier: photosId, quarterTurns: quarterTurns)
        } else if let url = currentURL {
            setupPlayerFromURL(url: url, quarterTurns: quarterTurns)
        } else if let move = currentMove {
            setupPlayerFromMove(move: move, quarterTurns: quarterTurns)
        }
    }

    /// Set error state
    /// - Parameter message: Error message to display
    func setError(_ message: String) {
        state = .error(message: message)
    }

    /// Clean teardown for navigation - cancels all async work and clears player
    func teardown() {
        print("🎬 VideoPlayerViewModel.teardown()")

        // Cancel any in-flight build task
        buildTask?.cancel()
        buildTask = nil

        // Clean up player state
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.cancelPendingPrerolls()

        // Reset state
        state = .loading
    }

    // MARK: - Private Methods

    /// Rebuild the player with new asset and rotation
    /// - Parameters:
    ///   - asset: The video asset
    ///   - quarterTurns: Rotation in quarter turns
    ///   - hardReset: Whether to perform a hard reset (for composition → plain asset transitions)
    private func rebuildPlayer(with asset: AVAsset, quarterTurns: Int, hardReset: Bool) {
        print("🎬 VideoPlayerViewModel.rebuildPlayer(hardReset: \(hardReset))")

        // Cancel previous task
        buildTask?.cancel()

        // Increment generation for fencing
        buildGen &+= 1
        let currentGen = buildGen

        // Start new build task
        buildTask = Task {
            guard !Task.isCancelled else { return }

            do {
                let playerItem: AVPlayerItem

                if quarterTurns != 0 {
                    // Use VideoTransformBuilder for rotation
                    print("🎬 Building rotated player item with \(quarterTurns) quarter turns")
                    let transformResult = try await VideoTransformBuilder.build(asset: asset, quarterTurns: quarterTurns)
                    playerItem = AVPlayerItem(asset: transformResult.composition)
                    playerItem.videoComposition = transformResult.videoComposition
                    playerItem.seekingWaitsForVideoCompositionRendering = true
                } else {
                    // Plain asset, no rotation
                    print("🎬 Building plain player item (no rotation)")
                    playerItem = AVPlayerItem(asset: asset)
                }

                // Apply the item on main actor
                await applyItem(playerItem, hardReset: hardReset, gen: currentGen)

            } catch {
                print("❌ VideoPlayerViewModel build failed: \(error)")

                // Update state on main actor if generation still current
                await MainActor.run {
                    guard currentGen == self.buildGen else {
                        print("🎬 Build result ignored (stale generation)")
                        return
                    }
                    self.state = .error(message: "Failed to process video: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Setup player from Photos library identifier
    /// - Parameters:
    ///   - identifier: Photos asset identifier
    ///   - quarterTurns: Rotation in quarter turns
    private func setupPlayerFromPhotos(identifier: String, quarterTurns: Int) {
        print("🎬 VideoPlayerViewModel.setupPlayerFromPhotos(identifier: \(identifier), quarterTurns: \(quarterTurns))")

        // Cancel previous task
        buildTask?.cancel()

        // Increment generation for fencing
        buildGen &+= 1
        let currentGen = buildGen

        // Start new build task
        buildTask = Task {
            guard !Task.isCancelled else { return }

            do {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

                guard let asset = fetchResult.firstObject else {
                    await MainActor.run {
                        guard currentGen == self.buildGen else { return }
                        self.state = .error(message: "Video not found in Photos.")
                    }
                    return
                }

                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .automatic

                let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
                    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                        if let error = info?[PHImageErrorKey] {
                            var errorMessage = "Failed to load video from Photos"
                            if let photosError = error as? NSError {
                                switch photosError.code {
                                case 3202:
                                    errorMessage = "Video not yet downloaded from iCloud"
                                case 3201:
                                    errorMessage = "Photos access denied"
                                default:
                                    errorMessage = "Photos error: \(photosError.localizedDescription)"
                                }
                            }
                            continuation.resume(throwing: NSError(domain: "PhotosError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                        } else if let avAsset = avAsset {
                            continuation.resume(returning: avAsset)
                        } else {
                            continuation.resume(throwing: NSError(domain: "PhotosError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video from Photos"]))
                        }
                    }
                }

                // Build player item with rotation if needed
                let playerItem: AVPlayerItem
                if quarterTurns != 0 {
                    let transformResult = try await VideoTransformBuilder.build(asset: avAsset, quarterTurns: quarterTurns)
                    playerItem = AVPlayerItem(asset: transformResult.composition)
                    playerItem.videoComposition = transformResult.videoComposition
                    playerItem.seekingWaitsForVideoCompositionRendering = true
                } else {
                    playerItem = AVPlayerItem(asset: avAsset)
                }

                // Apply the item on main actor
                await applyItem(playerItem, hardReset: false, gen: currentGen)

            } catch {
                print("❌ setupPlayerFromPhotos failed: \(error)")
                await MainActor.run {
                    guard currentGen == self.buildGen else { return }
                    self.state = .error(message: "Failed to load video: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Setup player from URL
    /// - Parameters:
    ///   - url: File URL to video
    ///   - quarterTurns: Rotation in quarter turns
    private func setupPlayerFromURL(url: URL, quarterTurns: Int) {
        print("🎬 VideoPlayerViewModel.setupPlayerFromURL(url: \(url), quarterTurns: \(quarterTurns))")

        // Cancel previous task
        buildTask?.cancel()

        // Increment generation for fencing
        buildGen &+= 1
        let currentGen = buildGen

        // Start new build task
        buildTask = Task {
            guard !Task.isCancelled else { return }

            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    await MainActor.run {
                        guard currentGen == self.buildGen else { return }
                        self.state = .error(message: "Video file not found.")
                    }
                    return
                }

                let asset = AVURLAsset(url: url)

                // Build player item with rotation if needed
                let playerItem: AVPlayerItem
                if quarterTurns != 0 {
                    let transformResult = try await VideoTransformBuilder.build(asset: asset, quarterTurns: quarterTurns)
                    playerItem = AVPlayerItem(asset: transformResult.composition)
                    playerItem.videoComposition = transformResult.videoComposition
                    playerItem.seekingWaitsForVideoCompositionRendering = true
                } else {
                    playerItem = AVPlayerItem(asset: asset)
                }

                // Apply the item on main actor
                await applyItem(playerItem, hardReset: false, gen: currentGen)

            } catch {
                print("❌ setupPlayerFromURL failed: \(error)")
                await MainActor.run {
                    guard currentGen == self.buildGen else { return }
                    self.state = .error(message: "Failed to load video: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Setup player from Move object
    /// - Parameters:
    ///   - move: CoreData Move object
    ///   - quarterTurns: Rotation in quarter turns
    private func setupPlayerFromMove(move: Move, quarterTurns: Int) {
        print("🎬 VideoPlayerViewModel.setupPlayerFromMove(move: \(move.name ?? "unnamed"), quarterTurns: \(quarterTurns))")

        // Check if move has Photos identifier first
        if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
            print("🎬 Move has Photos identifier, using Photos setup")
            setupPlayerFromPhotos(identifier: photosIdentifier, quarterTurns: quarterTurns)
            return
        }

        // Otherwise try to get URL from video reference
        if let videoURL = getVideoURL(for: move) {
            print("🎬 Move has video URL, using URL setup")
            setupPlayerFromURL(url: videoURL, quarterTurns: quarterTurns)
            return
        }

        // No valid video source found
        print("❌ Move has no valid video source")
        Task { @MainActor in
            self.state = .error(message: "Video not found.")
        }
    }

    /// Get video URL from Move object
    /// - Parameter move: CoreData Move object
    /// - Returns: URL if found, nil otherwise
    private func getVideoURL(for move: Move) -> URL? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }

    /// Apply a player item with proper generation fencing and optional hard reset
    /// - Parameters:
    ///   - item: The player item to apply
    ///   - hardReset: Whether to perform hard reset (pause, clear, create new player)
    ///   - gen: Generation number for fencing
    @MainActor
    private func applyItem(_ item: AVPlayerItem, hardReset: Bool, gen: Int) {
        // Generation fencing - ignore if generation has changed
        guard gen == buildGen else {
            print("🎬 Player item application ignored (stale generation)")
            return
        }

        print("🎬 Applying player item (hardReset: \(hardReset))")

        switch state {
        case .playing(let existingPlayer):
            if hardReset {
                print("🎬 Performing hard reset")
                // Hard reset: pause, clear current item, cancel prerolls, create fresh player
                existingPlayer.pause()
                existingPlayer.replaceCurrentItem(with: nil)
                existingPlayer.cancelPendingPrerolls()

                let freshPlayer = AVPlayer(playerItem: item)
                player = freshPlayer
                state = .playing(player: freshPlayer)
            } else {
                print("🎬 Updating existing player")
                // Soft update: just replace the item
                existingPlayer.replaceCurrentItem(with: item)
            }

        default:
            print("🎬 Creating new player")
            // Create new player for loading/error states
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            state = .playing(player: newPlayer)
        }

        // Start playback and seek to beginning
        if case .playing(let currentPlayer) = state {
            currentPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            currentPlayer.play()
        }
    }
}
