import Foundation
import PastPurchases

public final class StubPastPurchasesRepository: PastPurchasesRepository, @unchecked Sendable {
    public private(set) var orders: [PastOrder]

    public init(orders: [PastOrder] = PastOrder.stubs) {
        self.orders = orders
    }

    public func fetchOrders() async throws -> [PastOrder] { orders }

    public func saveOrder(_ order: PastOrder) async throws {
        orders.insert(order, at: 0)
    }

    public func deleteOrder(id: UUID) async throws {
        orders.removeAll { $0.id == id }
    }
}
