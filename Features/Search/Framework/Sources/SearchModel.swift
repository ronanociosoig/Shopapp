import Foundation
import Observation
import SwiftUINavigation

// MARK: - State

public enum SearchState: Equatable {
    case idle
    case loading
    case results([SearchProduct])
    case empty
    case error(String)
}

// MARK: - Model

/// SearchModel drives the Search feature.
///
/// All navigation destinations are expressed as a single enum,
/// making every state injectable in tests without launching a simulator:
///
///     let model = SearchModel()
///     model.destination = .productDetail(.stub)
///     assertSnapshot(of: SearchView(model: model), as: .image(on: .iPhone13Pro))
///
@Observable
public final class SearchModel {
    public var query: String = ""
    public var searchState: SearchState = .idle
    public var destination: Destination?

    /// Called by the composition root to route add-to-cart events to the Checkout module.
    /// Typed on Foundation primitives so the Search module stays independent of Checkout.
    /// Called by the composition root with (id, name, price, wantsExtendedGuarantee).
    public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

    private let repository: SearchRepositoryProtocol

    public init(repository: SearchRepositoryProtocol) {
        self.repository = repository
    }

    @CasePathable
    public enum Destination: Equatable {
        case productDetail(SearchProduct)
        case filters
        case categoryBrowse(String)
    }

    @MainActor
    public func search() async {
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

    public func selectProduct(_ product: SearchProduct) { destination = .productDetail(product) }
    public func showFilters()                           { destination = .filters }
    public func browseCategory(_ category: String)      { destination = .categoryBrowse(category) }

    public func addToCart(_ product: SearchProduct, wantsGuarantee: Bool = false) {
        onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
    }
}
