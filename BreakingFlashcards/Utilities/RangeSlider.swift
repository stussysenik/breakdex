import SwiftUI

struct RangeSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    @Binding var isEditing: Bool
    @Binding var isDraggingStart: Bool
    @Binding var isDraggingEnd: Bool
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool, Double) -> Void
    let onHapticFeedback: () -> Void
    
    private let handleWidth: CGFloat = 24
    private let trackHeight: CGFloat = 8
    private let minimumSelection: Double = 0.5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let rangeSize = range.upperBound - range.lowerBound

            // Guard against invalid range
            guard rangeSize > 0 && !rangeSize.isNaN && width > 0 else {
                return AnyView(
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: trackHeight)
                            .cornerRadius(trackHeight / 2)
                    }
                    .frame(height: handleWidth)
                )
            }

            let startProgress = (startTime - range.lowerBound) / rangeSize
            let endProgress = (endTime - range.lowerBound) / rangeSize

            // Clamp progress values to prevent NaN/invalid positions
            let clampedStartProgress = max(0, min(1, startProgress.isNaN ? 0 : startProgress))
            let clampedEndProgress = max(0, min(1, endProgress.isNaN ? 1 : endProgress))

            let startPosition = CGFloat(clampedStartProgress) * width
            let endPosition = CGFloat(clampedEndProgress) * width

            return AnyView(
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: trackHeight)
                        .cornerRadius(trackHeight / 2)

                    Rectangle()
                        .fill(Color.accent)
                        .frame(width: max(0, endPosition - startPosition), height: trackHeight)
                        .cornerRadius(trackHeight / 2)
                        .offset(x: startPosition)

                    handle(at: startPosition, isDragging: $isDraggingStart, time: $startTime, isStartHandle: true, width: width)
                    handle(at: endPosition, isDragging: $isDraggingEnd, time: $endTime, isStartHandle: false, width: width)
                }
                .frame(height: handleWidth)
            )
        }
        .frame(height: 40)
    }
    
    @ViewBuilder
    private func handle(at position: CGFloat, isDragging: Binding<Bool>, time: Binding<Double>, isStartHandle: Bool, width: CGFloat) -> some View {
        Circle()
            .fill(Color.accent)
            .frame(width: handleWidth, height: handleWidth)
            .overlay(Circle().stroke(Color.black, lineWidth: 2))
            .offset(x: position - handleWidth / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging.wrappedValue {
                            isDragging.wrappedValue = true
                            onHapticFeedback()
                        }
                        
                        let newPosition = max(0, min(value.location.x, width))
                        let newTime = range.lowerBound + Double(newPosition / width) * (range.upperBound - range.lowerBound)
                        
                        if isStartHandle {
                            time.wrappedValue = max(range.lowerBound, min(endTime - minimumSelection, newTime))
                        } else {
                            time.wrappedValue = min(range.upperBound, max(startTime + minimumSelection, newTime))
                        }
                        onEditingChanged(true, time.wrappedValue)
                    }
                    .onEnded { _ in
                        isDragging.wrappedValue = false
                        onEditingChanged(false, time.wrappedValue)
                    }
            )
    }
}
