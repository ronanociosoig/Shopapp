import Testing
import Foundation
import NetworkFoundation
import Replay
@testable import Checkout
@testable import CheckoutAPI

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

@Suite("CheckoutRepository — network")
struct CheckoutRepositoryTests {

    // MARK: - placeOrder

    @Test(
        "placeOrder sends the order and decodes the remote response",
        .replay("placeOrder", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func placeOrderDecodesResponse() async throws {
        // Response fidelity test: real traffic recorded from ShopAppServer (see
        // Replays/placeOrder.har), not a hand-authored stub. This is also the
        // regression test for the bug where `placeOrder` posted an empty body
        // and silently dropped the cart/address/payment details.
        let repo = DefaultCheckoutRepository(client: DefaultNetworkClient())
        let order = try await repo.placeOrder(
            items: CartItem.stubs,
            address: .stub,
            cardToken: "tok_test",
            deliveryOption: .express,
            guaranteeCost: 49.99
        )
        #expect(order.items.count == CartItem.stubs.count)
        #expect(order.shippingAddress.id == ShippingAddress.stub.id)
        #expect(order.deliveryOption == .express)
    }

    @Test("placeOrder sends the cart, address, and payment details as a JSON body")
    func placeOrderSendsRequestBody() async throws {
        let client = MockNetworkClient()
        try client.setJSON(PlacedOrder.stub)
        let repo = DefaultCheckoutRepository(client: client)
        _ = try await repo.placeOrder(
            items: CartItem.stubs,
            address: .stub,
            cardToken: "tok_test",
            deliveryOption: .express,
            guaranteeCost: 49.99
        )

        let request = try #require(client.receivedRequests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/orders") == true)

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["cardToken"] as? String == "tok_test")
        #expect(json["guaranteeCost"] as? Double == 49.99)
        #expect((json["items"] as? [[String: Any]])?.count == CartItem.stubs.count)
    }
}
