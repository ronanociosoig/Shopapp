#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Search
import SearchTesting

// MARK: - CaseIterable conformances

extension SearchModel.Destination: CaseIterable {
    public static var allCases: [SearchModel.Destination] {
        [
            .productDetail(.stub),
            .filters,
            .categoryBrowse("Electronics")
        ]
    }
}

extension SearchState: CaseIterable {
    public static var allCases: [SearchState] {
        [
            .idle,
            .loading,
            .results(.stubs),
            .empty,
            .error("Something went wrong. Please try again.")
        ]
    }
}

// MARK: - Snapshot Tests

@Suite("Search — Snapshot Tests")
@MainActor
struct SearchSnapshotTests {

    @Test(
        "Root view renders correctly in every search state",
        arguments: SearchState.allCases
    )
    func rootViewState(state: SearchState) async throws {
        let model = SearchModel()
        model.searchState = state

        assertSnapshot(
            of: SearchView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(state)
        )
    }

    @Test("Results view renders correctly when a query is active")
    func resultsWithActiveQuery() async throws {
        let model = SearchModel()
        model.query = "MacBook"
        model.searchState = .results(SearchProduct.stubs)
        assertSnapshot(
            of: SearchView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_results_with_query"
        )
    }

    @Test("Empty state renders correctly when a query yields no results")
    func emptyWithActiveQuery() async throws {
        let model = SearchModel()
        model.query = "ZZZ"
        model.searchState = .empty
        assertSnapshot(
            of: SearchView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_empty_with_query"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: SearchModel.Destination.allCases
    )
    func destination(_ destination: SearchModel.Destination) async throws {
        let model = SearchModel()
        model.query = "MacBook"
        model.searchState = .results(.stubs)
        model.destination = destination

        assertSnapshot(
            of: SearchView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: SearchModel.Destination) -> String {
    switch destination {
    case .productDetail:           return "destination_product_detail"
    case .filters:                 return "destination_filters"
    case .categoryBrowse(let cat): return "destination_category_\(cat.lowercased())"
    }
}

private func snapshotName(_ state: SearchState) -> String {
    switch state {
    case .idle:    return "state_idle"
    case .loading: return "state_loading"
    case .results: return "state_results"
    case .empty:   return "state_empty"
    case .error:   return "state_error"
    }
}
#endif
