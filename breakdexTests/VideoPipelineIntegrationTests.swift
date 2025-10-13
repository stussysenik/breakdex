////
////  VideoPipelineIntegrationTests.swift
////  BreakingFlashcardsTests
////
////  Created by Claude Code on 9/27/25.
////
//
//import XCTest
//import AVFoundation
//import Photos
//@testable import BreakingFlashcards
//
//// MARK: - Video Pipeline Integration Tests
//@MainActor
//final class VideoPipelineIntegrationTests: XCTestCase {
//
//    // MARK: - Properties
//    private var videoLoadingService: VideoLoadingService!
//    private var videoProcessor: EnhancedVideoProcessor!
//    private var photosPersistenceService: PhotosPersistenceService!
//    private var saveProgressViewModel: SaveProgressViewModel!
//    private var context: NSManagedObjectContext!
//    private var testPersistentContainer: NSPersistentContainer!
//
//    // MARK: - Test Setup
//    override func setUp() async throws {
//        try await super.setUp()
//
//        // Setup Core Data in-memory stack for testing
//        testPersistentContainer = NSPersistentContainer(name: "BreakingFlashcards")
//
//        // Use in-memory store for testing
//        let description = NSPersistentStoreDescription()
//        description.type = NSInMemoryStoreType
//
//        testPersistentContainer.persistentStoreDescriptions = [description]
//
//        await testPersistentContainer.loadPersistentStores { _, error in
//            if let error = error {
//                XCTFail("Failed to load persistent stores: \(error)")
//            }
//        }
//
//        context = testPersistentContainer.newBackgroundContext()
//
//        // Initialize services
//        videoLoadingService = VideoLoadingService()
//        videoProcessor = EnhancedVideoProcessor()
//        photosPersistenceService = PhotosPersistenceService()
//        saveProgressViewModel = SaveProgressViewModel(
//            videoLoadingService: videoLoadingService,
//            videoProcessor: videoProcessor,
//            photosPersistenceService: photosPersistenceService,
//            context: context
//        )
//
//        // Setup album manager for testing
//        await AlbumManager.shared.setup()
//    }
//
//    override func tearDown() async throws {
//        // Clean up resources
//        await saveProgressViewModel.resetState()
//        await videoLoadingService.cleanupTemporaryFiles()
//
//        // Reset Core Data
//        try await context.perform {
//            let fetchRequest = Move.fetchRequest()
//            let moves = try self.context.fetch(fetchRequest)
//            for move in moves {
//                self.context.delete(move)
//            }
//            try self.context.save()
//        }
//
//        // Clean up persistent container
//        await testPersistentContainer.viewContext.perform {
//            try? self.testPersistentContainer.viewContext.save()
//        }
//
//        testPersistentContainer = nil
//        context = nil
//
//        await super.tearDown()
//    }
//
//    // MARK: - Integration Tests
//
//    // MARK: Category Theory Validation Tests
//    func testCategoryTheoryMapping_EfficientFunctor() async throws {
//        // Test that the functor is efficient (streaming vs memory loading)
//        let testVideoURL = try createTestVideoFile()
//
//        let expectation = XCTestExpectation(description: "Efficient functor mapping")
//        var memoryUsageBefore: Double = 0.0
//        var memoryUsageAfter: Double = 0.0
//
//        // Measure memory before loading
//        memoryUsageBefore = getMemoryUsageMB()
//
//        let cancellable = videoLoadingService.progressPublisher
//            .sink { progress in
//                if progress.phase == .completed {
//                    memoryUsageAfter = self.getMemoryUsageMB()
//                    expectation.fulfill()
//                }
//            }
//
//        // Load video using streaming approach
//        let result = try await videoLoadingService.loadVideo(from: testVideoURL)
//
//        await fulfillment(of: [expectation], timeout: 10.0)
//        cancellable.cancel()
//
//        // Verify efficient memory usage (should not increase significantly)
//        let memoryIncrease = memoryUsageAfter - memoryUsageBefore
//        XCTAssertLessThan(memoryIncrease, 50.0, "Memory increase should be less than 50MB for streaming approach")
//
//        // Verify result structure
//        XCTAssertNotNil(result.asset)
//        XCTAssertEqual(result.sourceType, .fileURL)
//        XCTAssertFalse(result.filename.isEmpty)
//        XCTAssertEqual(result.correlationId.count, 36) // UUID length
//    }
//
//    func testCategoryTheoryIsomorphism_WYSIWYG() async throws {
//        // Test that WYSIWYG is maintained through proper transforms
//        let testVideoURL = try createTestVideoFile()
//        let rotationQuarterTurns = 1 // 90 degrees
//
//        // Load video
//        let loadingResult = try await videoLoadingService.loadVideo(from: testVideoURL)
//
//        // Process video with rotation
//        let processingResult = try await videoProcessor.processVideo(
//            loadingResult.asset,
//            rotationQuarterTurns: rotationQuarterTurns,
//            trimRange: nil
//        )
//
//        // Verify isomorphism - output should maintain input properties with proper transformation
//        XCTAssertEqual(processingResult.appliedRotation, rotationQuarterTurns)
//        XCTAssertNotNil(processingResult.videoComposition, "Video composition should exist for rotation")
//
//        // Test that player item can be created for preview
//        let playerItem = try await videoProcessor.createPlayerItem(
//            asset: loadingResult.asset,
//            rotationQuarterTurns: rotationQuarterTurns,
//            trimRange: nil
//        )
//
//        XCTAssertNotNil(playerItem.videoComposition, "Player item should have video composition")
//        XCTAssertEqual(playerItem.asset.duration, loadingResult.asset.duration, "Duration should be preserved")
//    }
//
//    func testCategoryTheoryAdjoint_AtomicOperations() async throws {
//        // Test that atomic operations prevent race conditions
//        let testVideoURL1 = try createTestVideoFile()
//        let testVideoURL2 = try createTestVideoFile()
//
//        // Simulate concurrent save operations
//        let expectation1 = XCTestExpectation(description: "First save operation")
//        let expectation2 = XCTestExpectation(description: "Second save operation")
//
//        var results: [PhotosPersistenceResult] = []
//
//        // First save operation
//        Task {
//            do {
//                let result1 = try await photosPersistenceService.saveVideoAsset(
//                    testVideoURL1,
//                    filename: "test1.mov",
//                    sourceIdentifier: nil
//                )
//                results.append(result1)
//                expectation1.fulfill()
//            } catch {
//                XCTFail("First save operation failed: \(error)")
//                expectation1.fulfill()
//            }
//        }
//
//        // Second save operation (should not cause race condition)
//        Task {
//            do {
//                let result2 = try await photosPersistenceService.saveVideoAsset(
//                    testVideoURL2,
//                    filename: "test2.mov",
//                    sourceIdentifier: nil
//                )
//                results.append(result2)
//                expectation2.fulfill()
//            } catch {
//                XCTFail("Second save operation failed: \(error)")
//                expectation2.fulfill()
//            }
//        }
//
//        await fulfillment(of: [expectation1, expectation2], timeout: 30.0)
//
//        // Verify both operations completed successfully
//        XCTAssertEqual(results.count, 2, "Both save operations should complete")
//        XCTAssertNotEqual(results[0].localAssetIdentifier, results[1].localAssetIdentifier, "Assets should have different identifiers")
//    }
//
//    func testCategoryTheoryObjectGap_CloudIdentifier() async throws {
//        // Test that cloud identifier closes the object gap
//        let testVideoURL = try createTestVideoFile()
//
//        // Save video asset
//        let persistenceResult = try await photosPersistenceService.saveVideoAsset(
//            testVideoURL,
//            filename: "cloud-test.mov",
//            sourceIdentifier: nil
//        )
//
//        // Verify cloud identifier exists
//        XCTAssertNotNil(persistenceResult.cloudAssetIdentifier, "Cloud identifier should be generated")
//
//        // Test that we can check cloud sync status
//        let isCloudSynced = try await photosPersistenceService.checkCloudSyncStatus(for: persistenceResult.localAssetIdentifier)
//        XCTAssertFalse(isCloudSynced, "Test asset should not be cloud synced (local)")
//
//        // Verify cloud identifier format
//        if let cloudId = persistenceResult.cloudAssetIdentifier {
//            XCTAssertTrue(cloudId.contains("cloud") || cloudId.contains("icloud"), "Cloud identifier should indicate cloud origin")
//        }
//    }
//
//    // MARK: End-to-End Pipeline Tests
//
//    func testEndToEndSaveFlow_Orchestration() async throws {
//        // Test the complete end-to-end save flow
//        let testVideoURL = try createTestVideoFile()
//
//        let configuration = SaveFlowConfiguration(
//            videoSource: .url(testVideoURL),
//            moveName: "Integration Test Move",
//            rotationQuarterTurns: 1,
//            trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)),
//            tags: "test,integration",
//            learningState: "new"
//        )
//
//        let saveExpectation = XCTestExpectation(description: "End-to-end save flow")
//
//        var saveResult: SaveFlowResult?
//
//        // Monitor state changes
//        let stateCancellable = saveProgressViewModel.$saveState
//            .sink { state in
//                if case .completed = state {
//                    saveExpectation.fulfill()
//                }
//            }
//
//        // Start save flow
//        await saveProgressViewModel.startSaveFlow(configuration: configuration)
//
//        await fulfillment(of: [saveExpectation], timeout: 30.0)
//        stateCancellable.cancel()
//
//        // Verify result
//        XCTAssertEqual(saveProgressViewModel.saveState, .completed)
//        XCTAssertNil(saveProgressViewModel.errorMessage)
//        XCTAssertNotNil(saveProgressViewModel.correlationId)
//
//        // Verify saved move in database
//        let savedMoves = try await context.perform {
//            let fetchRequest = Move.fetchRequest()
//            return try self.context.fetch(fetchRequest)
//        }
//
//        XCTAssertEqual(savedMoves.count, 1, "Should have exactly one saved move")
//        let savedMove = savedMoves.first!
//
//        XCTAssertEqual(savedMove.name, "Integration Test Move")
//        XCTAssertEqual(savedMove.rotationQuarterTurns, 1)
//        XCTAssertEqual(savedMove.tags, "test,integration")
//        XCTAssertEqual(savedMove.learningState, "new")
//        XCTAssertNotNil(savedMove.photosIdentifier)
//        XCTAssertNotNil(savedMove.videoAssetCloudIdentifier)
//        XCTAssertEqual(savedMove.trimStartTime, 0.0)
//        XCTAssertEqual(savedMove.trimEndTime, 5.0)
//    }
//
//    func testVideoProcessingProgress_FrameAccuracy() async throws {
//        // Test frame-accurate processing with progress tracking
//        let testVideoURL = try createTestVideoFile()
//
//        let progressExpectation = XCTestExpectation(description: "Processing progress")
//        var progressValues: [Double] = []
//
//        let cancellable = videoProcessor.progressPublisher
//            .sink { progress in
//                progressValues.append(progress.progress)
//                if progress.phase == .completed {
//                    progressExpectation.fulfill()
//                }
//            }
//
//        // Process video with rotation and trim
//        let result = try await videoProcessor.processVideo(
//            try await videoLoadingService.loadVideo(from: testVideoURL).asset,
//            rotationQuarterTurns: 2,
//            trimRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3.0, preferredTimescale: 600))
//        )
//
//        await fulfillment(of: [progressExpectation], timeout: 15.0)
//        cancellable.cancel()
//
//        // Verify progress tracking
//        XCTAssertFalse(progressValues.isEmpty, "Should have progress updates")
//        XCTAssertEqual(progressValues.last, 1.0, "Final progress should be 100%")
//
//        // Verify frame-accurate result
//        XCTAssertEqual(result.appliedRotation, 2)
//        XCTAssertEqual(result.asset.duration.seconds, 3.0, accuracy: 0.1, "Duration should match trim range")
//        XCTAssertGreaterThan(result.frameCount, 0, "Should have positive frame count")
//    }
//
//    func testErrorHandling_PipelineResilience() async throws {
//        // Test error handling across the pipeline
//        let invalidURL = URL(fileURLWithPath: "/invalid/path/video.mov")
//
//        // Test that loading handles invalid URLs gracefully
//        do {
//            _ = try await videoLoadingService.loadVideo(from: invalidURL)
//            XCTFail("Should have thrown an error for invalid URL")
//        } catch {
//            XCTAssertNotNil(error as? VideoLoadingError, "Should throw VideoLoadingError")
//        }
//
//        // Test that save flow handles loading errors
//        let configuration = SaveFlowConfiguration(
//            videoSource: .url(invalidURL),
//            moveName: "Error Test Move",
//            rotationQuarterTurns: 0,
//            trimRange: nil,
//            tags: nil,
//            learningState: nil
//        )
//
//        let errorExpectation = XCTestExpectation(description: "Error handling")
//
//        let cancellable = saveProgressViewModel.$saveState
//            .sink { state in
//                if case .failed = state {
//                    errorExpectation.fulfill()
//                }
//            }
//
//        await saveProgressViewModel.startSaveFlow(configuration: configuration)
//
//        await fulfillment(of: [errorExpectation], timeout: 10.0)
//        cancellable.cancel()
//
//        XCTAssertEqual(saveProgressViewModel.saveState, .failed)
//        XCTAssertNotNil(saveProgressViewModel.errorMessage)
//    }
//
//    // MARK: Performance Tests
//
//    func testPerformance_MemoryEfficiency() async throws {
//        // Test that the pipeline maintains memory efficiency
//        let testVideoURL = try createTestVideoFile()
//
//        measure {
//            Task {
//                do {
//                    let result = try await self.videoLoadingService.loadVideo(from: testVideoURL)
//                    XCTAssertNotNil(result.asset)
//                } catch {
//                    XCTFail("Performance test failed: \(error)")
//                }
//            }
//        }
//    }
//
//    func testPerformance_SaveFlowOrchestration() async throws {
//        // Test save flow orchestration performance
//        let testVideoURL = try createTestVideoFile()
//
//        let configuration = SaveFlowConfiguration(
//            videoSource: .url(testVideoURL),
//            moveName: "Performance Test Move",
//            rotationQuarterTurns: 1,
//            trimRange: nil,
//            tags: nil,
//            learningState: nil
//        )
//
//        measure {
//            Task {
//                let expectation = XCTestExpectation(description: "Performance test")
//                let cancellable = self.saveProgressViewModel.$saveState
//                    .sink { state in
//                        if case .completed = state {
//                            expectation.fulfill()
//                        }
//                    }
//
//                await self.saveProgressViewModel.startSaveFlow(configuration: configuration)
//
//                await fulfillment(of: [expectation], timeout: 30.0)
//                cancellable.cancel()
//            }
//        }
//    }
//
//    // MARK: - Helper Methods
//
//    private func createTestVideoFile() throws -> URL {
//        // Create a simple test video file
//        let tempDir = FileManager.default.temporaryDirectory
//        let testVideoURL = tempDir.appendingPathComponent("test-video-\(UUID().uuidString).mov")
//
//        // For testing purposes, create a small dummy file
//        let testData = "Test video data".data(using: .utf8)!
//        try testData.write(to: testVideoURL)
//
//        return testVideoURL
//    }
//
//    private func getMemoryUsageMB() -> Double {
//        var info = mach_task_basic_info()
//        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
//
//        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
//            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
//                task_info(mach_task_self_,
//                         task_flavor_t(MACH_TASK_BASIC_INFO),
//                         $0,
//                         &count)
//            }
//        }
//
//        if kerr == KERN_SUCCESS {
//            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
//        } else {
//            return 0.0
//        }
//    }
//}
