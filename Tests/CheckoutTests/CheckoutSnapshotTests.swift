#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Checkout

// MARK: - CaseIterable conformance

extension CheckoutModel.Destination: CaseIterable {
    public static var allCases: [CheckoutModel.Destination] {
        [
            .addressForm,
            .orderOptions(.stub),
            .paymentMethodSelection(.stub),
            .paymentEntry(.stub),
            .processing,
            .confirmation(.stub),
            .paymentFailed(.cardDeclined),
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

    @Test("Each checkout destination renders correctly", arguments: CheckoutModel.Destination.allCases)
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

// MARK: - Helpers

private func snapshotName(_ destination: CheckoutModel.Destination) -> String {
    switch destination {
    case .addressForm:             return "destination_address_form"
    case .orderOptions:            return "destination_order_options"
    case .paymentMethodSelection:  return "destination_payment_method_selection"
    case .paymentEntry:            return "destination_payment_entry"
    case .processing:              return "destination_processing"
    case .confirmation:            return "destination_confirmation"
    case .paymentFailed(let err):  return "destination_payment_failed_\(err.id)"
    }
}
#endif
