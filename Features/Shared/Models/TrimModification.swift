import Foundation
import AVFoundation

// MARK: - Video Rotation Enum
/// Video rotation angles with 90-degree increments
public enum VideoRotation: Int, CaseIterable, Codable {
    case degrees0 = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270

    /// Get the rotation in radians
    public var radians: Double {
        return Double(self.rawValue) * .pi / 180.0
    }

    /// Get the clockwise rotation value for AVFoundation
    public var avFoundationRotation: CGFloat {
        switch self {
        case .degrees0:
            return 0
        case .degrees90:
            return 90
        case .degrees180:
            return 180
        case .degrees270:
            return 270
        }
    }

    /// Human-readable description
    public var description: String {
        switch self {
        case .degrees0:
            return "0°"
        case .degrees90:
            return "90°"
        case .degrees180:
            return "180°"
        case .degrees270:
            return "270°"
        }
    }

    /// Rotate to the next 90-degree angle (clockwise)
    public func rotatedClockwise() -> VideoRotation {
        switch self {
        case .degrees0:
            return .degrees90
        case .degrees90:
            return .degrees180
        case .degrees180:
            return .degrees270
        case .degrees270:
            return .degrees0
        }
    }

    /// Rotate to the previous 90-degree angle (counter-clockwise)
    public func rotatedCounterClockwise() -> VideoRotation {
        switch self {
        case .degrees0:
            return .degrees270
        case .degrees90:
            return .degrees0
        case .degrees180:
            return .degrees90
        case .degrees270:
            return .degrees180
        }
    }
}

// MARK: - Trim Modification Model
/// Tracks user-applied trimming and rotation modifications
/// Essentialist model with precise timecode support for mechanical watch accuracy
public struct TrimModification: Codable, Equatable, Hashable {
    // MARK: - Properties
    /// Start time of the trim in milliseconds (precision timing)
    public let startTimeMs: Int64

    /// End time of the trim in milliseconds (precision timing)
    public let endTimeMs: Int64

    /// Video rotation applied
    public let rotation: VideoRotation

    /// Whether the modification has been applied to the asset
    public let isApplied: Bool

    /// Unique identifier for this modification
    public let id: UUID

    /// Timestamp when modification was created
    public let createdTimestamp: Date

    // MARK: - Computed Properties
    /// Trim duration in milliseconds
    public var durationMs: Int64 {
        return max(0, endTimeMs - startTimeMs)
    }

    /// Trim duration in seconds
    public var durationSeconds: Double {
        return Double(durationMs) / 1000.0
    }

    /// Start time in seconds (compatibility with existing code)
    public var startTimeSeconds: Double {
        return Double(startTimeMs) / 1000.0
    }

    /// End time in seconds (compatibility with existing code)
    public var endTimeSeconds: Double {
        return Double(endTimeMs) / 1000.0
    }

    /// CMTime representation for AVFoundation
    public var startTimeCMTime: CMTime {
        return CMTime(value: startTimeMs, timescale: 1000)
    }

    /// CMTime representation for AVFoundation
    public var endTimeCMTime: CMTime {
        return CMTime(value: endTimeMs, timescale: 1000)
    }

    /// Check if this is a valid trim (meets minimum duration requirements)
    public var isValid: Bool {
        return durationMs >= 3000 // Minimum 3 seconds as per spec
    }

    // MARK: - Initialization
    public init(
        startTimeMs: Int64,
        endTimeMs: Int64,
        rotation: VideoRotation = .degrees0,
        isApplied: Bool = false
    ) {
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.rotation = rotation
        self.isApplied = isApplied
        self.id = UUID()
        self.createdTimestamp = Date()
    }

    /// Convenience initializer with seconds (for compatibility with existing code)
    public init(
        startTimeSeconds: Double,
        endTimeSeconds: Double,
        rotation: VideoRotation = .degrees0,
        isApplied: Bool = false
    ) {
        self.startTimeMs = Int64(startTimeSeconds * 1000)
        self.endTimeMs = Int64(endTimeSeconds * 1000)
        self.rotation = rotation
        self.isApplied = isApplied
        self.id = UUID()
        self.createdTimestamp = Date()
    }

