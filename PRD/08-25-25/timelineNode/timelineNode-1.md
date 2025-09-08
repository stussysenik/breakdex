***

### Agent Task: Implement Interactive Combo Timeline

**Project Goal:**
Transform the static `CreateComboView` into an interactive screen where users can tap moves from a list to dynamically build a visual timeline.

***

### **Part 1: Build the `TimelineNodeView` Component**

**File to Create:** `TimelineNodeView.swift`

**Task:**
Create a new, reusable SwiftUI View that serves as the visual representation of a single move within the combo timeline.

**Implementation:**
Create a new SwiftUI View file named `TimelineNodeView.swift` and replace its contents with the following code:

```swift
import SwiftUI

struct TimelineNodeView: View {
    let move: Move

    var body: some View {
        ZStack {
            // The main circular shape.
            Circle()
                .fill(Color.neutralFill) // The inner fill color.
                .frame(width: 60, height: 60)
                .overlay(
                    // The colored border indicating the learning state.
                    Circle()
                        .stroke(learningStateColor, lineWidth: 4)
                )

            // Display the first letter of the move's name.
            if let firstLetter = move.name?.first {
                Text(String(firstLetter))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }

    // This helper computes the correct color based on the move's state.
    private var learningStateColor: Color {
        switch move.learningState {
        case "LEARNING":
            return .stateLearning
        case "MASTERY":
            return .stateMastery
        default: // Includes "NEW"
            return .stateNew
        }
    }
}
```

***

### **Part 2: Make `CreateComboView` Interactive**

**File to Modify:** `CreateComboView.swift`

**Task:**
Update the `CreateComboView` to manage the state of the combo being built and to display the interactive timeline.

**Implementation:**
Open `CreateComboView.swift` and replace its entire contents with this updated code:

```swift
import SwiftUI
import CoreData

struct CreateComboView: View {
    // Fetch all 'Move' objects from Core Data.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.name, ascending: true)],
        animation: .default)
    private var moves: FetchedResults<Move>
    
    // This new state variable will hold the sequence of moves in the timeline.
    @State private var comboMoves: [Move] = []

    var body: some View {
        VStack {
            // This is the list of available moves at the top.
            List {
                ForEach(moves) { move in
                    AvailableMoveRowView(move: move)
                        .onTapGesture {
                            // When a row is tapped, add the move to our combo.
                            comboMoves.append(move)
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Create Combo")

            // This is the bottom section for the timeline.
            VStack {
                Text("Your Combo")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                // If the combo is empty, show the placeholder text.
                if comboMoves.isEmpty {
                    Spacer()
                    Text("Select a move above to begin")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    // If the combo has moves, display the horizontal timeline.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(comboMoves.indices, id: \.self) { index in
                                TimelineNodeView(move: comboMoves[index])
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(maxHeight: .infinity / 2.5) // Give it a fixed portion of the screen.
        }
        .background(Color.backgroundPrimary)
    }
}
```