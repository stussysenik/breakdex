import AVFoundation
import Foundation
import OSLog

/// MARK: - ENHANCED: Comprehensive asset validation service for complex video files
/// Implements robust validation for multi-track assets, corrupted files, and edge cases
@MainActor
final class VideoAssetValidator {

    private static let logger = Logger(subsystem: "BreakingFlashcards", category: "VideoAssetValidator")

    /// MARK: - ENHANCED: Validation result containing detailed asset analysis
    struct ValidationResult {
        let isValid: Bool
        let videoTrackCount: Int
        let audioTrackCount: Int
        let primaryVideoTrack: AVAssetTrack?
        let primaryAudioTrack: AVAssetTrack?
        let assetDuration: CMTime
        let hasMultipleVideoTracks: Bool
        let validationErrors: [VideoProcessingError]
        let warnings: [String]
        let assetComplexity: AssetComplexity

        /// Asset complexity classification for handling strategies
        enum AssetComplexity {
            case simple           // Single video track, optional audio
            case multiTrack       // Multiple video/audio tracks
            case complex          // Multi-track with special formats (GoPro, drone footage)
            case corrupted        // Damaged or unreadable asset
            case unsupported      // Valid format but unsupported by our processing

            var localizedDescription: String {
                switch self {
                case .simple: return "Simple"
                case .multiTrack: return "Multi-Track"
                case .complex: return "Complex"
                case .corrupted: return "Corrupted"
                case .unsupported: return "Unsupported"
                }
            }
        }
    }

    /// MARK: - ENHANCED: Comprehensive asset validation
    /// - Parameter asset: AVAsset to validate
    /// - Returns: ValidationResult with detailed analysis
    static func validateAsset(_ asset: AVAsset) async -> ValidationResult {
        let validationStart = CFAbsoluteTimeGetCurrent()
        logger.info("🔍 VALIDATOR: Starting comprehensive asset validation")

        var errors: [VideoProcessingError] = []
        var warnings: [String] = []

        // Step 1: Basic asset properties validation
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
            logger.info("🔍 VALIDATOR: 📏 Asset duration: \(duration.seconds)s")

            if duration.seconds <= 0 {
                errors.append(.assetNotReadable)
                logger.error("🔍 VALIDATOR: ❌ Invalid asset duration: \(duration.seconds)s")
            } else if duration.seconds < 0.1 {
                warnings.append("Very short video duration (\(duration.seconds)s) may cause processing issues")
                logger.warning("🔍 VALIDATOR: ⚠️ Very short video duration detected")
            }
        } catch {
            errors.append(.assetNotReadable)
            logger.error("🔍 VALIDATOR: ❌ Failed to load asset duration: \(error)")
            return ValidationResult(
                isValid: false,
                videoTrackCount: 0,
                audioTrackCount: 0,
                primaryVideoTrack: nil,
                primaryAudioTrack: nil,
                assetDuration: .zero,
                hasMultipleVideoTracks: false,
                validationErrors: errors,
                warnings: warnings,
                assetComplexity: .corrupted
            )
        }

        // Step 2: Track validation
        let videoTracks: [AVAssetTrack]
        let audioTracks: [AVAssetTrack]

        do {
            videoTracks = try await asset.loadTracks(withMediaType: .video)
            audioTracks = try await asset.loadTracks(withMediaType: .audio)

            logger.info("🔍 VALIDATOR: 📊 Raw track count - Video: \(videoTracks.count), Audio: \(audioTracks.count)")
        } catch {
            errors.append(.assetNotReadable)
            logger.error("🔍 VALIDATOR: ❌ Failed to load tracks: \(error)")
            return ValidationResult(
                isValid: false,
                videoTrackCount: 0,
                audioTrackCount: 0,
                primaryVideoTrack: nil,
                primaryAudioTrack: nil,
                assetDuration: duration,
                hasMultipleVideoTracks: false,
                validationErrors: errors,
                warnings: warnings,
                assetComplexity: .corrupted
            )
        }

        // Step 3: Video track validation
        let validVideoTracks = await validateVideoTracks(videoTracks, &errors, &warnings)
        let validAudioTracks = await validateAudioTracks(audioTracks, &errors, &warnings)

