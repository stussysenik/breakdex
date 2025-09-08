//
//  TrimmerView.swift
//  BreakingFlashcards
//
//  Created by AI Assistant on 8/30/25.
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import Combine

// main wrapper view for the video trimmer
struct TrimmerView: View {
    @ObservedObject var addMoveViewModel: AddMoveViewModel
    @ObservedObject var trimmerViewModel: TrimmerViewModel
    @State var rotationQuarterTurns: Int

    @State private var showMinDurationWarning = false
    @State private var warningDismissTimer: Timer?

    private var isModified: Bool {
        trimmerViewModel.startTime.seconds > 0 || trimmerViewModel.endTime < trimmerViewModel.videoDuration
    }

    private var isExportInProgress: Bool {
        trimmerViewModel.isExporting
    }

    init(addMoveViewModel: AddMoveViewModel, trimmerViewModel: TrimmerViewModel, rotationQuarterTurns: Int) {
        self.addMoveViewModel = addMoveViewModel
        self.trimmerViewModel = trimmerViewModel
        _rotationQuarterTurns = State(initialValue: rotationQuarterTurns)

        // Sync rotation state with the view model
        trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                TrimmerVideoPlayerView(player: trimmerViewModel.player) // video player with composition-based rotation
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("TrimmerVideoPlayer")
            }
            .assertNoTransforms() // Runtime assertion: video surface must not have transforms

            Spacer()

            ActionBottomBar(
                onCancel: { addMoveViewModel.cancelTrimming() },
                onExport: {
                    Task {
                        trimmerViewModel.isExporting = true
                        defer { trimmerViewModel.isExporting = false }

                        guard trimmerViewModel.validateTrimRanges() else {
                            addMoveViewModel.state = .error(message: "Invalid trim ranges. Please ensure start time is before end time.", underlyingError: nil)
                            return
                        }

                        do {
                            let exportedURL = try await trimmerViewModel.exportVideo()
                            let trimmedAsset = AVURLAsset(url: exportedURL)
                            print("✅ EXPORT SUCCESS: URL=\(exportedURL), Asset created=\(trimmedAsset != nil)")
                            print("🎬 EXPORT COMPLETE: Transitioning to naming state with rotationQuarterTurns: \(trimmerViewModel.rotationQuarterTurns)")
                            addMoveViewModel.state = .naming(photosIdentifier: trimmerViewModel.photosIdentifier ?? "", originalAsset: trimmerViewModel.asset, trimmedAsset: trimmedAsset, trimStartTime: trimmerViewModel.startTime.seconds, trimEndTime: trimmerViewModel.endTime.seconds, rotationQuarterTurns: trimmerViewModel.rotationQuarterTurns)
                            MotionCatalog.Accessibility.successHaptic() // Success haptic
                        } catch {
                            print("❌ EXPORT FAILED: \(error.localizedDescription)")
                            addMoveViewModel.state = .error(message: "Failed to export video.", underlyingError: error.localizedDescription)
                        }
                    }
                },
                onRotate: rotateVideo,
                isModified: isModified,
                isExporting: isExportInProgress
            )
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 12)
        }
        .overlay(alignment: .bottom) {
            if showMinDurationWarning {
                MinimumDurationWarningView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: trimmerViewModel.startTime) { _, newStart in
            trimmerViewModel.requestSeek(to: newStart)
        }
        .onChange(of: trimmerViewModel.endTime) { _, newEnd in
            trimmerViewModel.requestSeek(to: newEnd)
        }
        .onChange(of: rotationQuarterTurns) { _, newRotation in
            // Sync the view model's rotation state with the view's parameter
            trimmerViewModel.rotationQuarterTurns = newRotation
            Task {
                await trimmerViewModel.updatePreview()
            }
        }
        .onChange(of: addMoveViewModel.state) { _, newState in
            // Sync local rotation state with AddMoveViewModel state changes
            if case .trimming(_, _, let stateRotation) = newState {
                rotationQuarterTurns = stateRotation
                trimmerViewModel.rotationQuarterTurns = stateRotation
            }
        }
        .task {
            do {
                try await trimmerViewModel.setupAsync()
                await trimmerViewModel.updatePreview()
            } catch {
                addMoveViewModel.state = .error(message: "Failed to load video for trimming.", underlyingError: error.localizedDescription)
            }
        }
    }

    private func rotateVideo() {
        let newRotationQuarterTurns = (rotationQuarterTurns + 1) % 4
        addMoveViewModel.updateTrimmingRotation(rotationQuarterTurns: newRotationQuarterTurns)
        // Update local state to match
        rotationQuarterTurns = newRotationQuarterTurns
        UIAccessibility.post(notification: .announcement, argument: "Rotated ninety degrees")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Minimum Duration Warning View
    private struct MinimumDurationWarningView: View {
        var body: some View {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.buttonHard)
                Text("Minimum duration: 1 second")
                    .font(.caption)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.9))
            )
            .padding(.bottom, 20)
        }
    }
}

struct ActionBottomBar: View {
    let onCancel: () -> Void
    let onExport: () -> Void
    let onRotate: () -> Void
    let isModified: Bool
    let isExporting: Bool

    var body: some View {
        HStack(spacing: 24) {
            Button("Back", action: onCancel)
                .buttonStyle(.borderless)
                .tint(.white)
                .frame(maxWidth: .infinity)

            Button(action: onRotate) {
                Image(systemName: "rotate.right").font(.title2)
            }
            .buttonStyle(.borderless)
            .tint(.white)
            .frame(width: 44, height: 44)

            if isExporting {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Button("Save Trim", action: onExport)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .frame(maxWidth: .infinity)
                    .disabled(!isModified)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
}