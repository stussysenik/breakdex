//
//  AVPlayerViewRepresentable.swift
//  BreakingFlashcards
//
//  Single Responsibility: Provide reliable AVPlayer rendering in SwiftUI
//  Replaces SwiftUI VideoPlayer with AVFoundation direct access for stability
//  UPDATED: Implemented Coordinator pattern to handle race conditions where the
//  player's currentItem is not yet ready when the view is created.
//

import SwiftUI
import AVFoundation
import OSLog

/// UIViewRepresentable wrapper for AVPlayer using AVPlayerLayer
/// Single Responsibility: Display AVPlayer content reliably in SwiftUI
/// Eliminates SwiftUI VideoPlayer crashes while maintaining identical UX
/// FIXED: Implemented Coordinator pattern to resolve race condition during view transitions
/// Now properly waits for player item readiness before rendering video content
struct AVPlayerViewRepresentable: UIViewRepresentable {
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "AVPlayerViewRepresentable")
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AVPlayerView")

    let metadata: [AVMetadataItem]?
    let viewModel: any VideoPlayerViewModelProtocol
    let playerItem: AVPlayerItem? // 🎯 CRITICAL FIX: Track player item for state synchronization

    init(metadata: [AVMetadataItem]? = nil, viewModel: any VideoPlayerViewModelProtocol, playerItem: AVPlayerItem?) {
        diagnosticLogger.startTiming("representable_initialization")

        let initMemory = diagnosticLogger.getMemoryInfo()
        let initCPU = diagnosticLogger.getCurrentCPUUsage()

        self.metadata = metadata
        self.viewModel = viewModel
        self.playerItem = playerItem // 🎯 CRITICAL FIX: Assign player item for state synchronization

        diagnosticLogger.logInfo("🎬 AVPlayerViewRepresentable initializing", metadata: [
            "metadata_provided": "\(metadata != nil)",
            "view_model_type": "\(type(of: viewModel))",
            "player_item_provided": "\(playerItem != nil)",
            "memory_usage_mb": "\(String(format: "%.1f", initMemory.used))",
            "cpu_usage_percent": "\(String(format: "%.1f", initCPU))"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: init called")
        logger.info("🎬 AV_PLAYER_VIEW: Using viewModel as single source of truth")
        logger.info("🎬 AV_PLAYER_VIEW: Metadata provided: \(metadata != nil)")
        logger.info("🎬 AV_PLAYER_VIEW: PlayerItem provided: \(playerItem != nil)") // 🎯 CRITICAL FIX: Log player item status

        if let player = viewModel.avPlayer {
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayer status: \(player.status.rawValue)")
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayer currentItem exists: \(player.currentItem != nil)")
            if let item = player.currentItem {
                logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem status: \(item.status.rawValue)")
                logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem duration: \(item.duration.seconds)")
                diagnosticLogger.logDebug("📹 Player item details", metadata: [
                    "item_duration_seconds": "\(item.duration.seconds)",
                    "item_status": "\(item.status.rawValue)",
                    "item_error": "\(item.error?.localizedDescription ?? "none")"
                ])
            }
        } else {
            logger.warning("🎬 AV_PLAYER_VIEW: AVPlayer is nil")
        }

        diagnosticLogger.stopTiming("representable_initialization")
    }

    // MARK: - Coordinator Pattern

    func makeCoordinator() -> Coordinator {
        diagnosticLogger.startTiming("coordinator_creation")

        let coordinator = Coordinator(viewModel: viewModel, logger: logger, diagnosticLogger: diagnosticLogger)

        diagnosticLogger.logInfo("🔧 Coordinator created", metadata: [
            "coordinator_type": "\(type(of: coordinator))",
            "view_model_type": "\(type(of: viewModel))"
        ])

        logger.info("🎬 AV_PLAYER_VIEW: Coordinator created")
        diagnosticLogger.stopTiming("coordinator_creation")

        return coordinator
    }

    class Coordinator: NSObject {
        let viewModel: any VideoPlayerViewModelProtocol
        let logger: Logger
        let diagnosticLogger: DiagnosticLoggingHelper

        // SIMPLIFIED: Removed all KVO logic - ViewModel is now single source of truth
        init(viewModel: any VideoPlayerViewModelProtocol, logger: Logger, diagnosticLogger: DiagnosticLoggingHelper) {
            self.viewModel = viewModel
            self.logger = logger
            self.diagnosticLogger = diagnosticLogger
            super.init()
            logger.info("🎬 COORDINATOR: Initialized with viewModel (Simplified)")
        }
    }
    
    func makeUIView(context: Context) -> PlayerView {
        diagnosticLogger.startTiming("make_uiview")
        logger.info("🎬 AV_PLAYER_VIEW: makeUIView called (Simplified)")

        let playerView = PlayerView()
        playerView.playerLayer.videoGravity = .resizeAspect

        // SIMPLIFIED: Directly assign the player if the ViewModel confirms it's ready.
        // The ViewModel is now the single source of truth for readiness.
        if viewModel.isPlayerReady {
            playerView.playerLayer.player = viewModel.avPlayer
            logger.info("🎬 AV_PLAYER_VIEW: Player assigned on creation because ViewModel is ready.")
        }

        // Add tap gesture for play/pause
        let tapGesture = UITapGestureRecognizer(target: playerView, action: #selector(PlayerView.handleTap))
        playerView.addGestureRecognizer(tapGesture)
        playerView.isUserInteractionEnabled = true

        diagnosticLogger.stopTiming("make_uiview")
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        diagnosticLogger.startTiming("update_uiview")
        logger.info("🎬 AV_PLAYER_VIEW: updateUIView called (Simplified)")

        // SIMPLIFIED: Synchronize the view's player with the ViewModel's player.
        // This is the core of the fix. It relies on SwiftUI's update cycle.
        if uiView.playerLayer.player !== viewModel.avPlayer {
            if viewModel.isPlayerReady {
                logger.info("🎬 AV_PLAYER_VIEW: Syncing player to layer.")
                uiView.playerLayer.player = viewModel.avPlayer
            } else {
                // If the player isn't ready, ensure we don't show a stale frame.
                logger.info("🎬 AV_PLAYER_VIEW: Player not ready, clearing layer.")
                uiView.playerLayer.player = nil
            }
        }

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
            // Note: deinit runs on whatever thread the object is deallocated on
            // We need to ensure cleanup happens on main thread for UI operations
            DispatchQueue.main.async {
                self.diagnosticLogger.startTiming("player_view_deinit")

                let deinitMemory = self.diagnosticLogger.getMemoryInfo()

                self.diagnosticLogger.logInfo("🗑️ PlayerView deinitializing", metadata: [
                    "final_memory_usage_mb": "\(String(format: "%.1f", deinitMemory.used))",
                    "had_player": "\(self.playerLayer.player != nil)",
                    "final_bounds": "\(self.bounds.size)",
                    "active_timers": "\(self.diagnosticLogger.getActiveTimerNames())"
                ])

                self.logger.info("🎬 PLAYER_VIEW: deinit called")

                // Clean up player reference
                if self.playerLayer.player != nil {
                    self.diagnosticLogger.logDebug("🧹 Clearing player reference")
                    self.playerLayer.player = nil
                }

                self.diagnosticLogger.logPerformanceSummary()
                self.diagnosticLogger.stopTiming("player_view_deinit")
            }
        }
    }
}

// MARK: - UIViewRepresentable Extension for Dismantling
extension AVPlayerViewRepresentable {
    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        let diagnosticLogger = DiagnosticLoggingHelper(category: "AVPlayerViewDismantle")
        let logger = Logger(subsystem: "com.breakingflashcards", category: "AVPlayerViewDismantle")
        logger.info("🎬 AV_PLAYER_VIEW: dismantleUIView called (Simplified)")

        // SIMPLIFIED: Clean up by removing the player from the layer.
        // This is the only cleanup now required from the representable.
        uiView.playerLayer.player = nil
        diagnosticLogger.logInfo("🧹 Dismantling UIView - Player reference cleared.")
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
