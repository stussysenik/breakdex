import SwiftUI
import CoreData
import BreakingFlashcards

struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) var viewContext
    @StateObject private var viewModel: AddMoveViewModel
    @Binding var selectedTab: TabSelection // Added selectedTab binding

    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // Designated initializer
        _viewModel = StateObject(wrappedValue: AddMoveViewModel(viewContext: context))
        _selectedTab = selectedTab
    }

    init(selectedTab: Binding<TabSelection>) { // Convenience initializer
        self.init(context: PersistenceController.shared.container.viewContext, selectedTab: selectedTab)
    }

    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // Convenience initializer
        self.init(context: viewContext, selectedTab: selectedTab)
    }

    private var currentView: some View {
        let currentState = viewModel.state
        switch currentState {
        case .ready:
            return AnyView(AddMoveSelectClipView(viewModel: viewModel))
        case .loading(let progress, let status):
            return AnyView(VStack {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding()
                Text(status)
                    .font(.caption)
            })
        case .previewing(let asset, let photosIdentifier):
            return AnyView(VideoPreviewOptionsView(viewModel: viewModel, asset: asset, photosIdentifier: photosIdentifier, selectedTab: $selectedTab)) // Pass selectedTab
        case .trimming(let asset, let photosIdentifier):
            return AnyView(AsyncPreciseVideoTrimmerView(addMoveViewModel: viewModel, asset: asset, photosIdentifier: photosIdentifier))
        case .naming:
            return AnyView(NameMoveView(viewModel: viewModel))
        case .saving:
            return AnyView(Text("Saving Move..."))
        case .error(let message, let underlyingError):
            return AnyView(AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: $selectedTab)) // Pass selectedTab
        case .success(let message):
            return AnyView(MoveAddedSuccessView(viewModel: viewModel, message: message, selectedTab: $selectedTab)) // Pass selectedTab
        }
    }

    var body: some View {
        currentView
    }
}

#Preview {
    // Need to provide a dummy binding for preview
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}