        // Step 4: Determine asset complexity
        let complexity = determineAssetComplexity(
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            validVideoTracks: validVideoTracks,
            validAudioTracks: validAudioTracks,
            errors: errors
        )

        // Step 5: Final validation decision
        let isValid = errors.isEmpty && !validVideoTracks.isEmpty

        logger.info("🔍 VALIDATOR: ✅ Validation completed in \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - validationStart) * 1000))ms")
        logger.info("🔍 VALIDATOR: 📊 Final result - Valid: \(isValid), Complexity: \(complexity.localizedDescription)")

        return ValidationResult(
            isValid: isValid,
            videoTrackCount: videoTracks.count,
            audioTrackCount: audioTracks.count,
            primaryVideoTrack: validVideoTracks.first,
            primaryAudioTrack: validAudioTracks.first,
            assetDuration: duration,
            hasMultipleVideoTracks: validVideoTracks.count > 1,
            validationErrors: errors,
            warnings: warnings,
            assetComplexity: complexity
        )
    }

    /// MARK: - ENHANCED: Detailed video track validation
    private static func validateVideoTracks(
        _ tracks: [AVAssetTrack],
        _ errors: inout [VideoProcessingError],
        _ warnings: inout [String]
    ) async -> [AVAssetTrack] {
        logger.info("🔍 VALIDATOR: 🎬 Validating \(tracks.count) video tracks")

        var validTracks: [AVAssetTrack] = []

        for (index, track) in tracks.enumerated() {
            logger.info("🔍 VALIDATOR: 🎬 Analyzing video track \(index + 1)")

            // Check basic track properties
            do {
                let isPlayable = try await track.load(.isPlayable)
                guard isPlayable else {
                    warnings.append("Video track \(index + 1) is not playable")
                    logger.warning("🔍 VALIDATOR: ⚠️ Video track \(index + 1) is not playable")
                    continue
                }
            } catch {
                warnings.append("Failed to check playability for video track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to check playability for video track \(index + 1): \(error)")
                continue
            }

            // Check format descriptions
            do {
                let formatDescriptions = try await track.load(.formatDescriptions)
                if formatDescriptions.isEmpty {
                    warnings.append("Video track \(index + 1) has no format descriptions")
                    logger.warning("🔍 VALIDATOR: ⚠️ Video track \(index + 1) has no format descriptions")
                    continue
                }

                // Log format details for debugging
                for (descIndex, desc) in formatDescriptions.enumerated() {
                    let mediaType = CMFormatDescriptionGetMediaType(desc)
                    logger.info("🔍 VALIDATOR: 📊 Format \(descIndex + 1): \(mediaType)")
                }
            } catch {
                warnings.append("Failed to load format descriptions for video track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to load format descriptions for video track \(index + 1): \(error)")
                continue
            }

            // Check dimensions
            do {
                let naturalSize = try await track.load(.naturalSize)
                guard naturalSize != .zero else {
                    warnings.append("Video track \(index + 1) has zero dimensions")
                    logger.warning("🔍 VALIDATOR: ⚠️ Video track \(index + 1) has zero dimensions")
                    continue
                }

                // Check for unusual dimensions
                if naturalSize.width > 4096 || naturalSize.height > 4096 {
                    warnings.append("Video track \(index + 1) has very large dimensions (\(naturalSize.width)x\(naturalSize.height))")
                    logger.warning("🔍 VALIDATOR: ⚠️ Very large dimensions detected")
                }

                if naturalSize.width < 16 || naturalSize.height < 16 {
                    warnings.append("Video track \(index + 1) has very small dimensions (\(naturalSize.width)x\(naturalSize.height))")
                    logger.warning("🔍 VALIDATOR: ⚠️ Very small dimensions detected")
                }

                logger.info("🔍 VALIDATOR: 📏 Video track \(index + 1) dimensions: \(String(describing: naturalSize))")
                validTracks.append(track)

            } catch {
                warnings.append("Failed to load dimensions for video track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to load dimensions for video track \(index + 1): \(error)")
                continue
            }

            // Check frame rate
            do {
                let frameRate = try await track.load(.nominalFrameRate)
                if frameRate <= 0 {
                    warnings.append("Video track \(index + 1) has invalid frame rate: \(frameRate)")
                    logger.warning("🔍 VALIDATOR: ⚠️ Invalid frame rate detected")
                } else if frameRate > 120 {
                    warnings.append("Video track \(index + 1) has very high frame rate: \(frameRate)fps")
                    logger.warning("🔍 VALIDATOR: ⚠️ Very high frame rate detected")
                }
            } catch {
                warnings.append("Failed to load frame rate for video track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to load frame rate for video track \(index + 1): \(error)")
            }
        }

        logger.info("🔍 VALIDATOR: ✅ Video track validation completed: \(validTracks.count)/\(tracks.count) valid")
        return validTracks
    }

    /// MARK: - ENHANCED: Detailed audio track validation
    private static func validateAudioTracks(
        _ tracks: [AVAssetTrack],
        _ errors: inout [VideoProcessingError],
        _ warnings: inout [String]
    ) async -> [AVAssetTrack] {
        logger.info("🔍 VALIDATOR: 🎵 Validating \(tracks.count) audio tracks")

        var validTracks: [AVAssetTrack] = []

        for (index, track) in tracks.enumerated() {
            logger.info("🔍 VALIDATOR: 🎵 Analyzing audio track \(index + 1)")

            do {
                let isPlayable = try await track.load(.isPlayable)
                guard isPlayable else {
                    warnings.append("Audio track \(index + 1) is not playable")
                    logger.warning("🔍 VALIDATOR: ⚠️ Audio track \(index + 1) is not playable")
                    continue
                }
            } catch {
                warnings.append("Failed to check playability for audio track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to check playability for audio track \(index + 1): \(error)")
                continue
            }

            // Check format descriptions
            do {
                let formatDescriptions = try await track.load(.formatDescriptions)
                if formatDescriptions.isEmpty {
                    warnings.append("Audio track \(index + 1) has no format descriptions")
                    logger.warning("🔍 VALIDATOR: ⚠️ Audio track \(index + 1) has no format descriptions")
                    continue
                }
            } catch {
                warnings.append("Failed to load format descriptions for audio track \(index + 1)")
                logger.warning("🔍 VALIDATOR: ⚠️ Failed to load format descriptions for audio track \(index + 1): \(error)")
                continue
            }

            validTracks.append(track)
        }

        logger.info("🔍 VALIDATOR: ✅ Audio track validation completed: \(validTracks.count)/\(tracks.count) valid")
        return validTracks
    }

    /// MARK: - ENHANCED: Determine asset complexity based on analysis
    private static func determineAssetComplexity(
        videoTracks: [AVAssetTrack],
        audioTracks: [AVAssetTrack],
        validVideoTracks: [AVAssetTrack],
        validAudioTracks: [AVAssetTrack],
        errors: [VideoProcessingError]
    ) -> ValidationResult.AssetComplexity {

        // If we have critical errors, asset is corrupted
        if errors.contains(where: {
            switch $0 {
            case .assetNotReadable:
                return true
            default:
                return false
            }
        }) {
            return .corrupted
        }

        // If no valid video tracks, asset is unsupported
        if validVideoTracks.isEmpty {
            return .unsupported
        }

        // Simple asset: single video track, any number of audio tracks
        if videoTracks.count == 1 && validVideoTracks.count == 1 {
            return .simple
        }

        // Multi-track asset: multiple video tracks
        if videoTracks.count > 1 {
            // Check if this looks like complex footage (GoPro, drone, etc.)
            if videoTracks.count > 2 || audioTracks.count > 4 {
                return .complex
            }
            return .multiTrack
        }

        // Default to multi-track for other cases
        return .multiTrack
    }

    /// MARK: - ENHANCED: Quick validation for basic asset readability
    /// Use this for fast checks before comprehensive validation
    static func quickValidate(_ asset: AVAsset) async -> Bool {
        do {
            let duration = try await asset.load(.duration)
            guard duration.seconds > 0 else { return false }

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            return !videoTracks.isEmpty
        } catch {
            return false
        }
    }
}