import Search

/// A catalog of named, realistic states the Search micro-app can launch into —
/// the scenario/dev-support tier, distinct from both `Search`'s production API
/// (what the composition root needs) and `SearchTesting`'s test-support API
/// (what unit/snapshot tests need). Deliberately depends only on `Search`, not
/// `SearchTesting`: conflating "what a test needs" with "what a demo needs" is
/// the problem this tier exists to avoid, not repeat.
///
/// `CaseIterable` so a scenario picker (or, later, a structural-coverage test
/// mirroring Article 1's `Destination.allCases` pattern) can enumerate every
/// scenario without anyone having to remember to wire up a new case by hand.
public enum SearchScenario: String, CaseIterable, Identifiable {
    /// Today's real default: no query yet, nothing loaded.
    case launch
    /// A query that returned several real results.
    case resultsLoaded
    /// A query that matched nothing.
    case noResults
    /// A query that failed — network or decoding error.
    case searchFailed
    /// Launches straight into a product's detail screen.
    case productDetail
    /// Launches straight into the filters sheet.
    case filtersOpen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .launch:        return "Launch (empty)"
        case .resultsLoaded: return "Results Loaded"
        case .noResults:     return "No Results"
        case .searchFailed:  return "Search Failed"
        case .productDetail: return "Product Detail"
        case .filtersOpen:   return "Filters Open"
        }
    }
}

/// Builds a `SearchModel` already configured for a given `SearchScenario`.
public struct SearchScenarioBuilder {
    public init() {}

    public func makeModel(for scenario: SearchScenario) -> SearchModel {
        let repository = ScenarioSearchRepository()
        switch scenario {
        case .launch:
            return SearchModel(repository: repository)
        case .resultsLoaded:
            return SearchModel(
                repository: repository,
                query: "MacBook",
                results: Array(SearchProduct.stubs.prefix(6))
            )
        case .noResults:
            return SearchModel(
                repository: repository,
                query: "xyzzy",
                results: []
            )
        case .searchFailed:
            return SearchModel(
                repository: repository,
                query: "MacBook",
                failureMessage: "The request timed out."
            )
        case .productDetail:
            return SearchModel(
                repository: repository,
                destination: .productDetail(.stub)
            )
        case .filtersOpen:
            return SearchModel(
                repository: repository,
                destination: .filters
            )
        }
    }
}

/// A minimal fake conforming to `SearchRepository`, present only so
/// `SearchModel`'s designated initializer has something to hold — none of
/// its methods are expected to be called from a scenario-built model, since
/// scenario state is set directly at construction, not reached by triggering
/// a real search. Throws if a scenario's own wiring is ever wrong and one of
/// these does get called, rather than silently returning fake data.
struct ScenarioSearchRepository: SearchRepository {
    struct Unexpected: Error {}
    func search(query: String) async throws -> [SearchProduct] { throw Unexpected() }
    func fetchCategories() async throws -> [String] { throw Unexpected() }
    func fetchByCategory(_ category: String) async throws -> [SearchProduct] { throw Unexpected() }
}
