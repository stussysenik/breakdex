//
//  VideoProcessorImpl.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/27/25.
//

import Foundation
import AVFoundation
import OSLog
import Combine

// MARK: - Video Processor Implementation
@MainActor
public final class VideoProcessorImpl: VideoProcessor {
    private let logger: AppLogger
    private let enhancedProcessor: EnhancedVideoProcessor

    public init(logger: AppLogger) {
        self.logger = logger
        self.enhancedProcessor = EnhancedVideoProcessor()

        logger.info("🎬 VIDEO_PROCESSOR_IMPL: 🚀 Initialized", metadata: nil)
    }

    // MARK: - VideoProcessor Protocol Implementation
    public func processVideo(_ asset: AVAsset, rotationQuarterTurns: Int) async throws -> AVAsset {
        logger.info("🎬 VIDEO_PROCESSOR_IMPL: 🔄 Processing video - rotation: \(rotationQuarterTurns) quarter turns", metadata: nil)

        do {
            let result = try await enhancedProcessor.processVideo(
                asset,
                rotationQuarterTurns: rotationQuarterTurns,
                trimRange: nil
            )

            logger.info("🎬 VIDEO_PROCESSOR_IMPL: ✅ Video processing completed successfully", metadata: nil)
            return result.asset

        } catch {
            logger.error("🎬 VIDEO_PROCESSOR_IMPL: ❌ Video processing failed: \(error.localizedDescription)", metadata: nil)
            throw error
        }
    }

    // MARK: - Additional Helper Methods
    public func processVideoWithEnhancedFeatures(
        _ asset: AVAsset,
        rotationQuarterTurns: Int,
        trimRange: CMTimeRange? = nil
    ) async throws -> VideoProcessingResult {
        logger.info("🎬 VIDEO_PROCESSOR_IMPL: 🔄 Processing video with enhanced features", metadata: [
            "rotation": "\(rotationQuarterTurns)",
            "hasTrimRange": "\(trimRange != nil)"
        ])

        do {
            let result = try await enhancedProcessor.processVideo(
                asset,
                rotationQuarterTurns: rotationQuarterTurns,
                trimRange: trimRange
            )

            logger.info("🎬 VIDEO_PROCESSOR_IMPL: ✅ Enhanced video processing completed", metadata: [
                "processingTime": "\(result.processingTime)s",
                "frameCount": "\(result.frameCount)"
            ])

            return result

        } catch {
            logger.error("🎬 VIDEO_PROCESSOR_IMPL: ❌ Enhanced video processing failed: \(error.localizedDescription)", metadata: nil)
            throw error
        }
    }

    // MARK: - Progress Subscription
    public func subscribeToProgress() -> AnyPublisher<VideoProcessingProgress, Never> {
        return enhancedProcessor.progressPublisher
    }

    // MARK: - Cleanup
    public func cleanup() {
        logger.info("🎬 VIDEO_PROCESSOR_IMPL: 🧹 Cleaning up resources", metadata: nil)
        // EnhancedVideoProcessor doesn't require explicit cleanup
        // but we can add any necessary cleanup here in the future
    }
}