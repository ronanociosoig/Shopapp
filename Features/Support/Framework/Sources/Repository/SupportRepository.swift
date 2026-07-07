import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol SupportRepositoryProtocol: Sendable {
    func submitTicket(_ ticket: SupportTicket) async throws
    func fetchTickets() async throws -> [SupportTicket]
}

// MARK: - Remote data source

final class RemoteSupportDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func submitTicket(_ ticket: SupportTicket) async throws {
        try await remote.post("support/tickets")
    }

    func fetchTickets() async throws -> [SupportTicket] { [] }
}

// MARK: - Stub remote data source

public final class StubRemoteSupportDataSource: Sendable {
    public init() {}

    public func submitTicket(_ ticket: SupportTicket) async throws {}
    public func fetchTickets() async throws -> [SupportTicket] { [] }
}

// MARK: - Live repository

public final class SupportRepository: SupportRepositoryProtocol {
    private let remote: RemoteSupportDataSource

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemoteSupportDataSource(client: client)
    }

    public func submitTicket(_ ticket: SupportTicket) async throws {
        try await remote.submitTicket(ticket)
    }

    public func fetchTickets() async throws -> [SupportTicket] {
        try await remote.fetchTickets()
    }
}

// MARK: - Stub repository

public final class StubSupportRepository: SupportRepositoryProtocol {
    public init() {}

    public func submitTicket(_ ticket: SupportTicket) async throws {}
    public func fetchTickets() async throws -> [SupportTicket] { [] }
}
