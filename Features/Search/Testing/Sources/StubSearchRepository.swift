import Foundation
import Search

public final class StubSearchRepository: SearchRepository {
    private let result: Result<[SearchProduct], Error>

    public init(returning products: [SearchProduct] = SearchProduct.stubs) {
        result = .success(products)
    }

    public init(throwing error: Error) {
        result = .failure(error)
    }

    public func search(query: String) async throws -> [SearchProduct] {
        let all = try result.get()
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    public func fetchCategories() async throws -> [String] {
        let all = try result.get()
        return Array(Set(all.map(\.category))).sorted()
    }

    public func fetchByCategory(_ category: String) async throws -> [SearchProduct] {
        let all = try result.get()
        return all.filter { $0.category == category }
    }
}
