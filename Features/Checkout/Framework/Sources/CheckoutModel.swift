import Foundation
import Observation
import SwiftUINavigation

// MARK: - Model

/// CheckoutModel drives the full purchase funnel.
///
/// All six reachable UI states are expressed as a single `Destination` enum.
/// This makes every screen injectable in tests without scripting UI interactions:
///
///     // Snapshot the confirmation screen in one line:
///     let model = CheckoutModel(cart: CartItem.stubs)
///     model.destination = .confirmation(.stub)
///     assertSnapshot(of: CheckoutView(model: model), as: .image(on: .iPhone13Pro))
///
/// Adding a new `Destination` case without updating `CaseIterable.allCases`
/// in the test target is a compile error — coverage is structural, not optional.
///
@Observable
public final class CheckoutModel {
    public var cart: [CartItem]
    public var destination: Destination?
    public var savedAddresses: [ShippingAddress] = []
    public var deliveryOption: DeliveryOption = .standard
    /// Product IDs (not cart-item IDs) for which the user has opted into the extended guarantee.
    public var extendedGuaranteeItems: Set<UUID> = []
    /// The UUID of the shipping address the user last selected, persisted across launches.
    public var selectedAddressID: UUID?

    private let repository: CheckoutRepositoryProtocol
    private let selectedAddressStore: SelectedAddressStoreProtocol

    /// Called after a successful order placement with the confirmed order and
    /// the set of product IDs for which the user opted into the extended guarantee.
    /// Wire at the composition root to persist the order in PastPurchases.
    public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)?

    public init(
        cart: [CartItem] = [],
        repository: CheckoutRepositoryProtocol = StubCheckoutRepository(),
        selectedAddressStore: SelectedAddressStoreProtocol = UserDefaultsSelectedAddressStore()
    ) {
        self.cart                 = cart
        self.repository           = repository
        self.selectedAddressStore = selectedAddressStore
        self.selectedAddressID    = selectedAddressStore.loadSelectedID()
    }

    // MARK: - Computed

    /// The `ShippingAddress` that matches `selectedAddressID`, or `nil` if none.
    public var selectedAddress: ShippingAddress? {
        guard let id = selectedAddressID else { return nil }
        return savedAddresses.first(where: { $0.id == id })
    }

    public var subtotal: Decimal {
        cart.reduce(0) { $0 + $1.subtotal }
    }

    public var itemCount: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    public var isEmpty: Bool { cart.isEmpty }

    /// Cost of all opted-in extended guarantees (€9.99 per eligible item line).
    public var guaranteeCost: Decimal {
        Decimal(extendedGuaranteeItems.count) * 9.99
    }

    /// Grand total shown to the user and charged at payment.
    public var checkoutTotal: Decimal {
        subtotal + deliveryOption.price + guaranteeCost
    }

    /// True when at least one cart item is eligible for an extended guarantee.
    public var hasGuaranteeEligibleItems: Bool {
        cart.contains { $0.product.supportsExtendedGuarantee }
    }

    // MARK: - Destination

    /// The complete set of UI states in the checkout funnel.
    ///
    /// - `cart` is the root view; `destination` is `nil` when showing the cart.
    /// - `addressForm` and `paymentEntry` are pushed onto the NavigationStack.
    /// - `processing` is a non-dismissable sheet shown during the API call.
    /// - `confirmation` is a full-screen cover shown on success.
    /// - `paymentFailed` is a sheet shown on failure, allowing the user to retry.
    @CasePathable
    public enum Destination: Equatable {
        case addressForm
        case orderOptions(ShippingAddress)
        case paymentMethodSelection(ShippingAddress)
        case paymentEntry(ShippingAddress)
        case processing
        case confirmation(PlacedOrder)
        case paymentFailed(PaymentError)
    }

    // MARK: - Actions

    public func proceedToAddress() {
        // If there are saved addresses and the stored selection is missing or stale,
        // fall back to the default address (or the first one if none is marked default).
        if !savedAddresses.isEmpty {
            let isValid = selectedAddressID.map { id in
                savedAddresses.contains(where: { $0.id == id })
            } ?? false
            if !isValid {
                let autoSelected = savedAddresses.first(where: { $0.isDefault }) ?? savedAddresses.first
                selectedAddressID = autoSelected?.id
                selectedAddressStore.saveSelectedID(selectedAddressID)
            }
        }
        destination = .addressForm
    }

    /// Persists the user's address choice and updates `selectedAddressID`.
    public func selectAddress(_ address: ShippingAddress) {
        selectedAddressID = address.id
        selectedAddressStore.saveSelectedID(address.id)
    }

    public func submitAddress(_ address: ShippingAddress) {
        destination = .orderOptions(address)
    }

    public func proceedToPaymentMethod(address: ShippingAddress) {
        destination = .paymentMethodSelection(address)
    }

    public func toggleGuarantee(for product: CheckoutProduct) {
        if extendedGuaranteeItems.contains(product.id) {
            extendedGuaranteeItems.remove(product.id)
        } else {
            extendedGuaranteeItems.insert(product.id)
        }
    }

    public func selectPaymentMethod(_ method: PaymentMethod, address: ShippingAddress) {
        if method == .creditCard {
            destination = .paymentEntry(address)
        } else {
            Task { await submitPayment(address: address, cardToken: method.stubToken) }
        }
    }

    public func submitPayment(address: ShippingAddress, cardToken: String) async {
        destination = .processing
        do {
            let order = try await repository.placeOrder(
                items: cart,
                address: address,
                cardToken: cardToken,
                deliveryOption: deliveryOption,
                guaranteeCost: guaranteeCost
            )
            // Notify the composition root so it can persist the order.
            onOrderPlaced?(order, extendedGuaranteeItems)
            // Clear the cart now that the order is confirmed.
            cart = []
            extendedGuaranteeItems = []
            deliveryOption = .standard
            destination = .confirmation(order)
        } catch let error as PaymentError {
            destination = .paymentFailed(error)
        } catch {
            destination = .paymentFailed(.unknown)
        }
    }

    public func retryPayment() {
        // Pop back to address form to let the user try a different card
        destination = .addressForm
    }

    public func updateQuantity(for item: CartItem, quantity: Int) {
        guard let index = cart.firstIndex(where: { $0.id == item.id }) else { return }
        if quantity <= 0 {
            cart.remove(at: index)
        } else {
            cart[index].quantity = quantity
        }
    }

    public func removeItem(_ item: CartItem) {
        cart.removeAll { $0.id == item.id }
    }

    /// Adds a product to the cart, or increments its quantity if already present.
    public func addToCart(_ product: CheckoutProduct) {
        if let index = cart.firstIndex(where: { $0.product.id == product.id }) {
            cart[index].quantity += 1
        } else {
            cart.append(CartItem(product: product))
        }
    }
}
