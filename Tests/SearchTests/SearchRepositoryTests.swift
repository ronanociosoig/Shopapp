import Testing
import Foundation
import NetworkFoundation
@testable import Search

@Suite("SearchRepository — caching, categories, and network")
struct SearchRepositoryTests {

    // MARK: - search(query:)

    @Test("search returns products matching the query")
    func searchDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SearchProduct.stubs)
        let repo    = SearchRepository(client: client)
        let results = try await repo.search(query: "MacBook")
        #expect(!results.isEmpty)
    }

    @Test("search appends the q query parameter to the URL")
    func searchAppendsQueryParam() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SearchProduct]())
        let repo = SearchRepository(client: client)
        _ = try await repo.search(query: "chair")
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("q=chair"))
    }

    @Test("search only sends one network request when called twice with the same query")
    func searchCachesResult() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SearchProduct.stubs)
        let repo = SearchRepository(client: client)
        _ = try await repo.search(query: "desk")
        _ = try await repo.search(query: "desk")
        #expect(client.receivedRequests.count == 1)
    }

    @Test("different search queries each trigger a separate network request")
    func differentQueriesMakeIndependentRequests() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SearchProduct]())
        let repo = SearchRepository(client: client)
        _ = try await repo.search(query: "laptop")
        _ = try await repo.search(query: "chair")
        _ = try await repo.search(query: "laptop") // cache hit
        #expect(client.receivedRequests.count == 2)
    }

    // MARK: - fetchCategories

    @Test("fetchCategories returns a sorted list of unique categories")
    func fetchCategoriesReturnsSortedUnique() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SearchProduct.stubs)
        let repo       = SearchRepository(client: client)
        let categories = try await repo.fetchCategories()
        #expect(categories == categories.sorted())
        #expect(Set(categories).count == categories.count)
    }

    @Test("fetchCategories returns all categories present in the product catalogue")
    func fetchCategoriesIncludesAllCatalogueCategories() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SearchProduct.stubs)
        let repo       = SearchRepository(client: client)
        let categories = try await repo.fetchCategories()
        let expected   = Set(SearchProduct.stubs.map(\.category))
        #expect(Set(categories) == expected)
    }

    @Test("fetchCategories sends a search request with an empty query")
    func fetchCategoriesUsesEmptyQuery() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SearchProduct]())
        let repo = SearchRepository(client: client)
        _ = try await repo.fetchCategories()
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("q=") || query.contains("q&") || query == "q=")
    }

    // MARK: - fetchByCategory

    @Test("fetchByCategory decodes products for the given category")
    func fetchByCategoryDecodesProducts() async throws {
        let client = MockNetworkClient()
        let electronics = SearchProduct.electronics
        try client.setJSON(electronics)
        let repo    = SearchRepository(client: client)
        let results = try await repo.fetchByCategory("Electronics")
        #expect(results.count == electronics.count)
    }

    @Test("fetchByCategory appends the category query parameter")
    func fetchByCategoryAppendsParam() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SearchProduct]())
        let repo = SearchRepository(client: client)
        _ = try await repo.fetchByCategory("Furniture")
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("category=Furniture"))
    }

    @Test("fetchByCategory only sends one request when called twice for the same category")
    func fetchByCategoryCachesResult() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SearchProduct.electronics)
        let repo = SearchRepository(client: client)
        _ = try await repo.fetchByCategory("Electronics")
        _ = try await repo.fetchByCategory("Electronics")
        #expect(client.receivedRequests.count == 1)
    }
}
