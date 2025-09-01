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

struct CustomVideoPlayerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let move: Move?
    let url: URL?
    let photosIdentifier: String?
    let onRelinkRequested: (() -> Void)?

    enum PlayerState {
        case loading
        case playing(player: AVPlayer)
        case error(message: String)
    }

    @State private var playerState: PlayerState = .loading
    @State private var isMuted = false
    @State private var isPlaying = true
    @State private var showFullscreen = false

    init(move: Move?, url: URL? = nil, onRelinkRequested: (() -> Void)? = nil) {
        self.move = move
        self.url = url
        self.photosIdentifier = nil
        self.onRelinkRequested = onRelinkRequested
    }

    // New initializer for URL-only usage (like in AddMoveView)
    init(url: URL, onRelinkRequested: (() -> Void)? = nil) {
        self.move = nil
        self.url = url
        self.photosIdentifier = nil
        self.onRelinkRequested = onRelinkRequested
    }

    // New initializer for Photos-based video playback
    init(move: Move? = nil, photosIdentifier: String? = nil, onRelinkRequested: (() -> Void)? = nil) {
        self.move = move
        self.url = nil
        self.photosIdentifier = photosIdentifier
        self.onRelinkRequested = onRelinkRequested
    }

    init(_ player: AVPlayer) {
        self.move = nil
        self.url = nil
        self.photosIdentifier = nil
        self.onRelinkRequested = nil
        // Set the player state directly since we already have the player
        self._playerState = State(initialValue: .playing(player: player))
    }

    private var shouldSetupPlayer: Bool {
        // Only setup player if we don't already have one (i.e., if move, url, or photosIdentifier is provided)
        return move != nil || url != nil || photosIdentifier != nil
    }

    private var shouldShowRelink: Bool {
        // Show relink if we have a move object but the video is missing
        guard let move = move, onRelinkRequested != nil else { return false }

        // Check if move has Photos identifier (BreakDex system)
        if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
            // For Photos-based moves, we can't synchronously check existence
            // The setupPlayer method will handle this asynchronously
            return true // Show relink button, setupPlayer will verify existence
        }

        // Legacy file-based system
        if let videoURL = getVideoURL(for: move) {
            return !FileManager.default.fileExists(atPath: videoURL.path)
        }

        return true // If we can't get the URL, the video is effectively missing
    }

    var body: some View {
        ZStack {
            switch playerState {
            case .loading:
                ProgressView("Loading video...")
            case .playing(let player):
                ZStack {
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

                    // Tap-to-play/pause overlay (covers entire video area)
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isPlaying.toggle()
                        }

                    // Control overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            // Play/pause indicator in center when paused
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

                    // Top controls
                    VStack {
                        HStack {
                            Spacer()
                            // Fullscreen button
                            Button(action: { showFullscreen = true }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 8)

                            // Mute button
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
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(message)
                        .font(.headline)
                    // Conditional relink: only show if we have a move with a reference but missing file
                    if shouldShowRelink {
                        Button("Relink Video", action: { onRelinkRequested?() })
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            if shouldSetupPlayer {
                await setupPlayer()
            }
        }
    }

    private func setupPlayer() async {
        if let photosIdentifier = photosIdentifier {
            // Photos-based playback
            await setupPlayerFromPhotos(identifier: photosIdentifier)
        } else if let url = url {
            if FileManager.default.fileExists(atPath: url.path) {
                playerState = .playing(player: AVPlayer(url: url))
            } else {
                playerState = .error(message: "Video file not found.")
            }
        } else if let move = move {
            // Check if move has Photos identifier (BreakDex system)
            if let photosIdentifier = move.photosIdentifier, !photosIdentifier.isEmpty {
                await setupPlayerFromPhotos(identifier: photosIdentifier, trimStartTime: move.trimStartTime, trimEndTime: move.trimEndTime)
            } else if let videoURL = getVideoURL(for: move) {
                // Legacy file-based system
                playerState = .playing(player: AVPlayer(url: videoURL))
            } else {
                // No video available - trigger relink if we have a callback
                if onRelinkRequested != nil {
                    playerState = .error(message: "Video not found. Please relink this move.")
                } else {
                    playerState = .error(message: "Could not find video for this move.")
                }
            }
        } else {
            playerState = .error(message: "No video provided.")
        }
    }

    private func setupPlayerFromPhotos(identifier: String, trimStartTime: Double = 0.0, trimEndTime: Double = 0.0) async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

        guard let asset = fetchResult.firstObject else {
            // Video not found in Photos - trigger relink if available
            if onRelinkRequested != nil {
                playerState = .error(message: "Video not found in Photos. Please relink this move.")
            } else {
                playerState = .error(message: "Could not find video in Photos.")
            }
            return
        }

        // Request AVAsset from Photos
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        do {
            let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                    if let error = info?[PHImageErrorKey] {
                        // Handle Photos framework error dictionary properly
                        var errorMessage = "Failed to load video from Photos"
                        var nsError: NSError

                        if let photosError = error as? NSError {
                            // Handle if it's actually an NSError
                            nsError = photosError
                            errorMessage = "Error loading AVAsset: \(photosError.localizedDescription)"
                        } else if let errorDict = error as? [String: Any],
                                  let errorCode = errorDict["PHImageErrorKey"] as? Int {
                            // Handle specific Photos error codes
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
                        continuation.resume(throwing: nsError)
                    } else if let avAsset = avAsset {
                        continuation.resume(returning: avAsset)
                    } else {
                        print("Unknown error: AVAsset is nil and no error provided.") // Log if both are nil
                        continuation.resume(throwing: NSError(domain: "CustomVideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load video from Photos."]))
                    }
                }
            }

            // Create player item and apply trim ranges if specified
            let playerItem = AVPlayerItem(asset: avAsset)

            // Apply trim ranges using forwardPlaybackEndTime
            if trimEndTime > trimStartTime {
                // Set the end time for trimming
                playerItem.forwardPlaybackEndTime = CMTime(seconds: trimEndTime, preferredTimescale: 600)

                // Seek to start time when playback begins
                if trimStartTime > 0 {
                    try? await MainActor.run {
                        let player = AVPlayer(playerItem: playerItem)
                        player.seek(to: CMTime(seconds: trimStartTime, preferredTimescale: 600))
                        playerState = .playing(player: player)
                    }
                    return
                }
            }

            playerState = .playing(player: AVPlayer(playerItem: playerItem))
        } catch {
            let errorMessage: String
            if let addMoveError = error as? AddMoveError {
                errorMessage = addMoveError.localizedDescription
            } else if let nsError = error as? NSError {
                errorMessage = "Failed to load video: \(nsError.localizedDescription)"
            } else {
                errorMessage = "Failed to load video from Photos: \(error.localizedDescription)"
            }
            playerState = .error(message: errorMessage)
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

// MARK: - Relink support
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
                // Start accessing security-scoped resource if needed
                let needsAccess = url.startAccessingSecurityScopedResource()
                defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
                DispatchQueue.main.async { self.parent.onPick(url) }
            }

            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
        }
    }
    // MARK: - Legacy file persistence removed in BreakDex
    // Video trimming now stores only metadata (start/end times) in Core Data
    // No file operations needed - videos remain in Photos BreakDex album
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

// MARK: - Fullscreen Video Player
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

            // Tap-to-play/pause overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isPlaying.toggle()
                }

            // Controls overlay
            VStack {
                HStack {
                    // Close button
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()

                    // Mute button
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

                // Center play/pause indicator
                if !isPlaying {
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
        // Simple preview without Core Data for now
        CustomVideoPlayerView(move: nil, photosIdentifier: nil)
            .frame(height: 300)
            .padding()
    }
}