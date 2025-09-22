import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.breakingflashcards", category: "NameMoveViewUnified")

/// Enhanced State-driven Name Move view with asset inheritance and loading states
/// Implements seamless WYSIWYG transition from trimming with proper asset transformation
struct NameMoveViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState

    // MARK: - Enhanced State Management
    @State private var moveName: String = ""
    @State private var isShowingPreview = false
    @State private var assetTransformationProgress: Double = 0.0
    @State private var assetTransformationStatus: String = ""
    @State private var isAssetReady: Bool = false
    @State private var transformationError: String?

    // MARK: - Asset Transformation State
    private enum AssetTransformationState {
        case idle
        case transforming(progress: Double, status: String)
        case ready
        case error(String)
    }

    @State private var transformationState: AssetTransformationState = .idle

    // MARK: - Optimized Transformation Properties
    private var shouldShowTransformation: Bool {
        return !isAssetReady && unifiedState.videoAsset != nil
    }

    private var isTransformationRequired: Bool {
        return unifiedState.trimStartTime > 0 ||
               unifiedState.trimEndTime < (unifiedState.videoAsset?.duration.seconds ?? 0) ||
               unifiedState.rotationQuarterTurns > 0
    }

    @ViewBuilder
    private var mainContentView: some View {
        if let playerViewModel = unifiedState.currentPlayerViewModel {
            mainContent(with: playerViewModel)
        } else {
            errorView(message: "Player not available")
        }
    }

    @ViewBuilder
    private var optimizedTransformationView: some View {
        VStack {
            mainContentView
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(1.2)
                                Text("Preparing video...")
                                    .font(.bodySmall)
                                    .foregroundColor(.textSecondary)
                            }
                        )
                )
        }
    }

    @ViewBuilder
    private func mainContentViewWithProgress(progress: Double, status: String) -> some View {
        VStack(spacing: 0) {
            // Main content with reduced opacity during processing
            mainContentView
                .opacity(0.7)

            // Progress indicator at bottom
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color.backgroundPrimary)
        }
    }

    // MARK: - Computed Properties
    private var canSave: Bool {
        !moveName.trimmingCharacters(in: .whitespaces).isEmpty &&
        unifiedState.currentPlayerViewModel != nil &&
        isAssetReady &&
        transformationError == nil
    }

    private var isTransformingAsset: Bool {
        switch transformationState {
        case .transforming:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Enhanced Body with Asset Transformation States
    var body: some View {
        Group {
            switch transformationState {
            case .idle:
                // Skip idle state and start transformation immediately if needed
                if shouldShowTransformation {
                    optimizedTransformationView
                } else {
                    mainContentView
                }

            case .transforming(let progress, let status):
                // Show transformation only when absolutely necessary
                if isTransformationRequired {
                    assetTransformationView(progress: progress, status: status)
                } else {
                    // Show main content with progress indicator
                    mainContentViewWithProgress(progress: progress, status: status)
                }

            case .ready:
                mainContentView

            case .error(let errorMessage):
                errorView(message: errorMessage)
            }
        }
        .onAppear {
            logger.info("🎬 NAME_MOVE_UNIFIED: View appeared")
            setupInitialState()
            optimizeAssetTransformation()
        }
        .onDisappear {
            logger.info("🎬 NAME_MOVE_UNIFIED: View disappeared - preparing for transition")
            cleanupAssetTransformation()
            unifiedState.prepareForTransition()
        }
        .sheet(isPresented: $isShowingPreview) {
            if let playerViewModel = unifiedState.currentPlayerViewModel, isAssetReady {
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
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                Text("Preparing save interface...")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func assetTransformationView(progress: Double, status: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)

                    Text("Transforming Asset")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("\(Int(progress * 100))%")
                        .font(.ibmPlexMono(size: 14, weight: .medium))
                        .foregroundColor(.accent)
                }
                .padding()
            }
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func errorView(message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.buttonHard)

                Text("Asset Transformation Failed")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button("Retry") {
                        startAssetTransformation()
                    }
                    .buttonStyle(.appPrimary(size: .medium))

                    Button("Back") {
                        handleBackButton()
                    }
                    .buttonStyle(.appSecondary(size: .medium))
                }
                .padding(.top)
            }
            .padding()
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Asset Transformation Methods

    private func optimizeAssetTransformation() {
        logger.info("🔄 NAME_MOVE_UNIFIED: Optimizing asset transformation")

        // Check if transformation is even needed
        guard unifiedState.videoAsset != nil else {
            let error = "No video asset available for transformation"
            logger.error("❌ NAME_MOVE_UNIFIED: \(error)")
            transformationError = error
            transformationState = .error(error)
            return
        }

        // Skip transformation if not required and asset is ready
        if !isTransformationRequired && isAssetReady {
            logger.info("✅ NAME_MOVE_UNIFIED: No transformation required, asset ready")
            transformationState = .ready
            return
        }

        // Start transformation only when necessary
        if isTransformationRequired || !isAssetReady {
            transformationState = .transforming(progress: 0.0, status: "Preparing video...")
            transformationError = nil
            Task {
                await performOptimizedAssetTransformation()
            }
        } else {
            transformationState = .ready
        }
    }

    private func startAssetTransformation() {
        // Legacy method - delegates to optimized version
        optimizeAssetTransformation()
    }

    private func performOptimizedAssetTransformation() async {
        logger.info("🔄 NAME_MOVE_UNIFIED: Performing optimized asset transformation")

        do {
            // Early validation with better progress feedback
            await updateTransformationProgress(0.05, status: "Quick validation...")

            // Fast validation - skip if transformation not required
            if isTransformationRequired {
                guard unifiedState.trimStartTime < unifiedState.trimEndTime else {
                    throw NSError(domain: "NameMoveView", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid trim range: start time must be before end time"
                    ])
                }

                guard (unifiedState.trimEndTime - unifiedState.trimStartTime) >= 3.0 else {
                    throw NSError(domain: "NameMoveView", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "Trim duration must be at least 3 seconds"
                    ])
                }
            }

            // Quick progress update
            await updateTransformationProgress(0.1, status: "Preparing asset...")

            // Only apply transformation if needed
            if isTransformationRequired {
                await updateTransformationProgress(0.3, status: "Applying trim settings...")

                // Apply trim settings to the current player
                try await unifiedState.applyTrimSettings(
                    startTime: unifiedState.trimStartTime,
                    endTime: unifiedState.trimEndTime,
                    rotation: unifiedState.rotationQuarterTurns
                )

                await updateTransformationProgress(0.6, status: "Finalizing transformation...")
            } else {
                await updateTransformationProgress(0.5, status: "Asset ready...")
            }

            // Verify the transformation was successful
            guard let playerViewModel = unifiedState.currentPlayerViewModel,
                  playerViewModel.isPlayerReady else {
                throw NSError(domain: "NameMoveView", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to prepare transformed asset"
                ])
            }

            // Final progress update
            await updateTransformationProgress(0.9, status: "Almost ready...")

            // Success!
            await MainActor.run {
                isAssetReady = true
                transformationState = .ready
                moveName = unifiedState.moveName
            }

            logger.info("✅ NAME_MOVE_UNIFIED: Optimized asset transformation completed successfully")

        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                transformationError = errorMessage
                transformationState = .error(errorMessage)
                isAssetReady = false
            }

            logger.error("❌ NAME_MOVE_UNIFIED: Asset transformation failed: \(error.localizedDescription)")
        }
    }

    private func updateTransformationProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            assetTransformationProgress = progress
            assetTransformationStatus = status

            if case .transforming = transformationState {
                transformationState = .transforming(progress: progress, status: status)
            }
        }
    }

    private func cleanupAssetTransformation() {
        logger.info("🧹 NAME_MOVE_UNIFIED: Cleaning up asset transformation")

        Task {
            await MainActor.run {
                isAssetReady = false
                transformationError = nil
                transformationState = .idle
                assetTransformationProgress = 0.0
                assetTransformationStatus = ""
            }
        }
    }

    // MARK: - Action Handlers

    private func setupInitialState() {
        // Initialize with current move name from unified state
        moveName = unifiedState.moveName
        logger.info("🎬 NAME_MOVE_UNIFIED: Initial setup completed")

        // Log asset transformation status
        logger.info("🎬 NAME_MOVE_UNIFIED: Asset transformation state - is_asset_ready: \(isAssetReady), transformation_state: \(String(describing: transformationState)), has_error: \(transformationError != nil), player_available: \(unifiedState.currentPlayerViewModel != nil)")
    }
    
    private func handleBackButton() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Back button tapped")
        
        // Pause player
        unifiedState.currentPlayerViewModel?.avPlayer?.pause()
        
        // Return to trimming state
        Task {
            await unifiedState.transitionTo(.trimming)
        }
    }
    
    private func handleCancel() {
        logger.info("🎬 NAME_MOVE_UNIFIED: Cancel button tapped")

        // Show confirmation dialog
        // For now, just go back to ready state
        Task {
            await unifiedState.reset()
        }
    }
    
    private func handleSave() {
        guard !moveName.trimmingCharacters(in: .whitespaces).isEmpty else {
            Task {
                await unifiedState.setError(message: "Please enter a move name")
            }
            return
        }

        logger.info("🎬 NAME_MOVE_UNIFIED: Save button tapped for '\(moveName)'")

        // Transition to saving state
        Task {
            await unifiedState.transitionTo(.saving)
        }

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
            await unifiedState.transitionTo(.success(message: "Move '\(moveName)' saved successfully!"))
            
            logger.info("🎬 NAME_MOVE_UNIFIED: Save completed successfully")
            
        } catch {
            await unifiedState.setError(message: "Failed to save move", underlying: error.localizedDescription)
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