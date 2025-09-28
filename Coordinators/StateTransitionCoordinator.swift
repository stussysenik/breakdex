//
//  StateTransitionCoordinator.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/28/25.
//

import Foundation
import OSLog

/// Coordinator responsible for managing state transitions and validation
/// Extracted from AddMoveUnifiedState to follow Single Responsibility Principle
@MainActor
public class StateTransitionCoordinator {

    // MARK: - Properties

    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🔄 STATE_COORDINATOR")
    private let diagnosticLogger: DiagnosticLoggingHelper

    // Workflow tracking
    private var workflowCorrelationId: String?

    // MARK: - Callbacks

    /// Callback for successful state transitions
    public var onStateTransition: ((AddMoveFlowState, AddMoveFlowState, String) -> Void)?
    /// Callback for invalid transitions
    public var onInvalidTransition: ((AddMoveFlowState, AddMoveFlowState, String) -> Void)?
    /// Callback for logging diagnostics
    public var onLogDiagnostic: ((String, [String: String]) -> Void)?
    /// Callback for timing operations
    public var onStartTiming: ((String) -> Void)?
    public var onStopTiming: ((String) -> Void)?

    // MARK: - Initialization

    public init(diagnosticLogger: DiagnosticLoggingHelper) {
        self.diagnosticLogger = diagnosticLogger
        logger.info("🔄 STATE_COORDINATOR: ✅ Coordinator initialized")
    }

    // MARK: - Public Methods

    /// Centralized state transition method with comprehensive logging and trigger context
    public func transition(
        from currentState: AddMoveFlowState,
        to newState: AddMoveFlowState,
        triggeredBy trigger: String
    ) async -> Bool {
        // Skip if already in target state
        guard currentState != newState else {
            logStateTransitionSkipped(currentState: currentState, targetState: newState, trigger: trigger)
            return false
        }

        // Validate transition
        guard isValidStateTransition(from: currentState, to: newState) else {
            logInvalidTransition(currentState: currentState, targetState: newState, trigger: trigger)
            onInvalidTransition?(currentState, newState, trigger)
            return false
        }

        // Execute transition
        await executeStateTransition(from: currentState, to: newState, triggeredBy: trigger)
        return true
    }

    /// Validates if a state transition is allowed
    public func isValidStateTransition(from oldState: AddMoveFlowState, to newState: AddMoveFlowState) -> Bool {
        let oldStateBase = getStateBase(oldState)
        let newStateBase = getStateBase(newState)

        guard let allowedTransitions = validTransitions[oldStateBase] else {
            logger.warning("🔄 STATE_COORDINATOR: ⚠️ No transitions defined for state: \(oldStateBase)")
            return false
        }

        let isValid = allowedTransitions.contains(newStateBase)

        if !isValid {
            logger.warning("🔄 STATE_COORDINATOR: ❌ Invalid transition from \(oldStateBase) to \(newStateBase)")
        }

        return isValid
    }

    /// Gets allowed transitions from a given state
    public func allowedTransitions(from state: AddMoveFlowState) -> [String] {
        let stateBase = getStateBase(state)
        return validTransitions[stateBase] ?? []
    }

    /// Resets workflow correlation
    public func resetWorkflow() {
        workflowCorrelationId = nil
        logger.info("🔄 STATE_COORDINATOR: 🔄 Workflow correlation reset")
    }

    // MARK: - Private Methods

    private func executeStateTransition(
        from oldState: AddMoveFlowState,
        to newState: AddMoveFlowState,
        triggeredBy trigger: String
    ) async {
        let correlationId = generateCorrelationId()
        let memoryBefore = String(format: "%.1fMB", diagnosticLogger.getMemoryInfo().used)

        // Setup workflow correlation if needed
        setupWorkflowCorrelationIfNeeded(correlationId: correlationId, oldState: oldState, newState: newState, trigger: trigger)

        // Start timing
        startStateTiming(newState: newState)

        // Log transition details
        logStateTransitionStart(
            oldState: oldState,
            newState: newState,
            trigger: trigger,
            correlationId: correlationId,
            memoryBefore: memoryBefore
        )

        // Notify callback
        onStateTransition?(oldState, newState, trigger)

        // Log completion
        logStateTransitionComplete(
            oldState: oldState,
            newState: newState,
            correlationId: correlationId
        )

        // Stop timing
        stopStateTiming(newState: newState)
    }

    private func setupWorkflowCorrelationIfNeeded(
        correlationId: String,
        oldState: AddMoveFlowState,
        newState: AddMoveFlowState,
        trigger: String
    ) {
        if workflowCorrelationId == nil {
            workflowCorrelationId = correlationId

            let metadata = [
                "correlation_id": correlationId,
                "initial_state": "\(String(describing: oldState))",
                "target_state": "\(String(describing: newState))",
                "trigger": trigger
            ]

            onLogDiagnostic?("🎯 NEW_WORKFLOW: Starting new add move workflow", metadata)
            logger.info("🔄 STATE_COORDINATOR: 🎯 New workflow started | correlationId: \(correlationId)")
        }
    }

    private func startStateTiming(newState: AddMoveFlowState) {
        let timingKey = "state_transition_\(String(describing: newState).lowercased())"
        onStartTiming?(timingKey)
    }

