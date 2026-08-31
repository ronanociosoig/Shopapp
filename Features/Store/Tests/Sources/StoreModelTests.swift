import Testing
import Foundation
@testable import Store
import StoreTesting

@Suite("StoreModel — Unit Tests")
@MainActor
struct StoreModelTests {

    // MARK: - Initial state

    @Test("Initial loadState is idle")
    func initialStateIsIdle() {
        let model = StoreModel()
        #expect(model.loadState == .idle)
    }

    @Test("Initial selectedCategory is nil")
    func initialCategoryIsNil() {
        let model = StoreModel()
        #expect(model.selectedCategory == nil)
    }

    @Test("Initial destination is nil")
    func initialDestinationIsNil() {
        let model = StoreModel()
        #expect(model.destination == nil)
    }

    // MARK: - categories computed property

    @Test("categories returns empty when loadState is not loaded")
    func categoriesEmptyWhenNotLoaded() {
        let model = StoreModel()
        #expect(model.categories.isEmpty)
        model.loadState = .loading
        #expect(model.categories.isEmpty)
        model.loadState = .failed("error")
        #expect(model.categories.isEmpty)
    }

    @Test("categories returns sorted unique category names from loaded products")
    func categoriesReturnsSortedUnique() {
        let model = StoreModel()
        model.loadState = .loaded(StoreProduct.stubs)
        let categories = model.categories
        #expect(!categories.isEmpty)
        #expect(categories == categories.sorted())
        #expect(Set(categories).count == categories.count) // no duplicates
    }

    // MARK: - displayedProducts computed property

    @Test("displayedProducts returns empty when loadState is not loaded")
    func displayedProductsEmptyWhenNotLoaded() {
        let model = StoreModel()
        #expect(model.displayedProducts.isEmpty)
    }

    @Test("displayedProducts returns all products when no category filter is set")
    func displayedProductsReturnsAllWhenNoFilter() {
        let model = StoreModel()
        let stubs = StoreProduct.stubs
        model.loadState = .loaded(stubs)
        #expect(model.displayedProducts == stubs)
    }

    @Test("displayedProducts filters by selectedCategory")
    func displayedProductsFiltersByCategory() {
        let model = StoreModel()
        model.loadState = .loaded(StoreProduct.stubs)
        model.selectedCategory = "Electronics"
        let filtered = model.displayedProducts
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.category == "Electronics" })
    }

    @Test("displayedProducts returns empty for an unknown category")
    func displayedProductsEmptyForUnknownCategory() {
        let model = StoreModel()
        model.loadState = .loaded(StoreProduct.stubs)
        model.selectedCategory = "NonExistentCategory"
        #expect(model.displayedProducts.isEmpty)
    }

    // MARK: - Navigation

    @Test("select sets destination to productDetail")
    func selectSetsProductDetailDestination() {
        let model = StoreModel()
        let product = StoreProduct.stub
        model.select(product)
        #expect(model.destination == .productDetail(product))
    }

    @Test("showCategoryFilter sets destination to categoryFilter")
    func showCategoryFilterSetsDestination() {
        let model = StoreModel()
        model.showCategoryFilter()
        #expect(model.destination == .categoryFilter)
    }

    // MARK: - addToCart

    @Test("addToCart fires onAddToCart with correct product primitives")
    func addToCartFiresCallback() {
        let model = StoreModel()
        let product = StoreProduct.stub
        var captured: (UUID, String, Decimal, Bool)?
        model.onAddToCart = { id, name, price, wantsGuarantee in
            captured = (id, name, price, wantsGuarantee)
        }
        model.addToCart(product, wantsGuarantee: true)
        #expect(captured?.0 == product.id)
        #expect(captured?.1 == product.name)
        #expect(captured?.2 == product.price)
        #expect(captured?.3 == true)
    }

    @Test("addToCart passes wantsGuarantee false by default")
    func addToCartDefaultsToNoGuarantee() {
        let model = StoreModel()
        var capturedGuarantee: Bool?
        model.onAddToCart = { _, _, _, wantsGuarantee in capturedGuarantee = wantsGuarantee }
        model.addToCart(.stub)
        #expect(capturedGuarantee == false)
    }

    @Test("addToCart does nothing when onAddToCart is not wired")
    func addToCartNoOpWithoutCallback() {
        let model = StoreModel()
        model.addToCart(.stub) // must not crash
    }

    // MARK: - load()

    @Test("load sets loadState to loaded on success")
    func loadSetsLoadedState() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()
        guard case .loaded(let products) = model.loadState else {
            Issue.record("Expected .loaded state")
            return
        }
        #expect(!products.isEmpty)
    }

    @Test("load sets loadState to failed when repository throws")
    func loadSetsFailedStateOnError() async {
        let model = StoreModel(repository: StubStoreRepository(throwing: URLError(.notConnectedToInternet)))
        await model.load()
        guard case .failed = model.loadState else {
            Issue.record("Expected .failed state")
            return
        }
    }
}
