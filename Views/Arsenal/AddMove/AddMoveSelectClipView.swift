import SwiftUI
import PhotosUI

// Select a Clip page
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
    @State private var isButtonPressed = false
    @State private var showTimecode = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            switch viewModel.state {
            case .ready:
                AppPhotosPickerButton(selection: $viewModel.selectedItem)
                    .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                    .opacity(isButtonPressed ? 0.8 : 1.0)
                    .onTapGesture {
                        MotionCatalog.Accessibility.buttonTap()
                        isButtonPressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            isButtonPressed = false
                        }
                    }
            case .selectingVideo:
                // Video selection mode - show PhotosPicker with cancel option
                VStack(spacing: 20) {
                    Text("Select a New Video")
                        .font(.appFont(.bold, size: 18))
                        .foregroundColor(.primary)

                    AppPhotosPickerButton(selection: $viewModel.selectedItem)
                        .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                        .opacity(isButtonPressed ? 0.8 : 1.0)
                        .onTapGesture {
                            MotionCatalog.Accessibility.buttonTap()
                            isButtonPressed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                isButtonPressed = false
                            }
                        }

                    Button("Cancel") {
                        print("🎬 SELECT CLIP VIEW: Cancel button tapped")
                        viewModel.cancelChangeVideo()
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    .accessibilityIdentifier("Cancel Selection Button")
                }
                .padding(.horizontal, 20)

                // Only show filename in ready state, not in selectingVideo state
                if case .ready = viewModel.state, let filename = viewModel.selectedFilename {
                    Text("Selected file name: \(filename)")
                        .font(.appFont(.regular, size: 12))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .opacity(showTimecode ? 1.0 : 0.0)
                        .onAppear { showTimecode = true }
                }

            case .loading(let progress, let status):
                VStack(spacing: 16) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .padding(.horizontal, 40)
                    Text(status)
                        .font(.ibmPlexMono(size: 14, weight: .thin))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity) // Smooth transition for loading state

            case .previewing(_, _):
                // This state should transition to TrimmerView or NamingView, so we might not need to display anything here directly, or we can show a placeholder/preview.
                // For now, let's assume it immediately transitions.
                EmptyView() // Or a placeholder if needed

            case .trimming(_, _, _):
                EmptyView() // Handled by TrimmerView

            case .naming(_, _, _, _, _, _):
                EmptyView() // Handled by NamingView

            case .saving:
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                    Text("Saving your move...")
                        .font(.ibmPlexMono(size: 14, weight: .thin))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity)

            case .success(let message):
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text(message)
                        .font(.ibmPlexMono(size: 16, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity)

            case .error(let message, let underlyingError):
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error: \(message)")
                        .font(.ibmPlexMono(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    if let underlyingError = underlyingError {
                        Text(underlyingError)
                            .font(.ibmPlexMono(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Button("Try Again") {
                        viewModel.reset()
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                }
                .transition(.opacity)
            }

            // The Import/Export button should always be visible, regardless of state
            Spacer()
                .frame(height: 12)

            Button {
                MotionCatalog.Accessibility.buttonTap()
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
