import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol AccountRepositoryProtocol: Sendable {
    func fetchProfile() async throws -> UserProfile
    func fetchAddresses() async throws -> [SavedAddress]
    func fetchCards() async throws -> [SavedCard]
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func addAddress(_ address: SavedAddress) async throws -> SavedAddress
    func removeAddress(id: UUID) async throws
    func setDefaultAddress(id: UUID) async throws
    func removeCard(id: UUID) async throws
}

// MARK: - Address Store Protocol

/// Abstracts over the address persistence back-end.
/// Inject a custom implementation in tests to avoid touching real UserDefaults.
public protocol AddressStoreProtocol: Sendable {
    func loadAddresses() -> [SavedAddress]
    func saveAddresses(_ addresses: [SavedAddress])
}

// MARK: - UserDefaults Address Store

/// Persists `SavedAddress` values as JSON in `UserDefaults`.
public final class UserDefaultsAddressStore: AddressStoreProtocol, @unchecked Sendable {
    private let store: UserDefaultsStore<SavedAddress>

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.shopapp.saved_addresses"
    ) {
        store = UserDefaultsStore(defaults: defaults, key: key)
    }

    public func loadAddresses() -> [SavedAddress] { store.load() }
    public func saveAddresses(_ addresses: [SavedAddress]) { store.save(addresses) }
}

// MARK: - Remote data source

final class RemoteAccountDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClientProtocol,
        baseURL: URL = RemoteDataSourceHelper.defaultBaseURL
    ) {
        remote = RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    func fetchProfile() async throws -> UserProfile {
        try await remote.get("account/profile")
    }

    func fetchAddresses() async throws -> [SavedAddress] {
        try await remote.get("account/addresses")
    }

    func fetchCards() async throws -> [SavedCard] {
        try await remote.get("account/cards")
    }
}

// MARK: - Local cache (profile and cards only)

final class LocalAccountDataSource: @unchecked Sendable {
    var profile: UserProfile?
    var cards: [SavedCard] = []
}

// MARK: - Live repository

public final class AccountRepository: AccountRepositoryProtocol {
    private let remote: RemoteAccountDataSource
    private let addressStore: AddressStoreProtocol
    // In-memory cache for profile and cards (not persisted across launches)
    private let local = LocalAccountDataSource()

    public init(
        client: NetworkClientProtocol = NetworkClient(),
        addressStore: AddressStoreProtocol = UserDefaultsAddressStore()
    ) {
        self.remote = RemoteAccountDataSource(client: client)
        self.addressStore = addressStore
    }

    public func fetchProfile() async throws -> UserProfile {
        if let cached = local.profile { return cached }
        let profile = try await remote.fetchProfile()
        local.profile = profile
        return profile
    }

    public func fetchAddresses() async throws -> [SavedAddress] {
        let stored = addressStore.loadAddresses()
        if !stored.isEmpty { return stored }
        let addresses = try await remote.fetchAddresses()
        addressStore.saveAddresses(addresses)
        return addresses
    }

    public func fetchCards() async throws -> [SavedCard] {
        if !local.cards.isEmpty { return local.cards }
        let cards = try await remote.fetchCards()
        local.cards = cards
        return cards
    }

    public func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        local.profile = profile
        return profile
    }

    public func addAddress(_ address: SavedAddress) async throws -> SavedAddress {
        var addresses = addressStore.loadAddresses()
        addresses.append(address)
        addressStore.saveAddresses(addresses)
        return address
    }

    public func removeAddress(id: UUID) async throws {
        var addresses = addressStore.loadAddresses()
        addresses.removeAll { $0.id == id }
        addressStore.saveAddresses(addresses)
    }

    public func setDefaultAddress(id: UUID) async throws {
        let updated = addressStore.loadAddresses().map { $0.settingDefault($0.id == id) }
        addressStore.saveAddresses(updated)
    }

    public func removeCard(id: UUID) async throws {
        local.cards.removeAll { $0.id == id }
    }
}

