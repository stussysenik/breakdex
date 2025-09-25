import SwiftUI
import Foundation

// MARK: - Tab Selection Enum

// Modified wrapper view - now uses AddMoveContainer for proper state routing
struct AddMoveView: View {
    @Binding var selectedTab: TabSelection

    // 🎯 CRITICAL FIX: Save completion handler for navigation
    private let onSaveSuccess: ((Move) -> Void)?

    var body: some View {
        AddMoveContainer(selectedTab: $selectedTab, onSaveSuccess: onSaveSuccess)
    }

    // Custom initializer with default value for selectedTab
    init(selectedTab: Binding<TabSelection> = .constant(.add), onSaveSuccess: ((Move) -> Void)? = nil) {
        self._selectedTab = selectedTab
        self.onSaveSuccess = onSaveSuccess
    }
}

#Preview {
    AddMoveView()
        .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
        .preferredColorScheme(.dark)
}
