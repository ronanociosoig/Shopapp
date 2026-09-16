import Foundation

/// The public contract for constructing the Checkout feature: everything a
/// consumer must supply to a `CheckoutFactory` conformance, and nothing
/// about how the feature uses it internally.
///
/// `selectedAddressStore` defaults to `nil`, not a concrete instance.
/// `CheckoutAPI` has no dependencies beyond Foundation, so it cannot name
/// `UserDefaultsSelectedAddressStore` — that concrete type lives in
/// `Checkout`. `CheckoutEnvironment` resolves the default one layer in,
/// where the concrete type is actually visible.
public struct CheckoutDependencies {
    public let repository: CheckoutRepository
    public let selectedAddressStore: SelectedAddressStore?

    public init(
        repository: CheckoutRepository,
        selectedAddressStore: SelectedAddressStore? = nil
    ) {
        self.repository = repository
        self.selectedAddressStore = selectedAddressStore
    }
}
