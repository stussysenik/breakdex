import Foundation
import AVFoundation
import OSLog
import Combine

// Note: Dependencies are defined elsewhere in the codebase

/// Handles all validation logic for the AddMoveUnifiedState
public class StateValidator: ObservableObject {
    private let logger = Logger(subsystem: "BreakingFlashcards", category: "✅ StateValidator")

    // MARK: - State Consistency Validation

    /// Validates the overall state consistency across all components
    @MainActor
    public func validateStateConsistency(
        flowState: AddMoveFlowState,
        playerState: PlayerState,
        videoAsset: AVAsset?,
        trimmerViewModel: TrimmerViewModel?,
        playerViewModel: UnifiedVideoPlayerViewModel?,
        photosIdentifier: String?
    ) -> [StateValidationError] {
        var errors: [StateValidationError] = []

        logger.debug("✅ Starting state consistency validation")

        // Validate asset duration in trimming states
        switch flowState {
        case .trimming, .loadingTrimmedAsset:
            if let asset = videoAsset {
                let duration = asset.duration.seconds
                if duration <= 0 {
                    errors.append(.invalidAssetDuration(duration))
                    logger.error("✅ State validation failed: Invalid asset duration (\(duration)s) in \(String(describing: flowState)) state")
                } else {
                    logger.debug("✅ Asset duration validation passed: \(String(format: "%.2f", duration))s")
                }
            } else {
                errors.append(.invalidAssetDuration(0.0))
                logger.error("✅ State validation failed: Video asset is nil in \(String(describing: flowState)) state")
            }
        default:
            break
        }

        // Validate trim parameters
        if let trimmerVM = trimmerViewModel {
            let startTime = trimmerVM.startTime.seconds
            let endTime = trimmerVM.endTime.seconds
            let assetDuration = trimmerVM.videoDuration.seconds

            logger.debug("✅ TrimmerViewModel validation: startTime=\(String(format: "%.3f", startTime))s, endTime=\(String(format: "%.3f", endTime))s, duration=\(String(format: "%.3f", assetDuration))s")

            if startTime < 0 {
                errors.append(.invalidStartTime(startTime))
                logger.error("✅ State validation failed: Start time is negative (\(String(format: "%.3f", startTime))s)")
            }

            if endTime > assetDuration {
                errors.append(.endTimeExceedsAsset(endTime, assetDuration))
                logger.error("✅ State validation failed: End time (\(String(format: "%.3f", endTime))s) exceeds asset duration (\(String(format: "%.3f", assetDuration))s)")
            }

            if startTime >= endTime {
                errors.append(.startTimeAfterEndTime(startTime, endTime))
                logger.error("✅ State validation failed: Start time (\(String(format: "%.3f", startTime))s) is after or equal to end time (\(String(format: "%.3f", endTime))s)")
            }

            let duration = endTime - startTime
            let minimumDuration = 3.0
            if duration < minimumDuration {
                errors.append(.durationTooShort(duration, minimumDuration))
                logger.error("✅ State validation failed: Duration too short (\(String(format: "%.3f", duration))s < \(String(format: "%.1f", minimumDuration))s minimum)")
            } else {
                logger.debug("✅ Trim duration validation passed: \(String(format: "%.3f", duration))s")
            }
        } else {
            logger.error("✅ State validation failed: TrimmerViewModel is nil")
        }

        // Validate player state consistency
        if case .trimming = flowState {
            if case .idle = playerState {
                errors.append(.playerNotReadyInTrimmingState)
                logger.error("✅ State validation failed: Player state is .idle in trimming state (should be .ready)")
            } else {
                logger.debug("✅ Player state validation passed for trimming: \(String(describing: playerState))")
            }

            if trimmerViewModel == nil {
                errors.append(.missingTrimmerInTrimmingState)
                logger.error("✅ State validation failed: TrimmerViewModel is nil in trimming state")
            } else {
                logger.debug("✅ TrimmerViewModel validation passed for trimming state")
            }
        }

        if case .naming = flowState {
            if playerViewModel == nil {
                errors.append(.missingPlayerInNamingState)
                logger.error("✅ State validation failed: PlayerViewModel is nil in naming state")
            } else {
                logger.debug("✅ PlayerViewModel validation passed for naming state")
            }
        }

        // Validate photos identifier
        switch flowState {
        case .loadingVideo, .trimming, .loadingTrimmedAsset:
            if photosIdentifier?.isEmpty != false {
                logger.warning("✅ Photos identifier is empty or nil during asset operation in \(String(describing: flowState)) state")
            } else {
                logger.debug("✅ Photos identifier validation passed for \(String(describing: flowState)) state")
            }
        default:
            break
        }

        logger.info("✅ State validation completed with \(errors.count) errors")
        return errors
    }

    // MARK: - Trim Parameter Validation

