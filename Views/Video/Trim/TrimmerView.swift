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

// Import for HybridPreciseTrimmerView
import Foundation

// main wrapper view for the video trimmer
struct TrimmerView: View {
    @ObservedObject var trimmerViewModel: TrimmerViewModel
    @State var rotationQuarterTurns: Int

    // Video player model for proper lifecycle management
    @StateObject private var videoModel = VideoPlayerViewModel()

    // Event-driven communication: emit events instead of mutating parent state
    let onError: (String, Error?) -> Void
    let onRotate: (Int) -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    // Track view construction for debugging
    private let constructionId = UUID()
    private let constructionTime = Date().timeIntervalSince1970

    private var isModified: Bool {
        trimmerViewModel.startTime.seconds > 0 || trimmerViewModel.endTime < trimmerViewModel.videoDuration
    }

    private var isExportInProgress: Bool {
        trimmerViewModel.isExporting
    }

    init(trimmerViewModel: TrimmerViewModel, rotationQuarterTurns: Int, onError: @escaping (String, Error?) -> Void, onRotate: @escaping (Int) -> Void, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.trimmerViewModel = trimmerViewModel
        _rotationQuarterTurns = State(initialValue: rotationQuarterTurns)
        self.onError = onError
        self.onRotate = onRotate
        self.onCancel = onCancel
        self.onSave = onSave

        // Log view construction for lifecycle tracking
        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"
        print("🏗️ [\(String(format: "%.3f", constructionTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Constructed on \(threadInfo) thread")
        print("   📊 Initial rotation: \(rotationQuarterTurns)")
        print("   🎯 Callbacks configured: true")

        // REMOVED: State mutation during construction moved to .onAppear
        print("   🔄 Rotation sync deferred to .onAppear (prevents infinite loop)")
    }

