//
//  ErrorHandlingService.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/28/25.
//

import Foundation
import OSLog

/// Service responsible for managing error states and error handling
/// Extracted from AddMoveUnifiedState to follow Single Responsibility Principle
@MainActor
public class ErrorHandlingService {

    // MARK: - Properties

    private let logger = Logger(subsystem: "BreakingFlashcards", category: "❌ ERROR_SERVICE")
    private let diagnosticLogger: DiagnosticLoggingHelper
    private let stateTransitionCoordinator: StateTransitionCoordinator

    // Error state
    public private(set) var errorMessage: String?
    public private(set) var underlyingError: String?
    public private(set) var playerState: PlayerState = .ready

    // Error history
    private var errorHistory: [ErrorEvent] = []

    // MARK: - Callbacks

    /// Callback for error state changes
    public var onErrorStateChanged: ((String, String?) -> Void)?
    /// Callback for error state cleared
    public var onErrorCleared: (() -> Void)?
    /// Callback for error recovery suggestions
    public var onRecoverySuggested: ((ErrorRecoveryAction) -> Void)?

    // MARK: - Initialization

    public init(
        diagnosticLogger: DiagnosticLoggingHelper,
        stateTransitionCoordinator: StateTransitionCoordinator
    ) {
        self.diagnosticLogger = diagnosticLogger
        self.stateTransitionCoordinator = stateTransitionCoordinator
        logger.info("❌ ERROR_SERVICE: ✅ Service initialized")
    }

    // MARK: - Public Methods

    /// Sets error state with comprehensive logging
    // MARK: - FUNC
    public func setError(message: String, underlying: String? = nil) async {
        let wasInError = errorMessage != nil

        // Update error state
        errorMessage = message
        underlyingError = underlying
        playerState = .error

        // Log error details
        logErrorSet(
            message: message,
            underlying: underlying,
            wasInError: wasInError
        )

        // Track error in history
        trackError(message: message, underlying: underlying)

        // Notify callback
        onErrorStateChanged?(message, underlying)

        // Transition to error state via coordinator
        await transitionToErrorState(message: message, underlying: underlying)

        logger.error("❌ ERROR_SERVICE: ❌ Error set - \(message)")
    }

    /// Clears error state
    // MARK: - FUNC
    public func clearError() async {
        let hadError = errorMessage != nil

        // Clear error state
        errorMessage = nil
        underlyingError = nil
        playerState = .ready

        // Log error clearing
        logErrorCleared(hadError: hadError)

        // Notify callback
        onErrorCleared?()

        logger.info("❌ ERROR_SERVICE: ✅ Error cleared")
    }

    /// Gets current error state
    // MARK: - FUNC
    public func getCurrentError() -> (message: String?, underlying: String?) {
        return (errorMessage, underlyingError)
    }
    // MARK: - FUNC
    /// Gets player state
    public func getPlayerState() -> PlayerState {
        return playerState
    }
    // MARK: - FUNC
    /// Gets error history
    public func getErrorHistory() -> [ErrorEvent] {
        return errorHistory
    }
    // MARK: - FUNC
    /// Clears error history
    public func clearErrorHistory() {
        errorHistory.removeAll()
        logger.info("❌ ERROR_SERVICE: 🧹 Error history cleared")
    }
    // MARK: - FUNC
    /// Checks if currently in error state
    public func isInErrorState() -> Bool {
        return errorMessage != nil
    }
    // MARK: - FUNC
    /// Suggests recovery action based on current error
    public func suggestRecovery() -> ErrorRecoveryAction? {
        guard let errorMessage = errorMessage else {
            return nil
        }

        return analyzeErrorForRecovery(errorMessage: errorMessage)
    }

