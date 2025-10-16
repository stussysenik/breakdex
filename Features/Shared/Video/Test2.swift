import SwiftUI

struct TrimmingView: View {
    @State private var trimRange: ClosedRange<CGFloat> = 0.2...0.8 // Example trim range (adjust as needed)
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. Video Player (Single Rounded Radius)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                
                // Video placeholder
                Image("video-placeholder") // Replace with your video asset
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }
            .frame(height: 220)
            .padding(.horizontal, 16)
            
            // 2. Timecode Section (Uniform Size, One Line)
            HStack(spacing: 40) {
                VStack(alignment: .center, spacing: 4) {
                    Text("START")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("00:00:00")
                        .font(.headline)
                }
                
                Text("00:34:03") // Single-line duration (matches start/end size)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                VStack(alignment: .center, spacing: 4) {
                    Text("END")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("00:34:03")
                        .font(.headline)
                }
            }
            .padding(.horizontal, 16)
            
            // 3. Timeline with Trim Handles
            VStack(spacing: 8) {
                // Timeline Bar (With Trim Handles)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background timeline
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(height: 40)
                            .cornerRadius(8)
                        
                        // Left trim handle
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .offset(x: geometry.size.width * trimRange.lowerBound - 10)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = value.location.x - 10
                                        let clampedOffset = min(max(newOffset, 0), geometry.size.width * trimRange.upperBound - 20)
                                        trimRange = clampedOffset / geometry.size.width ... trimRange.upperBound
                                    }
                            )
                        
                        // Right trim handle
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .offset(x: geometry.size.width * trimRange.upperBound - 10)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = value.location.x - 10
                                        let clampedOffset = max(min(newOffset, geometry.size.width - 20), geometry.size.width * trimRange.lowerBound)
                                        trimRange = trimRange.lowerBound ... clampedOffset / geometry.size.width
                                    }
                            )
                    }
                }
                .frame(height: 40)
                .padding(.horizontal, 16)
                
                // Timeline Annotations (Forced Single Line)
                HStack(spacing: 24) { // Wider spacing to accommodate full timestamps
                    ForEach([0, 1, 2, 3, 4], id: \.self) { index in
                        Text(timeLabel(for: index))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1) // Explicitly restrict to 1 line
                            .minimumScaleFactor(0.7) // Scale down if text overflows
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // 4. Control Buttons (Play/Rotate + Reset)
            HStack(spacing: 16) {
                Button(action: { /* Play video */ }) {
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                Button(action: { /* Rotate video */ }) {
                    Image(systemName: "rotate.right")
                        .font(.title)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                }
                
                Spacer()
                
                Text("Reset")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            
            // 5. Action Buttons (Cancel/Submit)
            HStack(spacing: 16) {
                Button("Cancel") {
                    /* Dismiss action */
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Button("Submit") {
                    /* Confirm action */
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            
            // 6. Bottom Navigation (Optional)
            HStack(spacing: 32) {
                bottomNavItem(icon: "book", label: "Arsenal")
                bottomNavItem(icon: "plus", label: "Add Move", isActive: true)
                bottomNavItem(icon: "wand.and.stars", label: "Create Combo")
                bottomNavItem(icon: "gamecontroller", label: "Review")
            }
            .padding(.top, 20)
        }
        .padding(.vertical, 20)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Helper: Generate time labels for timeline ticks
    private func timeLabel(for index: Int) -> String {
        switch index {
        case 0: return "00:00:00"
        case 1: return "00:08:12"
        case 2: return "00:17:01"
        case 3: return "00:25:14"
        default: return "00:34:03"
        }
    }
    
    // Helper: Reusable bottom nav item
    private func bottomNavItem(icon: String, label: String, isActive: Bool = false) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .blue : .gray)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isActive ? .blue : .gray)
        }
    }
}
// Preview for Xcode Canvas
struct TrimmingView_Previews: PreviewProvider {
    static var previews: some View {
        TrimmingView()
    }
}
