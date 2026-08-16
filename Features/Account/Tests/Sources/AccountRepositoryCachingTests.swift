import Testing
import Foundation
import NetworkFoundation
@testable import Account

@Suite("AccountRepository — caching")
struct AccountRepositoryCachingTests {

    // MARK: - fetchProfile

    @Test("fetchProfile decodes the remote response")
    func fetchProfileDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(UserProfile.stub)
        let repo    = AccountRepository(client: client)
        let profile = try await repo.fetchProfile()
        #expect(profile.email == UserProfile.stub.email)
    }

    @Test("fetchProfile only sends one network request when called twice")
    func fetchProfileCachesOnSecondCall() async throws {
        let client = MockNetworkClient()
        try client.setJSON(UserProfile.stub)
        let repo = AccountRepository(client: client)
        _ = try await repo.fetchProfile()
        _ = try await repo.fetchProfile()
        #expect(client.receivedRequests.filter { $0.url?.path.contains("profile") == true }.count == 1)
    }

    // MARK: - fetchAddresses

    @Test("fetchAddresses decodes the remote response when the local store is empty")
    func fetchAddressesDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON(SavedAddress.stubs)
        let repo      = AccountRepository(client: client, addressStore: InMemoryAddressStore())
        let addresses = try await repo.fetchAddresses()
        #expect(addresses.count == SavedAddress.stubs.count)
    }

    // MARK: - fetchCards

    @Test("fetchCards decodes the remote response")
    func fetchCardsDecodesResponse() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SavedCard.stub])
        let repo  = AccountRepository(client: client)
        let cards = try await repo.fetchCards()
        #expect(cards.count == 1)
    }

    @Test("fetchCards only sends one network request when called twice")
    func fetchCardsCachesOnSecondCall() async throws {
        let client = MockNetworkClient()
        try client.setJSON([SavedCard.stub])
        let repo = AccountRepository(client: client)
        _ = try await repo.fetchCards()
        _ = try await repo.fetchCards()
        #expect(client.receivedRequests.filter { $0.url?.path.contains("cards") == true }.count == 1)
    }

    // MARK: - updateProfile

    @Test("updateProfile returns the updated profile")
    func updateProfileReturnsUpdatedProfile() async throws {
        let client  = MockNetworkClient()
        try client.setJSON(UserProfile.stub)
        let repo    = AccountRepository(client: client)
        _           = try await repo.fetchProfile()
        let updated = try await repo.updateProfile(UserProfile.stub)
        #expect(updated.email == UserProfile.stub.email)
    }

    @Test("updateProfile updates the in-memory cache so the next fetchProfile uses new data")
    func updateProfileUpdatesCache() async throws {
        let client = MockNetworkClient()
        // First fetch populates the cache
        try client.setJSON(UserProfile.stub)
        let repo = AccountRepository(client: client)
        _ = try await repo.fetchProfile()
        // Update the profile
        let updatedProfile = UserProfile(
            id: UserProfile.stub.id,
            email: "updated@example.com",
            displayName: "Updated Name",
            avatarURL: nil
        )
        _ = try await repo.updateProfile(updatedProfile)
        // Subsequent fetch should come from the updated cache, not the network
        let requestCountBefore = client.receivedRequests.filter {
            $0.url?.path.contains("profile") == true
        }.count
        let fetched = try await repo.fetchProfile()
        let requestCountAfter = client.receivedRequests.filter {
            $0.url?.path.contains("profile") == true
        }.count
        // No new request was made (served from cache)
        #expect(requestCountAfter == requestCountBefore)
        #expect(fetched.displayName == "Updated Name")
    }
}
