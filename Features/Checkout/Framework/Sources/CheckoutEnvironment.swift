import CheckoutAPI

/// The feature's internal dependency vocabulary — what `CheckoutModel`
/// actually holds and calls, as opposed to what a consumer supplies.
///
/// An implementation detail, not a contract: it never appears in a public
/// signature and nothing outside `Checkout` ever names it. It exists so
/// `CheckoutModel` has one collaborator-bundle property instead of one
/// stored `let` per dependency, and so resolving `CheckoutDependencies`'
/// optional `selectedAddressStore` to its concrete default happens in one
/// place, next to the concrete type it defaults to.
struct CheckoutEnvironment {
    let repository: CheckoutRepository
    let selectedAddressStore: SelectedAddressStore

    init(dependencies: CheckoutDependencies) {
        self.repository = dependencies.repository
        self.selectedAddressStore = dependencies.selectedAddressStore ?? UserDefaultsSelectedAddressStore()
    }
}
