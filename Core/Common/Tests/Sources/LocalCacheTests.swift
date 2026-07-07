import Testing
import Foundation
import Common

@Suite("LocalCache")
struct LocalCacheTests {

    // MARK: - Initial state

    @Test("Returns nil for an unknown key")
    func returnsNilInitially() {
        let cache = LocalCache<String, Int>()
        #expect(cache.get("missing") == nil)
    }

    // MARK: - Set and get

    @Test("Returns the value that was stored for a key")
    func returnsStoredValue() {
        let cache = LocalCache<String, Int>()
        cache.set(42, for: "answer")
        #expect(cache.get("answer") == 42)
    }

    @Test("Second set for the same key overwrites the first")
    func setOverwritesPreviousValue() {
        let cache = LocalCache<String, Int>()
        cache.set(1, for: "key")
        cache.set(2, for: "key")
        #expect(cache.get("key") == 2)
    }

    @Test("Different keys are stored and retrieved independently")
    func differentKeysAreIndependent() {
        let cache = LocalCache<String, Int>()
        cache.set(10, for: "a")
        cache.set(20, for: "b")
        #expect(cache.get("a") == 10)
        #expect(cache.get("b") == 20)
    }

    // MARK: - Clear

    @Test("clear() removes all entries so every key returns nil")
    func clearRemovesAllValues() {
        let cache = LocalCache<String, Int>()
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.clear()
        #expect(cache.get("a") == nil)
        #expect(cache.get("b") == nil)
    }

    @Test("clear() on an empty cache does not crash")
    func clearOnEmptyCacheIsNoop() {
        let cache = LocalCache<String, Int>()
        cache.clear() // must not crash
    }

    // MARK: - Different key/value types

    @Test("Works with UUID keys")
    func supportsUUIDKeys() {
        let cache = LocalCache<UUID, String>()
        let id = UUID()
        cache.set("hello", for: id)
        #expect(cache.get(id) == "hello")
        #expect(cache.get(UUID()) == nil)
    }

    @Test("Works with array values")
    func supportsArrayValues() {
        let cache = LocalCache<String, [Int]>()
        cache.set([1, 2, 3], for: "list")
        #expect(cache.get("list") == [1, 2, 3])
    }
}
