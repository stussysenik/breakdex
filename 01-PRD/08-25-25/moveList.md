***

### Agent Task: Implement the `MoveListView.swift` Screen

**Project Goal:**
Create a SwiftUI view that fetches all `Move` objects from Core Data and displays them in a sorted list.

**Core Requirements:**

1.  **Fetch Data:** Use `@FetchRequest` to retrieve all `Move` objects from the database.
2.  **Display in a List:** The moves must be displayed in a `List`, with the most recently added moves appearing at the top.
3.  **Handle Empty State:** The view should display a helpful message if no moves have been added yet.

***

**Step-by-Step Implementation Guide:**

**1. Create the `MoveListView.swift` File**

First, ensure you have created a new SwiftUI View file in Xcode named `MoveListView.swift`.

**2. Implement the View Code**

Now, replace the entire contents of `MoveListView.swift` with the following code. This code will fetch the data and display it.

```swift
import SwiftUI
import CoreData

struct MoveListView: View {
    // 1. FETCH THE DATA
    // This fetches all 'Move' objects from Core Data.
    // They are sorted by 'createdAt' in descending order (newest first).
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Move.createdAt, ascending: false)],
        animation: .default)
    private var moves: FetchedResults<Move>

    var body: some View {
        // Use a ZStack to set a background color.
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            // 2. HANDLE EMPTY STATE
            // If there are no moves, show a message.
            if moves.isEmpty {
                Text("No moves added yet.\nTap the 'Add' tab to start!")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // 3. DISPLAY THE LIST
                // If there are moves, display them in a List.
                List(moves) { move in
                    // This is the view for each row in the list.
                    VStack(alignment: .leading) {
                        Text(move.name ?? "Untitled Move")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text("Added on: \(move.createdAt ?? Date(), style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(Color.backgroundPrimary)
                }
                .listStyle(.plain) // Use plain style for a cleaner look.
            }
        }
        .navigationTitle("Move Arsenal")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

[1](https://stackoverflow.com/questions/66180963/swiftui-and-core-data-using-a-fetch-request-with-instance-member-as-argument-in)
[2](https://developer.apple.com/documentation/swiftui/fetchrequest)
[3](https://fatbobman.com/en/posts/exploring-swiftui-property-wrappers-3/)
[4](https://www.youtube.com/watch?v=nalfX8yP0wc)
[5](https://www.donnywals.com/fetching-objects-from-core-data-in-a-swiftui-project/)
[6](https://fatbobman.com/en/posts/modern-core-data-fetcher/)
[7](https://tanaschita.com/coredata-with-swiftui/)