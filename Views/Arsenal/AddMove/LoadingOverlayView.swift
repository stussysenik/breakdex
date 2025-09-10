import SwiftUI

/// Overlay view that displays loading progress without disrupting the main UI
struct LoadingOverlayView: View {
    let progress: Double
    let status: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Loading content
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)
                    .frame(width: 200)

                Text(status)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .shadow(radius: 8)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()

        LoadingOverlayView(
            progress: 0.7,
            status: "Loading video from Photos library..."
        )
    }
}
