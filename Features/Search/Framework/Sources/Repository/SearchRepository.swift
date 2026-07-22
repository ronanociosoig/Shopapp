import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol SearchRepositoryProtocol: Sendable {
    func search(query: String) async throws -> [SearchProduct]
    func fetchCategories() async throws -> [String]
    func fetchByCategory(_ category: String) async throws -> [SearchProduct]
}

// MARK: - Remote data source protocol

protocol RemoteSearchDataSourceProtocol: Sendable {
    func search(query: String) async throws -> [SearchProduct]
    func fetchByCategory(_ category: String) async throws -> [SearchProduct]
}

// MARK: - Remote data source

final class RemoteSearchDataSource: RemoteSearchDataSourceProtocol, Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
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

final class LocalSearchDataSource: @unchecked Sendable {
    private let queryCache    = LocalCache<String, [SearchProduct]>()
    private let categoryCache = LocalCache<String, [SearchProduct]>()

    func cachedResults(for query: String) -> [SearchProduct]? { queryCache.get(query) }
    func cachedCategory(_ category: String) -> [SearchProduct]? { categoryCache.get(category) }
    func store(_ results: [SearchProduct], forQuery query: String) { queryCache.set(results, for: query) }
    func store(_ results: [SearchProduct], forCategory category: String) { categoryCache.set(results, for: category) }
}

// MARK: - Live repository

public final class SearchRepository: SearchRepositoryProtocol {
    private let remote: any RemoteSearchDataSourceProtocol
    private let local  = LocalSearchDataSource()

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemoteSearchDataSource(client: client)
    }

    public func search(query: String) async throws -> [SearchProduct] {
        if let cached = local.cachedResults(for: query) { return cached }
        let results = try await remote.search(query: query)
        local.store(results, forQuery: query)
        return results
    }

    public func fetchCategories() async throws -> [String] {
        let all = try await remote.search(query: "")
        return Array(Set(all.map(\.category))).sorted()
    }

    public func fetchByCategory(_ category: String) async throws -> [SearchProduct] {
        if let cached = local.cachedCategory(category) { return cached }
        let results = try await remote.fetchByCategory(category)
        local.store(results, forCategory: category)
        return results
    }
}

