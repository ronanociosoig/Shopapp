import Observation
import SwiftUINavigation

@Observable
public final class AccountModel {
    var profile: UserProfile?
    public var addresses: [SavedAddress] = []
    var cards: [SavedCard] = []
    var isLoading = false
    var destination: Destination?

    private let repository: AccountRepositoryProtocol

    public init(repository: AccountRepositoryProtocol, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable {
        case editProfile(UserProfile)
        case addAddress
        case savedCards
    }

    var defaultAddress: SavedAddress? { addresses.first(where: \.isDefault) ?? addresses.first }
    var defaultCard: SavedCard?        { cards.first(where: \.isDefault) ?? cards.first }
    var isSignedIn: Bool               { profile != nil }

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

    func showEditProfile() {
        guard let profile else { return }
        destination = .editProfile(profile)
    }

    func showAddAddress() { destination = .addAddress }
    func showSavedCards() { destination = .savedCards }

    func updateDisplayName(_ name: String) {
        guard let current = profile, !name.isEmpty else { return }
        let updated = UserProfile(id: current.id, email: current.email,
                                  displayName: name, avatarURL: current.avatarURL)
        profile = updated
        Task { try? await repository.updateProfile(updated) }
    }

    func setDefaultAddress(_ address: SavedAddress) {
        addresses = addresses.map { $0.settingDefault($0.id == address.id) }
        Task { try? await repository.setDefaultAddress(id: address.id) }
    }

    func removeAddress(_ address: SavedAddress) {
        addresses.removeAll { $0.id == address.id }
        Task { try? await repository.removeAddress(id: address.id) }
    }

    func removeCard(_ card: SavedCard) {
        cards.removeAll { $0.id == card.id }
        Task { try? await repository.removeCard(id: card.id) }
    }

    func addAddress(_ address: SavedAddress) {
        addresses.append(address)
        Task { try? await repository.addAddress(address) }
    }
}
