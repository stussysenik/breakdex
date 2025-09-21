import SwiftUI
import CoreData
import AVKit
import Foundation
import Photos
import PhotosUI
import OSLog
import Combine

// MARK: - Tab Selection Enum


private let logger = Logger(subsystem: "com.breakingflashcards", category: "AddMoveContainer")

// MARK: - State-Driven Container

/// Refactored container using unified state to eliminate State Object Churn
struct AddMoveContainer: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding private var selectedTab: TabSelection
    
    // 💡 SOLUTION: Single unified state object eliminates churn
    @StateObject private var unifiedState: AddMoveUnifiedState
    
    // MARK: - Initialization
    private init(context: NSManagedObjectContext, selectedTab: Binding<TabSelection>, unifiedState: AddMoveUnifiedState) {
        logger.info("🎬 CONTAINER: AddMoveContainer initialized with unified state")
        
        _selectedTab = selectedTab
        _unifiedState = StateObject(wrappedValue: unifiedState)
        
        logger.info("🎬 CONTAINER: AddMoveContainer initialization completed")
    }
    
    init(selectedTab: Binding<TabSelection>) {
        logger.info("🎬 CONTAINER: Convenience initializer called")
        logger.info("🎬 CONTAINER: Using shared PersistenceController context")
        
        let unifiedState = AddMoveUnifiedState(
            unifiedPlayerManager: UnifiedPlayerManager(),
            appContainer: AppContainer.shared
        )
        
        self.init(
            context: PersistenceController.shared.container.viewContext,
            selectedTab: selectedTab,
            unifiedState: unifiedState
        )
    }
    
    init(viewContext: NSManagedObjectContext, selectedTab: Binding<TabSelection>) {
        let unifiedState = AddMoveUnifiedState(
            unifiedPlayerManager: UnifiedPlayerManager(),
            appContainer: AppContainer.shared
        )
        
        self.init(context: viewContext, selectedTab: selectedTab, unifiedState: unifiedState)
    }
    
    var body: some View {
        Group {
            if isValidContainerState() {
                mainContentWithModifiers
            } else {
                renderContainerFallbackUI()
            }
        }
    }
    
    private var mainContentWithModifiers: some View {
        mainContent
            .onAppear {
                handleViewAppear()
            }
            .onDisappear {
                handleViewDisappear()
            }
            .onChange(of: unifiedState.flowState) { oldState, newState in
                handleStateChange(from: oldState, to: newState)
            }
    }
    
    private func handleViewAppear() {
        logger.info("🎬 CONTAINER: View appeared with state: \(String(describing: unifiedState.flowState))")
        logState("container_appear", flowState: unifiedState.flowState)
    }
    
    private func handleViewDisappear() {
        logger.info("🎬 CONTAINER: View disappeared from state: \(String(describing: unifiedState.flowState))")
        
        // Clean up resources when workflow is finished
        let currentState = unifiedState.flowState
        let shouldCleanUp: Bool = switch currentState {
        case .success, .error:
            true
        default:
            false
        }
        
        if shouldCleanUp {
            logger.info("🎬 CONTAINER: Workflow completed, cleaning up unified state")
            unifiedState.reset()
        }
    }
    
    private func handleStateChange(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) {
        logger.info("🎬 CONTAINER: Flow state change - From: \(String(describing: oldState)) To: \(String(describing: newState))")
        
        // Validate state transitions
        if !isValidFlowStateTransition(from: oldState, to: newState) {
            logger.error("🎬 CONTAINER: ❌ INVALID FLOW STATE TRANSITION!")
            unifiedState.setError(message: "Invalid state transition detected")
        }
    }
    
    private var mainContent: some View {
        // 💡 SOLUTION: Simple switch statement eliminates complex if-case chains
        Group {
            switch unifiedState.flowState {
            case .ready:
                AddMoveSelectClipViewUnified(unifiedState: unifiedState)
                
            case .loading(let progress, let status):
                LoadingView(progress: progress, status: status)

            case .previewing:
                EmptyView() // Preview state is skipped in new flow

            case .trimming:
                FeatureRichTrimmerView(
                    unifiedState: unifiedState
                )
                
            case .naming:
                NameMoveViewUnified(unifiedState: unifiedState)
                
            case .saving:
                SavingViewWithProgress(unifiedState: unifiedState)
                
            case .success(let message):
                SuccessView(message: message) {
                    unifiedState.reset()
                }
                
            case .error(let message, _):
                ErrorView(
                    message: message,
                    onRetry: { unifiedState.clearError() },
                    onCancel: { 
                        unifiedState.reset()
                        selectedTab = .arsenal
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    private func isValidContainerState() -> Bool {
        let stateValid = isValidFlowState(unifiedState.flowState)
        let tabValid = isTabValid()
        return stateValid && tabValid
    }
    
    private func isValidFlowState(_ state: AddMoveFlowState) -> Bool {
        return true // All flow states are valid
    }
    
    private func isTabValid() -> Bool {
        return selectedTab == .add
    }
    
    private func isValidFlowStateTransition(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) -> Bool {
        // Define valid flow state transitions
        switch oldState {
        case .ready:
            if case .loading(_, _) = newState { return true }
            return false
        case .loading:
            switch newState {
            case .loading, .trimming, .error: return true // ✅ ALLOW loading -> loading for progress updates
            default: return false
            }
        case .trimming:
            switch newState {
            case .ready, .previewing, .naming, .error: return true
            default: return false
            }
        case .naming:
            switch newState {
            case .saving, .error: return true
            default: return false
            }
        case .saving:
            switch newState {
            case .success, .error: return true
            default: return false
            }
        case .success, .error:
            return newState == .ready
        default:
            return false
        }
    }
    
    private func logState(_ context: String, flowState: AddMoveFlowState) {
        let memoryInfo = ProcessInfo.processInfo
        logger.info("🎬 [\(context)] State: \(String(describing: flowState)), Mem: \(memoryInfo.physicalMemory / (1024*1024*1024))GB")
    }
    
    private func renderContainerFallbackUI() -> some View {
        VStack {
            Spacer()
            Text("Unable to load video interface")
                .font(.headline)
                .foregroundColor(.white)
            Text("Please restart the app")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Restart") {
                unifiedState.reset()
                selectedTab = .add
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Unified State Views

/// State-driven video selection view
struct AddMoveSelectClipViewUnified: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    
    var body: some View {
        VStack {
            Spacer()
            
            PhotosPicker(
                selection: Binding(
                    get: { unifiedState.selectedVideoItem },
                    set: { newItem in
                        if let newItem = newItem {
                            unifiedState.didSelectVideo(newItem)
                        }
                    }
                ),
                matching: .videos,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                Text("Select Video")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Loading view with progress indicator
struct LoadingView: View {
    let progress: Double
    let status: String
    
    var body: some View {
        VStack {
            Spacer()
            ProgressView(status)
                .progressViewStyle(.circular)
            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Enhanced saving view with progress tracking
struct SavingViewWithProgress: View {
    @ObservedObject var unifiedState: AddMoveUnifiedState
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
                
                Text("Saving Move...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if unifiedState.saveProgress > 0 {
                    ProgressView(value: unifiedState.saveProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    
                    Text("\(Int(unifiedState.saveProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Saving view
struct SavingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Saving Move...")
                .progressViewStyle(.circular)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Success view
struct SuccessView: View {
    let message: String
    let onDone: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Done") {
                onDone()
            }
            .buttonStyle(.appPrimary(size: .medium))
            .padding(.top)
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Error view
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.appPrimary(size: .medium))
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.appSecondary(size: .medium))
            }
            .padding(.top)
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    AddMoveContainer(selectedTab: .constant(.add))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .preferredColorScheme(.dark)
}