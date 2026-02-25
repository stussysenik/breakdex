import SwiftUI

struct AvailableMoveRowView: View {
    let move: Move

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Capsule()
                .fill(learningStateColor)
                .frame(width: 5, height: 30)

            Text(move.name ?? "Untitled Move")
                .font(.bodyMedium)
                .padding(.leading, Spacing.sm)

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }

    private var learningStateColor: Color {
        LearningState.resolve(from: move.learningState).color
    }
}

#Preview {
    let mockMove = Move(context: PersistenceController.preview.container.viewContext)
    mockMove.name = "Sample Move"
    mockMove.learningState = "NEW"

    return AvailableMoveRowView(move: mockMove)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
