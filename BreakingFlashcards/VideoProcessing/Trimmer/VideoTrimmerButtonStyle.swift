import SwiftUI

struct VideoTrimmerButtonStyle: ButtonStyle {
    enum Level {
        case primary, secondary
    }

    let level: Level

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(level == .primary ? Color.accentColor : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
