import Foundation
import SwiftUI

// AddMoveView.swift

// MARK: - CLASS
struct AddMoveView: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState

    private let onSaveSuccess: ((Move) -> Void)?

    // MARK: - BODY
    var body: some View {
        AddMoveContainer(
            selectedTab: $selectedTab,
            unifiedState: unifiedState,
            onSaveSuccess: onSaveSuccess
        )
    }

    init(
        selectedTab: Binding<TabSelection> = .constant(.add),
        unifiedState: AddMoveUnifiedState,
        onSaveSuccess: ((Move) -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self.unifiedState = unifiedState
        self.onSaveSuccess = onSaveSuccess
    }
}

// MARK: - SWIFT UI PREVIEW
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        private var unifiedState: AddMoveUnifiedState {
            let appContainer = AppContainer.shared
            return AddMoveUnifiedState(
                unifiedPlayerManager: UnifiedPlayerManager(),
                modernVideoLoadingService: appContainer
                    .modernVideoLoadingService,
                videoProcessingPipeline: appContainer.videoProcessingPipeline,
                timecodeCalculationService: TimecodeCalculationService(),
                persistentContainer: PersistenceController(inMemory: true)
                    .container,
                movePersistenceService: appContainer.movePersistenceService,
                appContainer: appContainer
            )
        }

        var body: some View {
            AddMoveView(selectedTab: $selectedTab, unifiedState: unifiedState)
                .environment(
                    \.managedObjectContext,
                    PersistenceController(inMemory: true).container.viewContext
                )
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}
