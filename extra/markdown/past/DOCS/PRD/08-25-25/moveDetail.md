***

### Agent Task: Implement the `MoveDetailView.swift` Screen

**Project Goal:**
Create a SwiftUI view that displays the video and key details for a single `Move` object passed into it.

**Core Requirements:**

1.  **Receive a `Move`:** The view must be initialized with a specific `Move` object.
2.  **Play the Video:** It must use `AVKit`'s `VideoPlayer` to play the video clip associated with the `Move`.
3.  **Display Metadata:** It must show the `Move`'s name and its current `learningState`.

***

**Step-by-Step Implementation Guide:**

**1. Create the `MoveDetailView.swift` File**

First, ensure you have created a new SwiftUI View file in Xcode named `MoveDetailView.swift`.

**2. Implement the View Code**

Now, replace the entire contents of `MoveDetailView.swift` with the following code.

```swift
import SwiftUI
import AVKit

struct MoveDetailView: View {
    // This view receives a single 'Move' object to display.
    let move: Move

    // A state variable to hold the AVPlayer instance.
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack {
                // The VideoPlayer will take up the most space.
                if let player = player {
                    VideoPlayer(player: player)
                } else {
                    // Show a placeholder while the video loads or if it fails.
                    ZStack {
                        Color.black
                        Text("Loading Video...")
                            .foregroundColor(.secondary)
                    }
                }

                // Display the move's details below the video.
                HStack {
                    Text(move.name ?? "Untitled Move")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // We will create this reusable pill view later.
                    Text(move.learningState ?? "NEW")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                }
                .padding()
            }
        }
        .navigationTitle(move.name ?? "Move Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setupPlayer)
    }

    /// This function sets up the AVPlayer.
    private func setupPlayer() {
        // 1. Get the file path from the Move's videoReference.
        guard let videoReferenceData = move.videoReference,
              let filePath = String(data: videoReferenceData, encoding: .utf8) else {
            return
        }
        
        // 2. Create a URL from the file path.
        let videoURL = URL(fileURLWithPath: filePath)
        
        // 3. Initialize the AVPlayer with the URL.
        self.player = AVPlayer(url: videoURL)
        
        // 4. (Optional) Automatically play the video when the view appears.
        self.player?.play()
    }
}
```

[1](https://www.createwithswift.com/custom-video-player-with-avkit-and-swiftui-supporting-picture-in-picture/)
[2](https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/2-create-a-video-player-in-swiftui)
[3](https://www.youtube.com/watch?v=9pGn2S9ZX0A)
[4](https://developer.apple.com/documentation/avkit/videoplayer)
[5](https://www.swiftanytime.com/blog/videoplayer-in-swiftui)
[6](https://www.youtube.com/watch?v=9TwO9yMsPRg)
[7](https://designcode.io/swiftui-handbook-play-video-with-avplayer/)