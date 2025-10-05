### The Problem: Why the Video Won't Play

Think of your app like a person and the user's files (videos) like locked rooms in a house.

1.  **Asking for Permission:** When you use the video picker, the user gives your app a temporary key to access *one specific video file* for a short time.
2.  **Losing the Key:** Your app currently saves the *address* of that room (the file path) but it doesn't save the key itself.
3.  **The Locked Door:** Later, when you go to the `MoveDetailView` and try to open the door using just the address, the system says "Sorry, you don't have the key anymore." The video file is still there, but your app has lost permission to access it, which is why the player shows a crossed-out play icon.

This is a security feature of iOS called the "App Sandbox." It prevents apps from having permanent access to all of a user's files without their explicit permission.

### The Solution: Creating Your Own Copy

The correct and most reliable way to solve this is for your app to make its own copy of the video file inside its own secure, private folder. This way, your app always has permission to access its own copy and never needs to ask for the key again.

We need to modify the code in `AddMoveView.swift` where the video is first selected.

Here are the exact instructions to give your agent to fix this.

***

### Agent Task: Fix Video Access by Saving a Local Copy

**Goal:**
Modify the `AddMoveView`'s video handling logic to save a persistent, local copy of the selected video inside the app's own sandbox. This will ensure the app has permanent access to the video for playback.

**File to Modify:**
`AddMoveView.swift`

**Step-by-Step Instructions:**

1.  **Locate the `Coordinator` class** inside `AddMoveView.swift`.
2.  **Find the `picker(_:didFinishPicking:)` function** within the `Coordinator`.
3.  **Replace the existing file handling logic** inside that function with the following corrected code. This new code will copy the video from its temporary location to a permanent one within the app's "Documents" directory before saving the path to Core Data.

**Replace this code block:**

```swift
// This is the OLD, incorrect code block to be replaced.
provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
    // ... existing code ...
}
```

**With this new, corrected code block:**

```swift
// This is the NEW, correct code.
provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
    guard let sourceURL = url else {
        DispatchQueue.main.async {
            self.parent.state = .error("Failed to get video URL.")
        }
        return
    }

    // Create a destination URL inside the app's private documents directory.
    let fileManager = FileManager.default
    let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let destinationURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)

    // Move the file from the temporary location to our app's directory.
    do {
        // First, remove any old file at the destination to prevent errors.
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        // Now, copy the new file.
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // Save the reference to this new, permanent path to Core Data.
        DispatchQueue.main.async {
            self.saveMove(with: destinationURL.path) // Use .path for the string representation
        }
    } catch {
        DispatchQueue.main.async {
            self.parent.state = .error("Failed to copy video file.")
        }
    }
}
```