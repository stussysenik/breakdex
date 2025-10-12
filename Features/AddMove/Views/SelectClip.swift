import SwiftUI

// MARK: - SelectClip
/// Simple view for selecting a clip to add
struct SelectClip: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState

    var body: some View {
        VStack {
            Spacer()

            Button("Select a Clip") {
                // Handle clip selection
                print("Select clip tapped")
            }
            .buttonStyle(SelectClipButtonStyle())

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        var body: some View {
            SelectClip(
                selectedTab: $selectedTab,
                unifiedState: AddMoveUnifiedState()
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}