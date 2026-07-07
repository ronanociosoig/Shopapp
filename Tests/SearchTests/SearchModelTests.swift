import Testing
import Foundation
@testable import Search

// MARK: - Stub helpers

private final class FailingSearchRepository: SearchRepositoryProtocol {
    func search(query: String) async throws -> [SearchProduct] { throw URLError(.notConnectedToInternet) }
    func fetchCategories() async throws -> [String] { [] }
    func fetchByCategory(_ category: String) async throws -> [SearchProduct] { [] }
}

// MARK: - Unit Tests

@Suite("SearchModel — Unit Tests")
struct SearchModelTests {

    // MARK: - Initial state

    @Test("Initial searchState is idle")
    func initialStateIsIdle() {
        #expect(SearchModel().searchState == .idle)
    }

    @Test("Initial query is empty")
    func initialQueryIsEmpty() {
        #expect(SearchModel().query == "")
    }

    // MARK: - search()

    @Test("search with blank query resets state to idle")
    @MainActor
    func searchWithBlankQueryReturnsIdle() async {
        let model = SearchModel()
        model.query = "   "
        await model.search()
        #expect(model.searchState == .idle)
    }

    @Test("search with empty string resets state to idle")
    @MainActor
    func searchWithEmptyStringReturnsIdle() async {
        let model = SearchModel()
        model.query = ""
        await model.search()
        #expect(model.searchState == .idle)
    }

    @Test("search produces results state on success")
    @MainActor
    func searchProducesResults() async {
        let model = SearchModel()
        model.query = "macbook"
        await model.search()
        guard case .results(let results) = model.searchState else {
            Issue.record("Expected .results")
            return
        }
        #expect(!results.isEmpty)
    }

    @Test("search produces empty state when no products match")
    @MainActor
    func searchProducesEmpty() async {
        let model = SearchModel(repository: StubSearchRepository(returning: []))
        model.query = "zzznomatch"
        await model.search()
        #expect(model.searchState == .empty)
    }

    @Test("search produces error state when repository throws")
    @MainActor
    func searchProducesError() async {
        let model = SearchModel(repository: FailingSearchRepository())
        model.query = "macbook"
        await model.search()
        guard case .error = model.searchState else {
            Issue.record("Expected .error state")
            return
        }
    }

    // MARK: - Navigation

    @Test("selectProduct sets destination to productDetail")
    func selectProductSetsDestination() {
        let model = SearchModel()
        model.selectProduct(.stub)
        #expect(model.destination == .productDetail(.stub))
    }

    @Test("showFilters sets destination to filters")
    func showFiltersSetsDestination() {
        let model = SearchModel()
        model.showFilters()
        #expect(model.destination == .filters)
    }

    @Test("browseCategory sets destination to categoryBrowse")
    func browseCategorySetsDestination() {
        let model = SearchModel()
        model.browseCategory("Electronics")
        #expect(model.destination == .categoryBrowse("Electronics"))
    }

    // MARK: - addToCart

    @Test("addToCart fires onAddToCart with correct primitives")
    func addToCartFiresCallback() {
        let model = SearchModel()
        var captured: (UUID, String, Decimal, Bool)?
        model.onAddToCart = { id, name, price, wantsGuarantee in
            captured = (id, name, price, wantsGuarantee)
        }
        model.addToCart(.stub, wantsGuarantee: true)
        #expect(captured?.0 == SearchProduct.stub.id)
        #expect(captured?.3 == true)
    }
}
