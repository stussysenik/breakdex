import SwiftUI
import Foundation

// MARK: - Tab Selection Enum

// Modified wrapper view - now uses AddMoveContainer for proper state routing
struct AddMoveView: View {
    @Binding var selectedTab: TabSelection
    
    var body: some View {
        AddMoveContainer(selectedTab: $selectedTab)
    }
    
    // Custom initializer with default value for selectedTab
    init(selectedTab: Binding<TabSelection> = .constant(.add)) {
        self._selectedTab = selectedTab
    }
}

#Preview {
    AddMoveView()
        .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        .preferredColorScheme(.dark)
}
