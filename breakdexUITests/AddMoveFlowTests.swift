//import XCTest
//import Combine
//import AVFoundation
//import Photos
//@testable import BreakingFlashcards // Assuming BreakingFlashcards is the module name
//
//class AddMoveFlowTests: XCTestCase {
//
//    var viewModel: AddMoveViewModel!
//    var cancellables: Set<AnyCancellable>!
//
//    override func setUpWithError() throws {
//        let inMemoryContext = PersistenceController(inMemory: true).container.viewContext
//        viewModel = AddMoveViewModel(viewContext: inMemoryContext)
//        cancellables = []
//    }
//
//    override func tearDownWithError() throws {
//        viewModel = nil
//        cancellables = nil
//    }
//
//    // MARK: - State Transition Tests
//
//    func testInitialStateIsReady() {
//        XCTAssertEqual(viewModel.state, .ready)
//    }
//
//    func testSelectionToLoadingToPreviewing() async throws {
//        // Mock a PhotosPickerItem
//        let mockItem = PhotosPickerItem(itemIdentifier: "mock_identifier")
//
//        // Mock PHAsset and AVAsset loading
//        // This is a simplified mock. In a real scenario, you'd mock PHAsset and AVAsset more thoroughly.
//        // For now, we'll rely on the actual Photos framework calls, but ensure they don't fail.
//        // If running on a simulator without Photos access, these might fail.
//        // A proper mock would involve creating stub PHAsset and AVAsset objects.
//
//        // Simulate selection
//        viewModel.selectedItem = mockItem
//
//        // Expect loading state
//        var loadingStateReceived = false
//        let loadingExpectation = XCTestExpectation(description: "Loading state received")
//        viewModel.$state
//            .dropFirst() // Drop initial .ready state
//            .sink { state in
//                if case .loading = state {
//                    loadingStateReceived = true
//                    loadingExpectation.fulfill()
//                }
//            }
//            .store(in: &cancellables)
//        await fulfillment(of: [loadingExpectation], timeout: 5.0)
//        XCTAssertTrue(loadingStateReceived)
//
//        // Expect previewing state
//        var previewingStateReceived = false
//        let previewingExpectation = XCTestExpectation(description: "Previewing state received")
//        viewModel.$state
//            .dropFirst(2) // Drop initial .ready and .loading states
//            .sink { state in
//                if case .previewing = state {
//                    previewingStateReceived = true
//                    previewingExpectation.fulfill()
//                }
//            }
//            .store(in: &cancellables)
//        await fulfillment(of: [previewingExpectation], timeout: 10.0) // Increased timeout for AVAsset loading
//        XCTAssertTrue(previewingStateReceived)
//    }
//
//    func testResetFunction() {
//        viewModel.state = .previewing(asset: AVAsset(), photosIdentifier: "test_id")
//        viewModel.moveName = "Test Move"
//        viewModel.selectedItem = PhotosPickerItem(itemIdentifier: "another_id")
//
//        viewModel.reset()
//
//        XCTAssertEqual(viewModel.state, .ready)
//        XCTAssertNil(viewModel.selectedItem)
//        XCTAssertEqual(viewModel.moveName, "")
//    }
//
//    // MARK: - Persistence Tests (Simplified)
//
//    func testSaveMoveToCoreData() async throws {
//        // Set up a naming state for saving
//        let photosIdentifier = "test_photos_id"
//        let trimStartTime = 1.0
//        let trimEndTime = 5.0
//        viewModel.state = .naming(photosIdentifier: photosIdentifier, originalAsset: nil, trimmedAsset: nil, trimStartTime: trimStartTime, trimEndTime: trimEndTime, rotationDegrees: 0)
//        viewModel.moveName = "My Test Move"
//
//        // Mock BreakDexAlbumManager.shared.copyVideoToBreakDex
//        // In a real test, you'd use a mock object for BreakDexAlbumManager
//        // For simplicity, we'll just ensure the saveMove function is called.
//        // This test primarily verifies the Core Data saving part.
//
//        // Simulate successful copy to BreakDex album
//        // We need to mock this part as it interacts with Photos framework
//        // For now, we'll override the copyVideoToBreakDexAlbum function in a testable way
//        // This is a hacky way to mock, a proper dependency injection would be better.
//
//        // Temporarily override the copyVideoToBreakDexAlbum for testing
//        let originalCopyVideoToBreakDexAlbum = viewModel.copyVideoToBreakDexAlbum
//        viewModel.copyVideoToBreakDexAlbum = { _ in
//            return PHAsset() // Return a dummy PHAsset
//        }
//
//        let saveExpectation = XCTestExpectation(description: "Move saved to Core Data")
//        viewModel.$state
//            .sink { state in
//                if case .success = state {
//                    saveExpectation.fulfill()
//                }
//            }
//            .store(in: &cancellables)
//
//        viewModel.saveMove()
//        await fulfillment(of: [saveExpectation], timeout: 10.0)
//
//        // Verify move is saved in Core Data
//        let fetchRequest: NSFetchRequest<Move> = Move.fetchRequest()
//        let moves = try viewModel.viewContext?.fetch(fetchRequest)
//        XCTAssertEqual(moves?.count, 1)
//        XCTAssertEqual(moves?.first?.name, "My Test Move")
//        XCTAssertEqual(moves?.first?.photosIdentifier, photosIdentifier)
//        XCTAssertEqual(moves?.first?.trimStartTime, trimStartTime)
//        XCTAssertEqual(moves?.first?.trimEndTime, trimEndTime)
//
//        // Restore original copyVideoToBreakDexAlbum
//        viewModel.copyVideoToBreakDexAlbum = originalCopyVideoToBreakDexAlbum
//    }
//}
//
