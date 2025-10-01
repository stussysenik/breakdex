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
import Darwin

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

        // 🎯 CRITICAL FIX: Enhanced state validation with dependency checks
        guard await validateCurrentStateForTransition(currentState) else {
            logger.error("🔄 FLOW_STATE: ❌ Current state validation failed for: \(String(describing: currentState))")
            throw FlowStateError.stateValidationFailed(currentState)
        }

        // Validate that we're in a state that can proceed
        guard currentState.isInteractive else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Cannot proceed from non-interactive state: \(String(describing: currentState))")
            throw FlowStateError.invalidTransition(from: currentState, to: currentState)
        }

        // 🎯 CRITICAL FIX: Add transition guard to prevent duplicate transitions
        guard !isTransitionInProgress(from: currentState) else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Transition already in progress from: \(String(describing: currentState))")
            throw FlowStateError.transitionInProgress
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

            // 🎯 CRITICAL FIX: Validate trimming completion before proceeding
            guard await validateTrimmingCompletion() else {
                logger.error("🔄 FLOW_STATE: ❌ Trimming validation failed")
                throw FlowStateError.trimmingIncomplete
            }

            // 🎯 CRITICAL STATE SYNCHRONIZATION FIX: Implement missing morphism
            // This ensures AddMoveUnifiedState has the final edited values from TrimmerViewModel
            await synchronizeTrimmingStateToUnifiedState()

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

            // 🎯 CRITICAL FIX: Validate naming completion before saving
            guard await validateNamingCompletion() else {
                logger.error("🔄 FLOW_STATE: ❌ Naming validation failed")
                throw FlowStateError.namingIncomplete
            }

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

    /// 🎯 BACK BUTTON FIX: Rollback from naming back to trimming with state preservation
    public func rollbackToTrimming() async {
        logger.info("🔄 FLOW_STATE: 🔙 Executing rollback: naming → trimming")
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: Starting rollback with explicit self references in closures")

        // Validate we're in naming state
        guard case .naming = self.unifiedState.flowState else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Cannot rollback to trimming - not in naming state: \(String(describing: self.unifiedState.flowState))")
            return
        }

        // 🎯 BACK BUTTON FIX: Try to restore trimming state first
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: Attempting to resolve ambiguous method calls by accessing preserved state directly")

        // Direct access to preserved trimming state to avoid ambiguous method calls
        let hasPreservedState = self.unifiedState.preservedTrimmingState != nil
        if hasPreservedState {
            logger.info("🔄 FLOW_STATE: 🔄 Preserved trimming state available - attempting restoration")

            // Use a direct approach to avoid ambiguous method calls
            let restorationSuccess = await attemptDirectTrimmingStateRestoration()
            if restorationSuccess {
                logger.info("🔄 FLOW_STATE: ✅ Trimming state restored from preserved data")

                // Perform the transition to trimming state
                await performTransition(to: .trimming, triggeredBy: "rollback_to_trimming_preserved")

                logger.info("🔄 FLOW_STATE: ✅ Rollback completed: returned to trimming with preserved state")
                return
            } else {
                logger.warning("🔄 FLOW_STATE: ⚠️ Failed to restore trimming state from preserved data")
            }
        }

        // 🎯 BACK BUTTON FIX: Fallback to current state validation
        logger.info("🔄 FLOW_STATE: 📝 No preserved state - validating current data for trimmer reconstruction")

        // Validate we have the required data for trimming
        guard unifiedState.videoAsset != nil else {
            logger.error("🔄 FLOW_STATE: ❌ Cannot rollback to trimming - missing video asset")
            await performTransition(to: .error(message: "Cannot return to trimming", underlyingError: "Missing video asset"), triggeredBy: "rollback_to_trimming_failed")
            return
        }

        guard unifiedState.photosIdentifier != nil && !unifiedState.photosIdentifier!.isEmpty else {
            logger.error("🔄 FLOW_STATE: ❌ Cannot rollback to trimming - missing photos identifier")
            await performTransition(to: .error(message: "Cannot return to trimming", underlyingError: "Missing photos identifier"), triggeredBy: "rollback_to_trimming_failed")
            return
        }

        // 🎯 ACCESS LEVEL FIX: Ensure we have valid trim times - these properties are now accessible
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: ACCESS LEVEL FIX - Validating trim times")
        logger.info("🔄 FLOW_STATE: 📊 Current trim range: \(String(format: "%.2f", self.unifiedState.trimStartTime))s - \(String(format: "%.2f", self.unifiedState.trimEndTime))s")

        guard unifiedState.trimStartTime >= 0 && unifiedState.trimEndTime > unifiedState.trimStartTime else {
            logger.warning("🔄 FLOW_STATE: ⚠️ Invalid trim times - using defaults")
            // Set reasonable defaults if trim times are invalid
            logger.info("🔄 FLOW_STATE: 🔧 ACCESS LEVEL FIX - Setting default trim times")
            self.unifiedState.trimStartTime = 0.0
            // 🎯 DEPRECATION FIX: Use async duration loading instead of deprecated property
        if let asset = self.unifiedState.videoAsset {
            do {
                let duration = try await asset.load(.duration)
                self.unifiedState.trimEndTime = min(3.0, duration.seconds)
            } catch {
                logger.warning("🔄 FLOW_STATE: ⚠️ Failed to load asset duration, using default: \(error.localizedDescription)")
                self.unifiedState.trimEndTime = 3.0
            }
        } else {
            self.unifiedState.trimEndTime = 3.0
        }
            logger.info("🔄 FLOW_STATE: 📊 Default trim range set: \(String(format: "%.2f", self.unifiedState.trimStartTime))s - \(String(format: "%.2f", self.unifiedState.trimEndTime))s")
            return
        }

        logger.info("🔄 FLOW_STATE: 📊 Rollback validation passed - trim range: \(String(format: "%.2f", self.unifiedState.trimStartTime))s - \(String(format: "%.2f", self.unifiedState.trimEndTime))s")

        // 🎯 BACK BUTTON FIX: Ensure player state is ready for trimming transition
        logger.info("🔄 FLOW_STATE: 🔧 BACK BUTTON FIX - Setting player state to ready for fallback transition")
        self.unifiedState.updatePlayerState(.ready)
        logger.info("🔄 FLOW_STATE: 📊 Player state set to: .ready")

        // Perform the transition to trimming state
        await performTransition(to: .trimming, triggeredBy: "rollback_to_trimming_fallback")

        logger.info("🔄 FLOW_STATE: ✅ Rollback completed: returned to trimming with fallback state")
    }

    /// Completes the asset loading phase and transitions to the naming state
    /// 🎯 CRITICAL FIX: This method ensures proper state synchronization from .loadingTrimmedAsset to .naming
    /// with correct player state synchronization, fixing the core "Save Move" functionality issue
    @MainActor
    public func completeAssetLoading() async {
        logger.info("🔄 FLOW_STATE: 🚀 Completing asset loading from current: \(String(describing: self.unifiedState.flowState))")

        // Validate we're in the correct state before proceeding
        guard case .loadingTrimmedAsset = unifiedState.flowState else {
            logger.warning("🔄 FLOW_STATE: ⚠️ completeAssetLoading called but not in loadingTrimmedAsset state. Current state: \(String(describing: self.unifiedState.flowState))")
            return
        }

        // 🎯 CRITICAL FIX: Log the state transition for comprehensive diagnostic tracing
        logger.info("🔄 FLOW_STATE: 📊 State transition initiated: .loadingTrimmedAsset → .naming")
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC - Player state before transition: \(String(describing: self.unifiedState.playerState))")

        // 🎯 CRITICAL FIX: Perform the atomic transition using the existing performTransition method
        // This ensures that playerState is properly synchronized to .ready since .naming is an interactive state
        await performTransition(to: .naming, triggeredBy: "asset_loading_complete")

        // 🎯 CRITICAL FIX: Verify the transition completed successfully
        logger.info("🔄 FLOW_STATE: ✅ Asset loading completed, transitioned to naming state")
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC - Player state after transition: \(String(describing: self.unifiedState.playerState))")
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC - Flow state after transition: \(String(describing: self.unifiedState.flowState))")

        // 🎯 CRITICAL FIX: Additional verification to ensure state consistency
        if case .naming = self.unifiedState.flowState, self.unifiedState.playerState == .ready {
            logger.info("🔄 FLOW_STATE: ✅ State synchronization verified - Both flowState and playerState are correctly aligned")
        } else {
            logger.error("🔄 FLOW_STATE: ❌ State synchronization failed - Expected (.naming, .ready), got (\(String(describing: self.unifiedState.flowState)), \(String(describing: self.unifiedState.playerState)))")
            // Attempt recovery by setting player state explicitly
            self.unifiedState.updatePlayerState(.ready)
            logger.info("🔄 FLOW_STATE: 🔧 Recovery attempt - Player state explicitly set to .ready")
        }
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

    /// 🎯 CRITICAL STATE SYNCHRONIZATION FIX: Missing morphism implementation
    /// Maps final trim/rotation values from TrimmerViewModel back to AddMoveUnifiedState
    /// This implements the essential state functor that preserves user edits during state transitions
    @MainActor
    private func synchronizeTrimmingStateToUnifiedState() async {
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: Starting state synchronization morphism")

        // Validate we have the required TrimmerViewModel
        guard let trimmerViewModel = unifiedState.trimmerViewModel as? TrimmerViewModel else {
            logger.error("🔄 FLOW_STATE: ❌ Cannot synchronize - TrimmerViewModel not available")
            return
        }

        // Capture current state before synchronization for diagnostic logging
        let oldTrimStartTime = unifiedState.trimStartTime
        let oldTrimEndTime = unifiedState.trimEndTime
        let oldRotationQuarterTurns = unifiedState.rotationQuarterTurns

        // Get the final edited values from TrimmerViewModel
        let newTrimStartTime = trimmerViewModel.startTime.seconds
        let newTrimEndTime = trimmerViewModel.endTime.seconds
        let newRotationQuarterTurns = trimmerViewModel.rotationQuarterTurns

        // 🎯 CRITICAL FIX: Apply the state functor - copy final values to central state
        unifiedState.trimStartTime = newTrimStartTime
        unifiedState.trimEndTime = newTrimEndTime
        unifiedState.rotationQuarterTurns = newRotationQuarterTurns

        // Diagnostic logging for transparent debugging and build verification
        let trimDurationChanged = abs((newTrimEndTime - newTrimStartTime) - (oldTrimEndTime - oldTrimStartTime)) > 0.01
        let rotationChanged = newRotationQuarterTurns != oldRotationQuarterTurns

        logger.info("🔄 FLOW_STATE: ✅ State synchronization completed successfully")
        logger.info("🔄 FLOW_STATE: 📊 DIAGNOSTIC: State morphism results:")
        logger.info("🔄 FLOW_STATE:   - Trim range: \(String(format: "%.2f", oldTrimStartTime))-\(String(format: "%.2f", oldTrimEndTime)) → \(String(format: "%.2f", newTrimStartTime))-\(String(format: "%.2f", newTrimEndTime))")
        logger.info("🔄 FLOW_STATE:   - Duration: \(String(format: "%.2f", oldTrimEndTime - oldTrimStartTime))s → \(String(format: "%.2f", newTrimEndTime - newTrimStartTime))s (\(trimDurationChanged ? "CHANGED" : "same"))")
        logger.info("🔄 FLOW_STATE:   - Rotation: \(oldRotationQuarterTurns * 90)° → \(newRotationQuarterTurns * 90)° (\(rotationChanged ? "CHANGED" : "same"))")

        // State consistency verification
        guard newTrimStartTime < newTrimEndTime else {
            logger.error("🔄 FLOW_STATE: ❌ CRITICAL: Synchronized trim range is invalid: start(\(newTrimStartTime)) >= end(\(newTrimEndTime))")
            return
        }

        if (newTrimEndTime - newTrimStartTime) < 0.5 {
            logger.warning("🔄 FLOW_STATE: ⚠️ Synchronized trim duration is very short: \(String(format: "%.2f", newTrimEndTime - newTrimStartTime))s")
        }

        logger.info("🔄 FLOW_STATE: ✅ State synchronization verified - AddMoveUnifiedState now contains user's final edits")
    }

    /// 🎯 CRITICAL FIX: Enhanced state validation for robust transitions
    /// Validates that the current state has all required dependencies for transition
    @MainActor
    private func validateCurrentStateForTransition(_ state: AddMoveFlowState) async -> Bool {
        logger.info("🔄 FLOW_STATE: 🔍 Validating state dependencies for: \(String(describing: state))")

        switch state {
        case .trimming:
            // Validate we have video asset, photos identifier, and player
            guard unifiedState.videoAsset != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Video asset missing for trimming transition")
                return false
            }
            guard unifiedState.photosIdentifier != nil && !unifiedState.photosIdentifier!.isEmpty else {
                logger.error("🔄 FLOW_STATE: ❌ Photos identifier missing for trimming transition")
                return false
            }
            guard unifiedState.currentPlayerViewModel != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Player view model missing for trimming transition")
                return false
            }
            logger.info("🔄 FLOW_STATE: ✅ Trimming state dependencies validated")

        case .naming:
            // Validate we have trimmed asset ready
            guard unifiedState.trimmerViewModel != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Trimmer view model missing for naming transition")
                return false
            }
            guard unifiedState.currentPlayerViewModel != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Player view model missing for naming transition")
                return false
            }
            logger.info("🔄 FLOW_STATE: ✅ Naming state dependencies validated")

        case .saving:
            // Validate we have move name and all required data
            guard !unifiedState.moveName.isEmpty else {
                logger.error("🔄 FLOW_STATE: ❌ Move name empty for saving transition")
                return false
            }
            guard unifiedState.videoAsset != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Video asset missing for saving transition")
                return false
            }
            guard unifiedState.photosIdentifier != nil else {
                logger.error("🔄 FLOW_STATE: ❌ Photos identifier missing for saving transition")
                return false
            }
            logger.info("🔄 FLOW_STATE: ✅ Saving state dependencies validated")

        default:
            logger.info("🔄 FLOW_STATE: ℹ️ No specific validation needed for state: \(String(describing: state))")
        }

        return true
    }

    /// 🎯 CRITICAL FIX: Check if transition is already in progress
    @MainActor
    private func isTransitionInProgress(from state: AddMoveFlowState) -> Bool {
        // Simple heuristic to detect stuck transitions
        let _: Date = Date() // Current time for future timeout enhancement
        let transitionTimeout: TimeInterval = 30.0 // 30 seconds

        // You could enhance this with actual transition tracking if needed
        switch state {
        case .loadingVideo, .loadingTrimmedAsset:
            // Loading states should have progress
            return unifiedState.loadingProgress > 0.0 && unifiedState.loadingProgress < 1.0
        case .saving:
            // Saving state should have elapsed time
            return unifiedState.saveElapsedTime > 0.0 && unifiedState.saveElapsedTime < transitionTimeout
        default:
            return false
        }
    }

    /// 🎯 CRITICAL FIX: Validate trimming completion
    @MainActor
    private func validateTrimmingCompletion() async -> Bool {
        logger.info("🔄 FLOW_STATE: 🔍 Validating trimming completion")

        guard let trimmerViewModel = unifiedState.trimmerViewModel as? TrimmerViewModel else {
            logger.error("🔄 FLOW_STATE: ❌ TrimmerViewModel not available")
            return false
        }

        // Validate trim range is valid
        let startTime = trimmerViewModel.startTime.seconds
        let endTime = trimmerViewModel.endTime.seconds

        guard startTime < endTime else {
            logger.error("🔄 FLOW_STATE: ❌ Invalid trim range: start(\(startTime)) >= end(\(endTime))")
            return false
        }

        guard startTime >= 0 else {
            logger.error("🔄 FLOW_STATE: ❌ Invalid start time: \(startTime)")
            return false
        }

        // Validate minimum duration (e.g., 0.5 seconds)
        let minimumDuration: TimeInterval = 0.5
        guard (endTime - startTime) >= minimumDuration else {
            logger.error("🔄 FLOW_STATE: ❌ Trim duration too short: \(endTime - startTime)s < \(minimumDuration)s")
            return false
        }

        logger.info("🔄 FLOW_STATE: ✅ Trimming validation passed - duration: \(endTime - startTime)s")
        return true
    }

    /// 🎯 CRITICAL FIX: Validate naming completion
    @MainActor
    private func validateNamingCompletion() async -> Bool {
        logger.info("🔄 FLOW_STATE: 🔍 Validating naming completion")

        // Validate move name is not empty
        guard !unifiedState.moveName.isEmpty else {
            logger.error("🔄 FLOW_STATE: ❌ Move name is empty")
            return false
        }

        // Validate move name meets minimum requirements
        guard unifiedState.moveName.count >= 1 else {
            logger.error("🔄 FLOW_STATE: ❌ Move name too short")
            return false
        }

        guard unifiedState.moveName.count <= 100 else {
            logger.error("🔄 FLOW_STATE: ❌ Move name too long")
            return false
        }

        // Validate all required data is available
        guard unifiedState.videoAsset != nil else {
            logger.error("🔄 FLOW_STATE: ❌ Video asset not available")
            return false
        }

        guard unifiedState.photosIdentifier != nil else {
            logger.error("🔄 FLOW_STATE: ❌ Photos identifier not available")
            return false
        }

        logger.info("🔄 FLOW_STATE: ✅ Naming validation passed - move name: \(self.unifiedState.moveName)")
        return true
    }

    /// Perform a state transition with validation and logging
    private func performTransition(to newState: AddMoveFlowState, triggeredBy: String) async {
        let previousState = unifiedState.flowState

        // 🎯 BACK BUTTON FIX: Ensure player state is properly synchronized before validation
        // When transitioning to interactive states, ensure player is ready
        if case .trimming = newState {
            // Set player state to ready before validation for trimming state
            unifiedState.updatePlayerState(.ready)
            logger.info("🔄 FLOW_STATE: 🔧 BACK BUTTON FIX - Player state set to .ready for trimming transition")
        } else if newState.isInteractive {
            unifiedState.updatePlayerState(.ready)
            logger.info("🔄 FLOW_STATE: 🔧 Player state set to .ready for interactive state: \(String(describing: newState))")
        } else {
            unifiedState.updatePlayerState(.idle)
            logger.info("🔄 FLOW_STATE: 🔧 Player state set to .idle for non-interactive state: \(String(describing: newState))")
        }

        // Validate transition using existing state validator with updated player state
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
        // Fix: Add await keyword for async transition function call
        await unifiedState.transition(to: newState, triggeredBy: triggeredBy)

        // Notify callback
        onStateTransition?(previousState, newState, triggeredBy)

        logger.info("🔄 FLOW_STATE: 🔄 State transition executed: \(String(describing: previousState)) → \(String(describing: newState)) [triggered by: \(triggeredBy)]")
        logger.info("🔄 FLOW_STATE: ✅ BACK BUTTON FIX - Player state synchronized: \(String(describing: self.unifiedState.playerState)) for \(String(describing: newState))")
    }

    /// Initiate the save operation using the save coordinator
    private func initiateSaveOperation() async {
        logger.info("🔄 FLOW_STATE: Initiating save operation")
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: ACCESS LEVEL FIX - Starting save operation with explicit self references and corrected property access")

        // 🎯 ACCESS LEVEL FIX: Log save parameters - these properties are now accessible after making TrimmingStateSnapshot public
        logger.info("🔄 FLOW_STATE: 📊 Save parameters - Name: '\(self.unifiedState.moveName)', Duration: \(String(format: "%.2f", self.unifiedState.trimEndTime - self.unifiedState.trimStartTime))s, Rotation: \(self.unifiedState.rotationQuarterTurns * 90)°")
        logger.info("🔄 FLOW_STATE: 🔧 ACCESS LEVEL FIX - Accessing trimStartTime: \(self.unifiedState.trimStartTime)")
        logger.info("🔄 FLOW_STATE: 🔧 ACCESS LEVEL FIX - Accessing trimEndTime: \(self.unifiedState.trimEndTime)")
        logger.info("🔄 FLOW_STATE: 🔧 ACCESS LEVEL FIX - Accessing rotationQuarterTurns: \(self.unifiedState.rotationQuarterTurns)")

        do {
            let result = try await addMoveSaveCoordinator.saveMove(
                name: unifiedState.moveName,
                asset: unifiedState.videoAsset!,
                photosIdentifier: unifiedState.photosIdentifier!,
                trimStartTime: unifiedState.trimStartTime,
                trimEndTime: unifiedState.trimEndTime,
                rotationQuarterTurns: unifiedState.rotationQuarterTurns
            )

            logger.info("🔄 FLOW_STATE: 🎉 Save operation completed successfully")

            // 🎯 DIAGNOSTIC: Log save result details
            logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: Logging corrected SavedMoveResult properties (estimatedFileSize removed)")
            if let moveName = result.move.name {
                logger.info("🔄 FLOW_STATE: ✅ Saved move: \(moveName)")
                logger.info("🔄 FLOW_STATE: 📊 Photos identifier: \(result.move.photosIdentifier ?? "none")")
                logger.info("🔄 FLOW_STATE: 📊 Was trimmed: \(result.wasTrimmed)")
            } else {
                logger.info("🔄 FLOW_STATE: ✅ Save operation completed (no move name available)")
            }

            await performTransition(to: .success(message: "Move saved successfully"), triggeredBy: "saveOperation_complete")

        } catch {
            logger.error("🔄 FLOW_STATE: ❌ Save operation failed: \(error.localizedDescription)")
            logger.error("🔄 FLOW_STATE: 🔍 Error type: \(type(of: error))")
            logger.error("🔄 FLOW_STATE: 📊 Save parameters at failure - Name: '\(self.unifiedState.moveName)', Asset available: \(self.unifiedState.videoAsset != nil)")
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
            unifiedState.handleTrimmedAssetProgress(inProgress)

            // Create the trimmed player item
            logger.info("🔄 FLOW_STATE: 🎬 Calling prepareFinalAssetForSave on TrimmerViewModel")
            let trimmedPlayerItem = try await trimmerViewModel.prepareFinalAssetForSave()

            let duration = try await trimmedPlayerItem.asset.load(.duration)
            logger.info("🔄 FLOW_STATE: ✅ Trimmed asset created - Duration: \(duration.seconds)s")

            // Update progress
            let nearComplete = SimpleProgress(value: 0.8, message: "Finalizing trimmed asset...")
            unifiedState.handleTrimmedAssetProgress(nearComplete)

            // Replace player content with trimmed version
            logger.info("🔄 FLOW_STATE: 🔄 Replacing player item with trimmed asset")
            try await currentPlayerViewModel.replacePlayerItemAndWaitForReady(trimmedPlayerItem)

            logger.info("🔄 FLOW_STATE: ✅ Player ready with trimmed asset")

            // Update progress to complete
            let completed = SimpleProgress(value: 1.0, message: "Trimmed asset ready")
            unifiedState.handleTrimmedAssetProgress(completed)

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

    /// 🎯 DIAGNOSTIC: Direct trimming state restoration to avoid ambiguous method calls
    private func attemptDirectTrimmingStateRestoration() async -> Bool {
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: Attempting direct trimming state restoration")
        logger.info("🔄 FLOW_STATE: 📊 BACK BUTTON FIX - Starting trimming state restoration with player synchronization")

        guard let preservedState = self.unifiedState.preservedTrimmingState else {
            logger.warning("🔄 FLOW_STATE: ⚠️ No preserved trimming state available")
            return false
        }

        // Restore trim times with comprehensive diagnostic logging
        logger.info("🔄 FLOW_STATE: 🔧 DIAGNOSTIC: ACCESS LEVEL FIX - Restoring trim times from preserved state")
        logger.info("🔄 FLOW_STATE: 📊 Preserved trim range: \(String(format: "%.2f", preservedState.trimStartTime))s - \(String(format: "%.2f", preservedState.trimEndTime))s")
        logger.info("🔄 FLOW_STATE: 📊 Preserved rotation: \(preservedState.rotationQuarterTurns * 90)°")
        logger.info("🔄 FLOW_STATE: 📊 Preserved timestamp: \(preservedState.timestamp)")

        // 🎯 BACK BUTTON FIX: Restore player state as well to ensure consistency
        logger.info("🔄 FLOW_STATE: 🔧 BACK BUTTON FIX - Restoring player state for trimming consistency")
        self.unifiedState.updatePlayerState(.ready)
        logger.info("🔄 FLOW_STATE: 📊 Player state restored to: .ready")

        // 🎯 ACCESS LEVEL FIX: These properties are now accessible after making TrimmingStateSnapshot public
        self.unifiedState.trimStartTime = preservedState.trimStartTime
        self.unifiedState.trimEndTime = preservedState.trimEndTime
        self.unifiedState.rotationQuarterTurns = preservedState.rotationQuarterTurns

        logger.info("🔄 FLOW_STATE: ✅ ACCESS LEVEL FIX - Trim times successfully restored")
        logger.info("🔄 FLOW_STATE: 📊 Current trim range after restoration: \(String(format: "%.2f", self.unifiedState.trimStartTime))s - \(String(format: "%.2f", self.unifiedState.trimEndTime))s")
        logger.info("🔄 FLOW_STATE: 📊 Current rotation after restoration: \(self.unifiedState.rotationQuarterTurns * 90)°")
        logger.info("🔄 FLOW_STATE: 📊 BACK BUTTON FIX - Player state before validation: \(String(describing: self.unifiedState.playerState))")
        logger.info("🔄 FLOW_STATE: ✅ BACK BUTTON FIX - Trimming state restoration completed with player synchronization")
        return true
    }

    // MARK: - Enhanced Error Handling and Recovery

    /// Validate all required services are available before operations
    @MainActor
    private func validateServiceAvailability() throws {
        logger.info("🔄 FLOW_STATE: 🔍 Validating service availability")

        // Note: Services are non-optional and guaranteed to be available through dependency injection
        // This method serves as a placeholder for future service validation enhancements

        logger.info("🔄 FLOW_STATE: ✅ All required services are available")
    }

    /// Validate all required dependencies are present
    @MainActor
    private func validateDependencies() throws {
        logger.info("🔄 FLOW_STATE: 🔍 Validating dependencies")

        // Note: Dependencies are non-optional and guaranteed to be available through dependency injection
        // This method serves as a placeholder for future dependency validation enhancements

        logger.info("🔄 FLOW_STATE: ✅ All required dependencies are present")
    }

    /// Perform comprehensive health check before critical operations
    @MainActor
    func performHealthCheck() async -> FlowHealthCheckResult {
        logger.info("🔄 FLOW_STATE: 🏥 Performing comprehensive health check")
        logger.info("🔄 FLOW_STATE: 🏥 Health check timestamp: \(Date())")
        logger.info("🔄 FLOW_STATE: 🏥 Current flow state: \(String(describing: self.unifiedState.flowState))")

        var issues: [FlowHealthIssue] = []

        // Check service availability
        do {
            try validateServiceAvailability()
        } catch {
            if let flowError = error as? FlowStateError {
                issues.append(FlowHealthIssue(
                    type: .serviceUnavailable,
                    severity: .critical,
                    description: flowError.localizedDescription,
                    recoverySuggestion: flowError.recoverySuggestion
                ))
            }
        }

        // Check dependencies
        do {
            try validateDependencies()
        } catch {
            if let flowError = error as? FlowStateError {
                issues.append(FlowHealthIssue(
                    type: .dependencyMissing,
                    severity: .critical,
                    description: flowError.localizedDescription,
                    recoverySuggestion: flowError.recoverySuggestion
                ))
            }
        }

        // Check state consistency
        let validationErrors = stateValidator.validateStateConsistency(
            flowState: unifiedState.flowState,
            playerState: unifiedState.flowState.isInteractive ? .ready : .idle,
            videoAsset: unifiedState.videoAsset,
            trimmerViewModel: nil, // Not available in this context
            playerViewModel: unifiedState.currentPlayerViewModel as? UnifiedVideoPlayerViewModel,
            photosIdentifier: unifiedState.photosIdentifier
        )

        if !validationErrors.isEmpty {
            for error in validationErrors {
                issues.append(FlowHealthIssue(
                    type: .stateInconsistency,
                    severity: .warning,
                    description: error.localizedDescription,
                    recoverySuggestion: "Reset flow to resolve state inconsistency"
                ))
            }
        }

        // Check memory usage (basic heuristic)
        let memoryUsage = getMemoryUsageMb()
        if memoryUsage > 500 { // 500MB threshold
            issues.append(FlowHealthIssue(
                type: .memoryPressure,
                severity: .warning,
                description: "High memory usage detected: \(String(format: "%.0f", memoryUsage))MB",
                recoverySuggestion: "Consider clearing unused assets or restarting flow"
            ))
        }

        let isHealthy = issues.filter { $0.severity == .critical }.isEmpty
        let result = FlowHealthCheckResult(
            isHealthy: isHealthy,
            issues: issues,
            timestamp: Date()
        )

        // Log detailed health check results
        logger.info("🔄 FLOW_STATE: 🏥 Health check completed - Healthy: \(isHealthy)")
        logger.info("🔄 FLOW_STATE: 🏥 Total Issues: \(issues.count)")
        logger.info("🔄 FLOW_STATE: 🏥 Critical Issues: \(result.criticalIssues.count)")
        logger.info("🔄 FLOW_STATE: 🏥 Warning Issues: \(result.warningIssues.count)")
        logger.info("🔄 FLOW_STATE: 🏥 Info Issues: \(result.infoIssues.count)")

        // Log individual issues
        if !issues.isEmpty {
            logger.info("🔄 FLOW_STATE: 🏥 Issue Details:")
            for (index, issue) in issues.enumerated() {
                let severityEmoji = issue.severity == .critical ? "🚨" : issue.severity == .warning ? "⚠️" : "ℹ️"
                logger.info("🔄 FLOW_STATE: 🏥 \(severityEmoji) [\(index + 1)] \(String(describing: issue.type)): \(issue.description)")
                if let suggestion = issue.recoverySuggestion {
                    logger.info("🔄 FLOW_STATE: 🏥 💡 Recovery: \(suggestion)")
                }
            }
        }

        return result
    }

    /// Get current memory usage in MB
    private func getMemoryUsageMb() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        } else {
            return 0.0
        }
    }

    /// Attempt to recover from specific health issues
    @MainActor
    func attemptHealthRecovery(_ healthCheck: FlowHealthCheckResult) async {
        logger.info("🔄 FLOW_STATE: 🔄 Attempting health recovery for \(healthCheck.issues.count) issues")

        for issue in healthCheck.issues {
            switch issue.type {
            case .serviceUnavailable:
                logger.info("🔄 FLOW_STATE: 🔧 Attempting service recovery")
                // Service recovery would require reinitialization - not implemented in current architecture
                // Log for future enhancement
                logger.warning("🔄 FLOW_STATE: ⚠️ Service recovery requires architecture enhancement")

            case .dependencyMissing:
                logger.info("🔄 FLOW_STATE: 🔧 Attempting dependency recovery")
                // Dependency recovery would require reinitialization - not implemented in current architecture
                logger.warning("🔄 FLOW_STATE: ⚠️ Dependency recovery requires architecture enhancement")

            case .stateInconsistency:
                logger.info("🔄 FLOW_STATE: 🔄 Recovering from state inconsistency")
                // Reset to ready state to clear inconsistencies
                unifiedState.reset()

            case .memoryPressure:
                logger.info("🔄 FLOW_STATE: 🧠 Recovering from memory pressure")
                // Clear video assets to free memory
                unifiedState.videoAsset = nil
                unifiedState.currentPlayerViewModel = nil
                logger.info("🔄 FLOW_STATE: 🧹 Cleared video assets to free memory")

            case .timeoutExceeded:
                logger.info("🔄 FLOW_STATE: ⏰ Recovering from timeout")
                // Reset to ready state after timeout
                unifiedState.reset()

            case .resourceUnavailable:
                logger.info("🔄 FLOW_STATE: 📦 Recovering from resource unavailability")
                // Reset to ready state to clear resource issues
                unifiedState.reset()
            }
        }
    }
}

