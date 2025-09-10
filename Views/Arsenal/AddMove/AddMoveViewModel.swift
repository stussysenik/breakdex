import SwiftUI
import PhotosUI
import AVKit
import CoreData
import Combine
import OSLog
import Foundation
import AVFoundation
import Photos

// state machine for the add move view - all the logic + states
public enum AddMoveState: Equatable, Hashable {
    case ready
    case loading(progress: Double, status: String)
    case previewing(asset: AVAsset, photosIdentifier: String?)
    case selectingVideo(currentAsset: AVAsset?) // NEW: For video selection mode
    case trimming(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    case naming(photosIdentifier: String, originalAsset: AVAsset?, trimmedAsset: AVAsset?, trimStartTime: Double?, trimEndTime: Double?, rotationQuarterTurns: Int)
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)

    public static func == (lhs: AddMoveState, rhs: AddMoveState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.saving, .saving):
            return true
        case (.success(let m1), .success(let m2)):
            return m1 == m2
        case (.error(let m1, let e1), .error(let m2, let e2)):
            return m1 == m2 && e1 == e2
        case (let .loading(p1, s1), let .loading(p2, s2)):
            return p1 == p2 && s1 == s2
        case (let .previewing(a1, id1), let .previewing(a2, id2)):
            return a1 == a2 && id1 == id2
        case (let .selectingVideo(asset1), let .selectingVideo(asset2)):
            return asset1 == asset2
        case (let .trimming(a1, id1, rot1), let .trimming(a2, id2, rot2)):
            return a1 == a2 && id1 == id2 && rot1 == rot2
        case (let .naming(id1, _, _, start1, end1, rot1), let .naming(id2, _, _, start2, end2, rot2)):
            return id1 == id2 && start1 == start2 && end1 == end2 && rot1 == rot2
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .ready:
            hasher.combine(0)
        case .loading(let progress, let status):
            hasher.combine(1)
            hasher.combine(progress)
            hasher.combine(status)
        case .previewing(let asset, let photosIdentifier):
            hasher.combine(2)
            hasher.combine(ObjectIdentifier(asset))
            hasher.combine(photosIdentifier)
        case .selectingVideo(let asset):
            hasher.combine(3) // Using 3 since trimming uses 4
            if let asset = asset {
                hasher.combine(ObjectIdentifier(asset))
            }
        case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns):
            hasher.combine(4)
            hasher.combine(ObjectIdentifier(asset))
            hasher.combine(photosIdentifier)
            hasher.combine(rotationQuarterTurns)
        case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns):
            hasher.combine(5)
            hasher.combine(photosIdentifier)
            if let originalAsset = originalAsset {
                hasher.combine(ObjectIdentifier(originalAsset))
            }
            if let trimmedAsset = trimmedAsset {
                hasher.combine(ObjectIdentifier(trimmedAsset))
            }
            hasher.combine(trimStartTime)
            hasher.combine(trimEndTime)
            hasher.combine(rotationQuarterTurns)
        case .saving:
            hasher.combine(5)
        case .success(let message):
            hasher.combine(6)
            hasher.combine(message)
        case .error(let message, let underlyingError):
            hasher.combine(7)
            hasher.combine(message)
            hasher.combine(underlyingError)
        }
    }
}

public enum AddMoveError: LocalizedError {
    case photosPermissionDenied
    case iCloudUnavailable
    case videoLoadFailed(underlyingError: Error?)
    case videoFormatUnsupported
    case videoCopyFailed(underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error?)
    case unknown(underlyingError: Error?)
    
    public var errorDescription: String? {
        switch self {
        case .photosPermissionDenied:
            return "Photos access denied. Please enable Photos access in Settings."
        case .iCloudUnavailable:
            return "iCloud is unavailable. Please check your iCloud settings."
        case .videoLoadFailed(let error):
            return "Failed to load video. " + (error?.localizedDescription ?? "")
        case .videoFormatUnsupported:
            return "Unsupported video format. Please choose an MP4 or MOV file."
        case .videoCopyFailed(let error):
            return "Failed to copy video to BreakDex. " + (error?.localizedDescription ?? "")
        case .coreDataSaveFailed(let error):
            return "Failed to save your move. " + (error?.localizedDescription ?? "")
        case .unknown(let error):
            return "An unexpected error occurred. " + (error?.localizedDescription ?? "")
        }
    }
}

// MARK: - Video Loading Errors
public enum VideoLoaderError: Error, LocalizedError {
    case itemIdentifierMissing
    case assetNotFound
    case avAssetCreationFailed
    case unsupportedFileType
    case dataUnavailable
    case temporaryFileError(Error)

