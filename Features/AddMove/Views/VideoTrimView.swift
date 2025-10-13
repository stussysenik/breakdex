// import SwiftUI
// import AVKit
// import AVFoundation

// // MARK: - AVPlayerViewRepresentable
// /// Simple wrapper for AVPlayer in SwiftUI using AVPlayerLayer
// struct AVPlayerViewRepresentable: UIViewRepresentable {
//     let player: AVPlayer

//     func makeUIView(context: Context) -> UIView {
//         let view = UIView()

//         let playerLayer = AVPlayerLayer(player: player)
//         playerLayer.videoGravity = .resizeAspect

//         view.layer.addSublayer(playerLayer)

//         // Store the player layer in the context to update its frame later
//         context.coordinator.playerLayer = playerLayer

//         return view
//     }

//     func updateUIView(_ uiView: UIView, context: Context) {
//         context.coordinator.playerLayer?.player = player

//         // Update player layer frame when view bounds change
//         if context.coordinator.playerLayer?.frame != uiView.bounds {
//             context.coordinator.playerLayer?.frame = uiView.bounds
//         }
//     }

//     func makeCoordinator() -> Coordinator {
//         Coordinator()
//     }

//     class Coordinator {
//         var playerLayer: AVPlayerLayer?
//     }
// }

// // MARK: - VideoTrimView
// /// Clean video trimming interface for selecting video segments
// struct VideoTrimView: View {
//     @ObservedObject var unifiedState: AddMoveUnifiedState
//     @State private var trimStartTime: Double = 0.0
//     @State private var trimEndTime: Double = 1.0
//     @State private var videoDuration: Double = 1.0
//     @State private var isProcessingTrim = false

//     private let logger = Logger(
//         subsystem: "com.breakingflashcards",
//         category: "VideoTrimView"
//     )

//     var body: some View {
//         VStack(spacing: 20) {
//             // Header
//             headerView

//             // Video Preview
//             videoPreviewView

//             // Trimming Controls
//             trimmingControlsView

//             // Action Buttons
//             actionButtonsView

//             Spacer()
//         }
//         .background(Color.black.ignoresSafeArea())
//         .onAppear {
//             setupInitialValues()
//         }
//     }

//     // MARK: - Header View
//     private var headerView: some View {
//         VStack(spacing: 8) {
//             Text("Trim Video")
//                 .title2()
//                 .foregroundColor(.videoControlsForeground)

//             Text("Select the portion of the video you want to save")
//                 .subheadline()
//                 .foregroundColor(.textOnDark)
//                 .multilineTextAlignment(.center)
//         }
//         .padding(.top)
//     }

//     // MARK: - Video Preview View
//     private var videoPreviewView: some View {
//         VStack(spacing: 12) {
//             // Video Player Container
//             RoundedRectangle(cornerRadius: 12)
//                 .fill(Color.gray.opacity(0.3))
//                 .frame(height: 200)
//                 .overlay(
//                     Group {
//                         if unifiedState.isVideoReady {
//                             videoPlayerContent
//                         } else {
//                             loadingPlaceholder
//                         }
//                     }
//                 )
//                 .padding(.horizontal)

//             // Video Duration Info
//             HStack {
//                 Text(formatTime(trimStartTime))
//                     .videoTime()
//                     .foregroundColor(.textOnDark)

//                 Spacer()

//                 Text("Duration: \(formatTime(videoDuration))")
//                     .caption1()
//                     .foregroundColor(.textOnDark)

//                 Spacer()

//                 Text(formatTime(trimEndTime))
//                     .videoTime()
//                     .foregroundColor(.textOnDark)
//             }
//             .padding(.horizontal)
//         }
//     }

//     // MARK: - Video Player Content
//     private var videoPlayerContent: some View {
//         Group {
//             if let asset = unifiedState.selectedVideo {
//                 AVPlayerViewRepresentable(player: AVPlayer(playerItem: AVPlayerItem(asset: asset)))
//                     .onAppear {
//                         setupVideoDuration()
//                     }
//             } else {
//                 loadingPlaceholder
//             }
//         }
//     }

//     // MARK: - Loading Placeholder
//     private var loadingPlaceholder: some View {
//         SharedLoadingView.videoLoading()
//     }

//     // MARK: - Trimming Controls View
//     private var trimmingControlsView: some View {
//         VStack(spacing: 16) {
//             // Start Time Control
//             VStack(alignment: .leading, spacing: 8) {
//                 Text("Start Time")
//                     .font(.subheadline)
//                     .foregroundColor(.white)

