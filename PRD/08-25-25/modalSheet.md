***

### Agent Task: Implement Advanced Combo Creation with Gestures and Search

**Project Goal:**
Completely overhaul the `CreateComboView` to match the prototype's advanced functionality. This includes replacing the static "Available Moves" list with a searchable pop-up sheet, implementing full-screen video playback, and adding intuitive drag-and-drop gestures for reordering and deleting timeline nodes.

***

### **Part 1: Refactor UI with a Searchable "Move Picker" Sheet**

**Task:**
To solve the "tight space" problem and add search, we will replace the always-visible "Available Moves" list with a button that presents a modal sheet.

**1. Create the `MovePickerSheet.swift` View:**
Create a new SwiftUI View file named `MovePickerSheet.swift` and replace its contents with this code. This new view will contain the searchable list.

```swift
import SwiftUI

struct MovePickerSheet: View {
    // This receives the full list of moves from the parent view.
    let moves: [Move]
    // This is a closure that the sheet calls when a move is selected.
    let onSelect: (Move) -> Void
    
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    // The list is filtered by the search text.
    private var searchResults: [Move] {
        if searchText.isEmpty {
            return moves
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    var body: some View {
        NavigationStack {
            List(searchResults) { move in
                AvailableMoveRowView(move: move)
                    .onTapGesture {
                        onSelect(move)
                        dismiss()
                    }
            }
            .listStyle(.plain)
            .navigationTitle("Select a Move")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Moves...")
        }
    }
}
```

***

### **Part 2: Implement the New `CreateComboView` with Full Functionality**

**Task:**
Rebuild `CreateComboView` from the ground up to use the new modal sheet, support full-screen video, and handle complex drag gestures on the timeline.

**Implementation:**
Replace the **entire contents** of `CreateComboView.swift` with this new, final version.

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
    
    // --- GESTURE STATE ---
    @State private var draggedItem: Move?
    @State private var deletionOffset: CGSize = .zero
    @State private var isAboutToDelete = false

    private var availableMoves: [Move] {
        allMoves.filter { !comboMoves.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- 1. AVAILABLE MOVES BUTTON ---
            Button(action: { isShowingMovePicker = true }) {
                Label("Add Move to Combo", systemImage: "plus")
            }
            .padding()

            // --- 2. LIVE VIDEO PREVIEW ---
            VStack {
                if let index = activeNodeIndex, let move = comboMoves[safe: index], let videoData = move.videoReference, let path = String(data: videoData, encoding: .utf8) {
                    VideoPlayer(player: AVPlayer(url: URL(fileURLWithPath: path)))
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

            // --- 3. YOUR COMBO TIMELINE ---
            VStack {
                Text("Your Combo").font(.title2).fontWeight(.bold)
                if comboMoves.isEmpty {
                    Text("Add a move to begin").foregroundColor(.secondary).padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(comboMoves.enumerated()), id: \.element.id) { index, move in
                                    TimelineNodeView(move: move, index: index, isActive: activeNodeIndex == index)
                                        .gesture(dragGesture(for: move, at: index)) // Attach the complex gesture here
                                        .id(index)
                                    if index < comboMoves.count - 1 {
                                        Rectangle().fill(Color.gray).frame(width: 30, height: 2)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: activeNodeIndex) { newIndex in
                            if let newIndex = newIndex {
                                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
                            }
                        }
                    }
                }
            }
            .frame(height: 150)
            
            // --- 4. SAVE BUTTON ---
            Button("Save Combo") { /* Save logic will be added here */ }
                .buttonStyle(.borderedProminent)
                .padding()
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
            if let index = activeNodeIndex, let move = comboMoves[safe: index], let videoData = move.videoReference, let path = String(data: videoData, encoding: .utf8) {
                VideoPlayer(player: AVPlayer(url: URL(fileURLWithPath: path)))
                    .ignoresSafeArea()
            }
        }
    }
    
    // --- 4. DRAG GESTURE LOGIC ---
    private func dragGesture(for move: Move, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Determine gesture direction
                if abs(value.translation.height) > abs(value.translation.width) {
                    // Vertical Drag: Handle Deletion
                    self.draggedItem = nil // Ensure reordering doesn't trigger
                    self.deletionOffset = value.translation
                    self.isAboutToDelete = value.translation.height > 50 // Deletion threshold
                } else {
                    // Horizontal Drag: Handle Reordering
                    self.deletionOffset = .zero
                    self.draggedItem = move
                }
            }
            .onEnded { value in
                if isAboutToDelete {
                    // Finalize Deletion
                    comboMoves.remove(at: index)
                } else if let draggedItem = self.draggedItem, let fromIndex = comboMoves.firstIndex(of: draggedItem) {
                    // Finalize Reordering
                    let toIndex = Int(round(Double(fromIndex) + value.translation.width / 80)) // 80 is node width + spacing
                    let clampedToIndex = max(0, min(toIndex, comboMoves.count - 1))
                    
                    if fromIndex != clampedToIndex {
                        withAnimation {
                            comboMoves.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: clampedToIndex > fromIndex ? clampedToIndex + 1 : clampedToIndex)
                        }
                    }
                }
                // Reset all gesture states
                self.draggedItem = nil
                self.deletionOffset = .zero
                self.isAboutToDelete = false
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