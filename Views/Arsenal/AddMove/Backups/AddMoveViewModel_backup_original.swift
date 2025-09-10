import SwiftUI
import PhotosUI
import AVKit
@preconcurrency import AVFoundation
import CoreData
import Combine
import Photos
import OSLog

// Use the shared PhotosClient actor

// state machine for the add move view - all the logic + states
enum AddMoveState: Equatable, Hashable {
    case ready
    case loading(progress: Double, status: String)
    case previewing(asset: AVAsset, photosIdentifier: String?)
    case selectingVideo(currentAsset: AVAsset?) // NEW: For video selection mode
    case trimming(asset: AVAsset, photosIdentifier: String?, rotationQuarterTurns: Int)
    case naming(photosIdentifier: String, originalAsset: AVAsset?, trimmedAsset: AVAsset?, trimStartTime: Double?, trimEndTime: Double?, rotationQuarterTurns: Int)
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

    func hash(into hasher: inout Hasher) {
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
    // Loggers for debugging
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMove")
    private let mediaLogger = Logger(subsystem: "com.breakingflashcards", category: "Media")
    private let persistenceLogger = Logger(subsystem: "com.breakingflashcards", category: "Persistence")
    
    @Published var state: AddMoveState = .ready {
        didSet {
            let timestamp = Date().timeIntervalSince1970
            print("🔄 [\(String(format: "%.3f", timestamp))] STATE TRANSITION: \(oldValue) → \(state)")

            // Enhanced logging for trimming navigation
            if case .trimming = state {
                print("🎬 [\(String(format: "%.3f", timestamp))] NAVIGATION: Entering trimming interface")
            } else if case .error = state {
                print("❌ [\(String(format: "%.3f", timestamp))] ERROR: Navigation failed, showing error state")
            }

            // Log stack trace for debugging
            if case .loading = state, case .previewing = oldValue {
                print("   ⚠️ SUSPICIOUS: State reset from previewing back to loading!")
                let stack = Thread.callStackSymbols.joined(separator: "\n")
                print("   📍 Stack trace:\n\(stack)")
            }
        }
    }
    @Published var selectedItem: PhotosPickerItem? {
        didSet {
            let timestamp = Date().timeIntervalSince1970
            print("📝 AddMoveViewModel: selectedItem didSet at \(timestamp)")
            print("   - New value is nil: \(selectedItem == nil)")
            if let item = selectedItem {
                print("   - New item identifier: \(String(describing: item.itemIdentifier))")
                print("   - New item hash: \(item.hashValue)")
            }

            // Prevent re-processing if we're already in a loading/trimming state, but allow from previewing for "Change Video"
            switch state {
            case .loading, .trimming, .naming, .saving:
                print("   ⚠️ Already processing a video (state: \(state)), skipping video loading")
                return
            case .previewing:
                print("   🔄 User tapped 'Change Video' from previewing state - allowing new selection")
                // Continue to video loading for "Change Video" functionality
            default:
                break
            }

            // Use inline video loading to handle video selection
            if let item = selectedItem {
                print("   - Triggering inline video loading...")
                loadVideoFromItem(item)
            }
        }
    }
    @Published var moveName: String = ""
    @Published var selectedFilename: String? = nil
    
    let viewContext: NSManagedObjectContext

    // Loading state exposed for UI
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingStatus: String = ""
    @Published private(set) var loadingProgress: Double = 0.0
    
    private var currentPhotosIdentifier: String?
    private var currentProcessingItemHash: Int?
    private var cancellables = Set<AnyCancellable>()
    private let albumManager: BreakDexAlbumManagerProtocol // dependency Injection for BreakDexAlbumManager

    // Temporary inline video loader service
    private var currentTask: Task<Void, Never>?
    
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
        selectedFilename = nil
        currentProcessingItemHash = nil // Clear processing state
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        loadingStatus = ""
        loadingProgress = 0.0
    }

    // MARK: - Inline Video Loading

    private func loadVideoFromItem(_ item: PhotosPickerItem) {
        // Cancel any previous task
        currentTask?.cancel()

        // Set initial loading state
        isLoading = true
        loadingStatus = "Preparing to load video..."
        loadingProgress = 0.0

        // Start the loading task
        currentTask = Task {
            await performVideoLoading(from: item)
        }
    }

