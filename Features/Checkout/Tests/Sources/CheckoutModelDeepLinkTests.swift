import Testing
import Foundation
@testable import Checkout
import CheckoutTesting

/// `AppModel+DeepLinks.swift` only ever calls `CheckoutModel.handleDeepLink(url:)`
/// through the composition root, so `ShopAppTests/DeepLinkTests.swift` already
/// covers it black-box. These tests exercise the same method directly, inside
/// Checkout's own test target — the parsing lives here now, so the coverage
/// for it should too, not only reachable by going through `AppModel`.
@Suite("CheckoutModel – deep link parsing")
@MainActor
struct CheckoutModelDeepLinkTests {

    // MARK: - delivery

    @Test("checkout/delivery lands on Delivery & Extras and returns true")
    func deliverySucceeds() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.savedAddresses = ShippingAddress.stubs

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/delivery")!)

        #expect(handled)
        #expect(model.path == [.address, .orderOptions(ShippingAddress.stubs[0])])
    }

    @Test("checkout/delivery with an empty cart is still recognized, but can't reach Delivery & Extras")
    func deliveryFailsOnEmptyCart() {
        let model = CheckoutModel()
        model.savedAddresses = ShippingAddress.stubs

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/delivery")!)

        // `true` here means "this was a checkout/delivery URL," not "the funnel
        // could satisfy it" — same reason the old toolbar flow switched to the
        // Cart tab even on refusal. `path` is where the refusal actually shows.
        #expect(handled)
        #expect(model.path == [])
    }

    @Test("checkout/delivery with no saved address is still recognized, but can't reach Delivery & Extras")
    func deliveryFailsOnNoSavedAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/delivery")!)

        #expect(handled)
        #expect(model.path == [])
    }

    // MARK: - payment-retry

    @Test("checkout/payment-retry lands on Payment Method and returns true")
    func paymentRetrySucceeds() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.savedAddresses = ShippingAddress.stubs

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/payment-retry")!)

        #expect(handled)
        #expect(model.path == [
            .address, .orderOptions(ShippingAddress.stubs[0]), .paymentMethod(ShippingAddress.stubs[0]),
        ])
    }

    @Test("checkout/payment-retry with an empty cart is still recognized, but can't reach Payment Method")
    func paymentRetryFailsOnEmptyCart() {
        let model = CheckoutModel()
        model.savedAddresses = ShippingAddress.stubs

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/payment-retry")!)

        #expect(handled)
        #expect(model.path == [])
    }

    @Test("checkout/payment-retry with no saved address is still recognized, but can't reach Payment Method")
    func paymentRetryFailsOnNoSavedAddress() {
        let model = CheckoutModel(cart: CartItem.stubs)

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/payment-retry")!)

        #expect(handled)
        #expect(model.path == [])
    }

    // MARK: - add

    @Test("checkout/add adds the named product and returns true")
    func addSucceeds() {
        let model = CheckoutModel()
        let id = UUID()
        let url = URL(string: "shopapp://checkout/add/\(id.uuidString)?name=Desk%20Lamp&price=69.99&guarantee=true")!

        let handled = model.handleDeepLink(url: url)

        #expect(handled)
        #expect(model.cart.count == 1)
        #expect(model.cart[0].product.id == id)
        #expect(model.cart[0].product.name == "Desk Lamp")
        #expect(model.cart[0].product.price == 69.99)
        #expect(model.extendedGuaranteeItems.contains(id))
    }

    @Test("checkout/add missing price adds nothing and returns false")
    func addFailsOnMissingPrice() {
        let model = CheckoutModel()
        let url = URL(string: "shopapp://checkout/add/\(UUID().uuidString)?name=Desk%20Lamp")!

        let handled = model.handleDeepLink(url: url)

        #expect(!handled)
        #expect(model.cart.isEmpty)
    }

    // MARK: - unrecognized

    @Test("An unrecognized checkout path segment changes nothing and returns false")
    func unrecognizedPathFails() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.savedAddresses = ShippingAddress.stubs

        let handled = model.handleDeepLink(url: URL(string: "shopapp://checkout/not-a-real-step")!)

        #expect(!handled)
        #expect(model.path == [])
    }
}
