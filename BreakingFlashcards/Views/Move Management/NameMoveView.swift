import SwiftUI
import AVKit
import BreakingFlashcards

struct NameMoveView: View {
    @ObservedObject var viewModel: AddMoveViewModel

    var body: some View {
        VStack {
            if case .naming(let photosIdentifier, let originalAsset, _, _) = viewModel.state {
                CustomVideoPlayerView(photosIdentifier: photosIdentifier)
                    .cornerRadius(12)
                    .padding()
                    .accessibilityIdentifier("NameMoveVideoPlayer") // Added accessibility identifier

                TextField("Enter move name", text: $viewModel.moveName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .accessibilityIdentifier("Enter move name") // Added accessibility identifier

                HStack(spacing: 12) {
                    Button("Back") {
                        // Determine the previous state to go back to
                        // For now, let's go back to previewing
                        if let asset = originalAsset {
                            viewModel.state = .previewing(asset: asset, photosIdentifier: photosIdentifier)
                        } else {
                            // If originalAsset is nil, it means we came from trimming
                            // We need to get the asset from the trimming state or pass it along
                            // For now, reset to ready if we can't go back to previewing
                            viewModel.reset()
                        }
                    }
                    .buttonStyle(VideoTrimmerButtonStyle(level: .secondary))
                    .accessibilityIdentifier("Back Button") // Added accessibility identifier

                    Button("Save") {
                        viewModel.saveMove()
                    }
                    .disabled(viewModel.moveName.isEmpty)
                    .buttonStyle(VideoTrimmerButtonStyle(level: .primary))
                    .accessibilityIdentifier("Save Button") // Added accessibility identifier
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }
}

#Preview {
    NameMoveView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
        .preferredColorScheme(.dark)
}