import SwiftUI

struct TrimmerControlsView: View {
    @Binding var params: VideoEditParameters

    private let speeds: [Float] = [0.25, 0.5, 1.0, 1.5, 2.0]

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Speed pills
            speedRow

            // Transform controls
            transformRow
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Speed Row

    private var speedRow: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    params.playbackRate = speed
                    HapticEngine.shared.speedChange()
                } label: {
                    Text(speedLabel(speed))
                        .font(.ibmPlexMono(size: 15, weight: speed == params.playbackRate ? .bold : .regular))
                        .foregroundColor(speed == params.playbackRate ? .white : .textPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(
                            Capsule()
                                .fill(speed == params.playbackRate ? Color.accent : Color.neutralFill)
                        )
                }
                .animation(AppMotion.pillSelect, value: params.playbackRate)
            }
        }
    }

    // MARK: - Transform Row

    private var transformRow: some View {
        HStack(spacing: Spacing.md) {
            // Reverse toggle
            transformButton(
                icon: "arrow.uturn.backward",
                label: "Reverse",
                isActive: params.isReversed
            ) {
                params.isReversed.toggle()
                HapticEngine.shared.speedChange()
            }

            // Rotate
            transformButton(
                icon: params.rotation.iconName,
                label: "\(params.rotation.rawValue)\u{00B0}",
                isActive: params.rotation != .none
            ) {
                params.rotation = params.rotation.next
                HapticEngine.shared.rotationSnap()
            }

            // Aspect ratio
            transformButton(
                icon: params.aspectRatio.iconName,
                label: params.aspectRatio.label,
                isActive: params.aspectRatio != .original
            ) {
                params.aspectRatio = params.aspectRatio.next
                HapticEngine.shared.speedChange()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func transformButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 23))
                Text(label)
                    .font(.ibmPlexMono(size: 16))
            }
            .foregroundColor(isActive ? .accent : .textSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(isActive ? Color.accent.opacity(0.12) : Color.neutralFill)
            )
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed == 0.25 { return ".25x" }
        if speed == 0.5 { return ".5x" }
        return String(format: "%.1fx", speed).replacingOccurrences(of: ".0x", with: "x")
    }
}
