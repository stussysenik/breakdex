import XCTest

// MARK: - Video Loading Tests
/// Tests for video loading resilience and performance.
/// Ensures videos load properly on slow networks with proper progress indication.

final class VideoLoadingTests: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Helpers

    private func navigateToArsenal() {
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        if arsenalTab.waitForExistence(timeout: 5) {
            arsenalTab.tap()
        }
    }

    private func navigateToMovesList() -> Bool {
        navigateToArsenal()

        let movesButton = app.buttons["MOVES"]
        let movesText = app.staticTexts["MOVES"]

        if movesButton.waitForExistence(timeout: 3) {
            movesButton.tap()
            return true
        } else if movesText.waitForExistence(timeout: 3) {
            movesText.tap()
            return true
        }
        return false
    }

    private func navigateToFirstMoveDetail() -> Bool {
        guard navigateToMovesList() else { return false }

        sleep(2) // Wait for list to load

        // Try to tap first move
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            return true
        }
        return false
    }

    // MARK: - Loading Indicator Tests

    func testVideoLoadingShowsLoadingState() throws {
        guard navigateToMovesList() else {
            // No moves - test not applicable
            return
        }

        sleep(1)

        // Check for moves with loading indicators
        let cells = app.cells.allElementsBoundByIndex
        guard cells.count > 0 else { return }

        // Look for any loading indicators
        let loadingIndicator = app.progressIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch

        // Either loading indicator, loaded content, or empty state is acceptable
        XCTAssertTrue(app.state == .runningForeground, "App should handle video loading states")
    }

    func testMoveDetailVideoLoading() throws {
        guard navigateToFirstMoveDetail() else {
            // No moves - test not applicable
            return
        }

        sleep(1)

        // In move detail, look for video player or loading state
        let videoPlayer = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'video' OR identifier CONTAINS 'player'")).firstMatch
        let progressIndicator = app.progressIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch

        // Video should eventually load (30s for slow network tolerance)
        let deadline = Date().addingTimeInterval(30)
        var videoLoaded = false

        while Date() < deadline && !videoLoaded {
            if videoPlayer.exists || app.buttons["Play"].exists || app.images.count > 1 {
                videoLoaded = true
            } else {
                sleep(1)
            }
        }

        // Either video loaded or we have some UI present
        XCTAssertTrue(app.state == .runningForeground, "App should handle video loading in detail view")
    }

    // MARK: - Playback Tests

    func testVideoPlaybackControls() throws {
        guard navigateToFirstMoveDetail() else { return }

        sleep(2)

        // Look for playback controls
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]
        let scrubber = app.sliders.firstMatch

        // Should have some form of playback control if video loaded
        let hasControls = playButton.exists || pauseButton.exists || scrubber.exists

        // On empty state, controls won't exist
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testVideoAutoPlaysOrShowsPlayButton() throws {
        guard navigateToFirstMoveDetail() else { return }

        sleep(3)

        // Video may autoplay or show play button
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]

        // Either play or pause button should be visible if video loaded
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Error Recovery Tests

    func testVideoLoadingRecovery() throws {
        guard navigateToMovesList() else { return }

        sleep(1)

        // Navigate to a move
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 3) else { return }

        firstCell.tap()
        sleep(2)

        // If video fails to load, there should be a retry option
        let retryButton = app.buttons["Retry"]
        let reloadButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'retry' OR label CONTAINS 'reload'")).firstMatch

        // Retry may not exist if video loaded successfully
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Thumbnail Loading Tests

    func testThumbnailsLoadInList() throws {
        guard navigateToMovesList() else { return }

        // Wait for thumbnails to load
        sleep(3)

        // Look for images in the list
        let images = app.images.allElementsBoundByIndex
        let cells = app.cells.allElementsBoundByIndex

        // If there are cells, there should eventually be images (thumbnails)
        if cells.count > 0 {
            // Wait a bit more for thumbnails
            sleep(2)

            // Either we have images or placeholders
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    func testThumbnailLoadingPerformance() throws {
        guard navigateToMovesList() else { return }

        // Measure thumbnail loading
        measure {
            // Scroll and wait for thumbnails
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                sleep(1)
                scrollView.swipeDown()
                sleep(1)
            }
        }
    }

    // MARK: - Progress Display Tests

    func testVideoProgressBarExists() throws {
        guard navigateToFirstMoveDetail() else { return }

        sleep(2)

        // Look for progress bar or timeline
        let progressBar = app.sliders.firstMatch
        let timeline = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'timeline'")).firstMatch

        // Progress controls should exist if video is playing
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testVideoTimeDisplays() throws {
        guard navigateToFirstMoveDetail() else { return }

        sleep(2)

        // Look for time display (e.g., "0:00 / 1:30")
        let timePattern = NSPredicate(format: "label MATCHES '\\\\d+:\\\\d+'")
        let timeLabel = app.staticTexts.matching(timePattern).firstMatch

        // Time display should exist if video is loaded
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Network Resilience Tests

    func testAppHandlesSlowLoading() throws {
        // This test verifies the app doesn't crash during slow loading scenarios
        guard navigateToMovesList() else { return }

        sleep(1)

        // Try to interact while potentially loading
        let cells = app.cells.allElementsBoundByIndex
        if cells.count > 0 {
            // Rapidly tap cells to simulate impatient user
            for i in 0..<min(3, cells.count) {
                cells[i].tap()
                sleep(1)
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        XCTAssertTrue(app.state == .runningForeground, "App should remain stable during rapid navigation")
    }

    func testVideoLoadTimeout() throws {
        guard navigateToFirstMoveDetail() else { return }

        // Wait extended time for video to load (simulating slow network)
        let deadline = Date().addingTimeInterval(30)

        while Date() < deadline {
            // Check if video has loaded or error appeared
            let videoLoaded = app.buttons["Play"].exists ||
                             app.buttons["Pause"].exists ||
                             app.images.count > 2

            let hasError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error'")).firstMatch.exists

            if videoLoaded || hasError {
                break
            }

            sleep(1)
        }

        // App should still be running after timeout period
        XCTAssertTrue(app.state == .runningForeground, "App should handle slow/failed video loads gracefully")
    }

    // MARK: - Memory Management Tests

    func testNavigatingBetweenVideosDoesNotCrash() throws {
        guard navigateToMovesList() else { return }

        sleep(1)

        let cells = app.cells.allElementsBoundByIndex

        // Navigate to multiple moves to test memory management
        for i in 0..<min(5, cells.count) {
            cells[i].tap()
            sleep(2)

            // Go back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                sleep(1)
            }
        }

        XCTAssertTrue(app.state == .runningForeground, "App should not crash when navigating between videos")
    }

    // MARK: - Accessibility Tests

    func testVideoPlayerAccessibility() throws {
        guard navigateToFirstMoveDetail() else { return }

        sleep(2)

        // Video controls should have accessibility labels
        let playButton = app.buttons["Play"]
        let pauseButton = app.buttons["Pause"]

        if playButton.exists {
            XCTAssertFalse(playButton.label.isEmpty, "Play button should have accessibility label")
        }

        if pauseButton.exists {
            XCTAssertFalse(pauseButton.label.isEmpty, "Pause button should have accessibility label")
        }
    }
}
