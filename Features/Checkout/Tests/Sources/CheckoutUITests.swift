import Testing
import Foundation
@testable import Checkout
@testable import CheckoutAPI
import CheckoutTesting

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

    @Test("User proceeds from cart to address step")
    func userProceedsToAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.proceedToAddress()
        #expect(model.path.last == .address)
    }

    @Test("User submits an address and proceeds to order options")
    func userSubmitsAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.submitAddress(.stub)
        #expect(model.path.last == .orderOptions(.stub))
    }

    @Test("User proceeds from order options to payment method step")
    func userProceedsToPaymentMethod() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.proceedToPaymentMethod(address: .stub)
        #expect(model.path.last == .paymentMethod(.stub))
    }

    @Test("Selecting credit card pushes payment entry onto the path")
    func userSelectsCreditCard() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.selectPaymentMethod(.creditCard, address: .stub)
        #expect(model.path.last == .paymentEntry(.stub))
    }

    @Test("Selecting Apple Pay does not push payment entry onto the path")
    func userSelectsApplePay() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(delay: .zero)
        )
        model.selectPaymentMethod(.applePay, address: .stub)
        try? await Task.sleep(for: .milliseconds(100))
        let pushedCardEntry = model.path.contains(where: {
            if case .paymentEntry = $0 { return true }; return false
        })
        #expect(!pushedCardEntry, "Apple Pay should not push the card entry step")
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

    @Test("User retries after a failed payment and returns to the address step")
    func userRetriesAfterFailure() async {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(throwing: PaymentError.cardDeclined)
        )
        await model.submitPayment(address: .stub, cardToken: "tok_bad")
        model.retryPayment()
        #expect(model.destination == nil)
        #expect(model.path == [.address])
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