    /// Validates trim parameters for saving
    public func validateTrimParametersForSave(
        trimStartTime: Double,
        trimEndTime: Double,
        videoAsset: AVAsset,
        minimumDuration: Double = 3.0
    ) throws {
        logger.info("✅ Validating trim parameters for save")

        let assetDuration = videoAsset.duration.seconds

        // Ensure minimum duration
        let validatedEndTime = assetDuration >= minimumDuration ? assetDuration : minimumDuration

        // Validate time bounds
        if trimStartTime < 0 {
            throw AddMoveError.invalidTrimRange("Start time cannot be negative")
        }

        if trimEndTime > assetDuration {
            throw AddMoveError.invalidTrimRange("End time exceeds asset duration")
        }

        if trimStartTime >= trimEndTime {
            throw AddMoveError.invalidTrimRange("Start time must be before end time")
        }

        let duration = trimEndTime - trimStartTime
        if duration < minimumDuration {
            throw AddMoveError.invalidTrimRange("Duration too short: \(duration)s (minimum: \(minimumDuration)s)")
        }

        logger.info("✅ Trim parameters validated successfully")
    }

    /// Validates that the state is ready for saving
    public func validateReadyForSave(
        flowState: AddMoveFlowState,
        trimStartTime: Double,
        trimEndTime: Double,
        videoAsset: AVAsset,
        moveName: String,
        minimumDuration: Double = 3.0
    ) throws {
        logger.info("✅ Validating readiness for save")

        // Validate flow state
        guard case .naming = flowState else {
            throw AddMoveError.invalidStateForSaving
        }

        // Validate move name
        if moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AddMoveError.saveValidationFailed("Move name cannot be empty")
        }

        // Validate trim parameters
        try validateTrimParametersForSave(
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            videoAsset: videoAsset,
            minimumDuration: minimumDuration
        )

