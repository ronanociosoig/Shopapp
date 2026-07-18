import Foundation
import NetworkFoundation
import Store

public final class StubStoreRepository: StoreRepositoryProtocol {
    private let result: Result<[StoreProduct], Error>

    public init(returning products: [StoreProduct] = StoreProduct.stubs) {
        result = .success(products)
    }

    public init(throwing error: Error) {
        result = .failure(error)
    }

    public func fetchProducts(category: String?) async throws -> [StoreProduct] {
        let all = try result.get()
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    public func fetchProduct(id: UUID) async throws -> StoreProduct {
        let all = try result.get()
        guard let product = all.first(where: { $0.id == id }) else { throw HTTPError.statusCode(404) }
        return product
    }
}
