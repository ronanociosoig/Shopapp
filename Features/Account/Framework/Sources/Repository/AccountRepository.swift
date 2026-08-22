import Foundation
import NetworkFoundation
import Common

// MARK: - Protocol

public protocol AccountRepository: Sendable {
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
public protocol AddressStore: Sendable {
    func loadAddresses() -> [SavedAddress]
    func saveAddresses(_ addresses: [SavedAddress])
}

// MARK: - UserDefaults Address Store

/// Persists `SavedAddress` values as JSON in `UserDefaults`.
public struct UserDefaultsAddressStore: AddressStore, @unchecked Sendable {
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

struct RemoteAccountDataSource: Sendable {
    private let remote: RemoteDataSourceHelper

    init(
        client: NetworkClient,
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

// An actor, not a class — genuinely mutable state accessed from async
// repository methods needs real isolation, same reasoning as LocalCache.
actor LocalAccountDataSource {
    private var profile: UserProfile?
    private var cards: [SavedCard] = []

    func getProfile() -> UserProfile? { profile }
    func setProfile(_ profile: UserProfile) { self.profile = profile }
    func getCards() -> [SavedCard] { cards }
    func setCards(_ cards: [SavedCard]) { self.cards = cards }
}

// MARK: - Live repository

public struct DefaultAccountRepository: AccountRepository {
    private let remote: RemoteAccountDataSource
    private let addressStore: AddressStore
    // In-memory cache for profile and cards (not persisted across launches)
    private let local = LocalAccountDataSource()

    public init(
        client: NetworkClient = DefaultNetworkClient(),
        addressStore: AddressStore = UserDefaultsAddressStore()
    ) {
        self.remote = RemoteAccountDataSource(client: client)
        self.addressStore = addressStore
    }

    public func fetchProfile() async throws -> UserProfile {
        if let cached = await local.getProfile() { return cached }
        let profile = try await remote.fetchProfile()
        await local.setProfile(profile)
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
        let cached = await local.getCards()
        if !cached.isEmpty { return cached }
        let cards = try await remote.fetchCards()
        await local.setCards(cards)
        return cards
    }

    public func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        await local.setProfile(profile)
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
        var cards = await local.getCards()
        cards.removeAll { $0.id == id }
        await local.setCards(cards)
    }
}