    // MARK: - Methods
    /// Create a new modification with updated start time
    public func withStartTime(_ newStartTimeMs: Int64) -> TrimModification {
        return TrimModification(
            startTimeMs: newStartTimeMs,
            endTimeMs: endTimeMs,
            rotation: rotation,
            isApplied: false // Reset applied flag when modified
        )
    }

    /// Create a new modification with updated end time
    public func withEndTime(_ newEndTimeMs: Int64) -> TrimModification {
        return TrimModification(
            startTimeMs: startTimeMs,
            endTimeMs: newEndTimeMs,
            rotation: rotation,
            isApplied: false // Reset applied flag when modified
        )
    }

    /// Create a new modification with updated rotation
    public func withRotation(_ newRotation: VideoRotation) -> TrimModification {
        return TrimModification(
            startTimeMs: startTimeMs,
            endTimeMs: endTimeMs,
            rotation: newRotation,
            isApplied: false // Reset applied flag when modified
        )
    }

    /// Create a new modification marked as applied
    public func applied() -> TrimModification {
        return TrimModification(
            startTimeMs: startTimeMs,
            endTimeMs: endTimeMs,
            rotation: rotation,
            isApplied: true
        )
    }

    /// Validate that the trim constraints are satisfied
    public func validateConstraints() -> TrimValidationResult {
        var errors: [TrimValidationError] = []

        // Check minimum duration
        if durationMs < 3000 {
            errors.append(.minimumDurationViolation)
        }

        // Check start/end order
        if startTimeMs >= endTimeMs {
            errors.append(.invalidTimeRange)
        }

        // Check for negative times
        if startTimeMs < 0 || endTimeMs < 0 {
            errors.append(.negativeTime)
        }

        return TrimValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }

    // MARK: - Hashable Conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(startTimeMs)
        hasher.combine(endTimeMs)
        hasher.combine(rotation)
        hasher.combine(isApplied)
        hasher.combine(id)
        hasher.combine(createdTimestamp)
    }
}

// MARK: - Validation Types
/// Result of trim validation
public struct TrimValidationResult {
    public let isValid: Bool
    public let errors: [TrimValidationError]
}

/// Types of validation errors for trims
public enum TrimValidationError: String, CaseIterable, Codable, Hashable {
    case minimumDurationViolation = "Trim duration must be at least 3 seconds"
    case invalidTimeRange = "Start time must be before end time"
    case negativeTime = "Time values cannot be negative"

    public var description: String {
        return self.rawValue
    }
}

// MARK: - Convenience Extensions
extension TrimModification {
    /// Create a trim modification for the full duration of an asset
    public static func fullDuration(for asset: AVAsset, rotation: VideoRotation = .degrees0) async -> TrimModification? {
        do {
            let duration = try await asset.load(.duration)
            let durationMs = Int64(duration.seconds * 1000)

            return TrimModification(
                startTimeMs: 0,
                endTimeMs: durationMs,
                rotation: rotation,
                isApplied: false
            )
        } catch {
            Logger.shared.error("Failed to create full duration trim: \(error.localizedDescription)", emoji: "❌")
            return nil
        }
    }

    /// Create a trim modification with mechanical watch precision
    public static func preciseTrim(
        startTimeMs: Int64,
        endTimeMs: Int64,
        rotation: VideoRotation = .degrees0
    ) -> TrimModification {
        // Ensure millisecond precision by rounding to nearest millisecond
        let preciseStart = (startTimeMs / 1) * 1
        let preciseEnd = (endTimeMs / 1) * 1

        return TrimModification(
            startTimeMs: preciseStart,
            endTimeMs: preciseEnd,
            rotation: rotation,
            isApplied: false
        )
    }
}