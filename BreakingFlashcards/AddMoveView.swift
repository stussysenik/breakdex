// In AddMoveView.swift
import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers


struct AddMoveView: View {
    @Environment(\.managedObjectContext) private var viewContext

    enum AddMoveState: Equatable {
        case ready                                  // The initial state.
        case loading                                // Briefly shown after video selection.
        case previewing(originalURL: URL)           // User confirms the selected video.
        case naming(finalURL: URL, name: String)    // User names the trimmed/final video.
        case saving                                 // Saving move to database.
        case success(message: String)               // Successfully saved.
        case error(message: String)                 // Handles any failures.
    }

    @State private var currentState: AddMoveState = .ready
    @State private var isPickerPresented = false
    @State private var moveName: String = ""
    @State private var showTrimmer = false

    var body: some View {
        VStack {
            switch currentState {
            case .ready:
                // The initial button to start the process.
                VStack(spacing: 12) {
                    Button("Select a Clip") { 
                        isPickerPresented = true
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Supports .mp4, .mov files up to 100MB.")
                        .font(.ibmPlexMono(size: 12))
                        .foregroundColor(.secondary)
                }

            case .loading:
                // Enhanced loading indicator with motion animations
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                    
                    VStack(spacing: 8) {
                        Text("Processing Video...")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Please wait while we prepare your clip")
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: UUID())

            case .saving:
                // Enhanced saving indicator
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                    
                    VStack(spacing: 8) {
                        Text("Saving Move...")
                            .font(.ibmPlexMono(size: 18, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Adding to your arsenal...")
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: UUID())

            case .success(let message):
                // Enhanced success feedback with motion animations
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0).delay(0.2), value: message)
                    
                    Text(message)
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Another Move") { 
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentState = .ready 
                            moveName = ""
                        }
                    }
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
                    .buttonStyle(ReviewButtonStyle())
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))

            case .previewing(let originalURL):
                // The new preview and decision screen.
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Selected File:")
                            .font(.ibmPlexMono(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(originalURL.lastPathComponent)
                            .font(.ibmPlexMono(size: 16, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 8)

                    CustomVideoPlayerView(url: originalURL)
                        .cornerRadius(12)
                        .frame(height: 300)

                    HStack(spacing: 16) {
                        Button("Change Video") { 
                            isPickerPresented = true 
                        }
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button("Trim") { 
                            showTrimmer = true 
                        }
                        .font(.ibmPlexMono(size: 14, weight: .bold))
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(Color.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()

            case .naming(let finalURL, _):
                // The final naming and saving screen.
                VStack {
                    CustomVideoPlayerView(url: finalURL)
                        .cornerRadius(12)
                        .frame(height: 300)

                    TextField("Enter move name...", text: $moveName)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    Button("Save Move") { 
                        saveMove(videoURL: finalURL, name: moveName) 
                    }
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()

            case .error(let message):
                // Enhanced error feedback with motion animations
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0).delay(0.1), value: message)
                    
                    Text(message)
                        .font(.ibmPlexMono(size: 18, weight: .bold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") { 
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentState = .ready 
                            moveName = ""
                        }
                    }
                    .font(.ibmPlexMono(size: 16, weight: .bold))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(Color.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
                    .buttonStyle(ReviewButtonStyle())
                }
                .padding()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentState)
        .sheet(isPresented: $isPickerPresented, onDismiss: {
            // Only reset to ready if no video was selected (user cancelled)
            if case .ready = currentState {
                // User cancelled, stay in ready state
            }
        }) {
            VideoPickerSheet { selectedURL in
                handleVideoSelection(url: selectedURL)
            }
        }
        .sheet(isPresented: $showTrimmer) {
            if case .previewing(let originalURL) = currentState {
                VideoTrimmerView(videoURL: originalURL) { trimmedURL in
                    showTrimmer = false
                    if let finalURL = trimmedURL {
                        // After trimming, transition to the naming state.
                        currentState = .naming(finalURL: finalURL, name: "")
                    } else {
                        // If trimming is cancelled or fails, use original video
                        currentState = .naming(finalURL: originalURL, name: "")
                    }
                }
            }
        }

    }

    // This is the new logic for your VideoPickerSheet completion handler.
    // It transitions immediately to loading, then to previewing state.
    private func handleVideoSelection(url: URL) {
        // Immediately show loading state for better UX
        withAnimation(.easeInOut(duration: 0.2)) {
            currentState = .loading
        }
        
        // Validate video file
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentState = .error(message: "Selected video file could not be found.")
            }
            return
        }
        
        // Show loading for a meaningful duration to indicate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { 
            withAnimation(.easeInOut(duration: 0.3)) {
                currentState = .previewing(originalURL: url)
            }
        }
    }

    private func saveMove(videoURL: URL, name: String) {
        currentState = .saving

        let newMove = Move(context: viewContext)
        newMove.id = UUID()
        newMove.name = name.isEmpty ? "Untitled Move" : name
        newMove.createdAt = Date()
        newMove.learningState = "NEW"
        newMove.videoReference = Data(videoURL.path.utf8)

        // Simulate a brief save delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try viewContext.save()
                // Show success state
                currentState = .success(message: "Move '\(newMove.name ?? "Untitled Move")' saved successfully!")
                
                // Auto-reset to ready after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if case .success = currentState {
                        currentState = .ready
                        moveName = ""
                    }
                }
            } catch {
                currentState = .error(message: "Failed to save move. Please try again.")
            }
        }
    }
}

// Simple VideoPickerSheet that takes a completion handler
struct VideoPickerSheet: UIViewControllerRepresentable {
    let onVideoSelected: (URL) -> Void

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
        let parent: VideoPickerSheet

        init(_ parent: VideoPickerSheet) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            // If no results, user cancelled
            guard let provider = results.first?.itemProvider else {
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let sourceURL = url else {
                    DispatchQueue.main.async {
                        // Handle error case - could trigger error state in parent
                        print("Failed to load video file: \(error?.localizedDescription ?? "Unknown error")")
                    }
                    return
                }

                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsDirectory.appendingPathComponent(UUID().uuidString + "." + sourceURL.pathExtension)

                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    DispatchQueue.main.async {
                        self.parent.onVideoSelected(destinationURL)
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Failed to copy video file: \(error)")
                        // Could trigger error state in parent
                    }
                }
            }
        }
    }
}

#Preview {
    AddMoveView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
