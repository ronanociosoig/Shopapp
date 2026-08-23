import Foundation

// MARK: - Selected Address Store

/// Abstracts persistence of the user's last-chosen shipping address ID.
/// Inject a custom implementation in tests to avoid touching real UserDefaults.
public protocol SelectedAddressStore: Sendable {
    func loadSelectedID() -> UUID?
    func saveSelectedID(_ id: UUID?)
}

// MARK: - Protocol

public protocol CheckoutRepository: Sendable {
    func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder
}
