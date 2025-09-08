//
//  HybridPreciseTrimmerView.swift
//  BreakingFlashcards
//
//  Created by AI Assistant
//  Hybrid component combining UIKit precision with SwiftUI visual flexibility
//

import SwiftUI
import AVFoundation

struct HybridPreciseTrimmerView: View {
    @ObservedObject var viewModel: TrimmerViewModel

    // MARK: - Handle Content Configuration
    let startHandleContent: AnyView
    let endHandleContent: AnyView

    // Default emoji handles for easy use
    init(viewModel: TrimmerViewModel,
         startHandleContent: AnyView = AnyView(Text("👟")),
         endHandleContent: AnyView = AnyView(Text("🔥"))) {
        self.viewModel = viewModel
        self.startHandleContent = startHandleContent
        self.endHandleContent = endHandleContent
    }

    // MARK: - Layout Constants
    private let handleWidth: CGFloat = 44
    private let trackHeight: CGFloat = 8
    private let activeRangeHeight: CGFloat = 12
    private let totalHeight: CGFloat = 60

    // MARK: - State
    @State private var initialStartTime: CMTime = .zero
    @State private var initialEndTime: CMTime = .zero
    @State private var startHandleInitialPosition: CGFloat = 0
    @State private var endHandleInitialPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track (UIKit styling)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: trackHeight)
                    .cornerRadius(4)
                    .padding(.horizontal, handleWidth / 2)
                    .allowsHitTesting(false)

                // Active range bar (UIKit styling)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: activeRangeWidth(in: geometry.size.width))
                    .frame(height: activeRangeHeight)
                    .cornerRadius(6)
                    .offset(x: activeRangeOffset(in: geometry.size.width))
                    .allowsHitTesting(false)

                // Start Handle
                SwiftUIHandleBridge(
                    content: HandleView { startHandleContent },
                    onChanged: { gesture in
                        handlePan(gesture, isStartHandle: true, totalWidth: geometry.size.width)
                    },
                    onEnded: { gesture in
                        handlePanEnded(gesture, isStartHandle: true)
                    },
                    isStartHandle: true
                )
                .frame(width: handleWidth, height: totalHeight)
                .offset(x: startHandlePosition(in: geometry.size.width) - handleWidth / 2)
                .zIndex(viewModel.isDraggingStartHandle ? 2 : 1)

                // End Handle
                SwiftUIHandleBridge(
                    content: HandleView { endHandleContent },
                    onChanged: { gesture in
                        handlePan(gesture, isStartHandle: false, totalWidth: geometry.size.width)
                    },
                    onEnded: { gesture in
                        handlePanEnded(gesture, isStartHandle: false)
                    },
                    isStartHandle: false
                )
                .frame(width: handleWidth, height: totalHeight)
                .offset(x: endHandlePosition(in: geometry.size.width) - handleWidth / 2)
                .zIndex(viewModel.isDraggingEndHandle ? 2 : 1)
            }
        }
        .frame(height: totalHeight)
    }

    // MARK: - Position Calculations
    private func startHandlePosition(in totalWidth: CGFloat) -> CGFloat {
        let effectiveWidth = totalWidth - handleWidth
        return timeToPosition(viewModel.startTime, totalWidth: effectiveWidth) + handleWidth / 2
    }

    private func endHandlePosition(in totalWidth: CGFloat) -> CGFloat {
        let effectiveWidth = totalWidth - handleWidth
        return timeToPosition(viewModel.endTime, totalWidth: effectiveWidth) + handleWidth / 2
    }

    private func activeRangeOffset(in totalWidth: CGFloat) -> CGFloat {
        startHandlePosition(in: totalWidth)
    }

    private func activeRangeWidth(in totalWidth: CGFloat) -> CGFloat {
        endHandlePosition(in: totalWidth) - startHandlePosition(in: totalWidth)
    }

    private func timeToPosition(_ time: CMTime, totalWidth: CGFloat) -> CGFloat {
        guard viewModel.videoDuration.seconds > 0 else { return 0 }
        let percentage = time.seconds / viewModel.videoDuration.seconds
        return CGFloat(percentage) * totalWidth
    }

    private func positionToTime(_ position: CGFloat, totalWidth: CGFloat) -> CMTime {
        guard totalWidth > 0 else { return .zero }
        let percentage = position / totalWidth
        let seconds = Double(percentage) * viewModel.videoDuration.seconds
        return CMTime(seconds: seconds, preferredTimescale: viewModel.videoDuration.timescale)
    }

    // MARK: - Gesture Handling (UIKit Precision Algorithms)
    private func handlePan(_ gesture: UIPanGestureRecognizer, isStartHandle: Bool, totalWidth: CGFloat) {
        let effectiveWidth = totalWidth - handleWidth

        switch gesture.state {
        case .began:
            handlePanBegan(isStartHandle: isStartHandle, effectiveWidth: effectiveWidth)
        case .changed:
            handlePanChanged(gesture: gesture, isStartHandle: isStartHandle, effectiveWidth: effectiveWidth)
        case .ended, .cancelled:
            handlePanEnded(gesture, isStartHandle: isStartHandle)
        default:
            break
        }
    }

    private func handlePanBegan(isStartHandle: Bool, effectiveWidth: CGFloat) {
        if isStartHandle {
            initialStartTime = viewModel.startTime
            startHandleInitialPosition = timeToPosition(viewModel.startTime, totalWidth: effectiveWidth)
            viewModel.isDraggingStartHandle = true
        } else {
            initialEndTime = viewModel.endTime
            endHandleInitialPosition = timeToPosition(viewModel.endTime, totalWidth: effectiveWidth)
            viewModel.isDraggingEndHandle = true
        }
        viewModel.triggerHapticFeedback(for: .dragStart)
    }

    private func handlePanChanged(gesture: UIPanGestureRecognizer, isStartHandle: Bool, effectiveWidth: CGFloat) {
        let translation = gesture.translation(in: gesture.view)
        let verticalDistance = abs(translation.y)

        // Precision scaling based on vertical drag
        let precisionScale = calculatePrecisionScale(verticalDistance: verticalDistance)

        // Calculate new position
        let initialPosition = isStartHandle ? startHandleInitialPosition : endHandleInitialPosition
        let initialTime = isStartHandle ? initialStartTime : initialEndTime
        let translationX = translation.x * precisionScale

        updateTime(translationX: translationX, initialTime: initialTime, initialPosition: initialPosition,
                  isStartHandle: isStartHandle, effectiveWidth: effectiveWidth)
    }

    private func handlePanEnded(_ gesture: UIPanGestureRecognizer, isStartHandle: Bool) {
        if isStartHandle {
            viewModel.isDraggingStartHandle = false
        } else {
            viewModel.isDraggingEndHandle = false
        }
        viewModel.triggerHapticFeedback(for: .dragEnd)
    }

    private func calculatePrecisionScale(verticalDistance: CGFloat) -> CGFloat {
        let maxVerticalDistance: CGFloat = 100
        let precisionReduction = min(verticalDistance / maxVerticalDistance, 1.0)
        return 1.0 - (precisionReduction * 0.9) // Scale from 1.0 to 0.1
    }

    private func updateTime(translationX: CGFloat, initialTime: CMTime, initialPosition: CGFloat,
                           isStartHandle: Bool, effectiveWidth: CGFloat) {
        let newPosition = initialPosition + translationX
        let proposedTime = positionToTime(newPosition, totalWidth: effectiveWidth)

        let frameDuration = viewModel.oneFrameDuration
        let minTime = isStartHandle ? CMTime.zero : viewModel.startTime + frameDuration
        let maxTime = isStartHandle ? viewModel.endTime - frameDuration : viewModel.videoDuration

        var clampedTime = proposedTime
        if frameDuration.seconds > 0 {
            let frameNumber = round(proposedTime.seconds / frameDuration.seconds)
            let snappedTime = CMTime(seconds: frameNumber * frameDuration.seconds,
                                   preferredTimescale: proposedTime.timescale)
            clampedTime = max(minTime, min(snappedTime, maxTime))
        }

        // Trigger haptic feedback for frame changes
        if didFrameChange(from: isStartHandle ? viewModel.startTime : viewModel.endTime, to: clampedTime) {
            let feedback = UISelectionFeedbackGenerator()
            feedback.selectionChanged()
        }

        if isStartHandle {
            viewModel.startTime = clampedTime
        } else {
            viewModel.endTime = clampedTime
        }

        viewModel.requestSeek(to: clampedTime)
    }

    private func didFrameChange(from oldTime: CMTime, to newTime: CMTime) -> Bool {
        guard viewModel.oneFrameDuration.seconds > 0 else { return false }
        let oldFrame = round(oldTime.seconds / viewModel.oneFrameDuration.seconds)
        let newFrame = round(newTime.seconds / viewModel.oneFrameDuration.seconds)
        return oldFrame != newFrame
    }
}

// MARK: - Convenience Initializers for Common Handle Styles
extension HybridPreciseTrimmerView {
    // Emoji handles
    static func emoji(viewModel: TrimmerViewModel,
                     startEmoji: String = "👟",
                     endEmoji: String = "🔥") -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleContent: AnyView(Text(startEmoji)),
            endHandleContent: AnyView(Text(endEmoji))
        )
    }

    // SF Symbol handles
    static func symbols(viewModel: TrimmerViewModel,
                       startSymbol: String = "scissors",
                       endSymbol: String = "scissors") -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleContent: AnyView(
                Image(systemName: startSymbol)
                    .foregroundColor(.blue)
            ),
            endHandleContent: AnyView(
                Image(systemName: endSymbol)
                    .foregroundColor(.blue)
            )
        )
    }

    // Custom view handles
    static func custom(viewModel: TrimmerViewModel,
                      startView: some View,
                      endView: some View) -> HybridPreciseTrimmerView {
        HybridPreciseTrimmerView(
            viewModel: viewModel,
            startHandleContent: AnyView(startView),
            endHandleContent: AnyView(endView)
        )
    }
}
