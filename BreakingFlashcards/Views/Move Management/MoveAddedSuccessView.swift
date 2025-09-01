import SwiftUI
import BreakingFlashcards

struct MoveAddedSuccessView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    let message: String
    @Binding var selectedTab: TabSelection // Added selectedTab binding

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text(message)
                .font(.headline)
                .accessibilityIdentifier("Success Message Text") // Added accessibility identifier

            HStack(spacing: 12) { // Added HStack for buttons
                Button("Add Another Move") { // Changed button text
                    viewModel.reset()
                }
                .buttonStyle(VideoTrimmerButtonStyle(level: .primary))
                .accessibilityIdentifier("Add Another Button")

                Button("Done") { // Added Done button
                    selectedTab = .arsenal // Switch to Arsenal tab
                    viewModel.reset() // Reset the AddMoveViewModel state
                }
                .buttonStyle(VideoTrimmerButtonStyle(level: .secondary))
                .accessibilityIdentifier("Done Button")
            }
        }
    }
}

#Preview {
    // Need to provide a dummy binding for preview
    MoveAddedSuccessView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext), message: "Your move has been added!", selectedTab: .constant(.add))
        .preferredColorScheme(.dark)
}