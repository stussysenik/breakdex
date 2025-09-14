import SwiftUI

struct AddMovePreviewingView: View {
    @Bindable var viewModel: AddMoveViewModel

    var body: some View {
        if let playerViewModel = viewModel.preparedVideoPlayerViewModel {
            if playerViewModel.isPlayerReady {
                EmptyView() // Actual player view will be in AddMoveContainer
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                    Text("Preparing video player...")
                        .font(.custom("IBMPlexMono-Thin", size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity)
            }
        } else {
            // Fallback if playerViewModel is not yet available (shouldn't happen often)
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accentColor)
                Text("Loading video...")
                    .font(.custom("IBMPlexMono-Thin", size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .transition(.opacity)
        }
    }
}