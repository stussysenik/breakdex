import SwiftUI
import CoreData
import AVKit
import Foundation
import Photos
import PhotosUI

// traffic manager - routes to the correct view based on the state
struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) var viewContext
    @StateObject private var viewModel: AddMoveViewModel
    @StateObject private var trimmerViewModel: TrimmerViewModel
    @Binding var selectedTab: TabSelection

    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // designated initializer
        _viewModel = StateObject(wrappedValue: AddMoveViewModel(viewContext: context))
        // Create a placeholder TrimmerViewModel that will be replaced when transitioning to trimming
        let placeholderAsset = AVURLAsset(url: URL(fileURLWithPath: "/dev/null"))
        _trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: placeholderAsset, photosIdentifier: nil))
        _selectedTab = selectedTab
    }
    
    init(selectedTab: Binding<TabSelection>) { // convenience initializer
        self.init(context: PersistenceController.shared.container.viewContext, selectedTab: selectedTab)
    }
    
    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // convenience initializer
        self.init(context: viewContext, selectedTab: selectedTab)
    }
    
    private var currentView: some View {
        let currentState = viewModel.state
        print("🎬 ADDMOVE CONTAINER: currentView called, state: \(String(describing: currentState))")

        switch currentState {
        case .ready:
            print("🎬 ADDMOVE CONTAINER: Showing ready state")
            return AnyView(AddMoveSelectClipView(viewModel: viewModel))
        case .loading(let progress, let status): // LOADING
            print("🎬 ADDMOVE CONTAINER: Showing loading state - progress: \(progress), status: '\(status)'")
            return AnyView(VStack {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding()
                Text(status)
                    .font(.caption)
            })
        case .previewing(let asset, let photosIdentifier): // PREVIEWING
            print("🎬 ADDMOVE CONTAINER: Creating PreTrimView")
            print("   📹 Asset: \(asset)")
            print("   🆔 Photos ID: \(photosIdentifier ?? "nil")")
            return AnyView(PreTrimView(viewModel: viewModel, asset: asset, photosIdentifier: photosIdentifier, selectedTab: $selectedTab))
        case .selectingVideo(let currentAsset): // VIDEO SELECTION MODE
            print("🎬 ADDMOVE CONTAINER: Showing PhotosPicker for video selection")
            print("   📹 Current Asset: \(String(describing: currentAsset))")
            return AnyView(
                VideoPickerWrapper(viewModel: viewModel)
            )
        case .trimming(let asset, _, let rotationQuarterTurns): // TRIMMING
            print("🎬 ADDMOVE CONTAINER: Creating TrimmerViewWrapper")
            print("   📹 Asset: \(asset)")
            print("   🔄 Rotation: \(rotationQuarterTurns)")

            return AnyView(
                TrimmerViewWrapper(
                    viewModel: viewModel,
                    trimmerViewModel: trimmerViewModel,
                    asset: asset,
                    rotationQuarterTurns: rotationQuarterTurns
                )
            )
        case .naming: // NAMING MOVE
            return AnyView(NameMoveView(viewModel: viewModel))
        case .saving: // SAVING MOVE
            return AnyView(Text("Saving Move..."))
        case .error(let message, let underlyingError): // if ERROR
            return AnyView(AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: $selectedTab))
        case .success(let message): // SUCCESS
            return AnyView(MoveAddedSuccessView(viewModel: viewModel, message: message, selectedTab: $selectedTab))
        }
    }
    
    var body: some View {
        currentView
            .id(viewModel.state) // Force view recreation when state changes
    }
}

// MARK: - Minimal Video Picker Wrapper
struct VideoPickerWrapper: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        // PhotosPicker needs a proper label to show its UI
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            // Simple label that PhotosPicker will replace with its native UI
            Text("Select Video")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.blue)
        }
        .photosPickerStyle(.inline)
        .onChange(of: selectedItem) { newItem in
            if let item = newItem {
                print("🎬 VIDEO PICKER WRAPPER: Video selected, updating viewModel")
                // PhotosPicker selected a video - our state management takes over
                viewModel.selectedItem = item
            }
        }
        .onAppear {
            print("🎬 VIDEO PICKER WRAPPER: Appeared - PhotosPicker should be visible now")
        }
    }
}

// MARK: - Trimmer View Wrapper (Safe State Management)
struct TrimmerViewWrapper: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @ObservedObject var trimmerViewModel: TrimmerViewModel
    let asset: AVAsset
    let rotationQuarterTurns: Int

    @State private var hasInitialized = false

    var body: some View {
        TrimmerView(addMoveViewModel: viewModel, trimmerViewModel: trimmerViewModel, rotationQuarterTurns: rotationQuarterTurns)
            .onAppear {
                // Only update once to prevent infinite loop
                if !hasInitialized {
                    hasInitialized = true
                    print("🎬 TRIMMER WRAPPER: Initializing trimmer state")
                    // Update trimmer state safely after view is fully constructed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self.trimmerViewModel.asset.description != asset.description {
                            self.trimmerViewModel.rotationQuarterTurns = rotationQuarterTurns
                        }
                    }
                }
            }
    }
}

#Preview {
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}
