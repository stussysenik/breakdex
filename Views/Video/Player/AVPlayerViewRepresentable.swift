//
//  AVPlayerViewRepresentable.swift
//  BreakingFlashcards
//
//  Single Responsibility: Provide reliable AVPlayer rendering in SwiftUI
//  Replaces SwiftUI VideoPlayer with AVFoundation direct access for stability
//  UPDATED: Restored UI-level rotation for immediate visual feedback
//  Provides instant rotation feedback while asset-level rotation processes in background
//

import SwiftUI
import AVFoundation
import OSLog

/// UIViewRepresentable wrapper for AVPlayer using AVPlayerLayer
/// Single Responsibility: Display AVPlayer content reliably in SwiftUI
/// Eliminates SwiftUI VideoPlayer crashes while maintaining identical UX
/// FIXED: Removed UI-level rotation to prevent conflicts with data-layer rotation
/// Rotation is now handled exclusively by VideoTransformBuilder at the asset level
struct AVPlayerViewRepresentable: UIViewRepresentable {
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "AVPlayerViewRepresentable")
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AVPlayerView")

    let player: AVPlayer
    let metadata: [AVMetadataItem]?

    init(player: AVPlayer, metadata: [AVMetadataItem]? = nil) {
        diagnosticLogger.startTiming("representable_initialization")

        let initMemory = diagnosticLogger.getMemoryInfo()
        let initCPU = diagnosticLogger.getCurrentCPUUsage()

        self.player = player
        self.metadata = metadata

        diagnosticLogger.logInfo("🎬 AVPlayerViewRepresentable initializing", metadata: [
            "player_status": "\(player.status.rawValue)",
            "player_item_exists": "\(player.currentItem != nil)",
            "metadata_provided": "\(metadata != nil)",
            "memory_usage_mb": "\(String(format: "%.1f", initMemory.used))",
            "cpu_usage_percent": "\(String(format: "%.1f", initCPU))"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: init called")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer status: \(player.status.rawValue)")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer currentItem exists: \(player.currentItem != nil)")
        logger.info("🎬 AV_PLAYER_VIEW: Metadata provided: \(metadata != nil)")
        if let item = player.currentItem {
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem status: \(item.status.rawValue)")
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem duration: \(item.duration.seconds)")
            diagnosticLogger.logDebug("📹 Player item details", metadata: [
                "item_duration_seconds": "\(item.duration.seconds)",
                "item_status": "\(item.status.rawValue)",
                "item_error": "\(item.error?.localizedDescription ?? "none")"
            ])
        }

        diagnosticLogger.stopTiming("representable_initialization")
    }
    
    func makeUIView(context: Context) -> PlayerView {
        diagnosticLogger.startTiming("make_uiview")

        let makeMemory = diagnosticLogger.getMemoryInfo()
        let makeCPU = diagnosticLogger.getCurrentCPUUsage()

        diagnosticLogger.logInfo("🔧 Creating UIView for AVPlayer rendering", metadata: [
            "memory_usage_mb": "\(String(format: "%.1f", makeMemory.used))",
            "cpu_usage_percent": "\(String(format: "%.1f", makeCPU))",
            "player_status": "\(player.status.rawValue)",
            "player_ready": "\(player.status == .readyToPlay)"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: makeUIView called")

        let playerView = PlayerView()

        // Configure player layer
        playerView.playerLayer.player = player
        playerView.playerLayer.videoGravity = .resizeAspect

        diagnosticLogger.logDebug("⚙️ Player layer configured", metadata: [
            "video_gravity": "resizeAspect",
            "player_assigned": "true"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: PlayerView created successfully")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayerLayer configured with videoGravity: resizeAspect")

        // Add tap gesture for play/pause (maintaining UX compatibility)
        let tapGesture = UITapGestureRecognizer(target: playerView, action: #selector(PlayerView.handleTap))
        playerView.addGestureRecognizer(tapGesture)
        playerView.isUserInteractionEnabled = true

        diagnosticLogger.logDebug("👆 Tap gesture configured", metadata: [
            "gesture_enabled": "true",
            "user_interaction_enabled": "true"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: Tap gesture recognizer added for play/pause")

        let postMakeMemory = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("✅ UIView creation completed", metadata: [
            "memory_after_mb": "\(String(format: "%.1f", postMakeMemory.used))",
            "memory_increase_mb": "\(String(format: "%.1f", postMakeMemory.used - makeMemory.used))",
            "player_view_ready": "true"
        ])

        diagnosticLogger.stopTiming("make_uiview")
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        diagnosticLogger.startTiming("update_uiview")

        let updateMemory = diagnosticLogger.getMemoryInfo()
        let currentRotation = uiView.playerLayer.player != nil ? "player_assigned" : "no_player"

        diagnosticLogger.logInfo("🔄 Updating UIView for AVPlayer", metadata: [
            "memory_usage_mb": "\(String(format: "%.1f", updateMemory.used))",
            "player_status": "\(player.status.rawValue)",
            "player_assigned": "\(uiView.playerLayer.player !== player ? "needs_update" : "current")"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: updateUIView called")

        // Update player if needed
        if uiView.playerLayer.player !== player {
            diagnosticLogger.logInfo("🔄 Player reference needs update", metadata: [
                "old_player_status": "\(uiView.playerLayer.player?.status.rawValue ?? -1)",
                "new_player_status": "\(player.status.rawValue)"
            ])
            logger.info("🎬 AV_PLAYER_VIEW: Updating player reference")
            uiView.playerLayer.player = player
            diagnosticLogger.logDebug("✅ Player reference updated successfully")
        }

        let postUpdateMemory = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("✅ UIView update completed", metadata: [
            "memory_after_mb": "\(String(format: "%.1f", postUpdateMemory.used))",
            "memory_change_mb": "\(String(format: "%.1f", postUpdateMemory.used - updateMemory.used))",
            "player_sync": "\(uiView.playerLayer.player === player)"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: updateUIView completed")
        diagnosticLogger.stopTiming("update_uiview")
    }
    
    /// Private UIView subclass that provides AVPlayerLayer
    /// Single Responsibility: Host AVPlayerLayer for video rendering
    class PlayerView: UIView {
        private let diagnosticLogger = DiagnosticLoggingHelper(category: "PlayerView")
        private let logger = Logger(subsystem: "com.breakingflashcards", category: "PlayerView")

        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        // MARK: - Rotation Support Removed
        // Rotation is now handled exclusively at the asset level by VideoTransformBuilder
        // This prevents conflicts between view-layer and data-layer transformations
        
        override init(frame: CGRect) {
            diagnosticLogger.startTiming("player_view_init")

            let initMemory = diagnosticLogger.getMemoryInfo()

            super.init(frame: frame)

            diagnosticLogger.logInfo("🔧 PlayerView initializing", metadata: [
                "frame_size": "\(frame.size)",
                "frame_origin": "\(frame.origin)",
                "memory_usage_mb": "\(String(format: "%.1f", initMemory.used))"
            ])

            logger.info("🎬 PLAYER_VIEW: init called")

            // Configure layer
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor

            diagnosticLogger.logDebug("⚙️ AVPlayerLayer configured", metadata: [
                "video_gravity": "resizeAspect",
                "background_color": "black"
            ])

            let postInitMemory = diagnosticLogger.getMemoryInfo()
            diagnosticLogger.logInfo("✅ PlayerView initialization completed", metadata: [
                "memory_after_mb": "\(String(format: "%.1f", postInitMemory.used))",
                "memory_increase_mb": "\(String(format: "%.1f", postInitMemory.used - initMemory.used))",
                "layer_ready": "true"
            ])

            logger.info("🎬 PLAYER_VIEW: AVPlayerLayer configured")
            diagnosticLogger.stopTiming("player_view_init")
        }

        required init?(coder: NSCoder) {
            diagnosticLogger.logWarning("⚠️ PlayerView init(coder:) called - not implemented")
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            diagnosticLogger.startTiming("layout_subviews")

            let layoutMemory = diagnosticLogger.getMemoryInfo()

            diagnosticLogger.logInfo("📐 LayoutSubviews called", metadata: [
                "frame_size": "\(self.frame.size)",
                "frame_origin": "\(self.frame.origin)",
                "bounds_size": "\(self.bounds.size)",
                "memory_usage_mb": "\(String(format: "%.1f", layoutMemory.used))"
            ])

            super.layoutSubviews()

            logger.info("🎬 PLAYER_VIEW: layoutSubviews called")
            logger.info("🎬 PLAYER_VIEW: Frame: \(String(describing: self.frame))")
            logger.info("🎬 PLAYER_VIEW: Bounds: \(String(describing: self.bounds))")

            diagnosticLogger.logDebug("📏 Layout details", metadata: [
                "frame_width": "\(self.frame.width)",
                "frame_height": "\(self.frame.height)",
                "bounds_width": "\(self.bounds.width)",
                "bounds_height": "\(self.bounds.height)",
                "center_x": "\(self.center.x)",
                "center_y": "\(self.center.y)"
            ])

            let postLayoutMemory = diagnosticLogger.getMemoryInfo()
            diagnosticLogger.logInfo("✅ LayoutSubviews completed", metadata: [
                "memory_after_mb": "\(String(format: "%.1f", postLayoutMemory.used))",
                "memory_change_mb": "\(String(format: "%.1f", postLayoutMemory.used - layoutMemory.used))"
            ])

            diagnosticLogger.stopTiming("layout_subviews")
        }
        
        @objc func handleTap() {
            diagnosticLogger.startTiming("handle_tap")

            let tapMemory = diagnosticLogger.getMemoryInfo()

            diagnosticLogger.logUserInteraction("video_tap_playback_toggle", metadata: [
                "memory_usage_mb": "\(String(format: "%.1f", tapMemory.used))",
                "bounds_size": "\(self.bounds.size)"
            ])

            guard let player = playerLayer.player else {
                diagnosticLogger.logWarning("⚠️ Tap received but no player assigned")
                logger.warning("🎬 PLAYER_VIEW: Tap received but no player assigned")
                return
            }

            diagnosticLogger.logInfo("👆 Video tap detected - toggling playback", metadata: [
                "current_rate": "\(player.rate)",
                "time_control_status": "\(player.timeControlStatus.rawValue)",
                "current_time_seconds": "\(player.currentTime().seconds)",
                "duration_seconds": "\(player.currentItem?.duration.seconds ?? 0)"
            ])

            logger.info("🎬 PLAYER_VIEW: Video tapped - toggling playback")
            logger.info("🎬 PLAYER_VIEW: Current player rate: \(player.rate)")
            logger.info("🎬 PLAYER_VIEW: Current timeControlStatus: \(player.timeControlStatus.rawValue)")

            let wasPlaying = player.rate != 0

            if player.rate == 0 {
                diagnosticLogger.logInfo("▶️ Starting video playback")
                logger.info("🎬 PLAYER_VIEW: Starting playback")
                player.play()
            } else {
                diagnosticLogger.logInfo("⏸️ Pausing video playback")
                logger.info("🎬 PLAYER_VIEW: Pausing playback")
                player.pause()
            }

            diagnosticLogger.logInfo("✅ Playback toggled", metadata: [
                "was_playing": "\(wasPlaying)",
                "now_playing": "\(player.rate != 0)",
                "new_rate": "\(player.rate)",
                "new_time_control_status": "\(player.timeControlStatus.rawValue)"
            ])

            logger.info("🎬 PLAYER_VIEW: New player rate: \(player.rate)")
            diagnosticLogger.stopTiming("handle_tap")
        }


        deinit {
            Task { @MainActor in
                diagnosticLogger.startTiming("player_view_deinit")

                let deinitMemory = diagnosticLogger.getMemoryInfo()

                diagnosticLogger.logInfo("🗑️ PlayerView deinitializing", metadata: [
                    "final_memory_usage_mb": "\(String(format: "%.1f", deinitMemory.used))",
                    "had_player": "\(playerLayer.player != nil)",
                    "final_bounds": "\(self.bounds.size)",
                    "active_timers": "\(diagnosticLogger.getActiveTimerNames())"
                ])

                logger.info("🎬 PLAYER_VIEW: deinit called")

                // Clean up player reference
                if playerLayer.player != nil {
                    diagnosticLogger.logDebug("🧹 Clearing player reference")
                    playerLayer.player = nil
                }

                diagnosticLogger.logPerformanceSummary()
                diagnosticLogger.stopTiming("player_view_deinit")
            }
        }
    }
}

// MARK: - UIViewRepresentable Extension for Logging
extension AVPlayerViewRepresentable {
    func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        diagnosticLogger.startTiming("dismantle_uiview")

        let dismantleMemory = diagnosticLogger.getMemoryInfo()

        diagnosticLogger.logInfo("🧹 Dismantling UIView", metadata: [
            "memory_usage_mb": "\(String(format: "%.1f", dismantleMemory.used))",
            "had_player": "\(uiView.playerLayer.player != nil)",
            "player_status": "\(uiView.playerLayer.player?.status.rawValue ?? -1)"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: dismantleUIView called")

        // Clean up player reference
        if uiView.playerLayer.player != nil {
            diagnosticLogger.logDebug("🗑️ Clearing player reference in dismantle")
            uiView.playerLayer.player = nil
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayer reference cleared")
        }

        let postDismantleMemory = diagnosticLogger.getMemoryInfo()
        diagnosticLogger.logInfo("✅ UIView dismantle completed", metadata: [
            "memory_after_mb": "\(String(format: "%.1f", postDismantleMemory.used))",
            "memory_freed_mb": "\(String(format: "%.1f", dismantleMemory.used - postDismantleMemory.used))",
            "player_cleared": "true"
        ])

        diagnosticLogger.stopTiming("dismantle_uiview")
    }
}

// MARK: - AVPlayer Extension for Compatibility
fileprivate extension AVPlayer {
    func togglePlayback() {
        if rate == 0 {
            play()
        } else {
            pause()
        }
    }
}
