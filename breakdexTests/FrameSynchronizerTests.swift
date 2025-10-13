//import XCTest
//import AVFoundation
//@testable import BreakingFlashcards
//
//final class FrameSynchronizerTests: XCTestCase {
//
//    var synchronizer: FrameSynchronizer!
//    let testFrameRate: Double = 30.0
//    let testConfiguration = FrameSynchronizer.HapticConfiguration.default
//
//    override func setUp() {
//        super.setUp()
//        synchronizer = FrameSynchronizer(frameRate: testFrameRate, configuration: testConfiguration)
//    }
//
//    override func tearDown() {
//        synchronizer = nil
//        super.tearDown()
//    }
//
//    // MARK: - Initialization Tests
//
//    func testInitialization_withDefaultConfiguration() {
//        let synchronizer = FrameSynchronizer(frameRate: 60.0)
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertEqual(synchronizer.lastSyncedFrame, 0)
//        XCTAssertEqual(synchronizer.frameAccuracy, 0.0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//    }
//
//    func testInitialization_withCustomConfiguration() {
//        let config = FrameSynchronizer.HapticConfiguration.sensitive
//        let synchronizer = FrameSynchronizer(frameRate: 30.0, configuration: config)
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//    }
//
//    // MARK: - Frame Synchronization Tests
//
//    func testSynchronize_toSpecificTime() {
//        let testTime = CMTime(seconds: 2.5, preferredTimescale: 600)
//        synchronizer.synchronize(to: testTime)
//
//        let expectedFrame = Int(2.5 * testFrameRate)
//        XCTAssertEqual(synchronizer.currentFrame, expectedFrame)
//        XCTAssertTrue(synchronizer.isSynchronized)
//        XCTAssertEqual(synchronizer.lastSyncedFrame, expectedFrame)
//    }
//
//    func testSynchronize_multipleTimes_incrementsFrame() {
//        let time1 = CMTime(seconds: 1.0, preferredTimescale: 600)
//        let time2 = CMTime(seconds: 2.0, preferredTimescale: 600)
//
//        synchronizer.synchronize(to: time1)
//        let firstFrame = synchronizer.currentFrame
//
//        synchronizer.synchronize(to: time2)
//        let secondFrame = synchronizer.currentFrame
//
//        XCTAssertGreaterThan(secondFrame, firstFrame)
//        XCTAssertEqual(secondFrame, Int(2.0 * testFrameRate))
//    }
//
//    func testSynchronize_sameTime_doesNotSync() {
//        let testTime = CMTime(seconds: 1.0, preferredTimescale: 600)
//        synchronizer.synchronize(to: testTime)
//
//        let firstSyncCount = synchronizer.lastSyncedFrame
//        synchronizer.synchronize(to: testTime)
//
//        XCTAssertEqual(synchronizer.lastSyncedFrame, firstSyncCount)
//    }
//
//    // MARK: - Frame Calculation Tests
//
//    func testCalculateFrameNumber_forZeroTime() {
//        let zeroTime = CMTime.zero
//        let frameNumber = synchronizer.getNearestFrameBoundary(for: zeroTime)
//
//        XCTAssertEqual(frameTimeToSeconds(frameNumber), 0.0, accuracy: 0.001)
//    }
//
//    func testCalculateFrameNumber_forHalfSecond() {
//        let halfSecondTime = CMTime(seconds: 0.5, preferredTimescale: 600)
//        let frameBoundary = synchronizer.getNearestFrameBoundary(for: halfSecondTime)
//
//        let expectedTime = 1.0 / testFrameRate // Should snap to nearest frame boundary
//        XCTAssertEqual(frameTimeToSeconds(frameBoundary), expectedTime, accuracy: 0.001)
//    }
//
//    func testCalculateFrameNumber_forExactFrameBoundary() {
//        let exactTime = CMTime(seconds: 2.0 / testFrameRate, preferredTimescale: 600)
//        let frameBoundary = synchronizer.getNearestFrameBoundary(for: exactTime)
//
//        XCTAssertEqual(frameTimeToSeconds(frameBoundary), frameTimeToSeconds(exactTime), accuracy: 0.001)
//    }
//
//    func testIsOnFrameBoundary_exactBoundary() {
//        let exactTime = CMTime(seconds: 1.0 / testFrameRate, preferredTimescale: 600)
//        XCTAssertTrue(synchronizer.isOnFrameBoundary(exactTime))
//    }
//
//    func testIsOnFrameBoundary_nonBoundary() {
//        let nonBoundaryTime = CMTime(seconds: 0.5 / testFrameRate, preferredTimescale: 600)
//        XCTAssertFalse(synchronizer.isOnFrameBoundary(nonBoundaryTime))
//    }
//
//    // MARK: - Performance Metrics Tests
//
//    func testGetPerformanceMetrics_initialState() {
//        let metrics = synchronizer.getPerformanceMetrics()
//
//        XCTAssertEqual(metrics.averageSyncTime, 0.0)
//        XCTAssertEqual(metrics.frameMissRate, 0.0)
//        XCTAssertEqual(metrics.hapticLatency, 0.0)
//    }
//
//    func testGetPerformanceMetrics_afterSynchronization() {
//        let testTime = CMTime(seconds: 1.0, preferredTimescale: 600)
//        synchronizer.synchronize(to: testTime)
//
//        let metrics = synchronizer.getPerformanceMetrics()
//
//        XCTAssertGreaterThanOrEqual(metrics.averageSyncTime, 0.0)
//        XCTAssertGreaterThanOrEqual(metrics.frameMissRate, 0.0)
//    }
//
//    // MARK: - Reset Tests
//
//    func testReset_clearsAllState() {
//        let testTime = CMTime(seconds: 2.0, preferredTimescale: 600)
//        synchronizer.synchronize(to: testTime)
//
//        synchronizer.reset()
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertEqual(synchronizer.lastSyncedFrame, 0)
//        XCTAssertEqual(synchronizer.frameAccuracy, 0.0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//    }
//
//    // MARK: - Convenience Initializer Tests
//
//    func testForVideoTrimming_usesSensitiveConfiguration() {
//        let synchronizer = FrameSynchronizer.forVideoTrimming(frameRate: 60.0)
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//        // Should use sensitive configuration (can't test private properties directly)
//    }
//
//    func testForPlayback_usesDefaultConfiguration() {
//        let synchronizer = FrameSynchronizer.forPlayback(frameRate: 30.0)
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//    }
//
//    func testForPrecisionEditing_usesAggressiveConfiguration() {
//        let synchronizer = FrameSynchronizer.forPrecisionEditing(frameRate: 120.0)
//
//        XCTAssertEqual(synchronizer.currentFrame, 0)
//        XCTAssertFalse(synchronizer.isSynchronized)
//    }
//
//    // MARK: - Continuous Synchronization Tests
//
//    func testStartSynchronization_andStop() {
//        XCTAssertFalse(synchronizer.isSynchronized)
//
//        synchronizer.startSynchronization()
//        // Can't easily test timer activity without mocking
//
//        synchronizer.stopSynchronization()
//        // Timer should be stopped
//    }
//
//    func testGetCurrentFrameTime() {
//        let testTime = CMTime(seconds: 1.5, preferredTimescale: 600)
//        synchronizer.synchronize(to: testTime)
//
//        let frameTime = synchronizer.getCurrentFrameTime()
//        let expectedFrame = Int(1.5 * testFrameRate)
//        let expectedTime = Double(expectedFrame) / testFrameRate
//
//        XCTAssertEqual(frameTimeToSeconds(frameTime), expectedTime, accuracy: 0.001)
//    }
//
//    // MARK: - Helper Methods
//
//    private func frameTimeToSeconds(_ time: CMTime) -> Double {
//        return time.seconds
//    }
//}
