import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol PromotionsRepository: Sendable {
    func fetchPromotions() async throws -> [Promotion]
}

// MARK: - Remote data source

final class RemotePromotionsDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchPromotions() async throws -> [Promotion] {
        try await remote.get("promotions")
    }
}

// MARK: - Live repository

public final class DefaultPromotionsRepository: PromotionsRepository {
    private let remote: RemotePromotionsDataSource

    public init(client: NetworkClient = DefaultNetworkClient()) {
        self.remote = RemotePromotionsDataSource(client: client)
    }

    public func fetchPromotions() async throws -> [Promotion] {
        try await remote.fetchPromotions()
    }
}

