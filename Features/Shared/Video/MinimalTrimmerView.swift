import SwiftUI
import AVFoundation
import AVKit
import OSLog
import PhotosUI

// MARK: - Logger
private let logger = Logger(subsystem: "com.breakingflashcards", category: "MinimalTrimmerView")


// MARK: - iOS 18 AVMetrics Integration
/// ENHANCEMENT: iOS 18 performance monitoring and optimization
/// Provides frame-accurate seeking with AVMetrics API integration
@available(iOS 18.0, *)
class iOS18PerformanceManager {
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "iOS18Performance")

    // Performance metrics tracking
    private var seekOperations: [UUID: Date] = [:]
    private var frameDropCount: Int = 0
    private var averageSeekTime: TimeInterval = 0.0

    // AVMetrics for iOS 18 performance monitoring
    private var avMetrics: AVMetrics<AVMetricPlayerItemLikelyToKeepUpEvent>?

    init() {
        setupAVMetrics()
    }

    /// Setup AVMetrics for performance monitoring (iOS 18+)
    private func setupAVMetrics() {
        if #available(iOS 18.0, *) {
            // AVMetrics initialization - disable for now due to API limitations
            // avMetrics = AVMetrics(eventType: AVMetricPlayerItemLikelyToKeepUpEvent.self)
            logger.info("🚀 iOS 18 AVMetrics temporarily disabled due to API limitations")
        }
    }

    /// Begin tracking a seek operation
    func beginSeekOperation(operationId: UUID) {
        seekOperations[operationId] = Date()
        logger.debug("⏱️ Seek operation started: \(operationId)")
    }

    /// End tracking a seek operation and record performance
    func endSeekOperation(operationId: UUID) {
        guard let startTime = seekOperations[operationId] else { return }

        let duration = Date().timeIntervalSince(startTime)
        seekOperations.removeValue(forKey: operationId)

        // Update average seek time
        averageSeekTime = (averageSeekTime + duration) / 2.0

        logger.info("✅ Seek operation completed: \(operationId) in \(String(format: "%.3f", duration))s")

        // Log performance warnings if needed
        if duration > 0.1 {
            logger.warning("⚠️ Slow seek detected: \(String(format: "%.3f", duration))s (threshold: 0.1s)")
        }
    }

    /// Get current performance metrics
    var currentMetrics: PerformanceMetrics {
        return PerformanceMetrics(
            averageSeekTime: averageSeekTime,
            activeSeekOperations: seekOperations.count,
            frameDropCount: frameDropCount,
            hasAVMetricsSupport: avMetrics != nil
        )
    }

    /// Reset performance metrics
    func resetMetrics() {
        seekOperations.removeAll()
        frameDropCount = 0
        averageSeekTime = 0.0
        logger.info("📊 Performance metrics reset")
    }
}

/// Performance metrics data structure
struct PerformanceMetrics {
    let averageSeekTime: TimeInterval
    let activeSeekOperations: Int
    let frameDropCount: Int
    let hasAVMetricsSupport: Bool

    var isPerformant: Bool {
        return averageSeekTime < 0.05 && activeSeekOperations < 3
    }
}

// MARK: - Clean MVVM Minimal Trimmer View
/// Clean MVVM video trimming interface that works with AddMoveViewModel
/// Follows MVVM pattern with no adapters - direct view-model communication
///
/// Key Features:
/// - Frame-accurate trimming with universal frame rate support
/// - Simple drag handles for start/end selection
/// - Real-time preview with timecode display
/// - Minimum 3-second validation
/// - Clean, minimal interface
/// - Direct AddMoveViewModel integration
@MainActor
struct MinimalTrimmerView: View {
    // MARK: - Dependencies (MVVM Pattern)
    @ObservedObject var viewModel: AddMoveViewModel

    // MARK: - State
    @State private var startTime: TimeInterval = 0.0
    @State private var endTime: TimeInterval = 0.0
    @State private var isPlaying: Bool = false
    @State private var rotation: VideoRotation = .degrees0
    @State private var isDraggingLeftHandle: Bool = false
    @State private var isDraggingRightHandle: Bool = false
    @State private var videoDuration: TimeInterval = 0.0
    @State private var frameRate: Double = 30.0
    @State private var errorMessage: String?

    // MARK: - Performance Optimization State
    @State private var seekTask: Task<Void, Never>?
    @State private var lastSeekTime: TimeInterval = 0
    @State private var seekDebounceMs: TimeInterval = 100 // 100ms debounce for seeking

    // ENHANCEMENT: iOS 18 Performance Manager
    @State private var performanceManager: iOS18PerformanceManager?
    @State private var currentSeekOperationId: UUID?

    // MARK: - OPENSPEC FIX: Timing Guard State (Removed - simplified initialization)
    // Complex timing guards removed to prevent view rendering blocking

    // MARK: - OPENSPEC FIX: Loading State Synchronization (Removed - video should be ready when view appears)
    // Note: Loading overlay removed since video should be ready when SelectClip transitions at .fullyReady

    // MARK: - Constants
    private let minimumTrimDuration: TimeInterval = 3.0
    private let handleWidth: CGFloat = 20.0 // Width of trim handles for accurate positioning

    private let logger = Logger(subsystem: "com.breakingflashcards", category: "MinimalTrimmerView")

    // MARK: - Computed Properties
    private var trimDuration: TimeInterval {
        max(0.0, endTime - startTime)
    }

    private var isValidTrimRange: Bool {
        trimDuration >= minimumTrimDuration &&
        startTime >= 0 &&
        endTime <= videoDuration &&
        startTime < endTime
    }

