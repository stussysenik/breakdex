import SwiftUI

struct AddMoveReadyView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    @State private var isButtonPressed = false

    var body: some View {
        AppPhotosPickerButton(selection: $viewModel.selectedItem)
            .scaleEffect(isButtonPressed ? 0.97 : 1.0)
            .opacity(isButtonPressed ? 0.8 : 1.0)
            .onTapGesture {
                // logger.info("🎬 SELECT_CLIP_VIEW: Button tapped - initiating video selection")
                // logger.info("🎬 SELECT_CLIP_VIEW: Current viewModel state: \(String(describing: viewModel.state))")
                // logger.info("🎬 SELECT_CLIP_VIEW: Current selectedItem: \(viewModel.selectedItem?.itemIdentifier ?? "nil")")

                MotionCatalog.Accessibility.buttonTap()
                isButtonPressed = true

                // logger.info("🎬 SELECT_CLIP_VIEW: Starting button animation")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    // logger.info("🎬 SELECT_CLIP_VIEW: Button animation completed")
                    isButtonPressed = false
                }
            }
    }
}