import SwiftUI
import AVKit

// less precise than UIKitPreciseTrimmerView

struct TrimControlPanelView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    
    // MARK: - State Properties
    @State private var initialStartTime: CMTime = .zero
    @State private var initialEndTime: CMTime = .zero
    
    private let handleWidth: CGFloat = 44
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.videoDuration.seconds > 0 {
                trimmerTimelineView
                    .padding(.top, 12)
            } else {
                placeholderTimelineView
            }
            timeDisplayView
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top)
    }
    
    // MARK: - UI Components
    private var trimmerTimelineView: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            
            ZStack(alignment: .leading) {
                // Background Track
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
                    .padding(.horizontal, handleWidth / 2)
                    .allowsHitTesting(false)
                
                // Active Range Bar
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: activeRangeWidth(in: totalWidth))
                    .frame(height: 12)
                    .cornerRadius(6)
                    .offset(x: activeRangeOffset(in: totalWidth))
                    .allowsHitTesting(false)
                
                // Start Handle
                handleView(isStartHandle: true)
                    .offset(x: startHandlePosition(in: totalWidth) - (handleWidth / 2))
                    .highPriorityGesture(dragGesture(isStartHandle: true, totalWidth: totalWidth))
                    .zIndex(viewModel.isDraggingStartHandle ? 2 : 1)
                
                // End Handle
                handleView(isStartHandle: false)
                    .offset(x: endHandlePosition(in: totalWidth) - (handleWidth / 2))
                    .highPriorityGesture(dragGesture(isStartHandle: false, totalWidth: totalWidth))
                    .zIndex(viewModel.isDraggingEndHandle ? 2 : 1)
            }
            .animation(nil, value: viewModel.startTime)
            .animation(nil, value: viewModel.endTime)
        }
        .frame(height: 60)
    }
    
    private var placeholderTimelineView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.5))
            .frame(height: 60)
            .cornerRadius(12)
            .overlay(ProgressView())
    }
    
    private var timeDisplayView: some View {
        // ... (This view remains the same)
        HStack {
            VStack(alignment: .leading) {
                Text("Start").font(.caption).foregroundColor(.secondary)
                Text(formatTime(viewModel.startTime)).font(.system(size: 16, weight: .bold, design: .monospaced))
            }
            Spacer()
            VStack {
                Text("Duration").font(.caption).foregroundColor(.secondary)
                Text(formatTime(viewModel.endTime - viewModel.startTime)).font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("End").font(.caption).foregroundColor(.secondary)
                Text(formatTime(viewModel.endTime)).font(.system(size: 16, weight: .bold, design: .monospaced))
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func handleView(isStartHandle: Bool) -> some View {
        let isDragging = isStartHandle ? viewModel.isDraggingStartHandle : viewModel.isDraggingEndHandle
        Capsule()
            .fill(Color.white)
            .frame(width: 8, height: 44)
            .opacity(isDragging ? 1.0 : 0.8)
            .shadow(radius: isDragging ? 4 : 2)
            .frame(width: handleWidth, height: 60)
            .contentShape(Rectangle())
    }
    
    // MARK: - Native Drag Gesture Logic
    private func dragGesture(isStartHandle: Bool, totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isStartHandle {
                    if !viewModel.isDraggingStartHandle {
                        initialStartTime = viewModel.startTime
                        viewModel.isDraggingStartHandle = true
                        viewModel.triggerHapticFeedback(for: .dragStart)
                    }
                } else {
                    if !viewModel.isDraggingEndHandle {
                        initialEndTime = viewModel.endTime
                        viewModel.isDraggingEndHandle = true
                        viewModel.triggerHapticFeedback(for: .dragStart)
                    }
                }
                updateTime(for: value, isStartHandle: isStartHandle, totalWidth: totalWidth)
            }
            .onEnded { _ in
                if isStartHandle {
                    viewModel.isDraggingStartHandle = false
                } else {
                    viewModel.isDraggingEndHandle = false
                }
                viewModel.triggerHapticFeedback(for: .dragEnd)
            }
    }
    
    private func updateTime(for value: DragGesture.Value, isStartHandle: Bool, totalWidth: CGFloat) {
        let effectiveWidth = totalWidth - handleWidth
        let translationX = value.translation.width
        let verticalDrag = abs(value.translation.height)
        let precisionScale = 1.0 - (min(1.0, max(0, verticalDrag / 100.0))) * 0.9

        if isStartHandle {
            let initialPosition = timeToPosition(initialStartTime, totalWidth: effectiveWidth)
            let newPosition = initialPosition + (translationX * precisionScale)
            
            let proposedTime = positionToTime(newPosition, totalWidth: effectiveWidth)
            
            let frameDuration = viewModel.oneFrameDuration
            let minTime = CMTime.zero
            var maxTime = viewModel.endTime - frameDuration
            if maxTime < .zero { maxTime = .zero }

            var clampedTime = proposedTime
            if frameDuration.seconds > 0 {
                let frameNumber = round(proposedTime.seconds / frameDuration.seconds)
                let snappedTime = CMTime(seconds: frameNumber * frameDuration.seconds, preferredTimescale: proposedTime.timescale)
                clampedTime = max(minTime, min(snappedTime, maxTime))
            }

            if didFrameChange(from: viewModel.startTime, to: clampedTime) { selectionFeedback.selectionChanged() }
            viewModel.startTime = clampedTime
            viewModel.requestSeek(to: clampedTime)
            
        } else { // End Handle
            let initialPosition = timeToPosition(initialEndTime, totalWidth: effectiveWidth)
            let newPosition = initialPosition + (translationX * precisionScale)
            
            let proposedTime = positionToTime(newPosition, totalWidth: effectiveWidth)
            
            let frameDuration = viewModel.oneFrameDuration
            let minTime = viewModel.startTime + frameDuration
            let maxTime = viewModel.videoDuration

            var clampedTime = proposedTime
            if frameDuration.seconds > 0 {
                let frameNumber = round(proposedTime.seconds / frameDuration.seconds)
                let snappedTime = CMTime(seconds: frameNumber * frameDuration.seconds, preferredTimescale: proposedTime.timescale)
                clampedTime = max(minTime, min(snappedTime, maxTime))
            }

            if didFrameChange(from: viewModel.endTime, to: clampedTime) { selectionFeedback.selectionChanged() }
            viewModel.endTime = clampedTime
            viewModel.requestSeek(to: clampedTime)
        }
    }
    
    private func didFrameChange(from oldTime: CMTime, to newTime: CMTime) -> Bool {
        guard viewModel.oneFrameDuration.seconds > 0 else { return false }
        let oldFrame = round(oldTime.seconds / viewModel.oneFrameDuration.seconds)
        let newFrame = round(newTime.seconds / viewModel.oneFrameDuration.seconds)
        return oldFrame != newFrame
    }
    
    // MARK: - Helper Methods
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
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite && !seconds.isNaN else { return "00:00.00" }
        let totalSeconds = max(0, seconds)
        let minutes = Int(totalSeconds) / 60
        let remainingSeconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, remainingSeconds, milliseconds)
    }
}