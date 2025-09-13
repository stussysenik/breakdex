
import Foundation
import AVFoundation

struct Quantizer {
    static func quantizedCMTime(
        for proposedTime: CMTime,
        frameDuration: CMTime,
        minTime: CMTime,
        maxTime: CMTime,
        oneFrameDuration: CMTime
    ) -> CMTime {
        // Snap to nearest frame
        let proposedSeconds = CMTimeGetSeconds(proposedTime)
        let frameDurationSeconds = CMTimeGetSeconds(frameDuration)
        let snappedSeconds = round(proposedSeconds / frameDurationSeconds) * frameDurationSeconds
        var quantizedTime = CMTime(seconds: snappedSeconds, preferredTimescale: proposedTime.timescale)
        
        // Enforce boundaries
        quantizedTime = CMTimeMaximum(quantizedTime, minTime)
        quantizedTime = CMTimeMinimum(quantizedTime, maxTime)
        
        return quantizedTime
    }
    
    static func enforceOneFrameGap(
        startTime: CMTime,
        endTime: CMTime,
        oneFrameDuration: CMTime
    ) -> (CMTime, CMTime) {
        var newStartTime = startTime
        var newEndTime = endTime
        
        // Ensure end time is at least one frame after start time
        if CMTimeCompare(newEndTime, CMTimeAdd(newStartTime, oneFrameDuration)) < 0 {
            newEndTime = CMTimeAdd(newStartTime, oneFrameDuration)
        }
        
        // Ensure start time is at most one frame before end time
        if CMTimeCompare(newStartTime, CMTimeSubtract(newEndTime, oneFrameDuration)) > 0 {
            newStartTime = CMTimeSubtract(newEndTime, oneFrameDuration)
        }
        
        return (newStartTime, newEndTime)
    }
}
