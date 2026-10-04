import SwiftUI
import CheckoutAPI

/// Module-scoped SwiftUI Environment value — set once by `DefaultCheckoutFactory`
/// at the top of `Checkout`'s own view tree, read directly by any view nested
/// arbitrarily deep inside the module. Never marked `public`: promoting this to
/// a shared key any module could read or set would be the same mistake as a
/// global `AppDependencies` environment value, wearing `.environment()` instead
/// of a constructor parameter. See "Being Environmentally Friendly" in Article 3.
private struct CheckoutCurrencyFormatterKey: EnvironmentKey {
    static let defaultValue: NumberFormatter = .checkoutDefault
}

extension EnvironmentValues {
    var checkoutCurrencyFormatter: NumberFormatter {
        get { self[CheckoutCurrencyFormatterKey.self] }
        set { self[CheckoutCurrencyFormatterKey.self] = newValue }
    }
}