    public var errorDescription: String? {
        switch self {
        case .itemIdentifierMissing:
            return "The selected item does not have a valid identifier."
        case .assetNotFound:
            return "Could not find the video in the Photos library."
        case .avAssetCreationFailed:
            return "Failed to create a playable video asset."
        case .unsupportedFileType:
            return "The selected file type is not a supported video format."
        case .dataUnavailable:
            return "Could not retrieve video data for the selected item."
        case .temporaryFileError(let underlyingError):
            return "Failed to save video data to a temporary file: \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - Video Loader Result
public struct VideoLoaderResult {
    let asset: AVAsset
    let photosIdentifier: String
    let filename: String
}

// MARK: - VideoLoader Actor
public actor VideoLoader {
    private let imageManager = PHImageManager.default()

    public func loadVideo(from item: PhotosPickerItem) async throws -> VideoLoaderResult {
        if let identifier = item.itemIdentifier {
            // Load from Photos library using the identifier
            return try await loadFromPhotos(identifier: identifier)
        } else {
            // Load directly from the item's data
            return try await loadDirectly(from: item)
        }
    }

    // MARK: - Private Loading Methods

    private func loadFromPhotos(identifier: String) async throws -> VideoLoaderResult {
        // 1. Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            throw VideoLoaderError.assetNotFound
        }

        // 2. Request the AVAsset
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let avAsset = try await requestAVAsset(for: phAsset, options: options)

        // 3. Get the original filename
        let filename = await fetchFilename(for: phAsset)

        return VideoLoaderResult(asset: avAsset, photosIdentifier: identifier, filename: filename)
    }

    private func loadDirectly(from item: PhotosPickerItem) async throws -> VideoLoaderResult {
        // 1. Ensure it's a movie type
        guard item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) else {
            throw VideoLoaderError.unsupportedFileType
        }

        // 2. Load transferable data
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw VideoLoaderError.dataUnavailable
        }

        // 3. Create a temporary file to host the data
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        do {
            try data.write(to: tempURL)
        } catch {
            throw VideoLoaderError.temporaryFileError(error)
        }

        // 4. Create an AVURLAsset from the temporary file
        let avAsset = AVURLAsset(url: tempURL)
        
        // Since we don't have a filename, we'll generate one.
        let filename = "video-\(Date().timeIntervalSince1970).mov"
        
        // Create a temporary identifier for tracking
        let tempIdentifier = "temp-\(UUID().uuidString)"

        return VideoLoaderResult(asset: avAsset, photosIdentifier: tempIdentifier, filename: filename)
    }

    // MARK: - Helper Methods

    private func requestAVAsset(for phAsset: PHAsset, options: PHVideoRequestOptions) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let asset = avAsset {
                    continuation.resume(returning: asset)
                } else {
                    continuation.resume(throwing: VideoLoaderError.avAssetCreationFailed)
                }
            }
        }
    }

    private func fetchFilename(for phAsset: PHAsset) async -> String {
        let resources = PHAssetResource.assetResources(for: phAsset)
        if let resource = resources.first(where: { $0.type == .video }) {
            return resource.originalFilename
        }
        return "Video" // Fallback filename
    }
}

@MainActor
class AddMoveViewModel: ObservableObject {
    // MARK: - State Management
    @Published var state: AddMoveState = .ready
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            if let selectedItem {
                loadVideo(from: selectedItem)
            }
        }
    }
    @Published var moveName: String = ""
    @Published var selectedFilename: String?

    // MARK: - Dependencies
    private let videoLoader = VideoLoader()
    private let viewContext: NSManagedObjectContext
    private let albumManager: BreakDexAlbumManager

    // MARK: - Private State
    private var loadingTask: Task<Void, Never>?
    private var currentPhotosIdentifier: String?

    // MARK: - Logging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMove")

    init(viewContext: NSManagedObjectContext, albumManager: BreakDexAlbumManager = BreakDexAlbumManager.shared) {
        self.viewContext = viewContext
        self.albumManager = albumManager
    }

    // MARK: - Public API

    func reset() {
        logger.info("Resetting AddMoveViewModel state.")
        loadingTask?.cancel()
        state = .ready
        selectedItem = nil
        moveName = ""
        currentPhotosIdentifier = nil
        selectedFilename = nil
    }

    func startTrimming(rotationQuarterTurns: Int = 0) {
        logger.info("Starting trimming with rotation \(rotationQuarterTurns)")
        if case .previewing(let asset, let photosIdentifier) = state {
            state = .trimming(asset: asset, photosIdentifier: photosIdentifier, rotationQuarterTurns: rotationQuarterTurns)
        }
    }

    func cancelTrimming() {
        logger.info("Cancelling trimming operation")
        if case .trimming(let asset, let photosIdentifier, _) = state {
            state = .previewing(asset: asset, photosIdentifier: photosIdentifier)
        }
    }

    func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        logger.info("Finishing trimming operation")
        if case .trimming(let asset, let photosIdentifier, let rotationQuarterTurns) = state {
            Task {
                do {
                    let exportedURL = try await trimmerViewModel.exportVideo()
                    let trimmedAsset = AVURLAsset(url: exportedURL)
                    state = .naming(
                        photosIdentifier: photosIdentifier ?? "",
                        originalAsset: asset,
                        trimmedAsset: trimmedAsset,
                        trimStartTime: trimmerViewModel.startTime.seconds,
                        trimEndTime: trimmerViewModel.endTime.seconds,
                        rotationQuarterTurns: rotationQuarterTurns
                    )
                } catch {
                    state = .error(message: "Failed to export video.", underlyingError: error.localizedDescription)
                }
            }
        }
    }

    func saveMove() {
        logger.info("Saving move")
        state = .saving
        // ... save logic ...
    }
    
    func startNaming() {
        logger.info("Starting naming process")
        if case .previewing(let asset, let photosIdentifier) = state {
            state = .naming(photosIdentifier: photosIdentifier ?? "", originalAsset: asset, trimmedAsset: nil, trimStartTime: nil, trimEndTime: nil, rotationQuarterTurns: 0)
        }
    }

    // MARK: - Private Video Loading

    private func loadVideo(from item: PhotosPickerItem) {
        loadingTask?.cancel()
        state = .loading(progress: 0.0, status: "Preparing to load video...")

        loadingTask = Task {
            do {
                let result = try await videoLoader.loadVideo(from: item)
                
                // Check for cancellation before updating the state
                if Task.isCancelled { return }

                self.selectedFilename = result.filename
                self.currentPhotosIdentifier = result.photosIdentifier
                self.state = .previewing(asset: result.asset, photosIdentifier: result.photosIdentifier)

            } catch {
                // Check for cancellation before showing an error
                if Task.isCancelled { return }
                
                logger.error("Failed to load video: \(error.localizedDescription)")
                self.state = .error(message: "Failed to load video.", underlyingError: error.localizedDescription)
            }
        }
    }
}