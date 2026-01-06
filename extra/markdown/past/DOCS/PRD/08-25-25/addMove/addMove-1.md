***

### Agent Task: Implement the `AddMoveView.swift` Screen

**Project Goal:**
Build a fully functional `AddMoveView` using SwiftUI and Core Data. This view allows a user to select a video from their Photos library, save it as a new "Move" in the database, and receive clear, in-place feedback about the success or failure of the operation.

**Core Requirements:**

1.  **State-Driven UI:** The view's appearance must be controlled by a state enum.
2.  **Core Data Integration:** It must correctly save new `Move` objects to the database.
3.  **Video Picker:** It must use the native `PHPickerViewController` to select videos.

***

**Step-by-Step Implementation Guide:**

**1. Set up the View Structure and State Management**

First, replace the entire contents of `AddMoveView.swift` with the following code. This sets up the necessary state variables, environment access for Core Data, and the state enum that will control the UI.

```swift
import SwiftUI
import PhotosUI

struct AddMoveView: View {
    // Access the Core Data database context from the environment.
    @Environment(\.managedObjectContext) private var viewContext

    // The state enum to control the UI's appearance and behavior.
    enum AddMoveState {
        case ready          // The initial state, ready for user input.
        case loading        // Processing the selected video.
        case success(String) // The move was saved successfully.
        case error(String)   // An error occurred.
    }

    // The current state of the view.
    @State private var currentState: AddMoveState = .ready
    // This will control showing the video picker sheet.
    @State private var isPickerPresented = false

    var body: some View {
        // We will implement the view's body in the next step.
        Text("Placeholder")
    }
}

// We will add the preview back later.
```

**2. Build the UI based on the Current State**

Now, replace the `// We will implement...` and `Text("Placeholder")` lines inside the `body` with this `ZStack` and `switch` statement. This will make the UI render differently for each state.

```swift
var body: some View {
    ZStack {
        // Use a switch to change the view's content based on the current state.
        switch currentState {
        case .ready:
            VStack(spacing: 10) {
                Button("SELECT CLIP") {
                    isPickerPresented = true
                }
                .font(.headline)
                .padding()
                .background(Color.accent)
                .foregroundColor(.white)
                .cornerRadius(10)

                Text("Supports .mp4, .mov")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2.0)
                .tint(.accent)

        case .success(let message):
            Text(message)
                .font(.headline)
                .foregroundColor(.stateMastery)

        case .error(let message):
            Text(message)
                .font(.headline)
                .foregroundColor(.red)
        }
    }
    // This sheet presents the video picker when isPickerPresented becomes true.
    .sheet(isPresented: $isPickerPresented) {
        // We will implement the VideoPicker here.
    }
}
```

**3. Implement the Video Picker**

To handle the video picker, we need a special helper `struct` that can talk to the older UIKit-based `PHPickerViewController`. Add the following `VideoPicker` struct *inside* the `AddMoveView.swift` file, but *outside* the `AddMoveView` struct itself.

```swift
struct VideoPicker: UIViewControllerRepresentable {
    // This allows the picker to communicate back to the AddMoveView.
    @Binding var state: AddMoveView.AddMoveState
    var viewContext: NSManagedObjectContext

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos // Only allow videos to be selected.
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }
            parent.state = .loading

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url else {
                    DispatchQueue.main.async {
                        self.parent.state = .error("Failed to load video.")
                    }
                    return
                }

                // Move the temporary file to a permanent location.
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let newURL = documentsURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)

                do {
                    try fileManager.copyItem(at: url, to: newURL)
                    
                    // Save the reference to Core Data on the main thread.
                    DispatchQueue.main.async {
                        self.saveMove(with: newURL.absoluteString)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.state = .error("Failed to save video.")
                    }
                }
            }
        }
        
        private func saveMove(with filePath: String) {
            let newMove = Move(context: parent.viewContext)
            newMove.id = UUID()
            newMove.name = "New Move" // We can add a text field for this later.
            newMove.createdAt = Date()
            newMove.learningState = "NEW"
            newMove.videoReference = Data(filePath.utf8) // Store the file path as data.

            do {
                try parent.viewContext.save()
                parent.state = .success("Your move clip was added!")
                // Task to reset the UI after a delay.
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    parent.state = .ready
                }
            } catch {
                parent.state = .error("Database save failed.")
            }
        }
    }
}
```

Finally, go back to the `.sheet` modifier in the `AddMoveView`'s `body` and create an instance of the `VideoPicker`.

```swift
// Replace the comment inside the .sheet
.sheet(isPresented: $isPickerPresented) {
    VideoPicker(state: $currentState, viewContext: viewContext)
}
```