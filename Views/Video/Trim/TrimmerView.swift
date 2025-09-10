import SwiftUI
import AVKit
import Combine

// MARK: - HandleType Enum
public enum HandleType {
    case start, end
}

// MARK: - TrimmerViewModel
@MainActor
public final class TrimmerViewModel: ObservableObject {
    // MARK: - Core Properties
    let player: AVPlayer
    public let asset: AVAsset
    public let photosIdentifier: String?

    public var oneFrameDuration: CMTime = CMTime(value: 1, timescale: 30)
    public let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)

    // MARK: - Published State
    @Published public var startTime: CMTime = .zero
    @Published public var endTime: CMTime = .zero
    @Published public var videoDuration: CMTime = .zero
    @Published public var isExporting: Bool = false
    @Published public var rotationQuarterTurns: Int = 0
    @Published public var showMinimumDurationWarning = false
    @Published public var isDraggingStartHandle: Bool = false
    @Published public var isDraggingEndHandle: Bool = false

    // MARK: - Coalescing and Chasing Seek State
    private var displayLink: CADisplayLink?
    private var pendingPreviewTime: CMTime?
    private var isSeekInProgress = false
    private var chaseTime: CMTime = .zero

    // MARK: - Initialization & Deinitialization
    public init(asset: AVAsset, photosIdentifier: String? = nil, rotationQuarterTurns: Int = 0) {
        self.asset = asset
        self.photosIdentifier = photosIdentifier
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        self.rotationQuarterTurns = rotationQuarterTurns
        Task {
            await setupAsync()
        }
    }

    deinit {
        // Schedule cleanup on main thread to avoid actor isolation issues
        Task { @MainActor in
            stopCoalescing()
        }
    }

    // MARK: - Public Setup
    public func setupAsync() async {
        do {
            videoDuration = try await asset.load(.duration)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let frameRate = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? 30
            oneFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            endTime = videoDuration
        } catch {
            print("Failed to load asset properties: \(error)")
        }
    }

    // MARK: - Coalescing Timer Control
    public func startCoalescing() {
        player.pause()
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stopCoalescing() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let time = pendingPreviewTime else { return }
        pendingPreviewTime = nil
        seekTo(time)
    }

    // MARK: - Time Proposal and Committing
    public func proposeTime(_ proposedTime: CMTime, for handle: HandleType) {
        let validatedTime = validate(proposedTime, for: handle)

        switch handle {
        case .start:
            if startTime != validatedTime {
                startTime = validatedTime
            }
        case .end:
            if endTime != validatedTime {
                endTime = validatedTime
            }
        }

        self.pendingPreviewTime = validatedTime

        // Show while duration <= minimum during drag
        let atOrBelowMin = (endTime - startTime) <= minimumDuration
        showMinimumDurationWarning = atOrBelowMin
    }
    
    public func commitTime(_ time: CMTime, for handle: HandleType) {
        let validatedTime = validate(time, for: handle)
        switch handle {
        case .start:
            startTime = validatedTime
        case .end:
            endTime = validatedTime
        }
        // Keep warning consistent with the final committed range
        showMinimumDurationWarning = (endTime - startTime) <= minimumDuration
    }

    private func validate(_ proposedTime: CMTime, for handle: HandleType) -> CMTime {
        var validatedTime = max(.zero, min(proposedTime, videoDuration))

        switch handle {
        case .start:
            let limit = endTime - minimumDuration
            if validatedTime > limit {
                validatedTime = limit
                showMinimumDurationWarning = true
            }
        case .end:
            let limit = startTime + minimumDuration
            if validatedTime < limit {
                validatedTime = limit
                showMinimumDurationWarning = true
            }
        }

        if oneFrameDuration.seconds > 0 {
            let frameNumber = round(validatedTime.seconds / oneFrameDuration.seconds)
            validatedTime = CMTime(seconds: frameNumber * oneFrameDuration.seconds, preferredTimescale: validatedTime.timescale)
        }
        
        return validatedTime
    }

    // MARK: - Chasing Seek Implementation
    private func seekTo(_ newTime: CMTime) {
        if newTime != chaseTime {
            chaseTime = newTime
            if !isSeekInProgress {
                trySeekToChaseTime()
            }
        }
    }

    private func trySeekToChaseTime() {
        guard player.currentItem?.status == .readyToPlay else { return }
        actuallySeekToTime()
    }

    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime
        player.seek(to: seekTimeInProgress, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if seekTimeInProgress == self.chaseTime {
                    self.isSeekInProgress = false
                } else {
                    self.trySeekToChaseTime()
                }
            }
        }
    }

    // MARK: - Validation Methods
    public func validateTrimRanges() -> Bool {
        return startTime >= .zero && endTime <= videoDuration && startTime < endTime
    }

    // MARK: - Export Methods (needed by TrimmerView)
    public func exportVideo() async throws -> URL {
        guard validateTrimRanges() else {
            throw NSError(domain: "TrimmerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid trim ranges"])
        }

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

        // Create trim range
        let timeRange = CMTimeRange(start: startTime, duration: endTime - startTime)

        let exportedURL = try await VideoTransformBuilder.exportVideo(
            asset: asset,
            trimRange: timeRange,
            quarterTurns: rotationQuarterTurns,
            outputURL: outputURL
        )
        return exportedURL
    }

    // MARK: - Preview Updates
    public func updatePreview() {
        // Update the live preview by seeking to current start time
        requestSeek(to: startTime)
    }

    public func requestSeek(to time: CMTime) {
        seekTo(time)
    }

    // MARK: - Haptic Feedback
    public func triggerHapticFeedback(for event: HapticManager.HapticEvent) {
        HapticManager.shared.trigger(event)
    }
}


