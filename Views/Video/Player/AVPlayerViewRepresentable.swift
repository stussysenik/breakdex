//
//  AVPlayerViewRepresentable.swift
//  BreakingFlashcards
//
//  Single Responsibility: Provide reliable AVPlayer rendering in SwiftUI
//  Replaces SwiftUI VideoPlayer with AVFoundation direct access for stability
//

import SwiftUI
import AVFoundation
import OSLog

/// UIViewRepresentable wrapper for AVPlayer using AVPlayerLayer
/// Single Responsibility: Display AVPlayer content reliably in SwiftUI
/// Eliminates SwiftUI VideoPlayer crashes while maintaining identical UX
struct AVPlayerViewRepresentable: UIViewRepresentable {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "AVPlayerView")
    
    let player: AVPlayer
    let metadata: [AVMetadataItem]?
    
    init(player: AVPlayer, metadata: [AVMetadataItem]? = nil) {
        self.player = player
        self.metadata = metadata
        logger.info("🎬 AV_PLAYER_VIEW: init called")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer status: \(player.status.rawValue)")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer currentItem exists: \(player.currentItem != nil)")
        logger.info("🎬 AV_PLAYER_VIEW: Metadata provided: \(metadata != nil)")
        if let item = player.currentItem {
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem status: \(item.status.rawValue)")
            logger.info("🎬 AV_PLAYER_VIEW: AVPlayerItem duration: \(CMTimeGetSeconds(item.duration))")
        }
    }
    
    func makeUIView(context: Context) -> PlayerView {
        logger.info("🎬 AV_PLAYER_VIEW: makeUIView called")
        
        let playerView = PlayerView()
        playerView.playerLayer.player = player
        playerView.playerLayer.videoGravity = .resizeAspect
        
        logger.info("🎬 AV_PLAYER_VIEW: PlayerView created successfully")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayerLayer configured with videoGravity: resizeAspect")
        
        // Add tap gesture for play/pause (maintaining UX compatibility)
        let tapGesture = UITapGestureRecognizer(target: playerView, action: #selector(PlayerView.handleTap))
        playerView.addGestureRecognizer(tapGesture)
        playerView.isUserInteractionEnabled = true
        
        logger.info("🎬 AV_PLAYER_VIEW: Tap gesture recognizer added for play/pause")
        return playerView
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        logger.info("🎬 AV_PLAYER_VIEW: updateUIView called")
        
        // Update player if needed
        if uiView.playerLayer.player !== player {
            logger.info("🎬 AV_PLAYER_VIEW: Updating player reference")
            uiView.playerLayer.player = player
        }
        
        logger.info("🎬 AV_PLAYER_VIEW: updateUIView completed")
    }
    
    /// Private UIView subclass that provides AVPlayerLayer
    /// Single Responsibility: Host AVPlayerLayer for video rendering
    class PlayerView: UIView {
        private let logger = Logger(subsystem: "com.breakingflashcards", category: "PlayerView")
        
        override class var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            logger.info("🎬 PLAYER_VIEW: init called")
            
            // Configure layer
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
            
            logger.info("🎬 PLAYER_VIEW: AVPlayerLayer configured")
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            logger.info("🎬 PLAYER_VIEW: layoutSubviews called")
            logger.info("🎬 PLAYER_VIEW: Frame: \(String(describing: self.frame))")
            logger.info("🎬 PLAYER_VIEW: Bounds: \(String(describing: self.bounds))")
        }
        
        @objc func handleTap() {
            guard let player = playerLayer.player else {
                logger.warning("🎬 PLAYER_VIEW: Tap received but no player assigned")
                return
            }
            
            logger.info("🎬 PLAYER_VIEW: Video tapped - toggling playback")
            logger.info("🎬 PLAYER_VIEW: Current player rate: \(player.rate)")
            logger.info("🎬 PLAYER_VIEW: Current timeControlStatus: \(player.timeControlStatus.rawValue)")
            
            if player.rate == 0 {
                logger.info("🎬 PLAYER_VIEW: Starting playback")
                player.play()
            } else {
                logger.info("🎬 PLAYER_VIEW: Pausing playback")
                player.pause()
            }
            
            logger.info("🎬 PLAYER_VIEW: New player rate: \(player.rate)")
        }
        
        deinit {
            logger.info("🎬 PLAYER_VIEW: deinit called")
        }
    }
}

// MARK: - UIViewRepresentable Extension for Logging
extension AVPlayerViewRepresentable {
    func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        logger.info("🎬 AV_PLAYER_VIEW: dismantleUIView called")
        uiView.playerLayer.player = nil
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer reference cleared")
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
