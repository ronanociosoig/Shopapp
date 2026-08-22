import Foundation
import Checkout

public final class StubSelectedAddressStore: SelectedAddressStore, @unchecked Sendable {
    public private(set) var storedID: UUID?

    public init(id: UUID? = nil) { storedID = id }

    public func loadSelectedID() -> UUID? { storedID }
    public func saveSelectedID(_ id: UUID?) { storedID = id }
}

public final class StubCheckoutRepository: CheckoutRepository {
    private let error: Error?
    private let delay: Duration

    public init(delay: Duration = .seconds(1.5)) {
        error      = nil
        self.delay = delay
    }

    public init(throwing error: Error) {
        self.error = error
        self.delay = .seconds(0)
    }

    public func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder {
        try await Task.sleep(for: delay)
        if let error { throw error }
        let subtotal = items.reduce(Decimal(0)) { $0 + $1.subtotal }
        let total = subtotal + deliveryOption.price + guaranteeCost
        let deliveryDays: TimeInterval = deliveryOption == .express ? 1 : (deliveryOption == .collect ? 0.1 : 5)
        return PlacedOrder(
            items: items.map { OrderLineItem(product: $0.product, quantity: $0.quantity) },
            shippingAddress: address,
            deliveryOption: deliveryOption,
            total: total,
            estimatedDelivery: Date(timeIntervalSinceNow: deliveryDays * 24 * 3600)
        )
    }
}
