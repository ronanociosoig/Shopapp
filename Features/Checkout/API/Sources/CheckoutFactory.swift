import SwiftUI

/// The Checkout feature's complete public contract: the one thing an ordinary
/// consumer is meant to build anything against, and the narrow, long-lived
/// handle it keeps for cross-feature wiring after construction.
///
/// `makeCheckout` binds to an `associatedtype`, not a bare `some View` —
/// Swift doesn't allow an opaque return type directly on a protocol
/// requirement, only on a concrete implementation's own declaration
/// (the same reason `View` itself is `associatedtype Body: View; var body:
/// Body { get }` rather than `var body: some View { get }`). A conforming
/// type still implements it with `some View` — Swift infers the associated
/// type from that — and never needs `AnyView` to satisfy the requirement.
///
/// The requirement deliberately takes no parameters: a per-call generic
/// parameter (letting a caller embed a custom promotion banner) can't be
/// expressed as a single associated type, since an associated type is fixed
/// per conformance, not per call. A conforming type that wants that
/// flexibility — `DefaultCheckoutFactory` does — offers it as an additional
/// method beyond this protocol; a consumer that only holds `CheckoutFactory`
/// gets the plain screen, and a consumer holding the concrete type gets both.
///
/// This is the reason `CheckoutFactory` lives in `CheckoutAPI` at all,
/// despite `CheckoutAPI` otherwise having no dependency beyond Foundation:
/// the protocol only needs `SwiftUI`'s `View`, never `Checkout`'s concrete
/// `CheckoutModel`/`CheckoutView` — those stay exactly where they always
/// were, known only to whatever conforms.
@MainActor
public protocol CheckoutFactory {
    associatedtype CheckoutContent: View

    /// Builds the real, currently-configured screen, with no promotion
    /// content embedded.
    func makeCheckout() -> CheckoutContent

    // MARK: - Cross-feature port
    //
    // Same Foundation-primitive-callback convention ADR-0003 already uses
    // for Store/Search calling into Checkout, applied symmetrically so a
    // caller holding this protocol never needs to see a CheckoutModel.

    var itemCount: Int { get }

    func addToCart(id: UUID, name: String, price: Decimal, wantsGuarantee: Bool)

    func setSavedAddresses(_ addresses: [ShippingAddress])

    /// Decodes and acts on everything past `shopapp://checkout/` — which
    /// path segment names a screen or action, and whatever query items it
    /// needs. The composition root has matched the host; it has no idea
    /// which path segments Checkout's deep links use, and adding, renaming,
    /// or removing one never touches anything outside this module. Returns
    /// `false` for a path segment this module doesn't recognize, or a
    /// recognized one with a malformed/missing argument — those are the
    /// only two outcomes the composition root needs to tell apart, since
    /// both mean "don't switch to the Cart tab, nothing happened."
    @discardableResult
    func handleDeepLink(url: URL) -> Bool

    var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)? { get set }
}
