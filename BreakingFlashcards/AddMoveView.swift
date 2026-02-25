
// In AddMoveView.swift
import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import Combine
import Photos

// MARK: - MediaManager
class MediaManager: ObservableObject {
    static let shared = MediaManager()
    private var assetCache = NSCache<NSString, AVAsset>()
    private var progressTimer: Timer?
    private var loadingStartTime: Date?

    enum MediaStatus {
        case idle
        case loading(progress: Double, status: String, eta: String?)
        case loaded(asset: AVAsset, url: URL)
        case failed(error: Error)
    }

    @Published var status: MediaStatus = .idle

    private init() {
        // Configure cache limits for better memory management
        assetCache.countLimit = 10
        assetCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func loadVideo(from url: URL) {
        // Gate: file must exist
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.status = .failed(error: NSError(domain: "MediaManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found"]))
            return
        }

        let assetKey = url.absoluteString as NSString

        // Always show the pipeline — every stage visible
        self.status = .loading(progress: 0.0, status: "Creating asset...", eta: nil)
        loadingStartTime = Date()

        let asset = AVURLAsset(url: url)

        // Cache hit — still show pipeline, just faster
        if let cachedAsset = self.assetCache.object(forKey: assetKey) {
            self.status = .loading(progress: 0.3, status: "Loading from cache...", eta: nil)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.status = .loading(progress: 0.7, status: "Restoring asset...", eta: nil)
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.status = .loading(progress: 1.0, status: "Ready", eta: nil)
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.status = .loaded(asset: cachedAsset, url: url)
            }
            return
        }

        // Full pipeline with 90s timeout for edge/cellular resilience
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await self.loadPipeline(asset: asset, url: url, cacheKey: assetKey)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 90_000_000_000)
                        throw NSError(domain: "MediaManager", code: -10,
                            userInfo: [NSLocalizedDescriptionKey: "Video took too long to load. The file may be corrupt or too large to process."])
                    }
                    // First to finish wins — if timeout fires first, pipeline is cancelled
                    try await group.next()
                    group.cancelAll()
                }
            } catch is CancellationError {
                // Task was cancelled (e.g. view disappeared) — don't show an error
            } catch {
                await MainActor.run {
                    self.status = .failed(error: error)
                }
            }
        }
    }
    
    private func loadPipeline(asset: AVURLAsset, url: URL, cacheKey: NSString) async throws {
        // Stage 1: Load playable
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.15, status: "Reading file header...", eta: nil)
        }
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            await MainActor.run {
                self.status = .failed(error: NSError(domain: "MediaManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "File is not playable"]))
            }
            return
        }

        // Stage 2: Load duration
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.35, status: "Loading duration...", eta: nil)
        }
        let duration = try await asset.load(.duration)

        // Stage 3: Load tracks
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.55, status: "Loading video tracks...", eta: nil)
        }
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else {
            await MainActor.run {
                self.status = .failed(error: NSError(domain: "MediaManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No video tracks found"]))
            }
            return
        }

        // Stage 4: Load track properties (natural size, frame rate)
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.70, status: "Reading track metadata...", eta: nil)
        }
        let naturalSize = try await tracks[0].load(.naturalSize)
        let _ = try await tracks[0].load(.nominalFrameRate)

        // Stage 5: Load audio tracks
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.85, status: "Loading audio tracks...", eta: nil)
        }
        let _ = try? await asset.loadTracks(withMediaType: .audio)

        // Stage 6: Cache and finish
        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.95, status: "Caching asset...", eta: nil)
        }
        self.assetCache.setObject(asset, forKey: cacheKey)

        try Task.checkCancellation()
        await MainActor.run {
            let durationText = String(format: "%.1fs", duration.seconds)
            self.status = .loading(progress: 1.0, status: "Ready — \(durationText) • \(Int(naturalSize.width))x\(Int(naturalSize.height))", eta: nil)
        }

        // Brief hold at 100% so the user sees the final stats — use try (not try?) so cancellation propagates
        try await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            self.status = .loaded(asset: asset, url: url)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

