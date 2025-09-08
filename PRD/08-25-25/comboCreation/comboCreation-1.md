***

### Agent Task: Build Combo Creation Foundation & Refine UI

**Project Goal:**
Implement the foundational UI for the "Create Combo" feature and improve the timestamp display in the "Move Arsenal".

***

### **Part 1: Refine `MoveListView` Timestamp**

**File to Modify:** `MoveListView.swift`

**Task:**
Update the `List` to display a more precise timestamp for each move, including the time.

**Implementation:**
Locate the `List` in the view's `body`. Find the `Text` view that displays the creation date and modify it to include the time.

**Replace this line:**
`Text("Added on: $$move.createdAt ?? Date(), style: .date)")`

**With this line:**
`Text("Added: $$move.createdAt ?? Date(), format: .dateTime.month().day().year().hour().minute())")`

***

### **Part 2: Build the `AvailableMoveRowView` Component**

**File to Create:** `AvailableMoveRowView.swift`

**Task:**
Create a new, reusable SwiftUI View that will serve as a row in the list of available moves.

**Implementation:**
Create a new SwiftUI View file named `AvailableMoveRowView.swift` and replace its contents with the following code:

```swift
import SwiftUI

struct AvailableMoveRowView: View {
    let move: Move

    var body: some View {
        HStack {
            // This capsule's color indicates the move's learning state.
            Capsule()
                .fill(learningStateColor)
                .frame(width: 5, height: 30)

            Text(move.name ?? "Untitled Move")
                .font(.headline)
                .padding(.leading, 8)

            Spacer()
        }
        .padding(.vertical, 4)
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

### **Part 3: Build the `CreateComboView` Layout**

**File to Create:** `CreateComboView.swift`

**Task:**
Create the main view for the "Create Combo" feature. It will fetch and display all saved moves using the new row component.

**Implementation:**
Create a new SwiftUI View file named `CreateComboView.swift` and replace its contents with this code:

```swift
import SwiftUI
import CoreData

struct CreateComboView: View {
    // Fetch all 'Move' objects from Core Data, sorted by name.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.name, ascending: true)],
        animation: .default)
    private var moves: FetchedResults<Move>

    var body: some View {
        VStack {
            // The top half of the screen lists all available moves.
            List(moves) { move in
                AvailableMoveRowView(move: move)
            }
            .listStyle(.plain)
            .navigationTitle("Create Combo")

            // The bottom half is a placeholder for the timeline.
            VStack {
                Text("Your Combo")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                Text("Select a move above to begin")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .frame(maxHeight: .infinity / 2) // Give it half the screen space.
        }
        .background(Color.backgroundPrimary)
    }
}
```