import SwiftUI

// MARK: - Animation Tester
// Development utility for testing and validating animations
// Remove from production builds

struct AnimationTester: View {
    @State private var isAnimating = false
    @State private var currentTest = 0

    let tests = [
        "Tap Animation",
        "Press Animation",
        "Navigation Animation",
        "Content Animation",
        "Tab Switch"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Animation Tester")
                .font(.title)
                .padding()

            ForEach(tests.indices, id: \.self) { index in
                Button(action: {
                    currentTest = index
                    isAnimating.toggle()
                }) {
                    Text(tests[index])
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .animation(MotionCatalog.Navigation.push, value: isAnimating)
            }

            Spacer()

            // Test subject
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 180 : 0))
                .offset(y: isAnimating ? -50 : 0)
                .applyTestAnimation(testIndex: currentTest, isAnimating: isAnimating)
        }
        .padding()
    }
}

// MARK: - Animation Test Helpers
private extension View {
    @ViewBuilder
    func applyTestAnimation(testIndex: Int, isAnimating: Bool) -> some View {
        switch testIndex {
        case 0: self.animation(MotionCatalog.Navigation.push, value: isAnimating)
        case 1: self.animation(MotionCatalog.Navigation.tabSwitch, value: isAnimating)
        case 2: self.animation(MotionCatalog.Navigation.push, value: isAnimating)
        case 3: self.animation(MotionCatalog.Navigation.push, value: isAnimating)
        case 4: self.animation(MotionCatalog.Navigation.tabSwitch, value: isAnimating)
        default: self
        }
    }
}

#Preview {
    AnimationTester()
}
