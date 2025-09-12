
import SwiftUI

struct HandleView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: 44, height: 60)
            .contentShape(Rectangle())
    }
}
