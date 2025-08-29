
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
        print("DEBUG: MediaManager.loadVideo called with URL: \(url)")
        print("DEBUG: File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        // IMMEDIATELY update to loading state - no delay!
        self.status = .loading(progress: 0.1, status: "Preparing video...", eta: nil)
        print("DEBUG: MediaManager status IMMEDIATELY set to loading")
        
        loadingStartTime = Date()
        
        // Start progress simulation timer
        startProgressTimer()

        DispatchQueue.global(qos: .userInitiated).async {
            // Verify file exists first
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("DEBUG: File does not exist at path: \(url.path)")
                DispatchQueue.main.async {
                    self.stopProgressTimer()
                    self.status = .failed(error: NSError(domain: "MediaManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found at: \(url.path)"]))
                }
                return
            }
            
            let asset = AVAsset(url: url)
            let assetKey = url.absoluteString as NSString

            // Check cache first
            if let cachedAsset = self.assetCache.object(forKey: assetKey) {
                DispatchQueue.main.async {
                    self.stopProgressTimer()
                    self.status = .loaded(asset: cachedAsset, url: url)
                }
                return
            }
            
            // Update progress for asset initialization
            DispatchQueue.main.async {
                self.status = .loading(progress: 0.3, status: "Loading video properties...", eta: self.calculateETA(currentProgress: 0.3))
            }
            
            // Load asset properties asynchronously
            asset.loadValuesAsynchronously(forKeys: ["playable", "duration", "tracks"]) {
                var error: NSError?
                let playableStatus = asset.statusOfValue(forKey: "playable", error: &error)
                let durationStatus = asset.statusOfValue(forKey: "duration", error: &error)
                let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &error)
                
                DispatchQueue.main.async {
                    if playableStatus == .loaded && durationStatus == .loaded && tracksStatus == .loaded {
                        self.status = .loading(progress: 0.8, status: "Finalizing...", eta: self.calculateETA(currentProgress: 0.8))
                        
                        // Cache the asset
                        self.assetCache.setObject(asset, forKey: assetKey)
                        
                        // Complete loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.stopProgressTimer()
                            print("DEBUG: 🎬 MediaManager setting status to .loaded with URL: \(url)")
                            self.status = .loaded(asset: asset, url: url)
                            print("DEBUG: 🎬 MediaManager status set to: \(self.status)")
                        }
                    } else {
                        self.stopProgressTimer()
                        let failureError = error ?? NSError(domain: "MediaManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video properties"])
                        self.status = .failed(error: failureError)
                    }
                }
            }
        }
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if case .loading(let currentProgress, let status, _) = self.status {
                // More aggressive progress for better UX
                let increment = Double.random(in: 0.01...0.03) // Faster progress
                let newProgress = min(currentProgress + increment, 0.90) // Cap at 90% until actual completion
                
                DispatchQueue.main.async {
                    let eta = self.calculateETA(currentProgress: newProgress)
                    self.status = .loading(progress: newProgress, status: status, eta: eta)
                    print("DEBUG: ⏱️ Progress updated: \(Int(newProgress * 100))%, ETA: \(eta ?? "nil")")
                }
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func calculateETA(currentProgress: Double) -> String? {
        guard let startTime = loadingStartTime, currentProgress > 0.1 else { return nil }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / currentProgress
        let remaining = estimatedTotal - elapsed
        
        if remaining < 1 {
            return "< 1s"
        } else if remaining < 60 {
            return "\(Int(remaining))s"
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "\(minutes)m \(seconds)s"
        }
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
        VStack {
            // Add accessibility identifiers for testing
            switch currentState {
            case .ready:
                VStack(spacing: 12) {
                    Button("Select a Clip") {
                        isPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("SelectClipButton")
                    
                    Text("Supports .mp4, .mov files")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("SupportText")
                    
                    // Debug buttons for testing
                    // #if DEBUG
                    // VStack(spacing: 8) {
                    //     Button("🔍 Test Loading State") {
                    //         mediaManager.status = .loading(progress: 0.5, status: "Testing...", eta: "2s")
                    //     }
                    //     .buttonStyle(.bordered)
                    //     .font(.caption)
                        
                    //     Button("🔍 Test Preview State") {
                    //         // Create a dummy URL for testing
                    //         let testURL = URL(fileURLWithPath: "/tmp/test.mp4")
                    //         let testAsset = AVAsset(url: testURL)
                    //         mediaManager.status = .loaded(asset: testAsset, url: testURL)
                    //     }
                    //     .buttonStyle(.bordered)
                    //     .font(.caption)
                    // }
                    // .accessibilityIdentifier("DebugButtons")
                    // #endif
                    
                    // Debug info for testing
                    // #if DEBUG
                    // Text("State: Ready | Manager: \(mediaManagerStatusText)")
                    //     .font(.caption)
                    //     .foregroundColor(.gray)
                    //     .accessibilityIdentifier("DebugStateText")
                    // #endif
                }
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
                                        .font(.ibmPlexMono(size: 16, weight: .bold))
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
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text(status)
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text(getETAText(startTime: startTime, estimatedSize: estimatedSize))
                            .font(.ibmPlexMono(size: 12))
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
                                .font(.ibmPlexMono(size: 16, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .accessibilityIdentifier("ProgressPercentage")
                        }
                    }

                    VStack(spacing: 8) {
                        Text("Loading Video")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .accessibilityIdentifier("LoadingTitle")

                        Text(status)
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("LoadingStatus")
                        
                        if let eta = eta {
                            Text("ETA: \(eta)")
                                .font(.ibmPlexMono(size: 12))
                                .foregroundColor(.accent)
                                .padding(.top, 4)
                                .accessibilityIdentifier("LoadingETA")
                        } else {
                            // Always show some ETA, even if estimated
                            Text("ETA: Calculating...")
                                .font(.ibmPlexMono(size: 12))
                                .foregroundColor(.accent)
                                .padding(.top, 4)
                        }
                        
                        // Debug info for testing
                        #if DEBUG
                        Text("State: Loading (\(Int(progress * 100))%)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityIdentifier("DebugStateText")
                        #endif
                    }
                }
                .padding()
                .accessibilityIdentifier("LoadingState")

            case .previewing(let asset, let url):
                VStack(spacing: 16) {
                    Text("Selected File: \(url.lastPathComponent)")
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .foregroundColor(.textPrimary)
                    
                    CustomVideoPlayerView(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
                        .cornerRadius(12)
                        .frame(height: 300)

                    HStack(spacing: 16) {
                        Button("Change Video") { 
                            isPickerPresented = true 
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Trim") { 
                            currentState = .trimming(asset: asset, url: url)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Use Original") {
                            currentState = .naming(finalURL: url, name: "", originalAsset: asset, originalURL: url)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
            case .trimming(let asset, let url):
                VStack(spacing: 16) {
                    HStack {
                        Button("← Back") {
                            currentState = .previewing(asset: asset, url: url)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("Trim Video")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Button("← Back") {
                            currentState = .previewing(asset: asset, url: url)
                        }
                        .buttonStyle(.bordered)
                        .opacity(0)
                    }
                    .padding(.horizontal)
                    
                    VideoTrimmerView(asset: asset) { trimmedURL in
                        if let finalURL = trimmedURL {
                            currentState = .naming(finalURL: finalURL, name: "", originalAsset: asset, originalURL: url)
                        } else {
                            // If trimming is cancelled, go back to preview
                            currentState = .previewing(asset: asset, url: url)
                        }
                    }
                }

            case .naming(let finalURL, _, let originalAsset, let originalURL):
                VStack(spacing: 16) {
                    HStack {
                        Button("← Back") {
                            if let asset = originalAsset, let url = originalURL {
                                currentState = .previewing(asset: asset, url: url)
                            } else {
                                currentState = .ready
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("Name Your Move")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        // Edit video button
                        Button("Edit") {
                            if let asset = originalAsset, let url = originalURL {
                                currentState = .trimming(asset: asset, url: url)
                            }
                        }
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
                            .font(.ibmPlexMono(size: 16))

                        Button("Save Move") { 
                            saveMove(videoURL: finalURL, name: moveName) 
                        }
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
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Adding to your arsenal...")
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

            case .success(let message):
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text(message)
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                    Button("Add Another Move") {
                        currentState = .ready
                        moveName = ""
                    }
                }

            case .error(let message):
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                    
                    VStack(spacing: 8) {
                        Text("Something went wrong")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text(message)
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Try Again") {
                            moveName = ""
                            currentState = .ready
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Change Video") {
                            moveName = ""
                            isPickerPresented = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentState)
        .onReceive(mediaManager.$status) { status in
            print("DEBUG: 📺 MediaManager status changed to: \(status)")
            print("DEBUG: 📺 Current local state: \(currentState)")
            
            switch status {
            case .idle:
                print("DEBUG: 📺 Received .idle - ignoring to prevent state conflicts")
                // DO NOT change state on idle - let manual state management handle this
                
            case .loading(let progress, let status, let eta):
                print("DEBUG: 📺 MediaManager loading - updating UI")
                currentState = .loadingVideo(progress: progress, status: status, eta: eta)
                
            case .loaded(let asset, let url):
                print("DEBUG: 📺 MediaManager loaded - going to preview")
                currentState = .previewing(asset: asset, url: url)
                
            case .failed(let error):
                print("DEBUG: 📺 MediaManager failed - showing error")
                currentState = .error(message: error.localizedDescription)
            }
            
            print("DEBUG: 📺 Final state: \(currentState)")
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
            
            print("DEBUG: ✅ Video selected via onChange. URL: \(url)")
            isPickerPresented = false
            
            // Start the loading process for local processing phase
            currentState = .loadingVideo(progress: max(pickerDownloadProgress, 0.05), status: "Preparing video...", eta: "Calculating...")
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
                        newMove.learningState = "NEW"
                        
                        // Store the file path instead of the full video data for better performance
                        newMove.videoReference = finalVideoURL.path.data(using: .utf8)
                        
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
