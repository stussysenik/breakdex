import SwiftUI
import AVKit
import PhotosUI // Added PhotosUI
import BreakingFlashcards

struct VideoPreviewOptionsView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    let asset: AVAsset
    let photosIdentifier: String?
    @Binding var selectedTab: TabSelection // Added selectedTab binding

    @State private var showPhotosPicker = false // State to control PhotosPicker presentation
    @State private var selectedPhotosPickerItem: PhotosPickerItem? = nil // State to hold selected item from PhotosPicker

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Cancel") {
                    selectedTab = .add // Stay on Add tab
                    viewModel.reset() // Reset the AddMoveViewModel state
                }
                .padding()
                .accessibilityIdentifier("Cancel Button") // Added accessibility identifier
            }

            CustomVideoPlayerView(photosIdentifier: photosIdentifier)
                .cornerRadius(12)
                .padding()
                .accessibilityIdentifier("CustomVideoPlayerView") // Added accessibility identifier

            Spacer()

            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Button("Change Video") {
                        showPhotosPicker = true // Show PhotosPicker
                    }
                    .buttonStyle(VideoTrimmerButtonStyle(level: .secondary))
                    .accessibilityIdentifier("Change Video Button") // Added accessibility identifier

                    Button("Trim Video") {
                        viewModel.state = .trimming(asset: asset, photosIdentifier: photosIdentifier)
                    }
                    .buttonStyle(VideoTrimmerButtonStyle(level: .secondary))
                    .accessibilityIdentifier("Trim Video Button") // Added accessibility identifier

                    Button("Use Original") {
                        viewModel.state = .naming(photosIdentifier: photosIdentifier ?? "", originalAsset: asset, trimStartTime: nil, trimEndTime: nil)
                    }
                    .buttonStyle(VideoTrimmerButtonStyle(level: .primary))
                    .accessibilityIdentifier("Use Original Button") // Added accessibility identifier
                }
                .padding(.horizontal, 30)
            }
            .padding(.bottom)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotosPickerItem, matching: .videos) // PhotosPicker modifier
        .onChange(of: selectedPhotosPickerItem) { oldItem, newItem in // Handle new selection
            print("VideoPreviewOptionsView: onChange - oldItem: \(String(describing: oldItem?.itemIdentifier)), newItem: \(String(describing: newItem?.itemIdentifier))")
            // Only process if newItem is not nil AND has a valid itemIdentifier
            if let newItem = newItem, newItem.itemIdentifier != nil {
                viewModel.selectedItem = newItem // Pass the new item to the AddMoveViewModel
            } else {
                // Optionally, log or handle the case where selection is cleared or invalid
                print("VideoPreviewOptionsView: onChange - New selection is nil or has no itemIdentifier. Ignoring.")
            }
        }
    }
}

#Preview {
    // Need to provide a dummy binding for preview
    VideoPreviewOptionsView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext), asset: AVAsset(), photosIdentifier: nil, selectedTab: .constant(.add))
        .preferredColorScheme(.dark)
}