***

### Agent Task: Fix and Refine Combo Creation and Video Playback

**Project Goal:**
Overhaul the combo creation workflow to fix bugs, simplify interactions, and improve the user experience. This includes fixing video playback, implementing a simple "drag-to-delete" gesture, adding a cancel button, and enabling fullscreen video.

***

### **Part 1: Update the `MovePickerSheet`**

**File to Modify:** `MovePickerSheet.swift`

**Task:**
Add an explicit "Cancel" button to the sheet's navigation bar, giving users a clear way to close it without making a selection.

**Implementation:**
Add a `.toolbar` modifier to the `List`.

```swift
// In MovePickerSheet.swift, add this modifier to the List
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
            dismiss()
        }
    }
}
```

***

### **Part 2: Update `AddMoveView` for Fullscreen Video**

**File to Modify:** `AddMoveView.swift`

**Task:**
Make the video preview on the confirmation screen tappable to open it in a fullscreen player.

**Implementation:**
Add state to control the fullscreen view and attach a `.onTapGesture` and a `.fullScreenCover` to the `VideoPlayer`.

```swift
// In AddMoveView, add this new state variable
@State private var isShowingFullscreenPlayer = false

// In the .loaded(let videoURL) case, find the VideoPlayer and wrap it
VStack { // The existing VStack
    VideoPlayer(player: AVPlayer(url: videoURL))
        .frame(height: 200)
        .cornerRadius(10)
        .onTapGesture {
            isShowingFullscreenPlayer = true
        }
        .fullScreenCover(isPresented: $isShowingFullscreenPlayer) {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .ignoresSafeArea()
        }

    // ... rest of the content (TextField, Buttons)
}
```

***

### **Part 3: Overhaul `CreateComboView` for Stability and Simplicity**

**File to Modify:** `CreateComboView.swift`

**Task:**
Rebuild the view to fix video playback and horizontal scrolling, and implement a simple, robust "drag down to delete" gesture.

**Implementation:**
Replace the **entire contents** of `CreateComboView.swift` with this new, corrected, and simplified version.

```swift
import SwiftUI
import CoreData
import AVKit

struct CreateComboView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.name, ascending: true)],
        animation: .default)
    private var allMoves: FetchedResults<Move>
    
    // --- STATE MANAGEMENT ---
    @State private var comboMoves: [Move] = []
    @State private var activeNodeIndex: Int?
    @State private var isShowingMovePicker = false
    @State private var isShowingFullscreenPlayer = false
    
    // --- GESTURE STATE (SIMPLIFIED FOR DELETION ONLY) ---
    @State private var deletionOffsets: [UUID: CGSize] = [:]

    private var availableMoves: [Move] {
        allMoves.filter { !comboMoves.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isShowingMovePicker = true }) {
                Label("Add Move to Combo", systemImage: "plus")
            }
            .padding()

            // --- VIDEO PREVIEW (CORRECTED) ---
            VStack {
                // Use a computed property for the player to ensure it updates.
                if let player = activePlayer {
                    VideoPlayer(player: player)
                        .onTapGesture { isShowingFullscreenPlayer = true }
                } else {
                    ZStack {
                        Color.black.cornerRadius(10)
                        Text("Select a move to preview").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            // --- YOUR COMBO TIMELINE (CORRECTED) ---
            VStack {
                Text("Your Combo").font(.title2).fontWeight(.bold)
                ScrollView(.horizontal, showsIndicators: false) { // This now works correctly
                    HStack(spacing: 0) {
                        ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, move in
                            TimelineNodeView(move: move, index: index, isActive: activeNodeIndex == index)
                                .offset(deletionOffsets[move.id!, default: .zero]) // Apply drag offset
                                .gesture(deletionDragGesture(for: move)) // Attach deletion gesture
                                .onTapGesture { activeNodeIndex = index }
                            
                            if index < comboMoves.count - 1 {
                                Rectangle().fill(Color.gray).frame(width: 30, height: 2)
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(height: 150)
            
            // --- SAVE BUTTON (WITH PROPER PADDING) ---
            Button("Save Combo") { /* Save logic will be added here */ }
                .buttonStyle(.borderedProminent)
                .padding() // This padding lifts the button from the bottom edge.
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Create Combo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingMovePicker) {
            MovePickerSheet(moves: availableMoves) { selectedMove in
                comboMoves.append(selectedMove)
            }
        }
        .fullScreenCover(isPresented: $isShowingFullscreenPlayer) {
            if let player = activePlayer {
                VideoPlayer(player: player).ignoresSafeArea()
            }
        }
    }
    
    // This computed player ensures the video updates when the selection changes.
    private var activePlayer: AVPlayer? {
        guard let index = activeNodeIndex,
              let move = comboMoves[safe: index],
              let videoData = move.videoReference,
              let path = String(data: videoData, encoding: .utf8) else {
            return nil
        }
        return AVPlayer(url: URL(fileURLWithPath: path))
    }
    
    // --- SIMPLIFIED DELETION DRAG GESTURE ---
    private func deletionDragGesture(for move: Move) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Only track vertical movement for deletion.
                if value.translation.height > 0 {
                    deletionOffsets[move.id!] = value.translation
                }
            }
            .onEnded { value in
                // If dragged down far enough, delete the move.
                if value.translation.height > 80 {
                    comboMoves.removeAll { $0.id == move.id }
                    deletionOffsets.removeValue(forKey: move.id!)
                } else {
                    // Otherwise, animate it back to its original position.
                    withAnimation(.spring()) {
                        deletionOffsets[move.id!] = .zero
                    }
                }
            }
    }
}

// ... (safe subscript helper extension remains the same) ...
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
```