import SwiftUI
import AVKit
import Combine
import OSLog
import UIKit

// Import the types we need from their respective files
// HandleType is defined in TrimmerViewModel.swift
// TrimmerViewModel is defined in TrimmerViewModel.swift

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
    
    // State for video player loading
    @State private var isPlayerReady = false
    @State private var playerViewModel: UpdatedVideoPlayerViewModel?
    
    private let asset: AVAsset
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "TrimmerView")
    
    // Haptic feedback generator
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    init(viewModel: AddMoveViewModel, asset: AVAsset, rotation: Int) {
        self.viewModel = viewModel
        self.asset = asset
        self._rotationQuarterTurns = State(initialValue: rotation)
        self._trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: asset, rotationQuarterTurns: rotation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The video player with loading state management
            if isPlayerReady, let playerViewModel = playerViewModel {
                CustomVideoPlayerView(viewModel: playerViewModel)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                // Loading state while player is being initialized
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                    Text("Loading video player...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(height: 300)
                .background(Color.black.ignoresSafeArea())
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // The trimmer UI component with dark capsule handles
            HybridPreciseTrimmerView.custom(
                viewModel: trimmerViewModel,
                startView: Capsule()
                    .fill(Color.gray.opacity(0.8))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 36, height: 36),
                endView: Capsule()
                    .fill(Color.gray.opacity(0.8))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .frame(width: 36, height: 36)
            )
            .padding()
            
            Spacer()
            
            // Action bar for trimming controls
            trimmerActionButtons
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            // Log body rendering state
            logger.info("🎬 TRIMMER_VIEW: 🖼️ Body rendering - isPlayerReady: \(isPlayerReady), playerViewModel exists: \(playerViewModel != nil)")
            
            if isPlayerReady, let playerViewModel = playerViewModel {
                logger.info("🎬 TRIMMER_VIEW: 🎬 RENDERING VIDEO PLAYER!")
                logger.info("🎬 TRIMMER_VIEW: 📊 Player VM state: \(String(describing: playerViewModel.state))")
                logger.info("🎬 TRIMMER_VIEW: 📊 Player VM isPlayerReady: \(playerViewModel.isPlayerReady)")
            } else {
                logger.info("🎬 TRIMMER_VIEW: ⏳ RENDERING LOADING STATE")
                logger.info("🎬 TRIMMER_VIEW: 📊 isPlayerReady: \(isPlayerReady)")
                logger.info("🎬 TRIMMER_VIEW: 📊 playerViewModel: \(playerViewModel != nil)")
            }
        }
        .onChange(of: rotationQuarterTurns) {
            logger.info("🎬 TRIMMER_VIEW: 🔄 Rotation changed to \(rotationQuarterTurns)°")
            trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
            // Recreate player with new rotation
            logger.info("🎬 TRIMMER_VIEW: 🔄 Recreating player with new rotation...")
            playerViewModel = UpdatedVideoPlayerViewModel(
                asset: trimmerViewModel.asset,
                rotationQuarterTurns: rotationQuarterTurns,
                appContainer: AppContainer.shared
            )
            logger.info("🎬 TRIMMER_VIEW: 🔄 Player recreated with new rotation")
        }
        .onAppear {
            logger.info("🎬 TRIMMER_VIEW: 👁️ VIEW APPEARING!")
            logger.info("🎬 TRIMMER_VIEW: 📊 Initial isPlayerReady: \(isPlayerReady)")
            // Initialize the player view model when the view appears
            initializePlayer()
        }
        .onDisappear {
            logger.info("🎬 TRIMMER_VIEW: 👋 VIEW DISAPPEARING!")
            // Clean up timeout task when view disappears
            playerTimeoutTask?.cancel()
            playerTimeoutTask = nil
        }
        .task {
            logger.info("🎬 TRIMMER_VIEW: 📋 Starting trimmer view model setup task...")
            // Wait for the trimmer view model to be ready
            do {
                logger.info("🎬 TRIMMER_VIEW: ⚙️ Calling trimmerViewModel.setupAsync()...")
                try await trimmerViewModel.setupAsync()
                logger.info("🎬 TRIMMER_VIEW: ✅ TrimmerViewModel setup completed")
                
                logger.info("🎬 TRIMMER_VIEW: 🖼️ Calling trimmerViewModel.updatePreview()...")
                await trimmerViewModel.updatePreview()
                logger.info("🎬 TRIMMER_VIEW: ✅ TrimmerViewModel preview updated")
            } catch {
                // Handle the error appropriately
                logger.error("🎬 TRIMMER_VIEW: ❌ Failed to setup trimmer view model: \(error.localizedDescription)")
                logger.error("🎬 TRIMMER_VIEW: ❌ Error type: \(type(of: error))")
                // Optionally, we can show an error state to the user
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializePlayer() {
        logger.info("🎬 TRIMMER_VIEW: 🚀 Starting player initialization")
        logger.info("🎬 TRIMMER_VIEW: 📊 TrimmerViewModel asset: \(trimmerViewModel.asset)")
        logger.info("🎬 TRIMMER_VIEW: 📊 Rotation: \(rotationQuarterTurns)°")
        logger.info("🎬 TRIMMER_VIEW: 📊 Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        
        // Check if asset is valid before creating player
        logger.info("🎬 TRIMMER_VIEW: 🔍 Validating asset...")
        if let urlAsset = trimmerViewModel.asset as? AVURLAsset {
            logger.info("🎬 TRIMMER_VIEW: ✅ Asset is URL asset: \(urlAsset.url)")
            logger.info("🎬 TRIMMER_VIEW: 📊 Asset duration: \(urlAsset.duration.seconds)s")
        } else {
            logger.info("🎬 TRIMMER_VIEW: ⚠️ Asset is not a URL asset: \(type(of: trimmerViewModel.asset))")
        }
        
        logger.info("🎬 TRIMMER_VIEW: 🏗️ Creating UpdatedVideoPlayerViewModel...")
        // Create the player view model
        playerViewModel = UpdatedVideoPlayerViewModel(
            asset: trimmerViewModel.asset,
            rotationQuarterTurns: rotationQuarterTurns,
            appContainer: AppContainer.shared
        )
        
        // Set up a publisher to monitor when the player is ready
        if let playerViewModel = playerViewModel {
            logger.info("🎬 TRIMMER_VIEW: 🎯 Setting up state monitoring...")
            logger.info("🎬 TRIMMER_VIEW: 📊 Initial player state: \(String(describing: playerViewModel.state))")
            
            // Using Combine to monitor the player state with proper enum checking
            playerViewModel.$state
                .handleEvents(
                    receiveSubscription: { _ in
                        logger.info("🎬 TRIMMER_VIEW: 📡 State monitoring subscription started")
                    },
                    receiveOutput: { state in
                        logger.info("🎬 TRIMMER_VIEW: 📊 Player state changed: \(String(describing: state))")
                    },
                    receiveCompletion: { _ in
                        logger.info("🎬 TRIMMER_VIEW: 📡 State monitoring completed")
                    },
                    receiveCancel: {
                        logger.info("🎬 TRIMMER_VIEW: 📡 State monitoring cancelled")
                    }
                )
                .compactMap { state in
                    logger.info("🎬 TRIMMER_VIEW: 🔍 Processing state: \(String(describing: state))")
                    switch state {
                    case .playing:
                        logger.info("🎬 TRIMMER_VIEW: ✅ Detected playing state - player is ready!")
                        return true
                    case .loading:
                        logger.info("🎬 TRIMMER_VIEW: ⏳ Player still loading...")
                        return false
                    case .error(let message):
                        logger.error("🎬 TRIMMER_VIEW: ❌ Player error state: \(message)")
                        return false
                    }
                }
                .receive(on: RunLoop.main)
                .sink { [self] isReady in
                    logger.info("🎬 TRIMMER_VIEW: 🎯 State processor result: isReady=\(isReady)")
                    if isReady {
                        logger.info("🎬 TRIMMER_VIEW: 🎉 SETTING isPlayerReady = true!")
                        isPlayerReady = true
                        logger.info("🎬 TRIMMER_VIEW: 📊 Player is now ready and should be playing")
                        logger.info("🎬 TRIMMER_VIEW: 📊 isPlayerReady flag: \(isPlayerReady)")
                        logger.info("🎬 TRIMMER_VIEW: 📊 Player VM isPlayerReady: \(playerViewModel.isPlayerReady)")
                    }
                }
                .store(in: &cancellables)
                
            logger.info("🎬 TRIMMER_VIEW: ✅ State monitoring pipeline configured")
        } else {
            logger.error("🎬 TRIMMER_VIEW: ❌ Failed to create player view model - playerViewModel is nil")
        }
        
        // Set up timeout detection for player initialization
        logger.info("🎬 TRIMMER_VIEW: ⏰ Setting up 10-second timeout detection...")
        playerTimeoutTask = Task {
            do {
                logger.info("🎬 TRIMMER_VIEW: ⏳ Timeout task started - waiting 10 seconds...")
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
                
                if !isPlayerReady {
                    await MainActor.run {
                        logger.error("🎬 TRIMMER_VIEW: ⏰ TIMEOUT! Player not ready after 10 seconds")
                        logger.error("🎬 TRIMMER_VIEW: ⏰ Current isPlayerReady: \(isPlayerReady)")
                        logger.error("🎬 TRIMMER_VIEW: ⏰ Forcing isPlayerReady = true to show UI")
                        logger.error("🎬 TRIMMER_VIEW: ⏰ Video may not display properly")
                        // Force set player ready to show UI even if video doesn't load
                        isPlayerReady = true
                    }
                } else {
                    logger.info("🎬 TRIMMER_VIEW: ✅ Player became ready before timeout!")
                }
            } catch {
                logger.info("🎬 TRIMMER_VIEW: ✅ Timeout task cancelled - player likely initialized successfully")
            }
        }
        
        logger.info("🎬 TRIMMER_VIEW: 🚀 Player initialization process completed")
    }
    
    // Combine cancellables
    @State private var cancellables = Set<AnyCancellable>()
    
    // Timeout task for player initialization
    @State private var playerTimeoutTask: Task<Void, Never>?
    
    private var trimmerActionButtons: some View {
        HStack(spacing: 20) {
            Button("Cancel") {
                impactGenerator.impactOccurred()
                viewModel.cancelTrimming()
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button(action: {
                impactGenerator.impactOccurred()
                rotationQuarterTurns = (rotationQuarterTurns + 1) % 4
            }) {
                Image(systemName: "rotate.right")
            }
            .buttonStyle(.appSecondary(size: .medium))
            
            Button("Save") {
                impactGenerator.impactOccurred()
                viewModel.finishTrimming(with: trimmerViewModel)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(trimmerViewModel.isExporting)
        }
        .padding()
        .padding(.bottom, 180)
    }
}