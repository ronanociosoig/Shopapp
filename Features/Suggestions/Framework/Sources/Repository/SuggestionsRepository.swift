import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol SuggestionsRepositoryProtocol: Sendable {
    func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct]
}

// MARK: - Remote data source

final class RemoteSuggestionsDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        if let userId {
            return try await remote.get("suggestions", queryItems: [URLQueryItem(name: "userId", value: userId)])
        }
        return try await remote.get("suggestions")
    }
}

// MARK: - Stub remote data source

public final class StubRemoteSuggestionsDataSource: Sendable {
    private let products: [SuggestedProduct]

    public init(products: [SuggestedProduct] = SuggestedProduct.stubs) {
        self.products = products
    }

    public func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        products
    }
}

// MARK: - Live repository

public final class SuggestionsRepository: SuggestionsRepositoryProtocol {
    private let remote: RemoteSuggestionsDataSource

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemoteSuggestionsDataSource(client: client)
    }

    public func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        try await remote.fetchSuggestions(for: userId)
    }
}

// MARK: - Stub repository

public final class StubSuggestionsRepository: SuggestionsRepositoryProtocol {
    private let products: [SuggestedProduct]

    public init(products: [SuggestedProduct] = SuggestedProduct.stubs) {
        self.products = products
    }

    public func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        products
    }
}
