import Testing
import Foundation
@testable import Store

/// Tests that exercise complete user interaction flows through the Store module.
/// Each test simulates a multi-step journey a user would take in the UI.
@Suite("Store — UI Interaction Tests")
@MainActor
struct StoreUITests {

    @Test("User loads the store and sees products")
    func userLoadsStore() async {
        let model = StoreModel(repository: StubStoreRepository())
        #expect(model.loadState == .idle)
        await model.load()
        guard case .loaded(let products) = model.loadState else {
            Issue.record("Expected products to be loaded")
            return
        }
        #expect(!products.isEmpty)
    }

    @Test("User filters by category then clears the filter")
    func userFiltersAndClearsCategory() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()

        model.selectedCategory = "Electronics"
        let filtered = model.displayedProducts
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.category == "Electronics" })

        model.selectedCategory = nil
        #expect(model.displayedProducts.count > filtered.count)
    }

    @Test("User opens category filter sheet and dismisses it")
    func userOpensCategoryFilter() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()

        model.showCategoryFilter()
        #expect(model.destination == .categoryFilter)

        model.destination = nil
        #expect(model.destination == nil)
    }

    @Test("User taps a product and navigates to product detail")
    func userSelectsProduct() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()

        guard case .loaded(let products) = model.loadState, let first = products.first else {
            Issue.record("Products should be loaded")
            return
        }

        model.select(first)
        #expect(model.destination == .productDetail(first))

        model.destination = nil
        #expect(model.destination == nil)
    }

    @Test("User adds a product to cart")
    func userAddsProductToCart() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()

        var addedID: UUID?
        model.onAddToCart = { id, _, _, _ in addedID = id }

        guard case .loaded(let products) = model.loadState, let first = products.first else {
            Issue.record("Products should be loaded")
            return
        }

        model.addToCart(first)
        #expect(addedID == first.id)
    }

    @Test("User adds a product with extended guarantee")
    func userAddsProductWithGuarantee() async {
        let model = StoreModel(repository: StubStoreRepository())
        await model.load()

        var capturedGuarantee: Bool?
        model.onAddToCart = { _, _, _, wantsGuarantee in capturedGuarantee = wantsGuarantee }

        let eligible = StoreProduct.stubs.first(where: { $0.supportsExtendedGuarantee })!
        model.addToCart(eligible, wantsGuarantee: true)
        #expect(capturedGuarantee == true)
    }

    @Test("Store shows error state when loading fails, then recovers on retry")
    func userRetriesAfterError() async {
        final class FailingThenSucceedingRepository: StoreRepositoryProtocol, @unchecked Sendable {
            var callCount = 0
            func fetchProducts(category: String?) async throws -> [StoreProduct] {
                callCount += 1
                if callCount == 1 { throw URLError(.notConnectedToInternet) }
                return StoreProduct.stubs
            }
            func fetchProduct(id: UUID) async throws -> StoreProduct { .stub }
        }

        let repo = FailingThenSucceedingRepository()
        let model = StoreModel(repository: repo)

        await model.load()
        guard case .failed = model.loadState else {
            Issue.record("Expected .failed on first load")
            return
        }

        await model.load()
        guard case .loaded = model.loadState else {
            Issue.record("Expected .loaded after retry")
            return
        }
    }
}
