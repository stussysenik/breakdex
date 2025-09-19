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
    let rotationQuarterTurns: Int
    
    init(player: AVPlayer, metadata: [AVMetadataItem]? = nil, rotationQuarterTurns: Int = 0) {
        self.player = player
        self.metadata = metadata
        self.rotationQuarterTurns = rotationQuarterTurns
        logger.info("🎬 AV_PLAYER_VIEW: init called")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer status: \(player.status.rawValue)")
        logger.info("🎬 AV_PLAYER_VIEW: AVPlayer currentItem exists: \(player.currentItem != nil)")
        logger.info("🎬 AV_PLAYER_VIEW: Metadata provided: \(metadata != nil)")
        logger.info("🎬 AV_PLAYER_VIEW: Rotation quarter turns: \(rotationQuarterTurns)")
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
        playerView.rotationQuarterTurns = rotationQuarterTurns
        
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
        
        // Update rotation if needed
        if uiView.rotationQuarterTurns != rotationQuarterTurns {
            logger.info("🎬 AV_PLAYER_VIEW: Updating rotation from \(uiView.rotationQuarterTurns) to \(rotationQuarterTurns)")
            uiView.rotationQuarterTurns = rotationQuarterTurns
            uiView.applyRotation()
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
        
        var rotationQuarterTurns: Int = 0 {
            didSet {
                logger.info("🎬 PLAYER_VIEW: Rotation quarter turns changed to \(self.rotationQuarterTurns)")
                applyRotation()
            }
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
        
        // MARK: - Rotation Methods
        
        func applyRotation() {
            guard rotationQuarterTurns > 0 else {
                logger.info("🎬 PLAYER_VIEW: No rotation needed (rotationQuarterTurns: \(self.rotationQuarterTurns))")
                playerLayer.transform = CATransform3DIdentity
                return
            }
            
            logger.info("🎬 PLAYER_VIEW: Applying rotation: \(self.rotationQuarterTurns) quarter turns (\(self.rotationQuarterTurns * 90)°)")
            
            // Calculate rotation angle in radians
            let rotationAngle = CGFloat.pi / 2 * CGFloat(self.rotationQuarterTurns)
            
            // Apply rotation transform
            let rotationTransform = CATransform3DMakeRotation(rotationAngle, 0, 0, 1)
            playerLayer.transform = rotationTransform
            
            logger.info("🎬 PLAYER_VIEW: Rotation transform applied successfully")
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
