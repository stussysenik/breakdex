import Foundation
import AVFoundation
import OSLog

// MARK: - Unified Timecode Service
/// Provides centralized timecode calculations and validation for all components
@MainActor
public class TimecodeCalculationService: ObservableObject {

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.breakingflashcards", category: "TimecodeCalculationService")
    private let diagnosticLogger = DiagnosticLoggingHelper(category: "TimecodeCalculationService")

    // MARK: - Published Properties
    @Published public private(set) var lastCalculation: TimecodeCalculationResult?
    @Published public private(set) var validationErrors: [TimecodeValidationError] = []

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
        logger.info("🧮 Calculating timecode", metadata: [
            "start_time": "\(startTime.seconds)",
            "end_time": "\(endTime.seconds)",
            "asset_duration": "\(assetDuration.seconds)",
            "frame_rate": "\(frameRate)"
        ])

        // Calculate duration
        let duration = endTime - startTime
        let isValid = validateTimecodeRange(startTime: startTime, endTime: endTime, assetDuration: assetDuration)

        // Calculate frame information
        let startFrame = Int(startTime.seconds * frameRate)
        let endFrame = Int(endTime.seconds * frameRate)
        let durationFrames = Int(duration.seconds * frameRate)

        // Create calculation result
        let result = TimecodeCalculationResult(
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            startFrame: startFrame,
            endFrame: endFrame,
            durationFrames: durationFrames,
            frameRate: frameRate,
            assetDuration: assetDuration,
            isValid: isValid,
            minimumDuration: minimumDuration,
            validationErrors: validationErrors
        )

        // Store result
        lastCalculation = result

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
        assetDuration: CMTime
    ) -> Bool {
        validationErrors.removeAll()

        var isValid = true

        // Validate start time
        if startTime.seconds < 0 {
            validationErrors.append(.negativeStartTime(startTime.seconds))
            isValid = false
        }

        // Validate end time
        if endTime.seconds > assetDuration.seconds {
            validationErrors.append(.endTimeExceedsAsset(endTime.seconds, assetDuration.seconds))
            isValid = false
        }

        // Validate time order
        if startTime >= endTime {
            validationErrors.append(.startTimeAfterEndTime(startTime.seconds, endTime.seconds))
            isValid = false
        }

        // Validate minimum duration
        let duration = endTime - startTime
        if duration.seconds < minimumDuration.seconds {
            validationErrors.append(.durationTooShort(duration.seconds, minimumDuration.seconds))
            isValid = false
        }

        // Validate asset duration
        if assetDuration.seconds <= 0 {
            validationErrors.append(.invalidAssetDuration(assetDuration.seconds))
            isValid = false
        }

        if !isValid {
            diagnosticLogger.logWarning("⚠️ Timecode validation failed", metadata: [
                "error_count": "\(validationErrors.count)",
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

    /// Resets the service state
    public func reset() {
        lastCalculation = nil
        validationErrors.removeAll()

        diagnosticLogger.logDebug("🔄 Timecode service reset")
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
        TimecodeCalculationService().formatTime(startTime)
    }

    public var formattedEndTime: String {
        TimecodeCalculationService().formatTime(endTime)
    }

    public var formattedDuration: String {
        TimecodeCalculationService().formatTime(duration)
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
        TimecodeCalculationService().formatTime(effectiveTime)
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

@MainActor
public protocol TimecodeCalculationServiceProtocol: ObservableObject {
    var lastCalculation: TimecodeCalculationResult? { get }
    var validationErrors: [TimecodeValidationError] { get }

    func calculateTimecode(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime,
        frameRate: Double
    ) -> TimecodeCalculationResult

    func validateTimecodeRange(
        startTime: CMTime,
        endTime: CMTime,
        assetDuration: CMTime
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
    func reset()
}

// MARK: - Protocol Conformance

extension TimecodeCalculationService: TimecodeCalculationServiceProtocol {}