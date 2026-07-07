import Testing
import Foundation
@testable import PastPurchases

// MARK: - Test double

private final class StubOrderStore: OrderStoreProtocol, @unchecked Sendable {
    var storedOrders: [PastOrder]

    init(orders: [PastOrder] = []) { storedOrders = orders }

    func loadOrders() -> [PastOrder] { storedOrders }
    func saveOrders(_ orders: [PastOrder]) { storedOrders = orders }
    func deleteOrder(id: UUID) { storedOrders.removeAll { $0.id == id } }
}

// MARK: - Unit Tests

@Suite("PastPurchasesRepository")
struct PastPurchasesRepositoryTests {

    // MARK: - fetchOrders — remote vs local

    @Test("fetchOrders uses the remote when the local store is empty")
    func fetchOrdersUsesRemoteWhenStoreIsEmpty() async throws {
        let remote = MockRemotePastPurchasesDataSource(orders: PastOrder.stubs)
        let store  = StubOrderStore(orders: [])
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        let orders = try await repo.fetchOrders()
        #expect(orders.count == PastOrder.stubs.count)
    }

    @Test("fetchOrders uses the local store when it already has data")
    func fetchOrdersUsesLocalWhenStoreHasData() async throws {
        let localOrder = PastOrder.stub
        let remote = MockRemotePastPurchasesDataSource(orders: [])
        let store  = StubOrderStore(orders: [localOrder])
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        let orders = try await repo.fetchOrders()
        // The local order should be present (possibly with refreshed status)
        #expect(orders.contains(where: { $0.id == localOrder.id }))
    }

    // MARK: - Status refresh

    @Test("fetchOrders refreshes order status from the remote data source")
    func fetchOrdersRefreshesStatus() async throws {
        // Create an order with a known status that the mock will override
        var order = PastOrder.stub
        // placedAt is already old, so mock will return .delivered
        let store  = StubOrderStore(orders: [order])
        let remote = MockRemotePastPurchasesDataSource(orders: [order])
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        let orders = try await repo.fetchOrders()
        // The stub is from 2026-03-15 which is well in the past → delivered
        #expect(orders[0].status == .delivered)
    }

    @Test("fetchOrders persists refreshed statuses back to the local store")
    func fetchOrdersPersistsRefreshedStatuses() async throws {
        let order  = PastOrder.stub           // old order → will be refreshed to .delivered
        let store  = StubOrderStore(orders: [order])
        let remote = MockRemotePastPurchasesDataSource(orders: [order])
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        _ = try await repo.fetchOrders()
        // Status should have been written back into the store
        #expect(store.storedOrders[0].status == .delivered)
    }

    // MARK: - saveOrder

    @Test("saveOrder inserts the new order at index 0")
    func saveOrderInsertsAtFront() async throws {
        let existing = PastOrder.stubs[0]
        let store    = StubOrderStore(orders: [existing])
        let remote   = MockRemotePastPurchasesDataSource()
        let repo     = PastPurchasesRepository(remote: remote, store: store)
        let newOrder = PastOrder.stubs[1]
        try await repo.saveOrder(newOrder)
        #expect(store.storedOrders[0].id == newOrder.id)
    }

    @Test("saveOrder preserves all previously stored orders")
    func saveOrderPreservesExistingOrders() async throws {
        let store  = StubOrderStore(orders: PastOrder.stubs)
        let remote = MockRemotePastPurchasesDataSource()
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        let fresh  = PastOrder(
            placedAt: Date(), estimatedDelivery: Date(),
            lines: [], deliveryOptionName: "Standard",
            itemsSubtotal: 0, deliveryCost: 0, guaranteeCost: 0, total: 0,
            shippingAddress: .stub
        )
        try await repo.saveOrder(fresh)
        #expect(store.storedOrders.count == PastOrder.stubs.count + 1)
    }

    // MARK: - deleteOrder

    @Test("deleteOrder removes the matching order from the store")
    func deleteOrderRemovesOrder() async throws {
        let store  = StubOrderStore(orders: PastOrder.stubs)
        let remote = MockRemotePastPurchasesDataSource()
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        let target = PastOrder.stubs[0]
        try await repo.deleteOrder(id: target.id)
        #expect(!store.storedOrders.contains(where: { $0.id == target.id }))
    }

    @Test("deleteOrder with an unknown id leaves orders unchanged")
    func deleteOrderUnknownIdIsNoop() async throws {
        let store  = StubOrderStore(orders: PastOrder.stubs)
        let remote = MockRemotePastPurchasesDataSource()
        let repo   = PastPurchasesRepository(remote: remote, store: store)
        try await repo.deleteOrder(id: UUID())
        #expect(store.storedOrders.count == PastOrder.stubs.count)
    }
}

// MARK: - MockRemotePastPurchasesDataSource status logic

@Suite("MockRemotePastPurchasesDataSource — status derivation")
struct MockRemotePastPurchasesDataSourceTests {

    private func makeOrder(daysAgo: Double) -> PastOrder {
        PastOrder(
            placedAt: Date().addingTimeInterval(-daysAgo * 86_400),
            estimatedDelivery: Date(),
            lines: [], deliveryOptionName: "Standard",
            itemsSubtotal: 0, deliveryCost: 0, guaranteeCost: 0, total: 0,
            shippingAddress: .stub
        )
    }

    @Test("Returns .processing for an order placed less than 2 days ago")
    func processingForRecentOrder() async throws {
        let order  = makeOrder(daysAgo: 0.5)
        let source = MockRemotePastPurchasesDataSource(orders: [order])
        let status = try await source.fetchOrderStatus(for: order.id)
        #expect(status == .processing)
    }

    @Test("Returns .shipped for an order placed 2–5 days ago")
    func shippedForMidAgeOrder() async throws {
        let order  = makeOrder(daysAgo: 3)
        let source = MockRemotePastPurchasesDataSource(orders: [order])
        let status = try await source.fetchOrderStatus(for: order.id)
        #expect(status == .shipped)
    }

    @Test("Returns .delivered for an order placed more than 5 days ago")
    func deliveredForOldOrder() async throws {
        let order  = makeOrder(daysAgo: 7)
        let source = MockRemotePastPurchasesDataSource(orders: [order])
        let status = try await source.fetchOrderStatus(for: order.id)
        #expect(status == .delivered)
    }

    @Test("Returns .processing for an unknown order ID (falls back to now)")
    func processingForUnknownOrderID() async throws {
        let source = MockRemotePastPurchasesDataSource(orders: [])
        let status = try await source.fetchOrderStatus(for: UUID())
        #expect(status == .processing)
    }
}