//                 Slider(
//                     value: $trimStartTime,
//                     in: 0...max(trimEndTime - 0.1, 0.1),
//                     step: 0.1
//                 ) {
//                     Text("Start Time")
//                 } minimumValueLabel: {
//                     Text("0:00")
//                         .font(.caption2)
//                         .foregroundColor(.textSecondary)
//                 } maximumValueLabel: {
//                     Text(formatTime(videoDuration))
//                         .font(.caption2)
//                         .foregroundColor(.textSecondary)
//                 }
//                 .accentColor(.blue)
//             }

//             // End Time Control
//             VStack(alignment: .leading, spacing: 8) {
//                 Text("End Time")
//                     .font(.subheadline)
//                     .foregroundColor(.white)

//                 Slider(
//                     value: $trimEndTime,
//                     in: max(trimStartTime + 0.1, 0.1)...videoDuration,
//                     step: 0.1
//                 ) {
//                     Text("End Time")
//                 } minimumValueLabel: {
//                     Text("0:00")
//                         .font(.caption2)
//                         .foregroundColor(.textSecondary)
//                 } maximumValueLabel: {
//                     Text(formatTime(videoDuration))
//                         .font(.caption2)
//                         .foregroundColor(.textSecondary)
//                 }
//                 .accentColor(.blue)
//             }

//             // Selected Duration
//             VStack(spacing: 4) {
//                 Text("Selected Duration")
//                     .font(.caption)
//                     .foregroundColor(.textSecondary)

//                 Text(formatTime(trimEndTime - trimStartTime))
//                     .font(.title3)
//                     .fontWeight(.medium)
//                     .foregroundColor(.blue)
//             }
//             .padding(.vertical, 8)
//             .padding(.horizontal, 16)
//             .background(
//                 RoundedRectangle(cornerRadius: 8)
//                     .fill(Color.blue.opacity(0.1))
//             )
//         }
//         .padding(.horizontal)
//     }

//     // MARK: - Action Buttons View
//     private var actionButtonsView: some View {
//         HStack(spacing: 16) {
//             // Skip Trimming Button
//             SharedButton.withIcon(
//                 "Skip Trimming",
//                 icon: "forward.fill",
//                 style: .secondary
//             ) {
//                 skipTrimming()
//             }

//             // Apply Trim Button
//             SharedButton.loading(
//                 isProcessingTrim ? "Processing..." : "Apply Trim",
//                 isLoading: isProcessingTrim
//             ) {
//                 applyTrim()
//             }
//         }
//         .padding(.horizontal)
//     }

//     // MARK: - Private Methods

//     private func setupInitialValues() {
//         videoDuration = unifiedState.currentVideoDuration
//         trimEndTime = videoDuration
//         logger.info("✂️ Video trim view setup - duration: \(videoDuration)s")
//     }

//     private func setupVideoDuration() {
//         guard let asset = unifiedState.selectedVideo else { return }

//         Task {
//             do {
//                 let duration = try await asset.load(.duration)
//                 await MainActor.run {
//                     videoDuration = duration.seconds
//                     trimEndTime = duration.seconds
//                     logger.info("✂️ Video duration loaded: \(duration.seconds)s")
//                 }
//             } catch {
//                 logger.error("❌ Failed to load video duration: \(error)")
//             }
//         }
//     }

//     private func applyTrim() {
//         guard !isProcessingTrim else { return }

//         let startTime = CMTime(seconds: trimStartTime, preferredTimescale: 600)
//         let endTime = CMTime(seconds: trimEndTime, preferredTimescale: 600)

//         logger.info("✂️ Applying trim: \(trimStartTime)s - \(trimEndTime)s")

//         Task {
//             isProcessingTrim = true
//             defer {
//                 Task { @MainActor in
//                     isProcessingTrim = false
//                 }
//             }

//             do {
//                 let trimmedAsset = try await unifiedState.processTrim(from: startTime, to: endTime)
//                 logger.info("✅ Trim applied successfully")
//             } catch {
//                 logger.error("❌ Trim failed: \(error)")
//             }
//         }
//     }

//     private func skipTrimming() {
//         logger.info("⏭️ Skipping trimming - using full video")
//         Task {
//             await MainActor.run {
//                 unifiedState.flowState = .naming
//             }
//         }
//     }

//     private func formatTime(_ seconds: Double) -> String {
//         let totalSeconds = Int(seconds)
//         let minutes = totalSeconds / 60
//         let secs = totalSeconds % 60
//         return String(format: "%d:%02d", minutes, secs)
//     }
// }

// // MARK: - Preview
// #Preview {
//     struct PreviewWrapper: View {
//         private var unifiedState: AddMoveUnifiedState {
//             let state = AddMoveUnifiedState()

//             // Simulate a loaded video for preview
//             state.selectedVideo = AVAsset(url: URL(fileURLWithPath: "/dev/null"))
//             return state
//         }

//         var body: some View {
//             VideoTrimView(unifiedState: unifiedState)
//                 .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//                 .preferredColorScheme(.dark)
//         }
//     }

//     return PreviewWrapper()
// }