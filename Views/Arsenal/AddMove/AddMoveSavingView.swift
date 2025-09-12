import SwiftUI

struct AddMoveSavingView: View {
    var body: some View {
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
    }
}