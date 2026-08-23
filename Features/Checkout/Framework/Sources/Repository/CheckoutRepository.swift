import Foundation
import NetworkFoundation
import Common
import CheckoutAPI

// MARK: - Live Selected Address Store

/// Persists the selected shipping address UUID as a string in `UserDefaults`.
// @unchecked Sendable here is about UserDefaults specifically — it's documented
// thread-safe by Apple but this toolchain doesn't recognize it as Sendable, not
// about needing reference semantics; struct is still the right type otherwise.
public struct UserDefaultsSelectedAddressStore: SelectedAddressStore, @unchecked Sendable {
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

// MARK: - Remote data source

struct RemoteCheckoutDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
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
        let request = PlaceOrderRequest(
            items: items,
            shippingAddress: address,
            cardToken: cardToken,
            deliveryOption: deliveryOption,
            guaranteeCost: guaranteeCost
        )
        return try await remote.post("orders", body: request)
    }
}

// MARK: - Live repository

public struct DefaultCheckoutRepository: CheckoutRepository {
    private let remote: RemoteCheckoutDataSource

    public init(client: NetworkClient = DefaultNetworkClient()) {
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
