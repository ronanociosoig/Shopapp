import Testing
import Foundation
@testable import Checkout

@Suite("CheckoutModel — Payment Flow")
@MainActor
struct CheckoutModelPaymentTests {

    // Shared helpers

    private func makeModel(
        error: Error? = nil
    ) -> CheckoutModel {
        let repo: CheckoutRepositoryProtocol = error.map { StubCheckoutRepository(throwing: $0) }
            ?? StubCheckoutRepository(delay: .zero)
        return CheckoutModel(repository: repo)
    }

    private func makeModelWithItem(error: Error? = nil) -> CheckoutModel {
        let model = makeModel(error: error)
        model.addToCart(.stub)
        return model
    }

    // MARK: - submitAddress

    @Test("submitAddress sets destination to orderOptions with the given address")
    func submitAddressNavigatesToOrderOptions() {
        let model = makeModelWithItem()
        model.submitAddress(.stub)
        #expect(model.destination == .orderOptions(.stub))
    }

    // MARK: - proceedToPaymentMethod

    @Test("proceedToPaymentMethod sets destination to paymentMethodSelection")
    func proceedToPaymentMethodNavigates() {
        let model = makeModelWithItem()
        model.proceedToPaymentMethod(address: .stub)
        #expect(model.destination == .paymentMethodSelection(.stub))
    }

    // MARK: - selectPaymentMethod

    @Test("selectPaymentMethod(.creditCard) sets destination to paymentEntry")
    func selectCreditCardNavigatesToPaymentEntry() {
        let model = makeModelWithItem()
        model.selectPaymentMethod(.creditCard, address: .stub)
        #expect(model.destination == .paymentEntry(.stub))
    }

    // MARK: - submitPayment — success

//    @Test("submitPayment sets destination to .processing while the request is in flight")
//    func submitPaymentSetsProcessingState() async {
//        // Use a non-zero delay so we can observe the .processing transition
//        let model = CheckoutModel(repository: StubCheckoutRepository(delay: .milliseconds(50)))
//        model.addToCart(.stub)
//        let task = Task { await model.submitPayment(address: .stub, cardToken: "tok_test") }
//        // Yield briefly to let the task start and set .processing
//        await Task.yield()
//        if case .processing = model.destination {} else {
//            Issue.record("Expected .processing during submission, got \(String(describing: model.destination))")
//        }
//        await task.value
//    }

    @Test("submitPayment on success sets destination to .confirmation")
    func submitPaymentSuccessNavigatesToConfirmation() async {
        let model = makeModelWithItem()
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        if case .confirmation = model.destination {} else {
            Issue.record("Expected .confirmation, got \(String(describing: model.destination))")
        }
    }

    @Test("submitPayment on success clears the cart")
    func submitPaymentClearsCartOnSuccess() async {
        let model = makeModelWithItem()
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.cart.isEmpty)
    }

    @Test("submitPayment on success clears extended guarantee selections")
    func submitPaymentClearsGuarantees() async {
        let model = makeModelWithItem()
        model.extendedGuaranteeItems.insert(CheckoutProduct.stub.id)
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.extendedGuaranteeItems.isEmpty)
    }

    @Test("submitPayment on success resets delivery option to standard")
    func submitPaymentResetsDeliveryOption() async {
        let model = makeModelWithItem()
        model.deliveryOption = .express
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.deliveryOption == .standard)
    }

    @Test("submitPayment fires onOrderPlaced callback with the placed order")
    func submitPaymentFiresOnOrderPlacedCallback() async {
        let model = makeModelWithItem()
        var receivedOrder: PlacedOrder?
        model.onOrderPlaced = { order, _ in receivedOrder = order }
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(receivedOrder != nil)
    }

    @Test("submitPayment passes the guarantee item set to the onOrderPlaced callback")
    func submitPaymentPassesGuaranteeItemsToCallback() async {
        let model = makeModelWithItem()
        model.extendedGuaranteeItems.insert(CheckoutProduct.stub.id)
        var receivedGuarantees: Set<UUID>?
        model.onOrderPlaced = { _, guarantees in receivedGuarantees = guarantees }
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(receivedGuarantees?.contains(CheckoutProduct.stub.id) == true)
    }

    // MARK: - submitPayment — failure

    @Test("submitPayment with a PaymentError sets destination to .paymentFailed with that error")
    func submitPaymentPaymentErrorNavigatesToFailed() async {
        let model = makeModelWithItem(error: PaymentError.cardDeclined)
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.destination == .paymentFailed(.cardDeclined))
    }

    @Test("submitPayment with a non-PaymentError wraps it as .paymentFailed(.unknown)")
    func submitPaymentUnknownErrorBecomesUnknown() async {
        let model = makeModelWithItem(error: URLError(.notConnectedToInternet))
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(model.destination == .paymentFailed(.unknown))
    }

    @Test("submitPayment failure does not clear the cart")
    func submitPaymentFailurePreservesCart() async {
        let model = makeModelWithItem(error: PaymentError.cardDeclined)
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        #expect(!model.cart.isEmpty)
    }
}
