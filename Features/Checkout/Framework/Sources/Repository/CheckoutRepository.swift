import Foundation
import NetworkFoundation
import Common

// MARK: - Selected Address Store

/// Abstracts persistence of the user's last-chosen shipping address ID.
/// Inject a custom implementation in tests to avoid touching real UserDefaults.
public protocol SelectedAddressStoreProtocol: Sendable {
    func loadSelectedID() -> UUID?
    func saveSelectedID(_ id: UUID?)
}

/// Persists the selected shipping address UUID as a string in `UserDefaults`.
public final class UserDefaultsSelectedAddressStore: SelectedAddressStoreProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.shopapp.selected_address_id"
    ) {
        self.defaults = defaults
        self.key      = key
    }

    public func loadSelectedID() -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init)
    }

    public func saveSelectedID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

// MARK: - Protocol

public protocol CheckoutRepositoryProtocol: Sendable {
    func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder
}

// MARK: - Remote data source

final class RemoteCheckoutDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder {
        try await remote.post("orders")
    }
}

// MARK: - Live repository

public final class CheckoutRepository: CheckoutRepositoryProtocol {
    private let remote: RemoteCheckoutDataSource

    public init(client: NetworkClientProtocol = NetworkClient()) {
        self.remote = RemoteCheckoutDataSource(client: client)
    }

    public func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder {
        try await remote.placeOrder(
            items: items, address: address, cardToken: cardToken,
            deliveryOption: deliveryOption, guaranteeCost: guaranteeCost
        )
    }
}

