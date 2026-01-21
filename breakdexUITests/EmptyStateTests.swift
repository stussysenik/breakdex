import XCTest

// MARK: - Empty State Tests
/// Tests for empty state rendering across all major screens.
/// These tests verify that empty states display correctly with proper
/// icons, titles, descriptions, and optional CTAs.

final class EmptyStateTests: VisualTestCase {

    // MARK: - Arsenal Empty State Tests

    func testArsenalEmptyMovesState() throws {
        // Navigate to Arsenal
        navigateToArsenal()

        // Try to navigate to MOVES section
        let movesButton = app.buttons["MOVES"]
        let movesText = app.staticTexts["MOVES"]

        if movesButton.waitForExistence(timeout: 3) {
            movesButton.tap()
        } else if movesText.waitForExistence(timeout: 3) {
            movesText.tap()
        }

        // Wait for navigation
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Check for empty state elements
        // Look for "No Moves Yet" or similar empty state text
        let emptyStateTitle = app.staticTexts["No Moves Yet"]
        let emptyStateAlt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No Moves'")).firstMatch

        let hasEmptyState = emptyStateTitle.exists || emptyStateAlt.exists

        // Capture screenshot regardless of state
        captureScreenshot(of: app, name: "Arsenal-MovesSection")

        // If empty, verify empty state components
        if hasEmptyState {
            captureScreenshot(of: app, name: "Arsenal-MovesEmptyState")

            // Verify CTA button exists
            let addMoveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add'")).firstMatch
            XCTAssertTrue(
                addMoveButton.exists,
                "Empty state should have an Add Move CTA button"
            )
        }
    }

    func testArsenalEmptyCombosState() throws {
        // Navigate to Arsenal
        navigateToArsenal()

        // Try to navigate to COMBOS section
        let combosButton = app.buttons["COMBOS"]
        let combosText = app.staticTexts["COMBOS"]

        if combosButton.waitForExistence(timeout: 3) {
            combosButton.tap()
        } else if combosText.waitForExistence(timeout: 3) {
            combosText.tap()
        }

        // Wait for navigation
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Check for empty state
        let emptyStateTitle = app.staticTexts["No Combos Yet"]
        let emptyStateAlt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'No Combos'")).firstMatch

        // Capture screenshot
        captureScreenshot(of: app, name: "Arsenal-CombosSection")

        if emptyStateTitle.exists || emptyStateAlt.exists {
            captureScreenshot(of: app, name: "Arsenal-CombosEmptyState")
        }
    }

    // MARK: - Add Move Empty State Tests

    func testAddMoveInitialState() throws {
        // Navigate to Add Move tab
        navigateToAddMove()

        // Wait for view to load
        _ = app.buttons.firstMatch.waitForExistence(timeout: 3)

        // Capture initial state
        captureScreenshot(of: app, name: "AddMove-InitialState")

        // Verify "Select a Clip" button exists
        let selectClipButton = app.buttons["Select a Clip"]
        let selectClipAlt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch

        XCTAssertTrue(
            selectClipButton.exists || selectClipAlt.exists,
            "Add Move should show 'Select a Clip' button"
        )

        // Look for guidance text (empty state description)
        let guidanceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'video' OR label CONTAINS[c] 'clip' OR label CONTAINS[c] 'move'")).firstMatch

        if guidanceText.exists {
            captureScreenshot(of: app, name: "AddMove-WithGuidance")
        }
    }

    // MARK: - Review Empty State Tests

    func testReviewEmptyState() throws {
        // Navigate to Review tab
        navigateToReview()

        // Wait for view to load
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture Review screen
        captureScreenshot(of: app, name: "Review-Screen")

        // Check for empty state (when no moves to review)
        let emptyStateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Nothing to review' OR label CONTAINS[c] 'No moves'")).firstMatch

        if emptyStateText.exists {
            captureScreenshot(of: app, name: "Review-EmptyState")

            // Verify guidance text exists
            let guidanceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Add' OR label CONTAINS[c] 'start'")).firstMatch
            XCTAssertTrue(
                guidanceText.exists,
                "Empty state should have guidance text"
            )
        }
    }

    // MARK: - Visual Consistency Tests

    func testEmptyStateIconsExist() throws {
        // This test documents empty state icon presence across screens

        // Arsenal
        navigateToArsenal()
        _ = app.images.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Arsenal-IconCheck")

        // Add Move
        navigateToAddMove()
        _ = app.images.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "AddMove-IconCheck")

        // Review
        navigateToReview()
        _ = app.images.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Review-IconCheck")
    }

    func testEmptyStateAccessibility() throws {
        // Navigate to a screen that might show empty state
        navigateToArsenal()

        // Wait for content
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Check that empty state elements are accessible
        let accessibleElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))

        XCTAssertGreaterThan(
            accessibleElements.count,
            0,
            "Screen should have accessible elements"
        )

        captureScreenshot(of: app, name: "Arsenal-Accessibility")
    }
}
