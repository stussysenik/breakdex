import SwiftUI
import PhotosUI
import Combine

// MARK: - Add Move Step
/// Simplified step enumeration for AddMove flow
enum AddMoveStep {
    case ready      // Initial ready state
    case selecting  // Selecting video from library
    case trimming   // Trimming video
    case naming     // Naming the move
    case saving     // Saving process
    case complete   // Process complete
}

// AddMoveView.swift - Main coordinator for Add Move flow
// Updated to use simplified AddMoveViewModel architecture

// MARK: - Add Move View
/// Main coordinator view for the Add Move feature
/// Uses simplified AddMoveViewModel instead of complex UnifiedState
struct AddMoveView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = AddMoveViewModel()
    @State private var currentStep: AddMoveStep = .ready
    @State private var viewTransitionID = UUID().uuidString

    var body: some View {
        Group {
            switch currentStep {
            case .ready:
                SelectClip(
                    selectedTab: $selectedTab,
                    viewModel: viewModel
                ) { step in
                    handleStepChange(step)
                }

            case .selecting:
                SelectClip(
                    selectedTab: $selectedTab,
                    viewModel: viewModel
                ) { step in
                    handleStepChange(step)
                }

            case .trimming:
                MinimalTrimmerView(viewModel: viewModel)
                    .id("trimmer-\(viewTransitionID)")
                    .onAppear { handleTrimmerAppear() }
                    .onDisappear { handleTrimmerDisappear() }

            case .naming:
                NameMoveView(viewModel: viewModel)

            case .saving:
                SavingView(viewModel: viewModel) { step in
                    handleStepChange(step)
                }

            case .complete:
                EmptyView()
            }
        }
        .id(viewTransitionID)
        .onAppear {
            setupInitialState()
        }
        .onChange(of: viewModel.errorMessage) { _, errorMessage in
            if let errorMessage = errorMessage {
                handleError(errorMessage)
            }
        }
        .onChange(of: currentStep) { _, newStep in
            Logger.addMove.debug("Step: \(newStep)")
        }
        .onChange(of: viewModel.loadingState) { _, newState in
            // Handle cancel: when loadingState returns to idle during trimming, transition to ready
            if newState == .idle && currentStep == .trimming {
                currentStep = .ready
                viewTransitionID = UUID().uuidString
            }
        }
        .onChange(of: viewModel.currentTrimModification) { _, trimModification in
            // Handle trim completion - transition from trimming to naming when trim is set
            if trimModification != nil, currentStep == .trimming {
                currentStep = .naming
                viewTransitionID = UUID().uuidString
            }
        }
        .onChange(of: viewModel.saveState) { _, saveState in
            // Handle save completion - transition from naming to ready when save succeeds
            if saveState.isSaved && currentStep == .naming {
                viewModel.resetForNextMove()
                currentStep = .ready
                viewTransitionID = UUID().uuidString
            }

            if saveState.isFailed {
                Logger.addMove.error("Save failed: \(saveState.errorMessage ?? "Unknown")")
            }
        }
    }

    // MARK: - Navigation Helper Methods

    // MARK: - Private Methods

    private func setupInitialState() {
        // Check if we can restore a suspended workflow (TabView navigation case)
        if viewModel.canRestoreWorkflow {
            Task { @MainActor in
                await viewModel.preloadVideoForQuickReturn()
            }
            currentStep = .trimming
            viewTransitionID = UUID().uuidString
        } else {
            currentStep = .ready
        }
    }

    private func handleStepChange(_ newStep: AddMoveStep) {
        Task { @MainActor in
            // Force view recomposition when transitioning to trimming
            if newStep == .trimming {
                self.viewTransitionID = UUID().uuidString
            }

            self.currentStep = newStep
            await Task.yield()
        }
    }

  
    private func handleTrimmerAppear() {
        Task { @MainActor in
            if viewModel.canRestoreWorkflow && viewModel.isQuickReturn {
                await viewModel.restoreWorkflow()
            }
        }
    }

    private func handleTrimmerDisappear() {
        viewModel.suspendWorkflow()
    }

    private func handleError(_ message: String) {
        Logger.addMove.error("Error: \(message)")
        if currentStep == .trimming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                currentStep = .selecting
            }
        }
    }
}

// MARK: - Saving View
private struct SavingView: View {
    @ObservedObject var viewModel: AddMoveViewModel
    let onStepChange: (AddMoveStep) -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Loading indicator
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: Color.primary))

            // Saving message
            Text("Saving Move...")
                .font(.ibmPlexMono(size: 18, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text("Please wait while we save your move")
                .font(.ibmPlexMono(size: 14, weight: .regular))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            // Progress bar if available
            if viewModel.progress > 0 {
                ProgressView(value: viewModel.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                    .frame(height: 8)
                    .padding(.horizontal, 40)

                Text("\(viewModel.progressPercentage)%")
                    .font(.ibmPlexMono(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: Int = 1 // Add Move tab

        var body: some View {
            AddMoveView(selectedTab: $selectedTab)
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}