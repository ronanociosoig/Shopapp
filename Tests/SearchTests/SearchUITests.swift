import Testing
import Foundation
@testable import Search

/// Tests that exercise complete user interaction flows through the Search module.
@Suite("Search — UI Interaction Tests")
@MainActor
struct SearchUITests {

    @Test("User types a query and gets results")
    func userSearchesAndGetsResults() async {
        let model = SearchModel()
        #expect(model.searchState == .idle)

        model.query = "macbook"
        await model.search()

        guard case .results(let products) = model.searchState else {
            Issue.record("Expected search results")
            return
        }
        #expect(!products.isEmpty)
    }

    @Test("User clears query and state returns to idle")
    func userClearsQuery() async {
        let model = SearchModel()
        model.query = "macbook"
        await model.search()

        model.query = ""
        await model.search()
        #expect(model.searchState == .idle)
    }

    @Test("User selects a product from results")
    func userSelectsProduct() async {
        let model = SearchModel()
        model.query = "macbook"
        await model.search()

        guard case .results(let products) = model.searchState, let first = products.first else {
            Issue.record("Expected results to select from")
            return
        }
        model.selectProduct(first)
        #expect(model.destination == .productDetail(first))
    }

    @Test("User opens filters and dismisses them")
    func userOpensFilters() async {
        let model = SearchModel()
        model.showFilters()
        #expect(model.destination == .filters)
        model.destination = nil
        #expect(model.destination == nil)
    }

    @Test("User browses by category")
    func userBrowsesByCategory() async {
        let model = SearchModel()
        model.browseCategory("Furniture")
        #expect(model.destination == .categoryBrowse("Furniture"))
    }

    @Test("User adds a search result to the cart")
    func userAddsResultToCart() async {
        let model = SearchModel()
        model.query = "macbook"
        await model.search()

        guard case .results(let products) = model.searchState, let first = products.first else {
            Issue.record("Expected results")
            return
        }

        var addedID: UUID?
        model.onAddToCart = { id, _, _, _ in addedID = id }
        model.addToCart(first)
        #expect(addedID == first.id)
    }
}
