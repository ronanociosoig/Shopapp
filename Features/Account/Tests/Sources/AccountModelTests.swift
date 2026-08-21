import Testing
import Foundation
@testable import Account
import AccountTesting

// MARK: - AccountModel Tests

@Suite("AccountModel")
@MainActor
struct AccountModelTests {

    // MARK: - load()

    @Test("load() populates addresses from the repository")
    func loadPopulatesAddresses() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: SavedAddress.stubs))
        await model.load()
        #expect(model.addresses == SavedAddress.stubs)
    }

    @Test("load() populates profile from the repository")
    func loadPopulatesProfile() async {
        let model = AccountModel(repository: StubAccountRepository())
        await model.load()
        #expect(model.profile == .stub)
    }

    @Test("load() populates cards from the repository")
    func loadPopulatesCards() async {
        let model = AccountModel(repository: StubAccountRepository(cards: [.stub]))
        await model.load()
        #expect(model.cards == [.stub])
    }

    @Test("load() sets isLoading to false after completion")
    func loadClearsIsLoading() async {
        let model = AccountModel(repository: StubAccountRepository())
        await model.load()
        #expect(!model.isLoading)
    }

    @Test("load() sets isLoading to false even when repository throws")
    func loadClearsIsLoadingOnError() async {
        let model = AccountModel(repository: FailingAccountRepository())
        await model.load()
        #expect(!model.isLoading)
    }

    @Test("load() starts with empty addresses when repository returns none")
    func loadWithEmptyAddresses() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: []))
        await model.load()
        #expect(model.addresses.isEmpty)
    }

    // MARK: - addAddress()

    @Test("addAddress() immediately appends to addresses")
    func addAddressAppendsImmediately() {
        let model = AccountModel(repository: StubAccountRepository(addresses: []))
        model.addAddress(.stub)
        #expect(model.addresses == [.stub])
    }

    @Test("addAddress() appends to existing addresses without replacing them")
    func addAddressPreservesExisting() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: SavedAddress.stubs))
        await model.load()
        let newAddress = SavedAddress(
            fullName: "New User",
            line1: "99 New Street",
            city: "Cork",
            state: "Cork",
            postalCode: "T12 AB34",
            country: "Ireland"
        )
        model.addAddress(newAddress)
        #expect(model.addresses.count == SavedAddress.stubs.count + 1)
        #expect(model.addresses.last == newAddress)
    }

    @Test("addAddress() multiple times accumulates all addresses")
    func addAddressMultipleTimes() {
        let model = AccountModel(repository: StubAccountRepository(addresses: []))
        for address in SavedAddress.stubs {
            model.addAddress(address)
        }
        #expect(model.addresses.count == SavedAddress.stubs.count)
    }

    // MARK: - removeAddress()

    @Test("removeAddress() removes the correct address by ID")
    func removeAddressRemovesCorrectOne() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: SavedAddress.stubs))
        await model.load()
        let toRemove = model.addresses[0]
        model.removeAddress(toRemove)
        #expect(!model.addresses.contains(toRemove))
    }

    @Test("removeAddress() leaves all other addresses intact")
    func removeAddressLeavesOthers() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: SavedAddress.stubs))
        await model.load()
        let beforeCount = model.addresses.count
        let toRemove = model.addresses[0]
        model.removeAddress(toRemove)
        #expect(model.addresses.count == beforeCount - 1)
        for address in model.addresses {
            #expect(address.id != toRemove.id)
        }
    }

    @Test("removeAddress() on empty list does nothing")
    func removeAddressOnEmpty() {
        let model = AccountModel(repository: StubAccountRepository(addresses: []))
        model.removeAddress(.stub)  // Should not crash or add anything
        #expect(model.addresses.isEmpty)
    }

    // MARK: - removeCard()

    @Test("removeCard() removes the correct card")
    func removeCardRemovesCorrect() async {
        let model = AccountModel(repository: StubAccountRepository(cards: [.stub]))
        await model.load()
        model.removeCard(.stub)
        #expect(model.cards.isEmpty)
    }

    @Test("removeCard() leaves other cards intact")
    func removeCardLeavesOthers() async {
        let extraCard = SavedCard(
            id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            token: "tok_extra",
            lastFour: "9999",
            brand: .mastercard,
            expiryMonth: 6,
            expiryYear: 2027
        )
        let model = AccountModel(repository: StubAccountRepository(cards: [.stub, extraCard]))
        await model.load()
        model.removeCard(.stub)
        #expect(model.cards == [extraCard])
    }

    // MARK: - showEditProfile()

    @Test("showEditProfile() sets destination to .editProfile after load")
    func showEditProfileSetsDestination() async {
        let model = AccountModel(repository: StubAccountRepository())
        await model.load()
        model.showEditProfile()
        #expect(model.destination == .editProfile(.stub))
    }

    @Test("showEditProfile() does nothing when profile has not been loaded")
    func showEditProfileDoesNothingWithoutProfile() {
        let model = AccountModel(repository: StubAccountRepository())
        // intentionally skip load() so profile stays nil
        model.showEditProfile()
        #expect(model.destination == nil)
    }

    // MARK: - showAddAddress() / showSavedCards()

    @Test("showAddAddress() sets destination to .addAddress")
    func showAddAddressSetsDestination() {
        let model = AccountModel(repository: StubAccountRepository())
        model.showAddAddress()
        #expect(model.destination == .addAddress)
    }

    @Test("showSavedCards() sets destination to .savedCards")
    func showSavedCardsSetsDestination() {
        let model = AccountModel(repository: StubAccountRepository())
        model.showSavedCards()
        #expect(model.destination == .savedCards)
    }

    // MARK: - Computed properties

    @Test("defaultAddress returns the address flagged isDefault")
    func defaultAddressReturnsDefaultFlagged() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: SavedAddress.stubs))
        await model.load()
        // SavedAddress.stubs[0] has isDefault = true
        #expect(model.defaultAddress?.isDefault == true)
    }

    @Test("defaultAddress returns first address when none is flagged as default")
    func defaultAddressFallsBackToFirst() async {
        let addresses = [
            SavedAddress(fullName: "A", line1: "1 St", city: "X", state: "Y", postalCode: "Z", isDefault: false),
            SavedAddress(fullName: "B", line1: "2 St", city: "X", state: "Y", postalCode: "Z", isDefault: false),
        ]
        let model = AccountModel(repository: StubAccountRepository(addresses: addresses))
        await model.load()
        #expect(model.defaultAddress == addresses.first)
    }

    @Test("defaultAddress returns nil when there are no addresses")
    func defaultAddressNilForEmpty() async {
        let model = AccountModel(repository: StubAccountRepository(addresses: []))
        await model.load()
        #expect(model.defaultAddress == nil)
    }

    @Test("isSignedIn is true after a successful load")
    func isSignedInTrueAfterLoad() async {
        let model = AccountModel(repository: StubAccountRepository())
        await model.load()
        #expect(model.isSignedIn)
    }

    @Test("isSignedIn is false before load is called")
    func isSignedInFalseBeforeLoad() {
        let model = AccountModel(repository: StubAccountRepository())
        #expect(!model.isSignedIn)
    }
}

// MARK: - Test doubles

/// Repository whose fetch calls always throw so we can test error-path behaviour.
private final class FailingAccountRepository: AccountRepository, @unchecked Sendable {
    private struct FetchError: Error {}

    func fetchProfile()                              async throws -> UserProfile   { throw FetchError() }
    func fetchAddresses()                            async throws -> [SavedAddress] { throw FetchError() }
    func fetchCards()                               async throws -> [SavedCard]   { throw FetchError() }
    func updateProfile(_ profile: UserProfile)       async throws -> UserProfile   { throw FetchError() }
    func addAddress(_ address: SavedAddress)         async throws -> SavedAddress  { throw FetchError() }
    func removeAddress(id: UUID)                     async throws                  { throw FetchError() }
    func setDefaultAddress(id: UUID)                 async throws                  { throw FetchError() }
    func removeCard(id: UUID)                        async throws                  { throw FetchError() }
}
