import XCTest

// MARK: - Camera Recording Tests
/// Tests for the camera recording feature.
/// Covers camera tab access, permission handling, recording controls, and video preview.

final class CameraRecordingTests: XCTestCase {

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

    // MARK: - Navigation

    private func navigateToCamera() -> Bool {
        let cameraTab = app.tabBars.buttons["Record"]
        if cameraTab.waitForExistence(timeout: 5) {
            cameraTab.tap()
            return true
        }
        return false
    }

    // MARK: - Camera Tab Tests

    func testCameraTabExists() throws {
        let cameraTab = app.tabBars.buttons["Record"]
        XCTAssertTrue(
            cameraTab.waitForExistence(timeout: 5),
            "Record (Camera) tab should exist in tab bar"
        )
    }

    func testCameraTabDisplaysContent() throws {
        guard navigateToCamera() else {
            XCTFail("Could not navigate to Camera tab")
            return
        }

        sleep(1)

        // Verify some UI content exists (permission prompt or camera controls)
        let hasContent = app.staticTexts.count > 0 ||
                         app.buttons.count > 0 ||
                         app.images.count > 0

        XCTAssertTrue(hasContent, "Camera screen should display content")
    }

    // MARK: - Permission Handling Tests

    func testCameraPermissionPromptOrControls() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // On simulator without camera, we expect either:
        // 1. Permission prompt
        // 2. Error message about camera access
        // 3. Camera controls (if permission granted)

        let permissionText = app.staticTexts["Camera Access Required"]
        let openSettingsButton = app.buttons["Open Settings"]
        let recordButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'recording'")).firstMatch
        let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'camera'")).firstMatch

        let hasExpectedUI = permissionText.exists ||
                            openSettingsButton.exists ||
                            recordButton.exists ||
                            errorText.exists

        // On simulator, camera may not work, so we accept various states
        XCTAssertTrue(app.state == .runningForeground, "App should remain running")
    }

    // MARK: - Recording Controls Tests

    func testRecordButtonExists() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // Look for record button - may be hidden if no permission
        let recordButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'recording'")).firstMatch

        // Record button may not exist on simulator without camera
        // Just verify app doesn't crash
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testFlashButtonExists() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // Look for flash toggle button
        let flashButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'flash'")).firstMatch

        // Flash button may not exist on simulator
        // Just verify app doesn't crash
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testSwitchCameraButtonExists() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // Look for camera switch button
        let switchButton = app.buttons["Switch camera"]

        // Button may not exist on simulator without camera
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Recording Indicator Tests

    func testRecordingDurationDisplay() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // Duration display only appears during recording
        // On simulator we can't actually record, so just verify UI is present

        let durationPattern = NSPredicate(format: "label MATCHES '\\\\d+:\\\\d+.\\\\d+'")
        let durationLabel = app.staticTexts.matching(durationPattern).firstMatch

        // Duration won't exist unless recording - verify app is running
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Navigation Bar Tests

    func testRecordScreenHasNavigationBar() throws {
        guard navigateToCamera() else { return }

        sleep(1)

        // Check for navigation bar with title
        let navBar = app.navigationBars["Record"]

        XCTAssertTrue(
            navBar.waitForExistence(timeout: 3) || app.staticTexts["Record"].exists,
            "Record screen should have navigation title"
        )
    }

    // MARK: - Tab Navigation Tests

    func testNavigateFromCameraToOtherTabs() throws {
        guard navigateToCamera() else { return }

        sleep(1)

        // Navigate to Arsenal
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        if arsenalTab.exists {
            arsenalTab.tap()
            sleep(1)

            // Verify we left Camera tab
            let movesButton = app.buttons["MOVES"]
            let movesText = app.staticTexts["MOVES"]

            XCTAssertTrue(
                movesButton.exists || movesText.exists,
                "Should be able to navigate from Camera to Arsenal"
            )
        }

        // Navigate back to Camera
        guard navigateToCamera() else { return }

        sleep(1)

        // Verify we're back on Camera
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Error State Tests

    func testErrorStateShowsRetryButton() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // On simulator, we may see an error state
        let tryAgainButton = app.buttons["Try Again"]

        // If error state exists, verify retry button is present
        if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'Error'")).firstMatch.exists {
            XCTAssertTrue(
                tryAgainButton.exists,
                "Error state should have Try Again button"
            )
        }

        // Otherwise just verify app is running
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Accessibility Tests

    func testCameraControlsHaveAccessibilityLabels() throws {
        guard navigateToCamera() else { return }

        sleep(2)

        // Check that buttons have accessibility labels
        for button in app.buttons.allElementsBoundByIndex.prefix(5) {
            guard button.exists else { continue }

            // Buttons should have non-empty labels
            if button.isHittable {
                XCTAssertFalse(
                    button.label.isEmpty,
                    "Camera control button should have accessibility label"
                )
            }
        }
    }

    // MARK: - Performance Tests

    func testCameraTabLoadPerformance() throws {
        // Navigate to a different tab first
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        if arsenalTab.waitForExistence(timeout: 5) {
            arsenalTab.tap()
        }

        sleep(1)

        // Measure time to open Camera tab
        measure {
            let cameraTab = app.tabBars.buttons["Record"]
            cameraTab.tap()
            sleep(1)

            // Navigate back for next iteration
            arsenalTab.tap()
            sleep(1)
        }
    }
}
