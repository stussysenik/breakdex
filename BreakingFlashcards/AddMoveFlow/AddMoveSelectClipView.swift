import SwiftUI
import PhotosUI
import BreakingFlashcards

// MARK: - Consistent Photos Picker Button
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
    }
}

struct AddMoveSelectClipView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var showingImportExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // PRIMARY CONCERN: Select Clip Button + Helper Text
            VStack(spacing: 4) {
                // Main select clip button - Primary Action
                AppPhotosPickerButton(selection: $viewModel.selectedItem)

                // Helper text - Aligned with button, never exceeds edges
                // Text("Supports .mp4, .mov files")
                //     .font(.appFont(.regular, size: 12)) // IBM Plex Mono font
                //     .foregroundStyle(.gray)
                //     .multilineTextAlignment(.center)
                //     .frame(maxWidth: .infinity)
                //     .padding(.horizontal, 12) // Tighter padding for better fit
            }

            // Clear separation from secondary functionality
            Spacer()
                .frame(height: 24) // More breathing room

            // SECONDARY CONCERN: Import/Export functionality
            Button {
                showingImportExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Import / Export")
                }
                .font(.appFont(.regular, size: 12)) // IBM Plex Mono font
                .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Import Export Button")
            .sheet(isPresented: $showingImportExportSheet) {
                ImportExportView()
            }

            Spacer()
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    AddMoveSelectClipView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
        .preferredColorScheme(.dark)
}