    // MARK: - Professional Timecode Display (Inline Format)
    private var timeDisplayView: some View {
        HStack(spacing: 24) {
            // Start time - positioned near left handle
            VStack(alignment: .leading, spacing: 4) {
                Text("Start")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTimeInline(trimmerViewModel.startTime))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            // Duration - centered underneath
            VStack(spacing: 4) {
                Text("Duration")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTimeInline(trimmerViewModel.endTime - trimmerViewModel.startTime))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            // End time - positioned near right handle
            VStack(alignment: .trailing, spacing: 4) {
                Text("End")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTimeInline(trimmerViewModel.endTime))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }

    // MARK: - Inline Time Formatting (shows all digits including ms)
    private func formatTimeInline(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite && !seconds.isNaN else { return "00:00.00" }

        let totalSeconds = max(0, seconds)
        let minutes = Int(totalSeconds) / 60
        let remainingSeconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)

        // Always show 2 digits for minutes, 2 for seconds, 2 for milliseconds
        return String(format: "%02d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }

    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite && !seconds.isNaN else { return "00:00.00" }
        let totalSeconds = max(0, seconds)
        let minutes = Int(totalSeconds) / 60
        let remainingSeconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }


    var body: some View {
        let bodyEvaluationTime = Date().timeIntervalSince1970
        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"

        print("🔄 [\(String(format: "%.3f", bodyEvaluationTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Body evaluated on \(threadInfo) thread")
        print("   ⏱️ Time since construction: \(String(format: "%.3f", bodyEvaluationTime - constructionTime))s")
        print("   📊 Current rotation: \(rotationQuarterTurns)")
        print("   🎬 Video duration: \(String(format: "%.2f", trimmerViewModel.videoDuration.seconds))s")
        print("   ✂️ Trim range: \(String(format: "%.2f", trimmerViewModel.startTime.seconds)) - \(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")

        return VStack(spacing: 0) {
            // Video Player with proper lifecycle management
            CustomVideoPlayerView(videoModel: videoModel, asset: trimmerViewModel.asset, rotationQuarterTurns: rotationQuarterTurns)
                .frame(height: 300)
                .cornerRadius(12)
                .accessibilityIdentifier("TrimmerVideoPlayer")

            // Precise Trimming Controls - Professional Capsule Design
            TrimmerFactory.createTrimmer(
                with: .professionalCapsule,
                viewModel: trimmerViewModel
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Classic Timecode Display
            timeDisplayView
                .padding(.horizontal, 24)

            Spacer()

            ActionBottomBar(
                onCancel: {
                    print("🎬 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Cancel button tapped")
                    // Stop coalescing to prevent async task issues during navigation
                    trimmerViewModel.stopCoalescing()
                    // Clean teardown of video player to prevent lingering tasks
                    videoModel.teardown()
                    // Cancel trimming and navigate back to PreTrimView
                    onCancel()
                },
                onExport: {
                    let exportStartTime = Date().timeIntervalSince1970
                    print("🎬 [\(String(format: "%.3f", exportStartTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Export initiated")

                    Task {
                        trimmerViewModel.isExporting = true
                        defer { trimmerViewModel.isExporting = false }

                        guard trimmerViewModel.validateTrimRanges() else {
                            let validationTime = Date().timeIntervalSince1970
                            print("❌ [\(String(format: "%.3f", validationTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Invalid trim ranges detected")
                            print("   ✂️ Current range: \(String(format: "%.2f", trimmerViewModel.startTime.seconds)) - \(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")
                            onError("Invalid trim ranges. Please ensure start time is before end time.", nil)
                            return
                        }

                        do {
                            print("📤 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Starting video export")
                            let exportedURL = try await trimmerViewModel.exportVideo()
                            let exportEndTime = Date().timeIntervalSince1970
                            print("✅ [\(String(format: "%.3f", exportEndTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Export succeeded in \(String(format: "%.3f", exportEndTime - exportStartTime))s")
                            print("   📁 URL: \(exportedURL.lastPathComponent)")
                            print("   🎬 EXPORT COMPLETE: Rotation: \(trimmerViewModel.rotationQuarterTurns) turns")

                            // Success haptic and navigation to NameMoveView
                            MotionCatalog.Accessibility.successHaptic()
                            onSave() // Navigate to naming screen
                        } catch {
                            let errorTime = Date().timeIntervalSince1970
                            print("❌ [\(String(format: "%.3f", errorTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: Export failed after \(String(format: "%.3f", errorTime - exportStartTime))s")
                            print("   📝 Error type: \(type(of: error))")
                            print("   🔍 Error details: \(error.localizedDescription)")

                            // Log additional context for debugging
                            if let nsError = error as NSError? {
                                print("   🏷️ Error domain: \(nsError.domain)")
                                print("   🔢 Error code: \(nsError.code)")
                                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                                    print("   🔧 Underlying error: \(underlying.localizedDescription)")
                                }
                            }

                            onError("Failed to export video.", error)
                        }
                    }
                },
                onRotate: {
                    let newTurns = (rotationQuarterTurns + 1) % 4
                    rotationQuarterTurns = newTurns
                    // Apply rotation immediately to the video preview
                    videoModel.setRotation(newTurns)
                    onRotate(newTurns)

                    // Haptic feedback
                    UIAccessibility.post(notification: .announcement, argument: "Rotated ninety degrees")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                },
                isModified: isModified,
                isExporting: isExportInProgress
            )
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 12)
        }
        .overlay(alignment: .bottom) {
            if trimmerViewModel.showMinimumDurationWarning {
                MinimumDurationWarningView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            let appearTime = Date().timeIntervalSince1970
            print("🎬 [\(String(format: "%.3f", appearTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: View appeared")
            print("   ⏱️ Time since construction: \(String(format: "%.3f", appearTime - constructionTime))s")

            // Safe state synchronization after view construction
            print("   🔄 Syncing rotation state: \(rotationQuarterTurns)")
            trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
            print("   ✅ Rotation state synced successfully")
        }
        .onChange(of: rotationQuarterTurns) { _, newValue in
            trimmerViewModel.rotationQuarterTurns = newValue
        }
        .task {
            print("🎬 TrimmerView: Setting up video source")
            videoModel.setSource(asset: trimmerViewModel.asset, quarterTurns: rotationQuarterTurns)
        }
        .onDisappear {
            let disappearTime = Date().timeIntervalSince1970
            print("👋 [\(String(format: "%.3f", disappearTime))] TRIMMER VIEW [\(constructionId.uuidString.prefix(8))]: View disappeared")
            print("   ⏱️ Total lifetime: \(String(format: "%.3f", disappearTime - constructionTime))s")
        }
    }

    private func rotateVideo() {
        let rotateTime = Date().timeIntervalSince1970
        let newRotationQuarterTurns = (rotationQuarterTurns + 1) % 4

        print("🔄 [\(String(format: "%.3f", rotateTime))] TRIMMER VIEW: rotateVideo() called")
        print("   📐 Current rotation: \(rotationQuarterTurns) → New rotation: \(newRotationQuarterTurns)")

        // Event-driven communication: emit rotation event instead of mutating parent state
        print("📤 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER VIEW: Emitting rotation event via callback")
        onRotate(newRotationQuarterTurns)
        print("✅ [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER VIEW: Rotation event emitted")

        // Update local state to match
        rotationQuarterTurns = newRotationQuarterTurns

        // Haptic feedback (preserved functionality)
        UIAccessibility.post(notification: .announcement, argument: "Rotated ninety degrees")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        print("🎉 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER VIEW: Rotation complete")
    }

    // MARK: - Minimum Duration Warning View
    private struct MinimumDurationWarningView: View {
        var body: some View {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.buttonHard)
                Text("Minimum duration: 3 seconds")
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