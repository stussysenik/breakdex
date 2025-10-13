//import XCTest
//import AVFoundation
//import Combine
//@testable import BreakingFlashcards
//
//@MainActor
//final class PlayerStateMonitorTests: XCTestCase {
//    
//    var sut: PlayerStateMonitor!
//    var mockPlayer: MockAVPlayer!
//    
//    override func setUp() {
//        super.setUp()
//        sut = PlayerStateMonitor()
//        mockPlayer = MockAVPlayer()
//    }
//    
//    override func tearDown() {
//        sut.cancelMonitoring()
//        sut = nil
//        mockPlayer = nil
//        super.tearDown()
//    }
//    
//    // MARK: - Initial State Tests
//    
//    func testInitialState_IsPending() {
//        XCTAssertTrue(sut.isPending)
//    }
//    
//    // MARK: - Ready Player Tests
//    
//    func testWaitForPlayerReady_WhenAlreadyReady_ReturnsImmediately() async {
//        // Set up player as ready
//        mockPlayer.status = .readyToPlay
//        mockPlayer.currentItem = MockAVPlayerItem(status: .readyToPlay)
//        
//        // Should return immediately without timeout
//        let expectation = XCTestExpectation(description: "Should return immediately")
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 1.0)
//                expectation.fulfill()
//            } catch {
//                XCTFail("Should not throw when player is already ready: \(error)")
//            }
//        }
//        
//        await fulfillment(of: [expectation], timeout: 0.5)
//    }
//    
//    func testWaitForPlayerReady_WhenPlayerBecomesReady() async {
//        // Start with player not ready
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        let expectation = XCTestExpectation(description: "Should wait for player to become ready")
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 2.0)
//                expectation.fulfill()
//            } catch {
//                XCTFail("Should not throw when player becomes ready: \(error)")
//            }
//        }
//        
//        // Simulate player becoming ready after a delay
//        Task {
//            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//            mockPlayer.status = .readyToPlay
//            mockPlayer.currentItem?.status = .readyToPlay
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.5)
//    }
//    
//    // MARK: - Timeout Tests
//    
//    func testWaitForPlayerReady_TimesOutWhenNotReady() async {
//        // Player never becomes ready
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        let expectation = XCTestExpectation(description: "Should timeout")
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 0.5)
//                XCTFail("Should have timed out")
//            } catch PlayerStateMonitor.MonitorError.timeoutExceeded {
//                expectation.fulfill()
//            } catch {
//                XCTFail("Unexpected error: \(error)")
//            }
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//    }
//    
//    // MARK: - Error Handling Tests
//    
//    func testWaitForPlayerReady_WhenPlayerFails() async {
//        // Start with unknown status
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        let expectation = XCTestExpectation(description: "Should handle player failure")
//        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 2.0)
//                XCTFail("Should have thrown player failed error")
//            } catch PlayerStateMonitor.MonitorError.playerFailed(let error) {
//                XCTAssertEqual(error as NSError, testError)
//                expectation.fulfill()
//            } catch {
//                XCTFail("Unexpected error: \(error)")
//            }
//        }
//        
//        // Simulate player failure after a delay
//        Task {
//            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//            mockPlayer.status = .failed
//            mockPlayer.error = testError
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.5)
//    }
//    
//    func testWaitForPlayerReady_WhenPlayerItemFails() async {
//        // Start with unknown status
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        let expectation = XCTestExpectation(description: "Should handle player item failure")
//        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 2.0)
//                XCTFail("Should have thrown player failed error")
//            } catch PlayerStateMonitor.MonitorError.playerFailed(let error) {
//                XCTAssertEqual(error as NSError, testError)
//                expectation.fulfill()
//            } catch {
//                XCTFail("Unexpected error: \(error)")
//            }
//        }
//        
//        // Simulate player item failure after a delay
//        Task {
//            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//            mockPlayer.currentItem?.status = .failed
//            mockPlayer.currentItem?.error = testError
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.5)
//    }
//    
//    // MARK: - Cancellation Tests
//    
//    func testCancelMonitoring_StopsObservation() async {
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        let expectation = XCTestExpectation(description: "Should cancel monitoring")
//        
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 2.0)
//                XCTFail("Should have been cancelled")
//            } catch PlayerStateMonitor.MonitorError.observationCancelled {
//                expectation.fulfill()
//            } catch {
//                XCTFail("Unexpected error: \(error)")
//            }
//        }
//        
//        // Cancel after a delay
//        Task {
//            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
//            sut.cancelMonitoring()
//            
//            // Try to make player ready - should not trigger completion
//            mockPlayer.status = .readyToPlay
//            mockPlayer.currentItem?.status = .readyToPlay
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//    }
//    
//    // MARK: - Multiple Calls Tests
//    
//    func testMultipleWaitCalls_AfterCancellation() async {
//        mockPlayer.status = .unknown
//        mockPlayer.currentItem = MockAVPlayerItem(status: .unknown)
//        
//        // First call should timeout
//        let expectation1 = XCTestExpectation(description: "First call should timeout")
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 0.3)
//                XCTFail("Should have timed out")
//            } catch PlayerStateMonitor.MonitorError.timeoutExceeded {
//                expectation1.fulfill()
//            } catch {
//                XCTFail("Unexpected error: \(error)")
//            }
//        }
//        
//        await fulfillment(of: [expectation1], timeout: 0.5)
//        
//        // Second call should work if player becomes ready
//        let expectation2 = XCTestExpectation(description: "Second call should succeed")
//        Task {
//            do {
//                try await sut.waitForPlayerReady(mockPlayer, timeout: 1.0)
//                expectation2.fulfill()
//            } catch {
//                XCTFail("Second call should not fail: \(error)")
//            }
//        }
//        
//        // Make player ready
//        mockPlayer.status = .readyToPlay
//        mockPlayer.currentItem?.status = .readyToPlay
//        
//        await fulfillment(of: [expectation2], timeout: 0.5)
//    }
//}
//
//// MARK: - Mock Classes
//
//private class MockAVPlayer: AVPlayer {
//    var mockStatus: AVPlayer.Status = .unknown
//    var mockError: Error?
//    var mockCurrentItem: MockAVPlayerItem?
//    
//    override var status: AVPlayer.Status {
//        get { mockStatus }
//        set { mockStatus = newValue }
//    }
//    
//    override var error: Error? {
//        get { mockError }
//        set { mockError = newValue }
//    }
//    
//    override var currentItem: AVPlayerItem? {
//        get { mockCurrentItem }
//        set { mockCurrentItem = newValue as? MockAVPlayerItem }
//    }
//}
//
//private class MockAVPlayerItem: AVPlayerItem {
//    var mockStatus: AVPlayerItem.Status = .unknown
//    var mockError: Error?
//    
//    init(status: AVPlayerItem.Status) {
//        super.init(asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")))
//        self.mockStatus = status
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override var status: AVPlayerItem.Status {
//        get { mockStatus }
//        set { mockStatus = newValue }
//    }
//    
//    override var error: Error? {
//        get { mockError }
//        set { mockError = newValue }
//    }
//}
