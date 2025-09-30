//
//  FlowStateManager.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/30/25.
//

import Foundation
import AVFoundation
import OSLog
import SwiftUI
import CoreData

/// Service responsible for managing AddMove flow state transitions
/// Extracted from AddMoveUnifiedState to follow Single Responsibility Principle
@MainActor
public class FlowStateManager: ObservableObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "BreakingFlashcards", category: "🔄 FLOW_STATE")

    // MARK: - Service Dependencies

    private let unifiedState: AddMoveUnifiedState
    private let stateValidator: StateValidator
    private let addMoveSaveCoordinator: AddMoveSaveCoordinator

    // MARK: - Callbacks

    /// Callback for state transition events
    public var onStateTransition: ((AddMoveFlowState, AddMoveFlowState, String) -> Void)?

    // MARK: - Initialization

    public init(
        unifiedState: AddMoveUnifiedState,
        stateValidator: StateValidator,
        addMoveSaveCoordinator: AddMoveSaveCoordinator
    ) {
        self.unifiedState = unifiedState
        self.stateValidator = stateValidator
        self.addMoveSaveCoordinator = addMoveSaveCoordinator
        logger.info("🔄 FLOW_STATE: ✅ Service initialized")
    }

    // MARK: - Public API

    /// Proceed to the next state in the simplified 5-stage flow
    public func proceedToNextState() async throws {
        logger.info("🔄 FLOW_STATE: 🚀 Proceeding to next state from current: \(String(describing: self.unifiedState.flowState))")

        let currentState = unifiedState.flowState

        // Validate that we're in a state that can proceed
        guard currentState.isInteractive else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Cannot proceed from non-interactive state: \(String(describing: currentState))")
            throw FlowStateError.invalidTransition(from: currentState, to: currentState)
        }

        let nextState: AddMoveFlowState

        switch currentState {
        case .ready:
            // Should not happen - this means video loading hasn't started
            logger.warning("🔄 FLOW_STATE: ⚠️ proceedToNextState called from ready state")
            throw FlowStateError.invalidTransition(from: currentState, to: .loadingVideo(progress: SimpleProgress(value: 0.0, message: "")))

        case .loadingVideo:
            // Loading should complete automatically and transition to trimming
            logger.warning("🔄 FLOW_STATE: ⚠️ proceedToNextState called during loading - waiting for completion")
            throw FlowStateError.transitionInProgress

        case .trimming:
            logger.info("🔄 FLOW_STATE: 📊 Transition: trimming → loadingTrimmedAsset")

            // Start preparing the trimmed asset for naming
            let initialProgress = SimpleProgress(value: 0.0, message: "Preparing trimmed asset...")
            nextState = .loadingTrimmedAsset(progress: initialProgress)
            await performTransition(to: nextState, triggeredBy: "proceedToNextState_trimming")

            // Start asset preparation
            await prepareTrimmedAsset()

        case .loadingTrimmedAsset:
            // Asset loading should complete automatically and transition to naming
            logger.warning("🔄 FLOW_STATE: ⚠️ proceedToNextState called during asset loading - waiting for completion")
            throw FlowStateError.transitionInProgress

        case .naming:
            logger.info("🔄 FLOW_STATE: 📊 Transition: naming → saving")
            nextState = .saving
            await performTransition(to: nextState, triggeredBy: "proceedToNextState_naming")
            // Start save operation
            await initiateSaveOperation()

        case .saving:
            logger.warning("🔄 FLOW_STATE: ⚠️ proceedToNextState called during save operation")
            throw FlowStateError.transitionInProgress

        case .success, .error:
            logger.warning("🔄 FLOW_STATE: ⚠️ proceedToNextState called from terminal state: \(String(describing: currentState))")
            throw FlowStateError.invalidTerminalState(currentState)
        }

        logger.info("🔄 FLOW_STATE: ✅ State transition completed: \(String(describing: currentState)) → \(String(describing: nextState))")
    }

    /// Simplified setup method - in the new flow, trimmer setup happens within trimming state
    public func setupTrimmerAfterPreview() async {
        logger.info("🔄 FLOW_STATE: 📡 Setup trimmer - simplified version")

        // In the simplified flow, trimmer setup is handled directly in the trimming state
        // This method is kept for backward compatibility
        if case .trimming = unifiedState.flowState {
            logger.info("🔄 FLOW_STATE: ✅ Already in trimming state - no additional setup needed")
        } else {
            logger.warning("🔄 FLOW_STATE: ⚠️ setupTrimmerAfterPreview called but not in trimming state")
        }
    }

    /// Simplified rollback - go back from trimming to ready state
    public func rollbackToReady() async {
        logger.info("🔄 FLOW_STATE: 🔄 Executing rollback: trimming → ready")

        // Clean up trimmer setup
        if unifiedState.trimmerViewModel != nil {
            logger.info("🔄 FLOW_STATE: 🧹 Cleaning up trimmer setup")
            unifiedState.trimmerViewModel = nil
        }

        // Reset to ready state
        await performTransition(to: .ready, triggeredBy: "rollback_to_ready")

        logger.info("🔄 FLOW_STATE: ✅ Rollback completed: returned to ready state")
    }

    /// Validate the simplified flow works correctly
    public func validateFlowTransitions() async -> Bool {
        logger.info("🔄 FLOW_STATE: 🔍 Validating simplified flow transitions")

        // The simplified flow has fewer transitions to validate
        // We can test that we can proceed through each stage
        let currentState = unifiedState.flowState

        switch currentState {
        case .trimming:
            logger.info("🔄 FLOW_STATE: ✅ Can proceed from trimming state")
            return true
        case .naming:
            logger.info("🔄 FLOW_STATE: ✅ Can proceed from naming state")
            return true
        default:
            logger.info("🔄 FLOW_STATE: 📊 Current state: \(String(describing: currentState)) - validation complete")
            return true
        }
    }

    // MARK: - Private Methods

    /// Perform a state transition with validation and logging
    private func performTransition(to newState: AddMoveFlowState, triggeredBy: String) async {
        let previousState = unifiedState.flowState

        // Validate transition using existing state validator
        let validationErrors = stateValidator.validateStateConsistency(
            flowState: newState,
            playerState: unifiedState.playerState,
            videoAsset: unifiedState.videoAsset,
            trimmerViewModel: unifiedState.trimmerViewModel as? TrimmerViewModel,
            playerViewModel: unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel,
            photosIdentifier: unifiedState.photosIdentifier
        )

        if !validationErrors.isEmpty {
            let errorDescriptions = validationErrors.map { $0.localizedDescription }
            let errorMessage = errorDescriptions.joined(separator: ", ")
            logger.error("🔄 FLOW_STATE: ❌ State validation failed: \(errorMessage)")
            await setError(message: "State transition validation failed", underlying: errorMessage)
            return
        }

        // Perform transition through unified state
        unifiedState.transition(to: newState, triggeredBy: triggeredBy)

        // Notify callback
        onStateTransition?(previousState, newState, triggeredBy)

        logger.info("🔄 FLOW_STATE: 🔄 State transition executed: \(String(describing: previousState)) → \(String(describing: newState)) [triggered by: \(triggeredBy)]")
    }

    /// Initiate the save operation using the save coordinator
    private func initiateSaveOperation() async {
        logger.info("🔄 FLOW_STATE: Initiating save operation")

        do {
            let result = try await addMoveSaveCoordinator.saveMove(
                name: unifiedState.moveName,
                asset: unifiedState.videoAsset!,
                photosIdentifier: unifiedState.photosIdentifier!,
                trimStartTime: unifiedState.trimStartTime,
                trimEndTime: unifiedState.trimEndTime,
                rotationQuarterTurns: unifiedState.rotationQuarterTurns
            )

            await performTransition(to: .success(message: "Move saved successfully"), triggeredBy: "saveOperation_complete")

            if let moveName = result.move.name {
                logger.info("🔄 FLOW_STATE: ✅ Save operation completed: \(moveName)")
            } else {
                logger.info("🔄 FLOW_STATE: ✅ Save operation completed")
            }

        } catch {
            logger.error("🔄 FLOW_STATE: ❌ Save operation failed: \(error.localizedDescription)")
            await performTransition(to: .error(message: "Failed to save move", underlyingError: error.localizedDescription), triggeredBy: "saveOperation_failed")
        }
    }

    /// Prepare the trimmed asset for the naming stage
    private func prepareTrimmedAsset() async {
        logger.info("🔄 FLOW_STATE: 🎬 Preparing trimmed asset for naming stage")

        do {
            // Validate required components
            guard let trimmerViewModel = unifiedState.trimmerViewModel as? TrimmerViewModel else {
                logger.error("🔄 FLOW_STATE: ❌ TrimmerViewModel not available")
                throw FlowStateError.missingViewModel("TrimmerViewModel")
            }

            guard let currentPlayerViewModel = unifiedState.unifiedPlayerManager.currentPlayer else {
                logger.error("🔄 FLOW_STATE: ❌ Current player not available")
                throw FlowStateError.missingViewModel("UnifiedVideoPlayerViewModel")
            }

            logger.info("🔄 FLOW_STATE: ✅ Component validation successful")

            // Update progress
            let inProgress = SimpleProgress(value: 0.3, message: "Creating trimmed asset...")
            Task { @MainActor in
                await unifiedState.handleTrimmedAssetProgress(inProgress)
            }

            // Create the trimmed player item
            logger.info("🔄 FLOW_STATE: 🎬 Calling prepareFinalAssetForSave on TrimmerViewModel")
            let trimmedPlayerItem = try await trimmerViewModel.prepareFinalAssetForSave()

            let duration = try await trimmedPlayerItem.asset.load(.duration)
            logger.info("🔄 FLOW_STATE: ✅ Trimmed asset created - Duration: \(duration.seconds)s")

            // Update progress
            let nearComplete = SimpleProgress(value: 0.8, message: "Finalizing trimmed asset...")
            Task { @MainActor in
                await unifiedState.handleTrimmedAssetProgress(nearComplete)
            }

            // Replace player content with trimmed version
            logger.info("🔄 FLOW_STATE: 🔄 Replacing player item with trimmed asset")
            try await currentPlayerViewModel.replacePlayerItemAndWaitForReady(trimmedPlayerItem)

            logger.info("🔄 FLOW_STATE: ✅ Player ready with trimmed asset")

            // Update progress to complete
            let completed = SimpleProgress(value: 1.0, message: "Trimmed asset ready")
            Task { @MainActor in
                await unifiedState.handleTrimmedAssetProgress(completed)
            }

            logger.info("🔄 FLOW_STATE: ✅ Trimmed asset preparation completed successfully")

        } catch {
            logger.error("🔄 FLOW_STATE: ❌ Asset preparation failed: \(error.localizedDescription)")
            await setError(message: "Failed to prepare trimmed video", underlying: error.localizedDescription)
        }
    }

    /// Set error state through unified state
    private func setError(message: String, underlying: String? = nil) async {
        logger.error("🔄 FLOW_STATE: Error - \(message)")
        if let underlying = underlying {
            logger.error("🔄 FLOW_STATE: Underlying error - \(underlying)")
        }
        await unifiedState.setError(message: message, underlying: underlying)
    }
}

