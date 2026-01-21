import XCTest

// MARK: - Design System Component Tests
/// Tests for isolated design system component verification.
/// These tests verify that design system components render correctly
/// and have proper accessibility attributes.

final class DesignSystemComponentTests: VisualTestCase {

    // MARK: - Empty State View Tests

    func testEmptyStateViewRendering() throws {
        // Navigate to a screen that shows empty state
        navigateToArsenal()

        // Try to access MOVES which might show empty state
        let movesButton = app.buttons["MOVES"]
        let movesText = app.staticTexts["MOVES"]

        if movesButton.waitForExistence(timeout: 3) {
            movesButton.tap()
        } else if movesText.waitForExistence(timeout: 3) {
            movesText.tap()
        }

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Check for empty state structure
        // EmptyStateView should have: icon (image), title (text), description (text), optional button

        // Capture for visual verification
        captureScreenshot(of: app, name: "Component-EmptyStateView")

        // Verify accessibility - empty state should be readable
        let accessibleTexts = app.staticTexts.allElementsBoundByIndex
        XCTAssertGreaterThan(accessibleTexts.count, 0, "Empty state should have readable text")
    }

    // MARK: - Section Header Tests

    func testSectionHeaderViewRendering() throws {
        // Navigate to Review which has section headers
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Look for section headers (MOVES, COMBOS text with potential counts)
        let movesHeader = app.staticTexts["MOVES"]

        if movesHeader.exists {
            captureScreenshot(of: app, name: "Component-SectionHeader-MOVES")
        }

        // Capture overall layout
        captureScreenshot(of: app, name: "Component-SectionHeaders")
    }

    func testSectionHeaderAccessibility() throws {
        // Navigate to Review
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Section headers should be accessible
        let movesHeader = app.staticTexts["MOVES"]

        if movesHeader.exists {
            XCTAssertTrue(movesHeader.isEnabled, "Section header should be accessible")
        }
    }

    // MARK: - Card Container Tests

    func testCardContainerRendering() throws {
        // Navigate to Review where cards are used
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Cards are typically represented as cells or other elements
        // Capture the screen to verify card styling visually
        captureScreenshot(of: app, name: "Component-CardContainers")

        // Look for learning state rows which should be in cards
        let newStateRow = app.staticTexts["NEW"]
        let learningRow = app.staticTexts["LEARNING"]
        let masteryRow = app.staticTexts["MASTERY"]

        // At least verify the text elements exist within potential cards
        let hasContent = newStateRow.exists || learningRow.exists || masteryRow.exists
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Nothing'")).firstMatch.exists

        XCTAssertTrue(hasContent || hasEmptyState, "Review should show cards or empty state")
    }

    // MARK: - Progress Ring Tests

    func testProgressRingRendering() throws {
        // Navigate to Review where progress rings might appear
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture for visual verification of progress indicators
        captureScreenshot(of: app, name: "Component-ProgressRing")

        // Progress rings would typically be in the header or alongside state rows
        // Visual verification in screenshot
    }

    func testProgressRingAccessibility() throws {
        // Navigate to Review
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Progress should be announced - look for percentage or progress text
        let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '%'")).firstMatch

        if progressText.exists {
            XCTAssertTrue(progressText.isEnabled, "Progress should be accessible")
            captureScreenshot(of: app, name: "Component-ProgressRing-Accessible")
        }
    }

    // MARK: - Button Style Tests

    func testPrimaryButtonRendering() throws {
        // Navigate to Add Move which has a primary button
        navigateToAddMove()

        _ = app.buttons.firstMatch.waitForExistence(timeout: 3)

        // Capture the primary button styling
        captureScreenshot(of: app, name: "Component-PrimaryButton")

        // Verify button exists and is tappable
        let selectButton = app.buttons["Select a Clip"]
        let selectButtonAlt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch

        let buttonExists = selectButton.exists || selectButtonAlt.exists
        XCTAssertTrue(buttonExists, "Primary button should exist")

        if selectButton.exists {
            XCTAssertTrue(selectButton.isEnabled, "Primary button should be enabled")
        }
    }

    // MARK: - Typography Tests

    func testTypographyConsistency() throws {
        // Capture multiple screens to verify typography consistency

        // Arsenal
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Typography-Arsenal")

        // Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Typography-Review")

        // Typography is verified visually in screenshots
        // Ensure IBM Plex Mono is used consistently
    }

    // MARK: - Spacing Consistency Tests

    func testSpacingConsistency() throws {
        // Capture screens for spacing verification

        // Arsenal
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Spacing-Arsenal")

        // Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Spacing-Review")

        // Spacing is verified visually against 8-point grid
    }

    // MARK: - Color System Tests

    func testColorSystemApplication() throws {
        // Navigate through screens to capture color usage

        // Arsenal - should use accent color for interactive elements
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Colors-Arsenal")

        // Review - should use state colors (NEW=magenta, LEARNING=purple, MASTERY=green)
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Colors-Review")

        // Add Move - should use primary button color
        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Colors-AddMove")
    }
}
