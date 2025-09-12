import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - HandleType Enum (internal use)
enum HandleType {
    case start, end
}

// MARK: - Unified Feature-Rich Trimmer View
struct FeatureRichTrimmerView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @StateObject private var trimmerViewModel: TrimmerViewModel
    @State private var rotationQuarterTurns: Int = 0
    
    // MARK: - State
    @State private var isPlayerReady = false
    @State private var playerViewModel: UpdatedVideoPlayerViewModel?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var playerTimeoutTask: Task<Void, Error>?
    
    // MARK: - Configuration
    private let asset: AVAsset
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "FeatureRichTrimmer")
    
    init(viewModel: AddMoveViewModel, asset: AVAsset, rotation: Int) {
        self.viewModel = viewModel
        self.asset = asset
        self._rotationQuarterTurns = State(initialValue: rotation)
        self._trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: asset, rotationQuarterTurns: rotation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Video Player Section
            videoPlayerSection
            
            Spacer()
            
            // MARK: - Enhanced Trimmer Interface
            VStack(spacing: 16) {
                // Time code display
                timeCodeDisplay
                
                // Main trimmer with shoe handles
                mainTrimmerSection
                
                // Enhanced controls
                controlSection
                
                // Minimum duration warning
                if trimmerViewModel.showMinimumDurationWarning {
                    minimumDurationWarning
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .onAppear(perform: initializeTrimmer)
        .onDisappear {
            playerTimeoutTask?.cancel()
            playerTimeoutTask = nil
        }
        .onChange(of: rotationQuarterTurns) { _ in
            handleRotationChange()
        }
        .task {
            await setupTrimmerViewModel()
        }
    }
    
    // MARK: - Video Player Section
    private var videoPlayerSection: some View {
        Group {
            if isPlayerReady, let playerViewModel = playerViewModel {
                CustomVideoPlayerView(viewModel: playerViewModel)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                loadingState
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading video player...")
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
        .frame(height: 300)
        .background(Color.black.ignoresSafeArea())
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Time Code Display
    private var timeCodeDisplay: some View {
        VStack(spacing: 12) {
            HStack {
                // Start time
                TimeCodeLabel(
                    time: trimmerViewModel.startTime,
                    position: .start,
                    isActive: trimmerViewModel.isDraggingStartHandle
                )
                
                Spacer()
                
                // Duration with warning
                DurationLabel(
                    duration: trimmerViewModel.endTime - trimmerViewModel.startTime,
                    minimumDuration: trimmerViewModel.minimumDuration,
                    showWarning: trimmerViewModel.showMinimumDurationWarning
                )
                
                Spacer()
                
                // End time
                TimeCodeLabel(
                    time: trimmerViewModel.endTime,
                    position: .end,
                    isActive: trimmerViewModel.isDraggingEndHandle
                )
            }
            
            // Progress bar visualization
            TimeProgressBar(
                currentRange: trimmerViewModel.startTime...trimmerViewModel.endTime,
                totalDuration: trimmerViewModel.videoDuration
            )
        }
        .font(.ibmPlexMono(size: 12))
    }
    
    // MARK: - Main Trimmer Section
    private var mainTrimmerSection: some View {
        HybridPreciseTrimmerView.shoe(viewModel: trimmerViewModel)
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        HStack(spacing: 20) {
            Button("Cancel") {
                HapticManager.shared.trigger(.dragEnd)
                viewModel.cancelTrimming()
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button(action: {
                HapticManager.shared.trigger(.frameDetent)
                rotationQuarterTurns = (rotationQuarterTurns + 1) % 4
            }) {
                Image(systemName: "rotate.right")
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button("Save") {
                HapticManager.shared.trigger(.dragEnd)
                viewModel.finishTrimming(with: trimmerViewModel)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(trimmerViewModel.isExporting)
        }
        .padding()
    }
    
    // MARK: - Minimum Duration Warning
    private var minimumDurationWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.buttonHard)
            Text("Minimum duration is 3 seconds")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.buttonHard.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Private Methods
    private func initializeTrimmer() {
        logger.info("🎬 FEATURE_RICH_TRIMMER: 🚀 Initializing trimmer")
        
        // Create player view model
        playerViewModel = UpdatedVideoPlayerViewModel(
            asset: trimmerViewModel.asset,
            rotationQuarterTurns: rotationQuarterTurns,
            appContainer: AppContainer.shared
        )
        
        // Monitor player readiness
        if let playerViewModel = playerViewModel {
            playerViewModel.$state
                .compactMap { state in
                    switch state {
                    case .playing: return true
                    case .loading, .error: return false
                    }
                }
                .receive(on: RunLoop.main)
                .sink { [self] isReady in
                    if isReady {
                        isPlayerReady = true
                        logger.info("🎬 FEATURE_RICH_TRIMMER: ✅ Player ready")
                    }
                }
                .store(in: &cancellables)
        }
        
        // Setup timeout
        setupPlayerTimeout()
    }
    
    private func setupPlayerTimeout() {
        playerTimeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            if !isPlayerReady {
                await MainActor.run {
                    logger.warning("🎬 FEATURE_RICH_TRIMMER: ⏰ Player timeout - forcing ready state")
                    isPlayerReady = true
                }
            }
        }
    }
    
    private func handleRotationChange() {
        logger.info("🎬 FEATURE_RICH_TRIMMER: 🔄 Rotation changed to \(rotationQuarterTurns)°")
        trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
        
        // Recreate player with new rotation
        playerViewModel = UpdatedVideoPlayerViewModel(
            asset: trimmerViewModel.asset,
            rotationQuarterTurns: rotationQuarterTurns,
            appContainer: AppContainer.shared
        )
    }
    
    private func setupTrimmerViewModel() async {
        do {
            try await trimmerViewModel.setupAsync()
            await trimmerViewModel.updatePreview()
            logger.info("🎬 FEATURE_RICH_TRIMMER: ✅ Trimmer setup completed")
        } catch {
            logger.error("🎬 FEATURE_RICH_TRIMMER: ❌ Setup failed: \(error)")
        }
    }
}

// MARK: - Shoe Handle Component
struct ShoeHandle: View {
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Background capsule (IBM Carbon design)
            Capsule()
                .fill(Color.cardBackground.opacity(0.9))
                .frame(width: 40, height: 40)
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? Color.accentColor : Color.accentColor.opacity(0.6),
                            lineWidth: isActive ? 3 : 2
                        )
                )
                .shadow(
                    color: isActive ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.2),
                    radius: isActive ? 6 : 4,
                    x: 0,
                    y: isActive ? 3 : 2
                )
            
            // Shoe emoji with subtle background
            Text("👟")
                .font(.system(size: 20))
                .background(
                    Circle()
                        .fill(Color.cardBackground.opacity(0.8))
                        .frame(width: 26, height: 26)
                )
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Time Code Label
struct TimeCodeLabel: View {
    let time: CMTime
    let position: HandlePosition
    let isActive: Bool
    
    enum HandlePosition {
        case start, end
    }
    
    var body: some View {
        Text(formatTime(time))
            .font(.ibmPlexMono(size: 12, weight: isActive ? .medium : .regular))
            .foregroundColor(isActive ? Color.accentColor : Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            )
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = time.seconds
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Duration Label
struct DurationLabel: View {
    let duration: CMTime
    let minimumDuration: CMTime
    let showWarning: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if showWarning {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.buttonHard)
                    .font(.system(size: 10))
            }
            
            Text(formatDuration(duration))
                .font(.ibmPlexMono(size: 12, weight: showWarning ? .medium : .regular))
                .foregroundColor(showWarning ? Color.buttonHard : Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(showWarning ? Color.buttonHard.opacity(0.1) : Color.clear)
        )
    }
    
    private func formatDuration(_ time: CMTime) -> String {
        let seconds = time.seconds
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Time Progress Bar
struct TimeProgressBar: View {
    let currentRange: ClosedRange<CMTime>
    let totalDuration: CMTime
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                
                // Selected range
                Capsule()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(
                        width: calculateWidth(currentRange, totalDuration, in: geometry),
                        height: 4
                    )
                    .offset(x: calculateOffset(currentRange.lowerBound, totalDuration, in: geometry))
            }
        }
        .frame(height: 8)
    }
    
    private func calculateWidth(_ range: ClosedRange<CMTime>, _ total: CMTime, in geometry: GeometryProxy) -> CGFloat {
        let percentage = (range.upperBound.seconds - range.lowerBound.seconds) / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }
    
    private func calculateOffset(_ time: CMTime, _ total: CMTime, in geometry: GeometryProxy) -> CGFloat {
        let percentage = time.seconds / total.seconds
        return geometry.size.width * CGFloat(percentage)
    }
}

// MARK: - Hybrid Precise Trimmer (Integrated)
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
                    handle(content: Text("👟").font(.largeTitle)) // Changed to shoe emoji
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
    
    private func convertHandleType(_ handleType: HandleType) -> TrimmerHandleType {
        switch handleType {
        case .start: return .start
        case .end: return .end
        }
    }
    
    private func drag(handle: HandleType, in g: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { value in
                if handle == .start && !viewModel.isDraggingStartHandle {
                    viewModel.isDraggingStartHandle = true
                    viewModel.startCoalescing()
                    HapticManager.shared.trigger(.dragStart)
                } else if handle == .end && !viewModel.isDraggingEndHandle {
                    viewModel.isDraggingEndHandle = true
                    viewModel.startCoalescing()
                    HapticManager.shared.trigger(.dragStart)
                }
                
                let trackWidth = g.size.width - handleWidth
                let startX = timeToXLeft(viewModel.startTime, trackWidth: trackWidth)
                let endX = timeToXLeft(viewModel.endTime, trackWidth: trackWidth)
                let minPx = minDistancePx(g)
                
                // finger-aligned center -> left-edge
                var proposedLeft = value.location.x - handleWidth/2
                proposedLeft = max(0, min(proposedLeft, trackWidth))
                
                // bumper - physical bump implementation
                let oldProposedLeft = proposedLeft
                switch handle {
                case .start:
                    proposedLeft = min(proposedLeft, endX - minPx)
                case .end:
                    proposedLeft = max(proposedLeft, startX + minPx)
                }
                
                // Trigger haptic feedback for physical bump
                if oldProposedLeft != proposedLeft {
                    HapticManager.shared.trigger(.dragEnd)
                }
                
                let t = xLeftToTime(proposedLeft, trackWidth: trackWidth)
                viewModel.proposeTime(t, for: convertHandleType(handle))
                
                // Haptic feedback for normal sliding
                HapticManager.shared.trigger(.frameDetent)
            }
            .onEnded { value in
                let trackWidth = g.size.width - handleWidth
                var xLeft = value.location.x - handleWidth/2
                xLeft = max(0, min(xLeft, trackWidth))
                let t = xLeftToTime(xLeft, trackWidth: trackWidth)
                viewModel.commitTime(t, for: convertHandleType(handle))
                
                if handle == .start { viewModel.isDraggingStartHandle = false }
                else { viewModel.isDraggingEndHandle = false }
                
                viewModel.stopCoalescing()
                HapticManager.shared.trigger(.dragEnd)
            }
    }
}

// MARK: - Convenience Initializers for Common Handle Styles
extension HybridPreciseTrimmerView {
    // Default initializer with shoe emoji
    init(viewModel: TrimmerViewModel) {
        self.viewModel = viewModel
        self.startHandleView = nil
        self.endHandleView = nil
    }
    
    // Shoe handles - our new default
    static func shoe(viewModel: TrimmerViewModel) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleView: AnyView(ShoeHandle(isActive: viewModel.isDraggingStartHandle)),
            endHandleView: AnyView(ShoeHandle(isActive: viewModel.isDraggingEndHandle))
        )
    }
    
    // Custom view handles
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