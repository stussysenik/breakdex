import SwiftUI
import PhotosUI

// MARK: - VideoPickerView
/// Clean video picker component for selecting videos from Photos library
struct VideoPickerView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosPickerItem?

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "VideoPickerView"
    )

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Add New Move")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Select a video from your Photos library to create a new breaking move")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Select Video Button
            Button(action: {
                logger.info("📹 Video picker button tapped")
                showPhotosPicker = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)

                    Text("Select Video")
                        .font(.ibmPlexMono(size: 18, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Help text
            VStack(spacing: 8) {
                Text("💡 Tip")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Choose videos that clearly show the breaking move you want to learn")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
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

    private func handleVideoSelection(_ item: PhotosPickerItem?) {
        guard let newItem = item else {
            logger.info("📹 Video selection cleared")
            return
        }

        logger.info("📹 Video selected from Photos picker")

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
        private var unifiedState: AddMoveUnifiedState {
            let appContainer = AppContainer.shared
            return AddMoveUnifiedState(
                unifiedPlayerManager: UnifiedPlayerManager(),
                modernVideoLoadingService: appContainer.modernVideoLoadingService,
                videoProcessingPipeline: appContainer.videoProcessingPipeline,
                timecodeCalculationService: TimecodeCalculationService(),
                persistentContainer: PersistenceController(inMemory: true).container,
                movePersistenceService: appContainer.movePersistenceService,
                appContainer: appContainer
            )
        }

        var body: some View {
            VideoPickerView(unifiedState: unifiedState)
                .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}