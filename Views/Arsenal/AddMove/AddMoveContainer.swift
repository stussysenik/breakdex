import SwiftUI
import CoreData
import AVKit
import Foundation
import Photos
import PhotosUI

// MARK: - Memory Monitor Utility
struct MemoryMonitor {
    static func currentPressure() -> String {
        // Simple memory pressure indicator
        return "OK" // Could be enhanced with actual memory monitoring
    }
}

// traffic manager - routes to the correct view based on the state
struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) var viewContext
    @StateObject private var viewModel: AddMoveViewModel
    @Binding var selectedTab: TabSelection

    // Static tracking for debugging
    private static var lastState: AddMoveState?
    private static var viewEvaluationCount = 0

    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // designated initializer
        _viewModel = StateObject(wrappedValue: AddMoveViewModel(viewContext: context))
        _selectedTab = selectedTab
    }
    
    init(selectedTab: Binding<TabSelection>) { // convenience initializer
        self.init(context: PersistenceController.shared.container.viewContext, selectedTab: selectedTab)
    }
    
    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>) { // convenience initializer
        self.init(context: viewContext, selectedTab: selectedTab)
    }
    
    
    var body: some View {
        // Main content - stable, doesn't get destroyed
        mainContent
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .ready:
            AddMoveSelectClipView(viewModel: viewModel)
        case .loading:
            // This should not happen now that we have the overlay
            AddMoveSelectClipView(viewModel: viewModel)
        case .previewing(let asset, let photosIdentifier):
            PreTrimView(viewModel: viewModel, asset: asset, photosIdentifier: photosIdentifier, selectedTab: $selectedTab)
        case .selectingVideo(let currentAsset):
            VideoPickerWrapper(viewModel: viewModel)
        case .trimming(let asset, _, let rotationQuarterTurns):
            TrimmerViewWrapper(
                viewModel: viewModel,
                asset: asset,
                rotationQuarterTurns: rotationQuarterTurns,
                onError: { message, error in
                    viewModel.state = .error(message: message, underlyingError: error?.localizedDescription)
                },
                onRotate: { newRotation in
                    viewModel.updateTrimmingRotation(rotationQuarterTurns: newRotation)
                }
            )
        case .naming:
            NameMoveView(viewModel: viewModel)
        case .saving:
            Text("Saving Move...")
        case .error(let message, let underlyingError):
            AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: $selectedTab)
        case .success(let message):
            MoveAddedSuccessView(viewModel: viewModel, message: message, selectedTab: $selectedTab)
        }
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

    // OWN ITS OWN VIEWMODEL: Created fresh for each trimming session
    @StateObject private var trimmerViewModel: TrimmerViewModel

    let asset: AVAsset
    let rotationQuarterTurns: Int

    // Event-driven communication: pass callbacks from parent
    let onError: (String, Error?) -> Void
    let onRotate: (Int) -> Void

    // Track wrapper lifecycle for debugging
    private let wrapperId = UUID()
    private let constructionTime = Date().timeIntervalSince1970

    init(viewModel: AddMoveViewModel, asset: AVAsset, rotationQuarterTurns: Int, onError: @escaping (String, Error?) -> Void, onRotate: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.asset = asset
        self.rotationQuarterTurns = rotationQuarterTurns
        self.onError = onError
        self.onRotate = onRotate

        // Initialize StateObject with the REAL asset from the start
        _trimmerViewModel = StateObject(wrappedValue: TrimmerViewModel(asset: asset, photosIdentifier: nil))

        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"
        print("🏗️ [\(String(format: "%.3f", constructionTime))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Constructed on \(threadInfo) thread")
        print("   📹 Asset: \(asset.description.prefix(50))...")
        print("   🔄 Rotation: \(rotationQuarterTurns)")
        print("   🎯 Callbacks configured")
    }

    var body: some View {
        let bodyTimestamp = Date().timeIntervalSince1970
        let threadInfo = Thread.isMainThread ? "MAIN" : "BG"

        print("🔄 [\(String(format: "%.3f", bodyTimestamp))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Body evaluated on \(threadInfo) thread")
        print("   ⏱️ Time since construction: \(String(format: "%.3f", bodyTimestamp - constructionTime))s")
        print("   📊 Memory pressure: \(MemoryMonitor.currentPressure())")

        return TrimmerView(
            trimmerViewModel: trimmerViewModel,
            rotationQuarterTurns: rotationQuarterTurns,
            onError: onError,
            onRotate: onRotate,
            onCancel: {
                print("🎬 TRIMMER WRAPPER: Cancel button triggered - calling viewModel.cancelTrimming()")
                viewModel.cancelTrimming()
            },
            onSave: {
                print("🎬 TRIMMER WRAPPER: Save button triggered - calling viewModel.finishTrimming()")
                viewModel.finishTrimming(with: trimmerViewModel)
            }
        )
        .onAppear {
            let appearTimestamp = Date().timeIntervalSince1970
            print("👁️ [\(String(format: "%.3f", appearTimestamp))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: View appeared - starting safe async setup")
            print("   ⏱️ Construction to appear: \(String(format: "%.3f", appearTimestamp - constructionTime))s")

            // Perform async setup after view is fully constructed to prevent state mutations during construction
            Task {
                let taskStartTime = Date().timeIntervalSince1970
                print("⚙️ [\(String(format: "%.3f", taskStartTime))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting safe async operations")

                do {
                    print("🎬 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting setupAsync()")
                    try await trimmerViewModel.setupAsync()
                    print("✅ [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: setupAsync() completed successfully")

                    print("🎬 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Starting updatePreview()")
                    await trimmerViewModel.updatePreview()
                    print("✅ [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: updatePreview() completed successfully")

                    let taskEndTime = Date().timeIntervalSince1970
                    print("🎉 [\(String(format: "%.3f", taskEndTime))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: All async operations completed successfully")
                    print("   ⏱️ Total time: \(String(format: "%.3f", taskEndTime - taskStartTime)) seconds")
                    print("   📊 Final state: duration=\(String(format: "%.2f", trimmerViewModel.videoDuration.seconds))s, trim=\(String(format: "%.2f", trimmerViewModel.startTime.seconds))-\(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")

                } catch {
                    let errorTime = Date().timeIntervalSince1970
                    print("❌ [\(String(format: "%.3f", errorTime))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Async operation failed")
                    print("   📝 Error: \(error.localizedDescription)")
                    print("   🎯 Error type: \(type(of: error))")
                    print("   📍 Error context: setup phase after \(String(format: "%.3f", errorTime - taskStartTime))s")

                    // Log additional error context
                    if let nsError = error as NSError? {
                        print("   🏷️ Error domain: \(nsError.domain)")
                        print("   🔢 Error code: \(nsError.code)")
                    }

                    print("📤 [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Emitting error event via callback")
                    // Event-driven error handling: emit error event instead of mutating parent state
                    onError("Failed to load video for trimming.", error)
                    print("✅ [\(String(format: "%.3f", Date().timeIntervalSince1970))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: Error event emitted")
                }
            }
        }
        .onDisappear {
            let disappearTime = Date().timeIntervalSince1970
            print("👋 [\(String(format: "%.3f", disappearTime))] TRIMMER WRAPPER [\(wrapperId.uuidString.prefix(8))]: View disappeared")
            print("   ⏱️ Total lifetime: \(String(format: "%.3f", disappearTime - constructionTime))s")
            print("   📊 Final trim state: \(String(format: "%.2f", trimmerViewModel.startTime.seconds)) - \(String(format: "%.2f", trimmerViewModel.endTime.seconds))s")
        }
    }
}

#Preview {
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}
