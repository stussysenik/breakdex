import Foundation
import CoreMedia
import OSLog

/// A centralized utility for converting CMTime to precise, display-ready strings.
/// This ensures WYSIWYG accuracy across all UI components.
public enum TimecodeFormatter {

    // MARK: - Enhanced Diagnostic Logging
    private static let logger = Logger(subsystem: "com.breakingflashcards", category: "TimecodeFormatter")

    /// Formats a CMTime value into a "mm:ss.SSS" string.
    ///
    /// This function uses `CMTimeConvertScale` to prevent floating-point inaccuracies,
    /// ensuring that the displayed milliseconds are perfectly rounded and reliable.
    ///
    /// - Parameter time: The `CMTime` to format.
    /// - Returns: A string representation, e.g., "00:03.123".
    public static func format(time: CMTime) -> String {
        // Ensure the time is valid, otherwise return a default placeholder.
        guard time.isValid && !time.isIndefinite else {
            logger.warning("⚠️ Invalid time provided to formatter, using default")
            return "00:00.000"
        }

        // Convert the CMTime to a total number of milliseconds, using a timescale of 1000.
        // This is the key to avoiding floating-point precision errors.
        // .roundHalfAwayFromZero ensures rounding is predictable (e.g., 33.333...ms).
        let totalMilliseconds = CMTimeConvertScale(time, timescale: 1000, method: .roundHalfAwayFromZero).value

        let seconds = totalMilliseconds / 1000
        let minutes = seconds / 60
        let displaySeconds = seconds % 60
        let displayMilliseconds = totalMilliseconds % 1000

        let formattedString = String(format: "%02d:%02d.%03d", minutes, displaySeconds, displayMilliseconds)

        // Diagnostic logging for precision verification
        logger.debug("🕐 Time formatted - input: \(time.seconds)s, output: \(formattedString)")

        return formattedString
    }

    /// Formats duration with specific handling for minimum duration validation
    /// - Parameters:
    ///   - time: The duration time to format
    ///   - minimumDuration: The minimum allowed duration for validation
    /// - Returns: Formatted duration string
    public static func formatDuration(time: CMTime, minimumDuration: CMTime? = nil) -> String {
        let formattedDuration = format(time: time)

        if let minimumDuration = minimumDuration {
            let isBelowMinimum = time.seconds < minimumDuration.seconds
            logger.debug("⏱️ Duration formatted with validation - duration: \(time.seconds)s, minimum: \(minimumDuration.seconds)s, below_min: \(isBelowMinimum), formatted: \(formattedDuration)")
        }

        return formattedDuration
    }
}