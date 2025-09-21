import SwiftUI
import AVKit
import Combine
import OSLog

// MARK: - HandleType Enum (internal use)
enum HandleType {
    case start, end
}

// MARK: - Isolated Trimmer Player View
/// A new, isolated view that ONLY displays the video player.
/// Its dependencies do not change during a drag, so SwiftUI won't re-render it.
struct TrimmerPlayerView: View {
    @ObservedObject var playerViewModel: UnifiedVideoPlayerViewModel
    @Binding var rotationQuarterTurns: Int
    
    var body: some View {
        CustomVideoPlayerView(viewModel: playerViewModel, rotationQuarterTurns: rotationQuarterTurns)
            .frame(height: 300)
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

// MARK: - Unified Feature-Rich Trimmer View
struct FeatureRichTrimmerView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var playerViewModel: UnifiedVideoPlayerViewModel?
    
    // MARK: - State
    @State private var isPlayerReady = false
    @State private var playerTimeoutTask: Task<Void, Error>?
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Optimization
    @State private var localRotation: Int = 0
    @State private var cachedTimeCodeRow: (startTime: CMTime, endTime: CMTime, isDraggingStart: Bool, isDraggingEnd: Bool)?
    
    // MARK: - Enhanced Diagnostic Logging
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "FeatureRichTrimmer")
    
    // MARK: - Performance Memoization
    private var rotationBinding: Binding<Int> {
        Binding(
            get: { unifiedState.trimmerViewModel?.rotationQuarterTurns ?? 0 },
            set: { newValue in
                unifiedState.trimmerViewModel?.rotationQuarterTurns = newValue
                localRotation = newValue
            }
        )
    }
    
    // MARK: - Player Readiness Validation
    @State private var isTrimmerSetupComplete = false

    private var isPlayerTrimmerReady: Bool {
        guard let playerViewModel = playerViewModel,
              let trimmerViewModel = unifiedState.trimmerViewModel else {
            return false
        }

        // Player must be ready AND TrimmerViewModel must be setup
        return playerViewModel.isPlayerReady && (trimmerViewModel.isReady || isTrimmerSetupComplete)
    }
    
    // MARK: - Time Code Display with Memoization
    private var timeCodeRow: some View {
        let trimmerVM = unifiedState.trimmerViewModel
        let startTime = trimmerVM?.startTime ?? .zero
        let endTime = trimmerVM?.endTime ?? .zero
        let isDraggingStart = trimmerVM?.isDraggingStartHandle ?? false
        let isDraggingEnd = trimmerVM?.isDraggingEndHandle ?? false
        let minimumDuration = trimmerVM?.minimumDuration ?? CMTime(seconds: 3.0, preferredTimescale: 600)
        let showWarning = trimmerVM?.showMinimumDurationWarning ?? false
        
        return HStack {
            TimeCodeLabel(time: startTime, position: .start, isActive: isDraggingStart)
            Spacer()
            DurationLabel(
                duration: endTime - startTime,
                minimumDuration: minimumDuration,
                showWarning: showWarning
            )
            Spacer()
            TimeCodeLabel(time: endTime, position: .end, isActive: isDraggingEnd)
        }
    }
    
