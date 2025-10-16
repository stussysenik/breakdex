import SwiftUI
import PhotosUI

// SelectClip.swift - "select a clip" UI

// MARK: - SelectClip
/// Enhanced view for selecting a clip with loading feedback
struct SelectClip: View {
    @Binding var selectedTab: TabSelection
    @ObservedObject var unifiedState: AddMoveUnifiedState
    @State private var showPhotosPicker = false
    @State private var tempSelection: PhotosUI.PhotosPickerItem?

    var body: some View {
        ZStack {
            // Main content
            VStack {
                Spacer()

                // Show loading state or selection button
                if unifiedState.flowState.isLoading {
                    loadingView
                } else {
                    Button("Select a Clip") {
                        // Show Photos picker for video selection
                        showPhotosPicker = true
                    }
                    .buttonStyle(SelectClipButtonStyle())
                }

                Spacer()
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $tempSelection,
                matching: .videos,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: tempSelection) { _, newItem in
                handleVideoSelection(newItem)
            }
            .disabled(unifiedState.flowState.isLoading) // Disable interaction during loading

            // Error overlay
            if unifiedState.hasError {
                errorOverlay
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        SimpleLoadingView(
            state: unifiedState.loadingProgress.state,
            progress: unifiedState.loadingProgress,
            retryAction: nil // No retry action in SelectClip loading state
        )
    }

    // MARK: - Error Overlay
    private var errorOverlay: some View {
        SimpleLoadingView(
            state: .error(error: VideoLoadingError.dataUnavailable, retryAvailable: true),
            progress: nil,
            retryAction: {
                retryLastVideoSelection()
            }
        )
        .overlay(
            // Additional action buttons
            VStack(spacing: 12) {
                Button("Select Different Video") {
                    unifiedState.clearError()
                    tempSelection = nil
                    showPhotosPicker = true
                }
                .buttonStyle(.appSecondary())
            }
            .padding(.bottom, 20),
            alignment: .bottom
        )
    }

    // MARK: - Private Methods

    private func retryLastVideoSelection() {
        unifiedState.clearError()
        unifiedState.updateTab(.ready)
        // Retry logic would go here if we stored the last selection
        // For now, we just clear the error and return to ready state
    }

    private func handleVideoSelection(_ item: PhotosUI.PhotosPickerItem?) {
        guard let newItem = item else { return }

        unifiedState.clearError()
        tempSelection = nil

        Task {
            await unifiedState.loadVideo(from: newItem)
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabSelection = .add

        var body: some View {
            SelectClip(
                selectedTab: $selectedTab,
                unifiedState: AddMoveUnifiedState()
            )
            .preferredColorScheme(.dark)
        }
    }

    return PreviewWrapper()
}