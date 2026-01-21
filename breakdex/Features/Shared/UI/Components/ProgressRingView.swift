import SwiftUI

/// A circular progress ring component for displaying progress percentages.
///
/// Usage:
/// ```swift
/// ProgressRingView(progress: 0.75) // 75% progress
///
/// ProgressRingView(
///     progress: 0.5,
///     trackColor: .neutralGray200,
///     fillColor: .stateMastery,
///     lineWidth: 8,
///     showPercentage: true
/// )
/// ```
struct ProgressRingView: View {
    /// Progress value between 0 and 1
    let progress: Double

    /// Color of the background track ring
    var trackColor: Color = .neutralGray200

    /// Color of the filled progress portion
    var fillColor: Color = .stateMastery

    /// Width of the ring stroke
    var lineWidth: CGFloat = 8

    /// Whether to show the percentage in the center
    var showPercentage: Bool = true

    /// Font size for the percentage text
    var fontSize: CGFloat = 14

    /// Size of the ring (width and height)
    var size: CGFloat = 60

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percentageText: String {
        "\(Int(clampedProgress * 100))%"
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Progress fill
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    fillColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: clampedProgress)

            // Percentage text
            if showPercentage {
                Text(percentageText)
                    .font(.ibmPlexMono(size: fontSize, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(percentageText)")
        .accessibilityValue(percentageText)
    }
}

/// A mini progress ring for inline display in lists
struct MiniProgressRing: View {
    let progress: Double
    var fillColor: Color = .accent

    var body: some View {
        ProgressRingView(
            progress: progress,
            fillColor: fillColor,
            lineWidth: 4,
            showPercentage: false,
            size: 24
        )
    }
}

// MARK: - Previews

#Preview("Progress Values") {
    HStack(spacing: Spacing.lg) {
        ProgressRingView(progress: 0)
        ProgressRingView(progress: 0.25)
        ProgressRingView(progress: 0.5)
        ProgressRingView(progress: 0.75)
        ProgressRingView(progress: 1.0)
    }
    .padding()
}

#Preview("Custom Colors") {
    HStack(spacing: Spacing.lg) {
        ProgressRingView(
            progress: 0.3,
            fillColor: .stateNew
        )
        ProgressRingView(
            progress: 0.6,
            fillColor: .stateLearning
        )
        ProgressRingView(
            progress: 0.9,
            fillColor: .stateMastery
        )
    }
    .padding()
}

#Preview("Sizes") {
    HStack(spacing: Spacing.lg) {
        ProgressRingView(
            progress: 0.7,
            lineWidth: 4,
            fontSize: 10,
            size: 40
        )
        ProgressRingView(
            progress: 0.7,
            size: 60
        )
        ProgressRingView(
            progress: 0.7,
            lineWidth: 12,
            fontSize: 20,
            size: 100
        )
    }
    .padding()
}

#Preview("Mini Ring") {
    HStack(spacing: Spacing.md) {
        MiniProgressRing(progress: 0.3, fillColor: .stateNew)
        MiniProgressRing(progress: 0.6, fillColor: .stateLearning)
        MiniProgressRing(progress: 0.9, fillColor: .stateMastery)
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: Spacing.lg) {
        ProgressRingView(progress: 0.65)
        HStack(spacing: Spacing.md) {
            MiniProgressRing(progress: 0.3, fillColor: .stateNew)
            MiniProgressRing(progress: 0.6, fillColor: .stateLearning)
            MiniProgressRing(progress: 0.9, fillColor: .stateMastery)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