    private func performVideoLoading(from item: PhotosPickerItem) async {
        do {
            // Initial progress update
            await updateProgress(to: 0.1, status: "Analyzing video properties...")

            // Check if we have a Photos identifier
            if let identifier = item.itemIdentifier {
                // Load from Photos library
                let phAsset = try await loadAsset(from: identifier)
                await updateProgress(to: 0.4, status: "Loading video from Photos library...")

                let avAsset = try await createAVAsset(from: phAsset)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let filename = try await extractFilename(from: phAsset)

                // Success - transition to previewing state
                await MainActor.run {
                    currentPhotosIdentifier = identifier
                    selectedFilename = filename
                    currentProcessingItemHash = nil
                    state = .previewing(asset: avAsset, photosIdentifier: identifier)
                }

                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")

            } else {
                // Load directly from PhotosPickerItem data
                await updateProgress(to: 0.3, status: "Preparing to download video...")

                let avAsset = try await loadAVAssetDirectlyFromPhotosPickerItem(item)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let tempIdentifier = "temp-\(UUID().uuidString)"

                // Success - transition to previewing state
                await MainActor.run {
                    currentPhotosIdentifier = tempIdentifier
                    selectedFilename = "Selected Video"
                    currentProcessingItemHash = nil
                    state = .previewing(asset: avAsset, photosIdentifier: tempIdentifier)
                }

                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")
            }

        } catch {
            // Error handling
            await MainActor.run {
                currentProcessingItemHash = nil
                state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }
            await updateProgress(to: 0.0, status: "Failed to load video: \(error.localizedDescription)")
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func updateProgress(to value: Double, status: String) async {
        await MainActor.run {
            self.loadingProgress = value
            self.loadingStatus = status
        }
    }

    // MARK: - Photos Asset Loading Methods (copied from VideoLoaderService)

    private func loadAsset(from identifier: String) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

            if let asset = fetchResult.firstObject {
                continuation.resume(returning: asset)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "AddMoveViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find asset in Photos library."]
                ))
            }
        }
    }

    private func createAVAsset(from asset: PHAsset) async throws -> AVAsset {
        // First attempt with immediate response
        do {
            return try await attemptAVAssetCreation(from: asset)
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3164 {
            // iCloud download failure - try retry mechanism
            return try await retryAVAssetCreation(from: asset, originalError: error)
        }
    }

    private func attemptAVAssetCreation(from asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: NSError(
                        domain: "AddMoveViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]
                    ))
                    return
                }

                guard let avAsset = avAsset else {
                    continuation.resume(throwing: NSError(
                        domain: "AddMoveViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No asset returned"]
                    ))
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    private func retryAVAssetCreation(from asset: PHAsset, originalError: NSError) async throws -> AVAsset {
        // Basic retry mechanism for iCloud downloads
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return try await attemptAVAssetCreation(from: asset)
    }

    private func loadAVAssetDirectlyFromPhotosPickerItem(_ item: PhotosPickerItem) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                Task {
                    switch result {
                    case .success(let data):
                        guard let videoData = data else {
                            continuation.resume(throwing: NSError(
                                domain: "AddMoveViewModel",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No video data received"]
                            ))
                            return
                        }

                        do {
                            // Calculate data size for feedback
                            let dataSizeMB = Double(videoData.count) / (1024.0 * 1024.0)
                            let sizeDescription = dataSizeMB > 100.0 ? ">100MB" : String(format: "%.1fMB", dataSizeMB)

                            // Create a temporary file URL for the video data
                            let tempDirectory = FileManager.default.temporaryDirectory
                            let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mov")

                            // Write the data to a temporary file
                            try videoData.write(to: tempURL)

                            // Create AVAsset from the temporary file
                            let asset = AVURLAsset(url: tempURL)
                            continuation.resume(returning: asset)

                        } catch {
                            continuation.resume(throwing: error)
                        }

                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func extractFilename(from asset: PHAsset) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first(where: { $0.type == .video }) {
                continuation.resume(returning: resource.originalFilename)
            } else {
                continuation.resume(returning: "Video")
            }
        }
    }

    // Prepare for video reselection while preserving current state
    func prepareForVideoReselection() {
        logger.info("Preparing for video reselection from preview state.")
        // Don't reset the state - just clear the processing hash to allow new selection
        currentProcessingItemHash = nil
        // The state remains .previewing, which will allow the container to show selection UI
    }

    // State-driven navigation intents for video selection
    func beginChangeVideo() {
        logger.info("Beginning video change from current state.")
        if case .previewing(let currentAsset, _) = state {
            print("🔄 STATE CHANGE: \(state) → selectingVideo(currentAsset: \(String(describing: currentAsset)))")
            state = .selectingVideo(currentAsset: currentAsset)
        } else {
            logger.warning("beginChangeVideo called from non-previewing state: \(String(describing: self.state))")
        }
    }

    func cancelChangeVideo() {
        logger.info("Cancelling video change.")
        if case .selectingVideo(let currentAsset) = state {
            if let currentAsset = currentAsset {
                print("🔄 STATE CHANGE: \(state) → previewing(asset: \(currentAsset), photosIdentifier: nil)")
                state = .previewing(asset: currentAsset, photosIdentifier: nil)
            } else {
                print("🔄 STATE CHANGE: \(state) → ready")
                state = .ready
            }
        } else {
            logger.warning("cancelChangeVideo called from non-selectingVideo state: \(String(describing: self.state))")
        }
    }

    func didPickVideo(asset: AVAsset, photosIdentifier: String?) {
        logger.info("Video picked: \(photosIdentifier ?? "no identifier")")
        print("🔄 STATE CHANGE: \(state) → previewing(asset: \(asset), photosIdentifier: \(photosIdentifier ?? "nil"))")
        state = .previewing(asset: asset, photosIdentifier: photosIdentifier)
    }
    
    // photo selection
    private func handleSelection() async {
        var metadataTask: Task<Void, Never>?
        let timestamp = Date().timeIntervalSince1970
        print("🔄 AddMoveViewModel: handleSelection started at \(timestamp)")
        print("   - Thread: Main (async context)")
        print("   - Current state: \(state)")

        // Double-check guard - prevent re-processing if already processing
        // Note: previewing is a completed state, not processing, so allow reselection
        switch state {
        case .loading, .trimming, .naming, .saving:
            print("   ⚠️ DOUBLE GUARD: Already processing a video (state: \(state)), aborting handleSelection()")
            return
        case .previewing:
            print("   🔄 DOUBLE GUARD: Allowing reselection from previewing state")
        default:
            break
        }
        
        guard let item = selectedItem else {
            print("   ⚠️  No PhotosPickerItem selected - returning early")
            logger.debug("No PhotosPickerItem selected.")
            return
        }

        print("   - Item exists: ✅")
        print("   - Item hash: \(item.hashValue)")
        print("   - Item identifier: \(String(describing: item.itemIdentifier))")

        // Check for PhotosPicker dismissal (nil identifier means user canceled)
        if item.itemIdentifier == nil {
            print("   ⚠️  PHOTOS PICKER DISMISSED: No video selected (itemIdentifier is nil), skipping")
            return
        }

        // Deduplication: Prevent processing the same item multiple times
        if let currentHash = currentProcessingItemHash, currentHash == item.hashValue {
            print("   ⚠️  DEDUPLICATION: Already processing item with hash \(item.hashValue), skipping")
            return
        }

        // Mark this item as being processed
        currentProcessingItemHash = item.hashValue
        
        logger.info("Handling PhotosPicker selection.")
        print("   📊 Changing state to loading...")
        state = .loading(progress: 0.0, status: "Preparing to load video...")

        // Update progress on main thread with early analysis
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay for UI update
            self.state = .loading(progress: 0.1, status: "Analyzing video properties...")
        }
        
        do {
            // Try to get identifier first (for backwards compatibility)
            var identifier: String? = item.itemIdentifier

            if identifier == nil {
                print("   ⚠️  item.itemIdentifier is nil, trying to load video directly...")
                print("   - Item details: \(item)")

                // Update progress before starting direct loading
                await MainActor.run {
                    self.state = .loading(progress: 0.3, status: "Preparing to download video...")
                }

                // Try to load the video directly using the item provider
                let avAsset = try await loadAVAssetDirectlyFromPhotosPickerItem(item)

                // Analyze the loaded asset for better user feedback
                let assetInfo = await analyzeAssetProperties(avAsset)

                // Provide detailed feedback for long videos
                let detailedFeedback = assetInfo.duration > 60.0
                    ? "Loaded \(Int(assetInfo.duration/60))-minute video (\(assetInfo.trackCount) tracks) - processing..."
                    : "Processing video... (\(assetInfo.trackCount) tracks)"

                // Update progress after loading data with asset-specific feedback
                await MainActor.run {
                    self.state = .loading(progress: 0.7, status: detailedFeedback)
                }

                // Add intermediate step for asset validation
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // Brief pause for UI update
                    self.state = .loading(progress: 0.8, status: "Validating video format...")
                }

                print("   📊 Asset Analysis: duration=\(assetInfo.duration), tracks=\(assetInfo.trackCount), large=\(assetInfo.isLargeAsset)")

                logger.info("AVAsset created directly from PhotosPickerItem.")
                print("   🎬 AVAsset created successfully from PhotosPickerItem")

                // Create a temporary identifier for tracking purposes
                identifier = "temp-\(UUID().uuidString)"
                print("   ✅ Created temporary identifier: \(identifier!)")

                self.currentPhotosIdentifier = identifier
                self.selectedFilename = "Selected Video" // Generic filename since we don't have access to original

                // Final progress update before showing video
                await MainActor.run {
                    self.state = .loading(progress: 0.9, status: "Preparing video preview...")
                }

                // Add final preparation step for long videos
                if assetInfo.duration > 120.0 { // 2+ minutes
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s pause
                        self.state = .loading(progress: 0.95, status: "Finalizing long video...")
                    }
                }

                // Show 100% progress briefly before transitioning
                await MainActor.run {
                    self.state = .loading(progress: 1.0, status: "Video loaded successfully! 🎬")
                }

                // Cancel the metadata task since we're moving to previewing state
                metadataTask?.cancel()

                // Small delay to show completion
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds for long videos
                }

                print("   📺 Changing state to previewing...")
                print("   🎬 NEW STATE: .previewing(asset: \(avAsset), photosIdentifier: \(identifier!))")
                state = .previewing(asset: avAsset, photosIdentifier: identifier!)
                currentProcessingItemHash = nil // Clear processing state on success
                print("   ✅ handleSelection completed successfully")
                print("   🔄 STATE CHANGE COMPLETE - PreTrimView should be recreated with new asset")
            } else {
                print("   ✅ Photos identifier obtained: \(identifier!)")
                logger.debug("Photos identifier: \(identifier!)")

                // Update progress for Photos asset loading
                await MainActor.run {
                    self.state = .loading(progress: 0.4, status: "Loading video from Photos library...")
                }

                self.currentPhotosIdentifier = identifier

                let asset = try await loadAsset(from: identifier!)
                logger.debug("PHAsset loaded.")

                // Start granular PHAsset analysis
                await MainActor.run {
                    self.state = .loading(progress: 0.4, status: "Reading video properties...")
                }

                // Get basic asset properties first
                let basicDuration = asset.duration
                let isICloud = asset.sourceType == .typeCloudShared || asset.location == nil

                await MainActor.run {
                    let durationText = basicDuration > 60 ? "\(Int(basicDuration/60))m \(Int(basicDuration.truncatingRemainder(dividingBy: 60)))s" : "\(Int(basicDuration))s"
                    let earlyMessage = basicDuration > 60 || isICloud
                        ? "Detected \(durationText) video - analyzing details..."
                        : "Analyzing video details..."
                    self.state = .loading(progress: 0.45, status: earlyMessage)
                }

                // Analyze PHAsset for comprehensive feedback
                let assetInfo = await analyzePHAssetProperties(asset)

                // Provide detailed feedback based on analysis
                let estimatedLoadTime = estimateLoadTime(assetInfo.duration, assetInfo.isICloud)
                await MainActor.run {
                    let detailMessage = assetInfo.duration > 60.0
                        ? "\(Int(assetInfo.duration/60))-minute video detected - estimated load time: \(estimatedLoadTime)"
                        : assetInfo.isLargeAsset
                            ? "Large video file detected - preparing to load..."
                            : "Video analysis complete - preparing to load..."
                    self.state = .loading(progress: 0.5, status: detailMessage)
                }

                // Add intermediate steps for filename and resource extraction
                metadataTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s pause for UI update

                    // --- RACE CONDITION PROTECTION ---
                    // Only update state if we're still in loading state (not previewing)
                    // This prevents the race condition where this task completes late
                    // and incorrectly resets the state from .previewing back to .loading.
                    guard case .loading = self.state else {
                        print("🔍 DEBUG: State is no longer .loading, skipping late metadata update.")
                        return
                    }
                    // --- END PROTECTION ---

                    self.state = .loading(progress: 0.6, status: "Extracting video metadata...")
                }

                print("🔍 DEBUG: About to extract filename...")
                // Extract filename and prepare for AVAsset creation
                if let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename {
                    self.selectedFilename = filename
                    print("🔍 DEBUG: Filename extracted: \(filename)")
                } else {
                    print("🔍 DEBUG: No filename found in PHAssetResource")
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s pause for UI update
                    self.state = .loading(progress: 0.7, status: "Preparing video asset...")
                    print("🔍 DEBUG: Set status to 'Preparing video asset...'")
                }

                print("   📊 PHAsset Analysis: duration=\(assetInfo.duration), size=\(assetInfo.sizeDescription), iCloud=\(assetInfo.isICloud), estimatedTime=\(estimatedLoadTime)")

                // Update progress for AVAsset creation
                await MainActor.run {
                    let assetMessage = assetInfo.duration > 120.0
                        ? "Creating video asset... (may take longer for long videos)"
                        : "Creating video asset..."
                    self.state = .loading(progress: 0.8, status: assetMessage)
                    print("🔍 DEBUG: Set status to '\(assetMessage)'")
                }

                // Add intermediate step for asset creation
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
                    if assetInfo.duration > 60.0 {
                        self.state = .loading(progress: 0.85, status: "Processing \(Int(assetInfo.duration/60))-minute video...")
                        print("🔍 DEBUG: Set status for long video processing")
                    }
                }

                print("🔍 DEBUG: About to call createAVAsset...")
                let avAsset = try await createAVAsset(from: asset)
                logger.info("AVAsset created.")
                print("🔍 DEBUG: createAVAsset completed successfully")
                print("   🎬 AVAsset created successfully")

                // Final progress update before showing video
                await MainActor.run {
                    self.state = .loading(progress: 0.95, status: "Finalizing video preview...")
                    print("🔍 DEBUG: Set status to 'Finalizing video preview...'")
                }

                // Show 100% progress briefly before transitioning
                await MainActor.run {
                    self.state = .loading(progress: 1.0, status: "Video loaded successfully! 🎬")
                    print("🔍 DEBUG: Set status to 'Video loaded successfully! 🎬'")
                }

                // Small delay to show completion
                print("🔍 DEBUG: About to sleep for 0.2 seconds...")
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                print("🔍 DEBUG: Sleep completed, about to transition to previewing state")

                print("   📺 Changing state to previewing...")
                print("   🎬 NEW STATE: .previewing(asset: \(avAsset), photosIdentifier: \(identifier!))")
                print("🔍 DEBUG: About to set state to .previewing...")
                state = .previewing(asset: avAsset, photosIdentifier: identifier!)
                currentProcessingItemHash = nil // Clear processing state on success
                print("🔍 DEBUG: State set to .previewing successfully")
                print("   ✅ handleSelection completed successfully")
                print("   🔄 STATE CHANGE COMPLETE - PreTrimView should be recreated with new asset")
            }
        } catch {
            print("   ❌ ERROR in handleSelection: \(error.localizedDescription)")
            print("   - Error type: \(type(of: error))")
            print("   - Full error: \(error)")
            print("   🔄 Changing state to error...")

            // Clear processing state on error so user can retry
            currentProcessingItemHash = nil

            logger.error("Failed to handle PhotosPicker selection: \(error.localizedDescription)")
            state = .error(message: "Failed to load video from Photos.", underlyingError: error.localizedDescription)
            print("   ❌ handleSelection failed and completed")
        }
        print("🔚 handleSelection method finished")
        print("---")
    }
    
    // MARK: - Video Loading Methods

    private func loadVideoFromItem(_ item: PhotosPickerItem) {
        // Cancel any previous task
        currentTask?.cancel()

        // Set initial loading state
        isLoading = true
        loadingStatus = "Preparing to load video..."
        loadingProgress = 0.0

        // Start the loading task
        currentTask = Task {
            await performVideoLoading(from: item)
        }
    }

    private func performVideoLoading(from item: PhotosPickerItem) async {
        do {
            // Initial progress update
            await updateProgress(to: 0.1, status: "Analyzing video properties...")

            // Check if we have a Photos identifier
            if let identifier = item.itemIdentifier {
                // Load from Photos library
                let phAsset = try await loadAsset(from: identifier)
                await updateProgress(to: 0.4, status: "Loading video from Photos library...")

                let avAsset = try await createAVAsset(from: phAsset)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let filename = try await extractFilename(from: phAsset)

                // Success - transition to previewing state
                await MainActor.run {
                    currentPhotosIdentifier = identifier
                    selectedFilename = filename
                    currentProcessingItemHash = nil
                    state = .previewing(asset: avAsset, photosIdentifier: identifier)
                }

                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")

            } else {
                // Load directly from PhotosPickerItem data
                await updateProgress(to: 0.3, status: "Preparing to download video...")

                let avAsset = try await loadAVAssetDirectlyFromPhotosPickerItem(item)
                await updateProgress(to: 0.8, status: "Finalizing video preview...")

                let tempIdentifier = "temp-\(UUID().uuidString)"

                // Success - transition to previewing state
                await MainActor.run {
                    currentPhotosIdentifier = tempIdentifier
                    selectedFilename = "Selected Video"
                    currentProcessingItemHash = nil
                    state = .previewing(asset: avAsset, photosIdentifier: tempIdentifier)
                }

                await updateProgress(to: 1.0, status: "Video loaded successfully! 🎬")
            }

        } catch {
            // Error handling
            await MainActor.run {
                currentProcessingItemHash = nil
                state = .error(message: "Failed to load video", underlyingError: error.localizedDescription)
            }
            await updateProgress(to: 0.0, status: "Failed to load video: \(error.localizedDescription)")
        }

        await MainActor.run {
            isLoading = false
        }
    }

    private func updateProgress(to value: Double, status: String) async {
        await MainActor.run {
            self.loadingProgress = value
            self.loadingStatus = status
        }
    }

    // MARK: - Photos Asset Loading Methods

    private func loadAsset(from identifier: String) async throws -> PHAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)

            if let asset = fetchResult.firstObject {
                continuation.resume(returning: asset)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "AddMoveViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find asset in Photos library."]
                ))
            }
        }
    }

    private func createAVAsset(from asset: PHAsset) async throws -> AVAsset {
        // First attempt with immediate response
        do {
            return try await attemptAVAssetCreation(from: asset)
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3164 {
            // iCloud download failure - try retry mechanism
            return try await retryAVAssetCreation(from: asset, originalError: error)
        }
    }

    private func attemptAVAssetCreation(from asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: NSError(
                        domain: "AddMoveViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]
                    ))
                    return
                }

                guard let avAsset = avAsset else {
                    continuation.resume(throwing: NSError(
                        domain: "AddMoveViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No asset returned"]
                    ))
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    private func retryAVAssetCreation(from asset: PHAsset, originalError: NSError) async throws -> AVAsset {
        // Basic retry mechanism for iCloud downloads
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        return try await attemptAVAssetCreation(from: asset)
    }

    private func loadAVAssetDirectlyFromPhotosPickerItem(_ item: PhotosPickerItem) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                Task {
                    switch result {
                    case .success(let data):
                        guard let videoData = data else {
                            continuation.resume(throwing: NSError(
                                domain: "AddMoveViewModel",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No video data received"]
                            ))
                            return
                        }

                        do {
                            // Create a temporary file URL for the video data
                            let tempDirectory = FileManager.default.temporaryDirectory
                            let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mov")

                            // Write the data to a temporary file
                            try videoData.write(to: tempURL)

                            // Create AVAsset from the temporary file
                            let asset = AVURLAsset(url: tempURL)
                            continuation.resume(returning: asset)

                        } catch {
                            continuation.resume(throwing: error)
                        }

                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func extractFilename(from asset: PHAsset) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first(where: { $0.type == .video }) {
                continuation.resume(returning: resource.originalFilename)
            } else {
                continuation.resume(returning: "Video")
            }
        }
    }
}

// MARK: - Extensions
extension AddMoveViewModel {
    func copyVideoToBreakDex(from fileURL: URL) async throws -> PHAsset {
        // This method should be implemented by the album manager
        fatalError("copyVideoToBreakDex(from:) should be implemented by the album manager")
    }
}

protocol BreakDexAlbumManagerProtocol {
    func copyVideoToBreakDex(identifier: String) async throws -> PHAsset
    func copyVideoToBreakDex(_ asset: PHAsset) async throws -> PHAsset
    func copyVideoToBreakDex(from fileURL: URL) async throws -> PHAsset
}

extension BreakDexAlbumManager: BreakDexAlbumManagerProtocol {
    func copyVideoToBreakDex(identifier: String) async throws -> PHAsset {
        let originalAsset = try await loadAsset(from: identifier) // get the original PHAsset
        return try await copyVideoToBreakDex(originalAsset) // use BreakDexAlbumManager to copy it to the album
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

