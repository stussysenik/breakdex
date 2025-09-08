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
            print("🔄 STATE CHANGE: \(oldValue) → \(state)")
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
                print("   ⚠️ Already processing a video (state: \(state)), skipping handleSelection()")
                return
            case .previewing:
                print("   🔄 User tapped 'Change Video' from previewing state - allowing new selection")
                // Continue to handleSelection for "Change Video" functionality
            default:
                break
            }

            print("   - Triggering handleSelection()...")
            Task { await handleSelection() }
        }
    }
    @Published var moveName: String = ""
    @Published var selectedFilename: String? = nil
    
    let viewContext: NSManagedObjectContext
    
    private var currentPhotosIdentifier: String?
    private var currentProcessingItemHash: Int?
    private var cancellables = Set<AnyCancellable>()
    private let albumManager: BreakDexAlbumManagerProtocol // dependency Injection for BreakDexAlbumManager
    
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
                    // Only update state if we're still in loading state (not previewing)
                    if case .loading = self.state {
                        self.state = .loading(progress: 0.6, status: "Extracting video metadata...")
                    }
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
    
    private func loadAVAssetDirectlyFromPhotosPickerItem(_ item: PhotosPickerItem) async throws -> AVAsset {
        print("   🎬 Loading AVAsset directly from PhotosPickerItem...")

        return try await withCheckedThrowingContinuation { continuation in
            item.loadTransferable(type: Data.self) { result in
                Task { // Ensure we're on a background thread for file operations
                    switch result {
                    case .success(let data):
                        print("   📊 Successfully loaded transferable data")

                        guard let videoData = data else {
                            print("   ❌ No video data received")
                            continuation.resume(throwing: NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video data received"]))
                            return
                        }

                        // Calculate data size for better feedback
                        let dataSizeMB = Double(videoData.count) / (1024.0 * 1024.0)
                        let sizeDescription = dataSizeMB > 100.0 ? ">100MB" : String(format: "%.1fMB", dataSizeMB)

                        print("   📊 Video data size: \(sizeDescription) (\(videoData.count) bytes)")

                        // Update progress for data validation with size info
                        await MainActor.run {
                            let sizeMessage = dataSizeMB > 50.0
                                ? "Validating \(sizeDescription) video data... (large file detected)"
                                : "Validating video data..."
                            self.state = .loading(progress: 0.4, status: sizeMessage)
                        }

                        // Create a temporary file URL for the video data
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let tempURL = tempDirectory.appendingPathComponent("temp_video_\(UUID().uuidString).mov")

                        do {
                            // Update progress before file writing with size context
                            await MainActor.run {
                                let writeMessage = dataSizeMB > 50.0
                                    ? "Writing \(sizeDescription) video file... (may take a moment)"
                                    : "Writing video to temporary file..."
                                self.state = .loading(progress: 0.5, status: writeMessage)
                            }

                            // For very large files, add intermediate progress updates
                            if dataSizeMB > 100.0 {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
                                    self.state = .loading(progress: 0.55, status: "Writing large video file... (25% complete)")
                                }
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s pause
                                    self.state = .loading(progress: 0.57, status: "Writing large video file... (50% complete)")
                                }
                            }

                            // Write the data to a temporary file
                            try videoData.write(to: tempURL)
                            print("   💾 Wrote video data to temporary file: \(tempURL)")

                            // Update progress for AVAsset creation
                            await MainActor.run {
                                self.state = .loading(progress: 0.6, status: "Creating video asset from file...")
                            }

                            // Create AVAsset from the temporary file URL
                            let asset = AVURLAsset(url: tempURL)
                            print("   🎬 Created AVAsset from temporary file")

                            continuation.resume(returning: asset)

                        } catch {
                            print("   ❌ Failed to write video data to file: \(error)")
                            continuation.resume(throwing: NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process video data"]))
                        }

                    case .failure(let error):
                        print("   ❌ Failed to load transferable data: \(error)")
                        continuation.resume(throwing: NSError(domain: "AddMoveViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video from Photos"]))
                    }
                }
            }
        }
    }

    private func analyzeAssetProperties(_ asset: AVAsset) async -> (duration: Double, trackCount: Int, isLargeAsset: Bool) {
        do {
            let duration = try await asset.load(.duration).seconds
            let tracks = try await asset.load(.tracks)
            let isLarge = duration > 30.0 || tracks.count > 5 // Consider assets >30s or with >5 tracks as "large"
            return (duration, tracks.count, isLarge)
        } catch {
            logger.warning("Failed to load asset properties: \(error.localizedDescription)")
            return (0.0, 0, false)
        }
    }

    private func estimateLoadTime(_ duration: Double, _ isICloud: Bool) -> String {
        // Base time estimates based on video duration
        var baseTime: Double
        if duration <= 30.0 {
            baseTime = 8.0 // Short videos: 8 seconds
        } else if duration <= 60.0 {
            baseTime = 15.0 // Medium videos: 15 seconds
        } else if duration <= 300.0 { // 5 minutes
            baseTime = 30.0 + (duration - 60.0) * 0.1 // 30s base + 0.1s per second
        } else {
            baseTime = 60.0 + (duration - 300.0) * 0.05 // 1min base + 0.05s per second for very long videos
        }

        // Add iCloud overhead
        if isICloud {
            baseTime *= 2.0 // Double the time for iCloud downloads
        }

        // Format the estimate
        if baseTime < 60.0 {
            return "\(Int(baseTime)) seconds"
        } else {
            let minutes = Int(baseTime / 60.0)
            let seconds = Int(baseTime.truncatingRemainder(dividingBy: 60.0))
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes) minutes"
        }
    }

    private func analyzePHAssetProperties(_ asset: PHAsset) async -> (duration: Double, sizeDescription: String, isICloud: Bool, isLargeAsset: Bool) {
        await withCheckedContinuation { continuation in
            let resources = PHAssetResource.assetResources(for: asset)
            let duration = asset.duration
            let isICloud = asset.sourceType == .typeCloudShared || asset.location == nil

            // Estimate file size based on duration and media type
            var sizeDescription = "Unknown size"
            var estimatedSizeMB: Double = 0.0

            if let resource = resources.first {
                let fileSize = resource.value(forKey: "fileSize") as? Int64 ?? 0
                if fileSize > 0 {
                    estimatedSizeMB = Double(fileSize) / (1024.0 * 1024.0)
                    if estimatedSizeMB > 200.0 { // >200MB
                        sizeDescription = "Very large file (>200MB)"
                    } else if estimatedSizeMB > 100.0 { // >100MB
                        sizeDescription = "Large file (>100MB)"
                    } else if estimatedSizeMB > 50.0 { // >50MB
                        sizeDescription = "Medium file (50-100MB)"
                    } else {
                        sizeDescription = "Small file (<50MB)"
                    }
                } else {
                    // Estimate based on duration for iCloud assets or when fileSize is unavailable
                    // Rough estimate: 1080p video at 30fps is about 0.5MB per second
                    estimatedSizeMB = duration * 0.5 // Rough MB per second estimate

                    if duration > 300.0 { // >5 minutes
                        sizeDescription = "Very long video (estimated >150MB)"
                        estimatedSizeMB = max(estimatedSizeMB, 150.0)
                    } else if duration > 120.0 { // >2 minutes
                        sizeDescription = "Long video (estimated 60-150MB)"
                        estimatedSizeMB = max(estimatedSizeMB, 60.0)
                    } else if duration > 60.0 {
                        sizeDescription = "Medium video (estimated 30-60MB)"
                        estimatedSizeMB = max(estimatedSizeMB, 30.0)
                    } else if duration > 30.0 {
                        sizeDescription = "Medium video"
                    } else {
                        sizeDescription = "Short video"
                    }
                }
            }

            // Consider assets as "large" if they're long, big, or iCloud-based
            let isLarge = duration > 120.0 || estimatedSizeMB > 100.0 || isICloud
            continuation.resume(returning: (duration, sizeDescription, isICloud, isLarge))
        }
    }

    private func createAVAsset(from asset: PHAsset) async throws -> AVAsset {
        logger.debug("Creating AVAsset from PHAsset.")
        print("🔍 DEBUG: createAVAsset called")

        // First attempt with immediate response
        print("🔍 DEBUG: About to call attemptAVAssetCreation...")
        do {
            let result = try await attemptAVAssetCreation(from: asset)
            print("🔍 DEBUG: attemptAVAssetCreation succeeded")
            return result
        } catch let error as NSError where error.domain == "PHPhotosErrorDomain" && error.code == 3164 {
            // iCloud download failure - try retry mechanism
            logger.info("iCloud download failed, attempting retry mechanism...")
            print("🔍 DEBUG: iCloud download failed, attempting retry...")
            let result = try await retryAVAssetCreation(from: asset, originalError: error)
            print("🔍 DEBUG: retryAVAssetCreation succeeded")
            return result
        }
    }

    private func createAVAssetFromPHAsset(_ asset: PHAsset) async throws -> AVAsset {
        logger.debug("Creating AVAsset from PHAsset using standard PhotoKit")

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
                    continuation.resume(throwing: NSError(domain: "PhotoKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]))
                    return
                }

                guard let avAsset = avAsset else {
                    continuation.resume(throwing: NSError(domain: "PhotoKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "No asset returned"]))
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }


    private func attemptAVAssetCreation(from asset: PHAsset) async throws -> AVAsset {
        logger.debug("Attempting to create AVAsset from PHAsset with optimized options")

        return try await createAVAssetFromPHAsset(asset)
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
        guard duration > 0 else {
            return 100 * 1024 * 1024 // Assume 100MB if we can't get duration
        }
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
        guard case .naming(let photosIdentifier, let originalAsset, let trimmedAsset, let trimStartTime, let trimEndTime, let rotationQuarterTurns) = state else {
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

                let breakDexAsset: PHAsset

                // Check if we have a trimmed asset (exported video) or should use original
                if let trimmedAsset = trimmedAsset as? AVURLAsset,
                   trimmedAsset != originalAsset,
                   trimStartTime != 0.0 || trimEndTime != 0.0 {

                    // Copy the exported trimmed video to BreakDex
                    breakDexAsset = try await self.albumManager.copyVideoToBreakDex(from: trimmedAsset.url)

                    // For exported videos, reset trim times since the video is already trimmed
                    let finalTrimStartTime = 0.0
                    let finalTrimEndTime = 0.0

                    try await saveMoveToCoreData(
                        id: moveID,
                        name: name,
                        photosIdentifier: breakDexAsset.localIdentifier,
                        trimStartTime: finalTrimStartTime,
                        trimEndTime: finalTrimEndTime,
                        rotationQuarterTurns: rotationQuarterTurns
                    )

                } else {
                    // Copy the original video to BreakDex
                    breakDexAsset = try await self.albumManager.copyVideoToBreakDex(identifier: photosIdentifier)

                    // Keep original trim times for untrimmed videos
                    let finalTrimStartTime = trimStartTime ?? 0.0
                    let finalTrimEndTime = trimEndTime ?? 0.0

                    try await saveMoveToCoreData(
                        id: moveID,
                        name: name,
                        photosIdentifier: breakDexAsset.localIdentifier,
                        trimStartTime: finalTrimStartTime,
                        trimEndTime: finalTrimEndTime,
                        rotationQuarterTurns: rotationQuarterTurns
                    )
                }

                logger.info("Video copied to BreakDex album. New asset local identifier: \(breakDexAsset.localIdentifier)")

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
    
    private func saveMoveToCoreData(id: UUID, name: String, photosIdentifier: String, trimStartTime: Double, trimEndTime: Double, rotationQuarterTurns: Int) async throws {
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
            newMove.rotationQuarterTurns = Int16(rotationQuarterTurns)
            
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
    
    func getAssetForTrimming() async -> AVAsset? {
        print("getAssetForTrimming() called.")
        guard let item = selectedItem else {
            print("getAssetForTrimming: selectedItem is nil.")
            return nil
        }
        
        do {
            // Get the PHAsset
            guard let identifier = item.itemIdentifier else {
                print("getAssetForTrimming: item.itemIdentifier is nil.")
                return nil
            }
            let phAsset = try await loadAsset(from: identifier)
            
            // Get the AVAsset, this will handle iCloud downloads
            let avAsset = try await createAVAsset(from: phAsset)
            
            print("getAssetForTrimming: Successfully created AVAsset")
            return avAsset
            
        } catch {
            logger.error("Failed to get asset for trimming: \(error.localizedDescription)")
            print("getAssetForTrimming: failed with error: \(error.localizedDescription)")
            state = .error(message: "Failed to get video asset for trimming.", underlyingError: error.localizedDescription)
            return nil
        }
    }
    
    func getURLForTrimming() async -> URL? {
        print("getURLForTrimming() called.")
        guard let item = selectedItem else {
            print("getURLForTrimming: selectedItem is nil.")
            return nil
        }
        
        do {
            // Get the PHAsset
            guard let identifier = item.itemIdentifier else {
                print("getURLForTrimming: item.itemIdentifier is nil.")
                return nil
            }
            let phAsset = try await loadAsset(from: identifier)
            
            // Get the AVAsset, this will handle iCloud downloads
            let avAsset = try await createAVAsset(from: phAsset)
            print("getURLForTrimming: createAVAsset returned AVAsset: \(avAsset)")
            
            // Log preferredTransform
            if let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                if let preferredTransform = try? await videoTrack.load(.preferredTransform) {
                    print("getURLForTrimming: AVAsset preferredTransform: \(preferredTransform)")
                }
            } else {
                print("getURLForTrimming: No video track found in AVAsset.")
            }
            
            guard let urlAsset = avAsset as? AVURLAsset else {
                print("getURLForTrimming: Asset is not an AVURLAsset. Attempting export.")
                // If it's not a URL asset, we can try exporting it.
                let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetMediumQuality)
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
                exportSession?.outputURL = tempURL
                exportSession?.outputFileType = .mp4
                
                print("getURLForTrimming: Starting export session...")

                do {
                    // Use new iOS 18.0 export method
                    try await exportSession?.export(to: tempURL, as: .mp4)
                    print("getURLForTrimming: Successfully exported to temporary URL: \(tempURL)")
                    return tempURL
                } catch {
                    print("getURLForTrimming: Failed to export asset. Error: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // If we have a URL asset, copy it to a temporary location
            print("getURLForTrimming: Asset is an AVURLAsset. Original URL: \(urlAsset.url)")
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension(urlAsset.url.pathExtension)
            
            do {
                try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                print("getURLForTrimming: Successfully copied to temporary URL: \(tempURL)")
                return tempURL
            } catch {
                print("getURLForTrimming: Failed to copy AVURLAsset to temporary location: \(error.localizedDescription)")
                return nil
            }
            
        } catch {
            logger.error("Failed to get URL for trimming: \(error.localizedDescription)")
            print("getURLForTrimming: failed with error: \(error.localizedDescription)")
            state = .error(message: "Failed to get video URL for trimming.", underlyingError: error.localizedDescription)
            return nil
        }
    }
    
    func handleTrimmedVideo(url: URL?, rotationQuarterTurns: Int = 0) async {
        print("handleTrimmedVideo(url:) called with url: \(String(describing: url))")
        guard let url = url else {
            // User cancelled trimming
            print("handleTrimmedVideo: url is nil, user cancelled.")
            return
        }
        let asset = AVURLAsset(url: url)
        // NOTE: The trimmed video is a temporary file. The save functionality
        // will not work correctly as we don't have a photosIdentifier for this new asset.
        // This is a limitation of the current demo implementation.
        print("handleTrimmedVideo: transitioning to .naming state.")
        let duration = (try? await asset.load(.duration))?.seconds ?? 0
        state = .naming(photosIdentifier: "", originalAsset: asset, trimmedAsset: asset, trimStartTime: 0, trimEndTime: duration, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    func startTrimming(rotationQuarterTurns: Int = 0) {
        guard case .previewing(let asset, let identifier) = state else {
            logger.error("startTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Transitioning to .trimming state with rotationQuarterTurns: \(rotationQuarterTurns)")
        state = .trimming(asset: asset, photosIdentifier: identifier, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    func finishTrimming(with trimmerViewModel: TrimmerViewModel) {
        guard case .trimming(let asset, let identifier, let rotationQuarterTurns) = state, let identifier = identifier else {
            logger.error("finishTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Finishing trimming process with rotationQuarterTurns: \(rotationQuarterTurns)")
        let startTime = trimmerViewModel.startTime.seconds
        let endTime = trimmerViewModel.endTime.seconds
        // For now, we'll use the original asset as both original and trimmed
        // This will be updated when we get the actual trimmed asset from the export
        state = .naming(photosIdentifier: identifier, originalAsset: asset, trimmedAsset: asset, trimStartTime: startTime, trimEndTime: endTime, rotationQuarterTurns: rotationQuarterTurns)
        logger.info("Transitioned to .naming state after trimming.")
    }
    
    func cancelTrimming() {
        guard case .trimming(let asset, let identifier, _) = state else {
            logger.error("cancelTrimming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Cancelling trimming. Transitioning back to .previewing state.")
        state = .previewing(asset: asset, photosIdentifier: identifier)
    }

    func updateTrimmingRotation(rotationQuarterTurns: Int) {
        guard case .trimming(let asset, let identifier, _) = state else {
            logger.error("updateTrimmingRotation called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Updating trimming rotation to: \(rotationQuarterTurns)")
        state = .trimming(asset: asset, photosIdentifier: identifier, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    func cancelNaming() {
        guard case .naming(_, let originalAsset, let trimmedAsset, _, _, let rotationQuarterTurns) = state else {
            logger.error("cancelNaming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Cancelling naming. Transitioning back to .trimming state.")
        // Go back to trimming state to preserve rotation
        let assetToUse = trimmedAsset ?? originalAsset ?? originalAsset
        state = .trimming(asset: assetToUse!, photosIdentifier: nil, rotationQuarterTurns: rotationQuarterTurns)
    }
    
    func startNaming() {
        guard case .previewing(let asset, let identifier) = state else {
            logger.error("startNaming called in incorrect state: \(String(describing: self.state))")
            return
        }
        logger.info("Transitioning to .naming state.")
        state = .naming(photosIdentifier: identifier!, originalAsset: asset, trimmedAsset: nil, trimStartTime: nil, trimEndTime: nil, rotationQuarterTurns: 0)
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
        
        guard await isNetworkAvailable() else { // test basic internet connectivity
            logger.warning("No basic network connectivity")
            return false
        }
        
        guard let url = URL(string: "https://p23-sharedstreams.icloud.com") else {  // test connectivity to iCloud Photos
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
