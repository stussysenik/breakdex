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
                    .accessibilityIdentifier("NameMoveVideoPlayer")

                Spacer()

                VStack {
                    Text("Name Your Move")
                        .font(.titleMedium)
                        .foregroundColor(.white)
                    
                    TextField("Enter move name", text: $viewModel.moveName)
                        .font(.titleLarge)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .accessibilityIdentifier("Enter move name")
                }
                .padding()

                Spacer()
                Spacer()

                HStack(spacing: 15) {
                    Button("Back") {
                        if let asset = originalAsset {
                            viewModel.state = .previewing(asset: asset, photosIdentifier: photosIdentifier)
                        } else {
                            viewModel.reset()
                        }
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Back Button")

                    Button("Save") {
                        viewModel.saveMove()
                    }
                    .disabled(viewModel.moveName.isEmpty)
                    .buttonStyle(.appPrimary(size: .medium))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Save Button")
                }
                .padding(.horizontal)
                .padding(.bottom, 44)
            }
        }
    }
}

#Preview {
    NameMoveView(viewModel: AddMoveViewModel(viewContext: PersistenceController.shared.container.viewContext))
        .preferredColorScheme(.dark)
}