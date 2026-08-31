import Foundation
import Observation
import SwiftUINavigation

@MainActor
@Observable
public final class SuggestionsModel {
    var products: [SuggestedProduct] = []
    var isLoading                    = false
    var destination: Destination?

    /// Lets a caller (in practice, a snapshot test) opt a model out of
    /// SuggestionsView's auto-load entirely — "not loaded yet" and "loaded,
    /// genuinely no products" both look like an empty array from the
    /// outside, so a guard keyed on that state alone can't tell them apart.
    var suppressAutoLoad = false

    /// Called by the composition root to route add-to-cart events to the Checkout module.
    /// Typed on Foundation primitives so the Suggestions module stays independent of Checkout.
    /// Called by the composition root with (id, name, price, wantsExtendedGuarantee).
    public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

    private let repository: SuggestionsRepository

    public init(repository: SuggestionsRepository, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case productDetail(SuggestedProduct)
    }

    func select(_ product: SuggestedProduct) {
        destination = .productDetail(product)
    }

    func addToCart(_ product: SuggestedProduct, wantsGuarantee: Bool = false) {
        onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
    }

    func load(for userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await repository.fetchSuggestions(for: userId)) ?? []
    }
}
