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

/// In-memory stub for use in tests and previews.
public final class StubSelectedAddressStore: SelectedAddressStoreProtocol, @unchecked Sendable {
    public private(set) var storedID: UUID?

    public init(id: UUID? = nil) { storedID = id }

    public func loadSelectedID() -> UUID? { storedID }
    public func saveSelectedID(_ id: UUID?) { storedID = id }
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

// MARK: - Stub remote data source

public final class StubRemoteCheckoutDataSource: Sendable {
    private let delay: Duration

    public init(delay: Duration = .seconds(1.5)) {
        self.delay = delay
    }

    public func placeOrder(
        items: [CartItem],
        address: ShippingAddress,
        cardToken: String,
        deliveryOption: DeliveryOption,
        guaranteeCost: Decimal
    ) async throws -> PlacedOrder {
        try await Task.sleep(for: delay)
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

// MARK: - Stub repository

public final class StubCheckoutRepository: CheckoutRepositoryProtocol {
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
