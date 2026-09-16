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

    var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)? { get set }
}
