import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import Promotions

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

@Suite("PromotionsRepository — network")
struct PromotionsRepositoryTests {

    // MARK: - fetchPromotions (request construction)

    @Test("fetchPromotions decodes the remote response")
    func fetchPromotionsDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(Promotion.stubs)
        let repo       = PromotionsRepository(client: client)
        let promotions = try await repo.fetchPromotions()
        #expect(promotions.count == Promotion.stubs.count)
    }

    @Test("fetchPromotions sends a GET request to the promotions endpoint")
    func fetchPromotionsSendsGetRequest() async throws {
        let client = MockNetworkClient()
        try client.setJSON([Promotion]())
        let repo = PromotionsRepository(client: client)
        _ = try await repo.fetchPromotions()
        let request = try #require(client.receivedRequests.first)
        #expect(request.url?.path.hasSuffix("/promotions") == true)
    }

    // MARK: - fetchPromotions (response fidelity)

    @Test(
        "fetchPromotions decodes the real remote response",
        .replay("fetchPromotions", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchPromotionsDecodesRealResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer
        // (see Replays/fetchPromotions.har), not a hand-authored stub.
        let repo       = PromotionsRepository(client: DefaultNetworkClient())
        let promotions = try await repo.fetchPromotions()
        #expect(promotions.count == 2)
        #expect(promotions.first?.title == "Weekend Flash Sale")
    }
}
