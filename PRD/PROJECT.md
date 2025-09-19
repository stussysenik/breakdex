Here are the specific Cursor user rules and project rules tailored for your "Add Move" feature, aligned with iOS 18.0 compliance, Single Responsibility Principle (SRP), and your preference for verbose logging and clean code:

Cursor User Rules:
- Use Swift Concurrency rigorously: all async operations must use async/await.
- Employ actors (e.g., VideoLoader) for thread-safe data fetching and resource access.
- Restrict UI state and ViewModel updates to @MainActor to prevent data races.
- Use OSLog for detailed, category-specific logging with emojis for traceability.
- Log every significant state change, function invocation, and asynchronous boundary.
- Maintain unidirectional state flow with the AddMoveState enum as the source of truth.
- Render UI in SwiftUI via a state-driven approach reflecting ViewModel state.
- Keep UI views "dumb", with no business logic; forward user actions back to the ViewModel.
- Prefer CustomVideoPlayerView (using AVPlayerLayer) for stable video playback over native SwiftUI VideoPlayer.
- Follow strict modularization and separation of concerns following the project's architecture.
- Handle video transformations non-destructively using AVFoundation via VideoTransformBuilder.
- Perform robust video loading with error handling and respect Photos permissions.
- Follow naming conventions consistent with project files and components.
  
Project Rules:
- Enforce Single Responsibility Principle across all components.
- Separate business logic fully from UI representation.
- Mark all mutable UI state and ViewModels with @MainActor.
- Follow a logging-first approach: insert logs before and after critical operations.
- Model the user workflow strictly as a state machine (AddMoveState).
- Thoroughly test video lifecycle to avoid AVFoundation crashes.
- Utilize VideoTransformBuilder to abstract away AVFoundation complexities.
- Use a SwiftUI ViewRouter pattern driven by AddMoveState for clean view switching.
- Ensure concurrency correctness via actors and main actor isolation.
- Write clean, maintainable Swift code with clear, concise structure.
- Reuse components; avoid code duplication.
- Guarantee full compatibility with iOS 18.0 APIs and best practices.
- Gracefully handle PhotosPicker and PHPhotoLibrary permissions and possible errors.
- Use a custom UIViewRepresentable for video rendering to bypass native SwiftUI VideoPlayer limitations.
- Explicitly enumerate all user interaction and UI workflow states.

correct: build command - xcodebuild -project BreakingFlashcards.xcodeproj -scheme BreakingFlashcards -destination 'platform=iOS Simulator,name=iPhone 16' build
