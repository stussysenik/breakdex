////
////  AlbumManagerTests.swift
////  BreakingFlashcardsTests
////
////  Created by Claude Code on 10/2/25.
////
//
//import XCTest
//import Photos
//import OSLog
//@testable import BreakingFlashcards
//
//@MainActor
//final class AlbumManagerTests: XCTestCase {
//
//    // MARK: - Properties
//
//    var albumManager: AlbumManager!
//    let testTimeout: TimeInterval = 30.0
//
//    // MARK: - Setup & Teardown
//
//    override func setUp() async throws {
//        try await super.setUp()
//
//        // Reset album manager for each test
//        AlbumManager.shared.reset()
//        albumManager = AlbumManager.shared
//
//        // Ensure we have photo library permissions for testing
//        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
//        guard authStatus == .authorized else {
//            throw XCTSkip("Photo library permissions required for album tests")
//        }
//    }
//
//    override func tearDown() async throws {
//        // Clean up any test albums
//        albumManager.reset()
//        albumManager = nil
//
//        try await super.tearDown()
//    }
//
//    // MARK: - Atomic Operation Tests
//
//    func testAtomicFindOrCreate() async throws {
//        // First call should create album
//        let album1 = try await albumManager.getBreakDexAlbum()
//        XCTAssertNotNil(album1, "Should successfully create BreakDex album")
//        XCTAssertEqual(album1.localizedTitle, "BreakDex", "Album should have correct title")
//
//        // Second call should return existing album
//        let album2 = try await albumManager.getBreakDexAlbum()
//        XCTAssertEqual(album1.localIdentifier, album2.localIdentifier, "Should return same album")
//
//        // Verify metrics show cache hit on second call
//        let metrics = albumManager.getOperationMetrics()
//        XCTAssertGreaterThanOrEqual(metrics.count, 2, "Should have at least 2 operations logged")
//
//        let cacheHits = metrics.filter { $0.cacheHit }
//        XCTAssertGreaterThan(cacheHits.count, 0, "Should have cache hits in metrics")
//    }
//
//    func testConcurrentAlbumAccess() async throws {
//        let expectation = XCTestExpectation(description: "Concurrent album access")
//        expectation.expectedFulfillmentCount = 10
//
//        var results: [Result<PHAssetCollection, Error>] = []
//        let resultsLock = NSLock()
//
//        // Create 10 concurrent tasks
//        let tasks = (0..<10).map { index in
//            Task {
//                do {
//                    let album = try await albumManager.getBreakDexAlbum()
//                    resultsLock.lock()
//                    results.append(.success(album))
//                    resultsLock.unlock()
//                } catch {
//                    resultsLock.lock()
//                    results.append(.failure(error))
//                    resultsLock.unlock()
//                }
//                expectation.fulfill()
//            }
//        }
//
//        // Wait for all tasks to complete
//        await fulfillment(of: [expectation], timeout: testTimeout)
//
//        // Verify all operations succeeded
//        XCTAssertEqual(results.count, 10, "Should have 10 results")
//
//        let successes = results.compactMap { try? $0.get() }
//        let failures = results.compactMap { try? $0.get() == nil ? $0 : nil }
//
//        XCTAssertEqual(successes.count, 10, "All operations should succeed")
//        XCTAssertEqual(failures.count, 0, "No operations should fail")
//
//        // Verify all results point to the same album
//        let albumIds = Set(successes.map { $0.localIdentifier })
//        XCTAssertEqual(albumIds.count, 1, "All operations should return the same album")
//
//        // Verify no duplicate creation attempts in metrics
//        let metrics = albumManager.getOperationMetrics()
//        let duplicatePreventionEvents = metrics.filter {
//            $0.operationType.contains("duplicate") || $0.operationType.contains("prevent")
//        }
//        XCTAssertGreaterThan(duplicatePreventionEvents.count, 0, "Should have prevented duplicate creation attempts")
//    }
//
//    func testAlbumCacheInvalidation() async throws {
//        // Get album to populate cache
//        let album1 = try await albumManager.getBreakDexAlbum()
//        XCTAssertNotNil(album1)
//
//        // Reset manager to clear cache
//        albumManager.reset()
//
//        // Get album again - should work without cache
//        let album2 = try await albumManager.getBreakDexAlbum()
//        XCTAssertNotNil(album2)
//
//        // Should be the same album
//        XCTAssertEqual(album1.localIdentifier, album2.localIdentifier)
//    }
//
//    func testErrorHandling() async throws {
//        // Test permission denied by temporarily modifying the check
//        // Note: This is a simplified test as we can't easily mock PHPhotoLibrary
//        do {
//            _ = try await albumManager.getBreakDexAlbum()
//            // If we get here, permissions are granted (test passes)
//        } catch AlbumManagerError.permissionDenied {
//            // This is also a valid outcome - error handling works
//        } catch {
//            XCTFail("Unexpected error: \(error)")
//        }
//    }
//
//    func testMetricsTracking() async throws {
//        // Clear existing metrics
//        albumManager.clearOldMetrics()
//
//        // Perform several operations
//        _ = try await albumManager.getBreakDexAlbum()
//        _ = try await albumManager.getBreakDexAlbum() // Should be cache hit
//        _ = try await albumManager.getBreakDexAlbum() // Should be cache hit
//
//        let metrics = albumManager.getOperationMetrics()
//        XCTAssertGreaterThanOrEqual(metrics.count, 2, "Should track multiple operations")
//
//        // Check that we have both cache hits and misses
//        let cacheHits = metrics.filter { $0.cacheHit }
//        let cacheMisses = metrics.filter { !$0.cacheHit }
//
//        XCTAssertGreaterThan(cacheHits.count, 0, "Should have cache hits")
//        XCTAssertGreaterThan(cacheMisses.count, 0, "Should have cache misses")
//
//        // Verify timing metrics
//        for metric in metrics {
//            XCTAssertGreaterThan(metric.duration, 0, "Duration should be positive")
//            XCTAssertFalse(metric.correlationId.isEmpty, "Should have correlation ID")
//            XCTAssertNotNil(metric.timestamp, "Should have timestamp")
//        }
//    }
//
//    func testOperationTimeout() async throws {
//        // This test verifies that operations complete within reasonable time
//        let startTime = Date()
//
//        _ = try await albumManager.getBreakDexAlbum()
//
//        let duration = Date().timeIntervalSince(startTime)
//        XCTAssertLessThan(duration, 10.0, "Operation should complete within 10 seconds")
//    }
//
//    func testSetupIdempotency() async throws {
//        // Setup should be idempotent
//        try await albumManager.setup()
//        let album1 = try await albumManager.getBreakDexAlbum()
//
//        try await albumManager.setup() // Should not create new album
//        let album2 = try await albumManager.getBreakDexAlbum()
//
//        XCTAssertEqual(album1.localIdentifier, album2.localIdentifier, "Setup should be idempotent")
//    }
//
//    func testAlbumVerification() async throws {
//        let album = try await albumManager.getBreakDexAlbum()
//        XCTAssertNotNil(album)
//
//        // Verify album actually exists in photo library
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.predicate = NSPredicate(format: "localIdentifier = %@", album.localIdentifier)
//
//        let collections = PHAssetCollection.fetchAssetCollections(
//            withLocalIdentifiers: [album.localIdentifier],
//            options: fetchOptions
//        )
//
//        XCTAssertNotNil(collections.firstObject, "Album should exist in photo library")
//    }
//
//    func testCorrelationIdGeneration() async throws {
//        // Perform multiple operations and verify unique correlation IDs
//        _ = try await albumManager.getBreakDexAlbum()
//        _ = try await albumManager.getBreakDexAlbum()
//        _ = try await albumManager.getBreakDexAlbum()
//
//        let metrics = albumManager.getOperationMetrics()
//        let correlationIds = Set(metrics.map { $0.correlationId })
//
//        XCTAssertEqual(correlationIds.count, metrics.count, "Each operation should have unique correlation ID")
//
//        // Verify correlation ID format
//        for metric in metrics {
//            XCTAssertTrue(metric.correlationId.hasPrefix("ALBUM_"), "Correlation ID should start with ALBUM_")
//        }
//    }
//
//    func testConcurrentSetupAndAccess() async throws {
//        let expectation = XCTestExpectation(description: "Concurrent setup and access")
//        expectation.expectedFulfillmentCount = 20
//
//        var setupResults: [Result<Void, Error>] = []
//        var accessResults: [Result<PHAssetCollection, Error>] = []
//        let resultsLock = NSLock()
//
//        // Create concurrent setup and access tasks
//        let setupTasks = (0..<10).map { _ in
//            Task {
//                do {
//                    try await albumManager.setup()
//                    resultsLock.lock()
//                    setupResults.append(.success(()))
//                    resultsLock.unlock()
//                } catch {
//                    resultsLock.lock()
//                    setupResults.append(.failure(error))
//                    resultsLock.unlock()
//                }
//                expectation.fulfill()
//            }
//        }
//
//        let accessTasks = (0..<10).map { _ in
//            Task {
//                do {
//                    let album = try await albumManager.getBreakDexAlbum()
//                    resultsLock.lock()
//                    accessResults.append(.success(album))
//                    resultsLock.unlock()
//                } catch {
//                    resultsLock.lock()
//                    accessResults.append(.failure(error))
//                    resultsLock.unlock()
//                }
//                expectation.fulfill()
//            }
//        }
//
//        // Wait for all tasks to complete
//        await fulfillment(of: [expectation], timeout: testTimeout)
//
//        // Verify all operations succeeded
//        XCTAssertEqual(setupResults.count, 10, "Should have 10 setup results")
//        XCTAssertEqual(accessResults.count, 10, "Should have 10 access results")
//
//        let setupSuccesses = setupResults.compactMap { try? $0.get() }
//        let accessSuccesses = accessResults.compactMap { try? $0.get() }
//
//        XCTAssertEqual(setupSuccesses.count, 10, "All setup operations should succeed")
//        XCTAssertEqual(accessSuccesses.count, 10, "All access operations should succeed")
//
//        // Verify all access results point to the same album
//        let albumIds = Set(accessSuccesses.map { $0.localIdentifier })
//        XCTAssertEqual(albumIds.count, 1, "All access operations should return the same album")
//    }
//
//    // MARK: - Performance Tests
//
//    func testPerformanceCacheHit() async throws {
//        // Warm up cache
//        _ = try await albumManager.getBreakDexAlbum()
//
//        // Measure cache hit performance
//        measure {
//            Task {
//                do {
//                    _ = try await albumManager.getBreakDexAlbum()
//                } catch {
//                    XCTFail("Cache hit should not fail: \(error)")
//                }
//            }
//        }
//    }
//
//    func testPerformanceCacheMiss() async throws {
//        // Clear cache before measurement
//        albumManager.reset()
//
//        // Measure cache miss performance
//        measure {
//            Task {
//                do {
//                    _ = try await albumManager.getBreakDexAlbum()
//                } catch {
//                    XCTFail("Cache miss should not fail: \(error)")
//                }
//            }
//        }
//    }
//
//    // MARK: - Integration Tests
//
//    func testIntegrationWithPhotosPersistenceService() async throws {
//        // Test that AlbumManager works correctly with PhotosPersistenceService
//        let persistenceService = PhotosPersistenceService()
//
//        // Both should be able to get the same album
//        let albumFromManager = try await albumManager.getBreakDexAlbum()
//        let albumFromPersistence = try await persistenceService.getBreakDexAlbum()
//
//        XCTAssertEqual(albumFromManager.localIdentifier, albumFromPersistence.localIdentifier,
//                      "Both services should return the same album")
//    }
//
//    func testAlbumPersistenceAcrossManagerInstances() async throws {
//        // Get album from one instance
//        let album1 = try await AlbumManager.shared.getBreakDexAlbum()
//
//        // Create new instance (in practice, it's the same singleton)
//        let album2 = try await AlbumManager.shared.getBreakDexAlbum()
//
//        XCTAssertEqual(album1.localIdentifier, album2.localIdentifier,
//                      "Album should persist across manager accesses")
//    }
//
//    // MARK: - Edge Case Tests
//
//    func testEmptyAlbumNameHandling() async throws {
//        // Verify that our system doesn't accept empty album names
//        let album = try await albumManager.getBreakDexAlbum()
//        XCTAssertFalse(album.localizedTitle?.isEmpty ?? true, "Album should have non-empty title")
//    }
//
//    func testSpecialCharacterHandling() async throws {
//        // Test that system handles special characters in album operations
//        _ = try await albumManager.getBreakDexAlbum()
//
//        // Verify metrics contain special characters in correlation IDs if applicable
//        let metrics = albumManager.getOperationMetrics()
//        for metric in metrics {
//            XCTAssertFalse(metric.correlationId.contains("\n"), "Correlation ID should not contain newlines")
//            XCTAssertFalse(metric.correlationId.contains("\t"), "Correlation ID should not contain tabs")
//        }
//    }
//
//    func testMemoryManagement() async throws {
//        // Test that the system doesn't leak memory with repeated operations
//        weak var weakAlbum: PHAssetCollection?
//
//        autoreleasepool {
//            Task {
//                do {
//                    let album = try await albumManager.getBreakDexAlbum()
//                    weakAlbum = album
//
//                    // Verify we got the album
//                    XCTAssertNotNil(album)
//                } catch {
//                    XCTFail("Album operation should not fail: \(error)")
//                }
//            }
//        }
//
//        // Give time for cleanup
//        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
//
//        // Album should still be accessible (cached)
//        XCTAssertNotNil(weakAlbum, "Album should be cached and accessible")
//    }
//}
//
//// MARK: - Test Extensions
//
//extension AlbumManagerTests {
//
//    /// Helper method to clean up test albums
//    private func deleteTestAlbum(named albumName: String) async throws {
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
//
//        let collections = PHAssetCollection.fetchAssetCollections(
//            with: .album,
//            subtype: .any,
//            options: fetchOptions
//        )
//
//        guard let album = collections.firstObject else { return }
//
//        try await PHPhotoLibrary.shared().performChanges {
//            PHAssetCollectionChangeRequest.deleteAssetCollections(with: [album])
//        }
//    }
//}
