//
//  PreciseVideoTrimmerViewNew.swift
//  BreakingFlashcards
//
//  Created by AI Assistant on 8/30/25.
//

import SwiftUI
import AVKit
import AVFoundation
import BreakingFlashcards

// MARK: - Main Video Trimmer View
struct PreciseVideoTrimmerView: View {
    @ObservedObject var addMoveViewModel: AddMoveViewModel // New: Direct access to AddMoveViewModel
    let trimmerViewModel: TrimmerViewModel // Renamed for clarity
    let asset: AVAsset
    let photosIdentifier: String? // New: Passed from AddMoveViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top 40%: Video preview
                CustomVideoPlayerView(trimmerViewModel.player)
                    .frame(height: UIScreen.main.bounds.height * 0.4)
                    .accessibilityIdentifier("TrimmerVideoPlayer")

                // Bottom 60%: Controls
                TrimControlPanelView(viewModel: trimmerViewModel, onCancel: {
                    addMoveViewModel.cancelTrimming() // Direct call to AddMoveViewModel
                }, onExport: { // This is the "Save Trim" action
                    // Validate trim ranges before proceeding
                    guard trimmerViewModel.validateTrimRanges() else {
                        addMoveViewModel.state = .error(message: "Invalid trim ranges. Please ensure start time is before end time.", underlyingError: nil)
                        return
                    }

                    // Get trim ranges from the trimmer view model
                    let (startTime, endTime) = trimmerViewModel.getTrimRanges()

                    // Transition to .naming state in AddMoveViewModel
                    addMoveViewModel.state = .naming(photosIdentifier: photosIdentifier ?? "", originalAsset: asset, trimStartTime: startTime, trimEndTime: endTime)
                })
            }

            // Modal progress overlay (Remove this as TrimmerViewModel no longer exports)
            // if trimmerViewModel.isExporting {
            //     Color.black.opacity(0.8)
            //         .ignoresSafeArea()
            //         .overlay(
            //             VStack(spacing: 20) {
            //                 ZStack {
            //                     Circle()
            //                         .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            //                         .frame(width: 80, height: 80)
            //
            //                     Circle()
            //                         .trim(from: 0, to: trimmerViewModel.exportProgress)
            //                         .stroke(Color.accent, lineWidth: 8)
            //                         .frame(width: 80, height: 80)
            //                         .rotationEffect(.degrees(-90))
            //
            //                     Text("\(Int(trimmerViewModel.exportProgress * 100))")
            //                         .font(.ibmPlexMono(size: 16, weight: .bold))
            //                         .foregroundColor(.white)
            //                 }
            //
            //                 Text("Creating Clip…")
            //                     .font(.ibmPlexMono(size: 16))
            //                     .foregroundColor(.white)
            //             }
            //         )
            //         .transition(.opacity)
            // }
        }
        .onChange(of: trimmerViewModel.startTime) { _, newStart in // Use trimmerViewModel
            if trimmerViewModel.isDraggingStartHandle { // Use trimmerViewModel
                trimmerViewModel.seek(to: newStart) // Use trimmerViewModel
            }
        }
        .onChange(of: trimmerViewModel.endTime) { _, newEnd in // Use trimmerViewModel
            if trimmerViewModel.isDraggingEndHandle { // Use trimmerViewModel
                trimmerViewModel.seek(to: newEnd) // Use trimmerViewModel
            }
        }
    }

    private func calculateLoupePosition(for time: Double) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let timelineWidth: CGFloat = screenWidth - 40 // Account for padding

        // Guard against division by zero or invalid video duration
        guard trimmerViewModel.videoDuration > 0 && !trimmerViewModel.videoDuration.isNaN else {
            return 20 // Default to left padding position
        }

        let progress = time / trimmerViewModel.videoDuration
        // Ensure progress is within valid range and not NaN
        let clampedProgress = max(0, min(1, progress.isNaN ? 0 : progress))

        return 20 + (timelineWidth * CGFloat(clampedProgress)) // 20px left padding
    }
}

// MARK: - Async Wrapper
struct AsyncPreciseVideoTrimmerView: View {
    @ObservedObject var addMoveViewModel: AddMoveViewModel // New: Direct access to AddMoveViewModel
    let asset: AVAsset
    let photosIdentifier: String? // New: Passed from AddMoveViewModel

    @State private var trimmerViewModel: TrimmerViewModel? // Renamed for clarity

    var body: some View {
        ZStack {
            if let trimmerViewModel = trimmerViewModel { // Use trimmerViewModel
                PreciseVideoTrimmerView(addMoveViewModel: addMoveViewModel, trimmerViewModel: trimmerViewModel, asset: asset, photosIdentifier: photosIdentifier) // Pass new parameters
            } else {
                // Loading state while viewModel is being initialized
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.accent)
                    Text("Loading video...")
                        .font(.ibmPlexMono(size: 16))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            }
        }
        .task {
            trimmerViewModel = TrimmerViewModel(asset: asset) // Use trimmerViewModel
            do {
                try await trimmerViewModel?.setupAsync() // Use trimmerViewModel
            } catch {
                addMoveViewModel.state = .error(message: "Failed to load video for trimming.", underlyingError: error.localizedDescription)
            }
        }
    }
}

// MARK: - Control Panel
private struct TrimControlPanelView: View {
    @Bindable var viewModel: TrimmerViewModel
    let onCancel: () -> Void
    let onExport: () -> Void // This is now "Save Trim"

    var body: some View {
        VStack(spacing: 16) {
            // Range slider
            RangeSlider(
                startTime: $viewModel.startTime,
                endTime: $viewModel.endTime,
                isEditing: $viewModel.isEditing,
                isDraggingStart: $viewModel.isDraggingStartHandle,
                isDraggingEnd: $viewModel.isDraggingEndHandle,
                range: 0...viewModel.videoDuration,
                onEditingChanged: { isEditing, time in
                    if isEditing {
                        viewModel.generatePreviewImage(at: time)
                    } else {
                        viewModel.currentPreviewImage = nil
                    }
                },
                onHapticFeedback: {
                    viewModel.triggerHapticFeedback()
                }
            )
            .padding(.horizontal, 20)
            .accessibilityIdentifier("TrimmerRangeSlider") // Added accessibility identifier

            // Time display
            HStack {
                Text(formatTime(viewModel.startTime))
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("TrimmerStartTimeText") // Added accessibility identifier
                Spacer()
                Text(formatTime(viewModel.endTime - viewModel.startTime))
                    .font(.ibmPlexMono(size: 14))
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("TrimmerDurationText") // Added accessibility identifier
                Spacer()
                Text(formatTime(viewModel.endTime))
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .foregroundColor(.accent)
                    .accessibilityIdentifier("TrimmerEndTimeText") // Added accessibility identifier
            }
            .padding(.horizontal, 20)

            Spacer()

            // Action buttons
            HStack(spacing: 15) {
                Button("Back", action: onCancel) // Renamed "Cancel" to "Back"
                    .buttonStyle(SecondaryActionStyle())
                    // .disabled(viewModel.isExporting) // Remove this
                    .accessibilityIdentifier("TrimmerBackButton") // Added accessibility identifier
                Button("Save Trim", action: onExport) // Renamed "Create Clip" to "Save Trim"
                    .buttonStyle(PrimaryActionStyle())
                    // .disabled(viewModel.isExporting) // Remove this
                    .accessibilityIdentifier("TrimmerSaveTrimButton") // Added accessibility identifier
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}