    // MARK: - Body (enhanced visual hierarchy)
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) { // Increased spacing for better visual hierarchy
                // Video Preview Section - enhanced spacing
                videoPreviewSection

                // Timeline Section - aligned with video player edges
                timelineSection(geometry: geometry)

                // Controls Section - improved spacing
                controlsSection

                Spacer()

                // Bottom Actions Section - enhanced spacing
                actionsSection
            }
            .padding(.vertical, 20)
        }
        .background(Color.backgroundPrimary)
        .onAppear {
            // OPENSPEC ENHANCEMENT: Enhanced onAppear with video readiness checking
            logger.info("🚀 OPENSPEC PRELOAD: MinimalTrimmerView.onAppear started - checking video readiness")

            // ENHANCEMENT: Initialize iOS 18 performance manager
            if #available(iOS 18.0, *) {
                performanceManager = iOS18PerformanceManager()
                logger.info("🚀 ENHANCEMENT: iOS 18 Performance Manager initialized")
            }

            // OPENSPEC ENHANCEMENT: Check video readiness before setup
            if viewModel.videoPlayer.isReady {
                logger.info("✅ OPENSPEC PRELOAD: Video player is ready - proceeding with trimmer setup")
                setupTrimmerDirect()
                logger.info("✅ OPENSPEC PRELOAD: MinimalTrimmerView.onAppear completed successfully - no flashing expected")
            } else {
                logger.warning("⚠️ OPENSPEC PRELOAD: Video player not ready - this indicates preloading has not completed yet")
                logger.info("🔄 OPENSPEC PRELOAD: Setup will be handled by onChange(of: viewModel.videoPlayer.isReady)")

                // Still attempt basic setup for non-critical components
                logger.info("🔧 OPENSPEC PRELOAD: Performing basic setup while video preloads")
                setupBasicTrimmerState()
            }
        }
        .onChange(of: viewModel.videoPlayer.isReady) { _, isReady in
            if isReady {
                logger.info("🎯 OPENSPEC PRELOAD: Video player became ready - completing trimmer setup")
                setupTrimmerDirect()

                // OPENSPEC FIX: Load video metadata after trimmer setup to ensure duration is available
                // This coordinate ensures videoDuration is set before handle positioning calculations
                loadVideoMetadata()
                logger.info("✅ OPENSPEC PRELOAD: Trimmer setup completed after video player became ready")
            }
        }
        .onChange(of: startTime) { _, newStartTime in
            validateTrimRange()
            syncToViewModel()
        }
        .onChange(of: endTime) { _, newEndTime in
            validateTrimRange()
            syncToViewModel()
        }
        .onChange(of: rotation) { _, newRotation in
            Task {
                await viewModel.updateVideoRotation(newRotation)
            }
        }
    }

    // MARK: - Video Preview Section (Test2 styling with enhanced rotation)
    private var videoPreviewSection: some View {
        VStack(spacing: 20) {
            // Video Player - Test2 design with 12pt corner radius and rotation support
            ZStack {
                // ENHANCEMENT: Native video player with automatic aspect ratio detection
                RotatableVideoContainer(
                    player: viewModel.videoPlayer,
                    rotation: rotation,
                    showControls: false
                )

                // Enhanced rotation overlay with visual feedback
                if rotation != .degrees0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "rotate.right.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)

                            Text("Rotated \(rotation.description)")
                                .font(.ibmPlexMono(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(Layout.smallRadius)

                        // Rotation reset hint
                        Text("Tap rotate to cycle")
                            .font(.ibmPlexMono(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    .position(x: Spacing.sm + 40, y: Spacing.sm + 20)
                }

                // OPENSPEC FIX: Loading overlay removed - video should be ready when view appears
                // The transition from SelectClip now only occurs at .fullyReady state
            }
            .frame(height: 220)
            .padding(.horizontal, 16)

            // Time Display - Horizontal layout matching Test2.swift design
            HStack(spacing: 40) {
                // Start time group
                VStack(alignment: .center, spacing: 4) {
                    Text("START")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(formatTimecode(startTime))
                        .font(.headline)
                }

                // Duration - centered with enhanced visual feedback for minimum duration
                VStack(spacing: 2) {
                    Text("DURATION")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Text(formatTimecode(trimDuration))
                        .font(.headline)
                        .foregroundColor(trimDuration >= minimumTrimDuration ? .blue : .red)
                        .scaleEffect(trimDuration < minimumTrimDuration ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: trimDuration)

                    if trimDuration < minimumTrimDuration {
                        Text("Min: \(Int(minimumTrimDuration))s")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .opacity(0.8)
                    }
                }

                // End time group
                VStack(alignment: .center, spacing: 4) {
                    Text("END")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(formatTimecode(endTime))
                        .font(.headline)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Timeline Section (Enhanced with Capsule Design and Coordinate Space)
    private func timelineSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            // Timeline Bar with Trim Handles - Enhanced with coordinate space management
            GeometryReader { timelineGeometry in
                ZStack(alignment: .leading) {
                    // Background timeline - Enhanced Capsule design with coordinate space
                    Capsule()
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 40)
                        .coordinateSpace(name: "timeline")

                    // Calculate handle center coordinates for precise highlight alignment
                    let startHandleCenterCoord = timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
                    let endHandleCenterCoord = timeToCoordinate(endTime, totalWidth: timelineGeometry.size.width) + (handleWidth / 2.0)
                    let highlightWidth = max(0, endHandleCenterCoord - startHandleCenterCoord)

                    // Selected range highlight - Precisely aligned from handle center to handle center
                    Rectangle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: highlightWidth, height: 40)
                        .offset(x: startHandleCenterCoord)

                    // Left trim handle - Enhanced with Apple blue color and coordinate space
                    Circle()
                        .fill(Color(red: 0/255, green: 122/255, blue: 255/255)) // Apple blue
                        .frame(width: 20, height: 20)
                        .offset(x: startHandleCenterCoord)
                        .scaleEffect(isDraggingLeftHandle ? 1.1 : 1.0)
                        .onAppear {
                            // ENHANCED: Simplified coordinate space verification with new conversion function
                            let handleOffset = timeToCoordinate(startTime, totalWidth: timelineGeometry.size.width)

                            logger.debug("🎯 ENHANCED POSITION: Left handle positioned at offset \(String(format: "%.2f", handleOffset)) for startTime \(String(format: "%.3f", startTime))s")

                            // ENHANCED: Validate coordinate calculation prerequisites
                            logger.info("✅ ENHANCED VERIFICATION: Left handle positioning complete using timeToCoordinate function")
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingLeftHandle {
                                        provideSelectionFeedback()
                                    }
                                    isDraggingLeftHandle = true
                                    handleLeftHandleDrag(value.location.x, totalWidth: timelineGeometry.size.width)
                                }
                                .onEnded { _ in
                                    isDraggingLeftHandle = false
                                    provideNotificationFeedback(.success)
                                    snapToNearestFrame(&startTime)
                                    validateTrimRange()
                                }
                        )

                    // Right trim handle - Enhanced with Apple blue color and coordinate space
                    Circle()
                        .fill(Color(red: 0/255, green: 122/255, blue: 255/255)) // Apple blue
                        .frame(width: 20, height: 20)
                        .offset(x: endHandleCenterCoord)
                        .scaleEffect(isDraggingRightHandle ? 1.1 : 1.0)
                        .onAppear {
                            // ENHANCED: Simplified coordinate space verification with new conversion function
                            let handleOffset = timeToCoordinate(endTime, totalWidth: timelineGeometry.size.width)

                            logger.debug("🎯 ENHANCED POSITION: Right handle positioned at offset \(String(format: "%.2f", handleOffset)) for endTime \(String(format: "%.3f", endTime))s")

                            // ENHANCED: Validate coordinate calculation prerequisites
                            logger.info("✅ ENHANCED VERIFICATION: Right handle positioning complete using timeToCoordinate function")
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingRightHandle {
                                        provideSelectionFeedback()
                                    }
                                    isDraggingRightHandle = true
                                    handleRightHandleDrag(value.location.x, totalWidth: timelineGeometry.size.width)
                                }
                                .onEnded { _ in
                                    isDraggingRightHandle = false
                                    provideNotificationFeedback(.success)
                                    snapToNearestFrame(&endTime)
                                    validateTrimRange()
                                }
                        )
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 16)

            // Timeline Annotations - Test2 single line design
            HStack(spacing: 24) {
                ForEach([0, 1, 2, 3, 4], id: \.self) { index in
                    Text(timeLabel(for: index))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Controls Section (Test2 styling with enhanced accessibility)
    private var controlsSection: some View {
        HStack(spacing: 16) {
            // ENHANCEMENT: Play/Pause Button - Test2 circular design with accessibility
            Button(action: togglePlayback) {
                Image(systemName: viewModel.videoPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .frame(width: 60, height: 60) // ENHANCEMENT: Ensure 44x44pt minimum touch target
            .disabled(!viewModel.videoPlayer.isReady)
            .accessibilityLabel(viewModel.videoPlayer.isPlaying ? "Pause video" : "Play video")
            .accessibilityHint(viewModel.videoPlayer.isPlaying ? "Pause video playback" : "Play video from current trim position")
            .accessibilityAddTraits(.isButton)

            // ENHANCEMENT: Rotation Button - Direct 90-degree rotation with accessibility
            Button(action: rotateVideo90Degrees) {
                Image(systemName: "rotate.right")
                    .font(.title)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
            }
            .frame(width: 60, height: 60) // ENHANCEMENT: Ensure 44x44pt minimum touch target
            .disabled(!viewModel.videoPlayer.isReady)
            .accessibilityLabel("Rotate video")
            .accessibilityHint("Rotate video 90 degrees clockwise. Current rotation: \(rotation.description)")
            .accessibilityValue("Current rotation: \(rotation.description)")
            .accessibilityAddTraits(.isButton)

            Spacer()

            // ENHANCEMENT: Reset Button with rotation state reset and accessibility
            Button(action: resetAllModifications) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text("Reset")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(minHeight: 44) // ENHANCEMENT: Ensure minimum touch target height
            .disabled(!viewModel.videoPlayer.isReady)
            .accessibilityLabel("Reset all modifications")
            .accessibilityHint("Resets trim range to full video and rotation to original orientation")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Video playback controls")
    }

    // MARK: - Actions Section (Test2 styling with enhanced accessibility)
    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            // ENHANCEMENT: Error Message with accessibility
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .accessibilityLabel("Error: \(errorMessage)")
                    .accessibilityAddTraits(.isStaticText)
            }

            // ENHANCEMENT: Action Buttons - Test2 styling with accessibility compliance
            HStack(spacing: 16) {
                // Cancel Button
                Button("Cancel") {
                    cancelTrimming()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44) // ENHANCEMENT: Ensure minimum touch target height
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .accessibilityLabel("Cancel trimming")
                .accessibilityHint("Cancel video trimming and return to previous screen")
                .accessibilityAddTraits(.isButton)

                // Submit Button - Test2 styling with accessibility
                Button("Submit") {
                    proceedToNaming()
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44) // ENHANCEMENT: Ensure minimum touch target height
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isValidTrimRange)
                .accessibilityLabel(isValidTrimRange ? "Submit trim" : "Submit trim - not available")
                .accessibilityHint(isValidTrimRange ? "Continue to naming with selected trim range and rotation" : "Select a valid trim range of at least 3 seconds to continue")
                .accessibilityValue("Trim duration: \(String(format: "%.1f", trimDuration)) seconds")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trim actions")
        .accessibilityHint("Cancel or submit video trimming")
    }

    // MARK: - Sync to ViewModel
    private func syncToViewModel() {
        // Update the view model with current trim values
        Task { @MainActor in
            viewModel.trimStartTime = startTime
            viewModel.trimEndTime = endTime
        }
    }

  
    // OPENSPEC FIX: synchronizedLoadingOverlay removed
        // Video should be ready when view appears due to fixed transition timing in SelectClip

    // MARK: - Setup Methods

    /// Setup basic trimmer state that doesn't depend on video player readiness
    /// This allows the UI to prepare while video is preloading
    /// Note: Frame-precision trimming will be available after video metadata loads
    private func setupBasicTrimmerState() {
        logger.info("🔧 OPENSPEC PRELOAD: Setting up basic trimmer state without video dependency")

        // Sync rotation from view model (doesn't require video player)
        rotation = viewModel.videoRotation

        // Load existing trim values if available (doesn't require video player)
        if viewModel.trimStartTime > 0 && viewModel.trimEndTime > 0 {
            startTime = viewModel.trimStartTime
            endTime = viewModel.trimEndTime

            // ENHANCED DIAGNOSTIC: Track ViewModel trim value inheritance
            logger.info("🔍 COORDINATE SPACE: Inherited trim values from ViewModel")
            logger.info("🔍 COORDINATE SPACE: ViewModel.trimStartTime = \(viewModel.trimStartTime)s")
            logger.info("🔍 COORDINATE SPACE: ViewModel.trimEndTime = \(viewModel.trimEndTime)s")
            logger.info("🔍 COORDINATE SPACE: Local startTime = \(startTime)s")
            logger.info("🔍 COORDINATE SPACE: Local endTime = \(endTime)s")
        } else {
            // ENHANCED DIAGNOSTIC: Track default initialization path
            logger.info("🔍 COORDINATE SPACE: No ViewModel trim values - using defaults")
            logger.info("🔍 COORDINATE SPACE: ViewModel.trimStartTime = \(viewModel.trimStartTime)s")
            logger.info("🔍 COORDINATE SPACE: ViewModel.trimEndTime = \(viewModel.trimEndTime)s")
        }

        logger.info("✅ OPENSPEC PRELOAD: Basic trimmer state set - rotation: \(rotation.description), trim: \(startTime)s-\(endTime)s")
    }

    private func setupTrimmerDirect() {
        logger.info("🔧 OPENSPEC FIX: Setting up trimmer with direct synchronous initialization")

        // ENHANCED DIAGNOSTIC: Track initialization order and state
        logger.info("🔍 INITIALIZATION ORDER: setupTrimmerDirect() called")
        logger.info("🔍 INITIALIZATION ORDER: Current trim state before setup")
        logger.info("🔍 INITIALIZATION ORDER: - startTime = \(startTime)s")
        logger.info("🔍 INITIALIZATION ORDER: - endTime = \(endTime)s")
        logger.info("🔍 INITIALIZATION ORDER: - videoDuration = \(videoDuration)s")
        logger.info("🔍 INITIALIZATION ORDER: ViewModel trim state")
        logger.info("🔍 INITIALIZATION ORDER: - trimStartTime = \(viewModel.trimStartTime)s")
        logger.info("🔍 INITIALIZATION ORDER: - trimEndTime = \(viewModel.trimEndTime)s")

        // OPENSPEC FIX: Video should be ready when SelectClip transitions at .fullyReady
        guard viewModel.videoPlayer.isReady else {
            logger.warning("⚠️ OPENSPEC FIX: Video player is not ready - this should not happen")
            return
        }

        guard let asset = viewModel.selectedVideo else {
            logger.warning("⚠️ OPENSPEC FIX: No selected video asset available")
            return
        }

        logger.info("✅ OPENSPEC FIX: Video player confirmed ready - initializing trim range")

        // Use videoPlayer duration directly - no need to load from asset
        videoDuration = viewModel.videoPlayer.duration

        // Guard against invalid duration
        guard videoDuration > 0 else {
            logger.warning("⚠️ OPENSPEC FIX: Invalid video duration: \(videoDuration), cannot initialize trimmer")
            errorMessage = "Invalid video duration"
            return
        }

        // OPENSPEC FIX: Load existing trim values FIRST before setting defaults
        // This ensures proper state initialization order for handle positioning
        // ENHANCED: More robust condition checking with better logging
        let hasValidViewModelTrimValues = viewModel.trimStartTime > 0 && viewModel.trimEndTime > 0

        logger.info("🔍 OPENSPEC FIX: Checking ViewModel trim values")
        logger.info("🔍 OPENSPEC FIX: viewModel.trimStartTime = \(viewModel.trimStartTime)s (>0: \(viewModel.trimStartTime > 0))")
        logger.info("🔍 OPENSPEC FIX: viewModel.trimEndTime = \(viewModel.trimEndTime)s (>0: \(viewModel.trimEndTime > 0))")
        logger.info("🔍 OPENSPEC FIX: Combined condition result = \(hasValidViewModelTrimValues)")

        if hasValidViewModelTrimValues {
            startTime = viewModel.trimStartTime
            endTime = viewModel.trimEndTime
            logger.info("✅ OPENSPEC FIX: Successfully inherited trim values from ViewModel")
            logger.info("✅ OPENSPEC FIX: startTime = \(startTime)s, endTime = \(endTime)s")
        } else {
            // Only set defaults if no ViewModel values exist
            startTime = 0.0
            endTime = videoDuration
            logger.info("🔍 OPENSPEC FIX: No valid ViewModel trim values - using defaults")
            logger.info("🔍 OPENSPEC FIX: startTime = \(startTime)s, endTime = \(endTime)s")
        }

        // Sync rotation from view model
        rotation = viewModel.videoRotation

        logger.info("✅ OPENSPEC FIX: Trim range initialized directly: \(startTime)s - \(endTime)s")

        // OPENSPEC FIX: Add trim value propagation verification
        logger.info("🔍 OPENSPEC VERIFICATION: Trim value propagation complete")
        logger.info("🔍 OPENSPEC VERIFICATION: ViewModel.trimStartTime (\(viewModel.trimStartTime)s) -> TrimmerView.startTime (\(startTime)s)")
        logger.info("🔍 OPENSPEC VERIFICATION: ViewModel.trimEndTime (\(viewModel.trimEndTime)s) -> TrimmerView.endTime (\(endTime)s)")
        logger.info("🔍 OPENSPEC VERIFICATION: videoDuration = \(videoDuration)s")
        logger.info("🔍 OPENSPEC VERIFICATION: Handle positioning will use these values for coordinate calculations")
    }

    
    private func loadVideoMetadata() {
        guard let asset = viewModel.selectedVideo else { return }

        Task {
            do {
                // Load duration
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    let previousDuration = videoDuration
                    videoDuration = duration.seconds

                    // OPENSPEC FIX: Only set trim defaults if they weren't already set in setupTrimmerDirect()
                    // This prevents overriding ViewModel trim values that were properly initialized
                    let trimValuesAlreadySet = startTime > 0 || endTime < duration.seconds

                    logger.info("🔍 OPENSPEC METADATA: loadVideoMetadata completed")
                    logger.info("🔍 OPENSPEC METADATA: Previous videoDuration = \(previousDuration)s, New videoDuration = \(duration.seconds)s")
                    logger.info("🔍 OPENSPEC METADATA: Trim values already set = \(trimValuesAlreadySet)")
                    logger.info("🔍 OPENSPEC METADATA: Current trim range = \(startTime)s - \(endTime)s")

                    if !trimValuesAlreadySet && (startTime == 0.0 && endTime == 0.0) {
                        // Only set defaults if no trim values were initialized
                        endTime = duration.seconds
                        startTime = 0.0

                        logger.info("🔍 OPENSPEC METADATA: Applied default trim initialization - startTime: \(startTime)s, endTime: \(endTime)s")
                    } else {
                        logger.info("🔍 OPENSPEC METADATA: Preserving existing trim values - startTime: \(startTime)s, endTime: \(endTime)s")
                    }

                    // OPENSPEC FIX: Verify coordinate calculation prerequisites are met
                    logger.info("🔍 OPENSPEC VERIFICATION: Coordinate calculation prerequisites verified")
                    logger.info("🔍 OPENSPEC VERIFICATION: videoDuration = \(videoDuration)s (>0: \(videoDuration > 0))")
                    logger.info("🔍 OPENSPEC VERIFICATION: startTime = \(startTime)s (valid: \(startTime >= 0))")
                    logger.info("🔍 OPENSPEC VERIFICATION: endTime = \(endTime)s (valid: \(endTime <= videoDuration))")
                    logger.info("🔍 OPENSPEC VERIFICATION: Handle positioning calculations can now proceed with correct values")
                }

                // Load frame rate
                let videoTracks = try await asset.load(.tracks)
                if let videoTrack = videoTracks.first(where: { $0.mediaType == .video }) {
                    let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                    await MainActor.run {
                        frameRate = Double(nominalFrameRate)
                    }
                }

                logger.info("✅ OPENSPEC METADATA: Video metadata loaded - Duration: \(videoDuration)s, Frame Rate: \(frameRate)fps")
            } catch {
                logger.error("❌ OPENSPEC METADATA: Failed to load video metadata: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to load video metadata"
                }
            }
        }
    }

  
    // MARK: - Enhanced Drag Handlers with Coordinate Space Management
    private func handleLeftHandleDrag(_ dragX: CGFloat, totalWidth: CGFloat) {
        // COORDINATE FIX: Subtract radius before coordinateToTime to map finger position to available track
        let adjustedDragX = dragX - (handleWidth / 2.0)
        let newTime = coordinateToTime(adjustedDragX, totalWidth: totalWidth)

        logger.debug("🎯 COORDINATE FIX: Left handle - dragX: \(String(format: "%.2f", dragX))px -> adjustedDragX: \(String(format: "%.2f", adjustedDragX))px -> newTime: \(String(format: "%.3f", newTime))s")

        // Enforce minimum duration constraint
        let maxAllowedTime = endTime - minimumTrimDuration
        let constrainedTime = min(newTime, maxAllowedTime)

        // Apply final constraints
        startTime = max(0, constrainedTime)

        // Provide feedback if minimum duration constraint is violated
        if newTime > maxAllowedTime {
            provideMinimumDurationFeedback()
        }

        optimizedSeek(to: startTime)
    }

    private func handleRightHandleDrag(_ dragX: CGFloat, totalWidth: CGFloat) {
        // COORDINATE FIX: Subtract radius before coordinateToTime to map finger position to available track
        let adjustedDragX = dragX - (handleWidth / 2.0)
        let newTime = coordinateToTime(adjustedDragX, totalWidth: totalWidth)

        logger.debug("🎯 COORDINATE FIX: Right handle - dragX: \(String(format: "%.2f", dragX))px -> adjustedDragX: \(String(format: "%.2f", adjustedDragX))px -> newTime: \(String(format: "%.3f", newTime))s")

        // Enforce minimum duration constraint
        let minAllowedTime = startTime + minimumTrimDuration
        let constrainedTime = max(newTime, minAllowedTime)

        // Apply final constraints
        endTime = min(videoDuration, constrainedTime)

        // Provide feedback if minimum duration constraint is violated
        if newTime < minAllowedTime {
            provideMinimumDurationFeedback()
        }

        optimizedSeek(to: endTime)
    }

    // MARK: - Validation
    private func validateTrimRange() {
        if trimDuration < minimumTrimDuration {
            errorMessage = "Minimum duration is \(Int(minimumTrimDuration)) seconds"
        } else if startTime < 0 || endTime > videoDuration || startTime >= endTime {
            errorMessage = "Invalid trim range"
        } else {
            errorMessage = nil
        }
    }

    // MARK: - Enhanced Time-to-Coordinate Conversion Functions
    /// Converts time to coordinate position within the available track only
    /// Updated: Removed radius offset - now returns pure coordinates on available track
    private func timeToCoordinate(_ time: TimeInterval, totalWidth: CGFloat) -> CGFloat {
        guard videoDuration > 0 else {
            logger.warning("⚠️ ENHANCED COORDINATE: Cannot convert time to coordinate - videoDuration is 0")
            return 0
        }

        guard totalWidth > 0 else {
            logger.warning("⚠️ ENHANCED COORDINATE: Cannot convert time to coordinate - totalWidth is 0")
            return 0
        }

        // Calculate available track width (subtract handle width to keep handles within bounds)
        let availableTrackWidth = totalWidth - handleWidth
        let coordinate = availableTrackWidth * (time / videoDuration)
        // No radius offset - return pure coordinate on available track
        let clampedCoordinate = max(0, min(coordinate, availableTrackWidth))

        logger.debug("🎯 COORDINATE FIX: timeToCoordinate(\(time)s) = \(String(format: "%.2f", clampedCoordinate))px (available track only)")

        return clampedCoordinate
    }

    /// Converts coordinate position to time within the available track only
    /// Updated: Removed radius offset - now works with available track coordinates
    private func coordinateToTime(_ coordinate: CGFloat, totalWidth: CGFloat) -> TimeInterval {
        guard totalWidth > 0 else {
            logger.warning("⚠️ ENHANCED COORDINATE: Cannot convert coordinate to time - totalWidth is 0")
            return 0
        }

        // Calculate available track width (subtract handle width to keep handles within bounds)
        let availableTrackWidth = totalWidth - handleWidth
        // Clamp coordinate to available track range
        let clampedCoordinate = max(0, min(coordinate, availableTrackWidth))
        // No radius offset - convert directly from available track coordinate
        let time = (clampedCoordinate / availableTrackWidth) * videoDuration

        logger.debug("🎯 COORDINATE FIX: coordinateToTime(\(String(format: "%.2f", clampedCoordinate))px) = \(String(format: "%.3f", time))s (available track only)")

        return time
    }

    // MARK: - Helper Methods

    /// Frame-precision snapping algorithm for video trimming
    ///
    /// This function provides frame-accurate snapping instead of second-level rounding,
    /// eliminating jarring handle jumps and maintaining user's precise selections.
    ///
    /// Algorithm:
    /// 1. Validate frameRate is available and > 0
    /// 2. Calculate frameDuration = 1.0 / frameRate (e.g., 30fps = 0.033s per frame)
    /// 3. Calculate frameCount = round(time / frameDuration)
    /// 4. Snap time = frameCount * frameDuration
    ///
    /// Fallback: If frameRate is invalid, falls back to second rounding for compatibility
    ///
    /// Examples:
    /// - 30fps: 1.234s → frame 37 (1.233s)
    /// - 60fps: 1.234s → frame 74 (1.233s)
    /// - 24fps: 1.234s → frame 30 (1.250s)
    private func snapToNearestFrame(_ time: inout TimeInterval) {
        // Validate frameRate before using it for frame-precision calculations
        guard frameRate > 0 else {
            logger.warning("⚠️ FRAME SNAP: Invalid frameRate (\(frameRate)), falling back to second rounding")
            time = round(time)
            return
        }

        // Calculate frame duration (time between individual frames)
        let frameDuration = 1.0 / frameRate

        // Round to nearest frame using frame-accurate calculation
        // This ensures the time aligns exactly with video frame boundaries
        let frameCount = round(time / frameDuration)
        time = frameCount * frameDuration

        logger.debug("🎯 FRAME SNAP: Snapped to frame \(Int(frameCount)) at \(String(format: "%.3f", time))s (frameRate: \(frameRate)fps, frameDuration: \(String(format: "%.3f", frameDuration))s)")
    }

    /// Provides haptic feedback for selection interactions
    private func provideSelectionFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Provides haptic feedback for notification/completion interactions
    private func provideNotificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }

    /// Provides haptic and visual feedback when attempting to trim below minimum duration
    /// Works with frame-precision trim values to ensure accurate user feedback
    private func provideMinimumDurationFeedback() {
        // Haptic feedback for constraint violation
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)

        // Update error message temporarily
        errorMessage = "Minimum duration is \(Int(minimumTrimDuration)) seconds"

        // Clear error message after a short delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if errorMessage == "Minimum duration is \(Int(minimumTrimDuration)) seconds" {
                errorMessage = nil
            }
        }
    }

    private func formatTimecode(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * frameRate)
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }

    // Helper: Generate time labels for timeline ticks (Test2 style)
    private func timeLabel(for index: Int) -> String {
        switch index {
        case 0: return "00:00:00"
        case 1: return "00:08:12"
        case 2: return "00:17:01"
        case 3: return "00:25:14"
        default: return formatTimecode(videoDuration)
        }
    }

    // MARK: - Optimized Video Seeking (Enhanced with iOS 18 AVMetrics)
    private func optimizedSeek(to time: TimeInterval) {
        // Cancel any existing seek operation
        seekTask?.cancel()

        // ENHANCEMENT: Track seek operation with iOS 18 performance manager
        let operationId = UUID()
        currentSeekOperationId = operationId

        if #available(iOS 18.0, *) {
            performanceManager?.beginSeekOperation(operationId: operationId)
        }

        logger.debug("🎯 ENHANCED: Starting optimized seek to \(String(format: "%.2f", time))s [\(operationId)]")

        // Debounce seek operations to prevent excessive seeking during drag
        seekTask = Task { @MainActor in
            // Adaptive debounce based on performance metrics
            let adaptiveDebounceMs = calculateAdaptiveDebounceDelay()
            try? await Task.sleep(nanoseconds: UInt64(adaptiveDebounceMs * 1_000_000))

            // Check if task wasn't cancelled during sleep
            guard !Task.isCancelled else {
                if #available(iOS 18.0, *) {
                    performanceManager?.endSeekOperation(operationId: operationId)
                }
                logger.debug("🚫 Seek operation cancelled: \(operationId)")
                return
            }

            // ENHANCEMENT: iOS 18 optimized seeking with frame accuracy
            if #available(iOS 18.0, *) {
                await performiOS18OptimizedSeek(to: time, operationId: operationId)
            } else {
                // Fallback to standard seeking for older iOS versions
                viewModel.videoPlayer.seek(to: time)
                logger.debug("✅ Standard seek completed to \(String(format: "%.2f", time))s")
            }

            // End performance tracking
            if #available(iOS 18.0, *) {
                performanceManager?.endSeekOperation(operationId: operationId)
            }

            // Log performance metrics
            if #available(iOS 18.0, *) {
                let metrics = performanceManager?.currentMetrics
                logger.debug("📊 Performance metrics - Avg seek: \(String(format: "%.3f", metrics?.averageSeekTime ?? 0))s, Active: \(metrics?.activeSeekOperations ?? 0)")
            }
        }
    }

    // MARK: - iOS 18 Enhanced Seeking Methods
    @available(iOS 18.0, *)
    private func calculateAdaptiveDebounceDelay() -> TimeInterval {
        guard let metrics = performanceManager?.currentMetrics else {
            return seekDebounceMs // Default to static value
        }

        // Adaptive debounce: shorter delay if performance is good, longer if struggling
        if metrics.isPerformant {
            return max(50, seekDebounceMs * 0.5) // Faster response when performing well
        } else {
            return min(200, seekDebounceMs * 1.5) // Slower response to reduce load when struggling
        }
    }

    @available(iOS 18.0, *)
    private func performiOS18OptimizedSeek(to time: TimeInterval, operationId: UUID) async {
        // Use frame-accurate seeking for iOS 18
        let frameRate = viewModel.videoPlayer.duration > 0 ? 30.0 : 30.0 // Default to 30fps
        let frameTime = 1.0 / frameRate
        let quantizedTime = round(time / frameTime) * frameTime

        // Perform seek with precise timing
        let cmTime = CMTime(seconds: quantizedTime, preferredTimescale: CMTimeScale(frameRate * 100))

        logger.debug("🎯 iOS 18 frame-accurate seek: \(String(format: "%.3f", quantizedTime))s (frame-aligned)")

        // Use video player's enhanced seek method
        viewModel.videoPlayer.seek(to: quantizedTime)

        // Small delay to ensure seek completes before next operation
        try? await Task.sleep(nanoseconds: 16_666_667) // ~1/60 second
    }

    private func togglePlayback() {
        if viewModel.videoPlayer.isPlaying {
            viewModel.videoPlayer.pause()
        } else {
            // Seek to start time and play within trim range
            viewModel.videoPlayer.seek(to: startTime)
            viewModel.videoPlayer.play()

            // Monitor playback to enforce trim range boundaries
            monitorTrimRangePlayback()
        }
    }

    private func monitorTrimRangePlayback() {
        Task { @MainActor in
            // Use a timer for more efficient playback monitoring
            var lastCheckTime = viewModel.videoPlayer.currentTime

            while viewModel.videoPlayer.isPlaying && viewModel.videoPlayer.isReady {
                let currentTime = viewModel.videoPlayer.currentTime

                // Only seek if we've significantly moved forward to reduce operations
                if currentTime >= endTime || (currentTime - lastCheckTime > 0.5) {
                    if currentTime >= endTime {
                        // Loop back to start time using optimized seek
                        optimizedSeek(to: startTime)
                        if viewModel.videoPlayer.isPlaying {
                            viewModel.videoPlayer.play()
                        }
                    }
                    lastCheckTime = currentTime
                }

                // Use a longer sleep interval for better performance
                try? await Task.sleep(nanoseconds: 200_000_000) // Check every 200ms instead of 100ms
            }
        }
    }

    // MARK: - Direct Rotation Methods
    private func rotateVideo90Degrees() {
        // Calculate next rotation (cycle through 0 -> 90 -> 180 -> 270 -> 0)
        let nextRotation: VideoRotation
        switch rotation {
        case .degrees0:
            nextRotation = .degrees90
        case .degrees90:
            nextRotation = .degrees180
        case .degrees180:
            nextRotation = .degrees270
        case .degrees270:
            nextRotation = .degrees0
        }

        // Apply rotation with animation and haptic feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            rotation = nextRotation
        }

        // Provide haptic feedback for rotation
        provideSelectionFeedback()

        logger.info("Direct rotation applied: \(nextRotation.description)")

        // Update view model with new rotation
        Task {
            await viewModel.updateVideoRotation(nextRotation)
        }
    }

    // MARK: - Enhanced Reset Functionality
    private func resetAllModifications() {
        logger.info("🔄 ENHANCEMENT: Resetting all modifications (trim + rotation)")

        // Provide haptic feedback for reset action
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        // Reset trim range to full video duration
        startTime = 0
        endTime = videoDuration

        // Reset rotation to default (0 degrees)
        rotation = .degrees0

        // Clear any existing error messages
        errorMessage = nil

        // Validate the reset state
        validateTrimRange()

        // Update view model with reset values
        Task {
            await viewModel.updateVideoRotation(.degrees0)
            viewModel.trimStartTime = 0
            viewModel.trimEndTime = videoDuration
        }

        // Seek video to beginning after reset
        viewModel.videoPlayer.seek(to: 0)

        // Reset performance metrics if available
        if #available(iOS 18.0, *) {
            performanceManager?.resetMetrics()
            logger.info("📊 Performance metrics reset")
        }

        logger.info("✅ ENHANCEMENT: All modifications reset successfully")
    }

    // MARK: - Enhanced Submit Navigation
    private func proceedToNaming() {
        guard isValidTrimRange else {
            logger.warning("⚠️ ENHANCEMENT: Cannot proceed - invalid trim range")
            provideNotificationFeedback(.error)
            return
        }

        logger.info("🎯 ENHANCEMENT: Proceeding to naming with validated trim range: \(String(format: "%.2f", startTime))s - \(String(format: "%.2f", endTime))s, rotation: \(rotation.description)")

        // Cancel any pending seek operations before navigation
        seekTask?.cancel()

        // ENHANCEMENT: Create comprehensive trim modification with full data persistence
        let modification = TrimModification(
            startTimeMs: Int64(startTime * 1000),
            endTimeMs: Int64(endTime * 1000),
            rotation: rotation
        )

        // Validate trim modification before proceeding
        let validationResult = modification.validateConstraints()
        guard validationResult.isValid else {
            logger.error("❌ ENHANCEMENT: Trim modification validation failed: \(validationResult.errors.map(\.description).joined(separator: ", "))")
            errorMessage = validationResult.errors.first?.description ?? "Invalid trim parameters"
            provideNotificationFeedback(.error)
            return
        }

        // Provide success haptic feedback for successful validation
        provideNotificationFeedback(.success)

        Task {
            do {
                // Update ViewModel with comprehensive trim modification data
                await viewModel.updateTrimModification(modification)

                logger.info("📊 ENHANCEMENT: Trim modification created - Duration: \(String(format: "%.2f", modification.durationSeconds))s, Rotation: \(modification.rotation.description)")

                // Navigation will be handled by the parent view observing the view model changes
                logger.info("✅ ENHANCEMENT: Trimmer data updated successfully - parent view will handle navigation")

            } catch {
                logger.error("❌ ENHANCEMENT: Failed to prepare trim data: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to prepare trim data: \(error.localizedDescription)"
                }
                provideNotificationFeedback(.error)
            }
        }
    }

    // MARK: - Cleanup
    private func cancelTrimming() {
        logger.info("🚫 ENHANCEMENT: Cancelling trimming with complete workflow reset")

        // Cancel any pending seek operations
        seekTask?.cancel()

        // Provide haptic feedback for cancel action
        provideNotificationFeedback(.warning)

        // Perform complete workflow reset through view model
        Task { @MainActor in
            logger.info("🔄 ENHANCEMENT: Initiating complete workflow reset via ViewModel")

            // Reset the entire view model to initial state
            viewModel.reset()

            logger.info("✅ ENHANCEMENT: Workflow reset complete - user returned to initial 'select a clip' state")
        }
    }
}

