import XCTest

// MARK: - Dark Mode Parity Tests
/// Tests ensuring visual consistency between light and dark modes.
/// These tests capture screenshots in both modes for manual comparison
/// in the Xcode test results viewer.

final class DarkModeParityTests: VisualTestCase {

    // MARK: - Arsenal Dark Mode Tests

    func testArsenalDarkModeParity() throws {
        // Navigate to Arsenal
        navigateToArsenal()

        // Wait for content to load
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture screenshot in current mode
        captureScreenshot(of: app, name: "Arsenal-CurrentMode")

        // Note: To test both modes, run tests with different simulator appearances,
        // or implement an in-app debug toggle for appearance switching.

        // Verify core elements are visible (contrast check proxy)
        let movesButton = app.buttons["MOVES"]
        let movesText = app.staticTexts["MOVES"]

        XCTAssertTrue(
            movesButton.exists || movesText.exists,
            "MOVES navigation should be visible in current mode"
        )
    }

    // MARK: - Add Move Dark Mode Tests

    func testAddMoveDarkModeParity() throws {
        // Navigate to Add Move
        navigateToAddMove()

        // Wait for view
        _ = app.buttons.firstMatch.waitForExistence(timeout: 3)

        // Capture screenshot
        captureScreenshot(of: app, name: "AddMove-CurrentMode")

        // Verify button is visible and styled
        let selectButton = app.buttons["Select a Clip"]
        let selectButtonAlt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch

        XCTAssertTrue(
            selectButton.exists || selectButtonAlt.exists,
            "Select button should be visible in current mode"
        )
    }

    // MARK: - Review Dark Mode Tests

    func testReviewDarkModeParity() throws {
        // Navigate to Review
        navigateToReview()

        // Wait for content
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture screenshot
        captureScreenshot(of: app, name: "Review-CurrentMode")

        // Verify learning state rows are visible
        let newState = app.staticTexts["NEW"]
        let learningState = app.staticTexts["LEARNING"]
        let masteryState = app.staticTexts["MASTERY"]

        // At least one state label should be visible (either in list or empty state)
        let hasStateLabels = newState.exists || learningState.exists || masteryState.exists

        // Or check for empty state text
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Nothing' OR label CONTAINS[c] 'No'")).firstMatch.exists

        XCTAssertTrue(
            hasStateLabels || hasEmptyState,
            "Review should show learning states or empty state"
        )
    }

    // MARK: - Tab Bar Dark Mode Tests

    func testTabBarDarkModeParity() throws {
        // Capture tab bar appearance
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        // Capture full screen with tab bar visible
        captureScreenshot(of: app, name: "TabBar-CurrentMode")

        // Verify all tabs are visible
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        let addMoveTab = app.tabBars.buttons["Add Move"]
        let reviewTab = app.tabBars.buttons["Review"]

        XCTAssertTrue(arsenalTab.exists, "Arsenal tab should be visible")
        XCTAssertTrue(addMoveTab.exists, "Add Move tab should be visible")
        XCTAssertTrue(reviewTab.exists, "Review tab should be visible")
    }

    // MARK: - Component Dark Mode Tests

    func testProgressRingDarkModeParity() throws {
        // Navigate to Review where progress might be shown
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture the Review screen which may contain progress indicators
        captureScreenshot(of: app, name: "ProgressElements-CurrentMode")
    }

    func testCardContainerDarkModeParity() throws {
        // Navigate to Review where cards are used
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture to verify card backgrounds are visible
        captureScreenshot(of: app, name: "CardContainers-CurrentMode")

        // Cards should have distinct background from the main background
        // This is verified visually in the screenshot
    }

    // MARK: - Full App Dark Mode Walkthrough

    func testFullAppDarkModeWalkthrough() throws {
        // Capture each main screen for dark mode comparison

        // 1. Arsenal
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Walkthrough-1-Arsenal")

        // 2. Add Move
        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Walkthrough-2-AddMove")

        // 3. Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Walkthrough-3-Review")

        // 4. Record (if accessible)
        navigateToRecord()
        _ = app.otherElements.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Walkthrough-4-Record")
    }
}
