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
        client: NetworkClient,
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

// MARK: - Live repository

public final class SuggestionsRepository: SuggestionsRepositoryProtocol {
    private let remote: RemoteSuggestionsDataSource

    public init(client: NetworkClient = DefaultNetworkClient()) {
        self.remote = RemoteSuggestionsDataSource(client: client)
    }

    public func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        try await remote.fetchSuggestions(for: userId)
    }
}

