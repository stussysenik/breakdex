import SwiftUI
import BreakingFlashcards

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ibmPlexMono(size: 16, weight: .bold))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ibmPlexMono(size: 16, weight: .bold))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
