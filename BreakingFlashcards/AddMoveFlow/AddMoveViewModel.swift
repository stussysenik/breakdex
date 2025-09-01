import SwiftUI
import PhotosUI
import AVKit
import CoreData
import Combine
import Photos
import OSLog

enum AddMoveState: Equatable {
    case ready
    case loading(progress: Double, status: String)
    case previewing(asset: AVAsset, photosIdentifier: String?)
    case trimming(asset: AVAsset, photosIdentifier: String?)
    case naming(photosIdentifier: String, originalAsset: AVAsset?, trimStartTime: Double?, trimEndTime: Double?)
    case saving
    case success(message: String)
    case error(message: String, underlyingError: String?)

    static func == (lhs: AddMoveState, rhs: AddMoveState) -> Bool {
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
        case (let .trimming(a1, id1), let .trimming(a2, id2)):
            return a1 == a2 && id1 == id2
        case (let .naming(id1, _, start1, end1), let .naming(id2, _, start2, end2)):
            return id1 == id2 && start1 == start2 && end1 == end2
        default:
            return false
        }
    }
}

enum AddMoveError: LocalizedError {
    case photosPermissionDenied
    case iCloudUnavailable
    case videoLoadFailed(underlyingError: Error?)
    case videoFormatUnsupported
    case videoCopyFailed(underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error?)
    case unknown(underlyingError: Error?)

    var errorDescription: String? {
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

@MainActor
class AddMoveViewModel: ObservableObject {
    // Loggers
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMove")
    private let mediaLogger = Logger(subsystem: "com.breakingflashcards", category: "Media")
    private let persistenceLogger = Logger(subsystem: "com.breakingflashcards", category: "Persistence")

    @Published var state: AddMoveState = .ready
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            let timestamp = Date().timeIntervalSince1970
            print("📝 AddMoveViewModel: selectedItem didSet at \(timestamp)")
            print("   - New value is nil: \(selectedItem == nil)")
            if let item = selectedItem {
                print("   - New item identifier: \(String(describing: item.itemIdentifier))")
                print("   - New item hash: \(item.hashValue)")
            }
            print("   - Triggering handleSelection()...")
            Task { await handleSelection() }
        }
    }
    @Published var moveName: String = ""

    let viewContext: NSManagedObjectContext

    private var currentPhotosIdentifier: String?
    private var cancellables = Set<AnyCancellable>()

    // Dependency Injection for BreakDexAlbumManager
    private let albumManager: BreakDexAlbumManagerProtocol

    init(viewContext: NSManagedObjectContext, albumManager: BreakDexAlbumManagerProtocol? = nil) {
        self.viewContext = viewContext
        self.albumManager = albumManager ?? (BreakDexAlbumManager.shared as any BreakDexAlbumManagerProtocol)
    }

    func reset() {
        logger.info("Resetting AddMoveViewModel state.")
        state = .ready
        selectedItem = nil
        moveName = ""
        currentPhotosIdentifier = nil
    }

    // MARK: - Photos Selection Handling with Enhanced Logging
    // This method includes detailed logging to diagnose the "Could not get Photos identifier" error
    // that causes random switching to the Arsenal view during the Add Move flow.
    private func handleSelection() async {
        let timestamp = Date().timeIntervalSince1970
        print("🔄 AddMoveViewModel: handleSelection started at \(timestamp)")
        print("   - Thread: Main (async context)")

        guard let item = selectedItem else {
            print("   ⚠️  No PhotosPickerItem selected - returning early")
            logger.debug("No PhotosPickerItem selected.")
            return
        }

        print("   - Item exists: ✅")
        print("   - Item hash: \(item.hashValue)")
        print("   - Item identifier: \(String(describing: item.itemIdentifier))")

        logger.info("Handling PhotosPicker selection.")
        print("   📊 Changing state to loading...")
        state = .loading(progress: 0.0, status: "Loading video from Photos...")

        do {
            guard let identifier = item.itemIdentifier else {
                print("   ❌ CRITICAL: item.itemIdentifier is nil!")
                print("   - Item details: \(item)")
                logger.error("Could not get Photos identifier for selected item.")
                state = .error(message: "Unable to get video identifier.", underlyingError: nil)
                return
            }
            print("   ✅ Photos identifier obtained: \(identifier)")
            logger.debug("Photos identifier: \(identifier)")

            self.currentPhotosIdentifier = identifier

            let asset = try await loadAsset(from: identifier)
            logger.debug("PHAsset loaded.")

            let avAsset = try await createAVAsset(from: asset)
            logger.info("AVAsset created.")
            print("   🎬 AVAsset created successfully")

            print("   📺 Changing state to previewing...")
            state = .previewing(asset: avAsset, photosIdentifier: identifier)
            print("   ✅ handleSelection completed successfully")
        } catch {
            print("   ❌ ERROR in handleSelection: \(error.localizedDescription)")
            print("   - Error type: \(type(of: error))")
            print("   - Full error: \(error)")
            print("   🔄 Changing state to error...")

            logger.error("Failed to handle PhotosPicker selection: \(error.localizedDescription)")
            state = .error(message: "Failed to load video from Photos.", underlyingError: error.localizedDescription)
            print("   ❌ handleSelection failed and completed")
        }
        print("🔚 handleSelection method finished")
        print("---")
    }