    init(unifiedState: AddMoveUnifiedState) {
        self.unifiedState = unifiedState
        
        // Initialize the view's local state from the single source of truth
        guard let playerVM = unifiedState.currentPlayerViewModel else {
            // This is a failsafe; the container should not show this view unless these exist.
            // In a production app, you might handle this with a more robust error view.
            fatalError("FeatureRichTrimmerView initialized without a valid player ViewModel.")
        }
        
        self.playerViewModel = playerVM
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // MARK: - Video Player Section
            Group {
                if isPlayerTrimmerReady {
                    TrimmerPlayerView(
                        playerViewModel: playerViewModel!,
                        rotationQuarterTurns: Binding(
                            get: { unifiedState.trimmerViewModel?.rotationQuarterTurns ?? 0 },
                            set: { unifiedState.trimmerViewModel?.rotationQuarterTurns = $0 }
                        )
                    )
                } else {
                    loadingState
                }
            }
            // MARK: - Enhanced Trimmer Interface
            Spacer()
            VStack(spacing: 8) {
                Spacer()
                // Time code display
                timeCodeDisplay
                
                // Main trimmer with shoe handles
                mainTrimmerSection
                
                // Enhanced controls
                controlSection
                
                // Minimum duration warning
                if unifiedState.trimmerViewModel?.showMinimumDurationWarning == true {
                    minimumDurationWarning
                }
                Spacer()
            }
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            diagnosticLogger.logInfo("🎬 Body appeared", metadata: [
                "trimmer_vm_available": "\(unifiedState.trimmerViewModel != nil)",
                "trimmer_vm_ready": "\(unifiedState.trimmerViewModel?.isReady ?? false)",
                "show_warning": "\(unifiedState.trimmerViewModel?.showMinimumDurationWarning ?? false)",
                "player_ready": "\(playerViewModel?.isPlayerReady ?? false)",
                "combined_ready": "\(isPlayerTrimmerReady)"
            ])
            initializeTrimmer()
        }
        .onDisappear {
            diagnosticLogger.logInfo("🧹 Body disappeared")
            playerTimeoutTask?.cancel()
            playerTimeoutTask = nil
        }
        .task {
            diagnosticLogger.logInfo("⚡ Setup task started")
            await setupTrimmerViewModel()
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
            self.timeCodeRow
        }
        .onAppear(perform: onTimeCodeDisplayAppear)
    }
    
    private func onTimeCodeDisplayAppear() {
        let trimmerVM = unifiedState.trimmerViewModel
        diagnosticLogger.logInfo("⏰ Time code display appeared", metadata: [
            "start_time_seconds": "\(CMTimeGetSeconds(trimmerVM?.startTime ?? .zero))",
            "end_time_seconds": "\(CMTimeGetSeconds(trimmerVM?.endTime ?? .zero))",
            "show_warning": "\(trimmerVM?.showMinimumDurationWarning ?? false)"
        ])
    }
    
    // MARK: - Optimized Control Section
    private var controlSection: some View {
        let trimmerVM = unifiedState.trimmerViewModel
        let currentRotation = trimmerVM?.rotationQuarterTurns ?? 0
        let isExporting = trimmerVM?.isExporting ?? false
        
        return HStack(spacing: 20) {
            Button("Cancel") {
                HapticManager.shared.trigger(.dragEnd)
                diagnosticLogger.logUserInteraction("Cancel button tapped", metadata: [
                    "button_type": "cancel",
                    "current_rotation": "\(currentRotation)"
                ])
                // 🎯 CRITICAL FIX: Cancel should go back to select clip screen (ready state)
                // NOT previewing state which shows EmptyView()
                unifiedState.transitionTo(.ready)
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button(action: {
                HapticManager.shared.trigger(.frameDetent)
                diagnosticLogger.logUserInteraction("Rotation button tapped", metadata: [
                    "button_type": "rotation",
                    "current_rotation": "\(currentRotation)",
                    "target_rotation": "\((currentRotation + 1) % 4)"
                ])
                Task {
                    do {
                        let newRotation = (currentRotation + 1) % 4
                        try await unifiedState.applyTrimSettings(
                            startTime: trimmerVM?.startTime.seconds ?? 0,
                            endTime: trimmerVM?.endTime.seconds ?? 0,
                            rotation: newRotation
                        )
                    } catch {
                        unifiedState.setError(message: "Failed to apply rotation", underlying: error.localizedDescription)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "rotate.right")
                    Text("(\(currentRotation * 90)°)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button("Continue") {
                HapticManager.shared.trigger(.dragEnd)
                diagnosticLogger.logUserInteraction("Continue button tapped", metadata: [
                    "button_type": "continue",
                    "current_rotation": "\(currentRotation)",
                    "exporting": "\(isExporting)"
                ])
                unifiedState.transitionTo(.naming)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(isExporting)
        }
        .padding()
        .onAppear {
            diagnosticLogger.logInfo("🎮 Control section appeared", metadata: [
                "rotation": "\(currentRotation)",
                "exporting": "\(isExporting)",
                "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
            ])
        }
        .overlay(
            Text("DEBUG: Controls")
                .font(.caption)
                .foregroundColor(.green)
                .background {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                }
                .padding(2),
            alignment: .topLeading
        )
    }
    
    // MARK: - Main Trimmer Section
    private var mainTrimmerSection: some View {
        Group {
            if let trimmerViewModel = unifiedState.trimmerViewModel {
                HybridPreciseTrimmerView.shoe(viewModel: trimmerViewModel)
                    .onAppear(perform: onMainTrimmerAppear)
            }
        }
    }
    
    private func onMainTrimmerAppear() {
        let videoDuration = unifiedState.trimmerViewModel?.videoDuration ?? .zero
        diagnosticLogger.logInfo("🎚 Main trimmer section appeared", metadata: [
            "video_duration_seconds": "\(CMTimeGetSeconds(videoDuration))",
            "cpu_usage_percent": "\(String(format: "%.1f", diagnosticLogger.getCurrentCPUUsage()))"
        ])
    }
    
    // MARK: - Optimized Logging (Legacy - maintained for compatibility)
    private func logInfo(_ message: String) {
        diagnosticLogger.logInfo(message)
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
        .onAppear {
            guard let trimmerViewModel = unifiedState.trimmerViewModel else { return }
            let duration = trimmerViewModel.endTime - trimmerViewModel.startTime
            let minimum = trimmerViewModel.minimumDuration
            let durationSeconds = duration.seconds
            let minimumSeconds = minimum.seconds
            diagnosticLogger.logWarning("⚠️ Minimum duration warning appeared", metadata: [
                "duration_seconds": "\(durationSeconds)",
                "minimum_seconds": "\(minimumSeconds)",
                "is_below_minimum": "\(durationSeconds < minimumSeconds)"
            ])
        }
    }
    
    // MARK: - Private Methods
    private func initializeTrimmer() {
        diagnosticLogger.startTiming("trimmer_initialization")
        diagnosticLogger.logInfo("🚀 Initializing trimmer")
        
        // Monitor unified player readiness
        Task {
            while !isPlayerReady {
                try? await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1 seconds
                if playerViewModel?.isPlayerReady == true {
                    await MainActor.run {
                        isPlayerReady = true
                        diagnosticLogger.logInfo("✅ Shared player ready", metadata: [
                            "initialization_time_ms": "\(String(format: "%.0f", diagnosticLogger.getMemoryInfo().used))"
                        ])
                        diagnosticLogger.stopTiming("trimmer_initialization")
                    }
                    break
                }
            }
        }
        
        // Setup timeout
        setupPlayerTimeout()
    }
    
    private func setupPlayerTimeout() {
        playerTimeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            
            if !isPlayerReady {
                await MainActor.run {
                    diagnosticLogger.logWarning("⏰ Player timeout - forcing ready state", metadata: [
                        "timeout_seconds": "10",
                        "player_state": "\(playerViewModel?.isPlayerReady ?? false)"
                    ])
                    isPlayerReady = true
                }
            }
        }
    }
    
    
    private func setupTrimmerViewModel() async {
        diagnosticLogger.startTiming("trimmer_viewmodel_setup")

        guard let trimmerViewModel = unifiedState.trimmerViewModel else {
            diagnosticLogger.logError("No trimmer view model available")
            return
        }

        do {
            try await trimmerViewModel.setupAsync()
            await trimmerViewModel.updatePreview()

            // 🎯 CRITICAL FIX: Mark trimmer setup as complete to trigger UI update
            await MainActor.run {
                isTrimmerSetupComplete = true
                diagnosticLogger.logInfo("✅ Trimmer setup completed and UI state updated")
            }

            diagnosticLogger.stopTiming("trimmer_viewmodel_setup")
        } catch {
            diagnosticLogger.logError("Setup failed", error: error)
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
                            isActive ? Color.accent : Color.accent.opacity(0.6),
                            lineWidth: isActive ? 3 : 2
                        )
                )
                .shadow(
                    color: isActive ? Color.accent.opacity(0.4) : Color.black.opacity(0.2),
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
            .foregroundColor(isActive ? Color.accent : Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? Color.accent.opacity(0.1) : Color.clear)
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
                    .fill(Color.accent)
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
            viewModel: viewModel
        )
    }
    
    // Custom view handles
    static func custom(viewModel: TrimmerViewModel,
                       startView: some View,
                       endView: some View) -> HybridPreciseTrimmerView {
        // FIX: The original implementation was empty and ignored the parameters.
        // This corrected version properly uses the views.
        var view = HybridPreciseTrimmerView(viewModel: viewModel)
        view.startHandleView = AnyView(startView)
        view.endHandleView = AnyView(endView)
        return view
    }
}
