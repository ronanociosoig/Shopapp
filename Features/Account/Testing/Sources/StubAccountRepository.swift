import Foundation
import Account

public final class StubAccountRepository: AccountRepository, @unchecked Sendable {
    private var profile: UserProfile
    private var addresses: [SavedAddress]
    private var cards: [SavedCard]

    public init(
        profile: UserProfile      = .stub,
        addresses: [SavedAddress] = SavedAddress.stubs,
        cards: [SavedCard]        = [.stub]
    ) {
        self.profile   = profile
        self.addresses = addresses
        self.cards     = cards
    }

    public func fetchProfile()                            async throws -> UserProfile   { profile }
    public func fetchAddresses()                          async throws -> [SavedAddress] { addresses }
    public func fetchCards()                              async throws -> [SavedCard]   { cards }
    public func updateProfile(_ profile: UserProfile)     async throws -> UserProfile   { profile }
    public func addAddress(_ address: SavedAddress)       async throws -> SavedAddress  { address }
    public func removeAddress(id: UUID)                   async throws {}
    public func setDefaultAddress(id: UUID)               async throws {}
    public func removeCard(id: UUID)                      async throws {}
}
