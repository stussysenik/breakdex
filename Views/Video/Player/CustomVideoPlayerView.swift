import SwiftUI
import AVKit
import Combine
import OSLog
import UIKit

// MARK: - Custom Video Player View
public struct CustomVideoPlayerView: View {
    // MARK: - Properties
    @ObservedObject private var observableWrapper: ObservableVideoPlayerWrapper
    @State private var isViewReady = false
    @State private var showFullscreen = false
    @State private var isMuted = false
    @Binding private var rotationQuarterTurns: Int
    private let shouldTeardownOnDisappear: Bool
    
    // MARK: - Static Properties
    private static var viewRecomputeCount = 0
    private static var playerViewInstanceCount = 0
    
    // MARK: - Logger
    private let logger = AppContainer.shared.logger
    
    // MARK: - Haptic Feedback
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    public init(viewModel: any VideoPlayerViewModelProtocol, shouldTeardownOnDisappear: Bool = false, rotationQuarterTurns: Binding<Int> = .constant(0)) {
        self.observableWrapper = ObservableVideoPlayerWrapper(viewModel: viewModel)
        self.shouldTeardownOnDisappear = shouldTeardownOnDisappear
        self._rotationQuarterTurns = rotationQuarterTurns
        
        // Log the fix for diagnostic purposes
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: ✅ INIT - Using @ObservedObject (corrected from @StateObject)", metadata: nil)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewModel type: \(type(of: viewModel))", metadata: nil)
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: Should teardown: \(shouldTeardownOnDisappear)", metadata: nil)
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // Use type-erased approach to handle the protocol with associated types
            switch getStateAsString() {
            case "loading":
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    Text("Loading video...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Add additional loading context if available
                    if let loadingProgress = getLoadingProgress() {
                        Text("\(Int(loadingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                
            case "playing":
                if isViewReady, let player = getPlayerFromState() {
                    AVPlayerViewRepresentable(player: player, rotationQuarterTurns: rotationQuarterTurns ?? 0)
                        .overlay(alignment: Alignment.topTrailing) {
                            HStack {
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Fullscreen button tapped", metadata: nil)
                                    showFullscreen = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                }
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute button tapped", metadata: nil)
                                    isMuted.toggle()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                }
                            }
                            .padding()
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding()
                        }
                        .onChange(of: isMuted) { _, muted in
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute state changed to: \(muted)", metadata: nil)
                            player.isMuted = muted
                        }
                        .fullScreenCover(isPresented: $showFullscreen) {
                            FullscreenVideoPlayer(player: player, isPresented: $showFullscreen, rotationQuarterTurns: rotationQuarterTurns)
                        }
                        .task {
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: RenderStart: representable", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🔄 AVPlayerViewRepresentable task started (Instance #\(Self.playerViewInstanceCount), Recompute #\(Self.viewRecomputeCount))", metadata: nil)
                            logMemoryUsage(context: "playing_task_start")
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer status: \(player.status.rawValue)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem status: \(player.currentItem?.status.rawValue ?? -1)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer error: \(String(describing: player.error))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ✅ USING AVPlayerViewRepresentable - ELIMINATING VideoPlayer CRASHES!", metadata: nil)
                            
                            // Final diagnostic during rendering
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 📋 DIAGNOSTIC DURING RENDERING (State: playing)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer exists: ✅", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer status: \(player.status.rawValue) (\(player.status == .readyToPlay ? "readyToPlay" : player.status == .failed ? "failed" : "unknown"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer rate: \(player.rate)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer timeControlStatus: \(player.timeControlStatus.rawValue) (\(player.timeControlStatus == .playing ? "playing" : player.timeControlStatus == .paused ? "paused" : "waiting"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem exists: \(player.currentItem != nil)", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem status: \(player.currentItem?.status.rawValue ?? -1) (\(player.currentItem?.status == .readyToPlay ? "readyToPlay" : player.currentItem?.status == .failed ? "failed" : "unknown"))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer error: \(String(describing: player.error))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: AVPlayer currentItem error: \(String(describing: player.currentItem?.error))", metadata: nil)
                            
                            logMemoryUsage(context: "playing_task_end")
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: 🎬 AVPlayerViewRepresentable should be rendering now! (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Tap gesture handling built into UIViewRepresentable!", metadata: nil)
                        }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .task {
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: RenderStart: waiting_for_view_ready", metadata: nil)
                        }
                        .overlay(alignment: Alignment.topTrailing) {
                            HStack {
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Fullscreen button tapped", metadata: nil)
                                    showFullscreen = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                }
                                Button {
                                    impactGenerator.impactOccurred()
                                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute button tapped", metadata: nil)
                                    isMuted.toggle()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                }
                            }
                            .padding()
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding()
                        }
                        .onChange(of: isMuted) { _, muted in
                            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Mute state changed to: \(muted)", metadata: nil)
                            if let player = observableWrapper.avPlayer {
                                player.isMuted = muted
                            }
                        }
                        .fullScreenCover(isPresented: $showFullscreen) {
                            if let player = observableWrapper.avPlayer {
                                FullscreenVideoPlayer(player: player, isPresented: $showFullscreen, rotationQuarterTurns: rotationQuarterTurns)
                            }
                        }
                }
                
            case "error":
                VStack {
                    Image(systemName: "video.slash.fill")
                        .font(.largeTitle)
                    Text(getErrorMessage() ?? "Unknown error")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
            default:
                EmptyView()
            }
        }
        .onAppear {
            Self.viewRecomputeCount += 1
            Self.playerViewInstanceCount += 1
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View appeared (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: PlayerView instance count now: \(Self.playerViewInstanceCount)", metadata: nil)
            logMemoryUsage(context: "onAppear")
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewModel state: \(String(describing: observableWrapper.state))", metadata: nil)
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")", metadata: nil)
            
            // Mark view as ready and start playback
            isViewReady = true
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: ViewReady: onAppear", metadata: nil)
            observableWrapper.startPlayback()
        }
        .onDisappear {
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View disappearing - \(shouldTeardownOnDisappear ? "WILL teardown" : "NOT tearing down") (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logMemoryUsage(context: "onDisappear_start")
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: Current state: \(String(describing: observableWrapper.state))", metadata: nil)
            
            if shouldTeardownOnDisappear {
                // Full teardown for contexts like Pre-Trim view where view model should be cleaned up
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Performing full teardown of view model", metadata: nil)
                observableWrapper.teardown()
            } else {
                // Legacy behavior: only pause playback, don't tear down resources
                if let player = getPlayerFromState() {
                    logger.info("🎬 CUSTOM_VIDEO_PLAYER: Pausing playback (no teardown)", metadata: nil)
                    player.pause()
                }
            }
            
            // Reset view state only
            isViewReady = false
            showFullscreen = false
            isMuted = false
            
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View state reset, \(shouldTeardownOnDisappear ? "model torn down" : "player preserved")", metadata: nil)
            logMemoryUsage(context: "onDisappear_end")
            Self.playerViewInstanceCount -= 1
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: PlayerView instance count now: \(Self.playerViewInstanceCount)", metadata: nil)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the state as a string for type-erased comparison
    private func getStateAsString() -> String {
        return observableWrapper.stateString
    }
    
    /// Extract the player from the state if available
    private func getPlayerFromState() -> AVPlayer? {
        if let unifiedState = observableWrapper.state as? UnifiedVideoPlayerViewModel.State,
           case .playing(let player) = unifiedState {
            return player
        }
        return nil
    }
    
    /// Extract the error message from the state if available
    private func getErrorMessage() -> String? {
        if let unifiedState = observableWrapper.state as? UnifiedVideoPlayerViewModel.State,
           case .error(let message) = unifiedState {
            return message
        }
        return nil
    }
    
    /// Extract the loading progress from the state if available
    private func getLoadingProgress() -> Double? {
        return observableWrapper.loadingProgress
    }
    
    private func logViewState() {
        // This function is for debugging state changes
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: State change detected", metadata: nil)
        
        // Use a type-erased approach to handle the associated type
        let state = observableWrapper.state
        
        // Since all implementations have the same state structure, we can use a string representation
        let stateString = String(describing: state)
        
        if stateString.contains("loading") {
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View rendering loading state", metadata: nil)
            logMemoryUsage(context: "render_loading")
        } else if stateString.contains("playing") {
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: View rendering playing state", metadata: nil)
            // Extract player information if available
            if let player = getPlayerFromState() {
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player status: \(player.status.rawValue)", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player rate: \(player.rate)", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Current time: \(String(describing: player.currentTime().seconds))", metadata: nil)
                logger.info("🎬 CUSTOM_VIDEO_PLAYER: Player muted: \(player.isMuted)", metadata: nil)
            }
            logMemoryUsage(context: "render_playing")
        } else if stateString.contains("error") {
            logger.error("🎬 CUSTOM_VIDEO_PLAYER: View rendering error state: \(stateString)", metadata: nil)
            logMemoryUsage(context: "render_error")
        }
    }
    
    private func getCPUUsage() -> Double? {
        // Simplified CPU usage measurement for logging - returns nil for now
        // TODO: Implement proper CPU measurement if needed for production logging
        return nil
    }
    
    private func logMemoryUsage(context: String) {
        // Get memory information
        let memoryInfo = getMemoryInfo()
        
        // Log memory usage with context
        logger.info("🎬 CUSTOM_VIDEO_PLAYER: Memory Usage (\(context)) - Used: \(memoryInfo.usedMB)MB, Free: \(memoryInfo.freeMB)MB, Total: \(memoryInfo.totalMB)MB", metadata: nil)
        
        // Log CPU usage if available
        if let cpuUsage = getCPUUsage() {
            logger.info("🎬 CUSTOM_VIDEO_PLAYER: CPU Usage (\(context)): \(String(format: "%.1f", cpuUsage))%", metadata: nil)
        }
    }
    
    private func getMemoryInfo() -> (usedMB: Int, freeMB: Int, totalMB: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Int(info.resident_size / (1024 * 1024))
            let totalMB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
            let freeMB = totalMB - usedMB
            
            return (usedMB, freeMB, totalMB)
        }
        
        return (0, 0, 0)
    }
    
    // MARK: - Fullscreen Player
    private struct FullscreenVideoPlayer: View {
        let player: AVPlayer
        @Binding var isPresented: Bool
        let rotationQuarterTurns: Int?
        private let logger = AppContainer.shared.logger
        private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        
        var body: some View {
            logger.info("🎬 FULLSCREEN_PLAYER: Rendering fullscreen player", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player status: \(player.status.rawValue)", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player rate: \(player.rate)", metadata: nil)
            
            return ZStack(alignment: Alignment.topLeading) {
                AVPlayerViewRepresentable(player: player, rotationQuarterTurns: rotationQuarterTurns ?? 0)
                    .edgesIgnoringSafeArea(.all)
                
                Button {
                    impactGenerator.impactOccurred()
                    logger.info("🎬 FULLSCREEN_PLAYER: Close button tapped", metadata: nil)
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .opacity(0.8)
                }
                .padding()
            }
            .onAppear {
                logger.info("🎬 FULLSCREEN_PLAYER: Fullscreen player appeared", metadata: nil)
            }
            .onDisappear {
                logger.info("🎬 FULLSCREEN_PLAYER: Fullscreen player disappeared", metadata: nil)
            }
        }
    }
}

// MARK: - Observable Wrapper
/// This wrapper allows us to use a generic VideoPlayerViewModelProtocol as an ObservableObject
@MainActor
class ObservableVideoPlayerWrapper: ObservableObject {
    // 💡 SOLUTION: Extract only the properties we need to observe to prevent rate limiting
    @Published var stateString: String = "unknown"
    @Published var isPlayerReady: Bool = false
    @Published var shouldPlay: Bool = false
    @Published var loadingProgress: Double? = nil
    
