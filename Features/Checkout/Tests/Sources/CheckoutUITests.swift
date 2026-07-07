import Testing
import Foundation
@testable import Checkout

/// Tests that exercise complete user interaction flows through the Checkout module.
@Suite("Checkout — UI Interaction Tests")
@MainActor
struct CheckoutUITests {

    // MARK: - Cart management

    @Test("User adds multiple products and sees correct item count")
    func userBuildsCart() {
        let model = CheckoutModel()
        model.addToCart(CheckoutProduct.stubs[0])
        model.addToCart(CheckoutProduct.stubs[1])
        model.addToCart(CheckoutProduct.stubs[0]) // duplicate — increments quantity
        #expect(model.cart.count == 2)
        #expect(model.itemCount == 3)
    }

    @Test("User removes an item from the cart")
    func userRemovesItem() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let before = model.cart.count
        model.removeItem(model.cart[0])
        #expect(model.cart.count == before - 1)
    }

    @Test("User updates item quantity")
    func userUpdatesQuantity() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let item = model.cart[0]
        model.updateQuantity(for: item, quantity: 3)
        #expect(model.cart.first(where: { $0.id == item.id })?.quantity == 3)
    }

    // MARK: - Checkout funnel navigation

    @Test("User proceeds from cart to address form")
    func userProceedsToAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.proceedToAddress()
        #expect(model.destination == .addressForm)
    }

    @Test("User submits an address and proceeds to order options")
    func userSubmitsAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.submitAddress(.stub)
        #expect(model.destination == .orderOptions(.stub))
    }

    @Test("User proceeds from order options to payment method selection")
    func userProceedsToPaymentMethod() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.proceedToPaymentMethod(address: .stub)
        #expect(model.destination == .paymentMethodSelection(.stub))
    }

    @Test("Selecting credit card navigates to payment entry form")
    func userSelectsCreditCard() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.selectPaymentMethod(.creditCard, address: .stub)
        #expect(model.destination == .paymentEntry(.stub))
    }

    @Test("Selecting Apple Pay goes directly to processing without showing card form")
    func userSelectsApplePay() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(delay: .zero)
        )
        model.selectPaymentMethod(.applePay, address: .stub)
        // Give the spawned Task a moment to run
        try? await Task.sleep(for: .milliseconds(100))
        // Either processing or confirmation depending on timing — destination must not be .paymentEntry
        if let dest = model.destination {
            switch dest {
            case .paymentEntry: Issue.record("Apple Pay should not show the card entry form")
            default: break
            }
        }
    }

    // MARK: - Full payment flow

    @Test("Successful payment clears the cart and shows confirmation")
    func successfulPaymentClearsCart() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(delay: .zero)
        )
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.cart.isEmpty)
        guard case .confirmation = model.destination else {
            Issue.record("Expected .confirmation destination after payment")
            return
        }
    }

    @Test("Successful payment fires onOrderPlaced callback")
    func successfulPaymentFiresCallback() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(delay: .zero)
        )
        var callbackFired = false
        model.onOrderPlaced = { _, _ in callbackFired = true }
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(callbackFired)
    }

    @Test("Failed payment shows paymentFailed destination")
    func failedPaymentShowsError() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(throwing: PaymentError.cardDeclined)
        )
        await model.submitPayment(address: .stub, cardToken: "tok_bad")
        guard case .paymentFailed(let error) = model.destination else {
            Issue.record("Expected .paymentFailed destination")
            return
        }
        #expect(error == .cardDeclined)
    }

    @Test("User retries after a failed payment and returns to address form")
    func userRetriesAfterFailure() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(throwing: PaymentError.cardDeclined)
        )
        await model.submitPayment(address: .stub, cardToken: "tok_bad")
        model.retryPayment()
        #expect(model.destination == .addressForm)
    }

    // MARK: - Extended guarantee selection during checkout

    @Test("User opts into and out of extended guarantee during checkout")
    func userTogglesGuarantee() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let product = CheckoutProduct.stubs[0]
        model.toggleGuarantee(for: product)
        #expect(model.guaranteeCost == Decimal(9.99))
        model.toggleGuarantee(for: product)
        #expect(model.guaranteeCost == 0)
    }
}
