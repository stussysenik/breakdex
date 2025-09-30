import SwiftUI
import OSLog
import CoreData
import Combine

// MARK: - Navigation Coordinator
/// Centralized navigation state coordinator using category theory principles
/// Manages navigation flow with proper functor compositions and natural transformations
@MainActor
final class NavigationCoordinator: ObservableObject {

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "NavigationCoordinator")

    // MARK: - Published Navigation State
    @Published public private(set) var currentNavigationState: NavigationState = .idle
    @Published public private(set) var pendingNavigation: PendingNavigation?

    // MARK: - Navigation Queue
    private var navigationQueue: [PendingNavigation] = []
    private var isProcessingNavigation: Bool = false

    // MARK: - Navigation Dependencies
    private unowned let appContainer: AppContainer
    private unowned let persistentContainer: NSPersistentContainer

    // MARK: - Initialization
    init(appContainer: AppContainer, persistentContainer: NSPersistentContainer) {
        self.appContainer = appContainer
        self.persistentContainer = persistentContainer

        logger.info("🧭 NAV_COORD: 🚀 Navigation coordinator initialized")
        logCurrentState("initialization")

        // Setup navigation state monitoring
        setupNavigationMonitoring()
    }

    // MARK: - Navigation State Types

    public enum NavigationState: Equatable, Sendable {
        case idle
        case navigating(from: String, to: String)
        case transitioning(step: String)
        case completed(destination: String)
        case error(message: String)
    }

    public struct PendingNavigation: Identifiable, Sendable {
        let id = UUID()
        let source: String
        let destination: String
        let move: Move?
        let timestamp: Date
        let completion: (() -> Void)?

        init(source: String, destination: String, move: Move? = nil, completion: (() -> Void)? = nil) {
            self.source = source
            self.destination = destination
            self.move = move
            self.timestamp = Date()
            self.completion = completion
        }
    }

    // MARK: - Public Interface

    /// Queue navigation request with automatic state management
    /// - Parameters:
    ///   - source: Source view identifier
    ///   - destination: Destination view identifier
    ///   - move: Optional Move entity for navigation payload
    ///   - completion: Optional completion callback
    public func queueNavigation(
        from source: String,
        to destination: String,
        move: Move? = nil,
        completion: (() -> Void)? = nil
    ) {
        logger.info("🧭 NAV_COORD: 📤 Queueing navigation: \(source) → \(destination)")

        let navigation = PendingNavigation(
            source: source,
            destination: destination,
            move: move,
            completion: completion
        )

        // 🎯 CATEGORY THEORY: Natural transformation from request queue to execution
        navigationQueue.append(navigation)

        logCurrentState("queue_navigation")

        // Process queue if not already processing
        if !isProcessingNavigation {
            Task {
                await processNavigationQueue()
            }
        }
    }

    /// Execute immediate navigation with state validation
    /// - Parameters:
    ///   - destination: Destination view identifier
    ///   - move: Optional Move entity for navigation payload
    ///   - completion: Optional completion callback
    public func executeNavigation(
        to destination: String,
        move: Move? = nil,
        completion: (() -> Void)? = nil
    ) {
        logger.info("🧭 NAV_COORD: ⚡ Executing immediate navigation to: \(destination)")

        // Validate navigation state
        guard validateNavigationState() else {
            logger.error("🧭 NAV_COORD: ❌ Navigation state validation failed")
            currentNavigationState = .error(message: "Navigation state validation failed")
            return
        }

        // Create pending navigation
        let navigation = PendingNavigation(
            source: "immediate",
            destination: destination,
            move: move,
            completion: completion
        )

        // Execute navigation with comprehensive logging
        executeNavigationWithStateTracking(navigation)
    }

    /// Complete current navigation and reset state
    public func completeNavigation() {
        logger.info("🧭 NAV_COORD: ✅ Completing navigation")

        if let current = pendingNavigation {
            logger.info("🧭 NAV_COORD: 🎯 Navigation completed: \(current.source) → \(current.destination)")
            current.completion?()
        }

        // Reset navigation state
        pendingNavigation = nil
        currentNavigationState = .idle

        logCurrentState("navigation_completed")

        // Process any queued navigation
        Task {
            await processNavigationQueue()
        }
    }

    /// Clear all pending navigation and reset to idle state
    public func resetNavigation() {
        logger.info("🧭 NAV_COORD: 🔄 Resetting navigation state")

        navigationQueue.removeAll()
        pendingNavigation = nil
        currentNavigationState = .idle
        isProcessingNavigation = false

        logCurrentState("navigation_reset")
    }

    // MARK: - Private Implementation

    private func setupNavigationMonitoring() {
        logger.info("🧭 NAV_COORD: 📡 Setting up navigation state monitoring")

        // Monitor navigation state changes for debugging
        $currentNavigationState
            .sink { [weak self] newState in
                self?.logger.info("🧭 NAV_COORD: 📊 Navigation state changed: \(String(describing: newState))")
            }
            .store(in: &cancellables)

        // Monitor pending navigation changes
        $pendingNavigation
            .sink { [weak self] navigation in
                if let nav = navigation {
                    self?.logger.info("🧭 NAV_COORD: 📍 Pending navigation: \(nav.source) → \(nav.destination)")
                }
            }
            .store(in: &cancellables)
    }

    // Combine subscription storage
    private var cancellables = Set<AnyCancellable>()

    private func processNavigationQueue() async {
        logger.info("🧭 NAV_COORD: 🔄 Processing navigation queue (count: \(self.navigationQueue.count))")

        isProcessingNavigation = true

        while !navigationQueue.isEmpty {
            let navigation = navigationQueue.removeFirst()

            logger.info("🧭 NAV_COORD: 🎯 Processing queued navigation: \(navigation.source) → \(navigation.destination)")

            // Validate navigation before execution
            guard validateNavigationRequest(navigation) else {
                logger.warning("🧭 NAV_COORD: ⚠️ Navigation request validation failed, skipping")
                continue
            }

            // Execute navigation with state tracking
            executeNavigationWithStateTracking(navigation)

            // Small delay between navigations to prevent overwhelming the UI
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        isProcessingNavigation = false
        logger.info("🧭 NAV_COORD: ✅ Navigation queue processing completed")
    }

    private func executeNavigationWithStateTracking(_ navigation: PendingNavigation) {
        logger.info("🧭 NAV_COORD: 🚀 Executing navigation: \(navigation.source) → \(navigation.destination)")

        // Update navigation state
        currentNavigationState = .navigating(from: navigation.source, to: navigation.destination)
        pendingNavigation = navigation

        logCurrentState("navigation_execution")

        // 🎯 CATEGORY THEORY: Functor composition - navigation morphism execution
        // This represents the morphism from source to destination in our navigation category
        Task {
            await performNavigationTransition(navigation)
        }
    }

    private func performNavigationTransition(_ navigation: PendingNavigation) async {
        logger.info("🧭 NAV_COORD: 🔄 Performing navigation transition")

        // Update to transitioning state
        currentNavigationState = .transitioning(step: "executing_navigation")

        // Simulate navigation transition timing
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second

        // Mark navigation as completed
        currentNavigationState = .completed(destination: navigation.destination)

        logger.info("🧭 NAV_COORD: ✅ Navigation transition completed: \(navigation.destination)")
        logCurrentState("navigation_transition_complete")
    }

    private func validateNavigationState() -> Bool {
        logger.info("🧭 NAV_COORD: 🔍 Validating navigation state")

        // Check if already processing navigation
        if isProcessingNavigation {
            logger.warning("🧭 NAV_COORD: ⚠️ Already processing navigation")
            return false
        }

        // Check if there's an active navigation
        if pendingNavigation != nil {
            logger.warning("🧭 NAV_COORD: ⚠️ Active navigation in progress")
            return false
        }

        logger.info("🧭 NAV_COORD: ✅ Navigation state validation passed")
        return true
    }

    private func validateNavigationRequest(_ navigation: PendingNavigation) -> Bool {
        logger.info("🧭 NAV_COORD: 🔍 Validating navigation request: \(navigation.source) → \(navigation.destination)")

        // Validate source and destination
        guard !navigation.source.isEmpty && !navigation.destination.isEmpty else {
            logger.error("🧭 NAV_COORD: ❌ Invalid navigation: empty source or destination")
            return false
        }

        // Validate timestamp (should be recent)
        let maxAge: TimeInterval = 30.0 // 30 seconds
        if Date().timeIntervalSince(navigation.timestamp) > maxAge {
            logger.warning("🧭 NAV_COORD: ⚠️ Navigation request expired (age: \(Date().timeIntervalSince(navigation.timestamp))s)")
            return false
        }

        logger.info("🧭 NAV_COORD: ✅ Navigation request validation passed")
        return true
    }

    private func logCurrentState(_ context: String) {
        logger.info("🧭 NAV_COORD: 📊 [\(context)] State: \(String(describing: self.currentNavigationState)), Queue: \(self.navigationQueue.count), Processing: \(self.isProcessingNavigation)")
    }
}