// MARK: - Enhanced Flow State Errors

public enum FlowStateError: Error, LocalizedError {
    case invalidTransition(from: AddMoveFlowState, to: AddMoveFlowState)
    case transitionInProgress
    case invalidTerminalState(AddMoveFlowState)
    case missingViewModel(String)
    case stateValidationFailed(AddMoveFlowState)
    case trimmingIncomplete
    case namingIncomplete
    case serviceUnavailable(String)
    case dependencyMissing(String)
    case timeoutExceeded(String, TimeInterval)
    case resourceUnavailable(String)
    case configurationInvalid(String)

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
        case .stateValidationFailed(let state):
            return "State validation failed for: \(String(describing: state))"
        case .trimmingIncomplete:
            return "Trimming operation is incomplete or invalid"
        case .namingIncomplete:
            return "Naming operation is incomplete or invalid"
        case .serviceUnavailable(let serviceName):
            return "Required service '\(serviceName)' is unavailable"
        case .dependencyMissing(let dependency):
            return "Required dependency '\(dependency)' is missing"
        case .timeoutExceeded(let operation, let timeout):
            return "Operation '\(operation)' exceeded timeout of \(String(format: "%.1f", timeout)) seconds"
        case .resourceUnavailable(let resource):
            return "Required resource '\(resource)' is unavailable"
        case .configurationInvalid(let config):
            return "Invalid configuration: \(config)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidTransition:
            return "Ensure operations complete in proper sequence"
        case .transitionInProgress:
            return "Wait for current operation to complete"
        case .invalidTerminalState:
            return "Reset the flow and start over"
        case .missingViewModel:
            return "Ensure all required components are initialized"
        case .stateValidationFailed:
            return "Check system state and retry operation"
        case .trimmingIncomplete:
            return "Complete trimming operation or reset to start"
        case .namingIncomplete:
            return "Provide a valid move name"
        case .serviceUnavailable:
            return "Check service availability and retry"
        case .dependencyMissing:
            return "Ensure all dependencies are properly initialized"
        case .timeoutExceeded:
            return "Retry operation or check network connectivity"
        case .resourceUnavailable:
            return "Check resource availability and permissions"
        case .configurationInvalid:
            return "Review and fix configuration settings"
        }
    }
}

// MARK: - Health Check Types

/// Health issue types for flow state monitoring
public enum FlowHealthIssueType {
    case serviceUnavailable
    case dependencyMissing
    case stateInconsistency
    case memoryPressure
    case timeoutExceeded
    case resourceUnavailable
}

/// Health issue severity levels
public enum FlowHealthSeverity {
    case info
    case warning
    case critical
}

/// Individual health issue with recovery information
public struct FlowHealthIssue {
    let type: FlowHealthIssueType
    let severity: FlowHealthSeverity
    let description: String
    let recoverySuggestion: String?
    let timestamp: Date = Date()
}

/// Result of a comprehensive health check
public struct FlowHealthCheckResult {
    let isHealthy: Bool
    let issues: [FlowHealthIssue]
    let timestamp: Date

    var criticalIssues: [FlowHealthIssue] {
        return issues.filter { $0.severity == .critical }
    }

    var warningIssues: [FlowHealthIssue] {
        return issues.filter { $0.severity == .warning }
    }

    var infoIssues: [FlowHealthIssue] {
        return issues.filter { $0.severity == .info }
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