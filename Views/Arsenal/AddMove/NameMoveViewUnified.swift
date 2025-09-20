import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveViewUnified")

/// State-driven Name Move view that uses AddMoveUnifiedState
/// Eliminates direct ViewModel dependencies and State Object Churn
struct NameMoveViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    
    // MARK: - State
    @State private var moveName: String = ""
    @State private var isShowingPreview = false
    
    // MARK: - Computed Properties
    private var canSave: Bool {
        !moveName.trimmingCharacters(in: .whitespaces).isEmpty &&
        unifiedState.currentPlayerViewModel != nil
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let playerViewModel = unifiedState.currentPlayerViewModel {
                mainContent(with: playerViewModel)
            } else {
                loadingView
            }
        }
        .onAppear {
            logger.info("🎬 NAME_MOVE_UNIFIED: View appeared")
            setupInitialState()
        }
        .onDisappear {
            logger.info("🎬 NAME_MOVE_UNIFIED: View disappeared - preparing for transition")
            unifiedState.prepareForTransition()
        }
        .sheet(isPresented: $isShowingPreview) {
            if let playerViewModel = unifiedState.currentPlayerViewModel {
                PreviewSheet(
                    playerViewModel: playerViewModel,
                    startTime: unifiedState.trimStartTime,
                    endTime: unifiedState.trimEndTime,
                    onDismiss: {
                        isShowingPreview = false
                    }
                )
            }
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private func mainContent(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 0) {
            renderHeader()
            Spacer()
            
            // Video preview section
            renderVideoPreview(with: playerViewModel)
                .padding(.bottom, 20)
            
            // Name input section
            renderNameInput()
                .padding(.bottom, 20)
            
            // Action buttons
            renderActionButtons()
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }
    
    // MARK: - UI Components
    
    private func renderHeader() -> some View {
        HStack {
            Button(action: {
                handleBackButton()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Spacer()
            Text("Name Your Move")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                isShowingPreview = true
            }) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private func renderVideoPreview(with playerViewModel: UnifiedVideoPlayerViewModel) -> some View {
        VStack(spacing: 8) {
            Text("Preview")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false)
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
            
            // Trim info
            HStack {
                Text("Duration: \(formatDuration(unifiedState.trimEndTime - unifiedState.trimStartTime))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if unifiedState.rotationQuarterTurns > 0 {
                    Text("Rotation: \(unifiedState.rotationQuarterTurns * 90)°")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 4)
        }
    }
    
    private func renderNameInput() -> some View {
        VStack(spacing: 8) {
            Text("Move Name")
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            TextField("Enter move name...", text: $moveName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: moveName) { _, newValue in
                    unifiedState.moveName = newValue
                }
        }
    }
    
    private func renderActionButtons() -> some View {
        VStack(spacing: 16) {
            Button(action: {
                handleSave()
            }) {
                Text("Save Move")
                    .frame(maxWidth: 275)
            }
            .buttonStyle(.appPrimary(size: .medium))
            .disabled(!canSave)
            
            HStack(spacing: 16) {
                Button(action: {
                    handleBackButton()
                }) {
                    Text("Back")
                        .frame(maxWidth: 125)
                }
                .buttonStyle(.appSecondary(size: .medium))
                
                Button(action: {
                    handleCancel()
                }) {
                    Text("Cancel")
                        .frame(maxWidth: 125)
                }
                .buttonStyle(.appSecondary(size: .medium))
            }
        }
        .padding(.bottom, 20)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Preparing save interface...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Action Handlers
    
    private func setupInitialState() {
        // Initialize with current move name from unified state
        moveName = unifiedState.moveName
        logger.info("🎬 NAME_MOVE_UNIFIED: Initial setup completed")
    }
    
    private func handleBackButton() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Back button tapped")
        
        // Pause player
        unifiedState.currentPlayerViewModel?.avPlayer?.pause()
        
        // Return to trimming state
        unifiedState.transitionTo(.trimming)
    }
    
    private func handleCancel() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Cancel button tapped")
        
        // Show confirmation dialog
        // For now, just go back to ready state
        unifiedState.reset()
    }
    
    private func handleSave() {
        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            unifiedState.setError(message: "Please enter a move name")
            return
        }
        
        logger.info("🎬 NAME_MOVE_UNIFIED: Save button tapped for '\(moveName)'")
        
        // Transition to saving state
        unifiedState.transitionTo(.saving)
        
        // Start the save process
        Task {
            await performSave()
        }
    }
    
    private func performSave() async {
        logger.info("🎬 NAME_MOVE_UNIFIED: Starting save process")
        
        do {
            // This would be implemented with the actual save logic
            // For now, simulate a save process
            
            // Update progress
            unifiedState.saveProgress = 0.3
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            unifiedState.saveProgress = 0.7
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            unifiedState.saveProgress = 1.0
            
            // Simulate successful save
            unifiedState.transitionTo(.success(message: "Move '\(moveName)' saved successfully!"))
            
            logger.info("🎬 NAME_MOVE_UNIFIED: Save completed successfully")
            
        } catch {
            unifiedState.setError(message: "Failed to save move", underlying: error.localizedDescription)
            logger.error("🎬 NAME_MOVE_UNIFIED: Save failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview Sheet

struct PreviewSheet: View {
    let playerViewModel: UnifiedVideoPlayerViewModel
    let startTime: TimeInterval
    let endTime: TimeInterval
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Move Preview")
                    .font(.headline)
                    .padding()
                
                CustomVideoPlayerView(viewModel: playerViewModel, shouldTeardownOnDisappear: false)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding()
                
                Text("Duration: \(formatDuration(endTime - startTime))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onDisappear {
            onDismiss()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}