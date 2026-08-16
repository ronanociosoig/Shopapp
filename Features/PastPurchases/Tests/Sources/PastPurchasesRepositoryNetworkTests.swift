import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import PastPurchases

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

// These tests exercise `RemotePastPurchasesDataSource` directly rather than
// `PastPurchasesRepository`, because the public repository layers local-store
// caching and a per-order status refresh loop on top of the network calls —
// the network layer itself is what these tests target.
@Suite("PastPurchasesRepository — network")
struct PastPurchasesRepositoryNetworkTests {

    // MARK: - fetchOrders (request construction)

    @Test("fetchOrders sends a GET request to the orders endpoint")
    func fetchOrdersSendsGetRequest() async throws {
        let client = MockNetworkClient()
        try client.setJSON([PastOrder]())
        let source = RemotePastPurchasesDataSource(client: client)
        _ = try await source.fetchOrders()
        let request = try #require(client.receivedRequests.first)
        #expect(request.url?.path.hasSuffix("/orders") == true)
    }

    // MARK: - fetchOrderStatus (request construction)

    @Test("fetchOrderStatus includes the order UUID in the URL path")
    func fetchOrderStatusIncludesIDInPath() async throws {
        let client = MockNetworkClient()
        try client.setJSON(OrderStatus.delivered)
        let source = RemotePastPurchasesDataSource(client: client)
        let id     = UUID()
        _ = try await source.fetchOrderStatus(for: id)
        let path = client.receivedRequests.first?.url?.path ?? ""
        #expect(path.contains(id.uuidString))
        #expect(path.hasSuffix("/status"))
    }

    // MARK: - Response fidelity

    @Test(
        "fetchOrders decodes the real remote response",
        .replay("fetchOrders", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchOrdersDecodesRealResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer
        // (see Replays/fetchOrders.har), not a hand-authored stub.
        let source = RemotePastPurchasesDataSource(client: NetworkClient())
        let orders = try await source.fetchOrders()
        #expect(orders.count == 2)
        #expect(orders.first?.lines.first?.name == "MacBook Pro 16\"")
    }

    @Test(
        "fetchOrderStatus decodes the real remote response",
        .replay("fetchOrderStatus", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func fetchOrderStatusDecodesRealResponse() async throws {
        let source = RemotePastPurchasesDataSource(client: NetworkClient())
        let id     = UUID(uuidString: "00000000-0000-0000-0009-000000000001")!
        let status = try await source.fetchOrderStatus(for: id)
        #expect(status == .delivered)
    }
}
