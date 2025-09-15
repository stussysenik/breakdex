import SwiftUI

/// Enhanced overlay view that displays real-time loading progress with visual feedback
struct LoadingOverlayView: View {
    let progress: Double
    let status: String
    
    @State private var isAnimating = false
    @State private var pulseScale: Double = 1.0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .blur(radius: 2)

            // Enhanced loading content
            VStack(spacing: 20) {
                // Animated progress indicator with percentage
                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .scaleEffect(pulseScale)
                        .frame(width: 120, height: 120)
                        .animation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    
                    // Main progress circle
                    CircularProgressView(progress: progress)
                        .frame(width: 100, height: 100)
                    
                    // Percentage text
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Enhanced status text with emoji support
                Text(status)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Linear progress bar with gradient
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    .frame(width: 240, height: 8)
                    .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.9), Color.black.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
            )
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        .onAppear {
            isAnimating = true
            withAnimation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.1
            }
        }
    }
}

// Custom circular progress view for enhanced visual feedback
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 8)
                .frame(width: 100, height: 100)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 100)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
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
