
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
        assetCache.countLimit = 10
        assetCache.totalCostLimit = 100 * 1024 * 1024
    }

    func loadVideo(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.status = .failed(error: NSError(domain: "MediaManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video file not found"]))
            return
        }

        let assetKey = url.absoluteString as NSString
        self.status = .loading(progress: 0.0, status: "Creating asset...", eta: nil)
        loadingStartTime = Date()

        let asset = AVURLAsset(url: url)

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
                    try await group.next()
                    group.cancelAll()
                }
            } catch is CancellationError {
                // Task was cancelled — don't show an error
            } catch {
                await MainActor.run {
                    self.status = .failed(error: error)
                }
            }
        }
    }

    private func loadPipeline(asset: AVURLAsset, url: URL, cacheKey: NSString) async throws {
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

        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.35, status: "Loading duration...", eta: nil)
        }
        let duration = try await asset.load(.duration)

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

        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.70, status: "Reading track metadata...", eta: nil)
        }
        let naturalSize = try await tracks[0].load(.naturalSize)
        let _ = try await tracks[0].load(.nominalFrameRate)

        try Task.checkCancellation()
        await MainActor.run {
            self.status = .loading(progress: 0.85, status: "Loading audio tracks...", eta: nil)
        }
        let _ = try? await asset.loadTracks(withMediaType: .audio)

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
        if elapsed < 5 {
            return 180
        } else if elapsed < 15 {
            return max(120, 240 - elapsed)
        } else if elapsed < 45 {
            return max(180, 360 - elapsed)
        } else if elapsed < 120 {
            return max(240, 600 - elapsed)
        } else {
            return max(300, 900 - elapsed)
        }
    }

    private func estimateDownloadTime(for fileSize: Int64, elapsed: TimeInterval) -> TimeInterval {
        let fileSizeMB = Double(fileSize) / (1024 * 1024)

        if elapsed < 10 {
            return fileSizeMB * 3.0
        }

        let observedSpeedMBps = fileSizeMB / elapsed
        let estimatedSpeedMBps = max(0.1, min(3.0, observedSpeedMBps))
        let estimatedTotal = fileSizeMB / estimatedSpeedMBps
        return estimatedTotal * 1.2
    }

    private func getETAText(startTime: Date, estimatedSize: Int64?) -> String {
        let elapsed = Date().timeIntervalSince(startTime)

        if let estimatedSize = estimatedSize, elapsed > 5 {
            let estimatedTotal = estimateDownloadTime(for: estimatedSize, elapsed: elapsed)
            let remaining = max(0, estimatedTotal - elapsed)
            return "ETA: \(formatTime(remaining))"
        } else {
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
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()

                    VStack(spacing: Spacing.md) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)

                        Text("ADD A MOVE")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)

                        Text("Import a clip from your library")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)

                        Button(action: { isPickerPresented = true }) {
                            Text("SELECT CLIP")
                                .font(.ibmPlexMono(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: 280)
                                .frame(height: 52)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                        .padding(.top, Spacing.sm)
                        .accessibilityIdentifier("SelectClipButton")

                        Text("Supports .mp4, .mov files")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .accessibilityIdentifier("SupportText")
                    }

                    Spacer()
                    Spacer()
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .accessibilityIdentifier("ReadyState")

            case .downloadingFromiCloud(let status, let startTime, let estimatedSize, let progress):
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 48))
                            .foregroundColor(.accent)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeating)

                        if let progress = progress {
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

                                Text("\(Int(progress * 100))%")
                                    .font(.titleSmall)
                                    .foregroundColor(.textPrimary)
                            }
                        } else {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                        }
                    }

                    VStack(spacing: Spacing.sm) {
                        Text("Downloading from iCloud")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)

                        Text(status)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)

                        Text(getETAText(startTime: startTime, estimatedSize: estimatedSize))
                            .font(.bodyMedium)
                            .foregroundColor(.accent)
                            .padding(.top, Spacing.xs)

                        #if DEBUG
                        Text("State: Downloading from iCloud")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityIdentifier("DebugStateText")
                        #endif
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .accessibilityIdentifier("iCloudDownloadState")
                .onAppear {
                    etaUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        if case .downloadingFromiCloud(let status, let startTime, let estimatedSize, _) = currentState {
                            let elapsed = Date().timeIntervalSince(startTime)
                            let newProgress = min(0.95, elapsed / 30.0)
                            currentState = .downloadingFromiCloud(status: status, startTime: startTime, estimatedSize: estimatedSize, progress: newProgress)
                        }
                    }
                }
                .onDisappear {
                    etaUpdateTimer?.invalidate()
                    etaUpdateTimer = nil
                }

            case .loadingVideo(let progress, let status, let eta):
                VStack(spacing: Spacing.lg) {
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
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)
                            .accessibilityIdentifier("ProgressPercentage")
                    }

                    VStack(spacing: Spacing.sm) {
                        Text(status)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .accessibilityIdentifier("LoadingStatus")

                        if let eta = eta {
                            Text(eta)
                                .font(.bodySmall)
                                .foregroundColor(.accent)
                                .accessibilityIdentifier("LoadingETA")
                        }
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .accessibilityIdentifier("LoadingState")

            case .previewing(let asset, let url):
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Section label
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("PREVIEW")
                                .font(.caption)
                                .tracking(2)
                                .foregroundColor(.textSecondary)

                            Text("Ready to save")
                                .font(.titleSmall)
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.lg)

                        CustomVideoPlayerView(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .padding(.horizontal, Spacing.lg)

                        // Primary CTA
                        Button(action: {
                            currentState = .naming(finalURL: url, name: "", originalAsset: asset, originalURL: url)
                        }) {
                            Text("USE ORIGINAL")
                                .font(.ibmPlexMono(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Secondary pair
                        HStack(spacing: Spacing.md) {
                            Button(action: { isPickerPresented = true }) {
                                Text("CHANGE")
                                    .font(.ibmPlexMono(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.neutralFill)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }

                            Button(action: {
                                currentState = .trimming(asset: asset, url: url)
                            }) {
                                Text("EDIT")
                                    .font(.ibmPlexMono(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.neutralFill)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
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
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        HStack {
                            Button(action: {
                                if let asset = originalAsset, let url = originalURL {
                                    currentState = .previewing(asset: asset, url: url)
                                } else {
                                    isPickerPresented = true
                                }
                            }) {
                                Text("BACK")
                                    .font(.ibmPlexMono(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, Spacing.md)
                                    .frame(height: 44)
                                    .background(Color.neutralFill)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }

                            Spacer()

                            Button(action: {
                                if let asset = originalAsset, let url = originalURL {
                                    currentState = .trimming(asset: asset, url: url)
                                }
                            }) {
                                Text("EDIT")
                                    .font(.ibmPlexMono(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, Spacing.md)
                                    .frame(height: 44)
                                    .background(Color.neutralFill)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .disabled(originalAsset == nil)
                        }
                        .padding(.horizontal, Spacing.lg)

                        Text("Name Your Move")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)

                        CustomVideoPlayerView(url: finalURL)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .padding(.horizontal, Spacing.lg)

                        VStack(spacing: Spacing.md) {
                            TextField("Enter move name...", text: $moveName)
                                .padding(Spacing.md)
                                .background(Color.neutralFill)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                                .font(.bodyMedium)

                            Button(action: {
                                saveMove(videoURL: finalURL, name: moveName)
                            }) {
                                Text("SAVE MOVE")
                                    .font(.ibmPlexMono(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.neutralFill : Color.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .disabled(moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                    .padding(.top, Spacing.md)
                }

            case .saving:
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))

                    VStack(spacing: Spacing.sm) {
                        Text("Saving Move...")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)

                        Text("Adding to your arsenal...")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success(let message):
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.stateMastery)

                    Text(message)
                        .font(.titleSmall)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        currentState = .ready
                        moveName = ""
                    }) {
                        Text("ADD ANOTHER")
                            .font(.ibmPlexMono(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: 280)
                            .frame(height: 52)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .error(let message):
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.buttonAgain)

                    VStack(spacing: Spacing.sm) {
                        Text("Something went wrong")
                            .font(.titleSmall)
                            .foregroundColor(.textPrimary)

                        Text(message)
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }

                    HStack(spacing: Spacing.md) {
                        Button(action: {
                            moveName = ""
                            currentState = .ready
                        }) {
                            Text("TRY AGAIN")
                                .font(.ibmPlexMono(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }

                        Button(action: {
                            moveName = ""
                            currentState = .ready
                            isPickerPresented = true
                        }) {
                            Text("CHANGE")
                                .font(.ibmPlexMono(size: 14, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.neutralFill)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        }
        .animation(AppMotion.easeState, value: currentState)
        .onReceive(mediaManager.$status) { status in
            switch status {
            case .idle:
                break
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
            mediaManager.loadVideo(from: url)
        }
    }

    private func saveMove(videoURL: URL, name: String) {
        currentState = .saving

        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                DispatchQueue.main.async {
                    self.currentState = .error(message: "Video file not found. Please try again.")
                }
                return
            }

            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let movesDirectory = documentsDirectory.appendingPathComponent("Moves", isDirectory: true)
            try? FileManager.default.createDirectory(at: movesDirectory, withIntermediateDirectories: true)

            let fileName = "\(UUID().uuidString).mp4"
            let finalVideoURL = movesDirectory.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: finalVideoURL.path) {
                    try FileManager.default.removeItem(at: finalVideoURL)
                }
                try FileManager.default.copyItem(at: videoURL, to: finalVideoURL)

                DispatchQueue.main.async {
                    self.viewContext.perform {
                        let newMove = Move(context: self.viewContext)
                        newMove.id = UUID()
                        newMove.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Move" : name.trimmingCharacters(in: .whitespacesAndNewlines)
                        newMove.createdAt = Date()
                        newMove.learningState = LearningState.newState.rawValue

                        let relativePath = "Moves/\(fileName)"
                        newMove.videoReference = relativePath.data(using: .utf8)

                        do {
                            try self.viewContext.save()
                            DispatchQueue.main.async {
                                self.currentState = .success(message: "Move '\(newMove.name ?? "Untitled")' saved!")
                                if videoURL != finalVideoURL {
                                    try? FileManager.default.removeItem(at: videoURL)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.currentState = .error(message: "Failed to save move to database: \(error.localizedDescription)")
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

            if let assetId = result.assetIdentifier,
               let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {

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
