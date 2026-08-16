import Foundation
import Observation
import SwiftUINavigation

// MARK: - State

enum SearchState: Equatable {
    case idle
    case loading
    case results([SearchProduct])
    case empty
    case error(String)
}

// MARK: - Model

@Observable
public final class SearchModel {
    var query: String = ""
    var searchState: SearchState = .idle
    var destination: Destination?

    /// Called by the composition root to route add-to-cart events to the Checkout module.
    /// Typed on Foundation primitives so the Search module stays independent of Checkout.
    /// Called by the composition root with (id, name, price, wantsExtendedGuarantee).
    public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

    private let repository: SearchRepositoryProtocol

    public init(repository: SearchRepositoryProtocol, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case productDetail(SearchProduct)
        case filters
        case categoryBrowse(String)
    }

    @MainActor
    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchState = .idle
            return
        }
        searchState = .loading
        do {
            let results = try await repository.search(query: query)
            searchState = results.isEmpty ? .empty : .results(results)
        } catch {
            searchState = .error(error.localizedDescription)
        }
    }

    func selectProduct(_ product: SearchProduct) { destination = .productDetail(product) }
    func showFilters()                           { destination = .filters }
    func browseCategory(_ category: String)      { destination = .categoryBrowse(category) }

    func addToCart(_ product: SearchProduct, wantsGuarantee: Bool = false) {
        onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
    }
}
