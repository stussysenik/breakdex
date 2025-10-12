import SwiftUI
import PhotosUI

// SelectClip.swift - "select a clip" UI

// MARK: - SelectClip
/// Simple view for selecting a clip to add
struct SelectClip: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosUI.PhotosPickerItem?

    var body: some View {
        VStack {
            Spacer()

            Button("Select a Clip") {
                // Show Photos picker for video selection
                showPhotosPicker = true
            }
            .buttonStyle(SelectClipButtonStyle())

            Spacer()
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $tempSelection,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared()
        )
        .onChange(of: tempSelection) { _, newItem in
            handleVideoSelection(newItem)
        }
    }

    // MARK: - Private Methods

    private func handleVideoSelection(_ item: PhotosUI.PhotosPickerItem?) {
        guard let newItem = item else { return }

        Task {
            await unifiedState.loadVideo(from: newItem)

            // Clear the temporary selection
            await MainActor.run {
                tempSelection = nil
            }
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        var body: some View {
            SelectClip(
                selectedTab: $selectedTab,
                unifiedState: AddMoveUnifiedState()
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}