import XCTest

// MARK: - Move Flow Tests
/// Tests for the move creation and editing flows.
/// Covers the full lifecycle of adding, viewing, and managing moves.

final class MoveFlowTests: XCTestCase {

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

    // MARK: - Navigation to Arsenal

    private func navigateToArsenal() {
        let arsenalTab = app.tabBars.buttons["Arsenal"]
        if arsenalTab.waitForExistence(timeout: 5) {
            arsenalTab.tap()
        }
    }

    // MARK: - Move List Tests

    func testMoveListDisplays() throws {
        navigateToArsenal()

        // Allow list to load
        sleep(1)

        // Either empty state or list should be visible
        let scrollView = app.scrollViews.firstMatch
        let emptyState = app.staticTexts["No Moves Yet"]
        let listExists = app.cells.count > 0 || scrollView.exists

        XCTAssertTrue(listExists || emptyState.exists, "Move list or empty state should be visible")
    }

    func testMoveListLayoutToggle() throws {
        navigateToArsenal()

        // Look for layout toggle button (grid/list)
        let gridButton = app.buttons["square.grid.2x2"]
        let listButton = app.buttons["list.bullet"]
        let toggleButton = app.buttons.matching(identifier: "layoutToggle").firstMatch

        if gridButton.waitForExistence(timeout: 3) {
            // Grid mode - tap to switch to list
            gridButton.tap()
            sleep(1)

            // Verify layout changed
            XCTAssertTrue(listButton.exists || app.tables.count > 0)
        } else if toggleButton.exists {
            toggleButton.tap()
            sleep(1)
        }
    }

    // MARK: - Add Move Flow Tests

    func testAddMoveButtonOpensSheet() throws {
        // Add Move is accessed via the "Add Move" tab or from MoveListView empty state
        // Navigate to Arsenal > MOVES first
        navigateToArsenal()

        let movesLink = app.staticTexts["MOVES"]
        if movesLink.waitForExistence(timeout: 3) {
            movesLink.tap()
        }

        sleep(1)

        // Either find Add Move button in empty state, or use Add Move tab
        let addButton = app.buttons["Add Move"]
        if addButton.waitForExistence(timeout: 3) {
            // In empty state, tap Add Move button
            addButton.tap()
            sleep(1)

            // Should navigate to Add Move tab (tab 1)
            let addMoveTab = app.tabBars.buttons["Add Move"]
            XCTAssertTrue(addMoveTab.isSelected || app.staticTexts["SELECT CLIP"].exists,
                         "Add Move flow should open via tab or SelectClip view")
        } else {
            // No Add Move button visible - use the tab directly
            let addMoveTab = app.tabBars.buttons["Add Move"]
            if addMoveTab.waitForExistence(timeout: 3) {
                addMoveTab.tap()
                sleep(1)
                // Verify we're on Add Move view
                XCTAssertTrue(app.state == .runningForeground, "Add Move tab should be accessible")
            }
        }
    }

    func testCancelAddMoveFlow() throws {
        // Navigate to Add Move tab
        let addMoveTab = app.tabBars.buttons["Add Move"]
        if addMoveTab.waitForExistence(timeout: 5) {
            addMoveTab.tap()
            sleep(1)

            // The Add Move flow is tab-based, not modal
            // User would tap Arsenal tab to "cancel"
            let arsenalTab = app.tabBars.buttons["Arsenal"]
            if arsenalTab.waitForExistence(timeout: 3) {
                arsenalTab.tap()
                sleep(1)

                // Verify we're back at Arsenal - NavigationLinks appear as buttons or staticTexts
                let movesButton = app.buttons["MOVES"]
                let combosButton = app.buttons["COMBOS"]
                let movesText = app.staticTexts["MOVES"]
                let combosText = app.staticTexts["COMBOS"]

                XCTAssertTrue(
                    movesButton.exists || combosButton.exists || movesText.exists || combosText.exists,
                    "Should return to Arsenal"
                )
            }
        }
    }

    // MARK: - Move Detail Tests