// MARK: - SwiftUI Integration

extension NavigationCoordinator {
    /// SwiftUI-compatible binding for navigation state
    var navigationBinding: Binding<Bool> {
        Binding(
            get: {
                switch self.currentNavigationState {
                case .navigating, .transitioning:
                    return true
                default:
                    return false
                }
            },
            set: { isNavigating in
                if !isNavigating {
                    self.completeNavigation()
                }
            }
        )
    }

    /// Current pending move for navigation
    var pendingMove: Move? {
        return pendingNavigation?.move
    }
}

// MARK: - Category Theory Extensions

extension NavigationCoordinator {
    /// Natural transformation from navigation state to UI state
    /// This maps our internal navigation category to the SwiftUI presentation category
    private func naturalTransformToUIState(_ navigationState: NavigationState) -> NavigationUIState {
        logger.info("🧭 NAV_COORD: 🔄 Natural transformation: NavigationState → NavigationUIState")

        switch navigationState {
        case .idle:
            return .hidden
        case .navigating, .transitioning:
            return .presenting
        case .completed:
            return .presented
        case .error:
            return .error
        }
    }

    /// Universal property for navigation functor
    /// Ensures all navigation paths maintain consistent state transitions
    private func verifyUniversalProperty(_ navigation: PendingNavigation) -> Bool {
        logger.info("🧭 NAV_COORD: 🔍 Verifying universal property for navigation functor")

        // Verify navigation morphism is well-defined
        let sourceValid = !navigation.source.isEmpty
        let destinationValid = !navigation.destination.isEmpty
        let timestampValid = navigation.timestamp <= Date()

        let isValid = sourceValid && destinationValid && timestampValid

        if isValid {
            logger.info("🧭 NAV_COORD: ✅ Universal property verified - navigation functor is well-defined")
        } else {
            logger.error("🧭 NAV_COORD: ❌ Universal property violation - navigation functor is not well-defined")
        }

        return isValid
    }

    /// Navigation UI state for SwiftUI integration
    public enum NavigationUIState {
        case hidden
        case presenting
        case presented
        case error
    }
}