    private func stopStateTiming(newState: AddMoveFlowState) {
        let timingKey = "state_transition_\(String(describing: newState).lowercased())"
        onStopTiming?(timingKey)
    }

    private func generateCorrelationId() -> String {
        return UUID().uuidString
    }

    // MARK: - Logging Methods

    private func logStateTransitionSkipped(
        currentState: AddMoveFlowState,
        targetState: AddMoveFlowState,
        trigger: String
    ) {
        let metadata = [
            "current_state": "\(String(describing: currentState))",
            "target_state": "\(String(describing: targetState))",
            "trigger": trigger
        ]

        onLogDiagnostic?("State transition skipped - already in target state", metadata)
        logger.debug("🔄 STATE_COORDINATOR: ⏭️ State transition skipped | already in target state")
    }

    private func logInvalidTransition(
        currentState: AddMoveFlowState,
        targetState: AddMoveFlowState,
        trigger: String
    ) {
        let metadata = [
            "current_state": "\(String(describing: currentState))",
            "target_state": "\(String(describing: targetState))",
            "trigger": trigger,
            "allowed_transitions": "\(allowedTransitions(from: currentState))"
        ]

        onLogDiagnostic?("Invalid state transition attempted", metadata)
        logger.error("🔄 STATE_COORDINATOR: ❌ Invalid transition | \(String(describing: currentState)) -> \(String(describing: targetState))")
    }

    private func logStateTransitionStart(
        oldState: AddMoveFlowState,
        newState: AddMoveFlowState,
        trigger: String,
        correlationId: String,
        memoryBefore: String
    ) {
        let metadata = [
            "correlation_id": correlationId,
            "previous_state": "\(String(describing: oldState))",
            "new_state": "\(String(describing: newState))",
            "trigger": trigger,
            "memory_before": memoryBefore,
            "transition_type": "user_initiated"
        ]

        onLogDiagnostic?("State transition started", metadata)
        logger.info("🔄 STATE_COORDINATOR: 🚀 Transitioning | \(String(describing: oldState)) -> \(String(describing: newState))")
    }

    private func logStateTransitionComplete(
        oldState: AddMoveFlowState,
        newState: AddMoveFlowState,
        correlationId: String
    ) {
        let memoryAfter = diagnosticLogger.getMemoryInfo()
        let metadata: [String: String] = [
            "correlation_id": correlationId,
            "previous_state": "\(String(describing: oldState))",
            "current_state": "\(String(describing: newState))",
            "memory_after": String(format: "%.1fMB", memoryAfter.used),
            "workflow_correlation_id": workflowCorrelationId ?? "unknown"
        ]

        onLogDiagnostic?("State transition completed", metadata)
        logger.info("🔄 STATE_COORDINATOR: ✅ Transition completed | correlationId: \(correlationId)")
    }

    // MARK: - State Mapping

    private func getStateBase(_ state: AddMoveFlowState) -> String {
        switch state {
        case .ready: return "ready"
        case .loading: return "loading"
        case .replacingVideo: return "replacing_video"
        case .previewing: return "previewing"
        case .trimming_setup: return "trimming_setup"
        case .trimming: return "trimming"
        case .finalizing: return "finalizing"
        case .naming: return "naming"
        case .saving: return "saving"
        case .success: return "success"
        case .error: return "error"
        }
    }

    // MARK: - Valid Transitions

    private var validTransitions: [String: [String]] {
        return [
            "ready": ["loading", "error"],
            "loading": ["loading", "trimming_setup", "error"],
            "trimming_setup": ["trimming", "error"],
            "trimming": ["finalizing", "naming", "replacing_video", "error"],
            "replacing_video": ["loading", "error"],
            "finalizing": ["naming", "error"],
            "naming": ["saving", "error"],
            "saving": ["success", "error"],
            "success": ["ready"],
            "error": ["ready"]
        ]
    }

    // MARK: - Cleanup

    deinit {
        logger.info("🔄 STATE_COORDINATOR: 🧹 Coordinator deallocating")
        // Inline resetWorkflow() to avoid main actor isolation issues in deinit
        workflowCorrelationId = nil
    }
}

// MARK: - State Transition Configuration

/// Configuration for state transition behavior
public struct StateTransitionConfiguration {
    public let enableLogging: Bool
    public let enablePerformanceTracking: Bool
    public let enableWorkflowCorrelation: Bool

    public init(
        enableLogging: Bool = true,
        enablePerformanceTracking: Bool = true,
        enableWorkflowCorrelation: Bool = true
    ) {
        self.enableLogging = enableLogging
        self.enablePerformanceTracking = enablePerformanceTracking
        self.enableWorkflowCorrelation = enableWorkflowCorrelation
    }
}

// MARK: - State Transition Event

/// Represents a state transition event for analytics and debugging
public struct StateTransitionEvent {
    public let correlationId: String
    public let workflowCorrelationId: String?
    public let fromState: AddMoveFlowState
    public let toState: AddMoveFlowState
    public let trigger: String
    public let timestamp: Date
    public let memoryBefore: String
    public let memoryAfter: String
    public let duration: TimeInterval
}