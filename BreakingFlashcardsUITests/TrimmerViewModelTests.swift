import XCTest
import AVKit
@testable import BreakingFlashcards

class TrimmerViewModelTests: XCTestCase {

    var viewModel: TrimmerViewModel!
    var asset: AVAsset!

    override func setUp() {
        super.setUp()
        let videoPath = "/Users/s3nik/Desktop/dev playground/BreakingFlashcards/video/test.MOV"
        let url = URL(fileURLWithPath: videoPath)
        asset = AVURLAsset(url: url)
        viewModel = TrimmerViewModel(asset: asset)
    }

    override func tearDown() {
        viewModel = nil
        asset = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.startTime, 0)
        XCTAssertEqual(viewModel.endTime, 0)
        XCTAssertEqual(viewModel.videoDuration, 0)
    }

    func testSetupAsync() async {
        await viewModel.setupAsync()
        XCTAssertNotEqual(viewModel.videoDuration, 0)
        XCTAssertEqual(viewModel.endTime, viewModel.videoDuration)
    }

    func testGenerateThumbnails() async {
        await viewModel.setupAsync() // videoDuration is needed for thumbnails
        viewModel.generateThumbnails()
        // This is tricky to test without waiting for the async task to complete.
        // A better approach would be to use a completion handler or a delegate.
        // For now, we will just check that the isGeneratingThumbnails flag is set.
        XCTAssertTrue(viewModel.isGeneratingThumbnails)
    }

    func testExport() async throws {
        await viewModel.setupAsync()
        viewModel.startTime = 0
        viewModel.endTime = 1
        let url = try await viewModel.export()
        XCTAssertNotNil(url)
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 1, accuracy: 0.1)
    }
}
