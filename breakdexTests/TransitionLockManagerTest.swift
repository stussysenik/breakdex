//import Foundation
//
///// Simple test to verify TransitionLockManager functionality
/////
///// This test demonstrates that the actor-based lock management works correctly
///// and prevents race conditions through proper synchronization.
//class TransitionLockManagerTest {
//    private let transitionLockManager = TransitionLockManager.shared
//
//    /// Test basic lock acquisition and release
//    func testBasicLockFunctionality() async {
//        print("🧪 Testing basic lock functionality...")
//
//        let operationId = UUID()
//
//        do {
//            // Acquire lock
//            try await transitionLockManager.acquireLock(for: operationId)
//            print("✅ Lock acquired successfully")
//
//            // Verify we own the lock
//            let ownsLock = await transitionLockManager.ownsLock(id: operationId)
//            assert(ownsLock, "Should own the lock after acquisition")
//            print("✅ Lock ownership verified")
//
//            // Try to acquire again (should succeed since we own it)
//            try await transitionLockManager.acquireLock(for: operationId)
//            print("✅ Duplicate acquisition by same owner succeeded")
//
//            // Verify lock status
//            let isLocked = await transitionLockManager.isLocked()
//            assert(isLocked, "Lock should be engaged")
//            print("✅ Lock status verified")
//
//            // Release lock
//            await transitionLockManager.releaseLock(for: operationId)
//            print("✅ Lock released successfully")
//
//            // Verify we no longer own the lock
//            let ownsLockAfterRelease = await transitionLockManager.ownsLock(id: operationId)
//            assert(!ownsLockAfterRelease, "Should not own the lock after release")
//            print("✅ Lock release verified")
//
//        } catch {
//            print("❌ Test failed: \(error.localizedDescription)")
//        }
//    }
//
//    /// Test concurrent lock acquisition (should fail)
//    func testConcurrentLockPrevention() async {
//        print("🧪 Testing concurrent lock prevention...")
//
//        let operationId1 = UUID()
//        let operationId2 = UUID()
//
//        do {
//            // First operation acquires lock
//            try await transitionLockManager.acquireLock(for: operationId1)
//            print("✅ First operation acquired lock")
//
//            // Second operation should fail to acquire lock
//            do {
//                try await transitionLockManager.acquireLock(for: operationId2)
//                print("❌ Second operation should not have been able to acquire lock")
//                assert(false, "Second operation should not acquire lock")
//            } catch {
//                print("✅ Second operation correctly failed to acquire lock: \(error.localizedDescription)")
//            }
//
//            // Clean up
//            await transitionLockManager.releaseLock(for: operationId1)
//            print("✅ First operation released lock")
//
//        } catch {
//            print("❌ Test failed: \(error.localizedDescription)")
//        }
//    }
//
//    /// Test retry mechanism
//    func testRetryMechanism() async {
//        print("🧪 Testing retry mechanism...")
//
//        let operationId1 = UUID()
//        let operationId2 = UUID()
//
//        do {
//            // First operation acquires lock
//            try await transitionLockManager.acquireLock(for: operationId1)
//            print("✅ First operation acquired lock")
//
//            // Release lock after a delay
//            Task {
//                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
//                await transitionLockManager.releaseLock(for: operationId1)
//                print("✅ First operation released lock after delay")
//            }
//
//            // Second operation should eventually succeed with retry
//            let startTime = Date()
//            try await transitionLockManager.acquireLockWithRetry(for: operationId2, retryCount: 5, retryDelay: 20)
//            let duration = Date().timeIntervalSince(startTime)
//
//            print("✅ Second operation acquired lock with retry after \(String(format: "%.3f", duration * 1000))ms")
//
//            // Verify we own the lock
//            let ownsLock = await transitionLockManager.ownsLock(id: operationId2)
//            assert(ownsLock, "Second operation should own the lock")
//            print("✅ Retry mechanism success verified")
//
//            // Clean up
//            await transitionLockManager.releaseLock(for: operationId2)
//
//        } catch {
//            print("❌ Test failed: \(error.localizedDescription)")
//        }
//    }
//
//    /// Run all tests
//    func runAllTests() async {
//        print("🚀 Starting TransitionLockManager tests...")
//        print("=" * 50)
//
//        await testBasicLockFunctionality()
//        print()
//
//        await testConcurrentLockPrevention()
//        print()
//
//        await testRetryMechanism()
//        print()
//
//        print("=" * 50)
//        print("🎉 All TransitionLockManager tests completed!")
//    }
//}
//
//// Extension for string repetition
//extension String {
//    static func *(lhs: String, rhs: Int) -> String {
//        return String(repeating: lhs, count: rhs)
//    }
//}
