import SwiftUI

struct MagnifyingLoupeView: View {
    let image: UIImage
    let position: CGPoint

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: 3)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
        }
        .frame(width: 100, height: 100)
        .offset(x: position.x - 50, y: position.y - 50) // Center the loupe on the position
        .accessibilityHidden(true) // Hide from accessibility since it's a visual aid
    }
}