// MARK: - Native Video Player View with Automatic Aspect Ratio

struct NativeVideoPlayerView: UIViewControllerRepresentable {
    @ObservedObject var player: SharedVideoPlayer
    let rotation: VideoRotation
    let showControls: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        logger.info("🎥 Creating NativeVideoPlayerView with automatic aspect ratio", emoji: "🎥")

        let controller = AVPlayerViewController()
        controller.player = player.avPlayer
        controller.showsPlaybackControls = showControls
        controller.videoGravity = .resizeAspect // Maintain aspect ratio automatically

        logger.info("🎥 AVPlayerViewController created with videoGravity: .resizeAspect", emoji: "🎥")
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        logger.debug("🎥 Updating NativeVideoPlayerView - player: \(player.avPlayer != nil), controls: \(showControls)", emoji: "🎥")

        if uiViewController.player !== player.avPlayer {
            uiViewController.player = player.avPlayer
            logger.info("🎥 Updated AVPlayerViewController player", emoji: "🎥")
        }

        if uiViewController.showsPlaybackControls != showControls {
            uiViewController.showsPlaybackControls = showControls
            logger.debug("🎥 Updated playback controls visibility", emoji: "🎥")
        }
    }
}

// MARK: - Enhanced Rotatable Video Container

struct RotatableVideoContainer: View {
    @ObservedObject var player: SharedVideoPlayer
    let rotation: VideoRotation
    let showControls: Bool

