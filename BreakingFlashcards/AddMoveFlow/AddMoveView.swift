import SwiftUI
import BreakingFlashcards

struct AddMoveView: View {
    @State private var selectedTab: TabSelection = .add

    var body: some View {
        AddMoveContainer(selectedTab: $selectedTab)
    }
}

#Preview {
    AddMoveView()
        .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        .preferredColorScheme(.dark)
}