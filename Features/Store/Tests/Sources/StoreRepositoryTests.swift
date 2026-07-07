import Testing
import Foundation
import NetworkFoundation
@testable import Store

@Suite("StoreRepository — caching and network")
struct StoreRepositoryTests {

    // MARK: - fetchProducts

    @Test("fetchProducts decodes the remote response")
    func fetchProductsDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(StoreProduct.stubs)
        let repo     = StoreRepository(client: client)
        let products = try await repo.fetchProducts(category: nil)
        #expect(products.count == StoreProduct.stubs.count)
    }

    @Test("fetchProducts with no category sends a request without a query string")
    func fetchProductsWithNoCategoryHasNoQuery() async throws {
        let client = MockNetworkClient()
        try client.setJSON([StoreProduct]())
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProducts(category: nil)
        #expect(client.receivedRequests.first?.url?.query == nil)
    }

    @Test("fetchProducts with a category appends a category query parameter")
    func fetchProductsWithCategoryAppendsParam() async throws {
        let client = MockNetworkClient()
        try client.setJSON([StoreProduct]())
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProducts(category: "Electronics")
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("category=Electronics"))
    }

    @Test("fetchProducts only sends one network request when called twice in a row")
    func fetchProductsCachesResult() async throws {
        let client = MockNetworkClient()
        try client.setJSON(StoreProduct.stubs)
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProducts(category: nil)
        _ = try await repo.fetchProducts(category: nil)
        #expect(client.receivedRequests.count == 1)
    }

    @Test("fetchProducts for different categories each make exactly one request")
    func fetchProductsDifferentCategoriesAreIndependentlyCached() async throws {
        let client = MockNetworkClient()
        try client.setJSON([StoreProduct]())
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProducts(category: "Electronics")
        _ = try await repo.fetchProducts(category: "Furniture")
        _ = try await repo.fetchProducts(category: "Electronics") // cache hit
        #expect(client.receivedRequests.count == 2)
    }

    // MARK: - fetchProduct(id:)

    @Test("fetchProduct decodes a single product by ID")
    func fetchProductDecodesProduct() async throws {
        let client  = MockNetworkClient()
        let product = StoreProduct.stubs[0]
        try client.setJSON(product)
        let repo   = StoreRepository(client: client)
        let result = try await repo.fetchProduct(id: product.id)
        #expect(result.id == product.id)
    }

    @Test("fetchProduct only sends one network request when called twice with the same ID")
    func fetchProductCachesResult() async throws {
        let client  = MockNetworkClient()
        let product = StoreProduct.stubs[0]
        try client.setJSON(product)
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProduct(id: product.id)
        _ = try await repo.fetchProduct(id: product.id)
        #expect(client.receivedRequests.count == 1)
    }

    @Test("fetchProduct includes the product UUID in the URL path")
    func fetchProductIncludesIDInPath() async throws {
        let client  = MockNetworkClient()
        let product = StoreProduct.stubs[0]
        try client.setJSON(product)
        let repo = StoreRepository(client: client)
        _ = try await repo.fetchProduct(id: product.id)
        let path = client.receivedRequests.first?.url?.path ?? ""
        #expect(path.contains(product.id.uuidString))
    }
}