// MARK: - Haptic Feedback Manager (Helper)
public final class HapticManager {
    public static let shared = HapticManager()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    public enum HapticEvent {
        case dragStart
        case dragEnd
        case frameDetent
    }

    private init() {
        selectionFeedback.prepare()
    }

    public func trigger(_ event: HapticEvent) {
        switch event {
        case .dragStart, .dragEnd:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .frameDetent:
            selectionFeedback.selectionChanged()
        }
    }
}

struct HybridPreciseTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel

    // Custom handle views
    var startHandleView: AnyView?
    var endHandleView: AnyView?

    private let handleWidth: CGFloat = 44

    // Haptic Feedback Generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width - handleWidth
            let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
            let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)

            let startDragGesture = drag(handle: .start, in: geometry)
            let endDragGesture = drag(handle: .end, in: geometry)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: trackWidth, height: 6)
                    .offset(x: handleWidth/2)

                // Active range
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: endX - startX, height: 6)
                    .offset(x: startX + handleWidth/2)

                // Start handle
                if let startView = startHandleView {
                    handle(content: startView)
                        .offset(x: startX)
                        .gesture(startDragGesture)
                } else {
                    handle(content: Text("👟").font(.largeTitle))
                        .offset(x: startX)
                        .gesture(startDragGesture)
                }

                // End handle
                if let endView = endHandleView {
                    handle(content: endView)
                        .offset(x: endX)
                        .gesture(endDragGesture)
                } else {
                    handle(content: Text("🔥").font(.largeTitle))
                        .offset(x: endX)
                        .gesture(endDragGesture)
                }
            }
        }
        .coordinateSpace(name: "track")
        .frame(height: 60)
        .onAppear {
            viewModel.startCoalescing()
        }
        .onDisappear(perform: viewModel.stopCoalescing)
    }

    private func handle(content: some View) -> some View {
        content
    }

    // MARK: - Coordinate System

    private func timeToXLeft(_ t: CMTime, trackWidth: CGFloat) -> CGFloat {
        guard viewModel.videoDuration.seconds > 0 else { return 0 }
        let p = t.seconds / viewModel.videoDuration.seconds
        return CGFloat(p) * trackWidth
    }

    private func xLeftToTime(_ x: CGFloat, trackWidth: CGFloat) -> CMTime {
        let clamped = max(0, min(x, trackWidth))
        let seconds = Double(clamped / trackWidth) * viewModel.videoDuration.seconds
        return CMTime(seconds: seconds, preferredTimescale: viewModel.videoDuration.timescale)
    }

    private func minDistancePx(_ g: GeometryProxy) -> CGFloat {
        let trackWidth = g.size.width - handleWidth
        let pps = trackWidth / viewModel.videoDuration.seconds
        return pps * viewModel.minimumDuration.seconds
    }

    private func drag(handle: HandleType, in g: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { value in
                if handle == .start && !viewModel.isDraggingStartHandle {
                    viewModel.isDraggingStartHandle = true
                    viewModel.startCoalescing()
                    impactGenerator.impactOccurred()
                    selectionGenerator.prepare()
                } else if handle == .end && !viewModel.isDraggingEndHandle {
                    viewModel.isDraggingEndHandle = true
                    viewModel.startCoalescing()
                    impactGenerator.impactOccurred()
                    selectionGenerator.prepare()
                }

                let trackWidth = g.size.width - handleWidth
                let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
                let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)
                let minPx = minDistancePx(g)

                // finger-aligned center -> left-edge
                var proposedLeft = value.location.x - handleWidth/2
                proposedLeft = max(0, min(proposedLeft, trackWidth))

                // bumper
                switch handle {
                case .start:
                    proposedLeft = min(proposedLeft, endX - minPx)
                case .end:
                    proposedLeft = max(proposedLeft, startX + minPx)
                }

                let t = xLeftToTime(proposedLeft, trackWidth: trackWidth)
                viewModel.proposeTime(t, for: handle)

                // Haptic feedback for normal sliding
                selectionGenerator.selectionChanged()
            }
            .onEnded { value in
                let trackWidth = g.size.width - handleWidth
                var xLeft = value.location.x - handleWidth/2
                xLeft = max(0, min(xLeft, trackWidth))
                let t = xLeftToTime(xLeft, trackWidth: trackWidth)
                viewModel.commitTime(t, for: handle)

                if handle == .start { viewModel.isDraggingStartHandle = false }
                else { viewModel.isDraggingEndHandle = false }

                viewModel.stopCoalescing()
                impactGenerator.impactOccurred()
            }
    }
}

