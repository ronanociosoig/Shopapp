import Observation
import SwiftUINavigation

@Observable
public final class AccountModel {
    public var profile: UserProfile?
    public var addresses: [SavedAddress] = []
    public var cards: [SavedCard] = []
    public var isLoading = false
    public var destination: Destination?

    private let repository: AccountRepositoryProtocol

    public init(repository: AccountRepositoryProtocol = StubAccountRepository()) {
        self.repository = repository
    }

    @CasePathable
    public enum Destination: Equatable {
        case editProfile(UserProfile)
        case addAddress
        case savedCards
    }

    public var defaultAddress: SavedAddress? { addresses.first(where: \.isDefault) ?? addresses.first }
    public var defaultCard: SavedCard?        { cards.first(where: \.isDefault) ?? cards.first }
    public var isSignedIn: Bool               { profile != nil }

    @MainActor
    public func load() async {
        isLoading = true
        defer { isLoading = false }
        async let profile   = try? repository.fetchProfile()
        async let addresses = try? repository.fetchAddresses()
        async let cards     = try? repository.fetchCards()
        self.profile   = await profile
        self.addresses = await addresses ?? []
        self.cards     = await cards ?? []
    }

    public func showEditProfile() {
        guard let profile else { return }
        destination = .editProfile(profile)
    }

    public func showAddAddress() { destination = .addAddress }
    public func showSavedCards() { destination = .savedCards }

    public func removeAddress(_ address: SavedAddress) {
        addresses.removeAll { $0.id == address.id }
        Task { try? await repository.removeAddress(id: address.id) }
    }

    public func removeCard(_ card: SavedCard) {
        cards.removeAll { $0.id == card.id }
        Task { try? await repository.removeCard(id: card.id) }
    }

    public func addAddress(_ address: SavedAddress) {
        addresses.append(address)
        Task { try? await repository.addAddress(address) }
    }
}
