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
    @Binding var selectedTab: TabSelection
    @StateObject private var viewModel = AddMoveViewModel()
    @State private var currentStep: AddMoveStep = .ready
    @State private var viewTransitionID = UUID().uuidString

    var body: some View {
        let _ = Logger.addMove.debug("🔄 AddMoveView: Body recomputed - currentStep: \(currentStep)", emoji: "🔄")

        Group {
            switch currentStep {
            case .ready:
                // Initial ready state - show SelectClip
                SelectClip(
                    selectedTab: $selectedTab,
                    viewModel: viewModel
                ) { step in
                    handleStepChange(step)
                }
                .onAppear {
                    Logger.addMove.info("📱 AddMoveView: .ready case appeared", emoji: "📱")
                }

            case .selecting:
                // Video selection - show SelectClip
                SelectClip(
                    selectedTab: $selectedTab,
                    viewModel: viewModel
                ) { step in
                    handleStepChange(step)
                }
                .onAppear {
                    Logger.addMove.info("🎬 AddMoveView: .selecting case appeared", emoji: "🎬")
                }

            case .trimming:
                // Video trimming - show MinimalTrimmerView (clean MVVM)
                let _ = Logger.addMove.info("🎯 OPENSPEC FIX: AddMoveView: About to render MinimalTrimmerView - PlayerReady: \(viewModel.videoPlayer.isReady)", emoji: "🎯")
                MinimalTrimmerView(viewModel: viewModel)
                    .id("trimmer-\(viewTransitionID)") // Force view identity
                    .onAppear {
                        Logger.addMove.info("✅ OPENSPEC FIX: AddMoveView: .trimming case appeared - MinimalTrimmerView loaded successfully", emoji: "✅")
                    }
                    .onDisappear {
                        Logger.addMove.info("❌ OPENSPEC FIX: AddMoveView: MinimalTrimmerView disappeared", emoji: "❌")
                    }

            case .naming:
                // Move naming - show NameMoveView (clean MVVM)
                NameMoveView(viewModel: viewModel)
                    .onAppear {
                        Logger.addMove.info("📝 AddMoveView: .naming case appeared", emoji: "📝")
                    }

            case .saving:
                // Saving process - show loading view
                SavingView(viewModel: viewModel) { step in
                    handleStepChange(step)
                }
                .onAppear {
                    Logger.addMove.info("💾 AddMoveView: .saving case appeared", emoji: "💾")
                }

            case .complete:
                // Process complete - navigate back to arsenal
                EmptyView() // Will be handled by parent
                    .onAppear {
                        Logger.addMove.info("🎉 AddMoveView: .complete case appeared", emoji: "🎉")
                    }
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
        .onChange(of: currentStep) { oldStep, newStep in
            Logger.addMove.info("🚨 AddMoveView: currentStep changed from \(oldStep) to \(newStep)", emoji: "🚨")
            Logger.addMove.debug("📊 AddMoveView: Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "📊")
            if newStep == .trimming {
                Logger.addMove.info("🎯 AddMoveView: CRITICAL - About to show MinimalTrimmerView", emoji: "🎯")
            }
        }
        .onChange(of: viewTransitionID) { oldID, newID in
            Logger.addMove.info("🔄 AddMoveView: viewTransitionID changed from \(oldID) to \(newID)", emoji: "🔄")
        }
    }

    // MARK: - Private Methods

    private func setupInitialState() {
        Logger.addMove.info("🌱 AddMoveView: Setting up initial state", emoji: "🌱")
        Logger.addMove.info("📊 AddMoveView: Initial viewTransitionID: \(viewTransitionID)", emoji: "📊")
        currentStep = .ready
        Logger.addMove.info("🎬 AddMoveView: Initialized with simplified architecture - currentStep: \(currentStep)", emoji: "🎬")
    }

    private func handleStepChange(_ newStep: AddMoveStep) {
        Task { @MainActor in
            let previousStep = currentStep

            // Enhanced diagnostic logging
            Logger.addMove.info("🎯 AddMoveView: handleStepChange CALLED", emoji: "🎯")
            Logger.addMove.info("📊 AddMoveView: Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "📊")
            Logger.addMove.info("🔄 AddMoveView: State transition: \(previousStep) → \(newStep)", emoji: "🔄")
            Logger.addMove.debug("AddMoveView: ViewModel state - LoadingState: \(viewModel.loadingState), PlayerReady: \(viewModel.videoPlayer.isReady)", emoji: "📊")

            // Force view recomposition when transitioning to trimming
            if newStep == .trimming {
                Logger.addMove.info("🔄 AddMoveView: Forcing view recomposition for trimming transition", emoji: "🔄")
                self.viewTransitionID = UUID().uuidString
            }

            // Update state with explicit main thread safety
            self.currentStep = newStep
            Logger.addMove.info("✅ AddMoveView: currentStep updated to: \(self.currentStep)", emoji: "✅")

            // Small delay to ensure SwiftUI processes the change
            await Task.yield()

            Logger.addMove.info("🔄 View transition: \(previousStep) → \(newStep), ID: \(self.viewTransitionID)")
        }
    }

  
    private func handleError(_ message: String) {
        Logger.addMove.error("AddMove error: \(message)", emoji: "❌")
        // If there's an error during trimming, go back to selection
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
        @State private var selectedTab: TabSelection = .ready

        var body: some View {
            AddMoveView(selectedTab: $selectedTab)
                .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}