    // MARK: - Private Methods
    // MARK: - FUNC
    private func transitionToErrorState(message: String, underlying: String?) async {
        // This will be handled by the state transition coordinator
        // The coordinator will validate and execute the transition
        _ = await stateTransitionCoordinator.transition(
            from: .ready, // This should be the current state from the unified state
            to: .error(message: message, underlyingError: underlying),
            triggeredBy: "error_handler"
        )
    }
    // MARK: - FUNC
    private func trackError(message: String, underlying: String?) {
        let errorEvent = ErrorEvent(
            id: UUID().uuidString,
            message: message,
            underlyingError: underlying,
            timestamp: Date(),
            playerState: playerState
        )

        errorHistory.append(errorEvent)

        // Keep only last 50 errors to prevent memory issues
        if errorHistory.count > 50 {
            errorHistory.removeFirst()
        }

        logger.debug("❌ ERROR_SERVICE: 📝 Error tracked | total errors: \(self.errorHistory.count)")
    }
    // MARK: - FUNC
    private func analyzeErrorForRecovery(errorMessage: String) -> ErrorRecoveryAction? {
        // Analyze error message to suggest recovery actions
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .retry
        } else if errorMessage.contains("permission") || errorMessage.contains("access") {
            return .requestPermission
        } else if errorMessage.contains("memory") || errorMessage.contains("storage") {
            return .clearStorage
        } else if errorMessage.contains("format") || errorMessage.contains("codec") {
            return .selectDifferentVideo
        } else {
            return .contactSupport
        }
    }

    // MARK: - Logging Methods
    // MARK: - FUNC
    private func logErrorSet(message: String, underlying: String?, wasInError: Bool) {
        let metadata = [
            "error_message": message,
            "underlying_error": underlying ?? "none",
            "was_in_error": "\(wasInError)",
            "player_state": "\(playerState)",
            "memory_usage_mb": "\(String(format: "%.1f", diagnosticLogger.getMemoryInfo().used))"
        ]

        diagnosticLogger.logError("Error state set", metadata: metadata)
    }
    // MARK: - FUNC
    private func logErrorCleared(hadError: Bool) {
        let metadata = [
            "had_error": "\(hadError)",
            "player_state": "\(playerState)",
            "error_history_count": "\(errorHistory.count)"
        ]

        diagnosticLogger.logInfo("Error state cleared", metadata: metadata)
    }

    // MARK: - Cleanup

    deinit {
        logger.info("❌ ERROR_SERVICE: 🧹 Service deallocating, clearing error state")
        // Inline clearErrorHistory() to avoid main actor isolation issues in deinit
        errorHistory.removeAll()
    }
}

// MARK: - Error Event

/// Represents an error event for tracking and analysis
public struct ErrorEvent {
    public let id: String
    public let message: String
    public let underlyingError: String?
    public let timestamp: Date
    public let playerState: PlayerState
}

// MARK: - Error Recovery Action

/// Represents possible recovery actions for errors
public enum ErrorRecoveryAction {
    case retry
    case requestPermission
    case clearStorage
    case selectDifferentVideo
    case contactSupport
    case restartApp
    case dismiss

    var title: String {
        switch self {
        case .retry: return "Retry"
        case .requestPermission: return "Grant Permission"
        case .clearStorage: return "Clear Storage"
        case .selectDifferentVideo: return "Choose Different Video"
        case .contactSupport: return "Contact Support"
        case .restartApp: return "Restart App"
        case .dismiss: return "Dismiss"
        }
    }

    var description: String {
        switch self {
        case .retry: return "Try the operation again"
        case .requestPermission: return "Grant required permissions"
        case .clearStorage: return "Clear up storage space"
        case .selectDifferentVideo: return "Choose a different video file"
        case .contactSupport: return "Get help from support"
        case .restartApp: return "Restart the application"
        case .dismiss: return "Dismiss the error"
        }
    }
}

// MARK: - Error Handling Configuration

/// Configuration for error handling behavior
public struct ErrorHandlingConfiguration {
    public let maxErrorHistoryCount: Int
    public let enableRecoverySuggestions: Bool
    public let enableErrorAnalytics: Bool

    public init(
        maxErrorHistoryCount: Int = 50,
        enableRecoverySuggestions: Bool = true,
        enableErrorAnalytics: Bool = true
    ) {
        self.maxErrorHistoryCount = maxErrorHistoryCount
        self.enableRecoverySuggestions = enableRecoverySuggestions
        self.enableErrorAnalytics = enableErrorAnalytics
    }
}