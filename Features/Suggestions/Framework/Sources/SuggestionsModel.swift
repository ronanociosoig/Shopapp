import Foundation
import Observation
import SwiftUINavigation

@Observable
public final class SuggestionsModel {
    var products: [SuggestedProduct] = []
    var isLoading                    = false
    var destination: Destination?

    /// Called by the composition root to route add-to-cart events to the Checkout module.
    /// Typed on Foundation primitives so the Suggestions module stays independent of Checkout.
    /// Called by the composition root with (id, name, price, wantsExtendedGuarantee).
    public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

    private let repository: SuggestionsRepositoryProtocol

    public init(repository: SuggestionsRepositoryProtocol, destination: Destination? = nil) {
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

    @MainActor
    func load(for userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await repository.fetchSuggestions(for: userId)) ?? []
    }
}
