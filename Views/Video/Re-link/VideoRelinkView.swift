import SwiftUI
import AVKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct VideoRelinkView: View {
    enum ScreenState {
        case chooseSource
        case preview
        case trim
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let move: Move
    let onComplete: (URL?) -> Void
    
    @State private var screen: ScreenState = .chooseSource
    @State private var pickedURL: URL? = nil
    @State private var pickedAsset: AVAsset? = nil
    @State private var isPhotosPickerPresented = false
    @State private var isFilesPickerPresented = false
    @State private var errorText: String? = nil
    @State private var isTrimSheetPresented = false
    @State private var isAssetLoading = false

    init(move: Move, preselectedURL: URL? = nil, preselectedAsset: AVAsset? = nil, startOnTrim: Bool = false, onComplete: @escaping (URL?) -> Void) { // allow starting with a preselected URL/asset (e.g., after auto-rehydrate)
        self.move = move
        self.onComplete = onComplete
        _pickedURL = State(initialValue: preselectedURL)
        _pickedAsset = State(initialValue: preselectedAsset)
        _screen = State(initialValue: preselectedURL != nil ? (startOnTrim ? .preview : .preview) : .chooseSource)
        _isTrimSheetPresented = State(initialValue: startOnTrim)
    }

    private func loadAssetAsync(from url: URL) {
        isAssetLoading = true
        errorText = nil

        Task {
            do {
                // Create asset and wait for it to load basic properties
                let asset = AVURLAsset(url: url)
                _ = try await asset.load(.duration)
                _ = try await asset.load(.tracks)

                await MainActor.run {
                    self.pickedAsset = asset
                    self.pickedURL = url
                    self.isAssetLoading = false
                    self.screen = .preview
                }
            } catch {
                await MainActor.run {
                    self.errorText = "Failed to load video: \(error.localizedDescription)"
                    self.isAssetLoading = false
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isAssetLoading {
                    ZStack {
                        Color.black.opacity(0.8)
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading video...")
                                .font(.ibmPlexMono(size: 16, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    switch screen {
                    case .chooseSource:
                        chooseSourceView
                    case .preview:
                        previewView
                    case .trim:
                        previewView // show preview as background, sheet will overlay
                    }
                }
            }
            .navigationTitle("Relink Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onComplete(nil) }
                }
            }
        }
        .sheet(isPresented: $isPhotosPickerPresented) {
            RelinkPicker { result in
                switch result {
                case .success(let url):
                    self.loadAssetAsync(from: url)
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $isFilesPickerPresented) {
            FileRelinkPicker { picked in
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let ext = picked.pathExtension.isEmpty ? "mov" : picked.pathExtension
                let dest = documents.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
                do {
                    if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
                    try FileManager.default.copyItem(at: picked, to: dest)
                    self.loadAssetAsync(from: dest)
                } catch {
                    self.errorText = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $isTrimSheetPresented) {
            if let asset = pickedAsset {
                NavigationStack {
                    SimpleVideoTrimmerView(asset: asset) { trimmedURL in
                        isTrimSheetPresented = false
                        if let trimmedURL {
                            saveAndFinish(using: trimmedURL)
                        } else {
                            screen = .preview
                        }
                    }
                    .navigationTitle("Trim Video")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                isTrimSheetPresented = false
                                screen = .preview
                            }
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var chooseSourceView: some View {
        VStack(spacing: 24) {
            Text("Locate the correct video from Photos or Files.")
                .font(.ibmPlexMono(size: 14))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Pick From Photos") { isPhotosPickerPresented = true }
                    .buttonStyle(.borderedProminent)
                Button("Pick From Files") { isFilesPickerPresented = true }
                    .buttonStyle(.bordered)
            }
            
            if let errorText { Text(errorText).font(.caption).foregroundColor(.red).padding(.horizontal) }
            
            Spacer()
        }
        .padding()
    }
    
    private var previewView: some View {
        VStack(spacing: 16) {
            if let url = pickedURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 300)
                    .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                Button("Back") { screen = .chooseSource }
                    .buttonStyle(.bordered)
                Button("Trim") { isTrimSheetPresented = true }
                    .buttonStyle(.bordered)
                Button("Use Original") { saveAndFinish(using: pickedURL) }
                    .buttonStyle(.borderedProminent)
                    .disabled(pickedURL == nil)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var trimView: some View {
        VStack(spacing: 16) {
            if let asset = pickedAsset {
                SimpleVideoTrimmerView(asset: asset) { trimmed in
                    if let trimmed { saveAndFinish(using: trimmed) }
                    else { screen = .preview }
                }
            }
        }
        .padding()
    }
    
    private func saveAndFinish(using url: URL?) {
        guard let url else { return }
        
        Task {
            do {
                let newAssetIdentifier = try await PhotoKitService.shared.saveVideoToBreakDexAlbum(url)

                await viewContext.perform {
                    move.photosIdentifier = newAssetIdentifier
                    move.trimStartTime = 0.0
                    move.trimEndTime = 0.0
                    try? viewContext.save()
                }
                
                onComplete(nil)
            } catch {
                print("❌ Failed to relink video: \(error.localizedDescription)")
            }
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
            guard let result = results.first else { return }
            getVideoURL(from: result)
        }
        
        private func getVideoURL(from result: PHPickerResult) {
            let provider = result.itemProvider
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    if let error { DispatchQueue.main.async { self?.parent.onPick(.failure(error)) }; return }
                    guard let url else {
                        let err = NSError(domain: "RelinkPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get URL from file representation."])
                        DispatchQueue.main.async { self?.parent.onPick(.failure(err)) }
                        return
                    }
                    guard let newURL = self?.copyToSandbox(url: url) else {
                        let err = NSError(domain: "RelinkPicker", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to copy video to sandbox."])
                        DispatchQueue.main.async { self?.parent.onPick(.failure(err)) }
                        return
                    }
                    DispatchQueue.main.async { self?.parent.onPick(.success(newURL)) }
                }
            } else if let assetId = result.assetIdentifier {
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
                completion(.failure(NSError(domain: "Relink", code: -10, userInfo: [NSLocalizedDescriptionKey: "Photos access not granted"])))
                return
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = assets.firstObject else {
                completion(.failure(NSError(domain: "Relink", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])))
                return
            }
            let resources = PHAssetResource.assetResources(for: asset)
            guard let videoResource = resources.first(where: { $0.type == .fullSizeVideo || $0.type == .video }) ?? resources.first else {
                completion(.failure(NSError(domain: "Relink", code: -2, userInfo: [NSLocalizedDescriptionKey: "No video resource"])))
                return
            }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let ext = (videoResource.originalFilename as NSString).pathExtension
            let destinationURL = documents.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? ".mov" : "." + ext))
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: destinationURL, options: options) { error in
                if let error { completion(.failure(error)) } else { completion(.success(destinationURL)) }
            }
        }
    }
}

private struct FileRelinkPicker: UIViewControllerRepresentable {
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

// Simple video trimmer view for VideoRelinkView
private struct SimpleVideoTrimmerView: View {
    let asset: AVAsset
    let onComplete: (URL?) -> Void
    
    @State private var startTime: Double = 0.0
    @State private var endTime: Double = 0.0
    @State private var isExporting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Trim Video")
                .font(.headline)
            
            DurationView(asset: asset, startTime: $startTime, endTime: $endTime)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    onComplete(nil)
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button(isExporting ? "Exporting..." : "Trim") {
                    exportTrimmedVideo()
                }
                .disabled(isExporting || startTime >= endTime)
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .onAppear {
            Task {
                if #available(iOS 16.0, *) {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        endTime = CMTimeGetSeconds(duration)
                    }
                } else {
                    // For iOS < 16, we still need to use the synchronous API
                    await MainActor.run {
                        endTime = CMTimeGetSeconds(asset.duration)
                    }
                }
            }
        }
    }
    
    private func exportTrimmedVideo() {
        isExporting = true
        
        Task {
            do {
                let trimmedURL = try await trimVideo(asset: asset, startTime: startTime, endTime: endTime)
                DispatchQueue.main.async {
                    onComplete(trimmedURL)
                }
            } catch {
                DispatchQueue.main.async {
                    onComplete(nil)
                }
            }
        }
    }
    
    private func trimVideo(asset: AVAsset, startTime: Double, endTime: Double) async throws -> URL {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "VideoTrim", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create video track"])
        }
        
        if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
           let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            try audioTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: startTime, preferredTimescale: 600),
                                                       duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)),
                                           of: sourceAudioTrack,
                                           at: .zero)
        }
        
        let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first!
        try videoTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: startTime, preferredTimescale: 600),
                                                   duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)),
                                       of: sourceVideoTrack,
                                       at: .zero)
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documents.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoTrim", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        try await exportSession.export(to: outputURL, as: .mov)
        return outputURL
    }
}