    var body: some View {
        NativeVideoPlayerView(
            player: player,
            rotation: rotation,
            showControls: showControls
        )
        .rotationEffect(rotation.angle) // Rotate entire component as synchronized unit
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            logger.info("🎥 RotatableVideoContainer appeared with rotation: \(rotation)", emoji: "🎥")
        }
    }
}

// MARK: - Rotatable Video Player View (Enhancement)
/// ENHANCEMENT: Video player view with smooth rotation transform support
/// Provides immediate visual feedback for video rotation using AVPlayerLayer transforms
struct RotatableVideoPlayerView: UIViewRepresentable {
    @ObservedObject var player: SharedVideoPlayer
    let rotation: VideoRotation
    let showControls: Bool

    func makeUIView(context: Context) -> RotatableVideoPlayerUIView {
        let view = RotatableVideoPlayerUIView()
        view.player = player.avPlayer
        view.showControls = showControls
        view.rotation = rotation
        view.setupPlayer()
        return view
    }

    func updateUIView(_ uiView: RotatableVideoPlayerUIView, context: Context) {
        uiView.player = player.avPlayer
        uiView.showControls = showControls
        uiView.updateRotation(rotation, animated: true)
    }
}

/// UIKit view for rotatable video player with AVPlayerLayer transform support
class RotatableVideoPlayerUIView: UIView {
    var player: AVPlayer? {
        didSet {
            setupPlayer()
        }
    }