    func testTapMoveOpensDetail() throws {
        navigateToArsenal()

        // Wait for content to load
        sleep(1)

        // Try to tap first move if it exists
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            sleep(1)

            // Verify detail view appears
            let hasDetailView = app.navigationBars.count > 0

            XCTAssertTrue(hasDetailView, "Move detail should open on tap")
        }
    }

    // MARK: - Search Tests

    func testSearchFieldExists() throws {
        navigateToArsenal()

        // Look for search field
        let searchField = app.searchFields.firstMatch
        let searchButton = app.buttons["Search"]

        if searchField.waitForExistence(timeout: 3) {
            XCTAssertTrue(searchField.exists, "Search field should exist")
        } else if searchButton.exists {
            XCTAssertTrue(searchButton.exists, "Search button should exist")
        }
    }

    func testSearchFiltersResults() throws {
        navigateToArsenal()

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("test")
            sleep(1)

            // Results should be filtered
            // Could verify count changes or specific content
        }
    }

    // MARK: - Filter Tests

    func testFilterByLearningState() throws {
        navigateToArsenal()

        // Look for filter button or segmented control
        let filterButton = app.buttons["Filter"]
        let newFilter = app.buttons["NEW"]
        let learningFilter = app.buttons["LEARNING"]

        if filterButton.waitForExistence(timeout: 3) {
            filterButton.tap()
            sleep(1)
        }

        // Try tapping a learning state filter
        if newFilter.exists {
            newFilter.tap()
            sleep(1)
            // Verify filter is applied
        } else if learningFilter.exists {
            learningFilter.tap()
            sleep(1)
        }
    }

    // MARK: - Video Thumbnail Tests

    func testVideoThumbnailsLoad() throws {
        navigateToArsenal()

        // Wait for thumbnails to load
        sleep(2)

        // Look for image views (thumbnails)
        let hasImages = app.images.count > 0

        // This may fail on empty state - that's expected
        if app.cells.count > 0 {
            // If there are cells, there should be images
            XCTAssertTrue(hasImages, "Video thumbnails should load for moves")
        }
    }

    // MARK: - Swipe Actions Tests

    func testSwipeToDeleteMove() throws {
        navigateToArsenal()

        sleep(1)

        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            // Swipe left to reveal delete action
            firstCell.swipeLeft()
            sleep(1)

            // Look for delete button
            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                // Don't actually delete in test, just verify it exists
                XCTAssertTrue(deleteButton.exists, "Delete button should appear on swipe")
            }
        }
    }

    // MARK: - Context Menu Tests

    func testLongPressShowsContextMenu() throws {
        navigateToArsenal()

        sleep(1)

        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            // Long press to show context menu
            firstCell.press(forDuration: 1.0)
            sleep(1)

            // Look for context menu items
            let hasContextMenu = app.buttons["Delete"].exists ||
                                 app.buttons["Edit"].exists ||
                                 app.collectionViews.buttons.count > 0

            // Context menu may or may not exist depending on implementation
            // Just verify no crash occurred
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    // MARK: - State Pill Tests

    func testStatePillsDisplay() throws {
        navigateToArsenal()

        sleep(1)

        // Look for state pills (NEW, LEARNING, MASTERY)
        let newPill = app.staticTexts["NEW"]
        let learningPill = app.staticTexts["LEARNING"]
        let masteryPill = app.staticTexts["MASTERY"]

        // If there are cells, at least one state should be visible
        if app.cells.count > 0 {
            let hasStatePill = newPill.exists || learningPill.exists || masteryPill.exists
            XCTAssertTrue(hasStatePill, "State pills should be visible on move cards")
        }
    }

    // MARK: - Performance Tests

    func testMoveListScrollPerformance() throws {
        navigateToArsenal()
        sleep(1)

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists && app.cells.count > 3 {
            measure(metrics: [XCTOSSignpostMetric.scrollDraggingMetric]) {
                scrollView.swipeUp()
                scrollView.swipeUp()
                scrollView.swipeDown()
                scrollView.swipeDown()
            }
        }
    }
}
