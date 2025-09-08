import SwiftUI

/// Modular handle component that accepts any SwiftUI View as content

struct HandleView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: 24)) // Crisp rendering for emojis
            .frame(width: 44, height: 44, alignment: .center)
            .contentShape(Rectangle())
            .background(Color.clear) // Ensures full touch area
    }
}

#Preview {
    VStack(spacing: 20) {
        HandleView { Text("👟") }
        HandleView { Text("🔥") }
        HandleView { Text("🪩") }
        HandleView {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
        }
    }
    .padding()
    .background(Color.black)
}
