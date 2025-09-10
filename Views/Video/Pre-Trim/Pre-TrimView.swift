import SwiftUI
import AVKit

struct PreTrimView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    let asset: AVAsset
    @Binding var selectedTab: TabSelection

    var body: some View {
        VStack {
            // Header
            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.reset()
                    selectedTab = .add // Navigate back to the main tab
                }
                .padding()
            }

            // Video Player
            CustomVideoPlayerView(asset: asset, rotationQuarterTurns: 0)
                .cornerRadius(12)
                .padding(.horizontal)

            Spacer()

            // Action Buttons
            VStack(spacing: 16) {
                Text(viewModel.selectedFilename ?? "")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Change Video") {
                        // Simply reset and allow the user to pick another video
                        viewModel.reset()
                    }
                    .buttonStyle(.appSecondary(size: .medium))

                    Button("Trim Video") {
                        viewModel.startTrimming()
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                }
            }
            .padding()
            .padding(.bottom, 180)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
