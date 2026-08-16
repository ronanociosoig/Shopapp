import Testing
import Foundation
import NetworkFoundation
@testable import Support

@Suite("SupportRepository — network")
struct SupportRepositoryTests {

    // MARK: - submitTicket

    @Test("submitTicket sends a POST request to the tickets endpoint")
    func submitTicketSendsPostRequest() async throws {
        let client = MockNetworkClient()
        let repo   = SupportRepository(client: client)
        let ticket = SupportTicket(topic: "FAQs", message: "How do returns work?")
        try await repo.submitTicket(ticket)
        let request = try #require(client.receivedRequests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/support/tickets") == true)
    }

    // Regression test for a bug where `submitTicket` posted an empty body,
    // silently dropping the topic and message — no Replay coverage needed
    // here since the endpoint returns no decodable body; the request shape
    // itself is what's worth locking down.
    @Test("submitTicket sends the topic and message as a JSON body")
    func submitTicketSendsRequestBody() async throws {
        let client = MockNetworkClient()
        let repo   = SupportRepository(client: client)
        let ticket = SupportTicket(topic: "Order Issues", message: "Where is my order?")
        try await repo.submitTicket(ticket)

        let request = try #require(client.receivedRequests.first)
        let body    = try #require(request.httpBody)
        let json    = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["topic"] as? String == "Order Issues")
        #expect(json["message"] as? String == "Where is my order?")
    }
}