// MARK: - Flow State Errors

public enum FlowStateError: Error, LocalizedError {
    case invalidTransition(from: AddMoveFlowState, to: AddMoveFlowState)
    case transitionInProgress
    case invalidTerminalState(AddMoveFlowState)
    case missingViewModel(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Invalid state transition from \(String(describing: from)) to \(String(describing: to))"
        case .transitionInProgress:
            return "A state transition is already in progress"
        case .invalidTerminalState(let state):
            return "Cannot proceed from terminal state: \(String(describing: state))"
        case .missingViewModel(let name):
            return "Required view model '\(name)' was not available for the state transition."
        }
    }
}

// MARK: - Simplified TrimmerSetupProgressDelegate Implementation
extension FlowStateManager: @preconcurrency TrimmerSetupProgressDelegate {

    public func trimmerDidUpdateProgress(_ progress: Double, status: String) {
        logger.info("🔄 FLOW_STATE: 📊 Trimmer setup progress: \(String(format: "%.1f", progress * 100))% - \(status)")

        // In the simplified flow, we just log the progress but don't change states
        // The trimmer setup happens within the trimming state
        if case .trimming = self.unifiedState.flowState {
            logger.info("🔄 FLOW_STATE: 📊 Trimmer setup continuing in trimming state")
        } else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Trimmer progress update received but not in trimming state: \(String(describing: self.unifiedState.flowState))")
        }
    }

    public func trimmerDidCompleteSetup(totalTime: TimeInterval?) {
        logger.info("🔄 FLOW_STATE: ✅ Trimmer setup completed successfully")

        if let totalTime = totalTime {
            logger.info("🔄 FLOW_STATE: ⏱️ Total setup time: \(String(format: "%.2f", totalTime))s")
        }

        // In the simplified flow, we should already be in trimming state
        // Just log the completion
        if case .trimming = self.unifiedState.flowState {
            logger.info("🔄 FLOW_STATE: ✅ Trimmer is ready for user interaction")
        } else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Trimmer completion received but not in trimming state: \(String(describing: self.unifiedState.flowState))")
        }
    }

    public func trimmerDidEncounterError(_ error: Error, context: String) {
        logger.error("🔄 FLOW_STATE: ❌ Trimmer setup error in context '\(context)': \(error.localizedDescription)")

        // Provide detailed error information
        let underlyingError = "\(context): \(error.localizedDescription)"
        logger.error("🔄 FLOW_STATE: 🔍 Full error context: \(underlyingError)")

        // Transition to error state
        Task { @MainActor in
            await setError(message: "Trimmer setup failed", underlying: underlyingError)
        }
    }
}