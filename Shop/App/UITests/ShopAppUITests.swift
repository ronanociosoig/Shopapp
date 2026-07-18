import XCTest

/// End-to-end UI test that walks the full purchase funnel through the main ShopApp:
/// browse the store → add two items to the cart → complete checkout.
///
/// The app is launched with `--ui-testing` so it boots with stub repositories
/// and a zero-delay checkout, keeping the test deterministic and network-free.
final class ShopAppPurchaseUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Happy path

    func test_happyPath_addsTwoItemsAndCompletesCheckout() throws {

        // ── 1. Store ──────────────────────────────────────────────────────────
        XCTAssertTrue(
            app.navigationBars["Shop"].waitForExistence(timeout: 5),
            "Store screen should be the initial screen"
        )

        // ── 2. Add first item ─────────────────────────────────────────────────
        app.staticTexts["MacBook Pro 16\""].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["MacBook Pro 16\""].waitForExistence(timeout: 5))

        app.buttons["Add to Cart"].tap()
        XCTAssertTrue(
            app.buttons["Added to Cart ✓"].waitForExistence(timeout: 5),
            "Cart confirmation should flash after adding first item"
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()

        // ── 3. Add second item ────────────────────────────────────────────────
        XCTAssertTrue(app.navigationBars["Shop"].waitForExistence(timeout: 5))

        app.staticTexts["MacBook Air 15\""].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["MacBook Air 15\""].waitForExistence(timeout: 5))

        app.buttons["Add to Cart"].tap()
        XCTAssertTrue(
            app.buttons["Added to Cart ✓"].waitForExistence(timeout: 5),
            "Cart confirmation should flash after adding second item"
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()

        // ── 4. Cart ───────────────────────────────────────────────────────────
        app.tabBars.buttons["Cart"].tap()
        XCTAssertTrue(app.navigationBars["Your Cart"].waitForExistence(timeout: 5))

        app.buttons["Proceed to Checkout"].tap()

        // ── 5. Shipping Address ───────────────────────────────────────────────
        XCTAssertTrue(app.navigationBars["Shipping Address"].waitForExistence(timeout: 5))
        app.staticTexts["Alex Johnson"].firstMatch.tap()
        app.navigationBars.buttons["Continue"].tap()

        // ── 6. Delivery & Extras ──────────────────────────────────────────────
        XCTAssertTrue(app.navigationBars["Delivery & Extras"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Continue"].tap()

        // ── 7. Payment Method ─────────────────────────────────────────────────
        XCTAssertTrue(app.navigationBars["Payment"].waitForExistence(timeout: 5))
        app.buttons["Credit / Debit Card"].tap()

        // ── 8. Card Entry ─────────────────────────────────────────────────────
        let cardField = app.textFields["Card number"]
        XCTAssertTrue(cardField.waitForExistence(timeout: 5))
        cardField.tap()
        cardField.typeText("4111111111111111")

        app.textFields["MM/YY"].tap()
        app.textFields["MM/YY"].typeText("12/26")

        app.textFields["CVV"].tap()
        app.textFields["CVV"].typeText("123")

        app.navigationBars.buttons["Pay now"].tap()

        // ── 9. Confirmation ───────────────────────────────────────────────────
        XCTAssertTrue(
            app.staticTexts["Order Confirmed!"].waitForExistence(timeout: 10),
            "Order confirmation should appear after successful payment"
        )
    }
}
