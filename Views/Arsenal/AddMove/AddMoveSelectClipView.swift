import SwiftUI
import PhotosUI
import OSLog


// AddMoveState and AddMoveError are defined in AddMoveState.swift

// Select a Clip page
private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveSelectClip")

struct AppPhotosPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            Text("Select a Clip")
        }
        .buttonStyle(.photosPicker(type: .primary))
        .accessibilityIdentifier("Select a Clip Button")
        .onChange(of: selection) { oldValue, newValue in
            logger.info("🎬 PHOTO_PICKER: Selection changed")
            logger.info("🎬 PHOTO_PICKER: Old value: \(oldValue?.itemIdentifier ?? "nil")")
            logger.info("🎬 PHOTO_PICKER: New value: \(newValue?.itemIdentifier ?? "nil")")
            
            if let newValue = newValue {
                logger.info("🎬 PHOTO_PICKER: New selection details:")
                logger.info("   - Item ID: \(newValue.itemIdentifier ?? "nil")")
                logger.info("   - Supported types: \(newValue.supportedContentTypes)")
            } else {
                logger.info("🎬 PHOTO_PICKER: Selection cleared")
            }
        }
    }
}

struct AddMoveSelectClipView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            switch viewModel.state {
            case .ready:
                AddMoveReadyView(viewModel: viewModel)
            case .selectingVideo(_):
                AddMoveSelectingVideoView(viewModel: viewModel)
            case .loading(progress: let progress, status: let status):
                AddMoveLoadingView(progress: progress, status: status)
            case .initializing(progress: let progress, status: let status):
                AddMoveLoadingView(progress: progress, status: status)
            case .previewing(_, _, _, _):
                EmptyView() // Let AddMoveContainer handle the PreTrimView
            case .saving:
                AddMoveSavingView()
            case .success(let message):
                MoveAddedSuccessView(viewModel: viewModel, message: message, selectedTab: .constant(.add))
            case .error(let message, let underlyingError):
                AddMoveErrorView(viewModel: viewModel, message: message, underlyingError: underlyingError as? Error, selectedTab: .constant(.add))
            default:
                EmptyView()
            }
            
            Spacer()
        }
        .navigationBarHidden(true)
    }
}
