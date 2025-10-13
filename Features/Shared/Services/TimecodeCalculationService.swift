// import Foundation
// import AVFoundation

// // MARK: - Timecode Calculation Service
// /// Service for timecode calculations and time-related video operations
// /// Provides utilities for converting between different time formats and calculating time intervals
// class TimecodeCalculationService {

//     // MARK: - Initialization
//     init() {}

//     // MARK: - Public Methods

//     /// Convert seconds to timecode string format (HH:MM:SS)
//     /// - Parameter seconds: Time in seconds
//     /// - Returns: Formatted timecode string
//     func secondsToTimecode(_ seconds: TimeInterval) -> String {
//         let totalSeconds = Int(seconds)
//         let hours = totalSeconds / 3600
//         let minutes = (totalSeconds % 3600) / 60
//         let secs = totalSeconds % 60

//         if hours > 0 {
//             return String(format: "%02d:%02d:%02d", hours, minutes, secs)
//         } else {
//             return String(format: "%02d:%02d", minutes, secs)
//         }
//     }

//     /// Convert seconds to timecode string with milliseconds (HH:MM:SS.mmm)
//     /// - Parameter seconds: Time in seconds
//     /// - Returns: Formatted timecode string with milliseconds
//     func secondsToTimecodeWithMilliseconds(_ seconds: TimeInterval) -> String {
//         let totalSeconds = Int(seconds)
//         let hours = totalSeconds / 3600
//         let minutes = (totalSeconds % 3600) / 60
//         let secs = totalSeconds % 60
//         let milliseconds = Int((seconds - Double(totalSeconds)) * 1000)

//         if hours > 0 {
//             return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, milliseconds)
//         } else {
//             return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
//         }
//     }

//     /// Convert timecode string to seconds
//     /// - Parameter timecode: Timecode string in format "HH:MM:SS" or "MM:SS"
//     /// - Returns: Time in seconds, or nil if parsing fails
//     func timecodeToSeconds(_ timecode: String) -> TimeInterval? {
//         let components = timecode.split(separator: ":")

//         guard components.count == 2 || components.count == 3 else {
//             return nil
//         }

//         var hours = 0
//         var minutes = 0
//         var seconds = 0

//         if components.count == 3 {
//             // HH:MM:SS format
//             guard let h = Int(components[0]),
//                   let m = Int(components[1]),
//                   let s = Int(components[2]) else {
//                 return nil
//             }
//             hours = h
//             minutes = m
//             seconds = s
//         } else {
//             // MM:SS format
//             guard let m = Int(components[0]),
//                   let s = Int(components[1]) else {
//                 return nil
//             }
//             minutes = m
//             seconds = s
//         }

//         return TimeInterval(hours * 3600 + minutes * 60 + seconds)
//     }

//     /// Calculate the duration between two time points
//     /// - Parameters:
//     ///   - startTime: Start time in seconds
//     ///   - endTime: End time in seconds
//     /// - Returns: Duration in seconds
//     func calculateDuration(from startTime: TimeInterval, to endTime: TimeInterval) -> TimeInterval {
//         return max(0, endTime - startTime)
//     }

//     /// Convert CMTime to seconds
//     /// - Parameter cmTime: CMTime value
//     /// - Returns: Time in seconds
//     func cmTimeToSeconds(_ cmTime: CMTime) -> TimeInterval {
//         return cmTime.seconds
//     }

//     /// Convert seconds to CMTime
//     /// - Parameter seconds: Time in seconds
//     /// - Returns: CMTime value
//     func secondsToCMTime(_ seconds: TimeInterval) -> CMTime {
//         return CMTime(seconds: seconds, preferredTimescale: 600)
//     }

//     /// Convert frame count to seconds
//     /// - Parameters:
//     ///   - frameCount: Number of frames
//     ///   - frameRate: Frame rate (frames per second)
//     /// - Returns: Time in seconds
//     func framesToSeconds(_ frameCount: Int, frameRate: Float) -> TimeInterval {
//         return TimeInterval(frameCount) / TimeInterval(frameRate)
//     }

//     /// Convert seconds to frame count
//     /// - Parameters:
//     ///   - seconds: Time in seconds
//     ///   - frameRate: Frame rate (frames per second)
//     /// - Returns: Frame count
//     func secondsToFrames(_ seconds: TimeInterval, frameRate: Float) -> Int {
//         return Int(seconds * TimeInterval(frameRate))
//     }

//     /// Get the frame rate of an AVAsset
//     /// - Parameter asset: The AVAsset to inspect
//     /// - Returns: Nominal frame rate, or nil if unavailable
//     func getFrameRate(of asset: AVAsset) async -> Float? {
//         do {
//             let tracks = try await asset.loadTracks(withMediaType: .video)
//             guard let videoTrack = tracks.first else { return nil }

//             let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
//             return nominalFrameRate
//         } catch {
//             Logger.shared.error("Failed to get frame rate: \(error.localizedDescription)")
//             return nil
//         }
//     }

//     /// Format duration in a user-friendly way
//     /// - Parameter duration: Duration in seconds
//     /// - Returns: Formatted duration string
//     func formatDuration(_ duration: TimeInterval) -> String {
//         if duration < 60 {
//             return String(format: "%.1fs", duration)
//         } else if duration < 3600 {
//             let minutes = Int(duration) / 60
//             let seconds = Int(duration) % 60
//             return String(format: "%dm %ds", minutes, seconds)
//         } else {
//             let hours = Int(duration) / 3600
//             let minutes = (Int(duration) % 3600) / 60
//             return String(format: "%dh %dm", hours, minutes)
//         }
//     }

//     /// Calculate percentage progress
//     /// - Parameters:
//     ///   - currentTime: Current time in seconds
//     ///   - totalTime: Total time in seconds
//     /// - Returns: Progress percentage (0.0 to 1.0)
//     func calculateProgress(currentTime: TimeInterval, totalTime: TimeInterval) -> Double {
//         guard totalTime > 0 else { return 0.0 }
//         return min(1.0, max(0.0, currentTime / totalTime))
//     }

//     /// Interpolate time based on percentage
//     /// - Parameters:
//     ///   - percentage: Progress percentage (0.0 to 1.0)
//     ///   - totalTime: Total time in seconds
//     /// - Returns: Interpolated time in seconds
//     func interpolateTime(percentage: Double, totalTime: TimeInterval) -> TimeInterval {
//         return totalTime * max(0.0, min(1.0, percentage))
//     }
// }