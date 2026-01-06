
***
Note: I accidentally did it for the breaking arsenal option

### Agent Task: Implement Search, Naming, and Layout Refinements 

**Project Goal:**
Enhance the core functionality of the app by allowing users to name new moves, search their existing arsenal, and improve the layout of the "Create Combo" screen for better usability.

***

### **Part 1: Add Naming to the `AddMoveView`**

**File to Modify:** `AddMoveView.swift`

**Task:**
Update the "Add Move" workflow to include a `TextField` so users can name their move before saving it.

**Implementation:**
Modify the `Coordinator` and the `VideoPicker` to handle passing a name.

**1. Update the `VideoPicker` struct:**
Add a new `@Binding` for the move name.

```swift
// In VideoPicker struct
@Binding var moveName: String
```

**2. Update the `Coordinator`'s `saveMove` function:**
Modify the `saveMove` function to use the new `moveName` binding instead of a hardcoded string.

```swift
// In the Coordinator's saveMove function
private func saveMove(with filePath: String) {
    let newMove = Move(context: parent.viewContext)
    newMove.id = UUID()
    // Use the name from the binding.
    newMove.name = parent.moveName.isEmpty ? "Untitled Move" : parent.moveName
    // ... rest of the function is the same
    newMove.createdAt = Date()
    newMove.learningState = "NEW"
    newMove.videoReference = Data(filePath.utf8)

    do {
        try parent.viewContext.save()
        // ... success and error handling
    } catch {
        // ...
    }
}
```

**3. Update the `AddMoveView` itself:**
Add a state variable for the text field and place a `TextField` in the UI.

```swift
// In AddMoveView struct, add these new state variables
@State private var moveName: String = ""

// In the .sheet modifier where you create the VideoPicker
.sheet(isPresented: $isPickerPresented) {
    VideoPicker(state: $currentState, moveName: $moveName, viewContext: viewContext)
}

// In the body, inside the .ready case's VStack, add the TextField
// --- Inside the .ready case ---
VStack(spacing: 15) {
    TextField("Enter Move Name", text: $moveName)
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal)

    Button("SELECT CLIP") {
        // ...
    }
    // ...
}
```

***

### **Part 2: Implement Search in `MoveListView`**

**File to Modify:** `MoveListView.swift`

**Task:**
Add a search bar to the "Move Arsenal" list to allow users to quickly find specific moves.

**Implementation:**
Add a `@State` variable for the search text and apply the `.searchable` modifier to the `List`.

**Replace the entire contents of `MoveListView.swift` with this code:**

```swift
import SwiftUI
import CoreData

struct MoveListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    // New state for the search text.
    @State private var searchText = ""

    // Filtered results based on search text.
    var searchResults: [Move] {
        if searchText.isEmpty {
            return Array(moves)
        } else {
            return moves.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            if moves.isEmpty {
                // ... empty state remains the same
            } else {
                // The List now iterates over the searchResults.
                List(searchResults) { move in
                    NavigationLink(destination: MoveDetailView(move: move)) {
                        VStack(alignment: .leading) {
                            Text(move.name ?? "Untitled Move")
                            // ...
                        }
                    }
                    .listRowBackground(Color.backgroundPrimary)
                }
                .listStyle(.plain)
                // Add the searchable modifier here.
                .searchable(text: $searchText, prompt: "Search Moves...")
            }
        }
        .navigationTitle("Move Arsenal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

***

### **Part 3: Refine `CreateComboView` Layout**

**File to Modify:** `CreateComboView.swift`

**Task:**
Adjust the layout to provide a visual cue that the "Available Moves" list is scrollable, as seen in the prototype.

**Implementation:**
Simply change the fixed height of the "Available Moves" section.

**In `CreateComboView.swift`, locate this line:**
`.frame(height: 250)`

**And change it to a slightly smaller height:**
`.frame(height: 200)`