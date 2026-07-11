import XCTest

/// End-to-end UI test that walks the full checkout funnel through the live app UI.
///
/// This is the XCUITest counterpart to `CheckoutFunnelFlowTests` in
/// CheckoutSnapshotTests.swift. Both cover the same happy path through the same
/// six screens. The contrast between the two illuminates the key trade-offs:
///
/// | Dimension            | Snapshot (programmatic)        | XCUITest (end-to-end)              |
/// |----------------------|--------------------------------|------------------------------------|
/// | Speed                | < 1 s (no app launch)          | 15 – 30 s (full launch + UI)       |
/// | Fragility            | Immune to UI text changes      | Breaks on label / identifier edits |
/// | What it exercises    | View rendering & model state   | Real NavigationStack & animations  |
/// | Setup complexity     | Inject any state in one line   | App must be built with test data   |
///
final class CheckoutFunnelUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Happy path

    func test_happyPath_completesCheckoutFromCartToConfirmation() throws {

        // ── 1. Cart ───────────────────────────────────────────────────────────
        XCTAssertTrue(
            app.navigationBars["Your Cart"].waitForExistence(timeout: 5),
            "Cart screen should be the initial screen"
        )
        app.buttons["Proceed to Checkout"].tap()

        // ── 2. Shipping Address ───────────────────────────────────────────────
        // proceedToAddress() auto-selects the default address, so "Continue" is
        // enabled as soon as this screen appears. We tap the row explicitly so
        // the test reads as a faithful description of the user journey.
        XCTAssertTrue(
            app.navigationBars["Shipping Address"].waitForExistence(timeout: 5)
        )
        app.staticTexts["Jane Appleseed"].firstMatch.tap()
        app.navigationBars.buttons["Continue"].tap()

        // ── 3. Delivery & Extras ──────────────────────────────────────────────
        XCTAssertTrue(
            app.navigationBars["Delivery & Extras"].waitForExistence(timeout: 5)
        )
        app.navigationBars.buttons["Continue"].tap()

        // ── 4. Payment Method ─────────────────────────────────────────────────
        XCTAssertTrue(
            app.navigationBars["Payment"].waitForExistence(timeout: 5)
        )
        app.buttons["Credit / Debit Card"].tap()

        // ── 5. Card Entry ─────────────────────────────────────────────────────
        // Validation: cardNumber.count >= 15, expiry.count == 5, cvv.count >= 3
        let cardField = app.textFields["Card number"]
        XCTAssertTrue(cardField.waitForExistence(timeout: 5))
        cardField.tap()
        cardField.typeText("4111111111111111")

        app.textFields["MM/YY"].tap()
        app.textFields["MM/YY"].typeText("12/26")

        app.textFields["CVV"].tap()
        app.textFields["CVV"].typeText("123")

        app.navigationBars.buttons["Pay now"].tap()

        // ── 6. Confirmation ───────────────────────────────────────────────────
        XCTAssertTrue(
            app.staticTexts["Order Confirmed!"].waitForExistence(timeout: 10),
            "Order confirmation should appear after successful payment"
        )
    }
}
