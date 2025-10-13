import SwiftUI
import PhotosUI
import Combine

// AddMoveView.swift - Main coordinator for Add Move flow

// MARK: - Add Move View
/// Main coordinator view for the Add Move feature
/// Handles navigation between SelectClip, TrimmerView, and other steps
struct AddMoveView: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @StateObject private var videoLoadingService = VideoLoadingService()
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Group {
            switch unifiedState.currentTab {
            case .ready:
                // Initial ready state - show SelectClip
                SelectClip(
                    selectedTab: $selectedTab,
                    unifiedState: unifiedState
                )

            case .add:
                // Video selection - show SelectClip
                SelectClip(
                    selectedTab: $selectedTab,
                    unifiedState: unifiedState
                )

            case .trimming:
                // Video trimming - show TrimmerView
                TrimmerView(unifiedState: unifiedState)

            case .naming:
                // Move naming - show NameMoveView
                NameMoveView(unifiedState: unifiedState)

            case .saving:
                // Saving process - show loading view
                SavingView(unifiedState: unifiedState)

            case .arsenal:
                // Navigate back to arsenal
                EmptyView() // Will be handled by parent
            }
        }
        .onAppear {
            setupVideoLoadingMonitoring()
        }
        .onChange(of: unifiedState.flowState) { _, newState in
            handleFlowStateChange(newState)
        }
        .onChange(of: unifiedState.hasError) { _, hasError in
            if hasError {
                handleError()
            }
        }
    }

    // MARK: - Private Methods

    private func setupVideoLoadingMonitoring() {
        // Monitor video loading progress
        videoLoadingService.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { progress in
                unifiedState.updateProgress(progress)
            }
            .store(in: &cancellables)
    }

    private func handleFlowStateChange(_ newState: AddMoveFlowState) {
        switch newState {
        case .loadingVideo:
            // Already handled by progress monitoring
            break

        case .trimming:
            // Ensure we're on the trimming tab
            if unifiedState.currentTab != .trimming {
                unifiedState.updateTab(.trimming)
            }

        case .error(let message, _):
            // Handle error state
            Logger.addMove.error("AddMove error: \(message)", emoji: "❌")

        case .success(let message):
            Logger.addMove.info("AddMove success: \(message)", emoji: "✅")

        default:
            break
        }
    }

    private func handleError() {
        // If there's an error during trimming, go back to selection
        if unifiedState.currentTab == .trimming {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                unifiedState.updateTab(.add)
            }
        }
    }
}

// MARK: - Saving View
private struct SavingView: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState

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
            if unifiedState.processingProgress > 0 {
                ProgressView(value: unifiedState.processingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.primary))
                    .frame(height: 8)
                    .padding(.horizontal, 40)

                Text("\(Int(unifiedState.processingProgress * 100))%")
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
            AddMoveView(
                selectedTab: $selectedTab,
                unifiedState: AddMoveUnifiedState()
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}