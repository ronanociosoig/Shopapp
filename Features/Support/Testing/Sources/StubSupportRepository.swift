import Foundation
import Support

public final class StubSupportRepository: SupportRepository {
    public init() {}

    public func submitTicket(_ ticket: SupportTicket) async throws {}
    public func fetchTickets() async throws -> [SupportTicket] { [] }
}
