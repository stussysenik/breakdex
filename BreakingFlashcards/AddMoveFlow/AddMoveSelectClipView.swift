import SwiftUI
import PhotosUI
import BreakingFlashcards

struct AddMoveSelectClipView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var showingImportExportSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            PhotosPicker(
                selection: $viewModel.selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                Text("Select a Clip")
                    .font(.titleMedium)
                    .foregroundStyle(Color.backgroundPrimary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.accent, in: Capsule())
            }
            .accessibilityIdentifier("Select a Clip Button") // Added accessibility identifier
            Text("Supports .mp4, .mov files")
                .font(.caption)
                .foregroundStyle(.gray)

            Spacer()

            HStack {
                Spacer()
                Button {
                    showingImportExportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Import / Export")
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("Import Export Button") // Added accessibility identifier
                .sheet(isPresented: $showingImportExportSheet) {
                    ImportExportView()
                }
                Spacer()
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    AddMoveSelectClipView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
        .preferredColorScheme(.dark)
}