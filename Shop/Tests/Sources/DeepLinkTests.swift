import Testing
import Foundation
@testable import ShopCore
@testable import Promotions
import PromotionsTesting
@_spi(Internals) @testable import Checkout
import CheckoutTesting
@testable import PastPurchases

@Suite("Deep Links")
@MainActor
struct DeepLinkTests {

    @Test("A promotions deep link resolves to the matching promotion and switches to the Store tab")
    func promotionDeepLink() async throws {
        let model = makeModel()
        let promotion = Promotion.stubs[0]
        let url = URL(string: "shopapp://promotions/\(promotion.id.uuidString)")!

        await model.handle(url: url)

        #expect(model.selectedTab == .store)
        #expect(model.promotionsModel.destination == .promotionDetail(promotion))
    }

    @Test("An unknown promotion id leaves the destination untouched")
    func unknownPromotionID() async throws {
        let model = makeModel()
        let url = URL(string: "shopapp://promotions/\(UUID().uuidString)")!

        await model.handle(url: url)

        #expect(model.promotionsModel.destination == nil)
    }

    @Test("An unrecognized host does nothing")
    func unrecognizedHost() async throws {
        let model = makeModel()
        let url = URL(string: "shopapp://not-a-real-feature/123")!

        await model.handle(url: url)

        #expect(model.promotionsModel.destination == nil)
    }

    @Test("A checkout deep link resolves to Delivery & Extras and switches to the Cart tab")
    func checkoutDeliveryDeepLink() async throws {
        let model = makeModel()
        model.checkoutFactory.model.cart = CartItem.stubs
        model.checkoutFactory.setSavedAddresses(ShippingAddress.stubs)
        let url = URL(string: "shopapp://checkout/delivery")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [.address, .orderOptions(ShippingAddress.stubs[0])])
    }

    @Test("A checkout deep link with an empty cart switches tabs but can't reach Delivery & Extras")
    func checkoutDeliveryDeepLinkEmptyCart() async throws {
        let model = makeModel()
        model.checkoutFactory.setSavedAddresses(ShippingAddress.stubs)
        let url = URL(string: "shopapp://checkout/delivery")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [])
    }

    @Test("A checkout deep link with no saved address switches tabs but can't reach Delivery & Extras")
    func checkoutDeliveryDeepLinkNoSavedAddress() async throws {
        let model = makeModel()
        model.checkoutFactory.model.cart = CartItem.stubs
        let url = URL(string: "shopapp://checkout/delivery")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [])
    }

    @Test("A checkout payment-retry deep link lands on Payment Method and switches to the Cart tab")
    func checkoutPaymentRetryDeepLink() async throws {
        let model = makeModel()
        model.checkoutFactory.model.cart = CartItem.stubs
        model.checkoutFactory.setSavedAddresses(ShippingAddress.stubs)
        let url = URL(string: "shopapp://checkout/payment-retry")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [
            .address, .orderOptions(ShippingAddress.stubs[0]), .paymentMethod(ShippingAddress.stubs[0]),
        ])
    }

    @Test("A checkout payment-retry deep link with an empty cart switches tabs but can't reach Payment Method")
    func checkoutPaymentRetryDeepLinkEmptyCart() async throws {
        let model = makeModel()
        model.checkoutFactory.setSavedAddresses(ShippingAddress.stubs)
        let url = URL(string: "shopapp://checkout/payment-retry")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [])
    }

    @Test("A checkout payment-retry deep link with no saved address switches tabs but can't reach Payment Method")
    func checkoutPaymentRetryDeepLinkNoSavedAddress() async throws {
        let model = makeModel()
        model.checkoutFactory.model.cart = CartItem.stubs
        let url = URL(string: "shopapp://checkout/payment-retry")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.path == [])
    }

    @Test("A checkout add-to-cart deep link adds the named product and switches to the Cart tab")
    func checkoutAddToCartDeepLink() async throws {
        let model = makeModel()
        let id = UUID()
        let url = URL(string: "shopapp://checkout/add/\(id.uuidString)?name=Desk%20Lamp&price=69.99&guarantee=true")!

        await model.handle(url: url)

        #expect(model.selectedTab == .cart)
        #expect(model.checkoutFactory.model.cart.count == 1)
        #expect(model.checkoutFactory.model.cart[0].product.id == id)
        #expect(model.checkoutFactory.model.cart[0].product.name == "Desk Lamp")
        #expect(model.checkoutFactory.model.cart[0].product.price == 69.99)
    }

    @Test("A checkout add-to-cart deep link missing price does nothing")
    func checkoutAddToCartDeepLinkMissingPrice() async throws {
        let model = makeModel()
        let id = UUID()
        let url = URL(string: "shopapp://checkout/add/\(id.uuidString)?name=Desk%20Lamp")!

        await model.handle(url: url)

        #expect(model.checkoutFactory.model.cart.isEmpty)
    }

    @Test("An orders deep link resolves to the matching order and switches to the Orders tab")
    func orderDeepLink() async throws {
        let model = makeModel()
        let order = PastOrder.stubs[0]
        let url = URL(string: "shopapp://orders/\(order.id.uuidString)")!

        await model.handle(url: url)

        #expect(model.selectedTab == .orders)
        #expect(model.pastPurchasesModel.destination == .orderDetail(order))
    }

    @Test("An unknown order id leaves the destination untouched")
    func unknownOrderID() async throws {
        let model = makeModel()
        let url = URL(string: "shopapp://orders/\(UUID().uuidString)")!

        await model.handle(url: url)

        #expect(model.pastPurchasesModel.destination == nil)
    }
}
