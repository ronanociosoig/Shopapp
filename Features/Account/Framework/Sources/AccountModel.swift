import Observation
import SwiftUINavigation

@MainActor
@Observable
public final class AccountModel {
    var profile: UserProfile?
    public var addresses: [SavedAddress] = []
    var cards: [SavedCard] = []
    var isLoading = false
    var destination: Destination?

    /// Lets a caller (in practice, a snapshot test) opt a model out of
    /// `AccountView`'s auto-load entirely. Needed because "not loaded yet"
    /// and "signed out" both look identical from the outside — nil profile,
    /// empty addresses/cards — so a guard keyed on that state alone can't
    /// tell the two apart. Production code never needs to touch this.
    var suppressAutoLoad = false

    private let repository: AccountRepository

    public init(repository: AccountRepository, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case editProfile(UserProfile)
        case addAddress
        case savedCards
    }

    var defaultAddress: SavedAddress? { addresses.first(where: \.isDefault) ?? addresses.first }
    var defaultCard: SavedCard?        { cards.first(where: \.isDefault) ?? cards.first }
    var isSignedIn: Bool               { profile != nil }

    public func load() async {
        // Self-guarding rather than relying on every call site to check first —
        // AccountView's own .task and RootView's .task both trigger this
        // independently, and both need the same protection against
        // clobbering state a caller (or a test) already set explicitly.
        guard !suppressAutoLoad, !isLoading, profile == nil, addresses.isEmpty, cards.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let repo = repository
        async let profile   = try? repo.fetchProfile()
        async let addresses = try? repo.fetchAddresses()
        async let cards     = try? repo.fetchCards()
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
