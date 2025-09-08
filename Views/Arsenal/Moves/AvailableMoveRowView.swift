import SwiftUI

struct AvailableMoveRowView: View {
    let move: Move
    
    var body: some View {
        HStack {
            Capsule() // this capsule's color indicates the move's learning state.
                .fill(learningStateColor)
                .frame(width: 5, height: 30)
            
            Text(move.name ?? "Untitled Move")
                .font(.headline)
                .padding(.leading, 8)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var learningStateColor: Color {  // helper computes the correct color based on the move's state.
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
    let mockMove = Move(context: PersistenceController.shared.container.viewContext)
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"
    
    return AvailableMoveRowView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
