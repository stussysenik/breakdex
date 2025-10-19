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
                        handleTrimmerAppear()
                    }
                    .onDisappear {
                        Logger.addMove.info("❌ OPENSPEC FIX: AddMoveView: MinimalTrimmerView disappeared", emoji: "❌")
                        handleTrimmerDisappear()
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
        .onChange(of: viewModel.loadingState) { oldState, newState in
            Logger.addMove.info("🔄 OPENSPEC FIX: AddMoveView: loadingState changed from \(oldState) to \(newState)", emoji: "🔄")
            Logger.addMove.debug("📊 OPENSPEC FIX: Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "📊")

            // Handle cancel button workflow: when loadingState returns to idle during trimming, transition to ready
            if newState == .idle && currentStep == .trimming {
                Logger.addMove.info("🎯 OPENSPEC FIX: Detected cancel operation - transitioning from trimming to ready", emoji: "🎯")

                // Update state on main thread
                currentStep = .ready
                viewTransitionID = UUID().uuidString

                Logger.addMove.info("✅ OPENSPEC FIX: State transition complete - currentStep: \(currentStep), viewTransitionID: \(viewTransitionID)", emoji: "✅")
            }
        }
    }

    // MARK: - Private Methods

    private func setupInitialState() {
        Logger.addMove.info("🌱 OPENSPEC PRELOAD: AddMoveView: Setting up initial state", emoji: "🌱")
        Logger.addMove.info("📊 OPENSPEC PRELOAD: AddMoveView: Initial viewTransitionID: \(viewTransitionID)", emoji: "📊")

        // Check if we can restore a suspended workflow (TabView navigation case)
        if viewModel.canRestoreWorkflow {
            Logger.addMove.info("🔄 OPENSPEC PRELOAD: AddMoveView: Suspended workflow detected - starting preloading and synchronizing view state", emoji: "🔄")

            // OPENSPEC ENHANCEMENT: Start video preloading immediately before view composition
            Task { @MainActor in
                Logger.addMove.info("⚡ OPENSPEC PRELOAD: Triggering video preloading for quick return", emoji: "⚡")

                let preloadingStartTime = Date()
                await viewModel.preloadVideoForQuickReturn()
                let preloadingDuration = Date().timeIntervalSince(preloadingStartTime)

                Logger.addMove.info("✅ OPENSPEC PRELOAD: Video preloading completed in \(String(format: "%.3f", preloadingDuration))s", emoji: "✅")

                // Enhanced coordination: Log player readiness state for view transition
                if viewModel.videoPlayer.isReady {
                    Logger.addMove.info("🎯 OPENSPEC PRELOAD: Player is ready - instantaneous video display expected", emoji: "🎯")
                } else {
                    Logger.addMove.warning("⚠️ OPENSPEC PRELOAD: Player not ready after preloading - potential display delay", emoji: "⚠️")
                }

                // Log detailed player state diagnostics
                let playerDiagnostics = viewModel.videoPlayer.playerStateDiagnostics
                Logger.addMove.info("📊 OPENSPEC PRELOAD: \(playerDiagnostics)", emoji: "📊")
            }

            // Restore the trimming state since we have a suspended workflow
            currentStep = .trimming
            Logger.addMove.info("✅ OPENSPEC PRELOAD: AddMoveView: Restored currentStep to \(currentStep) for suspended workflow", emoji: "✅")

            // Generate new transition ID for proper view recreation
            viewTransitionID = UUID().uuidString
            Logger.addMove.info("🔄 OPENSPEC PRELOAD: AddMoveView: Generated new viewTransitionID for restored workflow: \(viewTransitionID)", emoji: "🔄")

            // Log restoration details
            Logger.addMove.debug("📊 OPENSPEC PRELOAD: AddMoveView: Workflow state synchronization - ViewModel: \(viewModel.workflowStateDescription), View: \(currentStep)", emoji: "📊")
            Logger.addMove.info("🎯 OPENSPEC PRELOAD: Video preloading triggered - should prevent flashing when MinimalTrimmerView appears", emoji: "🎯")
        } else {
            // Fresh start - no suspended workflow available
            currentStep = .ready
            Logger.addMove.info("🎬 OPENSPEC PRELOAD: AddMoveView: Fresh start - no suspended workflow - currentStep: \(currentStep)", emoji: "🎬")
            Logger.addMove.debug("📊 OPENSPEC PRELOAD: AddMoveView: Workflow state - ViewModel: \(viewModel.workflowStateDescription), View: \(currentStep)", emoji: "📊")
        }
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

  
    private func handleTrimmerAppear() {
        Task { @MainActor in
            Logger.addMove.info("🔄 Trimmer appeared - checking workflow restoration")

            // Check if we can restore a suspended workflow
            if viewModel.canRestoreWorkflow {
                if viewModel.isQuickReturn {
                    Logger.addMove.info("⚡ Quick return detected (< 5s) - restoring workflow")
                    await viewModel.restoreWorkflow()
                } else {
                    Logger.addMove.info("📊 Return after delay (> 5s) - workflow available but not auto-restoring")
                    // Could add user prompt here asking if they want to restore
                }
            } else {
                Logger.addMove.info("ℹ️ No suspended workflow available")
            }
        }
    }

    private func handleTrimmerDisappear() {
        Logger.addMove.info("🔄 Trimmer disappeared - suspending workflow")
        viewModel.suspendWorkflow()
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