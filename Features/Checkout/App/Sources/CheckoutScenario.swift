import Foundation
import CheckoutTesting
@_spi(Scenarios) import Checkout

/// A catalog of named, realistic states the Checkout micro-app can launch into.
/// Lives directly in the micro-app target, not a separate library — nothing
/// outside `CheckoutApp` ever needs this, so a standalone SPM target would be
/// ceremony with no consumer.
///
/// The scenario *states* below (the `path`/`destination` combinations) are
/// unique to this catalog and stay here — nothing else needs them. But the
/// fake behind them, `StubCheckoutRepository`, isn't scenario-specific: it's
/// the same "successfully place a fake order" logic `CheckoutSnapshotTests`'s
/// own happy-path test already depends on. Reusing it here instead of
/// hand-rolling a second copy is the same rule the other direction — don't
/// duplicate what's genuinely shared, don't share what's genuinely one-off.
///
/// `CaseIterable` so the scenario list (and, later, a structural-coverage test
/// mirroring Article 1's `Destination.allCases` pattern) can enumerate every
/// scenario without anyone having to remember to wire up a new case by hand.
enum CheckoutScenario: String, CaseIterable, Identifiable {
    /// Cart pre-populated, one saved address — the funnel's actual starting point.
    case cart
    /// Cart with nothing in it.
    case emptyCart
    /// Mid-funnel: choosing among several saved addresses.
    case addressSelection
    /// Mid-funnel: delivery option and extended-guarantee toggles, one item opted in.
    case orderOptions
    /// Mid-funnel: choosing how to pay.
    case paymentMethod
    /// Mid-funnel: entering card details.
    case cardEntry
    /// Non-dismissable overlay shown while the order is placed.
    case processing
    /// Order placed successfully.
    case confirmation
    /// Payment was declined; the funnel is still on the card-entry screen underneath.
    case paymentFailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cart:             return "Cart"
        case .emptyCart:        return "Empty Cart"
        case .addressSelection: return "Address Selection"
        case .orderOptions:     return "Delivery & Extras"
        case .paymentMethod:    return "Payment Method"
        case .cardEntry:        return "Card Entry"
        case .processing:       return "Processing"
        case .confirmation:     return "Order Confirmed"
        case .paymentFailed:    return "Payment Failed"
        }
    }
}

/// Builds a `CheckoutModel` already configured for a given `CheckoutScenario`,
/// via `CheckoutModel`'s `@_spi(Scenarios)` init — the only way to reach a
/// mid-funnel `path` from outside the `Checkout` module.
///
/// `@MainActor` because `CheckoutModel` itself is — unlike `SearchModel`, which
/// only isolates its scenario-support init.
@MainActor
struct CheckoutScenarioBuilder {
    func makeModel(for scenario: CheckoutScenario) -> CheckoutModel {
        let repository = StubCheckoutRepository(delay: .zero)
        let addressStore = StubSelectedAddressStore()
        let address = ShippingAddress.stub
        let guaranteeEligibleItem = CartItem.stubs[0].product.id

        switch scenario {
        case .cart:
            return CheckoutModel(
                cart: CartItem.stubs,
                savedAddresses: [address],
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .emptyCart:
            return CheckoutModel(
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .addressSelection:
            return CheckoutModel(
                cart: CartItem.stubs,
                path: [.address],
                savedAddresses: ShippingAddress.stubs,
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .orderOptions:
            return CheckoutModel(
                cart: CartItem.stubs,
                path: [.address, .orderOptions(address)],
                savedAddresses: [address],
                extendedGuaranteeItems: [guaranteeEligibleItem],
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .paymentMethod:
            return CheckoutModel(
                cart: CartItem.stubs,
                path: [.address, .orderOptions(address), .paymentMethod(address)],
                savedAddresses: [address],
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .cardEntry:
            return CheckoutModel(
                cart: CartItem.stubs,
                path: [.address, .orderOptions(address), .paymentMethod(address), .paymentEntry(address)],
                savedAddresses: [address],
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .processing:
            return CheckoutModel(
                cart: CartItem.stubs,
                destination: .processing,
                savedAddresses: [address],
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .confirmation:
            let order = PlacedOrder(
                items: CartItem.stubs.map { OrderLineItem(product: $0.product, quantity: $0.quantity) },
                shippingAddress: address,
                deliveryOption: .standard,
                total: 299.99,
                estimatedDelivery: Date(timeIntervalSinceNow: 5 * 24 * 3600)
            )
            return CheckoutModel(
                destination: .confirmation(order),
                repository: repository,
                selectedAddressStore: addressStore
            )
        case .paymentFailed:
            return CheckoutModel(
                cart: CartItem.stubs,
                path: [.address, .orderOptions(address), .paymentMethod(address), .paymentEntry(address)],
                destination: .paymentFailed(.cardDeclined),
                savedAddresses: [address],
                repository: repository,
                selectedAddressStore: addressStore
            )
        }
    }
}
