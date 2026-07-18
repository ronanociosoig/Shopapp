import Observation
import SwiftUINavigation

@Observable
public final class PastPurchasesModel {
    var orders: [PastOrder]       = []
    var isLoading                  = false
    var destination: Destination?
    /// Set to `true` after a repeat-order action; the composition root
    /// observes this to switch the tab bar to the cart tab.
    public var shouldNavigateToCart       = false

    /// Wire at the composition root to re-add an order's line items to the cart.
    public var onRepeatOrder: ((PastOrder) -> Void)?

    /// Set to `true` when the user taps the support button; the composition root
    /// observes this to present the Support screen and resets it afterwards.
    public var shouldOpenSupport = false

    /// Set to a `PastOrder` when the user requests a rating; the composition root
    /// observes this to present the Rate Order sheet and resets it afterwards.
    public var orderToRate: PastOrder?

    private let repository: PastPurchasesRepositoryProtocol

    public init(repository: PastPurchasesRepositoryProtocol) {
        self.repository = repository
    }

    @CasePathable
    enum Destination: Equatable {
        case orderDetail(PastOrder)
    }

    func select(_ order: PastOrder) {
        destination = .orderDetail(order)
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        orders = (try? await repository.fetchOrders()) ?? []
    }

    /// Persists a newly placed order and inserts it at the front of `orders`.
    @MainActor
    public func saveOrder(_ order: PastOrder) async {
        try? await repository.saveOrder(order)
        orders.insert(order, at: 0)
    }

    /// Removes an order from the list and deletes it from the store.
    @MainActor
    func deleteOrder(_ order: PastOrder) async {
        try? await repository.deleteOrder(id: order.id)
        orders.removeAll { $0.id == order.id }
    }

    func openSupport() {
        shouldOpenSupport = true
    }

    func requestRating(for order: PastOrder) {
        orderToRate = order
    }

    /// Fires `onRepeatOrder` with the given order and signals the composition
    /// root to switch to the cart tab.
    func repeatOrder(_ order: PastOrder) {
        onRepeatOrder?(order)
        shouldNavigateToCart = true
    }
}
