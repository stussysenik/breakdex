import SwiftUI

struct AddMoveSelectingVideoView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var isButtonPressed = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select a New Video")
                .font(.custom("IBMPlexMono-Bold", size: 18))
                .foregroundColor(.primary)
            
            AppPhotosPickerButton(selection: $viewModel.selectedItem)
                .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                .opacity(isButtonPressed ? 0.8 : 1.0)
                .onTapGesture {
                    // logger.info("🎬 SELECT_CLIP_VIEW: Change video button tapped in selectingVideo state")
                    MotionCatalog.Accessibility.buttonTap()
                    isButtonPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isButtonPressed = false
                    }
                }
            
            Button("Cancel") {
                // logger.info("🎬 SELECT_CLIP_VIEW: Cancel button tapped - calling cancelChangeVideo()")
                // logger.info("🎬 SELECT_CLIP_VIEW: Current state before cancel: \(String(describing: viewModel.state))")
                viewModel.cancelChangeVideo()
                // logger.info("🎬 SELECT_CLIP_VIEW: cancelChangeVideo() called")
            }
            .buttonStyle(.appSecondary(size: .medium))
            .accessibilityIdentifier("Cancel Selection Button")
        }
        .padding(.horizontal, 20)
    }
}
