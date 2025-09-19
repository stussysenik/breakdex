***

### Agent Task: Implement Advanced "Add Move" Workflow

**Project Goal:**
Refactor the `AddMoveView` to create a more robust and intuitive multi-step workflow. This includes showing a loading progress bar, allowing the user to name the move only *after* selection, and providing clear options to cancel or change the selected video.

***

### **Implementation Guide**

**File to Modify:** `AddMoveView.swift`

**Task:**
Rebuild the `AddMoveView` and its `VideoPicker` coordinator to manage a more complex state machine that guides the user through the selection, loading, and naming process.

**Replace the entire contents of `AddMoveView.swift` with this new, advanced implementation:**

```swift
import SwiftUI
import PhotosUI

struct AddMoveView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // 1. A MORE DETAILED STATE ENUM
    enum AddMoveState {
        case ready                  // The initial state, waiting for selection.
        case loading(Progress)      // The video is being loaded, with progress.
        case loaded(URL)            // Video is loaded, ready for naming.
        case saving                 // Saving the data to Core Data.
        case success(String)        // Final success message.
        case error(String)          // An error occurred at any stage.
    }

    @State private var currentState: AddMoveState = .ready
    @State private var isPickerPresented = false
    @State private var moveName: String = ""

    var body: some View {
        ZStack {
            // 2. A SWITCH FOR THE NEW, DETAILED STATES
            switch currentState {
            case .ready:
                Button("SELECT CLIP") { isPickerPresented = true }
                    // ... (button styling is the same)
                    .font(.headline).padding().background(Color.accent).foregroundColor(.white).cornerRadius(10)

            case .loading(let progress):
                // Show a determinate progress bar.
                ProgressView("Loading...", value: progress.fractionCompleted, total: 1.0)
                    .progressViewStyle(.circular)
                    .tint(.accent)

            case .loaded(let videoURL):
                // The "Confirmation" screen.
                VStack(spacing: 20) {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 200)
                        .cornerRadius(10)

                    TextField("Enter Move Name", text: $moveName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        // Button to go back and pick a different video.
                        Button("Change Clip") {
                            currentState = .ready
                            isPickerPresented = true
                        }
                        .buttonStyle(.bordered)
                        
                        // Button to confirm and save.
                        Button("Save Move") {
                            saveMove(videoURL: videoURL, name: moveName)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()

            case .saving:
                ProgressView("Saving...")

            case .success(let message):
                Text(message).foregroundColor(.green)

            case .error(let message):
                VStack {
                    Text(message).foregroundColor(.red)
                    Button("Try Again") { currentState = .ready }
                        .padding(.top)
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoPicker(state: $currentState)
        }
        // 3. LOGIC TO RESET THE VIEW AFTER SUCCESS
        .onChange(of: currentState) { newState in
            if case .success = newState {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    currentState = .ready
                    moveName = ""
                }
            }
        }
    }
    
    // 4. THE SAVE FUNCTION IS NOW IN THE VIEW
    private func saveMove(videoURL: URL, name: String) {
        currentState = .saving
        
        let newMove = Move(context: viewContext)
        newMove.id = UUID()
        newMove.name = name.isEmpty ? "Untitled Move" : name
        newMove.createdAt = Date()
        newMove.learningState = "NEW"
        newMove.videoReference = Data(videoURL.path.utf8)

        do {
            try viewContext.save()
            currentState = .success("Move '\(newMove.name!)' saved!")
        } catch {
            currentState = .error("Database save failed.")
        }
    }
}

// 5. A REFACTORED VIDEO PICKER COORDINATOR
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var state: AddMoveView.AddMoveState

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
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

            // Start tracking progress.
            let progress = Progress(totalUnitCount: 1)
            DispatchQueue.main.async {
                self.parent.state = .loading(progress)
            }
            
            // This is how we observe the loading progress.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                // This block is called when loading is complete.
                guard let sourceURL = url else {
                    DispatchQueue.main.async {
                        self.parent.state = .error("Failed to load video file.")
                    }
                    return
                }

                // Make our own copy of the file.
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "." + sourceURL.pathExtension)
                
                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    DispatchQueue.main.async {
                        // Transition to the 'loaded' state with the new URL.
                        self.parent.state = .loaded(destinationURL)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.state = .error("Failed to copy video file.")
                    }
                }
            }
        }
    }
}

// Helper to make the states comparable for the .onChange modifier.
extension AddMoveView.AddMoveState: Equatable {
    static func == (lhs: AddMoveView.AddMoveState, rhs: AddMoveView.AddMoveState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready): return true
        case (.loading, .loading): return true
        case (.loaded(let a), .loaded(let b)): return a == b
        case (.saving, .saving): return true
        case (.success(let a), .success(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
```