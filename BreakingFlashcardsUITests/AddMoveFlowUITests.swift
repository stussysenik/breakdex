import XCTest

class AddMoveFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-testing"] // Add launch argument for testing if needed
        app.launch()

        // Grant Photos access if prompted (this might require manual intervention or a pre-configured simulator)
        addUIInterruptionMonitor(withDescription: "Photos Access") { (alert) -> Bool in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }
        app.tap() // Tap to dismiss any initial alerts
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testFullAddMoveFlow() throws {
        // Navigate to the Add tab (assuming it's the first tab or has an accessibility identifier)
        // If your app has a TabView, you might need to tap on the "Add" tab item.
        // Example: app.tabBars.buttons["Add"].tap()

        // 1. Tap "Select a Clip" button
        let selectClipButton = app.buttons["Select a Clip"]
        XCTAssertTrue(selectClipButton.waitForExistence(timeout: 5), "Select a Clip button did not appear.")
        selectClipButton.tap()

        // 2. Select a video from Photos (this part is tricky for UI tests)
        // In a real scenario, you'd use XCUI test APIs to select from the Photos picker.
        // For simplicity, we'll assume a video is selected.
        // You might need to manually add a test video to the simulator's Photos library.
        // Example: app.collectionViews.cells.images.element(boundBy: 0).tap()
        // For now, we'll just wait for the preview screen to appear.

        // Wait for loading state to pass and preview screen to appear
        let videoPlayer = app.otherElements["CustomVideoPlayerView"] // Assuming CustomVideoPlayerView has an accessibility identifier
        XCTAssertTrue(videoPlayer.waitForExistence(timeout: 20), "Video preview did not appear.")

        // 3. Tap "Trim Video"
        let trimVideoButton = app.buttons["Trim Video"]
        XCTAssertTrue(trimVideoButton.waitForExistence(timeout: 5), "Trim Video button did not appear.")
        trimVideoButton.tap()

        // 4. Wait for trimming UI to appear (PreciseVideoTrimmerView)
        let preciseTrimmer = app.otherElements["PreciseVideoTrimmerView"] // Assuming PreciseVideoTrimmerView has an accessibility identifier
        XCTAssertTrue(preciseTrimmer.waitForExistence(timeout: 5), "Precise Video Trimmer did not appear.")

        // 5. Tap "Save Trim"
        let saveTrimButton = app.buttons["Save Trim"]
        XCTAssertTrue(saveTrimButton.waitForExistence(timeout: 5), "Save Trim button did not appear.")
        saveTrimButton.tap()

        // 6. Enter move name
        let enterNameTextField = app.textFields["Enter move name"] // Assuming TextField has an accessibility identifier
        XCTAssertTrue(enterNameTextField.waitForExistence(timeout: 5), "Name text field did not appear.")
        enterNameTextField.tap()
        enterNameTextField.typeText("My Test Move")

        // 7. Tap "Save"
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save button did not appear.")
        saveButton.tap()

        // 8. Wait for success screen
        let successMessage = app.staticTexts["'My Test Move' has been saved to BreakDex!"] // Assuming this is the success message
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10), "Success message did not appear.")

        // 9. Tap "Add Another"
        let addAnotherButton = app.buttons["Add Another"]
        XCTAssertTrue(addAnotherButton.waitForExistence(timeout: 5), "Add Another button did not appear.")
        addAnotherButton.tap()

        // 10. Verify return to initial "Select a Clip" screen
        XCTAssertTrue(selectClipButton.waitForExistence(timeout: 5), "Did not return to Select a Clip screen.")
    }
}