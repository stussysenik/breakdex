//import XCTest
//import AVFoundation
//@testable import BreakingFlashcards
//
//final class AssetInheritanceCoordinatorTests: XCTestCase {
//
//    var coordinator: AssetInheritanceCoordinator!
//    let testConfiguration = AssetInheritanceCoordinator.Configuration.default
//
//    override func setUp() {
//        super.setUp()
//        coordinator = AssetInheritanceCoordinator(configuration: testConfiguration)
//    }
//
//    override func tearDown() {
//        coordinator = nil
//        super.tearDown()
//    }
//
//    // MARK: - Initialization Tests
//
//    func testInitialization_withDefaultConfiguration() {
//        let coordinator = AssetInheritanceCoordinator()
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertEqual(coordinator.progress, 0.0)
//        XCTAssertEqual(coordinator.status, "")
//        XCTAssertFalse(coordinator.isAssetReady)
//        XCTAssertNil(coordinator.transformedAsset)
//        XCTAssertNil(coordinator.transformedPlayerItem)
//    }
//
//    func testInitialization_withCustomConfiguration() {
//        let config = AssetInheritanceCoordinator.Configuration.fast
//        let coordinator = AssetInheritanceCoordinator(configuration: config)
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertFalse(coordinator.isAssetReady)
//    }
//
//    // MARK: - Configuration Tests
//
//    func testDefaultConfiguration_values() {
//        XCTAssertTrue(testConfiguration.enableOptimization)
//        XCTAssertTrue(testConfiguration.enableValidation)
//        XCTAssertTrue(testConfiguration.enablePerformanceLogging)
//        XCTAssertEqual(testConfiguration.timeoutInterval, 30.0)
//    }
//
//    func testFastConfiguration_values() {
//        let fastConfig = AssetInheritanceCoordinator.Configuration.fast
//
//        XCTAssertTrue(fastConfig.enableOptimization)
//        XCTAssertFalse(fastConfig.enableValidation)
//        XCTAssertFalse(fastConfig.enablePerformanceLogging)
//        XCTAssertEqual(fastConfig.timeoutInterval, 15.0)
//    }
//
//    func testThoroughConfiguration_values() {
//        let thoroughConfig = AssetInheritanceCoordinator.Configuration.thorough
//
//        XCTAssertFalse(thoroughConfig.enableOptimization)
//        XCTAssertTrue(thoroughConfig.enableValidation)
//        XCTAssertTrue(thoroughConfig.enablePerformanceLogging)
//        XCTAssertEqual(thoroughConfig.timeoutInterval, 60.0)
//    }
//
//    // MARK: - Transformation State Tests
//
//    func testInitialState_isIdle() {
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertEqual(coordinator.progress, 0.0)
//        XCTAssertEqual(coordinator.status, "")
//        XCTAssertFalse(coordinator.isAssetReady)
//    }
//
//    // MARK: - Performance Metrics Tests
//
//    func testGetTransformationMetrics_initialState() {
//        let metrics = coordinator.getTransformationMetrics()
//
//        XCTAssertNil(metrics) // Should return nil when not in ready state
//    }
//
//    func testGetTransformationMetrics_afterReadyState() {
//        // Mock ready state
//        coordinator.state = .ready
//        coordinator.transformedAsset = createMockAsset()
//
//        let metrics = coordinator.getTransformationMetrics()
//
//        XCTAssertNotNil(metrics)
//        XCTAssertGreaterThanOrEqual(metrics.totalTime, 0.0)
//        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0.0)
//    }
//
//    // MARK: - Reset Tests
//
//    func testReset_clearsState() async {
//        // Set up some state
//        coordinator.state = .ready
//        coordinator.progress = 0.5
//        coordinator.status = "Test"
//        coordinator.isAssetReady = true
//
//        await coordinator.reset()
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertEqual(coordinator.progress, 0.0)
//        XCTAssertEqual(coordinator.status, "")
//        XCTAssertFalse(coordinator.isAssetReady)
//        XCTAssertNil(coordinator.transformedAsset)
//        XCTAssertNil(coordinator.transformedPlayerItem)
//    }
//
//    // MARK: - Cancel Transformation Tests
//
//    func testCancelTransformation_cancelsTask() {
//        // This test would require mocking Task behavior
//        // For now, we just verify the method doesn't crash
//        coordinator.cancelTransformation()
//        XCTAssertEqual(coordinator.state, .idle)
//    }
//
//    // MARK: - Convenience Initializer Tests
//
//    func testForFastOperations_usesFastConfiguration() {
//        let coordinator = AssetInheritanceCoordinator.forFastOperations()
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertFalse(coordinator.isAssetReady)
//    }
//
//    func testForThoroughOperations_usesThoroughConfiguration() {
//        let coordinator = AssetInheritanceCoordinator.forThoroughOperations()
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertFalse(coordinator.isAssetReady)
//    }
//
//    func testForDefaultOperations_usesDefaultConfiguration() {
//        let coordinator = AssetInheritanceCoordinator.forDefaultOperations()
//
//        XCTAssertEqual(coordinator.state, .idle)
//        XCTAssertFalse(coordinator.isAssetReady)
//    }
//
//    // MARK: - Transformation State Enum Tests
//
//    func testTransformationState_cases() {
//        let states: [AssetInheritanceCoordinator.TransformationState] = [
//            .idle,
//            .preparing(progress: 0.5, status: "Preparing"),
//            .transforming(progress: 0.7, status: "Transforming"),
//            .validating(progress: 0.9, status: "Validating"),
//            .ready,
//            .error("Test error")
//        ]
//
//        for state in states {
//            // Just verify all states can be created without crashing
//            switch state {
//            case .idle:
//                break
//            case .preparing(let progress, let status):
//                XCTAssertGreaterThanOrEqual(progress, 0.0)
//                XCTAssertLessThanOrEqual(progress, 1.0)
//                XCTAssertFalse(status.isEmpty)
//            case .transforming(let progress, let status):
//                XCTAssertGreaterThanOrEqual(progress, 0.0)
//                XCTAssertLessThanOrEqual(progress, 1.0)
//                XCTAssertFalse(status.isEmpty)
//            case .validating(let progress, let status):
//                XCTAssertGreaterThanOrEqual(progress, 0.0)
//                XCTAssertLessThanOrEqual(progress, 1.0)
//                XCTAssertFalse(status.isEmpty)
//            case .ready:
//                break
//            case .error(let error):
//                XCTAssertFalse(error.isEmpty)
//            }
//        }
//    }
//
//    // MARK: - Helper Methods
//
//    private func createMockAsset() -> AVAsset {
//        return AVAsset(url: URL(string: "file://test.mp4")!)
//    }
//}
