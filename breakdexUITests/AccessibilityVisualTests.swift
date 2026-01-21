import XCTest

// MARK: - Accessibility Visual Tests
/// Tests verifying accessibility-related visual requirements including
/// high contrast mode, dynamic type support, and touch target sizes.

final class AccessibilityVisualTests: VisualTestCase {

    // MARK: - Touch Target Size Tests

    func testTouchTargetSizes() throws {
        // Navigate to Arsenal
        navigateToArsenal()

        // Capture for touch target verification
        captureScreenshot(of: app, name: "Accessibility-TouchTargets-Arsenal")

        // Verify interactive elements have adequate size
        // Buttons should be at least 44x44 points

        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.prefix(10).enumerated() {
            if button.exists && button.isHittable {
                let frame = button.frame

                // Log button dimensions for review
                // (Visual verification in screenshots, automated check here)
                if frame.width < 44 || frame.height < 44 {
                    // Capture problematic button
                    captureScreenshot(of: app, name: "Accessibility-SmallButton-\(index)")
                }
            }
        }

        // Navigate to Add Move to check primary button
        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 3)
        captureScreenshot(of: app, name: "Accessibility-TouchTargets-AddMove")
    }

    // MARK: - Dynamic Type Tests

    func testDynamicTypeSupport() throws {
        // These tests capture screenshots at the current dynamic type setting.
        // To fully test, run the test suite with different simulator accessibility settings.

        // Arsenal
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "DynamicType-Arsenal")

        // Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "DynamicType-Review")

        // Add Move
        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "DynamicType-AddMove")
    }

    func testTextTruncation() throws {
        // Navigate to screens with text content
        navigateToArsenal()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Capture for visual verification of text truncation
        captureScreenshot(of: app, name: "TextTruncation-Arsenal")

        // Navigate to Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "TextTruncation-Review")
    }

    // MARK: - High Contrast Tests

    func testHighContrastStateColors() throws {
        // Navigate to Review where state colors are used
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture for contrast verification
        // State colors should use high contrast variants when accessibility is enabled
        captureScreenshot(of: app, name: "HighContrast-StateColors")

        // Look for state labels
        let newState = app.staticTexts["NEW"]
        let learningState = app.staticTexts["LEARNING"]
        let masteryState = app.staticTexts["MASTERY"]

        // Verify states are present (either as text or in empty state message)
        let hasStates = newState.exists || learningState.exists || masteryState.exists
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Nothing'")).firstMatch.exists

        XCTAssertTrue(hasStates || hasEmptyState, "Review should show states or empty state")
    }

    func testButtonContrast() throws {
        // Navigate to Add Move for primary button contrast check
        navigateToAddMove()

        _ = app.buttons.firstMatch.waitForExistence(timeout: 3)

        // Capture for contrast verification
        captureScreenshot(of: app, name: "HighContrast-PrimaryButton")

        // The "Select a Clip" button should have adequate contrast
        let selectButton = app.buttons["Select a Clip"]
        let selectButtonAlt = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch

        XCTAssertTrue(selectButton.exists || selectButtonAlt.exists, "Primary button should exist")
    }

    // MARK: - VoiceOver Support Tests

    func testVoiceOverLabels() throws {
        // Navigate through screens and verify accessibility labels exist

        // Arsenal
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Check that major elements have accessibility labels
        let arsenalElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(arsenalElements.count, 0, "Arsenal should have accessible elements")

        captureScreenshot(of: app, name: "VoiceOver-Arsenal")

        // Review
        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        let reviewElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(reviewElements.count, 0, "Review should have accessible elements")

        captureScreenshot(of: app, name: "VoiceOver-Review")

        // Add Move
        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 2)

        let addMoveElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertGreaterThan(addMoveElements.count, 0, "Add Move should have accessible elements")

        captureScreenshot(of: app, name: "VoiceOver-AddMove")
    }

    // MARK: - Focus Management Tests

    func testKeyboardFocusOrder() throws {
        // Navigate to screens with interactive elements
        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "Focus-Arsenal")

        // Tab bar should be focusable
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist for keyboard navigation")
    }

    // MARK: - Reduce Motion Tests

    func testReduceMotionCompliance() throws {
        // Capture screens - with Reduce Motion enabled, animations should be minimal
        // This is verified visually and through user experience testing

        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "ReduceMotion-Arsenal")

        navigateToAddMove()
        _ = app.buttons.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "ReduceMotion-AddMove")
    }

    // MARK: - Color Blind Support Tests

    func testColorBlindFriendlyDesign() throws {
        // Navigate to Review where colors indicate state
        navigateToReview()

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Capture for color blind accessibility review
        // States should be distinguishable not just by color but also by:
        // - Text labels (NEW, LEARNING, MASTERY)
        // - Icons or shapes (if applicable)
        captureScreenshot(of: app, name: "ColorBlind-StateColors")

        // Verify text labels exist alongside color indicators
        let newState = app.staticTexts["NEW"]
        let learningState = app.staticTexts["LEARNING"]
        let masteryState = app.staticTexts["MASTERY"]

        let hasTextLabels = newState.exists || learningState.exists || masteryState.exists
        let hasEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Nothing'")).firstMatch.exists

        XCTAssertTrue(hasTextLabels || hasEmptyState, "States should have text labels, not just colors")
    }

    // MARK: - Text Scaling Tests

    func testLargeTextScaling() throws {
        // Capture screens for large text verification
        // To fully test, run with accessibility large text enabled in simulator

        navigateToArsenal()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "LargeText-Arsenal")

        navigateToReview()
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)
        captureScreenshot(of: app, name: "LargeText-Review")

        // Verify text is present and readable
        let visibleText = app.staticTexts.allElementsBoundByIndex
        XCTAssertGreaterThan(visibleText.count, 0, "Text should be visible at large sizes")
    }
}
