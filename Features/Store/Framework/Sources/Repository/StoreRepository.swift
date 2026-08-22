import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol StoreRepository: Sendable {
    func fetchProducts(category: String?) async throws -> [StoreProduct]
    func fetchProduct(id: UUID) async throws -> StoreProduct
}

// MARK: - Remote data source

final class RemoteStoreDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
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

// MARK: - Local data source (in-memory cache)

// A struct holding two actor references, not a class — no state of its own to
// protect; LocalCache's own actor isolation is what makes concurrent access safe.
struct LocalStoreDataSource: Sendable {
    private let productsCache = LocalCache<String, [StoreProduct]>()
    private let productCache  = LocalCache<UUID, StoreProduct>()

    func cachedProducts(category: String?) async -> [StoreProduct]? { await productsCache.get(category ?? "all") }
    func cachedProduct(id: UUID) async -> StoreProduct? { await productCache.get(id) }

    func store(_ products: [StoreProduct], category: String?) async { await productsCache.set(products, for: category ?? "all") }
    func store(_ product: StoreProduct) async { await productCache.set(product, for: product.id) }
}

// MARK: - Live repository

public final class DefaultStoreRepository: StoreRepository {
    private let remote: RemoteStoreDataSource
    private let local  = LocalStoreDataSource()

    public init(client: NetworkClient = DefaultNetworkClient()) {
        self.remote = RemoteStoreDataSource(client: client)
    }

    public func fetchProducts(category: String?) async throws -> [StoreProduct] {
        if let cached = await local.cachedProducts(category: category) { return cached }
        let products = try await remote.fetchProducts(category: category)
        await local.store(products, category: category)
        return products
    }

    public func fetchProduct(id: UUID) async throws -> StoreProduct {
        if let cached = await local.cachedProduct(id: id) { return cached }
        let product = try await remote.fetchProduct(id: id)
        await local.store(product)
        return product
    }
}