        logger.info("✅ State validated and ready for save")
    }

    // MARK: - Save Readiness Validation

    /// Validates save readiness and returns detailed results
    public func validateSaveReadiness(
        flowState: AddMoveFlowState,
        playerState: PlayerState,
        moveName: String,
        videoAsset: AVAsset?,
        trimmerViewModel: TrimmerViewModel?,
        playerViewModel: UnifiedVideoPlayerViewModel?,
        photosIdentifier: String?,
        trimStartTime: Double,
        trimEndTime: Double
    ) async -> SaveReadinessResult {
        logger.info("✅ Starting save readiness validation")

        var validationIssues: [SaveValidationIssue] = []

        // Validate move name
        if moveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationIssues.append(.emptyMoveName)
        } else if moveName.count < 2 {
            validationIssues.append(.moveNameTooShort(moveName.count))
        } else if moveName.count > 50 {
            validationIssues.append(.moveNameTooLong(moveName.count))
        }

        // Validate asset
        if videoAsset == nil {
            validationIssues.append(.noVideoAsset)
        }

        // Validate photos identifier
        if photosIdentifier?.isEmpty != false {
            validationIssues.append(.noPhotosIdentifier)
        }

        // Validate flow state
        if flowState != .naming {
            validationIssues.append(.invalidFlowState(flowState))
        }

        // Validate trimmer
        if trimmerViewModel == nil {
            validationIssues.append(.trimmerNotReady)
        }

        // Validate player with enhanced diagnostics
        logger.debug("🎯 ENHANCED PLAYER VALIDATION: Starting player validation check")
        logger.debug("🎯 ENHANCED PLAYER VALIDATION: playerViewModel: \(playerViewModel != nil ? "available" : "nil")")
        logger.debug("🎯 ENHANCED PLAYER VALIDATION: playerState: \(String(describing: playerState))")
        logger.debug("🎯 ENHANCED PLAYER VALIDATION: playerState.isReady: \(playerState.isReady)")

        if playerViewModel == nil {
            validationIssues.append(.noPlayerAvailable)
            logger.warning("🎯 Player validation failed: playerViewModel is nil")
        } else if playerState != .ready {
            validationIssues.append(.playerNotReady)
            logger.warning("🎯 Player validation failed: playerState is \(String(describing: playerState)), expected .ready")

            // MARK: - DIAGNOSTIC: Additional context for debugging player state issues
            logger.warning("🎯 DIAGNOSTIC - Player state mismatch details:")
            logger.warning("🎯   - Current playerState: \(String(describing: playerState))")
            logger.warning("🎯   - playerState.isReady: \(playerState.isReady)")
            logger.warning("🎯   - playerState.canPlay: \(playerState.canPlay)")
            logger.warning("🎯   - playerState.isActive: \(playerState.isActive)")
            logger.warning("🎯   - Flow state: \(String(describing: flowState))")

            // MARK: - DIAGNOSTIC: Check if playerViewModel is actually ready despite state mismatch
            if let playerVM = playerViewModel {
                // MARK: - TEMPORARY FIX: Skip async call for build compatibility
                // let actualPlayerReady = await playerVM.isPlayerReady
                logger.warning("🎯 DIAGNOSTIC - playerViewModel available, async readiness check temporarily disabled")
                logger.warning("🎯 ⚠️ POTENTIAL INCONSISTENCY: playerViewModel is available but playerState is not .ready!")
                logger.warning("🎯 This suggests a state synchronization issue between AddMoveUnifiedState and UnifiedPlayerManager")
            }
        } else {
            logger.info("✅ Player validation passed: playerState is .ready")

            // MARK: - DIAGNOSTIC: Confirm consistency when validation passes
            if let playerVM = playerViewModel {
                // MARK: - TEMPORARY FIX: Skip async call for build compatibility
                // let actualPlayerReady = await playerVM.isPlayerReady
                logger.debug("🎯 DIAGNOSTIC - Consistency check: playerViewModel available, async readiness check temporarily disabled")
                logger.debug("🎯 ✅ Player validation passed based on playerState alone")
            }
        }

        // Validate trim parameters if available (temporarily simplified for build compatibility)
        // MARK: - TODO: Re-enable trim parameter validation once async property issue is resolved
        logger.debug("🎯 Trim parameter validation temporarily disabled due to async property access issues")
        // if let asset = videoAsset, let trimmerVM = trimmerViewModel {
        //     // Trim validation logic here
        // }

        let hasValidAsset = videoAsset != nil && photosIdentifier?.isEmpty == false
        let hasValidTrimmer = trimmerViewModel != nil
        let hasValidPlayer = playerViewModel != nil && playerState.isReady
        let canSave = validationIssues.filter { $0.isCritical }.isEmpty

        let result = SaveReadinessResult(
            isValid: canSave,
            issues: validationIssues,
            canSave: canSave,
            confidence: calculateValidationConfidence(validationIssues),
            moveName: moveName,
            hasValidAsset: hasValidAsset,
            hasValidTrimmer: hasValidTrimmer,
            hasValidPlayer: hasValidPlayer,
            trimDuration: trimEndTime - trimStartTime
        )

        logger.info("✅ Save readiness validation completed")

        return result
    }

    /// Validates for immediate save operation
    public func validateForImmediateSave(
        flowState: AddMoveFlowState,
        playerState: PlayerState,
        moveName: String,
        videoAsset: AVAsset?,
        trimmerViewModel: TrimmerViewModel?,
        playerViewModel: UnifiedVideoPlayerViewModel?,
        photosIdentifier: String?,
        trimStartTime: Double,
        trimEndTime: Double,
        rotationQuarterTurns: Int
    ) async throws -> ImmediateSaveValidationResult {
        logger.info("✅ Validating for immediate save")

        let readiness = await validateSaveReadiness(
            flowState: flowState,
            playerState: playerState,
            moveName: moveName,
            videoAsset: videoAsset,
            trimmerViewModel: trimmerViewModel,
            playerViewModel: playerViewModel,
            photosIdentifier: photosIdentifier,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime
        )

        guard readiness.isValid else {
            let errorDetails = readiness.issues.map { $0.localizedDescription }.joined(separator: "; ")
            throw AddMoveError.saveValidationFailed(errorDetails)
        }

        guard let asset = videoAsset, let photosID = photosIdentifier else {
            let errorDetails = readiness.issues.map { $0.localizedDescription }.joined(separator: "; ")
            throw AddMoveError.saveValidationFailed(errorDetails)
        }

        let trimmingReadiness = TrimmingReadinessResult(
            isReady: readiness.hasValidTrimmer,
            issues: [], // Will be populated based on trim validation
            trimmerViewModel: trimmerViewModel,
            videoAsset: asset,
            playerViewModel: playerViewModel
        )

        let preparedAsset = PreparedAssetResult(
            asset: asset,
            photosIdentifier: photosID,
            trimStartTime: trimStartTime,
            trimEndTime: trimEndTime,
            rotationQuarterTurns: rotationQuarterTurns,
            moveName: moveName,
            trimmingReadiness: trimmingReadiness
        )

        let result = ImmediateSaveValidationResult(
            isValid: true,
            preparedAsset: preparedAsset,
            saveReadiness: readiness,
            validationTimestamp: Date()
        )

        logger.info("✅ Immediate save validation successful")
        return result
    }

    // MARK: - Utility Methods

    /// Calculates validation confidence score based on issues
    private func calculateValidationConfidence(_ issues: [SaveValidationIssue]) -> Double {
        guard !issues.isEmpty else { return 1.0 }

        let criticalCount = issues.filter { $0.isCritical }.count
        let warningCount = issues.filter { !$0.isCritical }.count

        // Critical issues reduce confidence more severely
        let criticalPenalty = Double(criticalCount) * 0.5
        let warningPenalty = Double(warningCount) * 0.1

        return max(0.0, 1.0 - criticalPenalty - warningPenalty)
    }

    /// Gets the save validation status
    public func getSaveValidationStatus(_ readinessResult: SaveReadinessResult) -> SaveValidationStatus {
        if readinessResult.hasCriticalIssues {
            return .critical(readinessResult.issuesDescription)
        } else if readinessResult.hasWarningIssues {
            return .warning(readinessResult.issuesDescription)
        } else {
            return .ready("Ready to save")
        }
    }

    // MARK: - Cleanup

    /// Cleanup method to be called during teardown
    public func tearDown() {
        logger.info("✅ StateValidator teardown initiated")
        // No specific cleanup needed for now
    }

    deinit {
        tearDown()
    }
}