struct AddMoveView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var mediaManager = MediaManager.shared

    enum AddMoveState: Equatable {
        case ready
        case downloadingFromiCloud(status: String, startTime: Date, estimatedSize: Int64?, progress: Double?)
        case loadingVideo(progress: Double, status: String, eta: String?)
        case previewing(asset: AVAsset, url: URL)
        case trimming(asset: AVAsset, url: URL)
        case naming(finalURL: URL, name: String, originalAsset: AVAsset?, originalURL: URL?)
        case saving
        case success(message: String)
        case error(message: String)
    }

    @State private var currentState: AddMoveState = .ready
    @State private var isPickerPresented = false
    @State private var moveName: String = ""
    @State private var etaUpdateTimer: Timer?
    @State private var selectedVideoURL: URL?
    @State private var pickerDownloadProgress: Double = 0
    @State private var pickerDownloadStatus: String? = nil
    @State private var pickerDownloadStart: Date? = nil
    
    private var mediaManagerStatusText: String {
        switch mediaManager.status {
        case .idle: return "idle"
        case .loading(let progress, _, _): return "loading(\(Int(progress * 100))%)"
        case .loaded: return "loaded"
        case .failed: return "failed"
        }
    }
    
    private func estimateInitialDownloadTime(elapsed: TimeInterval) -> TimeInterval {
        // More realistic ETA estimates based on actual iCloud download behavior
        if elapsed < 5 {
            // Very early - give conservative but realistic estimate for typical 200MB+ videos
            return 180 // 3 minutes for typical videos (more realistic for iCloud)
        } else if elapsed < 15 {
            // Adjust based on how long it's already taken - if still downloading after 15s, it's slow
            return max(120, 240 - elapsed) // 2-4 minutes range
        } else if elapsed < 45 {
            // Taking longer than expected, give more realistic estimate
            return max(180, 360 - elapsed) // 3-6 minutes for larger files
        } else if elapsed < 120 {
            // This is taking a very long time - large file or slow connection
            return max(240, 600 - elapsed) // 4-10 minutes
        } else {
            // Very slow connection or very large file
            return max(300, 900 - elapsed) // 5-15 minutes
        }
    }
    
    private func estimateDownloadTime(for fileSize: Int64, elapsed: TimeInterval) -> TimeInterval {
        // More realistic iCloud download speed estimates
        let fileSizeMB = Double(fileSize) / (1024 * 1024)
        
        if elapsed < 10 {
            // Not enough data yet, use conservative estimate based on typical iCloud speeds
            // iCloud is often slower than direct downloads: 0.2-2 MB/s is more realistic
            return fileSizeMB * 3.0 // ~0.33 MB/s conservative estimate
        }
        
        // Use actual elapsed time to estimate speed, but be realistic about iCloud limitations
        let observedSpeedMBps = fileSizeMB / elapsed
        
        // Cap the speed estimates to realistic iCloud ranges
        let estimatedSpeedMBps = max(0.1, min(3.0, observedSpeedMBps)) // 0.1-3 MB/s range
        
        let estimatedTotal = fileSizeMB / estimatedSpeedMBps
        
        // Add some buffer for iCloud variability (20% extra time)
        return estimatedTotal * 1.2
    }
    
    private func getETAText(startTime: Date, estimatedSize: Int64?) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        
        if let estimatedSize = estimatedSize, elapsed > 5 {
            // Use actual data for more accurate estimate
            let estimatedTotal = estimateDownloadTime(for: estimatedSize, elapsed: elapsed)
            let remaining = max(0, estimatedTotal - elapsed)
            return "ETA: \(formatTime(remaining))"
        } else {
            // Immediate conservative estimate based on typical video sizes
            let conservativeETA = estimateInitialDownloadTime(elapsed: elapsed)
            return "ETA: \(formatTime(conservativeETA))"
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack {
                switch currentState {
            case .ready:
                VStack(spacing: 12) {
                    Button("Select a Clip") {
                        isPickerPresented = true
                    }
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    .textCase(.uppercase)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("SelectClipButton")

                    Text("Supports .mp4, .mov files")
                        .font(.ibmPlexMono(size: 20))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("SupportText")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .accessibilityIdentifier("ReadyState")

            case .downloadingFromiCloud(let status, let startTime, let estimatedSize, let progress):
                VStack(spacing: 20) {
                    // iCloud download indicator with real progress
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 48))
                            .foregroundColor(.accent)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                        
                        if let progress = progress {
                            // Show actual progress
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color.accent, lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.3), value: progress)

                                VStack {
                                    Text("\(Int(progress * 100))%")
                                        .font(.ibmPlexMono(size: 20, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                }
                            }
                        } else {
                            // Fallback to indeterminate progress
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("Downloading from iCloud")
                            .font(.ibmPlexMono(size: 23, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text(status)
                            .font(.ibmPlexMono(size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text(getETAText(startTime: startTime, estimatedSize: estimatedSize))
                            .font(.ibmPlexMono(size: 20))
                            .foregroundColor(.accent)
                            .padding(.top, 4)
                        
                        // Debug info for testing
                        #if DEBUG
                        Text("State: Downloading from iCloud")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityIdentifier("DebugStateText")
                        #endif
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .accessibilityIdentifier("iCloudDownloadState")
                .onAppear {
                    // Start timer to update ETA and progress every 0.5 seconds
                    etaUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        // Force UI refresh by triggering a state change with updated progress
                        if case .downloadingFromiCloud(let status, let startTime, let estimatedSize, let currentProgress) = currentState {
                            let elapsed = Date().timeIntervalSince(startTime)
                            let newProgress = min(0.95, elapsed / 30.0) // Estimate based on 30-second typical download
                            currentState = .downloadingFromiCloud(status: status, startTime: startTime, estimatedSize: estimatedSize, progress: newProgress)
                        }
                    }
                }
                .onDisappear {
                    etaUpdateTimer?.invalidate()
                    etaUpdateTimer = nil
                }

            case .loadingVideo(let progress, let status, let eta):
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            .frame(width: 64, height: 64)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                            .animation(AppMotion.springQuick, value: progress)

                        Text("\(Int(progress * 100))%")
                            .font(.ibmPlexMono(size: 23, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .accessibilityIdentifier("ProgressPercentage")
                    }

                    VStack(spacing: 6) {
                        Text(status)
                            .font(.ibmPlexMono(size: 18))
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("LoadingStatus")

                        if let eta = eta {
                            Text(eta)
                                .font(.ibmPlexMono(size: 15))
                                .foregroundColor(.accent)
                                .accessibilityIdentifier("LoadingETA")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .accessibilityIdentifier("LoadingState")

            case .previewing(let asset, let url):
                VStack(spacing: 16) {
                    Text("Selected File: \(url.lastPathComponent)")
                        .font(.ibmPlexMono(size: 23, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    CustomVideoPlayerView(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
                        .cornerRadius(12)
                        .frame(height: 300)

                    HStack(spacing: 16) {
                        Button("Change Video") {
                            isPickerPresented = true
                        }
                        .font(.ibmPlexMono(size: 18))
                        .buttonStyle(.bordered)

                        Button("Edit Video") {
                            currentState = .trimming(asset: asset, url: url)
                        }
                        .font(.ibmPlexMono(size: 18))
                        .buttonStyle(.bordered)

                        Button("Use Original") {
                            currentState = .naming(finalURL: url, name: "", originalAsset: asset, originalURL: url)
                        }
                        .font(.ibmPlexMono(size: 20, weight: .semibold))
                        .textCase(.uppercase)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

            case .trimming(let asset, let url):
                VideoEditorView(asset: asset) { editedURL in
                    if let finalURL = editedURL {
                        currentState = .naming(finalURL: finalURL, name: "", originalAsset: asset, originalURL: url)
                    } else {
                        currentState = .previewing(asset: asset, url: url)
                    }
                }

            case .naming(let finalURL, _, let originalAsset, let originalURL):
                VStack(spacing: 16) {
                    HStack {
                        Button("← Back") {
                            if let asset = originalAsset, let url = originalURL {
                                currentState = .previewing(asset: asset, url: url)
                            } else {
                                isPickerPresented = true
                            }
                        }
                        .font(.ibmPlexMono(size: 18))
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("Name Your Move")
                            .font(.ibmPlexMono(size: 23, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        // Edit video button
                        Button("Edit") {
                            if let asset = originalAsset, let url = originalURL {
                                currentState = .trimming(asset: asset, url: url)
                            }
                        }
                        .font(.ibmPlexMono(size: 18))
                        .buttonStyle(.bordered)
                        .disabled(originalAsset == nil)
                    }
                    .padding(.horizontal)
                    
                    CustomVideoPlayerView(url: finalURL)
                        .cornerRadius(12)
                        .frame(height: 300)

                    VStack(spacing: 12) {
                        TextField("Enter move name...", text: $moveName)
                            .padding(12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .font(.ibmPlexMono(size: 20))

                        Button("Save Move") {
                            saveMove(videoURL: finalURL, name: moveName)
                        }
                        .font(.ibmPlexMono(size: 20, weight: .semibold))
                        .textCase(.uppercase)
                        .buttonStyle(.borderedProminent)
                        .disabled(moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()

            case .saving:
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                    
                    VStack(spacing: 8) {
                        Text("Saving Move...")
                            .font(.ibmPlexMono(size: 23, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Adding to your arsenal...")
                            .font(.ibmPlexMono(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success(let message):
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text(message)
                        .font(.ibmPlexMono(size: 23, weight: .bold))
                    Button("Add Another Move") {
                        currentState = .ready
                        moveName = ""
                    }
                    .font(.ibmPlexMono(size: 20, weight: .semibold))
                    .textCase(.uppercase)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .error(let message):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                    
                    VStack(spacing: 8) {
                        Text("Something went wrong")
                            .font(.ibmPlexMono(size: 23, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text(message)
                            .font(.ibmPlexMono(size: 18))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Try Again") {
                            moveName = ""
                            currentState = .ready
                        }
                        .font(.ibmPlexMono(size: 20, weight: .semibold))
                        .textCase(.uppercase)
                        .buttonStyle(.borderedProminent)

                        Button("Change Video") {
                            moveName = ""
                            currentState = .ready
                            isPickerPresented = true
                        }
                        .font(.ibmPlexMono(size: 18))
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        }
        .animation(AppMotion.easeState, value: currentState)
        .onReceive(mediaManager.$status) { status in
            switch status {
            case .idle:
                break // Don't reset — let manual state management handle this
            case .loading(let progress, let statusText, let eta):
                currentState = .loadingVideo(progress: progress, status: statusText, eta: eta)
            case .loaded(let asset, let url):
                currentState = .previewing(asset: asset, url: url)
            case .failed(let error):
                currentState = .error(message: error.localizedDescription)
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoPickerSheet(selectedURL: $selectedVideoURL, downloadProgress: $pickerDownloadProgress, downloadStatus: $pickerDownloadStatus, downloadStart: $pickerDownloadStart)
        }
        .onChange(of: pickerDownloadProgress) { progress in
            // When the picker reports download progress (iCloud), show unified loading with ETA
            guard progress > 0 else { return }
            let status = pickerDownloadStatus ?? "Downloading from Photos..."
            if let start = pickerDownloadStart, progress > 0, progress < 0.999 {
                let elapsed = Date().timeIntervalSince(start)
                let estimatedTotal = elapsed / max(progress, 0.0001)
                let remaining = max(0, estimatedTotal - elapsed)
                let eta = formatTime(remaining)
                currentState = .loadingVideo(progress: min(progress, 0.95), status: status, eta: eta)
            } else {
                currentState = .loadingVideo(progress: min(progress, 0.95), status: status, eta: "Calculating...")
            }
        }
        .onChange(of: selectedVideoURL) { newURL in
            guard let url = newURL else { return }
            isPickerPresented = false
            // Let MediaManager drive state via .onReceive — no manual state set here
            mediaManager.loadVideo(from: url)
        }
    }

    private func saveMove(videoURL: URL, name: String) {
        currentState = .saving
        
        // Perform the heavy operations on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Validate video file exists and is readable
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                DispatchQueue.main.async {
                    self.currentState = .error(message: "Video file not found. Please try again.")
                }
                return
            }
            
            // Create a persistent file path in the documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let movesDirectory = documentsDirectory.appendingPathComponent("Moves", isDirectory: true)
            
            // Ensure the Moves directory exists
            try? FileManager.default.createDirectory(at: movesDirectory, withIntermediateDirectories: true)
            
            let fileName = "\(UUID().uuidString).mp4"
            let finalVideoURL = movesDirectory.appendingPathComponent(fileName)
            
            do {
                // Copy the video to the persistent location
                if FileManager.default.fileExists(atPath: finalVideoURL.path) {
                    try FileManager.default.removeItem(at: finalVideoURL)
                }
                try FileManager.default.copyItem(at: videoURL, to: finalVideoURL)
                
                // Save to Core Data on the main context
                DispatchQueue.main.async {
                    self.viewContext.perform {
                        let newMove = Move(context: self.viewContext)
                        newMove.id = UUID()
                        newMove.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Move" : name.trimmingCharacters(in: .whitespacesAndNewlines)
                        newMove.createdAt = Date()
                        newMove.learningState = LearningState.newState.rawValue
                        
                        // Store relative path so it survives container UUID rotation
                        let relativePath = "Moves/\(fileName)"
                        newMove.videoReference = relativePath.data(using: .utf8)
                        
                        do {
                            try self.viewContext.save()
                            DispatchQueue.main.async {
                                self.currentState = .success(message: "Move '\(newMove.name ?? "Untitled")' saved!")
                                // Clean up temporary file if it's different from the final location
                                if videoURL != finalVideoURL {
                                    try? FileManager.default.removeItem(at: videoURL)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.currentState = .error(message: "Failed to save move to database: \(error.localizedDescription)")
                                // Clean up the copied file if save failed
                                try? FileManager.default.removeItem(at: finalVideoURL)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentState = .error(message: "Failed to save video file: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct VideoPickerSheet: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Binding var downloadProgress: Double
    @Binding var downloadStatus: String?
    @Binding var downloadStart: Date?

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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerSheet

        init(_ parent: VideoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            // If we can get a PHAsset, use PHAssetResourceManager for accurate progress
            if let assetId = result.assetIdentifier,
               let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {

                // Choose the best video resource
                let resources = PHAssetResource.assetResources(for: asset)
                guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video }) ?? resources.first else {
                    return
                }

                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let ext = (videoResource.originalFilename as NSString).pathExtension
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? ".mov" : "." + ext))

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                options.progressHandler = { [weak self] progress in
                    DispatchQueue.main.async {
                        if self?.parent.downloadStart == nil { self?.parent.downloadStart = Date() }
                        self?.parent.downloadProgress = progress
                        self?.parent.downloadStatus = progress < 1.0 ? "Downloading from Photos..." : "Finalizing..."
                    }
                }

                parent.downloadStart = Date()
                parent.downloadStatus = "Downloading from Photos..."
                parent.downloadProgress = 0.01

                PHAssetResourceManager.default().writeData(for: videoResource, toFile: destinationURL, options: options) { [weak self] error in
                    if let error = error {
                        print("DEBUG: Failed to write asset data: \(error)")
                        return
                    }
                    DispatchQueue.main.async {
                        self?.parent.downloadProgress = 1.0
                        self?.parent.downloadStatus = "Processing..."
                        self?.parent.selectedURL = destinationURL
                    }
                }
                return
            }

            // Fallback: no PHAsset available; use loadFileRepresentation (likely local file)
            let provider = result.itemProvider
            guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { return }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                if let error = error { print("DEBUG: Error loading file representation: \(error)"); return }
                guard let url = url else { return }

                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "." + url.pathExtension)

                do {
                    if fileManager.fileExists(atPath: destinationURL.path) { try fileManager.removeItem(at: destinationURL) }
                    try fileManager.copyItem(at: url, to: destinationURL)
                    DispatchQueue.main.async {
                        self?.parent.selectedURL = destinationURL
                    }
                } catch {
                    print("DEBUG: File copy failed: \(error)")
                }
            }
        }
    }
}