// MARK: - Convenience Initializers for Common Handle Styles
extension HybridPreciseTrimmerView {
    // Default initializer with emoji fallback
    init(viewModel: TrimmerViewModel) {
        self.viewModel = viewModel
        self.startHandleView = nil
        self.endHandleView = nil
    }

    // Emoji handles - for backward compatibility
    static func emoji(viewModel: TrimmerViewModel,
                     startEmoji: String = "👟",
                     endEmoji: String = "🔥") -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleView: AnyView(Text(startEmoji).font(.largeTitle)),
            endHandleView: AnyView(Text(endEmoji).font(.largeTitle))
        )
    }

    // Custom view handles - now properly uses custom views
    static func custom(viewModel: TrimmerViewModel,
                      startView: some View,
                      endView: some View) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleView: AnyView(startView),
            endHandleView: AnyView(endView)
        )
    }
}

struct TrimmerView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    
    // The TrimmerViewModel now owns the trimming logic
    @StateObject private var trimmerViewModel: TrimmerViewModel
    
    // Local state for rotation, driven by the AddMoveViewModel
    @State private var rotationQuarterTurns: Int
    
    private let asset: AVAsset
    
    init(viewModel: AddMoveViewModel, asset: AVAsset, rotation: Int) {
        self.viewModel = viewModel
        self.asset = asset
        self._rotationQuarterTurns = State(initialValue: rotation)
        self._trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: asset, rotationQuarterTurns: rotation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The video player is now simpler, getting its asset and rotation from the TrimmerViewModel
            CustomVideoPlayerView(asset: trimmerViewModel.asset, rotationQuarterTurns: rotationQuarterTurns)
                .frame(height: 300)
                .cornerRadius(12)
                .padding(.horizontal)
            
            // The trimmer UI component remains the same
            HybridPreciseTrimmerView(viewModel: trimmerViewModel)
                .padding()
            
            Spacer()
            
            // Action bar for trimming controls
            trimmerActionButtons
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: rotationQuarterTurns) {
            trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
        }
    }
    
    private var trimmerActionButtons: some View {
        HStack(spacing: 20) {
            Button("Cancel") {
                viewModel.cancelTrimming()
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button(action: {
                rotationQuarterTurns = (rotationQuarterTurns + 1) % 4
            }) {
                Image(systemName: "rotate.right")
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button("Save") {
                viewModel.finishTrimming(with: trimmerViewModel)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(trimmerViewModel.isExporting)
        }
        .padding()
        .padding(.bottom, 180)
    }
}