import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import Account

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

@Suite("AccountRepository — network")
struct AccountRepositoryReplayTests {

    // MARK: - fetchProfile

    @Test(
        "fetchProfile decodes the real remote response",
        .replay("fetchProfile", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchProfileDecodesRealResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer
        // (see Replays/fetchProfile.har), not a hand-authored stub.
        let repo    = AccountRepository(client: NetworkClient())
        let profile = try await repo.fetchProfile()
        #expect(profile.email == "alex@example.com")
        #expect(profile.displayName == "Alex Johnson")
    }

    // MARK: - fetchAddresses

    @Test(
        "fetchAddresses decodes the real remote response",
        .replay("fetchAddresses", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchAddressesDecodesRealResponse() async throws {
        // A fresh in-memory address store guarantees the local cache is empty
        // so the repository actually hits the network instead of short-circuiting.
        let repo      = AccountRepository(client: NetworkClient(), addressStore: InMemoryAddressStore())
        let addresses = try await repo.fetchAddresses()
        #expect(addresses.count == 3)
        #expect(addresses.first?.city == "San Francisco")
    }

    // MARK: - fetchCards

    @Test(
        "fetchCards decodes the real remote response",
        .replay("fetchCards", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchCardsDecodesRealResponse() async throws {
        let repo  = AccountRepository(client: NetworkClient())
        let cards = try await repo.fetchCards()
        #expect(cards.count == 1)
        #expect(cards.first?.lastFour == "4242")
    }
}
