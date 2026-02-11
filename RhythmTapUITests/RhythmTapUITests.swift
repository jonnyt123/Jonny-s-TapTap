import XCTest

/// Minimal UI / visual baseline tests: app launches and main screen appears.
/// No snapshot library; uses accessibility and existence checks only.
final class RhythmTapUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Baseline: app launches and main menu (or root) is reachable.
    func testAppLaunches() throws {
        app.launch()
        // Wait for app to be ready (main menu has accessibility identifier "mainMenu")
        let menu = app.descendants(matching: .any).matching(identifier: "mainMenu").firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "Main menu should appear after launch")
    }

    /// Baseline: app stays responsive (no immediate crash after launch).
    func testAppStaysRunning() throws {
        app.launch()
        sleep(2)
        XCTAssertTrue(app.exists, "App should still be running")
    }
}
