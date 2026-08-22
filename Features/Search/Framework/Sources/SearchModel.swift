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

    private let repository: SearchRepository

    public init(repository: SearchRepository, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    /// Constructs a model already in a specific result state, without going through the
    /// real `search()` flow — for scenario/dev-support callers (e.g. a micro-app's scenario
    /// picker) that need a model showing "results loaded" or "search failed" on launch, and
    /// can't reach `search()`/`SearchState` directly since both are internal to this module.
    /// `SearchState` itself stays internal — this is the narrowest surface that closes the gap.
    public convenience init(
        repository: SearchRepository,
        query: String = "",
        results: [SearchProduct]? = nil,
        failureMessage: String? = nil,
        destination: Destination? = nil
    ) {
        self.init(repository: repository, destination: destination)
        self.query = query
        if let failureMessage {
            searchState = .error(failureMessage)
        } else if let results {
            searchState = results.isEmpty ? .empty : .results(results)
        }
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
