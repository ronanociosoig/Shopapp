import Testing
import Foundation
@testable import Checkout

@Suite("CheckoutModel — Unit Tests")
struct CheckoutModelTests {

    // MARK: - Initial state

    @Test("Initial cart is empty")
    func initialCartEmpty() {
        #expect(CheckoutModel().cart.isEmpty)
    }

    @Test("isEmpty returns true for an empty cart")
    func isEmptyTrueForEmptyCart() {
        #expect(CheckoutModel().isEmpty)
    }

    @Test("isEmpty returns false when cart has items")
    func isEmptyFalseWithItems() {
        let model = CheckoutModel(cart: CartItem.stubs)
        #expect(!model.isEmpty)
    }

    // MARK: - Cart mutations

    @Test("addToCart appends a new product")
    func addToCartAppendsNewProduct() {
        let model = CheckoutModel()
        model.addToCart(.stub)
        #expect(model.cart.count == 1)
        #expect(model.cart[0].product == .stub)
    }

    @Test("addToCart increments quantity for an existing product")
    func addToCartIncrementsExistingProduct() {
        let model = CheckoutModel()
        model.addToCart(.stub)
        model.addToCart(.stub)
        #expect(model.cart.count == 1)
        #expect(model.cart[0].quantity == 2)
    }

    @Test("removeItem removes the matching cart item")
    func removeItemRemovesItem() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let target = model.cart[0]
        model.removeItem(target)
        #expect(!model.cart.contains(where: { $0.id == target.id }))
    }

    @Test("updateQuantity sets the item quantity")
    func updateQuantitySetsQuantity() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let item = model.cart[0]
        model.updateQuantity(for: item, quantity: 5)
        #expect(model.cart.first(where: { $0.id == item.id })?.quantity == 5)
    }

    @Test("updateQuantity with zero removes the item")
    func updateQuantityZeroRemovesItem() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let item = model.cart[0]
        model.updateQuantity(for: item, quantity: 0)
        #expect(!model.cart.contains(where: { $0.id == item.id }))
    }

    @Test("updateQuantity with negative quantity removes the item")
    func updateQuantityNegativeRemovesItem() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let item = model.cart[0]
        model.updateQuantity(for: item, quantity: -1)
        #expect(!model.cart.contains(where: { $0.id == item.id }))
    }

    // MARK: - Computed totals

    @Test("itemCount sums quantities across all cart items")
    func itemCountSumsQuantities() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let expected = CartItem.stubs.reduce(0) { $0 + $1.quantity }
        #expect(model.itemCount == expected)
    }

    @Test("subtotal sums item subtotals")
    func subtotalSumsItems() {
        let model = CheckoutModel(cart: CartItem.stubs)
        let expected = CartItem.stubs.reduce(Decimal(0)) { $0 + $1.subtotal }
        #expect(model.subtotal == expected)
    }

    @Test("guaranteeCost is 9.99 per opted-in item")
    func guaranteeCostPerItem() {
        let model = CheckoutModel()
        let product = CheckoutProduct.stubs[0] // supportsExtendedGuarantee: true
        model.extendedGuaranteeItems = [product.id]
        #expect(model.guaranteeCost == Decimal(9.99))
    }

    @Test("guaranteeCost is zero when no items are opted in")
    func guaranteeCostZeroWhenNoneSelected() {
        #expect(CheckoutModel().guaranteeCost == 0)
    }

    @Test("checkoutTotal is subtotal + deliveryCost + guaranteeCost")
    func checkoutTotalIsCorrect() {
        let model = CheckoutModel(cart: CartItem.stubs)
        model.deliveryOption = .express
        model.extendedGuaranteeItems = [CheckoutProduct.stubs[0].id]
        let expected = model.subtotal + DeliveryOption.express.price + Decimal(9.99)
        #expect(model.checkoutTotal == expected)
    }

    // MARK: - Extended guarantee

    @Test("toggleGuarantee adds a product that is not yet opted in")
    func toggleGuaranteeAdds() {
        let model = CheckoutModel()
        let product = CheckoutProduct.stubs[0]
        model.toggleGuarantee(for: product)
        #expect(model.extendedGuaranteeItems.contains(product.id))
    }

    @Test("toggleGuarantee removes a product that is already opted in")
    func toggleGuaranteeRemoves() {
        let model = CheckoutModel()
        let product = CheckoutProduct.stubs[0]
        model.extendedGuaranteeItems.insert(product.id)
        model.toggleGuarantee(for: product)
        #expect(!model.extendedGuaranteeItems.contains(product.id))
    }

    @Test("hasGuaranteeEligibleItems is true when cart contains eligible products")
    func hasEligibleItemsTrue() {
        let eligible = CartItem(product: CheckoutProduct(name: "Laptop", price: 999, supportsExtendedGuarantee: true))
        let model = CheckoutModel(cart: [eligible])
        #expect(model.hasGuaranteeEligibleItems)
    }

    @Test("hasGuaranteeEligibleItems is false when no eligible products are in cart")
    func hasEligibleItemsFalse() {
        let ineligible = CartItem(product: CheckoutProduct(name: "Chair", price: 200, supportsExtendedGuarantee: false))
        let model = CheckoutModel(cart: [ineligible])
        #expect(!model.hasGuaranteeEligibleItems)
    }

    // MARK: - retryPayment

    @Test("retryPayment resets destination to addressForm")
    func retryPaymentResetsToAddressForm() {
        let model = CheckoutModel()
        model.destination = .paymentFailed(.cardDeclined)
        model.retryPayment()
        #expect(model.destination == .addressForm)
    }
}
