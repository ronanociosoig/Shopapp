import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol PromotionsRepositoryProtocol: Sendable {
    func fetchPromotions() async throws -> [Promotion]
}

// MARK: - Remote data source

final class RemotePromotionsDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchPromotions() async throws -> [Promotion] {
        try await remote.get("promotions")
    }
}

// MARK: - Stub remote data source

public final class StubRemotePromotionsDataSource: Sendable {
    private let promotions: [Promotion]

    public init(promotions: [Promotion] = Promotion.stubs) {
        self.promotions = promotions
    }

    public func fetchPromotions() async throws -> [Promotion] { promotions }
}

// MARK: - Live repository

public final class PromotionsRepository: PromotionsRepositoryProtocol {
    private let remote: RemotePromotionsDataSource

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemotePromotionsDataSource(client: client)
    }

    public func fetchPromotions() async throws -> [Promotion] {
        try await remote.fetchPromotions()
    }
}

// MARK: - Stub repository

public final class StubPromotionsRepository: PromotionsRepositoryProtocol {
    private let promotions: [Promotion]

    public init(promotions: [Promotion] = Promotion.stubs) {
        self.promotions = promotions
    }

    public func fetchPromotions() async throws -> [Promotion] { promotions }
}
