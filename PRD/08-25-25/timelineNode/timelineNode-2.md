***

### Agent Task: Implement Final Interactive Timeline with Active State

**Project Goal:**
Finalize the `CreateComboView` by implementing an "active" state for the timeline nodes. The selected node should scale up to become a focal point, and the timeline should automatically scroll to keep the active node centered.

***

### **Part 1: Enhance `TimelineNodeView` with an Active State**

**File to Modify:** `TimelineNodeView.swift`

**Task:**
Update the timeline node to visually change when it is "active" by scaling up with a smooth animation.

**Implementation:**
Modify the `TimelineNodeView` to accept an `isActive` boolean that controls its appearance.

**Replace the entire contents of `TimelineNodeView.swift` with this code:**

```swift
import SwiftUI

struct TimelineNodeView: View {
    let move: Move
    let index: Int
    let isActive: Bool // New property to track the active state

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.neutralFill)
                .overlay(
                    // The border width now changes when active.
                    Circle()
                        .stroke(learningStateColor, lineWidth: isActive ? 6 : 4)
                )

            Text("\(index + 1)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        // The node scales up when it's active.
        .scaleEffect(isActive ? 1.25 : 1.0)
        // Add a gentle spring animation to all changes.
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        .frame(width: 60, height: 60)
    }

    private var learningStateColor: Color {
        // ... (learningStateColor helper function remains the same)
        switch move.learningState {
        case "LEARNING":
            return .stateLearning
        case "MASTERY":
            return .stateMastery
        default:
            return .stateNew
        }
    }
}
```

***

### **Part 2: Implement Auto-Scrolling in `CreateComboView`**

**File to Modify:** `CreateComboView.swift`

**Task:**
Update the `CreateComboView` to use a `ScrollViewReader`, which allows us to programmatically scroll the timeline to center the active node.

**Implementation:**
Replace the entire contents of `CreateComboView.swift` with this final, fully-featured version:

```swift
import SwiftUI
import CoreData
import AVKit

struct CreateComboView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.name, ascending: true)],
        animation: .default)
    private var allMoves: FetchedResults<Move>
    
    @State private var comboMoves: [Move] = []
    @State private var activeNodeIndex: Int?

    private var availableMoves: [Move] {
        allMoves.filter { !comboMoves.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- AVAILABLE MOVES SECTION (Remains the same) ---
            VStack {
                Text("Available Moves").font(.headline).padding(.top)
                List(availableMoves) { move in
                    AvailableMoveRowView(move: move)
                        .onTapGesture {
                            comboMoves.append(move)
                        }
                }
                .listStyle(.plain)
            }
            .frame(height: 250)

            // --- LIVE VIDEO PREVIEW SECTION (Remains the same) ---
            VStack {
                if let index = activeNodeIndex, let move = comboMoves[safe: index] {
                    VideoPlayer(player: AVPlayer(url: URL(fileURLWithPath: String(data: move.videoReference!, encoding: .utf8)!)))
                } else {
                    ZStack {
                        Color.black.cornerRadius(10)
                        Text("Select a move in the timeline to preview")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxHeight: .infinity)

            // --- YOUR COMBO TIMELINE SECTION (With Auto-Scrolling) ---
            VStack {
                Text("Your Combo")
                    .font(.title2)
                    .fontWeight(.bold)

                if comboMoves.isEmpty {
                    Text("Select a move above to begin")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // 1. Wrap the ScrollView in a ScrollViewReader
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(comboMoves.indices, id: \.self) { index in
                                    TimelineNodeView(
                                        move: comboMoves[index],
                                        index: index,
                                        // Pass the active state to the node
                                        isActive: activeNodeIndex == index
                                    )
                                    .onTapGesture {
                                        activeNodeIndex = index
                                    }
                                    .id(index) // 2. Give each node a unique ID
                                    
                                    if index < comboMoves.count - 1 {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(width: 30, height: 2)
                                    }
                                }
                            }
                            .padding()
                        }
                        // 3. Add an .onChange modifier to trigger the scroll
                        .onChange(of: activeNodeIndex) { newIndex in
                            if let newIndex = newIndex {
                                withAnimation {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 150)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Create Combo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ... (safe subscript helper extension remains the same) ...
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```

[1](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/images/76040252/8661987b-bd5e-49ec-8e81-1159e6c7aa28/image.jpg)
[2](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/images/76040252/7027988b-e935-4094-b690-bdb6d0d815dc/image.jpg)