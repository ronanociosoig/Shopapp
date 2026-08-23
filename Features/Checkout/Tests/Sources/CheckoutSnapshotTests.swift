#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Checkout
@testable import CheckoutAPI
import CheckoutTesting

// MARK: - CaseIterable: Destination (modal surfaces)

extension CheckoutModel.Destination: CaseIterable {
    public static var allCases: [CheckoutModel.Destination] {
        [
            .processing,
            .confirmation(.stub),
            .paymentFailed(.cardDeclined),
        ]
    }
}

// MARK: - CaseIterable: CheckoutStep (funnel screens)

extension CheckoutStep: CaseIterable {
    public static var allCases: [CheckoutStep] {
        [
            .address,
            .orderOptions(.stub),
            .paymentMethod(.stub),
            .paymentEntry(.stub),
        ]
    }
}

// MARK: - Snapshot Tests

@Suite("Checkout — Snapshot Tests")
@MainActor
struct CheckoutSnapshotTests {

    @Test("Cart renders correctly with items")
    func cartWithItems() async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "cart_populated")
    }

    @Test("Cart renders correctly when empty")
    func cartEmpty() async throws {
        let model = CheckoutModel(cart: [])
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "cart_empty")
    }

    @Test("Cart renders correctly with a single item")
    func cartWithSingleItem() async throws {
        let model = CheckoutModel(cart: [CartItem(product: CheckoutProduct.stubs[0])])
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "cart_single_item")
    }

    @Test("Cart renders correctly with extended guarantee opted in for all items")
    func cartWithGuaranteeOptedIn() async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.extendedGuaranteeItems = Set(CartItem.stubs.map(\.product.id))
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "cart_guarantee_opted_in")
    }

    @Test("Cart renders correctly with express delivery selected")
    func cartWithExpressDelivery() async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.deliveryOption = .express
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "cart_express_delivery")
    }

    @Test("Each funnel step renders correctly", arguments: CheckoutStep.allCases)
    func step(_ step: CheckoutStep) async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.savedAddresses = ShippingAddress.stubs
        model.path = [step]
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: snapshotName(step))
    }

    @Test("Each modal destination renders correctly", arguments: CheckoutModel.Destination.allCases)
    func destination(_ destination: CheckoutModel.Destination) async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.destination = destination
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: snapshotName(destination))
    }

    @Test("Payment failed screen renders correctly for each error type", arguments: PaymentError.allCases)
    func paymentFailureVariants(error: PaymentError) async throws {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.destination = .paymentFailed(error)
        assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)), named: "payment_failed_\(error.id)")
    }
}

// MARK: - CaseIterable for PaymentError

extension PaymentError: CaseIterable {
    public static var allCases: [PaymentError] {
        [.cardDeclined, .insufficientFunds, .expiredCard, .fraudSuspected, .networkError, .unknown]
    }
}

// MARK: - Funnel Flow Snapshot Tests

/// Walks the complete checkout funnel using the same method calls a real user
/// would trigger, snapshotting the view after each state transition.
///
/// No XCUITest, no simulator interaction, no waiting for animations —
/// every screen is captured by setting model state directly.
@Suite("Checkout — Funnel Flow Snapshot Tests")
@MainActor
struct CheckoutFunnelFlowTests {

    @Test("Happy path — snapshot every step of the checkout funnel in sequence")
    func happyPathFunnel() async throws {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(delay: .zero)
        )
        model.savedAddresses = [.stub]

        // Step 1 — Cart
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_1_cart")

        // Step 2 — Address form
        model.proceedToAddress()
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_2_address")

        // Step 3 — Order options (delivery speed + extended guarantee)
        model.submitAddress(.stub)
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_3_order_options")

        // Step 4 — Payment method selection
        model.proceedToPaymentMethod(address: .stub)
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_4_payment_method")

        // Step 5 — Card entry form
        model.selectPaymentMethod(.creditCard, address: .stub)
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_5_payment_entry")

        // Step 6 — Confirmation (processing resolves instantly with delay: .zero)
        await model.submitPayment(address: .stub, cardToken: "tok_test")
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_6_confirmation")
    }

    @Test("Failure path — card declined shows error screen, retrying returns to address step")
    func cardDeclinedFunnel() async throws {
        let model = CheckoutModel(
            cart: CartItem.stubs,
            repository: StubCheckoutRepository(throwing: PaymentError.cardDeclined)
        )
        model.savedAddresses = [.stub]

        model.proceedToAddress()
        model.submitAddress(.stub)
        model.proceedToPaymentMethod(address: .stub)
        model.selectPaymentMethod(.creditCard, address: .stub)

        // Payment fails
        await model.submitPayment(address: .stub, cardToken: "tok_bad")
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_failure_card_declined")

        // Retry clears modal and returns to address step
        model.retryPayment()
        assertSnapshot(of: CheckoutView(model: model),
                       as: .image(layout: .device(config: .iPhone13Pro)),
                       named: "step_failure_retry_address")
    }
}

// MARK: - Helpers

private func snapshotName(_ step: CheckoutStep) -> String {
    switch step {
    case .address:               return "step_address"
    case .orderOptions:          return "step_order_options"
    case .paymentMethod:         return "step_payment_method"
    case .paymentEntry:          return "step_payment_entry"
    }
}

private func snapshotName(_ destination: CheckoutModel.Destination) -> String {
    switch destination {
    case .processing:            return "destination_processing"
    case .confirmation:          return "destination_confirmation"
    case .paymentFailed(let err): return "destination_payment_failed_\(err.id)"
    }
}
#endif
