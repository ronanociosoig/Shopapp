import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import Store

// Replay's source-relative archive resolution assumes a `swift test` working
// directory; under xcodebuild/simulator the test process cwd doesn't match the
// repo layout, so pin the archive root explicitly via `#filePath`.
private let replaysRootURL = URL(fileURLWithPath: "\(#filePath)")
    .deletingLastPathComponent()
    .appendingPathComponent("Replays")

@Suite("StoreRepository — caching and network")
struct StoreRepositoryTests {

    // MARK: - fetchProducts

    @Test(
        "fetchProducts decodes the remote response",
        .replay("fetchProducts", matching: .default, filters: [], rootURL: replaysRootURL)
    )
    func fetchProductsDecodesResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer (see
        // Replays/fetchProducts.har), not a hand-authored stub. Request-construction
        // and caching behavior are still covered by MockNetworkClient below.
        let repo     = StoreRepository(client: NetworkClient())
        let products = try await repo.fetchProducts(category: nil)
        #expect(products.count == 88)
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

    @Test(
        "fetchProduct decodes a single product by ID",
        .replay("fetchProduct", matching: .default, filters: [], rootURL: replaysRootURL)
    )
    func fetchProductDecodesProduct() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer (see
        // Replays/fetchProduct.har). The ID matches ShopAppServer's SeedData product 1.
        let id     = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
        let repo   = StoreRepository(client: NetworkClient())
        let result = try await repo.fetchProduct(id: id)
        #expect(result.id == id)
        #expect(result.name == "MacBook Pro 16\"")
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
