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

        // ── 0. Scenario picker ───────────────────────────────────────────────
        // The micro-app's root screen is a scenario list (see CheckoutScenario);
        // "Cart" is the pre-populated funnel starting point.
        XCTAssertTrue(
            app.navigationBars["Checkout Scenarios"].waitForExistence(timeout: 5)
        )
        app.buttons["Cart"].tap()

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

    // MARK: - Scenario picker dismissal

    /// `fullScreenCover` has no built-in swipe-to-dismiss on iOS, and
    /// `CheckoutView` has no dismiss affordance of its own — without the
    /// "Scenarios" strip, restarting the micro-app was the only way back to
    /// the list. Regression coverage for that specific fix, not just the
    /// happy-path funnel above.
    func test_scenarioPreview_returnsToScenarioList() throws {
        XCTAssertTrue(
            app.navigationBars["Checkout Scenarios"].waitForExistence(timeout: 5)
        )
        app.buttons["Cart"].tap()

        XCTAssertTrue(
            app.navigationBars["Your Cart"].waitForExistence(timeout: 5),
            "Cart screen should be the initial screen"
        )

        app.buttons["Scenarios"].tap()

        XCTAssertTrue(
            app.navigationBars["Checkout Scenarios"].waitForExistence(timeout: 5),
            "Tapping the scenario strip's back button should return to the scenario list"
        )
    }

    /// `.processing`'s sheet is `interactiveDismissDisabled()` on purpose —
    /// production never needs it dismissed any other way, since it always
    /// resolves once the real network call returns. The scenario has no such
    /// call in flight, so without `CheckoutModel.clearDestination()` firing
    /// on a delay, this scenario would be a genuine dead end: the sheet
    /// covers the whole screen, including the "Scenarios" strip above
    /// `CheckoutView`, so restarting the micro-app would be the only way out.
    func test_processingScenario_resolvesOnItsOwn() throws {
        XCTAssertTrue(
            app.navigationBars["Checkout Scenarios"].waitForExistence(timeout: 5)
        )
        app.buttons["Processing"].tap()

        XCTAssertTrue(
            app.staticTexts["Processing your order…"].waitForExistence(timeout: 5),
            "Processing scenario should show the non-dismissable processing sheet"
        )

        // Covered by the sheet, not just visually behind other content —
        // asserting this now (rather than assuming) is the point: a hit-test
        // failure here is exactly the dead end this scenario used to be.
        XCTAssertFalse(
            app.buttons["Scenarios"].isHittable,
            "The scenario strip should be covered while the processing sheet is up"
        )

        let processingGone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.staticTexts["Processing your order…"]
        )
        wait(for: [processingGone], timeout: 5)

        XCTAssertTrue(
            app.buttons["Scenarios"].isHittable,
            "The scenario strip should be reachable again once processing clears itself"
        )
    }
}
