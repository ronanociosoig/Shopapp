import Testing
import Foundation
@testable import Account

// MARK: - UserDefaultsAddressStore Tests

@Suite("UserDefaultsAddressStore")
struct AddressStoreTests {

    /// Each test instance gets its own isolated UserDefaults suite so tests
    /// never interfere with each other or with `.standard`.
    let store: UserDefaultsAddressStore
    let defaults: UserDefaults
    let suiteName: String

    init() {
        suiteName = "com.shopapp.tests.\(UUID().uuidString)"
        defaults  = UserDefaults(suiteName: suiteName)!
        store     = UserDefaultsAddressStore(defaults: defaults)
    }

    // MARK: - Initial state

    @Test("Returns an empty array when no data has been stored yet")
    func returnsEmptyInitially() {
        #expect(store.loadAddresses().isEmpty)
    }

    // MARK: - Save and load roundtrips

    @Test("Saves and reloads a single address correctly")
    func saveAndLoadSingleAddress() {
        store.saveAddresses([.stub])
        #expect(store.loadAddresses() == [.stub])
    }

    @Test("Saves and reloads multiple addresses correctly")
    func saveAndLoadMultipleAddresses() {
        store.saveAddresses(SavedAddress.stubs)
        #expect(store.loadAddresses() == SavedAddress.stubs)
    }

    @Test("Preserves all fields through encode/decode")
    func preservesAllFields() {
        let address = SavedAddress(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            fullName: "Test User",
            line1: "1 Test Lane",
            line2: "Apt 7",
            city: "Cork",
            state: "Cork",
            postalCode: "T12 XX99",
            country: "Ireland",
            isDefault: true
        )
        store.saveAddresses([address])
        let loaded = store.loadAddresses()
        #expect(loaded.count == 1)
        #expect(loaded.first == address)
    }

    // MARK: - Overwrite behaviour

    @Test("Saving an empty array removes previously stored addresses")
    func savingEmptyOverwritesPrevious() {
        store.saveAddresses(SavedAddress.stubs)
        store.saveAddresses([])
        #expect(store.loadAddresses().isEmpty)
    }

    @Test("Second save completely replaces the first")
    func secondSaveReplacesPrevious() {
        store.saveAddresses([.stub])
        let replacement = SavedAddress(
            fullName: "Replacement",
            line1: "99 New Rd",
            city: "Dublin",
            state: "Dublin 1",
            postalCode: "D01 AB12"
        )
        store.saveAddresses([replacement])
        let loaded = store.loadAddresses()
        #expect(loaded.count == 1)
        #expect(loaded.first == replacement)
    }

    // MARK: - Isolation

    @Test("Separate store instances with different keys are independent")
    func separateKeysAreIsolated() {
        let storeA = UserDefaultsAddressStore(defaults: defaults, key: "key_a")
        let storeB = UserDefaultsAddressStore(defaults: defaults, key: "key_b")

        storeA.saveAddresses([.stub])
        #expect(storeB.loadAddresses().isEmpty)
    }

    // MARK: - Resilience

    @Test("Returns empty array when stored data is not valid JSON")
    func handlesCorruptedData() {
        defaults.set("not valid json".data(using: .utf8)!, forKey: "com.shopapp.saved_addresses")
        #expect(store.loadAddresses().isEmpty)
    }

    @Test("Returns empty array when stored data is a non-array JSON type")
    func handlesWrongJSONType() throws {
        let wrongData = try JSONEncoder().encode(["key": "value"])
        defaults.set(wrongData, forKey: "com.shopapp.saved_addresses")
        #expect(store.loadAddresses().isEmpty)
    }
}
