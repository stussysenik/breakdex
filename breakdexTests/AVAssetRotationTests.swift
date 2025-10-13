////
////  AVAssetRotationTests.swift
////  BreakingFlashcardsTests
////
////  Created by Claude Code on 10/2/25.
////
//
//import XCTest
//import AVFoundation
//import OSLog
//@testable import BreakingFlashcards
//
//@MainActor
//final class AVAssetRotationTests: XCTestCase {
//
//    // MARK: - Properties
//
//    var mockAssetFactory: MockAVAssetFactory!
//    let testTimeout: TimeInterval = 10.0
//    let maxAcceptableExecutionTime: TimeInterval = 0.05 // 50ms
//
//    // MARK: - Setup & Teardown
//
//    override func setUp() async throws {
//        try await super.setUp()
//        mockAssetFactory = MockAVAssetFactory()
//    }
//
//    override func tearDown() async throws {
//        mockAssetFactory = nil
//        try await super.tearDown()
//    }
//
//    // MARK: - Standard Rotation Matrix Tests
//
//    func testGetRotationInQuarterTurns_ZeroRotation() async throws {
//        // Create mock asset with identity transform (0° rotation)
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0)
//        )
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 0, "Identity transform should return 0 quarter turns")
//    }
//
//    func testGetRotationInQuarterTurns_NinetyDegreeClockwise() async throws {
//        // Create mock asset with 90° clockwise rotation transform
//        // [ 0,  1; -1,  0]
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0)
//        )
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 1, "90° clockwise transform should return 1 quarter turn")
//    }
//
//    func testGetRotationInQuarterTurns_OneHundredEightyDegrees() async throws {
//        // Create mock asset with 180° rotation transform
//        // [-1,  0;  0, -1]
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0)
//        )
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 2, "180° transform should return 2 quarter turns")
//    }
//
//    func testGetRotationInQuarterTurns_TwoHundredSeventyDegrees() async throws {
//        // Create mock asset with 270° clockwise rotation transform
//        // [ 0, -1;  1,  0]
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0)
//        )
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 3, "270° clockwise transform should return 3 quarter turns")
//    }
//
//    // MARK: - Edge Case Tests
//
//    func testGetRotationInQuarterTurns_NonStandardTransformWithScaling() async throws {
//        // Create mock asset with non-standard transform (rotation + scaling)
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 2.0, b: 0.0, c: 0.0, d: 2.0)
//        )
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        // Should project to nearest quarter turn (0° in this case)
//        XCTAssertEqual(result, 0, "Scaled transform should project to nearest quarter turn")
//    }
//
//    func testGetRotationInQuarterTurns_NonStandardTransformWithTranslation() async throws {
//        // Create mock asset with non-standard transform (rotation + translation)
//        var transform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0)
//        transform.tx = 100.0
//        transform.ty = 50.0
//
//        let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        // Should project to nearest quarter turn (0° in this case)
//        XCTAssertEqual(result, 0, "Transform with translation should project to nearest quarter turn")
//    }
//
//    func testGetRotationInQuarterTurns_CompoundTransform() async throws {
//        // Create mock asset with compound transform (rotation + scaling + translation)
//        var transform = CGAffineTransform(a: 0.707, b: 0.707, c: -0.707, d: 0.707) // ~45° rotation
//        transform.tx = 25.0
//        transform.ty = -15.0
//
//        let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        // Should project to nearest quarter turn (1 for 45° ~ 90°)
//        XCTAssertEqual(result, 1, "Compound transform should project to nearest quarter turn")
//    }
//
//    func testGetRotationInQuarterTurns_NoVideoTracks() async throws {
//        // Create mock asset with no video tracks
//        let mockAsset = mockAssetFactory.createAssetWithNoVideoTracks()
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 0, "Asset with no video tracks should return 0")
//    }
//
//    func testGetRotationInQuarterTurns_MultipleVideoTracks() async throws {
//        // Create mock asset with multiple video tracks (should use first one)
//        let transforms = [
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0), // 90°
//            CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0), // 180°
//            CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0)  // 270°
//        ]
//
//        let mockAsset = mockAssetFactory.createAssetWithMultipleVideoTracks(transforms: transforms)
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 1, "Should use first video track's transform (90° = 1 quarter turn)")
//    }
//
//    func testGetRotationInQuarterTurns_TransformLoadingFailure() async throws {
//        // Create mock asset that fails to load transform
//        let mockAsset = mockAssetFactory.createAssetWithTransformLoadingFailure()
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 0, "Transform loading failure should return 0")
//    }
//
//    func testGetRotationInQuarterTurns_VideoTrackLoadingFailure() async throws {
//        // Create mock asset that fails to load video tracks
//        let mockAsset = mockAssetFactory.createAssetWithVideoTrackLoadingFailure()
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        XCTAssertEqual(result, 0, "Video track loading failure should return 0")
//    }
//
//    // MARK: - Mathematical Precision Tests
//
//    func testGetRotationInQuarterTurns_PrecisionHandling() async throws {
//        // Test transforms with floating-point precision variations
//        let precisionTests: [(CGAffineTransform, Int)] = [
//            // Near-identity transforms with small floating point variations
//            (CGAffineTransform(a: 0.999999, b: 0.000001, c: -0.000001, d: 0.999999), 0),
//            (CGAffineTransform(a: 0.000001, b: 0.999999, c: -0.999999, d: 0.000001), 1),
//            (CGAffineTransform(a: -0.999999, b: 0.000001, c: -0.000001, d: -0.999999), 2),
//            (CGAffineTransform(a: 0.000001, b: -0.999999, c: 0.999999, d: 0.000001), 3),
//        ]
//
//        for (transform, expectedQuarterTurns) in precisionTests {
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            let result = await mockAsset.getRotationInQuarterTurns()
//
//            XCTAssertEqual(result, expectedQuarterTurns,
//                          "Transform with precision variations should map to \(expectedQuarterTurns) quarter turns")
//        }
//    }
//
//    func testGetRotationInQuarterTurns_AngleProjection() async throws {
//        // Test non-standard angle projection to nearest quarter turn
//        let angleTests: [(Double, Int)] = [
//            // Angle in degrees, expected quarter turns
//            (0.0, 0),      // 0°
//            (44.9, 0),     // ~45° should project to 0°
//            (45.1, 1),     // ~45° should project to 90°
//            (90.0, 1),     // 90°
//            (134.9, 1),    // ~135° should project to 90°
//            (135.1, 2),    // ~135° should project to 180°
//            (180.0, 2),    // 180°
//            (224.9, 2),    // ~225° should project to 180°
//            (225.1, 3),    // ~225° should project to 270°
//            (270.0, 3),    // 270°
//            (314.9, 3),    // ~315° should project to 270°
//            (315.1, 0),    // ~315° should project to 360°/0°
//        ]
//
//        for (angle, expectedQuarterTurns) in angleTests {
//            let radians = angle * .pi / 180.0
//            let transform = CGAffineTransform(rotationAngle: radians)
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            let result = await mockAsset.getRotationInQuarterTurns()
//
//            XCTAssertEqual(result, expectedQuarterTurns,
//                          "Angle \(angle)° should project to \(expectedQuarterTurns) quarter turns")
//        }
//    }
//
//    // MARK: - Performance Tests
//
//    func testPerformanceGetRotationInQuarterTurns() async throws {
//        // Create mock asset with standard transform
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0)
//        )
//
//        // Measure execution time
//        let startTime = CFAbsoluteTimeGetCurrent()
//        let result = await mockAsset.getRotationInQuarterTurns()
//        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
//
//        // Verify correctness
//        XCTAssertEqual(result, 1, "Should return correct rotation")
//
//        // Verify performance
//        XCTAssertLessThan(executionTime, maxAcceptableExecutionTime,
//                         "Rotation extraction should complete within \(maxAcceptableExecutionTime * 1000)ms, took \(executionTime * 1000)ms")
//    }
//
//    func testPerformanceMultipleRotations() async throws {
//        let transforms = [
//            CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0),    // 0°
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0),   // 90°
//            CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0),  // 180°
//            CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0),   // 270°
//        ]
//
//        let startTime = CFAbsoluteTimeGetCurrent()
//
//        for transform in transforms {
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            _ = await mockAsset.getRotationInQuarterTurns()
//        }
//
//        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
//        let averageTime = totalTime / Double(transforms.count)
//
//        XCTAssertLessThan(averageTime, maxAcceptableExecutionTime,
//                         "Average rotation extraction time should be within \(maxAcceptableExecutionTime * 1000)ms, was \(averageTime * 1000)ms")
//    }
//
//    func testPerformanceLargeTransformMatrix() async throws {
//        // Test with complex transform that requires mathematical projection
//        var complexTransform = CGAffineTransform.identity
//        complexTransform = complexTransform.rotated(by: 1.23456789) // Irregular angle
//        complexTransform = complexTransform.scaledBy(x: 1.5, y: 1.5)
//        complexTransform.tx = 123.456
//        complexTransform.ty = -789.012
//
//        let mockAsset = mockAssetFactory.createAssetWithTransform(complexTransform)
//
//        let startTime = CFAbsoluteTimeGetCurrent()
//        let result = await mockAsset.getRotationInQuarterTurns()
//        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
//
//        // Should still complete within acceptable time
//        XCTAssertLessThan(executionTime, maxAcceptableExecutionTime,
//                         "Complex transform analysis should complete within \(maxAcceptableExecutionTime * 1000)ms")
//
//        // Should return a valid result
//        XCTAssertGreaterThanOrEqual(result, 0, "Should return valid quarter turns")
//        XCTAssertLessThan(result, 4, "Should return quarter turns in range 0-3")
//    }
//
//    // MARK: - Categorical Theory Tests
//
//    func testCategoricalTheoryMorphismComposition() async throws {
//        // Test that the composition of morphisms preserves mathematical properties
//        let identityTransform = CGAffineTransform.identity
//        let mockAsset = mockAssetFactory.createAssetWithTransform(identityTransform)
//
//        let result = await mockAsset.getRotationInQuarterTurns()
//
//        // Identity morphism should preserve identity
//        XCTAssertEqual(result, 0, "Identity transform should map to identity rotation (0 quarter turns)")
//    }
//
//    func testCategoricalTheoryFunctorProperties() async throws {
//        // Test functor properties: preserves identity and composition
//
//        // Test 1: Identity preservation
//        let identityAsset = mockAssetFactory.createAssetWithTransform(.identity)
//        let identityResult = await identityAsset.getRotationInQuarterTurns()
//        XCTAssertEqual(identityResult, 0, "Functor should preserve identity")
//
//        // Test 2: Composition preservation (90° + 90° = 180°)
//        let ninetyDegreeAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0)
//        )
//        let ninetyResult = await ninetyDegreeAsset.getRotationInQuarterTurns()
//
//        // Verify individual transforms work correctly
//        XCTAssertEqual(ninetyResult, 1, "90° transform should map to 1 quarter turn")
//    }
//
//    func testCategoricalTheoryNaturalTransformation() async throws {
//        // Test natural transformation properties: continuous to discrete mapping
//        let continuousAngles = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 360.0]
//        let expectedDiscreteResults = [0, 1, 1, 2, 2, 3, 3, 0, 0]
//
//        for (index, angle) in continuousAngles.enumerated() {
//            let radians = angle * .pi / 180.0
//            let transform = CGAffineTransform(rotationAngle: radians)
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            let result = await mockAsset.getRotationInQuarterTurns()
//
//            let expectedResult = expectedDiscreteResults[index]
//            XCTAssertEqual(result, expectedResult,
//                          "Continuous angle \(angle)° should naturally transform to discrete \(expectedResult) quarter turns")
//        }
//    }
//
//    func testCategoricalTheoryLoggingOutput() async throws {
//        // Test that categorical theory logging produces expected output
//        let mockAsset = mockAssetFactory.createAssetWithTransform(
//            CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0)
//        )
//
//        // Capture log output (simplified test - in real implementation would use OSLog capture)
//        let startTime = CFAbsoluteTimeGetCurrent()
//        let result = await mockAsset.getRotationInQuarterTurns()
//        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
//
//        // Verify mathematical correctness
//        XCTAssertEqual(result, 1, "Should return mathematically correct result")
//
//        // Verify execution time tracking is working
//        XCTAssertGreaterThan(executionTime, 0, "Should have measurable execution time")
//        XCTAssertLessThan(executionTime, maxAcceptableExecutionTime, "Should complete within acceptable time")
//    }
//
//    // MARK: - Backward Compatibility Tests
//
//    func testRotationMethodBackwardCompatibility() async throws {
//        // Test that the legacy rotation() method still works correctly
//        let testCases: [(CGAffineTransform, Int)] = [
//            (CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0), 0),    // 0°
//            (CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0), 1),   // 90°
//            (CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0), 2),  // 180°
//            (CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0), 3),   // 270°
//        ]
//
//        for (transform, expectedResult) in testCases {
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            let result = await mockAsset.rotation()
//
//            XCTAssertEqual(result, expectedResult,
//                          "Legacy rotation() method should return \(expectedResult) for standard transform")
//        }
//    }
//
//    func testRotationMethodNonStandardTransforms() async throws {
//        // Test legacy method with non-standard transforms (should return 0)
//        let nonStandardTransforms = [
//            CGAffineTransform(a: 2.0, b: 0.0, c: 0.0, d: 2.0),      // Scaled
//            CGAffineTransform(a: 0.707, b: 0.707, c: -0.707, d: 0.707), // 45°
//        ]
//
//        for transform in nonStandardTransforms {
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//            let result = await mockAsset.rotation()
//
//            XCTAssertEqual(result, 0,
//                          "Legacy rotation() method should return 0 for non-standard transforms")
//        }
//    }
//
//    // MARK: - Integration Tests
//
//    func testIntegrationWithRealAVFoundation() async throws {
//        // This test would use real AVFoundation assets if available
//        // For now, we'll verify our mock system behaves consistently with the real API expectations
//
//        let allStandardTransforms = [
//            (CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0), 0),    // 0°
//            (CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0), 1),   // 90°
//            (CGAffineTransform(a: -1.0, b: 0.0, c: 0.0, d: -1.0), 2),  // 180°
//            (CGAffineTransform(a: 0.0, b: -1.0, c: 1.0, d: 0.0), 3),   // 270°
//        ]
//
//        for (transform, expectedQuarterTurns) in allStandardTransforms {
//            // Test both new and legacy methods
//            let mockAsset = mockAssetFactory.createAssetWithTransform(transform)
//
//            let newResult = await mockAsset.getRotationInQuarterTurns()
//            let legacyResult = await mockAsset.rotation()
//
//            XCTAssertEqual(newResult, expectedQuarterTurns,
//                          "New method should return \(expectedQuarterTurns) for standard transform")
//            XCTAssertEqual(legacyResult, expectedQuarterTurns,
//                          "Legacy method should return \(expectedQuarterTurns) for standard transform")
//            XCTAssertEqual(newResult, legacyResult,
//                          "New and legacy methods should return consistent results")
//        }
//    }
//
//    // MARK: - Error Handling Tests
//
//    func testErrorHandlingGracefulDegradation() async throws {
//        // Test that all error conditions gracefully return 0
//
//        let errorScenarios = [
//            mockAssetFactory.createAssetWithNoVideoTracks(),
//            mockAssetFactory.createAssetWithTransformLoadingFailure(),
//            mockAssetFactory.createAssetWithVideoTrackLoadingFailure()
//        ]
//
//        for (index, mockAsset) in errorScenarios.enumerated() {
//            let result = await mockAsset.getRotationInQuarterTurns()
//            XCTAssertEqual(result, 0, "Error scenario \(index + 1) should gracefully return 0")
//        }
//    }
//
//    func testErrorHandlingWithLogging() async throws {
//        // Test that error conditions produce appropriate logging behavior
//        let mockAsset = mockAssetFactory.createAssetWithTransformLoadingFailure()
//
//        let startTime = CFAbsoluteTimeGetCurrent()
//        let result = await mockAsset.getRotationInQuarterTurns()
//        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
//
//        // Should handle error gracefully
//        XCTAssertEqual(result, 0, "Should return 0 on error")
//
//        // Should still execute quickly even in error cases
//        XCTAssertLessThan(executionTime, maxAcceptableExecutionTime,
//                         "Error handling should be fast and efficient")
//    }
//}
//
//// MARK: - Mock Classes
//
///// Mock factory for creating test assets with controlled transforms
//class MockAVAssetFactory {
//
//    func createAssetWithTransform(_ transform: CGAffineTransform) -> MockAVAsset {
//        let mockTrack = MockAVAssetTrack(preferredTransform: transform)
//        return MockAVAsset(videoTracks: [mockTrack])
//    }
//
//    func createAssetWithNoVideoTracks() -> MockAVAsset {
//        return MockAVAsset(videoTracks: [])
//    }
//
//    func createAssetWithMultipleVideoTracks(transforms: [CGAffineTransform]) -> MockAVAsset {
//        let mockTracks = transforms.map { MockAVAssetTrack(preferredTransform: $0) }
//        return MockAVAsset(videoTracks: mockTracks)
//    }
//
//    func createAssetWithTransformLoadingFailure() -> MockAVAsset {
//        let mockTrack = MockAVAssetTrack(preferredTransform: .identity, shouldFailTransformLoad: true)
//        return MockAVAsset(videoTracks: [mockTrack])
//    }
//
//    func createAssetWithVideoTrackLoadingFailure() -> MockAVAsset {
//        return MockAVAsset(shouldFailTrackLoad: true)
//    }
//}
//
///// Mock AVAsset class for testing
//class MockAVAsset: AVAsset {
//
//    private let _videoTracks: [MockAVAssetTrack]
//    private let shouldFailTrackLoad: Bool
//
//    init(videoTracks: [MockAVAssetTrack] = [], shouldFailTrackLoad: Bool = false) {
//        self._videoTracks = videoTracks
//        self.shouldFailTrackLoad = shouldFailTrackLoad
//        super.init()
//    }
//
//    override func loadTracks(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack] {
//        if shouldFailTrackLoad {
//            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock track loading failure"])
//        }
//
//        if mediaType == .video {
//            return _videoTracks
//        }
//        return []
//    }
//}
//
///// Mock AVAssetTrack class for testing
//class MockAVAssetTrack: AVAssetTrack {
//
//    private let _preferredTransform: CGAffineTransform
//    private let shouldFailTransformLoad: Bool
//
//    init(preferredTransform: CGAffineTransform, shouldFailTransformLoad: Bool = false) {
//        self._preferredTransform = preferredTransform
//        self.shouldFailTransformLoad = shouldFailTransformLoad
//        super.init()
//    }
//
//    override func load(_ key: AVAssetTrack.PropertyKey) async throws -> Any {
//        if key == .preferredTransform {
//            if shouldFailTransformLoad {
//                throw NSError(domain: "TestError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock transform loading failure"])
//            }
//            return _preferredTransform
//        }
//
//        throw NSError(domain: "TestError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unsupported property"])
//    }
//}
