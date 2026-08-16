import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import Suggestions

// Replay's source-relative archive resolution assumes a `swift test` working
// directory; under xcodebuild/simulator the test process cwd doesn't match the
// repo layout, so pin the archive root explicitly via `#filePath`.
let replaysRootURL = URL(fileURLWithPath: "\(#filePath)")
    .deletingLastPathComponent()
    .appendingPathComponent("Replays")

// Applied at record time to every fixture, regardless of whether the endpoint
// being recorded happens to carry anything sensitive today. ShopAppServer has
// no auth today, so this is currently a no-op; the policy is what matters.
let replayFilters: [Filter] = [
    .headers(removing: ["Authorization", "Cookie"]),
    .queryParameters(removing: ["token", "api_key"]),
]

@Suite("SuggestionsRepository — network")
struct SuggestionsRepositoryTests {

    // MARK: - fetchSuggestions (request construction)

    @Test("fetchSuggestions decodes the remote response")
    func fetchSuggestionsDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SuggestedProduct.stubs)
        let repo        = SuggestionsRepository(client: client)
        let suggestions = try await repo.fetchSuggestions(for: nil)
        #expect(suggestions.count == SuggestedProduct.stubs.count)
    }

    @Test("fetchSuggestions with no userId sends a request without a query string")
    func fetchSuggestionsWithNoUserIdHasNoQuery() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SuggestedProduct]())
        let repo = SuggestionsRepository(client: client)
        _ = try await repo.fetchSuggestions(for: nil)
        #expect(client.receivedRequests.first?.url?.query == nil)
    }

    @Test("fetchSuggestions with a userId appends a userId query parameter")
    func fetchSuggestionsWithUserIdAppendsParam() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SuggestedProduct]())
        let repo = SuggestionsRepository(client: client)
        _ = try await repo.fetchSuggestions(for: "user-42")
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("userId=user-42"))
    }

    // MARK: - fetchSuggestions (response fidelity)

    @Test(
        "fetchSuggestions decodes the real remote response",
        .replay("fetchSuggestions", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchSuggestionsDecodesRealResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer
        // (see Replays/fetchSuggestions.har), not a hand-authored stub.
        let repo        = SuggestionsRepository(client: NetworkClient())
        let suggestions = try await repo.fetchSuggestions(for: nil)
        #expect(!suggestions.isEmpty)
        #expect(suggestions.first?.name == "MacBook Pro 16\"")
    }
}
