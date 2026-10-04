import XCTest

/// Captures the App Store screenshots: `make screenshots` runs this on each
/// required device and passes the folder to write them to. Without that
/// folder it skips, so ordinary test runs are not slowed by it.
///
/// The app is launched with `-ScreenshotSamples`: a lease (3 pages), receipts
/// (2) and site photos (2), made in code by debug builds.
@MainActor
final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()

    func testCaptureAppStoreScreenshots() throws {
        guard let folder = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("Run through `make screenshots`, which sets SCREENSHOT_DIR.")
        }
        continueAfterFailure = false
        app.launchArguments = ["-ScreenshotSamples"]
        app.launch()
        XCTAssertTrue(app.staticTexts["7 pages from 3 files"].waitForExistence(timeout: 15))

        try capture("01-pages", in: folder)

        app.buttons["Select"].tap()
        page(2).tap()
        page(6).tap()
        XCTAssertTrue(app.staticTexts["2 pages selected"].waitForExistence(timeout: 5))
        try capture("02-select", in: folder)
        app.buttons["Done"].firstMatch.tap()

        app.buttons["Files"].tap()
        XCTAssertTrue(app.navigationBars["Files"].waitForExistence(timeout: 5))
        try capture("03-files", in: folder)
        app.buttons["Done"].firstMatch.tap()

        page(6).tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].waitForExistence(timeout: 5))
        try capture("04-preview", in: folder)
        app.navigationBars.buttons["Done"].tap()

        app.buttons["Merge 7 Pages"].tap()
        XCTAssertTrue(app.staticTexts["Merged 7 pages"].waitForExistence(timeout: 30))
        try capture("05-merged", in: folder)
    }

    private func page(_ position: Int) -> XCUIElement {
        let element = app.descendants(matching: .any)["page-\(position)"].firstMatch
        if !element.isHittable { app.swipeUp() }
        return element
    }

    /// Waits for thumbnails and animations to settle, then saves the screen.
    private func capture(_ name: String, in folder: String) throws {
        Thread.sleep(forTimeInterval: 1.5)
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }
}
