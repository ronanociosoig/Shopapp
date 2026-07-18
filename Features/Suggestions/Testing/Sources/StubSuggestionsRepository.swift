import Foundation
import Suggestions

public final class StubSuggestionsRepository: SuggestionsRepositoryProtocol {
    private let products: [SuggestedProduct]

    public init(products: [SuggestedProduct] = SuggestedProduct.stubs) {
        self.products = products
    }

    public func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        products
    }
}
