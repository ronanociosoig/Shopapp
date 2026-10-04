import SwiftUI
import CheckoutAPI

/// `Checkout`'s only conformance to `CheckoutFactory` — and, for an ordinary
/// `import Checkout`, effectively the only type worth building anything
/// against. `CheckoutModel` and `CheckoutView`'s designated initializer stay
/// reachable — gated, not deleted — but a well-behaved consumer never needs
/// to construct either directly: this is where "build the real thing" and
/// "keep talking to it" both live.
///
/// It's deliberately not a one-shot function. The composition root doesn't
/// just render Checkout once — it wires cross-feature callbacks
/// (`addToCart`, `onOrderPlaced`) and keeps them live for the app's whole
/// lifetime, the same way `AppModel` already does for every other feature
/// (see `ADR-0003`). So this type is retained, and it doubles as the narrow,
/// Foundation-primitive-typed port for that ongoing traffic — nobody outside
/// `Checkout` ever needs to hold a `CheckoutModel` to do it.
@MainActor
public final class DefaultCheckoutFactory: CheckoutFactory {
    private let checkoutModel: CheckoutModel
    private let currencyFormatter: NumberFormatter

    public init(dependencies: CheckoutDependencies) {
        self.checkoutModel = CheckoutModel(dependencies: dependencies)
        self.currencyFormatter = dependencies.currencyFormatter
    }

    // MARK: - Building the screen

    /// Satisfies `CheckoutFactory`'s requirement — no promotion content.
    public func makeCheckout() -> some View {
        makeCheckout { EmptyView() }
    }

    /// The fuller version `CheckoutFactory` itself can't require (a per-call
    /// generic parameter isn't expressible as an associated type). Every
    /// real caller today — `RootView`, `PromotionsApp` — uses this one
    /// directly, on the concrete type, not through the protocol.
    public func makeCheckout<PromotionBanner: View>(
        @ViewBuilder promotionBanner: @escaping () -> PromotionBanner
    ) -> some View {
        CheckoutView(model: checkoutModel, promotionBanner: promotionBanner)
            .environment(\.checkoutCurrencyFormatter, currencyFormatter)
    }

    // MARK: - Cross-feature port

    public var itemCount: Int { checkoutModel.itemCount }

    public func addToCart(id: UUID, name: String, price: Decimal, wantsGuarantee: Bool) {
        let product = CheckoutProduct(
            id: id, name: name, price: price, supportsExtendedGuarantee: wantsGuarantee
        )
        checkoutModel.addToCart(product)
        if wantsGuarantee { checkoutModel.extendedGuaranteeItems.insert(id) }
    }

    public func setSavedAddresses(_ addresses: [ShippingAddress]) {
        checkoutModel.savedAddresses = addresses
    }

    public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)? {
        get { checkoutModel.onOrderPlaced }
        set { checkoutModel.onOrderPlaced = newValue }
    }

    // MARK: - Escape hatch

    /// Cross-module equivalent of `@testable import` for a type this module
    /// doesn't declare: composition-root snapshot tests need to seed `cart`,
    /// `path`, and `destination` directly, the same deep access `CheckoutTests`
    /// gets for free inside its own module. `@_spi(Internals)` restricts that
    /// to callers who opt in explicitly — see `RootSnapshotTests`. Not part
    /// of `CheckoutFactory`: it's a trusted-caller-only hole, not part of the
    /// feature's contract.
    @_spi(Internals)
    public var model: CheckoutModel { checkoutModel }
}
