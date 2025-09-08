//
//  CustomVideoPlayerView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/26/25.
//

import SwiftUI
import AVKit
import CoreData
import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import AVFoundation

// MARK: - CGAffineTransform Validation Extension
extension CGAffineTransform {
    func isValid() -> Bool {
        // Check that all components are finite (not NaN or infinite)
        return a.isFinite && b.isFinite && c.isFinite && d.isFinite && tx.isFinite && ty.isFinite
    }

    var debugDescription: String {
        return String(format: "[%.3f, %.3f, %.3f, %.3f, %.3f, %.3f]", a, b, c, d, tx, ty)
    }
}

struct CustomVideoPlayerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let move: Move?
    let url: URL?
    let photosIdentifier: String?
    let asset: AVAsset?
    let rotationQuarterTurns: Int
    let onRelinkRequested: (() -> Void)?
    
    enum PlayerState {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }
    
    @State private var playerState: PlayerState = .loading
    @State private var isMuted = false
    @State private var isPlaying = false
    @State private var showFullscreen = false
    @State private var showLoadingIndicator = false
    @State private var loadingTimer: Timer?
    
    init(move: Move?, url: URL? = nil, onRelinkRequested: (() -> Void)? = nil) {
        self.move = move
        self.url = url
        self.photosIdentifier = nil
        self.asset = nil
        self.rotationQuarterTurns = Int(move?.rotationQuarterTurns ?? 0)
        self.onRelinkRequested = onRelinkRequested
    }

    init(url: URL, onRelinkRequested: (() -> Void)? = nil) { // new initializer for URL-only usage (like in AddMoveView)
        self.move = nil
        self.url = url
        self.photosIdentifier = nil
        self.asset = nil
        self.rotationQuarterTurns = 0
        self.onRelinkRequested = onRelinkRequested
    }

    init(move: Move? = nil, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0, onRelinkRequested: (() -> Void)? = nil) { // new initializer for Photos-based video playback
        self.move = move
        self.url = nil
        self.photosIdentifier = photosIdentifier
        self.asset = nil
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onRelinkRequested = onRelinkRequested
    }

    init(asset: AVAsset, rotationQuarterTurns: Int = 0, onRelinkRequested: (() -> Void)? = nil) { // new initializer for AVAsset usage
        self.move = nil
        self.url = nil
        self.photosIdentifier = nil
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onRelinkRequested = onRelinkRequested
    }

    init(_ player: AVPlayer) {
        self.move = nil
        self.url = nil
        self.photosIdentifier = nil
        self.asset = nil
        self.rotationQuarterTurns = 0
        self.onRelinkRequested = nil
        self._playerState = State(initialValue: .playing(player: player))
    }
    
    private var shouldSetupPlayer: Bool {
        return move != nil || url != nil || photosIdentifier != nil || asset != nil
    }
    
    private func startLoadingTimer() {
        // Cancel any existing timer
        loadingTimer?.invalidate()

        // Start new timer - show loading after 300ms
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [self] _ in
            Task { @MainActor in
                self.showLoadingIndicator = true
            }
        }
    }

    private func cancelLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        showLoadingIndicator = false
    }

    private var shouldShowRelink: Bool {
        guard let move = move, onRelinkRequested != nil else { return false }

        if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
            return true
        }

        if let videoURL = getVideoURL(for: move) {
            return !FileManager.default.fileExists(atPath: videoURL.path)
        }

        return true
    }
    
    var body: some View {
        ZStack {
            switch playerState {
            case .loading:
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing loading state")
                ZStack {
                    Color.backgroundPrimary
                        .edgesIgnoringSafeArea(.all)

                    if showLoadingIndicator {
                        Text("Loading video...")
                            .font(.ibmPlexMono(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            case .playing(let player):
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing playing state")
                ZStack {
                    VideoPlayer(player: player)
                        .assertNoTransforms() // Runtime assertion: video surface must not have transforms
                        .onAppear {
                            player.play()
                            isPlaying = true
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                        }
                        .onChange(of: isMuted) { _, newValue in
                            player.isMuted = newValue
                        }
                        .onChange(of: isPlaying) { _, newValue in
                            if newValue {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isPlaying.toggle()
                        }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if !isPlaying {
                                Image(systemName: "play.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { showFullscreen = true }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 8)

                            Button(action: { isMuted.toggle() }) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding()
                        Spacer()
                    }
                }
                .fullScreenCover(isPresented: $showFullscreen) {
                    if case .playing(let player) = playerState {
                        FullscreenVideoPlayer(player: player, isPresented: $showFullscreen)
                    }
                }
                
            case .error(let message):
                let _ = print("🎬 CUSTOM VIDEO PLAYER: showing error state: \(message)")
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(message)
                        .font(.headline)
                    if shouldShowRelink {
                        Button("Relink Video", action: { onRelinkRequested?() })
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            print("🎬 CustomVideoPlayerView task triggered")
            print("   📊 shouldSetupPlayer: \(shouldSetupPlayer)")
            print("   📹 move: \(move?.name ?? "nil")")
            print("   🆔 photosIdentifier: \(photosIdentifier ?? "nil")")
            print("   📹 asset: \(asset != nil ? "provided" : "nil")")
            print("   🔗 url: \(url?.absoluteString ?? "nil")")
            print("   🔄 rotationQuarterTurns: \(rotationQuarterTurns)")
            print("   📊 current playerState: \(String(describing: playerState))")

            if shouldSetupPlayer {
                print("🎬 Starting player setup...")
                startLoadingTimer()
                await setupPlayer()
                print("🎬 Player setup completed")
            } else {
                print("⚠️ shouldSetupPlayer is false, skipping setup")
            }
        }
        .onDisappear {
            cancelLoadingTimer()
        }
    }
    
    private func setupPlayer() async {
        print("🎬 CustomVideoPlayerView.setupPlayer() called with:")
        print("   asset: \(asset != nil)")
        print("   photosIdentifier: \(photosIdentifier ?? "nil")")
        print("   url: \(url?.absoluteString ?? "nil")")
        print("   move: \(move?.name ?? "nil")")

        if let asset = asset {
            print("🎬 Setting up player with AVAsset, rotationQuarterTurns: \(rotationQuarterTurns)")
            if rotationQuarterTurns != 0 {
                // Build video composition with rotation transforms
                Task {
                    do {
                        print("🎬 Building video composition for rotation: \(rotationQuarterTurns)")
                        let transformResult = try await VideoTransformBuilder.build(asset: asset, quarterTurns: rotationQuarterTurns)
                        let playerItem = AVPlayerItem(asset: transformResult.composition)
                        playerItem.videoComposition = transformResult.videoComposition
                        playerItem.seekingWaitsForVideoCompositionRendering = true

                        await MainActor.run {
                            // Check if we already have a playing player
                            if case .playing(let existingPlayer) = playerState {
                                print("🎬 Updating existing player with rotated item")
                                existingPlayer.replaceCurrentItem(with: playerItem)
                                existingPlayer.play()
                                cancelLoadingTimer()
                            } else {
                                print("🎬 Creating new player with rotated item")
                                let newPlayer = AVPlayer(playerItem: playerItem)
                                playerState = .playing(player: newPlayer)
                                cancelLoadingTimer()
                            }
                        }
                    } catch {
                        print("❌ Failed to build video composition: \(error)")
                        await MainActor.run {
                            playerState = .error(message: "Failed to process video: \(error.localizedDescription)")
                            cancelLoadingTimer()
                        }
                    }
                }
            } else {
                // No rotation needed, use asset directly
                print("🎬 Creating player item for asset: \(asset)")
                let playerItem = AVPlayerItem(asset: asset)

                // Check if we already have a playing player
                if case .playing(let existingPlayer) = playerState {
                    print("🎬 Updating existing player with new item")
                    // Replace current item instead of creating new player
                    existingPlayer.replaceCurrentItem(with: playerItem)
                    existingPlayer.play()
                    cancelLoadingTimer()
                } else {
                    print("🎬 Creating new player with item")
                    // Create new player if none exists
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    playerState = .playing(player: newPlayer)
                    cancelLoadingTimer()
                }
            }
        } else if let photosIdentifier = photosIdentifier {
            print("🎬 Setting up player with Photos identifier: \(photosIdentifier), rotationQuarterTurns: \(rotationQuarterTurns)")
            await setupPlayerFromPhotos(identifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
        } else if let url = url {
            if FileManager.default.fileExists(atPath: url.path) {
                print("🎬 Setting up player with URL: \(url), rotationQuarterTurns: \(rotationQuarterTurns)")
                if rotationQuarterTurns != 0 {
                    // Build video composition with rotation transforms for URL assets
                    Task {
                        do {
                            print("🎬 Building video composition for URL rotation: \(rotationQuarterTurns)")
                            let asset = AVURLAsset(url: url)
                            let transformResult = try await VideoTransformBuilder.build(asset: asset, quarterTurns: rotationQuarterTurns)
                            let playerItem = AVPlayerItem(asset: transformResult.composition)
                            playerItem.videoComposition = transformResult.videoComposition
                            playerItem.seekingWaitsForVideoCompositionRendering = true

                            await MainActor.run {
                                // Check if we already have a playing player
                                if case .playing(let existingPlayer) = playerState {
                                    print("🎬 Updating existing player with URL rotated item")
                                    existingPlayer.replaceCurrentItem(with: playerItem)
                                    existingPlayer.play()
                                    cancelLoadingTimer()
                                } else {
                                    print("🎬 Creating new player with URL rotated item")
                                    let newPlayer = AVPlayer(playerItem: playerItem)
                                    playerState = .playing(player: newPlayer)
                                    cancelLoadingTimer()
                                }
                            }
                        } catch {
                            print("❌ Failed to build video composition: \(error)")
                            await MainActor.run {
                                playerState = .error(message: "Failed to process video: \(error.localizedDescription)")
                                cancelLoadingTimer()
                            }
                        }
                    }
                } else {
                    // No rotation needed, use URL directly
                    print("🎬 Creating player for URL: \(url)")
                    let newPlayer = AVPlayer(url: url)

                    // Check if we already have a playing player
                    if case .playing(let existingPlayer) = playerState {
                        print("🎬 Updating existing player with URL")
                        // For URL changes, we need to create a new player item
                        let playerItem = AVPlayerItem(url: url)
                        existingPlayer.replaceCurrentItem(with: playerItem)
                        existingPlayer.play()
                        cancelLoadingTimer()
                    } else {
                        print("🎬 Creating new player for URL")
                        playerState = .playing(player: newPlayer)
                        cancelLoadingTimer()
                    }
                }
            } else {
                print("❌ Video file not found at URL: \(url)")
                playerState = .error(message: "Video file not found.")
                cancelLoadingTimer() // Error state
            }
        } else if let move = move {
            if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
                await setupPlayerFromPhotos(identifier: photosIdentifier, trimStartTime: move.trimStartTime, trimEndTime: move.trimEndTime, rotationQuarterTurns: rotationQuarterTurns)
            } else if let videoURL = getVideoURL(for: move) {
                if rotationQuarterTurns != 0 {
                    // Build video composition with rotation transforms for file URLs
                    Task {
                        do {
                            let asset = AVURLAsset(url: videoURL)
                            let transformResult = try await VideoTransformBuilder.build(asset: asset, quarterTurns: rotationQuarterTurns)
                            let playerItem = AVPlayerItem(asset: transformResult.composition)
                            playerItem.videoComposition = transformResult.videoComposition
                            playerItem.seekingWaitsForVideoCompositionRendering = true
                            await MainActor.run {
                                // Check if we already have a playing player
                                if case .playing(let existingPlayer) = playerState {
                                    print("🎬 Updating existing player with move rotated item")
                                    existingPlayer.replaceCurrentItem(with: playerItem)
                                    existingPlayer.play()
                                    cancelLoadingTimer()
                                } else {
                                    print("🎬 Creating new player with move rotated item")
                                    let newPlayer = AVPlayer(playerItem: playerItem)
                                    playerState = .playing(player: newPlayer)
                                    cancelLoadingTimer()
                                }
                            }
                        } catch {
                            print("❌ Failed to build video composition: \(error)")
                            await MainActor.run {
                                playerState = .error(message: "Failed to process video: \(error.localizedDescription)")
                                cancelLoadingTimer()
                            }
                        }
                    }
                } else {
                    // No rotation needed, use URL directly
                    print("🎬 Creating player for move URL: \(videoURL)")
                    let newPlayer = AVPlayer(url: videoURL)

                    // Check if we already have a playing player
                    if case .playing(let existingPlayer) = playerState {
                        print("🎬 Updating existing player with move URL")
                        let playerItem = AVPlayerItem(url: videoURL)
                        existingPlayer.replaceCurrentItem(with: playerItem)
                        existingPlayer.play()
                        cancelLoadingTimer()
                    } else {
                        print("🎬 Creating new player for move URL")
                        playerState = .playing(player: newPlayer)
                        cancelLoadingTimer()
                    }
                }
            } else {
                if onRelinkRequested != nil {
                    playerState = .error(message: "Video not found. Please relink this move.")
                } else {
                    playerState = .error(message: "Could not find video for this move.")
                }
                cancelLoadingTimer() // Error state
            }
        } else {
            print("❌ No video source provided to CustomVideoPlayerView")
            playerState = .error(message: "No video provided.")
            cancelLoadingTimer() // Error state
        }
    }

    /// Builds a video composition with rotation and trimming transforms


    private func setupPlayerFromPhotos(identifier: String, trimStartTime: Double = 0.0, trimEndTime: Double = 0.0, rotationQuarterTurns: Int = 0) async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        
        guard let asset = fetchResult.firstObject else {
            if onRelinkRequested != nil {
                playerState = .error(message: "Video not found in Photos. Please relink this move.")
            } else {
                playerState = .error(message: "Could not find video in Photos.")
            }
            cancelLoadingTimer() // Error state
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        
        do {
            let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                    if let error = info?[PHImageErrorKey] {
                        var errorMessage = "Failed to load video from Photos"
                        var nsError: NSError
                        
                        if let photosError = error as? NSError {
                            nsError = photosError
                            errorMessage = "Error loading AVAsset: \(photosError.localizedDescription)"
                        } else if let errorDict = error as? [String: Any],
                                  let errorCode = errorDict["PHImageErrorKey"] as? Int {
                            switch errorCode {
                            case 3202:
                                errorMessage = "Error loading AVAsset: iCloud photo not yet downloaded"
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            case 3201:
                                errorMessage = "Error loading AVAsset: Photo access denied"
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            default:
                                errorMessage = "Error loading AVAsset (error code: \(errorCode))"
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            }
                        } else {
                            // Fallback for unknown error format
                            nsError = NSError(domain: "CustomVideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos request failed."])
                        }

                        print(errorMessage) // Log the error
                        DispatchQueue.main.async {
                            self.playerState = .error(message: errorMessage)
                            self.cancelLoadingTimer() // Error state
                        }
                        continuation.resume(throwing: nsError)
                    } else if let avAsset = avAsset {
                        continuation.resume(returning: avAsset)
                    } else {
                        print("Unknown error: AVAsset is nil and no error provided.") // Log if both are nil
                        let error = NSError(domain: "CustomVideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video from Photos."])
                        DispatchQueue.main.async {
                            self.playerState = .error(message: "Could not load video from Photos.")
                            self.cancelLoadingTimer() // Error state
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            if rotationQuarterTurns != 0 || trimEndTime > trimStartTime {
                // Use VideoTransformBuilder for rotation and/or trimming
                do {
                    let trimRange: CMTimeRange?
                    if trimEndTime > trimStartTime {
                        trimRange = CMTimeRange(
                            start: CMTime(seconds: trimStartTime, preferredTimescale: 600),
                            duration: CMTime(seconds: trimEndTime - trimStartTime, preferredTimescale: 600)
                        )
                    } else {
                        trimRange = nil
                    }

                    let transformResult = try await VideoTransformBuilder.build(asset: avAsset, trimRange: trimRange, quarterTurns: rotationQuarterTurns)

                    let playerItem = AVPlayerItem(asset: transformResult.composition)
                    playerItem.videoComposition = transformResult.videoComposition
                    playerItem.seekingWaitsForVideoCompositionRendering = true

                    await MainActor.run {
                        // Check if we already have a playing player
                        if case .playing(let existingPlayer) = playerState {
                            print("🎬 Updating existing player with Photos item")
                            existingPlayer.replaceCurrentItem(with: playerItem)
                            existingPlayer.play()
                            cancelLoadingTimer()
                        } else {
                            print("🎬 Creating new player with Photos item")
                            let newPlayer = AVPlayer(playerItem: playerItem)
                            playerState = .playing(player: newPlayer)
                            cancelLoadingTimer()
                        }
                    }
                } catch {
                    print("❌ Failed to build video composition: \(error)")
                    await MainActor.run {
                        playerState = .error(message: "Failed to process video: \(error.localizedDescription)")
                        cancelLoadingTimer()
                    }
                }
            } else {
                // No rotation or trimming needed, use asset directly
                let playerItem = AVPlayerItem(asset: avAsset)
                await MainActor.run {
                    // Check if we already have a playing player
                    if case .playing(let existingPlayer) = playerState {
                        print("🎬 Updating existing player with Photos item (no rotation)")
                        existingPlayer.replaceCurrentItem(with: playerItem)
                        existingPlayer.play()
                        cancelLoadingTimer()
                    } else {
                        print("🎬 Creating new player with Photos item (no rotation)")
                        let newPlayer = AVPlayer(playerItem: playerItem)
                        playerState = .playing(player: newPlayer)
                        cancelLoadingTimer()
                    }
                }
            }
        } catch {
            let errorMessage: String
            if let addMoveError = error as? AddMoveError {
                errorMessage = addMoveError.localizedDescription
            } else {
                let nsError = error as NSError
                errorMessage = "Failed to load video: \(nsError.localizedDescription)"
            }
            playerState = .error(message: errorMessage)
            cancelLoadingTimer() // Error state
        }
    }
    
    private func getVideoURL(for move: Move) -> URL? {
        guard let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }
        
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }
}

private extension CustomVideoPlayerView {
    struct FileRelinkPicker: UIViewControllerRepresentable {
        let onPick: (URL) -> Void
        
        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
            picker.delegate = context.coordinator
            picker.allowsMultipleSelection = false
            return picker
        }
        
        func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator { Coordinator(self) }
        
        final class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: FileRelinkPicker
            init(_ parent: FileRelinkPicker) { self.parent = parent }
            
            func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                guard let url = urls.first else { return }
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
                DispatchQueue.main.async { self.parent.onPick(url) }
            }
            
            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
        }
    }
}

private struct RelinkPicker: UIViewControllerRepresentable {
    let onPick: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: RelinkPicker
        init(_ parent: RelinkPicker) { self.parent = parent }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else {
                return // User cancelled
            }
            getVideoURL(from: result)
        }
        
        private func getVideoURL(from result: PHPickerResult) {
            let provider = result.itemProvider
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                print("DEBUG: RelinkPicker is using loadFileRepresentation.")
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    if let error = error {
                        print("DEBUG: RelinkPicker loadFileRepresentation failed: \(error.localizedDescription)")
                        DispatchQueue.main.async { self?.parent.onPick(.failure(error)) }
                        return
                    }
                    guard let url = url else {
                        let err = NSError(domain: "RelinkPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get URL from file representation."])
                        DispatchQueue.main.async { self?.parent.onPick(.failure(err)) }
                        return
                    }
                    
                    guard let newURL = self?.copyToSandbox(url: url) else {
                        let err = NSError(domain: "RelinkPicker", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to copy video to sandbox."])
                        DispatchQueue.main.async { self?.parent.onPick(.failure(err)) }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        print("DEBUG: RelinkPicker successfully got URL via loadFileRepresentation: \(newURL.path)")
                        self?.parent.onPick(.success(newURL))
                    }
                }
            } else if let assetId = result.assetIdentifier {
                print("DEBUG: RelinkPicker is using assetIdentifier fallback.")
                reexportFromPhotos(assetIdentifier: assetId) { [weak self] result in
                    DispatchQueue.main.async { self?.parent.onPick(result) }
                }
            } else {
                let err = NSError(domain: "RelinkPicker", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not find a usable video representation."])
                DispatchQueue.main.async { self.parent.onPick(.failure(err)) }
            }
        }
        
        private func copyToSandbox(url: URL) -> URL? {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let destinationURL = documents.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            do {
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
                if FileManager.default.fileExists(atPath: destinationURL.path) { try FileManager.default.removeItem(at: destinationURL) }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                return destinationURL
            } catch {
                print("DEBUG: RelinkPicker failed to copy file to sandbox: \(error.localizedDescription)")
                return nil
            }
        }
        
        private func reexportFromPhotos(assetIdentifier: String, completion: @escaping (Result<URL, Error>) -> Void) {
            let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if currentStatus == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in self.reexportFromPhotos(assetIdentifier: assetIdentifier, completion: completion) }
                return
            }
            guard currentStatus == .authorized || currentStatus == .limited else {
                completion(.failure(NSError(domain: "Relink", code: -10, userInfo: [NSLocalizedDescriptionKey: "Photos access not granted"])));
                return
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = assets.firstObject else {
                completion(.failure(NSError(domain: "Relink", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])));
                return
            }
            let resources = PHAssetResource.assetResources(for: asset)
            guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video }) ?? resources.first else {
                completion(.failure(NSError(domain: "Relink", code: -2, userInfo: [NSLocalizedDescriptionKey: "No video resource"])));
                return
            }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ext = (videoResource.originalFilename as NSString).pathExtension
            let destinationURL = documents.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? ".mov" : "." + ext))
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: destinationURL, options: options) { error in
                if let error = error { completion(.failure(error)) } else { completion(.success(destinationURL)) }
            }
        }
    }
}

struct FullscreenVideoPlayer: View {
    let player: AVPlayer
    @Binding var isPresented: Bool
    
    @State private var isMuted = false
    @State private var isPlaying = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VideoPlayer(player: player)
                .onAppear {
                    player.play()
                    isPlaying = true
                }
                .onDisappear {
                    player.pause()
                    isPlaying = false
                }
                .onChange(of: isMuted) { _, newValue in
                    player.isMuted = newValue
                }
                .onChange(of: isPlaying) { _, newValue in
                    if newValue {
                        player.play()
                    } else {
                        player.pause()
                    }
                }
            
            Color.clear // tap-to-play/pause overlay
                .contentShape(Rectangle())
                .onTapGesture {
                    isPlaying.toggle()
                }
            
            VStack { // controls overlay
                HStack {
                    Button(action: { isPresented = false }) { // close button
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()
                    
                    Button(action: { isMuted.toggle() }) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                if !isPlaying { // center play/pause indicator
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                        Spacer()
                    }
                }
            }
        }
    }
}

struct CustomVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomVideoPlayerView(move: nil, photosIdentifier: nil, onRelinkRequested: nil)
            .frame(height: 300)
            .padding()
    }
}
