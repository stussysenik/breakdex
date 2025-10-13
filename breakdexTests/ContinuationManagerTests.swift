//import XCTest
//import Foundation
//@testable import BreakingFlashcards
//
//@MainActor
//final class ContinuationManagerTests: XCTestCase {
//    
//    var sut: ContinuationManager<String>!
//    
//    override func setUp() {
//        super.setUp()
//        sut = ContinuationManager<String>()
//    }
//    
//    override func tearDown() {
//        sut = nil
//        super.tearDown()
//    }
//    
//    // MARK: - Initial State Tests
//    
//    func testInitialStateIsPending() {
//        XCTAssertTrue(sut.isPending)
//        XCTAssertEqual(sut.currentState, "pending")
//    }
//    
//    // MARK: - Successful Resumption Tests
//    
//    func testSafelyResume_SuccessfullyResumes() async {
//        let expectation = XCTestExpectation(description: "Continuation should be resumed")
//        
//        let result = await withTaskGroup(of: String.self) { group in
//            group.addTask {
//                try await withCheckedThrowingContinuation { continuation in
//                    let success = self.sut.safelyResume(continuation, with: .success("test_value"))
//                    XCTAssertTrue(success)
//                }
//            }
//            
//            for await value in group {
//                expectation.fulfill()
//                return value
//            }
//            
//            return "default"
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//        XCTAssertEqual(result, "test_value")
//        XCTAssertFalse(sut.isPending)
//        XCTAssertEqual(sut.currentState, "resumed")
//    }
//    
//    func testSafelyResume_PreventsDoubleResumption() async {
//        let expectation = XCTestExpectation(description: "First resumption should succeed, second should fail")
//        expectation.expectedFulfillmentCount = 2
//        
//        let result1 = await withTaskGroup(of: Bool.self) { group in
//            group.addTask {
//                try await withCheckedThrowingContinuation { continuation in
//                    let success = self.sut.safelyResume(continuation, with: .success("first"))
//                    expectation.fulfill()
//                    return success
//                }
//            }
//            
//            for await value in group {
//                return value
//            }
//            
//            return false
//        }
//        
//        let result2 = await withTaskGroup(of: Bool.self) { group in
//            group.addTask {
//                try await withCheckedThrowingContinuation { continuation in
//                    let success = self.sut.safelyResume(continuation, with: .success("second"))
//                    expectation.fulfill()
//                    return success
//                }
//            }
//            
//            for await value in group {
//                return value
//            }
//            
//            return false
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//        XCTAssertTrue(result1)
//        XCTAssertFalse(result2)
//    }
//    
//    // MARK: - Error Resumption Tests
//    
//    func testSafelyResume_WithError() async {
//        let expectation = XCTestExpectation(description: "Continuation should be resumed with error")
//        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
//        
//        do {
//            let _ = try await withTaskGroup(of: String.self) { group in
//                group.addTask {
//                    try await withCheckedThrowingContinuation { continuation in
//                        let success = self.sut.safelyResume(continuation, with: .failure(testError))
//                        XCTAssertTrue(success)
//                    }
//                }
//                
//                for await value in group {
//                    return value
//                }
//                
//                return "default"
//            }
//        } catch {
//            expectation.fulfill()
//            XCTAssertEqual(error as NSError, testError)
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//        XCTAssertFalse(sut.isPending)
//    }
//    
//    // MARK: - Cancellation Tests
//    
//    func testCancel_WhenPending() {
//        let result = sut.cancel()
//        
//        XCTAssertTrue(result)
//        XCTAssertFalse(sut.isPending)
//        XCTAssertEqual(sut.currentState, "cancelled")
//    }
//    
//    func testCancel_AfterResumption() async {
//        // First resume
//        let _ = await withTaskGroup(of: String.self) { group in
//            group.addTask {
//                try await withCheckedThrowingContinuation { continuation in
//                    self.sut.safelyResume(continuation, with: .success("test"))
//                }
//            }
//            
//            for await value in group {
//                return value
//            }
//            
//            return "default"
//        }
//        
//        // Then try to cancel
//        let result = sut.cancel()
//        
//        XCTAssertFalse(result)
//        XCTAssertFalse(sut.isPending)
//    }
//    
//    func testCancel_PreventsResumption() async {
//        // Cancel first
//        let cancelResult = sut.cancel()
//        XCTAssertTrue(cancelResult)
//        
//        // Then try to resume
//        let expectation = XCTestExpectation(description: "Resumption should fail after cancellation")
//        
//        let result = await withTaskGroup(of: Bool.self) { group in
//            group.addTask {
//                try await withCheckedThrowingContinuation { continuation in
//                    let success = self.sut.safelyResume(continuation, with: .success("test"))
//                    expectation.fulfill()
//                    return success
//                }
//            }
//            
//            for await value in group {
//                return value
//            }
//            
//            return false
//        }
//        
//        await fulfillment(of: [expectation], timeout: 1.0)
//        XCTAssertFalse(result)
//    }
//    
//    // MARK: - Concurrency Tests
//    
//    func testConcurrentAccess_ThreadSafety() async {
//        let expectation = XCTestExpectation(description: "Concurrent operations should be thread-safe")
//        expectation.expectedFulfillmentCount = 100
//        
//        await withTaskGroup(of: Void.self) { group in
//            for i in 0..<100 {
//                group.addTask {
//                    if i == 0 {
//                        // First task resumes
//                        let _ = await withTaskGroup(of: String.self) { innerGroup in
//                            innerGroup.addTask {
//                                try await withCheckedThrowingContinuation { continuation in
//                                    let success = self.sut.safelyResume(continuation, with: .success("concurrent_test"))
//                                    XCTAssertTrue(success)
//                                    expectation.fulfill()
//                                }
//                            }
//                            
//                            for await _ in innerGroup {}
//                        }
//                    } else {
//                        // Other tasks try to resume or cancel
//                        let result = await withTaskGroup(of: Bool.self) { innerGroup in
//                            innerGroup.addTask {
//                                try await withCheckedThrowingContinuation { continuation in
//                                    let success = self.sut.safelyResume(continuation, with: .success("should_fail_\(i)"))
//                                    expectation.fulfill()
//                                    return success
//                                }
//                            }
//                            
//                            for await value in innerGroup {
//                                return value
//                            }
//                            
//                            return false
//                        }
//                        XCTAssertFalse(result, "Task \(i) should have failed to resume")
//                        expectation.fulfill()
//                    }
//                }
//            }
//        }
//        
//        await fulfillment(of: [expectation], timeout: 5.0)
//    }
//}