    private var viewModel: any VideoPlayerViewModelProtocol
    private let logger = AppContainer.shared.logger
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Accessors
    var avPlayer: AVPlayer? {
        return viewModel.avPlayer
    }
    
    var state: Any {
        return viewModel.state
    }
    
    func startPlayback() {
        viewModel.startPlayback()
    }
    
    func teardown() {
        viewModel.teardown()
    }
    
    init(viewModel: any VideoPlayerViewModelProtocol) {
        self.viewModel = viewModel
        self.updatePublishedProperties()
        
        // 💡 SOLUTION: Observe specific properties instead of the entire view model
        setupObservation()
        
        logger.info("🎬 OBSERVABLE_WRAPPER: ✅ INIT - Created focused wrapper for viewModel", metadata: nil)
    }
    
    deinit {
        logger.info("🎬 OBSERVABLE_WRAPPER: 🗑️ DEINIT - Wrapper being deallocated", metadata: nil)
        cancellables.removeAll()
    }
    
    // MARK: - Focused Observation Setup
    
    private func setupObservation() {
        // Use timer-based observation for rapidly changing properties
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePublishedProperties()
            }
            .store(in: &cancellables)
    }
    
    private func updatePublishedProperties() {
        // Extract state as string for comparison
        let newStateString = getStateString()
        let newIsPlayerReady = viewModel.isPlayerReady
        let newShouldPlay = viewModel.shouldPlay
        let newLoadingProgress = getLoadingProgress()
        
        // Only update if values changed to prevent unnecessary publishes
        if stateString != newStateString {
            stateString = newStateString
        }
        
        if isPlayerReady != newIsPlayerReady {
            isPlayerReady = newIsPlayerReady
        }
        
        if shouldPlay != newShouldPlay {
            shouldPlay = newShouldPlay
        }
        
        if loadingProgress != newLoadingProgress {
            loadingProgress = newLoadingProgress
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStateString() -> String {
        if let state = viewModel.state as? UnifiedVideoPlayerViewModel.State {
            switch state {
            case .idle: return "idle"
            case .loading: return "loading"
            case .ready: return "ready"
            case .playing: return "playing"
            case .error: return "error"
            }
        }
        return "unknown"
    }
    
    private func getLoadingProgress() -> Double? {
        let state = viewModel.state
        let stateString = String(describing: state)
        
        if stateString.contains("loading") {
            // Use reflection to extract the progress value from the state
            let mirror = Mirror(reflecting: state)
            
            // Look for the first associated value which should be the progress
            if let progressChild = mirror.children.first(where: { $0.label == nil }) {
                if let progress = progressChild.value as? Double {
                    return progress
                }
            }
        }
        
        return nil
    }
}


// MARK: - Process Info Helper
/// Helper struct to get process information
struct ProcessInfo {
    static let processInfo = Foundation.ProcessInfo.processInfo
    static var physicalMemory: UInt64 {
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size = MemoryLayout<UInt64>.size
        var physicalMemory: UInt64 = 0
        
        let result = sysctl(&mib, UInt32(mib.count), &physicalMemory, &size, nil, 0)
        
        if result != KERN_SUCCESS {
            return 0
        }
        
        return physicalMemory
    }
}
