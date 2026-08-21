import Foundation
import Observation
import SwiftUINavigation

// MARK: - Model

/// CheckoutModel drives the full purchase funnel.
///
/// Navigation is split across two properties, each modelling a distinct concern:
///
/// - `path` — the `NavigationStack` path for the sequential funnel screens.
///   Each step is pushed on top of the previous, giving the user full back
///   navigation through the funnel. A `[CheckoutStep]` array naturally expresses
///   sequence; boolean flags cannot.
///
/// - `destination` — modal surfaces (processing overlay, confirmation,
///   payment failed) that sit outside the back-navigable stack. These are not
///   part of the funnel sequence and are never back-navigated to.
///
/// Having two navigation properties on one model is intentional — the goal is
/// one type per navigation concern, not one type per model.
///
/// Any screen in the funnel is reachable in tests by setting state directly:
///
///     // Snapshot the order options screen:
///     let model = CheckoutModel(cart: CartItem.stubs)
///     model.savedAddresses = [.stub]
///     model.path = [.address, .orderOptions(.stub)]
///     assertSnapshot(of: CheckoutView(model: model), as: .image(on: .iPhone13Pro))
///
@MainActor
@Observable
public final class CheckoutModel {
    var cart: [CartItem]
    var path: [CheckoutStep] = []
    var destination: Destination?
    public var savedAddresses: [ShippingAddress] = []
    var deliveryOption: DeliveryOption = .standard
    /// Product IDs (not cart-item IDs) for which the user has opted into the extended guarantee.
    public var extendedGuaranteeItems: Set<UUID> = []
    /// The UUID of the shipping address the user last selected, persisted across launches.
    var selectedAddressID: UUID?

    private let repository: CheckoutRepository
    private let selectedAddressStore: SelectedAddressStoreProtocol

    /// Called after a successful order placement with the confirmed order and
    /// the set of product IDs for which the user opted into the extended guarantee.
    /// Wire at the composition root to persist the order in PastPurchases.
    public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)?

    public init(
        cart: [CartItem] = [],
        destination: Destination? = nil,
        repository: CheckoutRepository,
        selectedAddressStore: SelectedAddressStoreProtocol = UserDefaultsSelectedAddressStore()
    ) {
        self.cart                 = cart
        self.destination          = destination
        self.repository           = repository
        self.selectedAddressStore = selectedAddressStore
        self.selectedAddressID    = selectedAddressStore.loadSelectedID()
    }

    // MARK: - Computed

    /// The `ShippingAddress` that matches `selectedAddressID`, or `nil` if none.
    var selectedAddress: ShippingAddress? {
        guard let id = selectedAddressID else { return nil }
        return savedAddresses.first(where: { $0.id == id })
    }

    var subtotal: Decimal {
        cart.reduce(0) { $0 + $1.subtotal }
    }

    public var itemCount: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    var isEmpty: Bool { cart.isEmpty }

    /// Cost of all opted-in extended guarantees (€9.99 per eligible item line).
    var guaranteeCost: Decimal {
        Decimal(extendedGuaranteeItems.count) * 9.99
    }

    /// Grand total shown to the user and charged at payment.
    var checkoutTotal: Decimal {
        subtotal + deliveryOption.price + guaranteeCost
    }

    /// True when at least one cart item is eligible for an extended guarantee.
    var hasGuaranteeEligibleItems: Bool {
        cart.contains { $0.product.supportsExtendedGuarantee }
    }

    // MARK: - Destination

    /// Modal surfaces that sit outside the sequential funnel stack.
    ///
    /// - `processing` — non-dismissable overlay shown during the API call.
    /// - `confirmation` — full-screen cover shown on successful order placement.
    /// - `paymentFailed` — sheet shown on failure, allowing retry or cancel.
    @CasePathable
    public enum Destination: Equatable, Sendable {
        case processing
        case confirmation(PlacedOrder)
        case paymentFailed(PaymentError)
    }

    // MARK: - Actions

    func proceedToAddress() {
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
        path.append(.address)
    }

    /// Persists the user's address choice and updates `selectedAddressID`.
    func selectAddress(_ address: ShippingAddress) {
        selectedAddressID = address.id
        selectedAddressStore.saveSelectedID(address.id)
    }

    func submitAddress(_ address: ShippingAddress) {
        path.append(.orderOptions(address))
    }

    func proceedToPaymentMethod(address: ShippingAddress) {
        path.append(.paymentMethod(address))
    }

    func toggleGuarantee(for product: CheckoutProduct) {
        if extendedGuaranteeItems.contains(product.id) {
            extendedGuaranteeItems.remove(product.id)
        } else {
            extendedGuaranteeItems.insert(product.id)
        }
    }

    func selectPaymentMethod(_ method: PaymentMethod, address: ShippingAddress) {
        if method == .creditCard {
            path.append(.paymentEntry(address))
        } else {
            Task { await submitPayment(address: address, cardToken: method.stubToken) }
        }
    }

    func submitPayment(address: ShippingAddress, cardToken: String) async {
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
            // Clear cart and funnel state now that the order is confirmed.
            cart = []
            extendedGuaranteeItems = []
            deliveryOption = .standard
            path = []
            destination = .confirmation(order)
        } catch let error as PaymentError {
            destination = .paymentFailed(error)
        } catch {
            destination = .paymentFailed(.unknown)
        }
    }

    func retryPayment() {
        destination = nil
        path = [.address]
    }

    func updateQuantity(for item: CartItem, quantity: Int) {
        guard let index = cart.firstIndex(where: { $0.id == item.id }) else { return }
        if quantity <= 0 {
            cart.remove(at: index)
        } else {
            cart[index].quantity = quantity
        }
    }

    func removeItem(_ item: CartItem) {
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
