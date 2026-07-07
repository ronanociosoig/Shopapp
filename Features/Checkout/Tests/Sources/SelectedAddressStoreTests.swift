import Testing
import Foundation
@testable import Checkout

@Suite("UserDefaultsSelectedAddressStore")
struct SelectedAddressStoreTests {

    let store: UserDefaultsSelectedAddressStore
    let defaults: UserDefaults
    let suiteName: String

    init() {
        suiteName = "com.shopapp.tests.\(UUID().uuidString)"
        defaults  = UserDefaults(suiteName: suiteName)!
        store     = UserDefaultsSelectedAddressStore(defaults: defaults)
    }

    // MARK: - Initial state

    @Test("Returns nil when no ID has been stored yet")
    func returnsNilInitially() {
        #expect(store.loadSelectedID() == nil)
    }

    // MARK: - Save and load

    @Test("Saves and reloads a UUID correctly")
    func saveAndLoad() {
        let id = UUID()
        store.saveSelectedID(id)
        #expect(store.loadSelectedID() == id)
    }

    @Test("Saving nil removes a previously stored ID")
    func saveNilClearsStoredID() {
        store.saveSelectedID(UUID())
        store.saveSelectedID(nil)
        #expect(store.loadSelectedID() == nil)
    }

    @Test("Second save replaces the first")
    func secondSaveReplacesPrevious() {
        let first  = UUID()
        let second = UUID()
        store.saveSelectedID(first)
        store.saveSelectedID(second)
        #expect(store.loadSelectedID() == second)
    }

    // MARK: - Isolation

    @Test("Separate stores with different keys are independent")
    func separateKeysAreIsolated() {
        let storeA = UserDefaultsSelectedAddressStore(defaults: defaults, key: "key_a")
        let storeB = UserDefaultsSelectedAddressStore(defaults: defaults, key: "key_b")

        storeA.saveSelectedID(UUID())
        #expect(storeB.loadSelectedID() == nil)
    }

    // MARK: - Resilience

    @Test("Returns nil when stored value is not a valid UUID string")
    func handlesInvalidUUIDString() {
        defaults.set("not-a-uuid", forKey: "com.shopapp.selected_address_id")
        #expect(store.loadSelectedID() == nil)
    }
}
