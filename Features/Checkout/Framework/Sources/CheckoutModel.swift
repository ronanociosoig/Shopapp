import Foundation
import Observation
import SwiftUINavigation
@_exported import CheckoutAPI

// MARK: - Model

/// CheckoutModel drives the full purchase funnel.
///
/// Not the feature's public entry point — that's `DefaultCheckoutFactory`,
/// `Checkout`'s conformance to the `CheckoutFactory` protocol. This type's
/// designated initializer is `@_spi(Internals)`: reachable directly only by
/// `CheckoutTesting` and this module's own tests, both of which have a
/// standing reason to bypass the factory. See ADR-0014.
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

    private let environment: CheckoutEnvironment

    /// Called after a successful order placement with the confirmed order and
    /// the set of product IDs for which the user opted into the extended guarantee.
    /// Wire at the composition root to persist the order in PastPurchases.
    public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)?

    /// The real construction path. Not plain `public`: a consumer outside the
    /// module should go through `CheckoutFeatureFactory`, which is the only
    /// thing that can turn a `CheckoutDependencies` into a rendered screen.
    /// This stays reachable directly — gated, not deleted — for two trusted
    /// callers with a legitimate reason to bypass the factory: `CheckoutTesting`
    /// (needs a stub convenience init with no view attached) and this module's
    /// own composition-root snapshot tests (need to seed `cart`/`path` state a
    /// production consumer never should).
    @_spi(Internals)
    public init(
        cart: [CartItem] = [],
        destination: Destination? = nil,
        dependencies: CheckoutDependencies
    ) {
        self.cart        = cart
        self.destination = destination
        self.environment = CheckoutEnvironment(dependencies: dependencies)
        self.selectedAddressID = environment.selectedAddressStore.loadSelectedID()
    }

    /// Reaches any funnel state directly — including mid-`path` screens the
    /// designated init above has no parameter for — without exposing `path`,
    /// `deliveryOption`, or the funnel's step-advancing methods as ordinary
    /// public API. Gated separately from `@_spi(Internals)` above because it's
    /// a different reason to reach in: unlike `destination` (inert data),
    /// `path` carries sequencing invariants a caller could otherwise violate
    /// (e.g. `.paymentEntry` for an address absent from `savedAddresses`).
    /// Reserved for the one caller — the micro-app's scenario builder — that
    /// has a legitimate reason to teleport into the middle of the funnel.
    @_spi(Scenarios)
    public convenience init(
        cart: [CartItem] = [],
        path: [CheckoutStep] = [],
        destination: Destination? = nil,
        savedAddresses: [ShippingAddress] = [],
        deliveryOption: DeliveryOption = .standard,
        extendedGuaranteeItems: Set<UUID> = [],
        dependencies: CheckoutDependencies
    ) {
        self.init(
            cart: cart,
            destination: destination,
            dependencies: dependencies
        )
        self.path = path
        self.savedAddresses = savedAddresses
        self.deliveryOption = deliveryOption
        self.extendedGuaranteeItems = extendedGuaranteeItems
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
                environment.selectedAddressStore.saveSelectedID(selectedAddressID)
            }
        }
        path.append(.address)
    }

    /// Persists the user's address choice and updates `selectedAddressID`.
    func selectAddress(_ address: ShippingAddress) {
        selectedAddressID = address.id
        environment.selectedAddressStore.saveSelectedID(address.id)
    }

    func submitAddress(_ address: ShippingAddress) {
        path.append(.orderOptions(address))
    }

    /// Shared first step for every deep link that lands past Address: pushes
    /// `.address` then `.orderOptions`, the same way an ordinary user
    /// reaching that step through the funnel would, and returns the
    /// resolved `ShippingAddress`. Returns `nil`, with `path` reset to
    /// empty, when there's nothing to resolve — an empty cart (checked by
    /// each caller first) or no saved address at all.
    private func resolveAddressForFunnelDeepLink() -> ShippingAddress? {
        proceedToAddress()
        guard let address = selectedAddress else {
            path = []
            return nil
        }
        path.append(.orderOptions(address))
        return address
    }

    /// Deep-link entry point for "Delivery & Extras" — the one funnel step
    /// that needs more than an id from a URL: a real `ShippingAddress`.
    /// Resolves one the same way `proceedToAddress()` already does for an
    /// ordinary user (the saved default, falling back to the first saved
    /// address, or whatever's already selected), then pushes exactly the
    /// path a real user submitting that address would have produced — Back
    /// still lands on Address. Refuses, leaving `path` untouched, when
    /// there's nothing to resolve: an empty cart, or no saved address at
    /// all. The caller decides what refusal means for navigation; this only
    /// reports whether it could be satisfied.
    @discardableResult
    func handleDeepLinkToDeliveryOptions() -> Bool {
        guard !isEmpty else { return false }
        return resolveAddressForFunnelDeepLink() != nil
    }

    /// Deep-link entry point for "select a new payment method" — the case
    /// where a payment problem is detected later than the ordinary
    /// synchronous decline `submitPayment` already handles (a delayed
    /// authorization check, a bank's own fraud review), after the customer
    /// has left the payment step entirely. Rather than surface the
    /// `paymentFailed` sheet over whatever screen they're on now — which
    /// would reset them to Address on retry, right for a decline discovered
    /// *during* submission, wrong for one discovered well after it — this
    /// takes them straight back to Payment Method, skipping Address and
    /// Delivery & Extras since neither needs re-confirming just to pick a
    /// different card. Refuses, leaving `path` untouched, when there's
    /// nothing to retry: an empty cart, or no saved address.
    @discardableResult
    func handleDeepLinkToPaymentRetry() -> Bool {
        guard !isEmpty else { return false }
        guard let address = resolveAddressForFunnelDeepLink() else { return false }
        path.append(.paymentMethod(address))
        return true
    }

    /// Decodes and acts on everything past `shopapp://checkout/` —
    /// `AppModel` has already matched the host and hands the whole `URL`
    /// across unexamined. This is the one place that knows "delivery",
    /// "payment-retry", and "add" are the path segments Checkout's deep
    /// links use; adding, renaming, or removing one touches only this
    /// method. Returns `false` for a path segment this module doesn't
    /// recognize, or a recognized one with a malformed/missing argument —
    /// the composition root only needs to tell "don't switch to the Cart
    /// tab" apart from everything else, not *why*. A recognized funnel step
    /// that then refuses for its own reasons (empty cart, no saved address)
    /// still returns `true` here — `handleDeepLinkToDeliveryOptions()` and
    /// `handleDeepLinkToPaymentRetry()` already decide what refusal means
    /// for `path`; this only reports whether the URL was ours to handle.
    @discardableResult
    func handleDeepLink(url: URL) -> Bool {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch pathComponents.first {
        case "delivery":
            handleDeepLinkToDeliveryOptions()
            return true

        case "payment-retry":
            handleDeepLinkToPaymentRetry()
            return true

        // "add" has no id to look up against a catalog Checkout doesn't
        // own — the URL carries the full product record, the same
        // (id, name, price, wantsGuarantee) shape every other add-to-cart
        // caller (Store, Search, Suggestions) already passes through
        // `addToCart(id:name:price:wantsGuarantee:)` below. A marketing
        // email's "Add" button is just a new caller of that existing port.
        case "add":
            guard
                let idString = pathComponents.dropFirst().first,
                let id = UUID(uuidString: idString),
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                let name = queryItems.first(where: { $0.name == "name" })?.value,
                let priceString = queryItems.first(where: { $0.name == "price" })?.value,
                let price = Decimal(string: priceString)
            else { return false }
            let wantsGuarantee = queryItems.first(where: { $0.name == "guarantee" })?.value == "true"
            addToCart(id: id, name: name, price: price, wantsGuarantee: wantsGuarantee)
            return true

        default:
            return false
        }
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
            let order = try await environment.repository.placeOrder(
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

    /// Clears any modal `destination`, revealing whatever screen sits
    /// underneath. Scenario-only: a real user reaches a dismissable state
    /// through the funnel's own actions (`retryPayment()`, a confirmation's
    /// "Continue Shopping") — never by having a destination cleared out from
    /// under them. Exists for one case: the micro-app's `.processing`
    /// scenario. In production, `.processing`'s sheet is deliberately
    /// non-dismissable (`interactiveDismissDisabled()`) because it always
    /// resolves on its own once `submitPayment`'s network call returns; the
    /// scenario sets `destination = .processing` directly, with no request
    /// in flight to ever resolve it, so nothing would otherwise get it out
    /// of that state short of restarting the micro-app.
    @_spi(Scenarios)
    public func clearDestination() {
        destination = nil
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

    /// Foundation-primitive-typed overload for ADR-0003's cross-feature
    /// callback convention and the `checkout/add/<id>` deep link — both
    /// build a `CheckoutProduct` from the same four primitives rather than
    /// requiring a caller outside this module to construct one directly.
    func addToCart(id: UUID, name: String, price: Decimal, wantsGuarantee: Bool) {
        addToCart(CheckoutProduct(id: id, name: name, price: price, supportsExtendedGuarantee: wantsGuarantee))
        if wantsGuarantee { extendedGuaranteeItems.insert(id) }
    }
}
