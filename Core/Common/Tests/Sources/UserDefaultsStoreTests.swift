import Testing
import Foundation
import Common

struct TestItem: Codable, Equatable {
    let id: UUID
    let value: String
}

@Suite("UserDefaultsStore")
struct UserDefaultsStoreTests {

    let store: UserDefaultsStore<TestItem>
    let defaults: UserDefaults

    init() {
        let suiteName = "com.shopapp.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store    = UserDefaultsStore(defaults: defaults, key: "test_items")
    }

    // MARK: - Initial state

    @Test("Returns empty array before any data has been saved")
    func returnsEmptyInitially() {
        #expect(store.load().isEmpty)
    }

    // MARK: - Save and load

    @Test("Saves and reloads a single item correctly")
    func saveAndLoadSingleItem() {
        let item = TestItem(id: UUID(), value: "hello")
        store.save([item])
        #expect(store.load() == [item])
    }

    @Test("Saves and reloads multiple items preserving order")
    func saveAndLoadMultipleItemsPreservesOrder() {
        let items = [TestItem(id: UUID(), value: "a"), TestItem(id: UUID(), value: "b")]
        store.save(items)
        #expect(store.load() == items)
    }

    @Test("Preserves all Codable fields through encode/decode")
    func preservesAllFields() {
        let id = UUID()
        let item = TestItem(id: id, value: "preserved")
        store.save([item])
        let loaded = store.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == id)
        #expect(loaded[0].value == "preserved")
    }

    // MARK: - Overwrite behaviour

    @Test("Second save completely replaces the first")
    func secondSaveReplacesPrevious() {
        store.save([TestItem(id: UUID(), value: "first")])
        let second = TestItem(id: UUID(), value: "second")
        store.save([second])
        #expect(store.load() == [second])
    }

    @Test("Saving an empty array removes all stored items")
    func savingEmptyArrayClears() {
        store.save([TestItem(id: UUID(), value: "x")])
        store.save([])
        #expect(store.load().isEmpty)
    }

    // MARK: - Isolation

    @Test("Stores with different keys are fully independent")
    func differentKeysAreIsolated() {
        let storeA = UserDefaultsStore<TestItem>(defaults: defaults, key: "key_a")
        let storeB = UserDefaultsStore<TestItem>(defaults: defaults, key: "key_b")
        storeA.save([TestItem(id: UUID(), value: "A")])
        #expect(storeB.load().isEmpty)
    }

    // MARK: - Resilience

    @Test("Returns empty array when stored bytes are not valid JSON")
    func handlesCorruptData() {
        defaults.set("not json".data(using: .utf8)!, forKey: "test_items")
        #expect(store.load().isEmpty)
    }

    @Test("Returns empty array when stored JSON is the wrong type")
    func handlesWrongJSONType() {
        defaults.set(try! JSONEncoder().encode("a string not an array"), forKey: "test_items")
        #expect(store.load().isEmpty)
    }
}