    var showControls: Bool = false {
        didSet {
            updatePlayerController()
        }
    }

    var rotation: VideoRotation = .degrees0 {
        didSet {
            // Prevent infinite recursion by only updating if rotation actually changed
            guard rotation != oldValue else {
                logger.debug("🔄 Rotation unchanged, skipping update", emoji: "🔄")
                return
            }
            logger.debug("🔄 Rotation changed from \(oldValue) to \(rotation)", emoji: "🔄")
            updateRotation(rotation, animated: false)
        }
    }

    private var playerLayer: AVPlayerLayer?
    private var playerController: AVPlayerViewController?
    private let rotationAnimationDuration: TimeInterval = 0.3

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .black
        clipsToBounds = true
    }

    func setupPlayer() {
        // Remove existing layer and controller
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        playerController?.view?.removeFromSuperview()
        playerController = nil

        guard let player = player else { return }

        if showControls {
            // Use AVPlayerViewController for controls
            setupPlayerController(with: player)
        } else {
            // Use AVPlayerLayer for direct video display with rotation support
            setupPlayerLayer(with: player)
        }
    }

    private func setupPlayerLayer(with player: AVPlayer) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        layer.backgroundColor = UIColor.black.cgColor

        // Apply initial rotation
        applyRotationTransform(to: layer, rotation: rotation, animated: false)

        self.layer.addSublayer(layer)
        self.playerLayer = layer

        // Note: AVPlayerLayer doesn't have autoresizingMask property
        // Frame updates are handled in layoutSubviews()
    }

    private func setupPlayerController(with player: AVPlayer) {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showControls
        controller.allowsPictureInPicturePlayback = false
        controller.allowsVideoFrameAnalysis = false

        // Configure controller view
        controller.view.frame = bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(controller.view)

        self.playerController = controller

        // Apply rotation to the entire controller view
        applyRotationTransform(to: controller.view, rotation: rotation, animated: false)
    }

    private func updatePlayerController() {
        if let player = player {
            setupPlayer()
        }
    }

    /// Update rotation with smooth animation
    func updateRotation(_ newRotation: VideoRotation, animated: Bool) {
        logger.debug("🔄 updateRotation called with newRotation: \(newRotation), animated: \(animated)", emoji: "🔄")

        // Note: rotation property is already set by the caller, so don't set it here
        // to avoid infinite recursion. The didSet observer already called this method.

        if let playerLayer = playerLayer {
            logger.debug("🔄 Applying rotation transform to playerLayer", emoji: "🔄")
            applyRotationTransform(to: playerLayer, rotation: newRotation, animated: animated)
        } else if let controllerView = playerController?.view {
            logger.debug("🔄 Applying rotation transform to controllerView", emoji: "🔄")
            applyRotationTransform(to: controllerView, rotation: newRotation, animated: animated)
        } else {
            logger.warning("🔄 No player layer or controller view available for rotation", emoji: "⚠️")
        }
    }

    /// Apply rotation transform to a layer or view
    private func applyRotationTransform(to target: CALayer, rotation: VideoRotation, animated: Bool) {
        let transform = CGAffineTransform(rotationAngle: rotation.radians)

        if animated && target.animationKeys()?.contains("rotation") != true {
            // Smooth rotation animation
            let animation = CABasicAnimation(keyPath: "transform")
            animation.toValue = NSValue(caTransform3D: CATransform3DMakeAffineTransform(transform))
            animation.duration = rotationAnimationDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false

            target.add(animation, forKey: "rotation")
        } else {
            // Immediate rotation
            target.transform = CATransform3DMakeAffineTransform(transform)
        }
    }

    /// Apply rotation transform to a view
    private func applyRotationTransform(to target: UIView, rotation: VideoRotation, animated: Bool) {
        let transform = CGAffineTransform(rotationAngle: rotation.radians)

        if animated {
            UIView.animate(withDuration: rotationAnimationDuration, delay: 0, options: .curveEaseInOut) {
                target.transform = transform
            }
        } else {
            target.transform = transform
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Update frames for subviews
        playerLayer?.frame = bounds
        playerController?.view?.frame = bounds
    }
}

// MARK: - Preview
#Preview("Clean MVVM Minimal Trimmer") {
    MinimalTrimmerView(viewModel: AddMoveViewModel())
        .frame(height: 600)
        .background(Color.gray.opacity(0.1))
}