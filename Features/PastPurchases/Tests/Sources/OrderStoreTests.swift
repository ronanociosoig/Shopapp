import Testing
import Foundation
@testable import PastPurchases

@Suite("UserDefaultsOrderStore")
struct OrderStoreTests {

    let store: UserDefaultsOrderStore
    let defaults: UserDefaults
    let suiteName: String

    init() {
        suiteName = "com.shopapp.tests.\(UUID().uuidString)"
        defaults  = UserDefaults(suiteName: suiteName)!
        store     = UserDefaultsOrderStore(defaults: defaults)
    }

    // MARK: - Initial state

    @Test("Returns an empty array when no data has been stored yet")
    func returnsEmptyInitially() {
        #expect(store.loadOrders().isEmpty)
    }

    // MARK: - Save and load roundtrips

    @Test("Saves and reloads a single order correctly")
    func saveAndLoadSingleOrder() {
        store.saveOrders([.stub])
        #expect(store.loadOrders() == [.stub])
    }

    @Test("Saves and reloads multiple orders correctly")
    func saveAndLoadMultipleOrders() {
        store.saveOrders(PastOrder.stubs)
        #expect(store.loadOrders() == PastOrder.stubs)
    }

    @Test("Preserves all fields through encode/decode")
    func preservesAllFields() {
        let order = PastOrder.stub
        store.saveOrders([order])
        let loaded = store.loadOrders()
        #expect(loaded.count == 1)
        #expect(loaded.first == order)
    }

    // MARK: - Overwrite behaviour

    @Test("Saving an empty array removes previously stored orders")
    func savingEmptyOverwritesPrevious() {
        store.saveOrders(PastOrder.stubs)
        store.saveOrders([])
        #expect(store.loadOrders().isEmpty)
    }

    @Test("Second save completely replaces the first")
    func secondSaveReplacesPrevious() {
        store.saveOrders([.stubs[0]])
        store.saveOrders([.stubs[1]])
        let loaded = store.loadOrders()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == PastOrder.stubs[1].id)
    }

    // MARK: - Isolation

    @Test("Separate store instances with different keys are independent")
    func separateKeysAreIsolated() {
        let storeA = UserDefaultsOrderStore(defaults: defaults, key: "key_a")
        let storeB = UserDefaultsOrderStore(defaults: defaults, key: "key_b")
        storeA.saveOrders([.stub])
        #expect(storeB.loadOrders().isEmpty)
    }

    // MARK: - Resilience

    @Test("Returns empty array when stored data is not valid JSON")
    func handlesCorruptedData() {
        defaults.set("not valid json".data(using: .utf8)!, forKey: "com.shopapp.past_orders")
        #expect(store.loadOrders().isEmpty)
    }

    // MARK: - Delete

    @Test("deleteOrder removes the matching order")
    func deleteOrderRemovesOrder() {
        store.saveOrders(PastOrder.stubs)
        let target = PastOrder.stubs[0]
        store.deleteOrder(id: target.id)
        let loaded = store.loadOrders()
        #expect(!loaded.contains(where: { $0.id == target.id }))
        #expect(loaded.count == PastOrder.stubs.count - 1)
    }

    @Test("deleteOrder with unknown id leaves orders unchanged")
    func deleteOrderUnknownIdNoOp() {
        store.saveOrders(PastOrder.stubs)
        store.deleteOrder(id: UUID())
        #expect(store.loadOrders().count == PastOrder.stubs.count)
    }
}
