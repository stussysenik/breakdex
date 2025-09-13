import SwiftUI

struct AddMoveSavingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.accentColor)
            Text("Saving your move...")
                .font(.appFont(AppFont.thin, size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }
}