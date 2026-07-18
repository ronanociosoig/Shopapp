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