// Helper view for handling duration loading
private struct DurationView: View {
    let asset: AVAsset
    @Binding var startTime: Double
    @Binding var endTime: Double

    @State private var duration: Double? = nil

    var body: some View {
        VStack(spacing: 16) {
            if let duration = duration {
                Text("Duration: \(String(format: "%.1f", duration))s")
                    .font(.subheadline)

                VStack(spacing: 8) {
                    Text("Start: \(String(format: "%.1f", startTime))s")
                    Slider(value: $startTime, in: 0...max(0, duration - 1), step: 0.1)
                        .tint(.accentColor)

                    Text("End: \(String(format: "%.1f", endTime))s")
                    Slider(value: $endTime, in: 1...duration, step: 0.1)
                        .tint(.accentColor)
                }
            } else {
                ProgressView("Loading duration...")
            }
        }
        .task {
            do {
                if #available(iOS 16.0, *) {
                    let loadedDuration = try await asset.load(.duration)
                    await MainActor.run {
                        duration = CMTimeGetSeconds(loadedDuration)
                        if duration != nil && endTime == 0.0 {
                            endTime = duration!
                        }
                    }
                } else {
                    // For iOS < 16, we still need to use the synchronous API
                    await MainActor.run {
                        duration = CMTimeGetSeconds(asset.duration)
                        if duration != nil && endTime == 0.0 {
                            endTime = duration!
                        }
                    }
                }
            } catch {
                // Handle error - for now just set to nil
                await MainActor.run {
                    duration = nil
                }
            }
        }
    }
}

