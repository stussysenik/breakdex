import SwiftUI
import Foundation

// Simple wrapper view - directly shows the select clip view
struct AddMoveView: View {
    var body: some View {
        AddMoveSelectClipView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
}

#Preview {
    AddMoveView()
        .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        .preferredColorScheme(.dark)
}
