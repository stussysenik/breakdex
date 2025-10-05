import Foundation
import AVFoundation
import OSLog

// MARK: - Unified Timecode Service
/// Provides centralized timecode calculations and validation for all components
public final class TimecodeCalculationService {

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "TimecodeCalculationService")
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "TimecodeCalculationService")

    // MARK: - Constants
    private let minimumDuration: CMTime = CMTime(seconds: 3.0, preferredTimescale: 600)
    private let timeTolerance: Double = 0.001 // 1ms tolerance
    private let frameRateTolerance: Double = 0.1

    // MARK: - Timecode Calculation

    /// Calculates unified timecode values for trimming
    public func calculateTimecode(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime,
        frameRate: Double = 30.0
    ) -> TimecodeCalculationResult {
        logger.info("🧮 Calculating timecode: start=\(startTime.seconds), end=\(endTime.seconds), duration=\(assetDuration.seconds), frameRate=\(frameRate)")

        // 🚨 CRITICAL FIX: Validate frame rate to prevent crashes with NaN/infinite values
        let validFrameRate: Double
        if frameRate.isFinite && frameRate > 0 {
            validFrameRate = frameRate
        } else {
            logger.warning("🧮 ⚠️ Invalid frame rate detected: \(frameRate), falling back to 30.0 FPS")
            diagnosticLogger.logWarning("🧮 Invalid frame rate detected, using fallback", metadata: [
                "frameRate": "\(frameRate)",
                "frameRate_isFinite": "\(frameRate.isFinite)",
                "frameRate_isNaN": "\(frameRate.isNaN)",
                "frameRate_isZero": "\(frameRate == 0)",
                "fallback_frameRate": "30.0"
            ])
            validFrameRate = 30.0
        }

        // Calculate duration
        let duration = endTime - startTime

        // Validate timecode range and collect errors
        var validationErrors: [TimecodeValidationError] = []
        let isValid = validateTimecodeRange(
            startTime: startTime,
            endTime: endTime,
            assetDuration: assetDuration,
            errors: &validationErrors
        )

        // Calculate frame information using validated frame rate
        let startFrame = Int(startTime.seconds * validFrameRate)
        let endFrame = Int(endTime.seconds * validFrameRate)
        let durationFrames = Int(duration.seconds * validFrameRate)

        // Create calculation result using validated frame rate
        let result = TimecodeCalculationResult(
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            startFrame: startFrame,
            endFrame: endFrame,
            durationFrames: durationFrames,
            frameRate: validFrameRate,
            assetDuration: assetDuration,
            isValid: isValid,
            minimumDuration: minimumDuration,
            validationErrors: validationErrors
        )

        diagnosticLogger.logDebug("🧮 Timecode calculation completed", metadata: [
            "duration": "\(duration.seconds)",
            "is_valid": "\(isValid)",
            "frame_count": "\(durationFrames)"
        ])

        return result
    }

    /// Validates timecode range for consistency
    public func validateTimecodeRange(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime,
        errors: inout [TimecodeValidationError]
    ) -> Bool {
        var isValid = true

        // Validate start time
        if startTime.seconds < 0 {
            errors.append(.negativeStartTime(startTime.seconds))
            isValid = false
        }

        // Validate end time
        if endTime.seconds > assetDuration.seconds {
            errors.append(.endTimeExceedsAsset(endTime.seconds, assetDuration.seconds))
            isValid = false
        }

        // Validate time order
        if startTime >= endTime {
            errors.append(.startTimeAfterEndTime(startTime.seconds, endTime.seconds))
            isValid = false
        }

        // Validate minimum duration
        let duration = endTime - startTime
        if duration.seconds < minimumDuration.seconds {
            errors.append(.durationTooShort(duration.seconds, minimumDuration.seconds))
            isValid = false
        }

        // Validate asset duration
        if assetDuration.seconds <= 0 {
            errors.append(.invalidAssetDuration(assetDuration.seconds))
            isValid = false
        }

        if !isValid {
            diagnosticLogger.logWarning("⚠️ Timecode validation failed", metadata: [
                "error_count": "\(errors.count)",
                "duration": "\(duration.seconds)"
            ])
        } else {
            diagnosticLogger.logDebug("✅ Timecode validation passed")
        }

        return isValid
    }

    /// Synchronizes timecode values between components
    public func synchronizeTimecode(
        source: CMTime,
        animated: CMTime,
        isDragging: Bool,
        frameRate: Double = 30.0
    ) -> SynchronizedTimecode {
        let timeDifference = abs(source.seconds - animated.seconds)
        let isSynchronized = timeDifference <= timeTolerance

        // Use appropriate time based on context
        let effectiveTime: CMTime
        if isDragging || timeDifference > timeTolerance {
            effectiveTime = source
        } else {
            effectiveTime = animated
        }

        let frame = Int(effectiveTime.seconds * frameRate)

        return SynchronizedTimecode(
            sourceTime: source,
            animatedTime: animated,
            effectiveTime: effectiveTime,
            frame: frame,
            frameRate: frameRate,
            isSynchronized: isSynchronized,
            timeDifference: timeDifference,
            isDragging: isDragging
        )
    }

    /// Calculates frame-accurate time snapping
    public func snapToFrame(
        time: CMTime,
        frameRate: Double = 30.0
    ) -> CMTime {
        let frameInterval = 1.0 / frameRate
        let frameNumber = round(time.seconds / frameInterval)
        let snappedSeconds = frameNumber * frameInterval

        return CMTime(seconds: snappedSeconds, preferredTimescale: 600)
    }

    /// Formats time for display
    public func formatTime(_ time: CMTime, includeMilliseconds: Bool = true) -> String {
        let seconds = time.seconds
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if includeMilliseconds {
            let milliseconds = Int((seconds - Double(Int(seconds))) * 1000)
            return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// Calculates duration with validation
    public func calculateValidatedDuration(
        startTime: CMTime,
        endTime: CMTime
    ) -> CMTime {
        let duration = endTime - startTime
        return duration.seconds >= 0 ? duration : .zero
    }

    /// Validates frame rate consistency
    public func validateFrameRate(
        nominalFrameRate: Double,
        actualFrameRate: Double
    ) -> FrameRateValidation {
        let difference = abs(nominalFrameRate - actualFrameRate)
        let isConsistent = difference <= frameRateTolerance

        return FrameRateValidation(
            nominalFrameRate: nominalFrameRate,
            actualFrameRate: actualFrameRate,
            difference: difference,
            isConsistent: isConsistent
        )
    }

    
    /// Validates handle constraint boundaries with minimum duration
    public func validateHandleConstraint(
        proposedTime: CMTime,
        handleType: String,
        startTime: CMTime,
        endTime: CMTime,
        minimumDuration: CMTime
    ) -> HandleConstraintValidation {
        var isValid = true
        var constraintType = HandleConstraintType.none
        var boundaryTime = proposedTime

        switch handleType.lowercased() {
        case "start":
            let limit = endTime - minimumDuration
            if proposedTime > limit {
                boundaryTime = limit
                isValid = false
                constraintType = .minimumDuration
            }
        case "end":
            let limit = startTime + minimumDuration
            if proposedTime < limit {
                boundaryTime = limit
                isValid = false
                constraintType = .minimumDuration
            }
        default:
            break
        }

        return HandleConstraintValidation(
            proposedTime: proposedTime,
            boundaryTime: boundaryTime,
            isValid: isValid,
            constraintType: constraintType,
            minimumDuration: minimumDuration,
            handleType: handleType
        )
    }

    /// Checks if a time is at a constraint boundary
    public func isAtConstraintBoundary(
        time: CMTime,
        startTime: CMTime,
        endTime: CMTime,
        minimumDuration: CMTime,
        tolerance: Double = 0.001
    ) -> Bool {
        let startBoundary = endTime - minimumDuration
        let endBoundary = startTime + minimumDuration

        return abs(time.seconds - startBoundary.seconds) < tolerance ||
               abs(time.seconds - endBoundary.seconds) < tolerance
    }
}

// MARK: - Timecode Calculation Result

public struct TimecodeCalculationResult {
    public let startTime: CMTime
    public let endTime: CMTime
    public let duration: CMTime
    public let startFrame: Int
    public let endFrame: Int
    public let durationFrames: Int
    public let frameRate: Double
    public let assetDuration: CMTime
    public let isValid: Bool
    public let minimumDuration: CMTime
    public let validationErrors: [TimecodeValidationError]

    public var isDurationTooShort: Bool {
        duration.seconds < minimumDuration.seconds
    }

    public var formattedStartTime: String {
        TimecodeFormatter.format(time: startTime)
    }

    public var formattedEndTime: String {
        TimecodeFormatter.format(time: endTime)
    }

    public var formattedDuration: String {
        TimecodeFormatter.format(time: duration)
    }
}

// MARK: - Synchronized Timecode

public struct SynchronizedTimecode {
    public let sourceTime: CMTime
    public let animatedTime: CMTime
    public let effectiveTime: CMTime
    public let frame: Int
    public let frameRate: Double
    public let isSynchronized: Bool
    public let timeDifference: Double
    public let isDragging: Bool

    public var formattedTime: String {
        TimecodeFormatter.format(time: effectiveTime)
    }

    public var formattedFrame: String {
        "Frame \(frame)"
    }
}

// MARK: - Frame Rate Validation

public struct FrameRateValidation {
    public let nominalFrameRate: Double
    public let actualFrameRate: Double
    public let difference: Double
    public let isConsistent: Bool
}

// MARK: - Handle Constraint Types

public enum HandleConstraintType {
    case none
    case minimumDuration
    case assetBoundary
    case physicalBoundary
}

// MARK: - Handle Constraint Validation

public struct HandleConstraintValidation {
    public let proposedTime: CMTime
    public let boundaryTime: CMTime
    public let isValid: Bool
    public let constraintType: HandleConstraintType
    public let minimumDuration: CMTime
    public let handleType: String

    public var isConstrained: Bool {
        !isValid || constraintType != .none
    }

    public var constraintDescription: String {
        switch constraintType {
        case .none:
            return "No constraint"
        case .minimumDuration:
            return "Minimum duration (\(minimumDuration.seconds)s) would be violated"
        case .assetBoundary:
            return "Asset boundary would be exceeded"
        case .physicalBoundary:
            return "Physical boundary reached"
        }
    }
}

// MARK: - Timecode Validation Errors

public enum TimecodeValidationError {
    case negativeStartTime(Double)
    case endTimeExceedsAsset(Double, Double)
    case startTimeAfterEndTime(Double, Double)
    case durationTooShort(Double, Double)
    case invalidAssetDuration(Double)

    var localizedDescription: String {
        switch self {
        case .negativeStartTime(let time):
            return "Start time cannot be negative: \(time)s"
        case .endTimeExceedsAsset(let endTime, let assetDuration):
            return "End time (\(endTime)s) exceeds asset duration (\(assetDuration)s)"
        case .startTimeAfterEndTime(let startTime, let endTime):
            return "Start time (\(startTime)s) must be before end time (\(endTime)s)"
        case .durationTooShort(let duration, let minimum):
            return "Duration (\(duration)s) is too short (minimum: \(minimum)s)"
        case .invalidAssetDuration(let duration):
            return "Invalid asset duration: \(duration)s"
        }
    }
}

// MARK: - Timecode Service Protocol

public protocol TimecodeCalculationServiceProtocol {
    func calculateTimecode(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime,
        frameRate: Double
    ) -> TimecodeCalculationResult

    func validateTimecodeRange(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime,
        errors: inout [TimecodeValidationError]
    ) -> Bool

    func synchronizeTimecode(
        source: CMTime,
        animated: CMTime,
        isDragging: Bool,
        frameRate: Double
    ) -> SynchronizedTimecode

    func snapToFrame(time: CMTime, frameRate: Double) -> CMTime
    func formatTime(_ time: CMTime, includeMilliseconds: Bool) -> String
    func calculateValidatedDuration(startTime: CMTime, endTime: CMTime) -> CMTime
    func validateFrameRate(nominalFrameRate: Double, actualFrameRate: Double) -> FrameRateValidation
    func validateHandleConstraint(
        proposedTime: CMTime,
        handleType: String,
        startTime: CMTime,
        endTime: CMTime,
        minimumDuration: CMTime
    ) -> HandleConstraintValidation

    func isAtConstraintBoundary(
        time: CMTime,
        startTime: CMTime,
        endTime: CMTime,
        minimumDuration: CMTime,
        tolerance: Double
    ) -> Bool
}

// MARK: - Protocol Conformance

extension TimecodeCalculationService: TimecodeCalculationServiceProtocol {}