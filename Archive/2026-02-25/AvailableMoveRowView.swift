import SwiftUI

struct AvailableMoveRowView: View {
    let move: Move

    var body: some View {
        HStack {
            // This capsule's color indicates the move's learning state.
            Capsule()
                .fill(learningStateColor)
                .frame(width: 5, height: 30)

            Text(move.name ?? "Untitled Move")
                .font(.headline)
                .padding(.leading, 8)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // This helper computes the correct color based on the move's state.
    private var learningStateColor: Color {
        switch move.learningState {
        case "LEARNING":
            return .stateLearning
        case "MASTERY":
            return .stateMastery
        default: // Includes "NEW"
            return .stateNew
        }
    }
}

#Preview {
    // Create a mock Move for preview
    let mockMove = Move(context: PersistenceController.preview.container.viewContext)
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"

    return AvailableMoveRowView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