    private func createAVAsset(from asset: PHAsset) async throws -> AVAsset {
        logger.debug("Creating AVAsset from PHAsset.")

        // First attempt with immediate response
        do {
            return try await attemptAVAssetCreation(from: asset)
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3164 {
            // iCloud download failure - try retry mechanism
            logger.info("iCloud download failed, attempting retry mechanism...")
            return try await retryAVAssetCreation(from: asset, originalError: error)
        }
    }

    private func attemptAVAssetCreation(from asset: PHAsset) async throws -> AVAsset {
        logger.debug("Attempting to create AVAsset from PHAsset with optimized options")

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.version = .original // Request original quality

            // Add progress handler for better user feedback during download
            options.progressHandler = { [self] progress, error, stop, info in
                self.logger.debug("iCloud download progress: \(String(format: "%.1f", progress * 100))%")
                if let error = error {
                    self.logger.warning("Progress handler error: \(error.localizedDescription)")
                }
            }

            logger.debug("Requesting AVAsset with options: networkAllowed=\(options.isNetworkAccessAllowed), deliveryMode=\(options.deliveryMode.rawValue), version=\(options.version.rawValue)")

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [self] avAsset, audioMix, info in
                if let error = info?[PHImageErrorKey] {
                    var errorMessage = "Failed to load video from Photos"
                    var nsError: NSError

                    if let photosError = error as? NSError {
                        // Check for specific PHPhotosErrorDomain errors first
                        if photosError.domain == "PHPhotosErrorDomain" {
                            switch photosError.code {
                            case 3164:
                                errorMessage = "Error loading AVAsset: iCloud video could not be downloaded. Please ensure you have an internet connection and sufficient storage."
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: photosError.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            case 3202:
                                errorMessage = "Error loading AVAsset: iCloud photo not yet downloaded"
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: photosError.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            case 3201:
                                errorMessage = "Error loading AVAsset: Photo access denied"
                                nsError = NSError(domain: "PHPhotosErrorDomain", code: photosError.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            default:
                                nsError = photosError
                                errorMessage = "Error loading AVAsset: \(photosError.localizedDescription)"
                            }
                        } else {
                            nsError = photosError
                            errorMessage = "Error loading AVAsset: \(photosError.localizedDescription)"
                        }
                    } else if let errorDict = error as? [String: Any],
                              let errorCode = errorDict["PHImageErrorKey"] as? Int {
                        switch errorCode {
                        default:
                            errorMessage = "Error loading AVAsset (error code: \(errorCode))"
                            nsError = NSError(domain: "PHPhotosErrorDomain", code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        }
                    } else {
                        nsError = NSError(domain: "CustomVideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos request failed."])
                    }

                    print(errorMessage)
                    continuation.resume(throwing: nsError)
                } else if let avAsset = avAsset {
                    logger.debug("AVAsset created successfully.")
                    continuation.resume(returning: avAsset)
                } else {
                    print("Unknown error: AVAsset is nil and no error provided.")
                    continuation.resume(throwing: NSError(domain: "CustomVideoPlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos request failed."]))
                }
            }
        }
    }

    private func retryAVAssetCreation(from asset: PHAsset, originalError: NSError) async throws -> AVAsset {
        logger.info("Starting iCloud download retry mechanism at \(Date())")
        logger.info("Original error details: Domain=\(originalError.domain), Code=\(originalError.code), Description=\(originalError.localizedDescription)")

        // Check iCloud status first (most critical)
        guard await checkiCloudStatus() else {
            logger.error("iCloud not properly configured - user needs to sign in or enable iCloud Photos")
            throw NSError(domain: "PHPhotosErrorDomain",
                         code: 3164,
                         userInfo: [NSLocalizedDescriptionKey: "Please ensure you are signed into iCloud and iCloud Photo Library is enabled. Go to Settings > [Your Name] > iCloud > Photos and turn on iCloud Photos."])
        }

        // Enhanced network diagnostics for iCloud services
        guard await checkiCloudConnectivity() else {
            logger.error("Cannot reach iCloud services - network or service issue")
            throw NSError(domain: "PHPhotosErrorDomain",
                         code: 3164,
                         userInfo: [NSLocalizedDescriptionKey: "Unable to connect to iCloud services. Please check your internet connection and try again."])
        }

        // Check available storage with better estimation
        let estimatedSize = await estimateVideoSize(asset)
        let availableSpace = await getAvailableStorage()
        let minimumRequiredSpace = max(estimatedSize, 100) // At least 100MB buffer

        logger.info("Storage check: Estimated video size: \(estimatedSize)MB, Available: \(availableSpace)MB, Minimum required: \(minimumRequiredSpace)MB")

        if availableSpace < minimumRequiredSpace {
            logger.warning("Insufficient storage for iCloud download")
            throw NSError(domain: "PHPhotosErrorDomain",
                         code: 3164,
                         userInfo: [NSLocalizedDescriptionKey: "Not enough storage space. This video needs approximately \(minimumRequiredSpace)MB. Please free up space and try again."])
        }

        // Retry with exponential backoff and comprehensive logging
        let maxRetries = 3
        var lastError: NSError = originalError
        var attemptStartTime: Date = Date()

        for attempt in 1...maxRetries {
            attemptStartTime = Date()
            logger.info("iCloud download attempt \(attempt)/\(maxRetries) started at \(attemptStartTime)")
            logger.info("Asset details: localIdentifier=\(asset.localIdentifier), mediaType=\(asset.mediaType.rawValue), duration=\(asset.duration)")

            // Update progress for user feedback with more specific messages
            let progressMessages = [
                "Connecting to iCloud...",
                "Downloading video from iCloud...",
                "Final attempt to download from iCloud..."
            ]
            let progressMessage = attempt <= progressMessages.count ? progressMessages[attempt - 1] : "Downloading from iCloud... (Attempt \(attempt)/\(maxRetries))"

            await MainActor.run {
                state = .loading(progress: Double(attempt) / Double(maxRetries + 1), status: progressMessage)
            }

            do {
                let startTime = Date()
                logger.info("Initiating AVAsset request for attempt \(attempt)")

                let result = try await attemptAVAssetCreation(from: asset)
                let duration = Date().timeIntervalSince(startTime)

                logger.info("iCloud download succeeded on attempt \(attempt) in \(String(format: "%.2f", duration)) seconds")
                // Note: Using async load methods for asset properties would require additional async context

                return result
            } catch let error as NSError {
                let attemptDuration = Date().timeIntervalSince(attemptStartTime)
                lastError = error

                logger.error("iCloud download attempt \(attempt) failed after \(String(format: "%.2f", attemptDuration))s")
                logger.error("Failure details: Domain=\(error.domain), Code=\(error.code), Description=\(error.localizedDescription)")
                logger.error("Full error userInfo: \(error.userInfo)")

                // If it's not an iCloud error, don't retry
                if !(error.domain == "PHPhotosErrorDomain" && error.code == 3164) {
                    logger.error("Non-iCloud error encountered, aborting retry mechanism")
                    throw error
                }

                // Don't wait after the last attempt
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1)) * 2.0 // 2s, 4s, 8s
                    logger.info("Waiting \(delay) seconds before retry \(attempt + 1)...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All retries failed - provide comprehensive troubleshooting guidance
        logger.error("All iCloud download attempts failed after \(maxRetries) attempts")
        logger.error("Final error details: \(lastError)")

        let troubleshootingSteps = """
        Unable to download video from iCloud. Please try:
        1. Open the Photos app and ensure the video is fully downloaded to your device
        2. Check Settings > [Your Name] > iCloud > Photos - ensure iCloud Photos is enabled
        3. Verify you have enough storage space and a stable internet connection
        4. Try restarting your device if the problem persists
        """

        let finalError = NSError(domain: "PHPhotosErrorDomain",
                                code: 3164,
                                userInfo: [NSLocalizedDescriptionKey: troubleshootingSteps])
        throw finalError
    }

    private func isNetworkAvailable() async -> Bool {
        // Simple network reachability check
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 5.0

        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (_, response) = try await session.data(from: URL(string: "https://www.apple.com")!)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            logger.debug("Network check failed: \(error.localizedDescription)")
            return false
        }
    }

    private func estimateVideoSize(_ asset: PHAsset) async -> Int64 {
        // Estimate video size based on duration and typical bitrate
        // This is a rough estimate: ~50MB per minute at 1080p
        let duration = asset.duration
        let estimatedSizeMB = duration * 50.0 // 50MB per minute
        return Int64(estimatedSizeMB * 1024 * 1024) // Convert to bytes
    }

    private func getAvailableStorage() async -> Int64 {
        do {
            let fileManager = FileManager.default
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? Int64 ?? 0
            let freeSpaceMB = freeSpace / (1024 * 1024)
            logger.debug("Available storage: \(freeSpaceMB)MB")
            return freeSpace
        } catch {
            logger.warning("Could not determine available storage: \(error.localizedDescription)")
            return 100 * 1024 * 1024 // Assume 100MB if we can't check
        }
    }

    private func loadAsset(from identifier: String) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

            if let asset = fetchResult.firstObject {
                continuation.resume(returning: asset)
            } else {
                continuation.resume(throwing: NSError(domain: "AddMove", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find asset in Photos library."]))
            }
        }
    }

    func saveMove() {
        guard case .naming(let photosIdentifier, _, let trimStartTime, let trimEndTime) = state else {
            logger.error("saveMove called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Attempting to save move: \(self.moveName)")
        state = .saving

        let moveID = UUID()
        let name = self.moveName

        Task {
            do {
                logger.info("Copying video to BreakDex album.")
                state = .loading(progress: 0.7, status: "Copying video to BreakDex...")
                let breakDexAsset = try await self.albumManager.copyVideoToBreakDex(identifier: photosIdentifier)
                logger.info("Video copied to BreakDex album. New asset local identifier: \(breakDexAsset.localIdentifier)")

                logger.info("Saving move to Core Data.")
                try await saveMoveToCoreData(
                    id: moveID,
                    name: name,
                    photosIdentifier: breakDexAsset.localIdentifier,
                    trimStartTime: trimStartTime ?? 0.0,
                    trimEndTime: trimEndTime ?? 0.0
                )

                state = .success(message: "'\(name)' has been saved to BreakDex!")
                logger.info("Move saved successfully: \(name)")
            } catch {
                let addMoveError: AddMoveError
                if let error = error as? AddMoveError {
                    addMoveError = error
                } else if let albumError = error as? BreakDexAlbumError {
                    addMoveError = .videoCopyFailed(underlyingError: albumError)
                } else {
                    addMoveError = .unknown(underlyingError: error)
                }
                logger.error("Failed to save move: \(addMoveError.localizedDescription)")
                state = .error(message: addMoveError.localizedDescription, underlyingError: addMoveError.localizedDescription)
            }
        }
    }

    private func saveMoveToCoreData(id: UUID, name: String, photosIdentifier: String, trimStartTime: Double, trimEndTime: Double) async throws {
        logger.debug("Saving move to Core Data: ID=\(id), Name=\(name), PhotosIdentifier=\(photosIdentifier)")
        let context = viewContext

        try await context.perform {
            let newMove = Move(context: context)
            newMove.id = id
            newMove.name = name
            newMove.createdAt = Date()
            newMove.learningState = "NEW"
            newMove.photosIdentifier = photosIdentifier
            newMove.trimStartTime = trimStartTime
            newMove.trimEndTime = trimEndTime

            do {
                try context.save()
                self.persistenceLogger.info("Core Data context saved successfully for move ID: \(id)")
            } catch {
                self.persistenceLogger.error("Failed to save Core Data context for move ID \(id): \(error.localizedDescription)")
                throw AddMoveError.coreDataSaveFailed(underlyingError: error)
            }
        }
    }

    // MARK: - State Transitions

    func startTrimming() {
        guard case .previewing(let asset, let identifier) = state else {
            logger.error("startTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Transitioning to .trimming state.")
        state = .trimming(asset: asset, photosIdentifier: identifier)
    }

    func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        guard case .trimming(let asset, let identifier) = state, let identifier = identifier else { // Capture asset
            logger.error("finishTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Finishing trimming process.")
        let startTime = trimmerViewModel.startTime
        let endTime = trimmerViewModel.endTime
        state = .naming(photosIdentifier: identifier, originalAsset: asset, trimStartTime: startTime, trimEndTime: endTime) // Pass asset
        logger.info("Transitioned to .naming state after trimming.")
    }

    func cancelTrimming() {
        guard case .trimming(let asset, let identifier) = state else {
            logger.error("cancelTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Cancelling trimming. Transitioning back to .previewing state.")
        state = .previewing(asset: asset, photosIdentifier: identifier)
    }

    func cancelNaming() {
        guard case .naming(_, let originalAsset, _, _) = state, let originalAsset = originalAsset else {
            logger.error("cancelNaming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Cancelling naming. Transitioning back to .previewing state.")
        state = .previewing(asset: originalAsset, photosIdentifier: nil)
    }

    func startNaming() {
        guard case .previewing(let asset, let identifier) = state else {
            logger.error("startNaming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Transitioning to .naming state.")
        state = .naming(photosIdentifier: identifier!, originalAsset: asset, trimStartTime: nil, trimEndTime: nil)
    }

    // MARK: - iCloud Diagnostic Functions

    private func checkiCloudStatus() async -> Bool {
        logger.debug("Checking iCloud account status...")

        // Check if user is signed into iCloud
        guard let iCloudAccount = FileManager.default.ubiquityIdentityToken else {
            logger.warning("User not signed into iCloud")
            return false
        }

        logger.info("User is signed into iCloud: \(String(describing: iCloudAccount))")

        // Check if iCloud Photo Library is enabled
        let photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        logger.debug("Photo Library authorization status: \(photoLibraryStatus.rawValue)")

        return true
    }

    private func checkiCloudConnectivity() async -> Bool {
        logger.debug("Testing connectivity to iCloud services...")

        // Test basic internet connectivity
        guard await isNetworkAvailable() else {
            logger.warning("No basic network connectivity")
            return false
        }

        // Test connectivity to iCloud Photos specifically
        guard let url = URL(string: "https://p23-sharedstreams.icloud.com") else {
            logger.error("Invalid iCloud URL")
            return false
        }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 10.0

            let session = URLSession(configuration: config)
            let (_, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                logger.info("iCloud connectivity test: HTTP \(httpResponse.statusCode)")
                return httpResponse.statusCode >= 200 && httpResponse.statusCode < 400
            } else {
                logger.warning("iCloud connectivity test: Non-HTTP response")
                return true // Assume connectivity if we got a response
            }
        } catch {
            logger.error("iCloud connectivity test failed: \(error.localizedDescription)")
            return false
        }
    }
}

// Define a protocol for BreakDexAlbumManager to enable mocking
protocol BreakDexAlbumManagerProtocol {
    func copyVideoToBreakDex(identifier: String) async throws -> PHAsset
    func copyVideoToBreakDex(_ asset: PHAsset) async throws -> PHAsset
}

// Conform BreakDexAlbumManager to the protocol
extension BreakDexAlbumManager: BreakDexAlbumManagerProtocol {
    func copyVideoToBreakDex(identifier: String) async throws -> PHAsset {
        // Get the original PHAsset
        let originalAsset = try await loadAsset(from: identifier)
        // Use BreakDexAlbumManager to copy it to the album
        return try await copyVideoToBreakDex(originalAsset)
    }

    private func loadAsset(from identifier: String) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

            if let asset = fetchResult.firstObject {
                continuation.resume(returning: asset)
            } else {
                continuation.resume(throwing: NSError(domain: "AddMove", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find asset in Photos library."]))
            }
        }
    }
}