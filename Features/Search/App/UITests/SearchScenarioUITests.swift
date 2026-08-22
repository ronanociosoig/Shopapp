import XCTest

/// Verifies the scenario picker's tap-to-navigate actually works — the one
/// gap the pilot commit (e2b082a) explicitly flagged as unverified, since no
/// tap-synthesis tool was available at the time.
final class SearchScenarioUITests: XCTestCase {
    func test_tappingAScenario_opensTheRealSearchView() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Search Scenarios"].waitForExistence(timeout: 5))
        app.buttons["Results Loaded"].tap()

        XCTAssertTrue(
            app.navigationBars["Search"].waitForExistence(timeout: 5),
            "Tapping a scenario row should open the real SearchView, not leave the scenario list showing"
        )
    }
}
