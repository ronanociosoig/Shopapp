import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol StoreRepositoryProtocol: Sendable {
    func fetchProducts(category: String?) async throws -> [StoreProduct]
    func fetchProduct(id: UUID) async throws -> StoreProduct
}

// MARK: - Remote data source

final class RemoteStoreDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchProducts(category: String?) async throws -> [StoreProduct] {
        if let category {
            return try await remote.get("products", queryItems: [URLQueryItem(name: "category", value: category)])
        }
        return try await remote.get("products")
    }

    func fetchProduct(id: UUID) async throws -> StoreProduct {
        try await remote.get("products/\(id.uuidString)")
    }
}

// MARK: - Stub remote data source
//
// Used in micro-apps and Xcode previews so the Store feature runs
// without a live server. The main app swaps this for the live source.

public final class StubRemoteStoreDataSource: Sendable {
    private let products: [StoreProduct]

    public init(products: [StoreProduct] = StoreProduct.stubs) {
        self.products = products
    }

    func fetchProducts(category: String?) async throws -> [StoreProduct] {
        guard let category else { return products }
        return products.filter { $0.category == category }
    }

    func fetchProduct(id: UUID) async throws -> StoreProduct {
        guard let product = products.first(where: { $0.id == id }) else {
            throw HTTPError.statusCode(404)
        }
        return product
    }
}

// MARK: - Local data source (in-memory cache)

final class LocalStoreDataSource {
    private let productsCache = LocalCache<String, [StoreProduct]>()
    private let productCache  = LocalCache<UUID, StoreProduct>()

    func cachedProducts(category: String?) -> [StoreProduct]? { productsCache.get(category ?? "all") }
    func cachedProduct(id: UUID) -> StoreProduct? { productCache.get(id) }

    func store(_ products: [StoreProduct], category: String?) { productsCache.set(products, for: category ?? "all") }
    func store(_ product: StoreProduct) { productCache.set(product, for: product.id) }
}

// MARK: - Live repository

public final class StoreRepository: StoreRepositoryProtocol {
    private let remote: RemoteStoreDataSource
    private let local  = LocalStoreDataSource()

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemoteStoreDataSource(client: client)
    }

    public func fetchProducts(category: String?) async throws -> [StoreProduct] {
        if let cached = local.cachedProducts(category: category) { return cached }
        let products = try await remote.fetchProducts(category: category)
        local.store(products, category: category)
        return products
    }

    public func fetchProduct(id: UUID) async throws -> StoreProduct {
        if let cached = local.cachedProduct(id: id) { return cached }
        let product = try await remote.fetchProduct(id: id)
        local.store(product)
        return product
    }
}

// MARK: - Stub repository (for snapshot tests)

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
