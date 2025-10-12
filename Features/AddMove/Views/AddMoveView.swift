import SwiftUI
import OSLog

// MARK: - AddMoveView
/// Clean main container for the add move workflow
public struct AddMoveView: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState

    private let onSaveSuccess: ((Move) -> Void)?
    private let onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)?

    private let logger = Logger(
        subsystem: "com.breakingflashcards",
        category: "AddMoveView"
    )

    // MARK: - Initialization
    public init(
        selectedTab: Binding<TabSelection>,
        unifiedState: AddMoveUnifiedState,
        onSaveSuccess: ((Move) -> Void)? = nil,
        onLoadingStateChanged: ((Bool, AddMoveUnifiedState?) -> Void)? = nil
    ) {
        self._selectedTab = selectedTab
        self.unifiedState = unifiedState
        self.onSaveSuccess = onSaveSuccess
        self.onLoadingStateChanged = onLoadingStateChanged
    }

    public var body: some View {
        Group {
            switch unifiedState.flowState {
            case .loading:
                loadingView

            case .ready:
                VideoPickerView(unifiedState: unifiedState)

            case .loadingVideo:
                loadingView

            case .trimming:
                VideoTrimView(unifiedState: unifiedState)

            case .loadingTrimmedAsset(let progress):
                processingView(progress)

            case .naming:
                NameMoveView(unifiedState: unifiedState)

            case .saving:
                savingView

            case .done:
                successView(message: "Move saved successfully!")

            case .success(let message):
                successView(message: message)

            case .error(let message, let underlying):
                errorView(message: message, underlyingError: underlying)
            }
        }
        .onChange(of: unifiedState.flowState) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        .onAppear {
            logger.info("🎬 AddMoveView appeared with state: \(unifiedState.flowState)")
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Loading Video")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Please wait while we load your video...")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func processingView(_ progress: SimpleProgress) -> some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text("Processing Video")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(progress.message ?? "Processing...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("\(Int(progress.value * 100))%")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var savingView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text("Saving Move")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Please wait while we save your move...")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func successView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Success!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Done") {
                handleDone()
            }
            .font(.ibmPlexMono(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            )
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func errorView(message: String, underlyingError: String?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Error")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let underlying = underlyingError {
                    Text(underlying)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            VStack(spacing: 12) {
                Button("Retry") {
                    handleRetry()
                }
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
                .buttonStyle(PlainButtonStyle())

                Button("Cancel") {
                    handleCancel()
                }
                .font(.ibmPlexMono(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.7))
                )
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Private Methods

    private func handleStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logger.info("🔄 State changed: \(oldState) → \(newState)")

        // Notify parent about loading state changes
        let isLoading = newState.isLoading
        onLoadingStateChanged?(isLoading, unifiedState)

        // Handle successful save completion
        if case .success = newState {
            // The success view handles navigation, but we can also handle it here if needed
            logger.info("✅ Move save completed successfully")
        }
    }

    private func handleDone() {
        logger.info("✅ Done button tapped")

        // Reset the workflow
        unifiedState.reset()

        // Navigate back to Arsenal tab if callback provided
        // Note: unifiedState.currentVideoAsset is AVAsset, not Move, so create a new Move if needed
        onSaveSuccess?(Move())
    }

    private func handleRetry() {
        logger.info("🔄 Retry button tapped")

        // Reset to ready state
        unifiedState.reset()
    }

    private func handleCancel() {
        logger.info("❌ Cancel button tapped")

        // Reset and navigate back to Arsenal
        unifiedState.reset()
        selectedTab = .arsenal
    }
}


// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        private var unifiedState: AddMoveUnifiedState {
            return AddMoveUnifiedState()
        }

        var body: some View {
            AddMoveView(
                selectedTab: $selectedTab,
                unifiedState: unifiedState,
                onSaveSuccess: { savedMove in
                    print("Save success: \(savedMove.name ?? "unnamed")")
                },
                onLoadingStateChanged: { isLoading, state in
                    print("Loading state changed: \(isLoading)")
                }
            )
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}