import SwiftUI
import AVKit

struct NameMoveView: View {
    @ObservedObject var viewModel: AddMoveViewModel

    var body: some View {
        VStack {
            if case .naming(_, let originalAsset, let trimmedAsset, _, _, let rotation) = viewModel.state {
                let assetToPlay = trimmedAsset ?? originalAsset
                
                if let asset = assetToPlay {
                    CustomVideoPlayerView(asset: asset, rotationQuarterTurns: rotation)
                        .cornerRadius(12)
                        .padding()
                }
                
                TextField("Enter move name...", text: $viewModel.moveName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                HStack {
                    Button("Back") {
                        viewModel.cancelTrimming() // Go back to the trimming view
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                    
                    Button("Save") {
                        viewModel.saveMove()
                    }
                    .buttonStyle(.appPrimary(size: .medium))
                    .disabled(viewModel.moveName.isEmpty)
                }
                .padding()
                .padding(.bottom, 180)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
