import SwiftUI
import AVKit
import Combine
import OSLog
import UIKit

// MARK: - Shared Video Player View (uses VideoPlayerManager)
public struct SharedVideoPlayerView: View {
    // MARK: - Properties
    @EnvironmentObject private var videoPlayerManager: VideoPlayerManager
    @State private var isViewReady = false
    @State private var showFullscreen = false
    @State private var isMuted = false
    
    // MARK: - Static Properties
    private static var viewRecomputeCount = 0
    private static var playerViewInstanceCount = 0
    
    // MARK: - Logger
    private let logger = AppContainer.shared.logger
    
    // MARK: - Haptic Feedback
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    public init() {
        // No need for view model parameter - uses environment object
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // Use the shared player from VideoPlayerManager
            if videoPlayerManager.isPlayerReady {
                videoPlayerContent
            } else {
                loadingContent
            }
        }
        .onAppear {
            Self.viewRecomputeCount += 1
            logger.info("🎬 SHARED_VIDEO_PLAYER: View appeared (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logMemoryUsage(context: "onAppear")
            logger.info("🎬 SHARED_VIDEO_PLAYER: Player ready: \(videoPlayerManager.isPlayerReady)", metadata: nil)
            logger.info("🎬 SHARED_VIDEO_PLAYER: Thread: \(Thread.current.isMainThread ? "Main" : "Background")", metadata: nil)
            
            // Mark view as ready and start playback
            isViewReady = true
            logger.info("🎬 SHARED_VIDEO_PLAYER: ViewReady: onAppear", metadata: nil)
            
            // Auto-start playback when view appears
            if videoPlayerManager.isPlayerReady {
                videoPlayerManager.startPlayback()
            }
        }
        .onDisappear {
            logger.info("🎬 SHARED_VIDEO_PLAYER: View disappearing - NOT tearing down (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
            logMemoryUsage(context: "onDisappear_start")
            logger.info("🎬 SHARED_VIDEO_PLAYER: Player ready: \(videoPlayerManager.isPlayerReady)", metadata: nil)
            
            // CRITICAL: Remove all teardown logic from here.
            // The VideoPlayerManager handles the player's lifecycle.
            // Only pause playback, don't tear down resources.
            if videoPlayerManager.isPlayerReady {
                logger.info("🎬 SHARED_VIDEO_PLAYER: Pausing playback (no teardown)", metadata: nil)
                videoPlayerManager.pausePlayback()
            }
            
            // Reset view state only
            isViewReady = false
            showFullscreen = false
            isMuted = false
            
            logger.info("🎬 SHARED_VIDEO_PLAYER: View state reset, player preserved", metadata: nil)
            logMemoryUsage(context: "onDisappear_end")
            Self.playerViewInstanceCount -= 1
            logger.info("🎬 SHARED_VIDEO_PLAYER: PlayerView instance count now: \(Self.playerViewInstanceCount)", metadata: nil)
        }
    }
    
    // MARK: - Video Player Content
    private var videoPlayerContent: some View {
        AVPlayerViewRepresentable(player: videoPlayerManager.player)
            .overlay(alignment: Alignment.topTrailing) {
                HStack {
                    Button {
                        impactGenerator.impactOccurred()
                        logger.info("🎬 SHARED_VIDEO_PLAYER: Fullscreen button tapped", metadata: nil)
                        showFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    Button {
                        impactGenerator.impactOccurred()
                        logger.info("🎬 SHARED_VIDEO_PLAYER: Mute button tapped", metadata: nil)
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
                logger.info("🎬 SHARED_VIDEO_PLAYER: Mute state changed to: \(muted)", metadata: nil)
                videoPlayerManager.player.isMuted = muted
            }
            .fullScreenCover(isPresented: $showFullscreen) {
                FullscreenVideoPlayer(player: videoPlayerManager.player, isPresented: $showFullscreen)
            }
            .task {
                logger.info("🎬 SHARED_VIDEO_PLAYER: RenderStart: representable", metadata: nil)
                Self.playerViewInstanceCount += 1
                logger.info("🎬 SHARED_VIDEO_PLAYER: 🔄 AVPlayerViewRepresentable task started (Instance #\(Self.playerViewInstanceCount), Recompute #\(Self.viewRecomputeCount))", metadata: nil)
                logMemoryUsage(context: "playing_task_start")
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer status: \(videoPlayerManager.playerStatus.rawValue)", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer currentItem exists: \(videoPlayerManager.player.currentItem != nil)", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: ✅ USING SHARED PLAYER - ELIMINATING LIFECYCLE ISSUES!", metadata: nil)
                
                // Final diagnostic during rendering
                logger.info("🎬 SHARED_VIDEO_PLAYER: 📋 DIAGNOSTIC DURING RENDERING (Player ready: \(videoPlayerManager.isPlayerReady))", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer exists: ✅", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer status: \(videoPlayerManager.playerStatus.rawValue) (\(videoPlayerManager.playerStatus == .readyToPlay ? "readyToPlay" : videoPlayerManager.playerStatus == .failed ? "failed" : "unknown"))", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer rate: \(videoPlayerManager.player.rate)", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer timeControlStatus: \(videoPlayerManager.player.timeControlStatus.rawValue) (\(videoPlayerManager.player.timeControlStatus == .playing ? "playing" : videoPlayerManager.player.timeControlStatus == .paused ? "paused" : "waiting"))", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer currentItem exists: \(videoPlayerManager.player.currentItem != nil)", metadata: nil)
                if let currentItem = videoPlayerManager.player.currentItem {
                    logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer currentItem status: \(currentItem.status.rawValue) (\(currentItem.status == .readyToPlay ? "readyToPlay" : currentItem.status == .failed ? "failed" : "unknown"))", metadata: nil)
                    logger.info("🎬 SHARED_VIDEO_PLAYER: AVPlayer currentItem error: \(String(describing: currentItem.error))", metadata: nil)
                }
                
                logMemoryUsage(context: "playing_task_end")
                logger.info("🎬 SHARED_VIDEO_PLAYER: 🎬 AVPlayerViewRepresentable should be rendering now! (Recompute #\(Self.viewRecomputeCount))", metadata: nil)
                logger.info("🎬 SHARED_VIDEO_PLAYER: Tap gesture handling built into UIViewRepresentable!", metadata: nil)
            }
    }
    
    // MARK: - Loading Content
    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            Text("Loading video...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Helper Methods
    
    private func logMemoryUsage(context: String) {
        // Get memory information
        let memoryInfo = getMemoryInfo()
        
        // Log memory usage with context
        logger.info("🎬 SHARED_VIDEO_PLAYER: Memory Usage (\(context)) - Used: \(memoryInfo.usedMB)MB, Free: \(memoryInfo.freeMB)MB, Total: \(memoryInfo.totalMB)MB", metadata: nil)
        
        // Log CPU usage if available
        if let cpuUsage = getCPUUsage() {
            logger.info("🎬 SHARED_VIDEO_PLAYER: CPU Usage (\(context)): \(String(format: "%.1f", cpuUsage))%", metadata: nil)
        }
    }
    
    private func getCPUUsage() -> Double? {
        // Simplified CPU usage measurement for logging - returns nil for now
        // TODO: Implement proper CPU measurement if needed for production logging
        return nil
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
        private let logger = AppContainer.shared.logger
        private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        
        var body: some View {
            logger.info("🎬 FULLSCREEN_PLAYER: Rendering fullscreen player", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player status: \(player.status.rawValue)", metadata: nil)
            logger.info("🎬 FULLSCREEN_PLAYER: Player rate: \(player.rate)", metadata: nil)
            
            return ZStack(alignment: Alignment.topLeading) {
                AVPlayerViewRepresentable(player: player)
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

