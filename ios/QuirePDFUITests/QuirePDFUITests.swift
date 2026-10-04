import XCTest

/// Drives the app through its core flow with two sample PDFs, "Sample A"
/// (3 pages) and "Sample B" (4 pages), loaded by the `-UITestSamples` launch
/// argument so the tests do not depend on the system document picker.
@MainActor
final class QuirePDFUITests: XCTestCase {
    private let app = XCUIApplication()

    private func launchWithSamples() {
        continueAfterFailure = false
        app.launchArguments = ["-UITestSamples"]
        app.launch()
        XCTAssertTrue(app.staticTexts["7 pages from 2 files"].waitForExistence(timeout: 10))
    }

    private func page(_ position: Int) -> XCUIElement {
        app.descendants(matching: .any)["page-\(position)"].firstMatch
    }

    func testMovesAPageFromTheSecondFileToTheStart() {
        launchWithSamples()
        XCTAssertTrue(page(1).label.contains("Sample A, page 1"), page(1).label)

        app.buttons["Select"].tap()
        let last = page(7)
        if !last.isHittable { app.swipeUp() }
        last.tap()
        XCTAssertTrue(app.staticTexts["1 page selected"].waitForExistence(timeout: 5))
        app.buttons["Move to Start"].tap()
        app.buttons["Done"].tap()

        if !page(1).isHittable { app.swipeDown() }
        XCTAssertTrue(page(1).label.contains("Sample B, page 4"),
                      "the last page of the second file should now be first, got: \(page(1).label)")
        XCTAssertTrue(page(2).label.contains("Sample A, page 1"), page(2).label)
    }

    func testMergeThenStartNewMergeClearsEverything() {
        launchWithSamples()
        app.buttons["Merge 7 Pages"].tap()
        XCTAssertTrue(app.staticTexts["Merged 7 pages"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Share"].exists)
        XCTAssertTrue(app.buttons["Save to Files"].exists)

        app.buttons["Start New Merge"].tap()
        XCTAssertTrue(app.buttons["Choose PDFs"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["7 pages from 2 files"].exists)
    }

    func testDoneAfterMergeKeepsThePages() {
        launchWithSamples()
        app.buttons["Merge 7 Pages"].tap()
        XCTAssertTrue(app.staticTexts["Merged 7 pages"].waitForExistence(timeout: 30))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["7 pages from 2 files"].waitForExistence(timeout: 5))
    }
}
