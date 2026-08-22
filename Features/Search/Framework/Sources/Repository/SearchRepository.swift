import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol SearchRepository: Sendable {
    func search(query: String) async throws -> [SearchProduct]
    func fetchCategories() async throws -> [String]
    func fetchByCategory(_ category: String) async throws -> [SearchProduct]
}

// MARK: - Remote data source protocol

protocol RemoteSearchDataSource: Sendable {
    func search(query: String) async throws -> [SearchProduct]
    func fetchByCategory(_ category: String) async throws -> [SearchProduct]
}

// MARK: - Remote data source

final class DefaultRemoteSearchDataSource: RemoteSearchDataSource, Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func search(query: String) async throws -> [SearchProduct] {
        try await remote.get("search", queryItems: [URLQueryItem(name: "q", value: query)])
    }

    func fetchByCategory(_ category: String) async throws -> [SearchProduct] {
        try await remote.get("search", queryItems: [URLQueryItem(name: "category", value: category)])
    }
}

// MARK: - Local data source

// A struct holding two actor references, not a class — no state of its own to
// protect; LocalCache's own actor isolation is what makes concurrent access safe.
struct LocalSearchDataSource: Sendable {
    private let queryCache    = LocalCache<String, [SearchProduct]>()
    private let categoryCache = LocalCache<String, [SearchProduct]>()

    func cachedResults(for query: String) async -> [SearchProduct]? { await queryCache.get(query) }
    func cachedCategory(_ category: String) async -> [SearchProduct]? { await categoryCache.get(category) }
    func store(_ results: [SearchProduct], forQuery query: String) async { await queryCache.set(results, for: query) }
    func store(_ results: [SearchProduct], forCategory category: String) async { await categoryCache.set(results, for: category) }
}

// MARK: - Live repository

public final class DefaultSearchRepository: SearchRepository {
    private let remote: any RemoteSearchDataSource
    private let local  = LocalSearchDataSource()

    public init(client: NetworkClient = DefaultNetworkClient()) {
        self.remote = DefaultRemoteSearchDataSource(client: client)
    }

    public func search(query: String) async throws -> [SearchProduct] {
        if let cached = await local.cachedResults(for: query) { return cached }
        let results = try await remote.search(query: query)
        await local.store(results, forQuery: query)
        return results
    }

    public func fetchCategories() async throws -> [String] {
        let all = try await remote.search(query: "")
        return Array(Set(all.map(\.category))).sorted()
    }

    public func fetchByCategory(_ category: String) async throws -> [SearchProduct] {
        if let cached = await local.cachedCategory(category) { return cached }
        let results = try await remote.fetchByCategory(category)
        await local.store(results, forCategory: category)
        return results
    }
}

