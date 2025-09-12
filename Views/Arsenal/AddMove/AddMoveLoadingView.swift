import SwiftUI

struct AddMoveLoadingView: View {
    let progress: Double
    let status: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .padding(.horizontal, 40)
            Text(status)
                .font(.ibmPlexMono(size: 14, weight: .thin))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }
}
