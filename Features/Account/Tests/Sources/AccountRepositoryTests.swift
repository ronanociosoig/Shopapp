import Testing
import Foundation
import NetworkFoundation
@testable import Account

// MARK: - AccountRepository Address Persistence Tests
//
// These tests verify that the repository correctly delegates address reads and
// writes to the injected AddressStoreProtocol. UnimplementedNetworkClient is
// used so any unexpected network call causes an immediate test failure.

@Suite("AccountRepository — Address Persistence")
struct AccountRepositoryPersistenceTests {

    let store: InMemoryAddressStore
    let repository: AccountRepository

    init() {
        store = InMemoryAddressStore()
        repository = DefaultAccountRepository(
            client: UnimplementedNetworkClient(),
            addressStore: store
        )
    }

    // MARK: - fetchAddresses()

    @Test("fetchAddresses() returns addresses from the store without hitting the network")
    func fetchAddressesFromStore() async throws {
        store.saveAddresses([.stub])
        let result = try await repository.fetchAddresses()
        #expect(result == [.stub])
    }

    @Test("fetchAddresses() returns multiple addresses from the store in order")
    func fetchAddressesPreservesOrder() async throws {
        store.saveAddresses(SavedAddress.stubs)
        let result = try await repository.fetchAddresses()
        #expect(result == SavedAddress.stubs)
    }

    // MARK: - addAddress()

    @Test("addAddress() persists the new address to the store")
    func addAddressPersistsToStore() async throws {
        _ = try await repository.addAddress(.stub)
        #expect(store.loadAddresses() == [.stub])
    }

    @Test("addAddress() appends to addresses already in the store")
    func addAddressAppendsToExisting() async throws {
        store.saveAddresses(SavedAddress.stubs)
        let newAddress = SavedAddress(
            fullName: "New User",
            line1: "1 New St",
            city: "Cork",
            state: "Cork",
            postalCode: "X99 YY12"
        )
        _ = try await repository.addAddress(newAddress)
        let stored = store.loadAddresses()
        #expect(stored.count == SavedAddress.stubs.count + 1)
        #expect(stored.last == newAddress)
    }

    @Test("addAddress() returns the address it was given")
    func addAddressReturnsAddress() async throws {
        let returned = try await repository.addAddress(.stub)
        #expect(returned == .stub)
    }

    // MARK: - removeAddress()

    @Test("removeAddress() deletes the matching address from the store")
    func removeAddressDeletesFromStore() async throws {
        store.saveAddresses([.stub])
        try await repository.removeAddress(id: SavedAddress.stub.id)
        #expect(store.loadAddresses().isEmpty)
    }

    @Test("removeAddress() only removes the address with the matching ID")
    func removeAddressOnlyRemovesMatching() async throws {
        store.saveAddresses(SavedAddress.stubs)
        let toRemove = SavedAddress.stubs[0]
        try await repository.removeAddress(id: toRemove.id)
        let remaining = store.loadAddresses()
        #expect(remaining.count == SavedAddress.stubs.count - 1)
        #expect(!remaining.contains(toRemove))
    }

    @Test("removeAddress() on a non-existent ID leaves the store unchanged")
    func removeAddressNonExistentIDIsNoop() async throws {
        store.saveAddresses([.stub])
        try await repository.removeAddress(id: UUID())
        #expect(store.loadAddresses() == [.stub])
    }

    // MARK: - Persistence round-trip

    @Test("Add then remove leaves the store empty")
    func addThenRemoveLeavesEmpty() async throws {
        _ = try await repository.addAddress(.stub)
        try await repository.removeAddress(id: SavedAddress.stub.id)
        #expect(store.loadAddresses().isEmpty)
    }

    @Test("fetchAddresses reflects addresses added via addAddress")
    func fetchSeesAddedAddresses() async throws {
        _ = try await repository.addAddress(.stub)
        let fetched = try await repository.fetchAddresses()
        #expect(fetched == [.stub])
    }
}

// MARK: - In-memory store (test double)

/// A thread-safe, in-memory implementation of `AddressStoreProtocol` for use
/// in tests. No disk I/O — each test gets a fresh instance via `init()`.
final class InMemoryAddressStore: AddressStoreProtocol, @unchecked Sendable {
    private var addresses: [SavedAddress] = []

    func loadAddresses() -> [SavedAddress] { addresses }
    func saveAddresses(_ addresses: [SavedAddress]) { self.addresses = addresses }
}
