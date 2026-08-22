import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol PastPurchasesRepository: Sendable {
    func fetchOrders() async throws -> [PastOrder]
    func saveOrder(_ order: PastOrder) async throws
    func deleteOrder(id: UUID) async throws
}

// MARK: - Order Store Protocol

/// Abstracts over the order persistence back-end.
/// Inject a custom implementation in tests to avoid touching real UserDefaults.
public protocol OrderStore: Sendable {
    func loadOrders() -> [PastOrder]
    func saveOrders(_ orders: [PastOrder])
    func deleteOrder(id: UUID)
}

// MARK: - UserDefaults Order Store

/// Persists `PastOrder` values as JSON in `UserDefaults`, newest first.
public final class UserDefaultsOrderStore: OrderStore, @unchecked Sendable {
    private let store: UserDefaultsStore<PastOrder>

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.shopapp.past_orders"
    ) {
        store = UserDefaultsStore(defaults: defaults, key: key)
    }

    public func loadOrders() -> [PastOrder] { store.load() }
    public func saveOrders(_ orders: [PastOrder]) { store.save(orders) }

    public func deleteOrder(id: UUID) {
        var orders = store.load()
        orders.removeAll { $0.id == id }
        store.save(orders)
    }
}

// MARK: - Remote data source protocol

protocol RemotePastPurchasesDataSourceProtocol: Sendable {
    func fetchOrders() async throws -> [PastOrder]
    func fetchOrderStatus(for orderID: UUID) async throws -> OrderStatus
}

// MARK: - Remote data source

final class RemotePastPurchasesDataSource: RemotePastPurchasesDataSourceProtocol, Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchOrders() async throws -> [PastOrder] {
        try await remote.get("orders")
    }

    func fetchOrderStatus(for orderID: UUID) async throws -> OrderStatus {
        try await remote.get("orders/\(orderID.uuidString)/status")
    }
}

// MARK: - Mock remote data source

/// Simulates remote order-status responses without a real network connection.
/// Status is derived deterministically from the order's placement date.
public final class MockRemotePastPurchasesDataSource: RemotePastPurchasesDataSourceProtocol, Sendable {
    private let orders: [PastOrder]

    public init(orders: [PastOrder] = PastOrder.stubs) {
        self.orders = orders
    }

    public func fetchOrders() async throws -> [PastOrder] { orders }

    public func fetchOrderStatus(for orderID: UUID) async throws -> OrderStatus {
        let order = orders.first { $0.id == orderID }
        let age = Date().timeIntervalSince(order?.placedAt ?? Date())
        let days = age / 86_400
        switch days {
        case ..<2:   return .processing
        case 2..<5:  return .shipped
        default:     return .delivered
        }
    }
}

// MARK: - Live repository

public final class DefaultPastPurchasesRepository: PastPurchasesRepository {
    private let remote: any RemotePastPurchasesDataSourceProtocol
    private let store: OrderStore

    public init(
        client: NetworkClient = DefaultNetworkClient(),
        store: OrderStore = UserDefaultsOrderStore()
    ) {
        self.remote = RemotePastPurchasesDataSource(client: client)
        self.store  = store
    }

    init(
        remote: some RemotePastPurchasesDataSourceProtocol,
        store: OrderStore = UserDefaultsOrderStore()
    ) {
        self.remote = remote
        self.store  = store
    }

    /// A `DefaultPastPurchasesRepository` backed by mock remote data, going through
    /// the full local-store and status-refresh pipeline.
    public static func mock(store: OrderStore = UserDefaultsOrderStore()) -> DefaultPastPurchasesRepository {
        DefaultPastPurchasesRepository(remote: MockRemotePastPurchasesDataSource(), store: store)
    }

    /// Loads orders from the local store (or remote on first launch), then
    /// refreshes each order's status from the remote and persists the result.
    public func fetchOrders() async throws -> [PastOrder] {
        var orders = store.loadOrders()
        if orders.isEmpty {
            orders = try await remote.fetchOrders()
        }
        // Refresh statuses from remote; ignore individual failures so a
        // single bad response doesn't block the entire list from loading.
        for i in orders.indices {
            if let status = try? await remote.fetchOrderStatus(for: orders[i].id) {
                orders[i].status = status
            }
        }
        store.saveOrders(orders)
        return orders
    }

    /// Inserts the new order at the front of the store (most recent first).
    public func saveOrder(_ order: PastOrder) async throws {
        var orders = store.loadOrders()
        orders.insert(order, at: 0)
        store.saveOrders(orders)
    }

    public func deleteOrder(id: UUID) async throws {
        store.deleteOrder(id: id)
    }
}

