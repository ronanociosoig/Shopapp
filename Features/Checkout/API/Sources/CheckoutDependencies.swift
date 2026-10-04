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
///
/// `currencyFormatter` doesn't have that problem — `NumberFormatter` is
/// plain Foundation, so its default lives here directly rather than being
/// resolved one layer in.
public struct CheckoutDependencies {
    public let repository: CheckoutRepository
    public let selectedAddressStore: SelectedAddressStore?
    public let currencyFormatter: NumberFormatter

    public init(
        repository: CheckoutRepository,
        selectedAddressStore: SelectedAddressStore? = nil,
        currencyFormatter: NumberFormatter = .checkoutDefault
    ) {
        self.repository = repository
        self.selectedAddressStore = selectedAddressStore
        self.currencyFormatter = currencyFormatter
    }
}

extension NumberFormatter {
    /// Matches `PriceLabel`'s hardcoded `.currency(code: "EUR")` exactly, so
    /// every existing caller that doesn't supply its own formatter keeps
    /// rendering identically to before this existed.
    public static var checkoutDefault: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter
    }
}
