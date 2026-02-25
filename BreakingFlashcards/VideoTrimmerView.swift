
//
//  VideoTrimmerView.swift
//  BreakingFlashcards
//
//  Created by s3nik // m1LL on 8/27/25.
//

import SwiftUI
import AVKit

class ThumbnailGenerator: ObservableObject {
    @Published var thumbnails = [UIImage]()
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    
    private let asset: AVAsset
    private let imageGenerator: AVAssetImageGenerator
    private let cache = NSCache<NSValue, UIImage>()
    private var generationQueue = DispatchQueue(label: "thumbnail-generation", qos: .userInitiated)

    init(asset: AVAsset) {
        self.asset = asset
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        self.imageGenerator.appliesPreferredTrackTransform = true
        self.imageGenerator.maximumSize = CGSize(width: 100, height: 60)
        // Allow some tolerance for better performance
        self.imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        self.imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        // Configure cache
        cache.countLimit = 50
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }

    func generateThumbnails(for duration: CMTime, count: Int) {
        isGenerating = true
        generationProgress = 0.0
        thumbnails.removeAll()
        
        let interval = duration.seconds / Double(count)
        var times = [NSValue]()
        for i in 0..<count {
            let time = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }

        generationQueue.async { [weak self] in
            guard let self = self else { return }
            
            var generatedThumbnails: [(Int, UIImage)] = []
            let dispatchGroup = DispatchGroup()
            
            for (index, timeValue) in times.enumerated() {
                dispatchGroup.enter()
                
                // Check cache first
                if let cachedImage = self.cache.object(forKey: timeValue) {
                    generatedThumbnails.append((index, cachedImage))
                    DispatchQueue.main.async {
                        self.generationProgress = Double(index + 1) / Double(count)
                    }
                    dispatchGroup.leave()
                    continue
                }
                
                self.imageGenerator.generateCGImagesAsynchronously(forTimes: [timeValue]) { _, image, _, _, _ in
                    if let cgImage = image {
                        let uiImage = UIImage(cgImage: cgImage)
                        self.cache.setObject(uiImage, forKey: timeValue)
                        generatedThumbnails.append((index, uiImage))
                    }
                    
                    DispatchQueue.main.async {
                        self.generationProgress = Double(index + 1) / Double(count)
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Sort by index to maintain order
                let sortedThumbnails = generatedThumbnails.sorted { $0.0 < $1.0 }.map { $0.1 }
                self.thumbnails = sortedThumbnails
                self.isGenerating = false
                self.generationProgress = 1.0
            }
        }
    }
}

struct VideoTrimmerView: View {
    let asset: AVAsset
    let onComplete: (URL?) -> Void

    @StateObject private var thumbnailGenerator: ThumbnailGenerator
    @State private var player: AVPlayer
    @State private var isPlaying = false
    @State private var startTime: CMTime = .zero
    @State private var endTime: CMTime
    @State private var startHandlePosition: CGFloat = 0
    @State private var endHandlePosition: CGFloat
    @State private var isExporting = false
    @State private var exportProgress: Float = 0.0
    @State private var exportError: String?

    private let timelineWidth: CGFloat = 300

    init(asset: AVAsset, onComplete: @escaping (URL?) -> Void) {
        self.asset = asset
        self.onComplete = onComplete
        self._thumbnailGenerator = StateObject(wrappedValue: ThumbnailGenerator(asset: asset))
        self._player = State(initialValue: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
        self._endTime = State(initialValue: asset.duration)
        self._endHandlePosition = State(initialValue: timelineWidth)
    }

    var body: some View {
        VStack {
            CustomVideoPlayerView(player: player)
                .frame(height: 300)

            ZStack(alignment: .leading) {
                if thumbnailGenerator.isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: thumbnailGenerator.generationProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: timelineWidth * 0.8)
                        
                        Text("Generating thumbnails... \(Int(thumbnailGenerator.generationProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: timelineWidth, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(thumbnailGenerator.thumbnails, id: \.self) { thumbnail in
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: timelineWidth / 20, height: 60)
                                    .clipped()
                            }
                        }
                    }
                    .frame(width: timelineWidth, height: 60)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Trimming Handles - only show when not generating thumbnails
                if !thumbnailGenerator.isGenerating {
                    HStack {
                        // Start Handle
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 10)
                            .offset(x: startHandlePosition)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newPosition = max(0, min(value.location.x, endHandlePosition - 10))
                                        startHandlePosition = newPosition
                                        startTime = CMTime(seconds: Double(newPosition / timelineWidth) * asset.duration.seconds, preferredTimescale: 600)
                                        player.seek(to: startTime)
                                    }
                            )

                        Spacer()

                        // End Handle
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 10)
                            .offset(x: endHandlePosition - timelineWidth)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newPosition = max(startHandlePosition + 10, min(value.location.x, timelineWidth))
                                        endHandlePosition = newPosition
                                        endTime = CMTime(seconds: Double(newPosition / timelineWidth) * asset.duration.seconds, preferredTimescale: 600)
                                        player.seek(to: endTime)
                                    }
                            )
                    }
                    .frame(width: timelineWidth, height: 60)
                }
            }

            if isExporting {
                VStack(spacing: 16) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accent))
                        .frame(height: 8)
                    
                    Text("Exporting: \(Int(exportProgress * 100))%")
                        .font(.ibmPlexMono(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                HStack(spacing: 16) {
                    Button("Cancel") { 
                        onComplete(nil) 
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save Trimmed Video") { 
                        export() 
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(startTime >= endTime || thumbnailGenerator.isGenerating)
                }
                .padding()
            }
            
            if let error = exportError {
                Text("Export failed: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            thumbnailGenerator.generateThumbnails(for: asset.duration, count: 20)
            player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
                if time >= endTime {
                    player.seek(to: startTime)
                    if !isPlaying { player.pause() }
                }
            }
        }
    }

    private func export() {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
            exportError = "Could not create export session"
            return
        }
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        // Create unique output URL in documents directory for persistence
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        // Monitor export progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.exportProgress = exportSession.progress
            }
            
            if exportSession.status != .exporting {
                timer.invalidate()
            }
        }
        
        // Export on background queue
        DispatchQueue.global(qos: .background).async {
            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    progressTimer.invalidate()
                    self.isExporting = false
                    
                    switch exportSession.status {
                    case .completed:
                        self.onComplete(exportSession.outputURL)
                    case .failed:
                        self.exportError = exportSession.error?.localizedDescription ?? "Export failed"
                    case .cancelled:
                        self.exportError = "Export was cancelled"
                    default:
                        self.exportError = "Unknown export error"
                    }
                }
            }
        }
    }
}
