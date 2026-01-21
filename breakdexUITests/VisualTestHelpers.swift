import XCTest

// MARK: - Visual Test Helpers
/// Utilities for capturing screenshots and creating visual test attachments.
/// These helpers enable TDD-driven visual development by capturing reference images
/// that can be reviewed in Xcode test results.

extension XCTestCase {

    // MARK: - Screenshot Capture

    /// Captures a full-screen screenshot and attaches it to the test results.
    /// - Parameters:
    ///   - app: The application instance to screenshot.
    ///   - name: Descriptive name for the screenshot (e.g., "ArsenalEmptyState-Light").
    ///   - lifetime: Attachment lifetime. Defaults to `.keepAlways` for reference images.
    /// - Returns: The captured screenshot for further processing if needed.
    @discardableResult
    func captureScreenshot(
        of app: XCUIApplication,
        name: String,
        lifetime: XCTAttachment.Lifetime = .keepAlways
    ) -> XCUIScreenshot {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
        return screenshot
    }

    /// Captures a screenshot of a specific element and attaches it to the test results.
    /// - Parameters:
    ///   - element: The UI element to capture.
    ///   - name: Descriptive name for the screenshot.
    ///   - lifetime: Attachment lifetime.
    /// - Returns: The captured screenshot.
    @discardableResult
    func captureElementScreenshot(
        of element: XCUIElement,
        name: String,
        lifetime: XCTAttachment.Lifetime = .keepAlways
    ) -> XCUIScreenshot {
        let screenshot = element.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = lifetime
        add(attachment)
        return screenshot
    }

    // MARK: - Visual State Documentation

    /// Captures screenshots in both light and dark mode for comparison.
    /// - Parameters:
    ///   - app: The application instance.
    ///   - baseName: Base name for screenshots (e.g., "ArsenalEmptyState").
    ///   - setupBlock: Optional block to set up the desired state before capture.
    func captureLightAndDarkMode(
        of app: XCUIApplication,
        baseName: String,
        setupBlock: (() -> Void)? = nil
    ) {
        // Capture current state (usually light mode)
        setupBlock?()
        captureScreenshot(of: app, name: "\(baseName)-Light")

        // Note: Programmatic dark mode switching requires app support.
        // For now, tests should be run separately in each appearance mode,
        // or the app should support a debug toggle for appearance.
    }

    /// Creates a named attachment with arbitrary data for test documentation.
    /// - Parameters:
    ///   - data: Data to attach.
    ///   - name: Name for the attachment.
    ///   - uniformTypeIdentifier: UTI for the data type.
    func attachData(_ data: Data, name: String, uniformTypeIdentifier: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: uniformTypeIdentifier)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Element Existence Helpers

    /// Waits for an element and captures a screenshot when found.
    /// - Parameters:
    ///   - element: Element to wait for.
    ///   - timeout: Maximum time to wait.
    ///   - screenshotName: Name for the screenshot if element is found.
    ///   - app: App instance for screenshot.
    /// - Returns: True if element was found.
    @discardableResult
    func waitAndCapture(
        element: XCUIElement,
        timeout: TimeInterval = 5,
        screenshotName: String,
        app: XCUIApplication
    ) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        if exists {
            captureScreenshot(of: app, name: screenshotName)
        }
        return exists
    }

    /// Asserts an element exists and captures a screenshot.
    /// - Parameters:
    ///   - element: Element that should exist.
    ///   - message: Assertion failure message.
    ///   - screenshotName: Name for the screenshot.
    ///   - app: App instance for screenshot.
    func assertExistsAndCapture(
        _ element: XCUIElement,
        message: String,
        screenshotName: String,
        app: XCUIApplication
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), message)
        captureScreenshot(of: app, name: screenshotName)
    }
}

// MARK: - Visual Test Base Class

/// Base class for visual UI tests that provides common setup and helpers.
class VisualTestCase: XCTestCase {

    var app: XCUIApplication!

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

    /// Navigates to the Arsenal tab.
    func navigateToArsenal() {
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        if arsenalTab.waitForExistence(timeout: 5) {
            arsenalTab.tap()
        }
    }

    /// Navigates to the Review tab.
    func navigateToReview() {
        let reviewTab = app.tabBars.buttons["Review"]
        if reviewTab.waitForExistence(timeout: 5) {
            reviewTab.tap()
        }
    }

    /// Navigates to the Add Move tab.
    func navigateToAddMove() {
        let addMoveTab = app.tabBars.buttons["Add Move"]
        if addMoveTab.waitForExistence(timeout: 5) {
            addMoveTab.tap()
        }
    }

    /// Navigates to the Record tab.
    func navigateToRecord() {
        let recordTab = app.tabBars.buttons["Record"]
        if recordTab.waitForExistence(timeout: 5) {
            recordTab.tap()
        }
    }

    // MARK: - State Verification Helpers

    /// Checks if the current view shows an empty state.
    /// - Parameter keywords: Text keywords that indicate an empty state (e.g., "No", "Yet", "Empty").
    /// - Returns: True if empty state indicators are found.
    func isShowingEmptyState(keywords: [String] = ["No", "Yet", "Nothing"]) -> Bool {
        for keyword in keywords {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", keyword)
            let elements = app.staticTexts.matching(predicate)
            if elements.count > 0 {
                return true
            }
        }
        return false
    }
}
